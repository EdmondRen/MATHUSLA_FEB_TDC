library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity FIFO_AXI4_Stream_Wrap is
    generic (
        PACKET_SIZE : integer := 500
      );    
    port (
        -- [CDC FIFO read interface]
        fifo_read_data : in std_logic_vector(64-1 downto 0);
        fifo_empty : in std_logic;
        fifo_read_enable : out std_logic;
        fifo_rd_clk : in std_logic;

        -- [AXI-Stream compatible interface]
        m_axis_tdata : out std_logic_vector(64-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tlast : out std_logic --Optional
        -- m_axis_clk : in std_logic
               
    );
end entity FIFO_AXI4_Stream_Wrap;

architecture rtl of FIFO_AXI4_Stream_Wrap is
    signal tvalid_buf : std_logic := '0';
    signal tlast_buf1 : std_logic := '0';
    signal tlast_buf2 : std_logic := '0';
    signal tlast_buf3 : std_logic := '0';
    signal counter : integer := PACKET_SIZE;
begin    
    m_axis_tdata  <= fifo_read_data;
    fifo_read_enable <= m_axis_tready AND NOT fifo_empty;

    -- [Internal counter]
    counter_proc: process(fifo_rd_clk, fifo_empty)
    begin
        if rising_edge(fifo_rd_clk) and m_axis_tready='1' and fifo_empty='0' then
            if counter = 0 then
                counter <= PACKET_SIZE-1;
            else
                counter <= counter-1;
            end if;
        end if;        
    end process;      


    -- [Output Valid bit]
    output_valid_flag: process(fifo_rd_clk)
    begin
        if rising_edge(fifo_rd_clk) then
            tvalid_buf <= NOT fifo_empty;
            tlast_buf1 <= tvalid_buf;
            tlast_buf2 <= tlast_buf1;
            tlast_buf3 <= tlast_buf2;   

            if counter = 0 then
                m_axis_tlast <= tlast_buf3;
            else
                m_axis_tlast <= '0';
            end if;
            m_axis_tvalid <= NOT fifo_empty;
        end if;        
    end process;        

    -- fifo_rd_clk <= m_axis_clk;
end architecture rtl;