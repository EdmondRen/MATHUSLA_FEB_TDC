
-- ********************************************************************************************
-- [Single-channel trigger, T1+E1, T2+E1]
--  Description:
--      Single-channel trigger module for two TDC channels and an optional E1 signal. 
--      Latches fine time with internal coarse counter for full time stamp.
--      Implements a state machine to detect energy validated trigger (T1+E1, T2+E1) with programmable windows and optional E1 disable.
--      Implements a round-robin arbiter + MUX to select the correct output.
--
--  Ports:
--      clk                 : System clock
--      rst_n               : Active-low asynchronous reset
--      t1_ready, t2_ready  : Input trigger signals (from TDCs)
--      t1_fine, t2_fine    : Input fine time (from TDCs)
--      e1                  : Optional E1 input (can be disabled)
--      e1_disabled         : Disables E1 requirement if high
--      dout[63:0]          : Data output. [63:58] 6 bit channel ID;
--      dout_valid          : out std_logic;
--
--  State Machine:
--      S_IDLE              : Waiting for first trigger
--      S_WAIT_E1           : Waiting for E1 (if required)
--      S_TRIGGERED         : Output pulse, then return to idle
-- ********************************************************************************************
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_trigger is
    generic (
        CHID_BITS    : natural := 6;
        FINE_BITS    : natural := 4;
        COARSE_BITS  : natural := 54; -- Width of the coarse counter
        CHID_A       : integer := 0; -- ID of the first channel
        CHID_B       : integer := 1;  -- ID of the second channel

        E1_WINDOW_CYCLES          : natural := 6-1 -- 20ns = 4ns*(6-1)
    );    
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic; -- Asynchronous reset, active low

        -- [TDC input]
        t1_ready            : in  std_logic;
        t1_fine             : in  std_logic_vector(FINE_BITS - 1 downto 0);
        t2_ready            : in  std_logic;
        t2_fine             : in  std_logic_vector(FINE_BITS - 1 downto 0);    
        e1                  : in  std_logic;
        e1_disabled         : in  std_logic;

        -- [Data output]
        dout                : out std_logic_vector(64 - 1 downto 0);
        dout_valid          : out std_logic
    );
end entity single_trigger;

architecture rtl of single_trigger is
    -- State type definition for the FSM
    type single_state_t is (S_IDLE, S_WAIT_E1, S_TRIGGERED);
    signal pr_state, nx_state : single_state_t := S_IDLE;
    
    signal coarse_counter             : unsigned(COARSE_BITS - 1 downto 0)  := (others => '0');
    signal full_time_t1               : unsigned(FINE_BITS + COARSE_BITS - 1 downto 0)  := (others => '0');
    signal full_time_t2               : unsigned(FINE_BITS + COARSE_BITS - 1 downto 0)  := (others => '0');
    
    signal t1_prev, t2_prev, e1_prev : std_logic := '0';
    signal t1_rising, t2_rising, e1_rising : std_logic;
    signal e1_seen : std_logic := '0';
    signal e1_timer_reg : natural range 0 to E1_WINDOW_CYCLES := 0;

    -- Pending buffer for up to 2 triggers
    type ch_array is array(1 downto 0) of std_logic; -- 0: t1, 1: t2
    type time_array is array(1 downto 0) of unsigned(FINE_BITS + COARSE_BITS - 1 downto 0);
    signal pending_ch   : ch_array := (others => '0');
    signal pending_time : time_array := (others => (others => '0'));
    signal pending_count : integer range 0 to 2 := 0;
    signal pending_head  : integer range 0 to 1 := 0;

    signal dout_reg : std_logic_vector(64-1 downto 0) := (others => '0');
    signal dout_valid_reg : std_logic := '0';

