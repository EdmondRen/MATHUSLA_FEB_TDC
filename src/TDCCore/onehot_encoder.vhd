-- VHDL code for a 16-bit one-hot to 4-bit binary decoder.
-- This version uses direct LUT instantiation for manual optimization
-- to meet extreme timing constraints.

-- Standard IEEE libraries
library ieee;
use ieee.std_logic_1164.all;

-- For Xilinx FPGAs, the UNISIM library contains the primitive components like LUTs.
library UNISIM;
use UNISIM.vcomponents.all;

-- Entity declaration for the decoder
entity one_hot_to_binary_decoder is
    port (
        one_hot_in : in  std_logic_vector(15 downto 0); -- 16-bit one-hot input
        binary_out : out std_logic_vector(3 downto 0)   -- 4-bit binary output
    );
end entity one_hot_to_binary_decoder;

-- Architecture definition
architecture rtl of one_hot_to_binary_decoder is
    -- Intermediate signals for the first level of our manual LUT tree
    signal level1_out : std_logic_vector(3 downto 0);
    -- Final combinational output before the output register
    signal binary_out_comb : std_logic_vector(3 downto 0);

begin
    -- STAGE 1: Combinational Decoder Logic using Manual LUT Instantiation
    -- We manually build a 2-level LUT structure to create the 8-input OR
    -- functions required for each output bit. This gives us maximum control.

    -- *** Logic for binary_out(0) = OR(I(1), I(3), I(5), I(7), I(9), I(11), I(13), I(15)) ***
    LUT6_bit0: LUT6
    generic map (
        -- INIT is a 64-bit hex value defining the LUT's truth table.
        -- FFFFFFFE is a 6-input OR gate. Output is '1' unless all inputs are '0'.
        INIT => x"FFFFFFFFFFFFFFFE"
    )
    port map (
        O  => level1_out(0),
        I0 => one_hot_in(1),
        I1 => one_hot_in(3),
        I2 => one_hot_in(5),
        I3 => one_hot_in(7),
        I4 => one_hot_in(9),
        I5 => one_hot_in(11)
    );
    LUT2_bit0_final: LUT2
    generic map (
        -- INIT is a 4-bit value. 'E' (1110) is a 2-input OR gate.
        INIT => x"E"
    )
    port map (
        O  => binary_out_comb(0),
        I0 => level1_out(0),
        I1 => one_hot_in(13) or one_hot_in(15) -- Let tool handle this simple part
    );

    -- *** Logic for binary_out(1) = OR(I(2), I(3), I(6), I(7), I(10), I(11), I(14), I(15)) ***
    LUT6_bit1: LUT6
    generic map (INIT => x"FFFFFFFFFFFFFFFE")
    port map (
        O  => level1_out(1),
        I0 => one_hot_in(2),
        I1 => one_hot_in(3),
        I2 => one_hot_in(6),
        I3 => one_hot_in(7),
        I4 => one_hot_in(10),
        I5 => one_hot_in(11)
    );
    LUT2_bit1_final: LUT2
    generic map (INIT => x"E")
    port map (
        O  => binary_out_comb(1),
        I0 => level1_out(1),
        I1 => one_hot_in(14) or one_hot_in(15)
    );

    -- *** Logic for binary_out(2) = OR(I(4), I(5), I(6), I(7), I(12), I(13), I(14), I(15)) ***
    LUT6_bit2: LUT6
    generic map (INIT => x"FFFFFFFFFFFFFFFE")
    port map (
        O  => level1_out(2),
        I0 => one_hot_in(4),
        I1 => one_hot_in(5),
        I2 => one_hot_in(6),
        I3 => one_hot_in(7),
        I4 => one_hot_in(12),
        I5 => one_hot_in(13)
    );
    LUT2_bit2_final: LUT2
    generic map (INIT => x"E")
    port map (
        O  => binary_out_comb(2),
        I0 => level1_out(2),
        I1 => one_hot_in(14) or one_hot_in(15)
    );

    -- *** Logic for binary_out(3) = OR(I(8), I(9), I(10), I(11), I(12), I(13), I(14), I(15)) ***
    LUT6_bit3: LUT6
    generic map (INIT => x"FFFFFFFFFFFFFFFE")
    port map (
        O  => level1_out(3),
        I0 => one_hot_in(8),
        I1 => one_hot_in(9),
        I2 => one_hot_in(10),
        I3 => one_hot_in(11),
        I4 => one_hot_in(12),
        I5 => one_hot_in(13)
    );
    LUT2_bit3_final: LUT2
    generic map (INIT => x"E")
    port map (
        O  => binary_out_comb(3),
        I0 => level1_out(3),
        I1 => one_hot_in(14) or one_hot_in(15)
    );

    -- Output
    binary_out <= binary_out_comb;

end architecture rtl;
