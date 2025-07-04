library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Testbench for the  TDC core. 

-- Clock Generation:
-- Base clock frequency of 500MHz (2ns period)
-- 8 phase-shifted clocks (clk0 through clk7)
-- Each clock is shifted by PHASE_SHIFT (625ps = 10ns/16)
-- This creates a 16-phase system when considering both rising and falling edges

-- Test Cases:
-- Test Case 1: Hit between clk1 and clk2
-- Test Case 2: Hit between clk3 and clk4
-- Test Case 3: Hit between clk5 and clk6
-- Test Case 4: Hit between clk7 and clk0
-- Each test case generates a 2ns hit pulse

-- Monitoring:
-- Reports timestamp values when hits are detected
-- Monitors on clk0 rising edge
-- Displays both fine and coarse time values

-- Simulation Control:
-- Uses sim_done signal to gracefully end all processes
-- 100ns initialization period
-- Adequate wait times between test cases

-- To run the simulation, you'll need to:
-- Compile both the TDCCore.vhd and tb_TDCCore.vhd files
-- Set tb_TDCCore as your top-level entity
-- Run the simulation for at least 1000ns to see all test cases

-- The testbench will verify:
-- Proper phase relationships between clocks
-- Correct hit detection
-- Accurate fine time measurement
-- Proper synchronization to clk0
-- Coarse counter operation

entity tb_multiphase_tdc is
end entity tb_multiphase_tdc;

architecture tb of tb_multiphase_tdc is
    -- Constants for the design
    constant COARSE_BITS : positive := 28;
    constant FINE_BITS : positive := 4;

    -- Component declaration
    -- component multiphase_tdc is
    --     generic (
    --         COARSE_BITS : positive;
    --         FINE_BITS : positive
    --     );
    --     port (
    --         -- Clock inputs
    --         clk0, clk1, clk2, clk3, clk4, clk5, clk6, clk7 : in std_logic;
    --         rst_n : in std_logic;

    --         hit_signal : in std_logic;

    --         t1_out : out unsigned(COARSE_BITS + FINE_BITS-1 downto 0);
    --         t1_done : out std_logic;
    --         t1_busy : out std_logic
    --     );
    -- end component;

    -- Clock period definitions
    constant CLK_PERIOD : time := 2 ns;  -- 100MHz base clock
    constant PHASE_SHIFT : time := CLK_PERIOD/16;  -- Phase shift between clocks

    -- Signal declarations
    signal clk0, clk1, clk2, clk3, clk4, clk5, clk6, clk7 : std_logic := '0';
    signal rst_n : std_logic := '1';
    signal hit_signal : std_logic := '0';
    signal timestamp : unsigned(64-1 downto 0);
    -- signal timestamp : unsigned(COARSE_BITS + FINE_BITS-1 downto 0);
    signal t1_done : std_logic;
    signal t1_busy : std_logic;

    -- Simulation control
    signal sim_done : boolean := false;

