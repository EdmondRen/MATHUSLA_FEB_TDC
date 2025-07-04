

-- ********************************************************************************************
-- [Fast data builder]
--  File: fast_data_builder.vhd
--  Description:
--      Data formatting and output module for TDC coincidence system. Latches fine/coarse times,
--      computes time difference and sum, and outputs a 64-bit data word. Handles buffer overflow
--      counting and output valid signaling.
--
--  Ports:
--      clk                 : System clock
--      rst_n               : Active-low synchronous reset
--      t1_ready, t2_ready  : Ready flags from TDCs
--      t1_fine, t2_fine    : Fine time values from TDCs
--      trigger_waiting_e1  : Indicates if waiting for E1
--      trigger_decision    : Coincidence trigger decision
--      dout                : 64-bit output data word
--      dout_valid          : Output data valid flag
--      buffer_full         : Input flag indicating output buffer is full
--      overflow_count      : Output overflow counter
--      overflow_count_rstn : Reset for overflow counter
--
--  Functionality:
--      - Latches fine/coarse times for each channel
--      - Computes signed time difference and unsigned sum
--      - Packs results into output word
--      - Handles overflow counting
-- ******************************************************************************************** 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fast_data_builder is
    generic (
        CHID_BITS    : natural := 6;
        FINE_BITS    : natural := 4;
        COARSE_BITS  : natural := 54; -- Width of the coarse counter
        CHID_A       : integer := 0;
        CHID_B       : integer := 1
    );
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic; -- **Synchronous** reset, active low

        -- [TDC input]
        t1_ready            : in  std_logic;
        t1_fine             : in  std_logic_vector(FINE_BITS - 1 downto 0);
        t2_ready            : in  std_logic;
        t2_fine             : in  std_logic_vector(FINE_BITS - 1 downto 0);    
        
        -- [Coinc. trigger input]
        trigger_waiting_e1  : in std_logic;
        trigger_decision    : in std_logic;

        -- [Data output]
        dout                : out std_logic_vector(64 - 1 downto 0);
        dout_valid          : out std_logic;
        buffer_full         : in std_logic;
        overflow_count    : out std_logic_vector(16 - 1 downto 0);
        overflow_count_rstn  : in std_logic

    );
end entity fast_data_builder;

architecture rtl of fast_data_builder is
    signal coarse_counter             : unsigned(COARSE_BITS - 1 downto 0)  := (others => '0');
    signal overflow_counter_internal  : unsigned(16 - 1 downto 0)  := (others => '0');
    signal full_time_t1               : unsigned(FINE_BITS + COARSE_BITS - 1 downto 0)  := (others => '0');
    signal full_time_t2               : unsigned(FINE_BITS + COARSE_BITS - 1 downto 0)  := (others => '0');

    signal t_diff               : signed(10 - 1 downto 0) := (others => '0');
    signal t_sum               : unsigned(48 - 1 downto 0)  := (others => '0');
begin
    
    -- [Coarse counter process] 
    coarse_counter_proc: process(clk, rst_n)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                coarse_counter <= (others => '0');
            else
                coarse_counter <= coarse_counter + 1;
            end if;
        end if;
    end process;    
    
    -- [Input time latching] 
    -- Record the coarse time for each hit
    finetime_latching_proc: process(clk, trigger_waiting_e1)
    begin
        if rising_edge(clk) then
            if t1_ready = '1' and trigger_waiting_e1 = '0' then
                full_time_t1 <= coarse_counter & unsigned(t1_fine);
            end if;
            if t2_ready = '1' and trigger_waiting_e1 = '0' then
                full_time_t2 <= coarse_counter & unsigned(t2_fine);
            end if;            
        end if;
    end process;        
    
    -- [Time calculation] 
    -- Calculate the time difference and summation, combinational
    -- ch_id: 6bits, CHID_A, the channel ID of the first channel of this pair
    -- t_diff: 10bits SIGNED, lowest 9 bits of full_time_t1-full_time_t2 with one sign bit. +/- 9bits = +/-128 ns, 0.25ns per bit
    -- t_sum: 48bits UNsigned, lowest 48 bits of full_time_t1+full_time_t2. Range of about 19 hours.
    time_calc_proc: process(full_time_t1, full_time_t2)
        variable diff : signed((FINE_BITS + COARSE_BITS) downto 0); -- one extra bit for sign
        variable sum  : unsigned((FINE_BITS + COARSE_BITS) downto 0); -- one extra bit for carry
    begin
        -- Calculate difference and sum with one extra bit for overflow/sign
        diff := signed('0' & full_time_t1) - signed('0' & full_time_t2);
        sum  := unsigned('0' & full_time_t1) + unsigned('0' & full_time_t2);

        -- t_diff: lowest 9 bits + sign (total 10 bits)
        t_diff <= diff(diff'left) & diff(8 downto 0); -- sign & 9 LSBs

        -- t_sum: 
        t_sum <= sum(48-1 downto 0);
    end process;

    -- [Output latch] 
    -- Calculate the time difference and summation, combinational
    output_latch_proc: process(clk, trigger_decision, overflow_count_rstn)
    begin
        if overflow_count_rstn = '0' then
            overflow_counter_internal <= (others => '0');
        elsif rising_edge(clk) then
            if trigger_decision = '1' then
                dout <= std_logic_vector(to_unsigned(CHID_A, CHID_BITS)) & std_logic_vector(t_diff) & std_logic_vector(t_sum);
                dout_valid <= '1';

                if buffer_full = '1' then
                    overflow_counter_internal <= overflow_counter_internal + 1;
                end if;
            else
                dout_valid <= '0';
            end if;
        end if;
    end process;    

    overflow_count <= std_logic_vector(overflow_counter_internal);
    

end architecture rtl;
------------------------------------------------------------------------------------------------
