------------------------------------------------------------------------------------------------
-- [LUT based Buffer entity] to prevent synthesis from optimizing away the buffer
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM; -- Library for Xilinx primitives
use UNISIM.vcomponents.all; -- Import all components from UNISIM

entity LUT_buf is
    port (
        input  : in  std_logic;
        output : out std_logic
    );
end entity LUT_buf;

architecture rtl of LUT_buf is
begin
    -- Instantiate a LUT1 primitive to act as a buffer
    -- The INIT parameter for a LUT1 determines its logical function.
    -- For a simple buffer (output = input), INIT = "2'b10" (binary) or "2" (hex).
    --   If input is 0, output is LUT_content[0].
    --   If input is 1, output is LUT_content[1].
    --   So, for output = input, LUT_content[0] = 0, LUT_content[1] = 1. This is binary "10".
    lut1_i : LUT1
        generic map (
            INIT => "10"  -- Implements O = I0 (buffer)
        )
        port map (
            I0 => input,
            O  => output
        );
end architecture rtl;
------------------------------------------------------------------------------------------------