-- ********************************************************************************************
-- [Tripple coincidence trigger, T1 T2 E]
--  Description:
--      Coincidence trigger module for two TDC channels and an optional E1 signal. Implements a
--      state machine to detect triple coincidences (T1, T2, E1) with programmable windows and
--      optional E1 disable. Outputs trigger decision and waiting-for-E1 status.
--
--  Ports:
--      clk                 : System clock
--      rst_n               : Active-low asynchronous reset
--      t1, t2              : Input trigger signals (from TDCs)
--      e1                  : Optional E1 input (can be disabled)
--      e1_disabled         : Disables E1 requirement if high
--      trigger_waiting_e1  : High when waiting for E1 after T1/T2 coincidence
--      trigger_decision_out: High for one cycle when coincidence is detected
--
--  State Machine:
--      S_IDLE              : Waiting for first trigger
--      S_WAIT_SECOND_TRIGGER: Waiting for second trigger within window
--      S_WAIT_E1           : Waiting for E1 (if required)
--      S_TRIGGERED         : Output pulse, then return to idle
-- ********************************************************************************************
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity coincidence_trigger is
    generic (
        -- Constants for timer durations (in clock cycles)
        -- The timer will count N, N-1, ..., 1. '0' means time is up.
        -- So, N cycles are available where timer_reg > 0.
        COINCIDENCE_WINDOW_CYCLES : natural := 20-1;
        E1_WINDOW_CYCLES          : natural := 6-1 -- 24ns = 4ns*6
    );
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic; -- Asynchronous reset, active low

        t1                  : in  std_logic;
        t2                  : in  std_logic;
        e1                  : in  std_logic;
        e1_disabled         : in  std_logic;
        trigger_waiting_e1  : out std_logic;
        trigger_decision_out: out std_logic
    );
end entity coincidence_trigger;

architecture rtl of coincidence_trigger is

    -- State type definition for the FSM
    type t_state is (S_IDLE, S_WAIT_SECOND_TRIGGER, S_WAIT_E1, S_TRIGGERED);
    signal pr_state, nx_state : t_state;

    -- -- Constants for timer durations (in clock cycles)
    -- -- The timer will count N, N-1, ..., 1. '0' means time is up.
    -- -- So, N cycles are available where timer_reg > 0.
    -- constant COINCIDENCE_WINDOW_CYCLES : natural := 20-1;
    -- constant E1_WINDOW_CYCLES          : natural := 6-1; -- 20ns = 4ns*(6-1)

    -- Internal signals for edge detection
    signal t1_prev, t2_prev, e1_prev : std_logic;
    signal t1_rising, t2_rising, e1_rising : std_logic;

    -- Internal registers for timers and flags
    signal coincidence_timer_reg, coincidence_timer_next : natural range 0 to COINCIDENCE_WINDOW_CYCLES;
    signal e1_timer_reg, e1_timer_next                   : natural range 0 to E1_WINDOW_CYCLES;
    signal first_trigger_is_t1_reg, first_trigger_is_t1_next : boolean; -- true if t1 was first
    signal e1_seen_in_wait_second_trigger_reg, e1_seen_in_wait_second_trigger_next : boolean; -- NEW: tracks if E1 fired before t2

    -- Internal register for the output
    signal trigger_waiting_e1_reg, trigger_waiting_e1_next : std_logic := '0';
    signal trigger_out_reg : std_logic := '0';