begin
    -- Edge detection
    t1_rising <= t1_ready and not t1_prev;
    t2_rising <= t2_ready and not t2_prev;
    e1_rising <= e1 and not e1_prev;

    -- Coarse counter process
    coarse_counter_proc2: process(clk, rst_n)
    begin
        if rst_n = '0' then
            coarse_counter <= (others => '0');
        elsif rising_edge(clk) then
            coarse_counter <= coarse_counter + 1;
        end if;
    end process;

    -- Buffer management, state, and output logic (single process)
    main_proc: process(clk, rst_n)
        variable enqueue_idx : integer;
    begin
        if rst_n = '0' then
            full_time_t1 <= (others => '0');
            full_time_t2 <= (others => '0');
            t1_prev <= '0';
            t2_prev <= '0';
            e1_prev <= '0';
            e1_seen <= '0';
            e1_timer_reg <= 0;
            pending_ch   <= (others => '0');
            pending_time <= (others => (others => '0'));
            pending_count <= 0;
            pending_head  <= 0;
            dout_reg <= (others => '0');
            dout_valid_reg <= '0';
            pr_state <= S_IDLE;
        elsif rising_edge(clk) then
            -- Edge detection
            t1_prev <= t1_ready;
            t2_prev <= t2_ready;
            e1_prev <= e1;

            -- Default output
            dout_valid_reg <= '0';

            -- State machine
            pr_state <= nx_state;

            -- Buffer management and state transitions
            enqueue_idx := (pending_head + pending_count) mod 2;

            case pr_state is
                when S_IDLE =>
                    -- Enqueue triggers
                    if t1_rising = '1' and t2_rising = '1' then
                        full_time_t1 <= coarse_counter & unsigned(t1_fine);
                        full_time_t2 <= coarse_counter & unsigned(t2_fine);
                        pending_ch(enqueue_idx) <= '0'; -- t1
                        pending_time(enqueue_idx) <= coarse_counter & unsigned(t1_fine);
                        pending_ch((enqueue_idx+1) mod 2) <= '1'; -- t2
                        pending_time((enqueue_idx+1) mod 2) <= coarse_counter & unsigned(t2_fine);
                        pending_count <= 2;
                    elsif t1_rising = '1' then
                        full_time_t1 <= coarse_counter & unsigned(t1_fine);
                        pending_ch(enqueue_idx) <= '0';
                        pending_time(enqueue_idx) <= coarse_counter & unsigned(t1_fine);
                        pending_count <= 1;
                    elsif t2_rising = '1' then
                        full_time_t2 <= coarse_counter & unsigned(t2_fine);
                        pending_ch(enqueue_idx) <= '1';
                        pending_time(enqueue_idx) <= coarse_counter & unsigned(t2_fine);
                        pending_count <= 1;
                    end if;
                    e1_seen <= '0';
                    e1_timer_reg <= 0;

                when S_WAIT_E1 =>
                    -- E1 timer update
                    if e1_rising = '1' then
                        e1_seen <= '1';
                    end if;
                    if e1_timer_reg > 0 then
                        e1_timer_reg <= e1_timer_reg - 1;
                    end if;

                when S_TRIGGERED =>
                    -- Output the pending channel at head
                    if pending_count > 0 then
                        if pending_ch(pending_head) = '0' then
                            dout_reg <= std_logic_vector(to_unsigned(CHID_A, CHID_BITS)) & std_logic_vector(pending_time(pending_head));
                        else
                            dout_reg <= std_logic_vector(to_unsigned(CHID_B, CHID_BITS)) & std_logic_vector(pending_time(pending_head));
                        end if;
                        dout_valid_reg <= '1';
                        -- Move head and decrement count
                        pending_head <= (pending_head + 1) mod 2;
                        pending_count <= pending_count - 1;
                    end if;
            end case;

            -- Timer load on entry to S_WAIT_E1
            if pr_state /= S_WAIT_E1 and nx_state = S_WAIT_E1 then
                e1_timer_reg <= E1_WINDOW_CYCLES;
            end if;
            -- Reset pending buffer if WAIT_E1 times out
            if pr_state = S_WAIT_E1 and nx_state = S_IDLE and e1_timer_reg = 0 then
                pending_count <= 0;
                pending_head <= 0;
            end if;
        end if;
    end process;

    -- State machine combinational logic (unchanged)
    statemachine_proc: process(pr_state, pending_count, e1_rising, e1_disabled, e1_seen, e1_timer_reg)
    begin
        nx_state <= pr_state;
        case pr_state is
            when S_IDLE =>
                if pending_count > 0 then
                    if e1_disabled = '1' then
                        nx_state <= S_TRIGGERED;
                    else
                        nx_state <= S_WAIT_E1;
                    end if;
                end if;
            when S_WAIT_E1 =>
                if e1_rising = '1' or e1_disabled = '1' or e1_seen = '1' then
                    nx_state <= S_TRIGGERED;
                elsif e1_timer_reg = 0 then
                    nx_state <= S_IDLE;
                end if;
            when S_TRIGGERED =>
                if pending_count > 1 then
                    if e1_disabled = '1' or e1_seen = '1' then
                        nx_state <= S_TRIGGERED;
                    else
                        nx_state <= S_WAIT_E1;
                    end if;
                else
                    nx_state <= S_IDLE;
                end if;
        end case;
    end process;

    dout <= dout_reg;
    dout_valid <= dout_valid_reg;

end architecture rtl;
