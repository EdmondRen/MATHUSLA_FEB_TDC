library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity coincidence_trigger_tb is
end entity coincidence_trigger_tb;

architecture behavioral of coincidence_trigger_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component coincidence_trigger is
        port (
            clk                 : in  std_logic;
            rst_n               : in  std_logic; -- Asynchronous reset, active low
            t1                  : in  std_logic;
            t2                  : in  std_logic;
            e1                  : in  std_logic;
            trigger_decision_out: out std_logic
        );
    end component coincidence_trigger;

    -- Inputs
    signal clk_tb     : std_logic := '0';
    signal rst_n_tb   : std_logic := '0';
    signal t1_tb      : std_logic := '0';
    signal t2_tb      : std_logic := '0';
    signal e1_tb      : std_logic := '0';

    -- Outputs
    signal trigger_decision_out_tb : std_logic;

    -- Clock period definition
    constant clk_period : time := 10 ns; -- Example: 100 MHz clock

    -- Simulation control
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: coincidence_trigger
        port map (
            clk                  => clk_tb,
            rst_n                => rst_n_tb,
            t1                   => t1_tb,
            t2                   => t2_tb,
            e1                   => e1_tb,
            trigger_decision_out => trigger_decision_out_tb
        );

    -- Clock process definition
    clk_process :process
    begin
        if not sim_done then
            clk_tb <= '0';
            wait for clk_period/2;
            clk_tb <= '1';
            wait for clk_period/2;
        else
            wait;
        end if;
    end process;

    -- Stimulus process
    stim_proc: process
        procedure pulse_signal(signal s : out std_logic; delay_cycles : natural := 0; duration_cycles : natural := 1) is
        begin
            if delay_cycles > 0 then
                wait for delay_cycles * clk_period;
            end if;
            s <= '1';
            wait for duration_cycles * clk_period;
            s <= '0';
        end procedure;

        procedure report_status(message : string) is
            variable l : line;
        begin
            write(l, string'("TIME: "));
            write(l, now);
            write(l, string'(", STATUS: " & message));
            writeline(output, l);
        end procedure;

    begin
        report_status("Starting Testbench");

        -- 1. Initial Reset
        rst_n_tb <= '0';
        t1_tb <= '0';
        t2_tb <= '0';
        e1_tb <= '0';
        wait for 5 * clk_period;
        rst_n_tb <= '1';
        report_status("Reset Released");
        wait for 2 * clk_period;

        -- Test Case 1: Successful trigger (t1 -> t2 -> e1)
        report_status("Test Case 1: t1 -> t2 -> e1 (Success)");
        pulse_signal(t1_tb, 2); -- t1 at cycle 2 (relative to this section)
        pulse_signal(t2_tb, 10-1); -- t2 at cycle 10 (8 cycles after t1)
        pulse_signal(e1_tb, 15-1-10); -- e1 at cycle 15 (5 cycles after t2, 13 after t1)
        wait for 30 * clk_period; -- Observe for potential trigger and settle

        -- Test Case 1a: Successful trigger (t1 -> t1 -> t2 -> e1)
        report_status("Test Case 1: t1 -> t2 -> e1 (Success)");
        pulse_signal(t1_tb, 2); -- t1 at cycle 2 (relative to this section)
        pulse_signal(t1_tb, 8); -- t1 at cycle 8 (relative to this section)
        pulse_signal(t2_tb, 18-1-8); -- t2 at cycle 10 (8 cycles after t1)
        pulse_signal(e1_tb, 23-1-8-10); -- e1 at cycle 15 (5 cycles after t2, 13 after t1)
        wait for 30 * clk_period; -- Observe for potential trigger and settle        

        -- Test Case 2: Successful trigger (t2 -> t1 -> e1)
        report_status("Test Case 2: t2 -> t1 -> e1 (Success)");
        pulse_signal(t2_tb, 2);
        pulse_signal(t1_tb, 15-1);  -- t1 3 cycles after t2
        pulse_signal(e1_tb, 20-1-15); -- e1 15 cycles after t1, 18 after t2
        wait for 35 * clk_period;

        -- Test Case 2a: Successful trigger (t2 -> e1 -> t1)
        report_status("Test Case 2: t2 -> t1 -> e1 (Success)");
        pulse_signal(t2_tb, 2);
        pulse_signal(e1_tb, 5-1);  -- t1 3 cycles after t2
        pulse_signal(t1_tb, 18-1-5); -- e1 15 cycles after t1, 18 after t2
        wait for 35 * clk_period;        

        -- Test Case 3: Timeout - t2 too late
        report_status("Test Case 3: t1 -> t2 (too late)");
        pulse_signal(t1_tb, 2);
        pulse_signal(t2_tb, 25-1); -- t2 at cycle 25 (23 cycles after t1, COINCIDENCE_WINDOW is 20)
        wait for 30 * clk_period;

        -- Test Case 4: Timeout - e1_timer expires (no t2)
        report_status("Test Case 4: t1 -> (no t2) -> e1_timer expires");
        pulse_signal(t1_tb, 2);
        -- No t2 pulse
        wait for 40 * clk_period; -- Wait for E1_WINDOW_CYCLES (30) + buffer

        -- Test Case 5: Timeout - e1 too late
        report_status("Test Case 5: t1 -> t2 -> e1 (too late)");
        pulse_signal(t1_tb, 2);
        pulse_signal(t2_tb, 5-1);   -- t2 3 cycles after t1
        pulse_signal(e1_tb, 35-1-5);  -- e1 at cycle 35 (30 cycles after t2, 33 after t1, E1_WINDOW is 30 from t1)
        wait for 40 * clk_period;

        -- Test Case 6: Simultaneous t1, t2 (t1 should take precedence) -> e1
        report_status("Test Case 6: Simultaneous t1, t2 (t1 prio) -> e1");
        -- Pulse t1 and t2 in the same cycle
        t1_tb <= '1';
        t2_tb <= '1';
        wait for 1 * clk_period;
        t1_tb <= '0';
        t2_tb <= '0';
        -- e1 should arrive based on t1 being first
        pulse_signal(e1_tb, 10-1); -- e1 10 cycles after t1/t2
        wait for 30 * clk_period;

        -- Test Case 7: e1 arrives before second trigger (should be ignored, then valid sequence)
        report_status("Test Case 7: e1 early, then t1 -> t2 -> e1");
        pulse_signal(e1_tb, 2);    -- Early e1
        wait for 5 * clk_period; -- Let it pass
        pulse_signal(t1_tb, 2);    -- t1
        pulse_signal(t2_tb, 5-1);   -- t2 (3 cycles after t1)
        pulse_signal(e1_tb, 10-1-5);  -- e1 (5 cycles after t2, 8 after t1)
        wait for 30 * clk_period;

        -- Test Case 8: Reset during S_WAIT_SECOND_TRIGGER
        report_status("Test Case 8: Reset during S_WAIT_SECOND_TRIGGER");
        pulse_signal(t1_tb, 2);    -- Enter S_WAIT_SECOND_TRIGGER
        wait for 5 * clk_period;
        rst_n_tb <= '0';
        wait for 3 * clk_period;
        rst_n_tb <= '1';
        report_status("Reset released after interruption");
        wait for 10 * clk_period; -- Observe no trigger
        -- Try a valid sequence post-reset
        report_status("Test Case 8b: Valid sequence post-reset");
        pulse_signal(t1_tb, 2);
        pulse_signal(t2_tb, 5-1);
        pulse_signal(e1_tb, 10-1-5);
        wait for 30 * clk_period;

        -- Test Case 9: Back-to-back triggers
        report_status("Test Case 9: Back-to-back triggers");
        -- First trigger
        pulse_signal(t1_tb, 2);
        pulse_signal(t2_tb, 5-1);
        pulse_signal(e1_tb, 8-1-5);
        wait for 20 * clk_period; -- Allow first trigger to complete and system to return to idle
        -- Second trigger immediately after
        pulse_signal(t1_tb, 1); -- Start next sequence quickly
        pulse_signal(t2_tb, 6-1);
        pulse_signal(e1_tb, 10-1-6);
        wait for 30 * clk_period;

        report_status("All test cases finished.");
        sim_done <= true;
        wait;
    end process stim_proc;

end architecture behavioral;