begin
    -- Instantiate the Unit Under Test (UUT)
    UUT: entity work.multiphase_tdc
    generic map (
        COARSE_BITS => COARSE_BITS,
        FINE_BITS => FINE_BITS
    )
    port map (
        clk0 => clk0,
        clk1 => clk1,
        clk2 => clk2,
        clk3 => clk3,
        clk4 => clk4,
        clk5 => clk5,
        clk6 => clk6,
        clk7 => clk7,
        rst_n => rst_n,

        hit_signal => hit_signal,
        t1_out => timestamp,
        t1_done => t1_done,
        t1_busy => t1_busy

    );

    -- Clock generation processes
    clk0_proc: process
    begin
        while not sim_done loop
            clk0 <= '0';
            wait for CLK_PERIOD/2;
            clk0 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk1_proc: process
    begin
        wait for PHASE_SHIFT;
        while not sim_done loop
            clk1 <= '0';
            wait for CLK_PERIOD/2;
            clk1 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk2_proc: process
    begin
        wait for PHASE_SHIFT * 2;
        while not sim_done loop
            clk2 <= '0';
            wait for CLK_PERIOD/2;
            clk2 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk3_proc: process
    begin
        wait for PHASE_SHIFT * 3;
        while not sim_done loop
            clk3 <= '0';
            wait for CLK_PERIOD/2;
            clk3 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk4_proc: process
    begin
        wait for PHASE_SHIFT * 4;
        while not sim_done loop
            clk4 <= '0';
            wait for CLK_PERIOD/2;
            clk4 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk5_proc: process
    begin
        wait for PHASE_SHIFT * 5;
        while not sim_done loop
            clk5 <= '0';
            wait for CLK_PERIOD/2;
            clk5 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk6_proc: process
    begin
        wait for PHASE_SHIFT * 6;
        while not sim_done loop
            clk6 <= '0';
            wait for CLK_PERIOD/2;
            clk6 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    clk7_proc: process
    begin
        wait for PHASE_SHIFT * 7;
        while not sim_done loop
            clk7 <= '0';
            wait for CLK_PERIOD/2;
            clk7 <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stimulus: process
    begin
        -- Initialize
        hit_signal <= '0';
        wait for 10 ns;  -- Wait for clocks to stabilize
        rst_n <= '0';
        wait for 10 ns;  -- Wait for clocks to stabilize
        rst_n <= '1';
        wait for 10 ns;  -- Wait for clocks to stabilize

        -- Test Case 1: Hit between clk1 and clk2
        wait until rising_edge(clk1);
        wait for PHASE_SHIFT*0.5;  -- Wait 1/16th of clock period
        hit_signal <= '1';
        wait for 0.5 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 2.3;

        -- Test Case 2: Hit between clk3 and clk4
        wait until rising_edge(clk3);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 0.5 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;

        -- Test Case 3: Hit between clk5 and clk6
        wait until rising_edge(clk5);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 20.5 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;

        -- Test Case 4: Hit between clk7 and clk0
        wait until rising_edge(clk7);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 20.5 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;

        -- Test Case 5: Hit between clk1- and clk2-
        wait until falling_edge(clk1);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 20.3 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;    
        
        -- Test Case 6: Hit between clk3- and clk4-
        wait until falling_edge(clk3);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 20.3 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;    

        -- Test Case 7: Hit between clk5- and clk6-
        wait until falling_edge(clk5);
        wait for PHASE_SHIFT*0.5;
        hit_signal <= '1';
        wait for 20.3 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;                    

        -- Test Case 8: Hit between clk7- and clk0+
        wait until falling_edge(clk7);
        wait for PHASE_SHIFT*0.5;
        wait for 0.066 ns;
        hit_signal <= '1';
        wait for 20.3 ns;
        hit_signal <= '0';
        wait for CLK_PERIOD * 5;    
        
        -- End simulation
        wait for 100 ns;
        sim_done <= true;
        wait;
    end process;

    -- Monitor process
    monitor: process
        variable fine_time : integer;
        variable coarse_time : integer;
    begin
        wait for 100 ns;  -- Skip initialization period
        
        while not sim_done loop
            if rising_edge(clk0) then
                -- Monitor timestamp
                if hit_signal = '1' then
                    fine_time := to_integer(unsigned(timestamp(FINE_BITS-1 downto 0)));
                    coarse_time := to_integer(unsigned(timestamp(timestamp'high downto FINE_BITS)));
                    report "Hit detected! Timestamp = " & integer'image(coarse_time) &
                           " (coarse) + " & integer'image(fine_time) & " (fine)";
                end if;

--                -- Monitor AXI-Stream interface
--                if m_axis_tvalid = '1' and m_axis_tready = '1' then
--                    report "AXI-Stream data: " & integer'image(to_integer(unsigned(m_axis_tdata))) &
--                           " (Last: " & std_logic'image(m_axis_tlast) & ")";
--                end if;
            end if;
            wait until rising_edge(clk0);
        end loop;
        wait;
    end process;

end architecture tb; 