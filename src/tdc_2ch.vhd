-- ********************************************************************************************
--  File: tdc_2ch.vhd
--  Description: 
--      Top-level entity for a two-channel coincidence TDC system. Instantiates two multiphase TDC
--      cores, a coincidence trigger module, and a fast data builder. The design measures the fine
--      time of two input signals (hit_1, hit_2), detects coincidences, and outputs formatted data.
--
--  Ports:
--      clk0-clk7         : 8-phase clock inputs for TDC sampling
--      rst_n             : Active-low reset
--      hit_1, hit_2      : Input hit signals for the two TDC channels
--      dout              : 64-bit output data word
--      dout_valid        : Output data valid flag
--      buffer_full       : Input flag indicating output buffer is full
--      overflow_count    : Output overflow counter
--      overflow_count_rstn: Reset for overflow counter
--
--  Submodules:
--      multiphase_tdc_core (x2)   : Fine time measurement for each channel
--      coincidence_trigger         : Coincidence logic for T1, T2, and E1
--      fast_data_builder           : Data formatting and output logic
-- ********************************************************************************************


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity tdc_2ch is
    generic (
        CHID_BITS    : natural := 6;
        FINE_BITS    : natural := 4;
        COARSE_BITS  : natural := 54; -- Width of the coarse counter
        CHID_A       : integer := 0;
        CHID_B       : integer := 1
    );
    port (
        -- [Clocks and reset]
        clk0, clk1, clk2, clk3, clk4, clk5, clk6, clk7 : in std_logic; -- 8-phase clock inputs
        rst_n : in std_logic; -- Reset input

        -- [Signal input]
        hit_1, hit_2 : in std_logic; -- Hit signal input

        -- [Signal input]
        hit_1_out, hit_2_out, trigger_decision_out : out std_logic; -- Hit signal input        

        -- [Data output]
        dout                : out std_logic_vector(64 - 1 downto 0);
        dout_valid          : out std_logic;
        buffer_full         : in std_logic;
        overflow_count    : out std_logic_vector(16 - 1 downto 0);
        overflow_count_rstn  : in std_logic
    );
end entity tdc_2ch;



architecture rtl of tdc_2ch is
    signal t1_ready : std_logic := '0';
    signal t1_fine  : std_logic_vector(FINE_BITS-1 downto 0);    

    signal t2_ready : std_logic := '0';
    signal t2_fine  : std_logic_vector(FINE_BITS-1 downto 0); 
    
    signal e1_internal : std_logic := '1';
    signal e1_disabled : std_logic := '1';

    signal trigger_waiting_e1 : std_logic := '1';
    signal coinc_triggered : std_logic := '1';

    -- signal buffer_full : std_logic := '0';
    -- signal overflow_count_rstn : std_logic := '1';

begin

    hit_1_out <= t1_ready;
    hit_2_out <= t2_ready;
    trigger_decision_out <= coinc_triggered;

    tdc1: entity work.multiphase_tdc_core 
        port map (
            clk0       => clk0,
            clk1       => clk1,
            clk2       => clk2,
            clk3       => clk3,
            clk4       => clk4,
            clk5       => clk5,
            clk6       => clk6,
            clk7       => clk7,
            rst_n      => rst_n,
            hit_signal => hit_1,
            t1_out     => t1_fine,
            t1_done    => t1_ready
        );            

    tdc2: entity work.multiphase_tdc_core 
        port map (
            clk0       => clk0,
            clk1       => clk1,
            clk2       => clk2,
            clk3       => clk3,
            clk4       => clk4,
            clk5       => clk5,
            clk6       => clk6,
            clk7       => clk7,
            rst_n      => rst_n,
            hit_signal => hit_2,
            t1_out     => t2_fine,
            t1_done    => t2_ready
        );  


    trigger: entity work.coincidence_trigger 
        port map (
            clk                  => clk0, -- Use clk0 as the main clock
            rst_n                => rst_n, -- Asynchronous reset, active low
            t1                   => t1_ready,
            t2                   => t2_ready,
            e1                   => e1_internal,
            e1_disabled          => e1_disabled,
            trigger_waiting_e1   => trigger_waiting_e1,
            trigger_decision_out => coinc_triggered        
        );        

    fast_data_builder_inst: entity work.fast_data_builder
        generic map (
            CHID_BITS   => CHID_BITS,
            FINE_BITS   => FINE_BITS,
            COARSE_BITS => COARSE_BITS,
            CHID_A      => CHID_A,
            CHID_B      => CHID_B
        )
        port map (
            clk                 => clk0, 
            rst_n               => rst_n,
            t1_ready            => t1_ready,
            t1_fine             => t1_fine,
            t2_ready            => t2_ready,
            t2_fine             => t2_fine,
            trigger_waiting_e1  => trigger_waiting_e1,
            trigger_decision    => coinc_triggered,
            dout                => dout,
            dout_valid          => dout_valid,
            buffer_full         => buffer_full,
            overflow_count      => overflow_count,
            overflow_count_rstn => overflow_count_rstn
        );

end architecture rtl;