begin

    -- Edge detection logic (combinational based on current and previous values)
    t1_rising <= t1 and not t1_prev;
    t2_rising <= t2 and not t2_prev;
    e1_rising <= e1 and not e1_prev;

    -- [State machine]
    -- Synchronous process: Updates state, timers, and previous signal values on clock edge
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            pr_state                <= S_IDLE;
            t1_prev                 <= '0';
            t2_prev                 <= '0';
            e1_prev                 <= '0';
            coincidence_timer_reg   <= 0;
            e1_timer_reg            <= 0;
            first_trigger_is_t1_reg <= false;
            trigger_out_reg         <= '0';
            e1_seen_in_wait_second_trigger_reg <= false; -- NEW: reset flag
        elsif rising_edge(clk) then
            pr_state                <= nx_state;
            t1_prev                 <= t1;
            t2_prev                 <= t2;
            e1_prev                 <= e1;
            coincidence_timer_reg   <= coincidence_timer_next;
            e1_timer_reg            <= e1_timer_next;
            first_trigger_is_t1_reg <= first_trigger_is_t1_next;
            e1_seen_in_wait_second_trigger_reg <= e1_seen_in_wait_second_trigger_next; -- NEW: register flag
            trigger_waiting_e1_reg <= trigger_waiting_e1_next;
            if nx_state = S_TRIGGERED then
                trigger_out_reg         <= '1'; -- Output is high only in S_TRIGGERED
            else
                trigger_out_reg         <= '0';
            end if;
        end if;
    end process;

    -- Combinational process: Determines next state and control signals based on current state and inputs
    process (pr_state, t1_rising, t2_rising, e1_rising, coincidence_timer_reg, e1_timer_reg, first_trigger_is_t1_reg, e1_seen_in_wait_second_trigger_reg)
        -- Variables for calculating next timer values within this process
        variable temp_coincidence_timer_val : natural range 0 to COINCIDENCE_WINDOW_CYCLES;
        variable temp_e1_timer_val        : natural range 0 to E1_WINDOW_CYCLES;
    begin
        -- Default assignments for next values (prevents latches for signals not assigned in all paths)
        nx_state                  <= pr_state;
        coincidence_timer_next    <= coincidence_timer_reg; -- By default, keep current timer value
        e1_timer_next             <= e1_timer_reg;          -- By default, keep current timer value
        first_trigger_is_t1_next  <= first_trigger_is_t1_reg;
        e1_seen_in_wait_second_trigger_next <= e1_seen_in_wait_second_trigger_reg; -- NEW: default

        case pr_state is
            when S_IDLE =>
                -- Reset timers for a clean start when a trigger is initiated
                -- These values will be loaded when transitioning to S_WAIT_SECOND_TRIGGER
                -- If no transition, ensure timers remain 0 or are explicitly reset.
                coincidence_timer_next <= 0;
                e1_timer_next          <= 0;
                e1_seen_in_wait_second_trigger_next <= false; -- NEW: reset flag
                trigger_waiting_e1_next <= '0';

                if t1_rising = '1' and t2_rising = '1' then
                    if e1_disabled = '0' then
                        nx_state             <= S_WAIT_E1;
                        e1_timer_next        <= E1_WINDOW_CYCLES;
                    else
                        nx_state             <= S_TRIGGERED;
                    end if;                  
                elsif t1_rising = '1' then
                    nx_state                 <= S_WAIT_SECOND_TRIGGER;
                    first_trigger_is_t1_next <= true;
                    coincidence_timer_next   <= COINCIDENCE_WINDOW_CYCLES;
                    e1_timer_next            <= E1_WINDOW_CYCLES;
                    e1_seen_in_wait_second_trigger_next <= false; -- NEW: reset flag
                elsif t2_rising = '1' then
                    nx_state                 <= S_WAIT_SECOND_TRIGGER;
                    first_trigger_is_t1_next <= false;
                    coincidence_timer_next   <= COINCIDENCE_WINDOW_CYCLES;
                    e1_timer_next            <= E1_WINDOW_CYCLES;
                    e1_seen_in_wait_second_trigger_next <= false; -- NEW: reset flag
                end if;

            when S_WAIT_SECOND_TRIGGER =>
                -- Timer (t1 & t2 coinc.)
                if coincidence_timer_reg > 0 then
                    temp_coincidence_timer_val := coincidence_timer_reg - 1;
                else
                    temp_coincidence_timer_val := 0;
                end if;
                coincidence_timer_next <= temp_coincidence_timer_val;

                -- Timer (e1)
                if e1_timer_reg > 0 then
                    temp_e1_timer_val := e1_timer_reg - 1;
                else
                    temp_e1_timer_val := 0;
                end if;
                e1_timer_next        <= temp_e1_timer_val;                


                -- [Special condition] 
                -- * E1 fires before the second T: set flag
                -- * E1 trigger is disable: set flag
                if e1_rising = '1' or e1_disabled = '1' then
                    e1_seen_in_wait_second_trigger_next <= true;
                end if;


                -- Wait for second time trigger
                if first_trigger_is_t1_reg then 
                    -- T1 was first, waiting for T2    
                    if t2_rising = '1' and coincidence_timer_reg > 0 then
                        if e1_seen_in_wait_second_trigger_reg then
                            nx_state <= S_TRIGGERED;
                        else
                            e1_timer_next <= E1_WINDOW_CYCLES; -- reset E1 counter before moving to wait_e1
                            trigger_waiting_e1_next <= '1';
                            nx_state <= S_WAIT_E1;
                        end if;
                    -- [Special condition 1] the same T fires again: reset timers and flag, stay in state
                    elsif t1_rising = '1' then
                        coincidence_timer_next <= COINCIDENCE_WINDOW_CYCLES;
                        e1_timer_next <= E1_WINDOW_CYCLES;
                        e1_seen_in_wait_second_trigger_next <= false;
                        nx_state <= S_WAIT_SECOND_TRIGGER;
                    -- time out, reset                        
                    elsif temp_coincidence_timer_val = 0 then
                        nx_state <= S_IDLE;
                    end if;
                else 
                    -- T2 was first, waiting for T1
                    if t1_rising = '1' and coincidence_timer_reg > 0 then
                        if e1_seen_in_wait_second_trigger_reg then
                            nx_state <= S_TRIGGERED;
                        else
                            e1_timer_next <= E1_WINDOW_CYCLES; -- reset E1 counter before moving to wait_e1
                            trigger_waiting_e1_next <= '1';
                            nx_state <= S_WAIT_E1;
                        end if;
                    -- [Special condition 1] the same T fires again: reset timers and flag, stay in state
                    elsif t2_rising = '1' then
                        coincidence_timer_next <= COINCIDENCE_WINDOW_CYCLES;
                        e1_timer_next <= E1_WINDOW_CYCLES;
                        e1_seen_in_wait_second_trigger_next <= false;
                        nx_state <= S_WAIT_SECOND_TRIGGER;
                    elsif temp_coincidence_timer_val = 0 then
                        nx_state <= S_IDLE;
                    end if;
                end if;

            when S_WAIT_E1 =>
                -- Calculate next timer value (potential decrement)
                if e1_timer_reg > 0 then
                    temp_e1_timer_val := e1_timer_reg - 1;
                else
                    temp_e1_timer_val := 0;
                end if;
                e1_timer_next <= temp_e1_timer_val;

                if (e1_rising = '1' and e1_timer_reg > 0) or e1_disabled = '1' then
                    nx_state <= S_TRIGGERED;
                elsif temp_e1_timer_val = 0 then
                    nx_state <= S_IDLE;
                end if;

            when S_TRIGGERED =>
                -- The trigger_out_reg is set high by the synchronous process when pr_state = S_TRIGGERED.
                -- Stay in this state for one cycle, then go to IDLE.
                nx_state <= S_IDLE;
                -- Ensure timers are reset for the next sequence starting from IDLE
                coincidence_timer_next <= 0;
                e1_timer_next        <= 0;
                e1_seen_in_wait_second_trigger_next <= false; -- NEW: reset flag

        end case;
    end process;

    -- Assign registered output to the port
    trigger_decision_out <= trigger_out_reg;
    trigger_waiting_e1 <= trigger_waiting_e1_reg;
end architecture rtl;

