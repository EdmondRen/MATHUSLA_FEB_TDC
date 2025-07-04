------------------------------------------------------------------------------------------------
-- [Multi-phase TDC Core]
-- Only provide fine time and a trigger output, no internal coarse counter.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiphase_tdc_core is
    generic (
        FINE_BITS   : natural := 4  -- 2^4 = 16 = 8 phases * 2 edges/phase
    );
    port (
        -- [Clocks and reset]
        clk0, clk1, clk2, clk3, clk4, clk5, clk6, clk7 : in std_logic; -- 8-phase clock inputs
        rst_n : in std_logic; -- Reset input

        -- [Signal input]
        hit_signal : in std_logic; -- Hit signal input

        -- TDC Outputs
        -- t1_out      : out unsigned(COARSE_BITS + FINE_BITS - 1 downto 0);
        t1_out      : out std_logic_vector(FINE_BITS - 1 downto 0);
        t1_done     : out std_logic -- Pulse indicating measurement is complete and data is valid
    );
end entity multiphase_tdc_core;

architecture behavioral of multiphase_tdc_core is
    constant FINE_SAMPLERS : positive := 2**FINE_BITS;    

    -- State machine definition
    type tdc_state is (
        S_RESET,         -- Reset internal status
        S_ARMED,         -- Waiting for hit
        S_RESULTS_HOLD   -- Results are valid, t1_done pulsed
    );
    signal current_state, next_state : tdc_state;
    signal clk_main : std_logic; -- Main system clock

    signal hit_signal_extended : std_logic := '0';
    signal hit_b0 : std_logic := '0';
    signal hit_b1 : std_logic_vector(1 downto 0);
    signal hit_b2 : std_logic_vector(3 downto 0);
    signal hit_b3 : std_logic_vector(7 downto 0);    

    -- Internal signals for fine sampling
    -- Stage 1: Direct sampling of hit_signal by each phase edge (potentially metastable)
    signal fine_samples_S : std_logic_vector(FINE_SAMPLERS - 1 downto 0) := (others => '0');
    signal fine_samples_Q : std_logic_vector(FINE_SAMPLERS - 1 downto 0) := (others => '0');
    signal fine_samples_C : std_logic_vector(FINE_SAMPLERS - 1 downto 0) := (others => '0');
    -- Buffered S(0) for trigger decision
    signal fine_samples_Sb1 : std_logic := '0';
    signal fine_samples_Sb2 : std_logic := '0';

    -- Latched results
    signal decoded_fine_time   : std_logic_vector(FINE_BITS - 1 downto 0) := (others => '0');
    signal latched_fine_time   : std_logic_vector(FINE_BITS - 1 downto 0) := (others => '0');
    signal latched_fine_time_buf   : std_logic_vector(FINE_BITS - 1 downto 0) := (others => '0');

    -- Control signals
    signal internal_tdc_done : std_logic := '0';
    signal internal_tdc_done_buf : std_logic;
    signal hit_detected_edge : std_logic;

    -- Array of phase clocks for easier use in generate statement
    type clk_phase_array is array (0 to 7) of std_logic;
    signal clk_phases : clk_phase_array;

    -- Priority Encoder function (thermometer or one-hot to binary)
    -- Finds the index of the first '1' from LSB (index 0).
    -- function encode_fine_pattern (pattern : std_logic_vector(FINE_SAMPLERS -1 downto 0)) return std_logic_vector is
    --     variable fine_val : std_logic_vector(FINE_BITS - 1 downto 0) := (others => '0');
    -- begin
    --     for i in 0 to (FINE_SAMPLERS - 1)  loop
    --         if pattern(i) = '1' then
    --             fine_val := std_logic_vector(to_unsigned(i, FINE_BITS));
    --             exit; -- Found first '1'
    --         end if;
    --     end loop;
    --     return fine_val;
    -- end function encode_fine_pattern;   

    -- attribute ASYNC_REG : string;
    -- attribute ASYNC_REG of hit_signal_extended : signal is "TRUE";      

begin

    -- Assign phase clocks to an array for easier handling in sampler generation
    clk_main <= clk0;
    clk_phases(0) <= clk0;
    clk_phases(1) <= clk1;
    clk_phases(2) <= clk2;
    clk_phases(3) <= clk3;
    clk_phases(4) <= clk4;
    clk_phases(5) <= clk5;
    clk_phases(6) <= clk6;
    clk_phases(7) <= clk7;

    -- [Extend hit signal until conversion is finished] 
    input_capture_process: process(hit_signal, fine_samples_Sb1, fine_samples_Sb2)
    begin
        if fine_samples_Sb1 = '1' and fine_samples_Sb2 = '0' then
            hit_signal_extended <= '0';
        elsif rising_edge(hit_signal) then
            hit_signal_extended <= '1';
        end if;
    end process;    
    
    -- [Use three level routing tree to distribute hit_signal_extended to all fine samplers]
    -- Level 0: Input directly to B0
    b0_gen: entity work.LUT_buf -- Assuming LUT_buf is compiled into 'work'
        port map (
            input  => hit_signal_extended, -- The signal from your original logic
            output => hit_b0
        );        

    -- Level 1: B0 fans out to two B1 buffers
    b1_gen: for i in 0 to 1 generate
    begin
        b1_buffer_inst: entity work.LUT_buf
            port map (
                input  => hit_b0,
                output => hit_b1(i)
            );      
    end generate b1_gen;

    -- Level 2: Each B1 fans out to two B2 buffers
    b2_gen: for i in 0 to 3 generate
        constant b1_index : integer := i / 2; -- Selects which B1 output to connect from
    begin
        b2_buffer_inst: entity work.LUT_buf
            port map (
                input  => hit_b1(b1_index),
                output => hit_b2(i)
            );
    end generate b2_gen;

    -- Level 3: Each B2 fans out to two B3 buffers
    b3_gen: for i in 0 to 7 generate
        constant b2_index : integer := i / 2; -- Selects which B2 output to connect from
    begin
        b3_buffer_inst: entity work.LUT_buf
            port map (
                input  => hit_b2(b2_index),
                output => hit_b3(i)
            );
    end generate b3_gen;    

    -- [S] Stage 1 Fine Samplers: hit signal directly sampled by each of the 16 phase edges
    -- This is where metastability can occur if hit signal changes near a sampling edge.
    -- The subsequent pipeline stages (s2, s3) are for metastability resolution.
    sampler_gen : for i in 0 to (FINE_SAMPLERS / 2) - 1 generate
        -- Rising edge sampler for phase i
        process (clk_phases(i))
        begin
            -- if rst_n = '0' then
            --     fine_samples_S(i) <= '0';
            if rising_edge(clk_phases(i)) then
                fine_samples_S(i) <= hit_b3(i);
            end if;
        end process;

        -- Falling edge sampler for phase i
        process (clk_phases(i))
        begin
            -- if rst_n = '0' then
            --     fine_samples_S(i + 8) <= '0';
            if falling_edge(clk_phases(i)) then
                fine_samples_S(i + 8) <= hit_b3(i);
            end if;
        end process;
    end generate sampler_gen;


    -- [E and Q] Edge detection with register (E signal. combinatorial + Q registered)
    q_detect_gen: for i in 0 to (FINE_SAMPLERS / 2) - 1 generate
        process (clk_phases(i), hit_detected_edge) 
        begin 
            if hit_detected_edge = '1' 
                then fine_samples_Q(i) <= '0'; 
            elsif rising_edge(clk_phases(i)) then 
                if (fine_samples_S((i+1) mod FINE_SAMPLERS) and (not fine_samples_S(i))) = '1' then 
                    fine_samples_Q(i) <= '1'; 
                end if; 
            end if; 
        end process;

        process (clk_phases(i), hit_detected_edge) 
        begin 
            if hit_detected_edge = '1'
                then fine_samples_Q(i+8) <= '0';            
            elsif falling_edge(clk_phases(i)) then 
                if (fine_samples_S((i+8+1) mod FINE_SAMPLERS) and (not fine_samples_S(i+8))) = '1' then 
                    fine_samples_Q(i+8) <= '1'; 
                end if; 
            end if; 
        end process;        
    end generate;       
    

    -- -- Priority encoder, thermal code -> binary (combinatorial)
    -- 2-level logic, 0.5ns less delay
    decode_lut6: entity work.one_hot_to_binary_decoder
        port map (
            one_hot_in  => fine_samples_C, -- The signal from your original logic
            binary_out => decoded_fine_time
        );        


    -- Pipeline stages for fine samples and coarse counter, synchronized to clk_main
    process (clk_main, rst_n)
    begin
        if rst_n = '0' then
            fine_samples_C <= (others => '0');
            latched_fine_time <= (others => '0');            
        elsif rising_edge(clk_main) then
            -- Pipeline the fine samples
            fine_samples_Sb1 <= fine_samples_S(0); -- Sb1 is the first bit of previous fine_samples_S
            fine_samples_Sb2 <= fine_samples_Sb1; -- Sb2 is the buffered Sb1
            fine_samples_C <= fine_samples_Q; -- C is current fine_samples

            -- Hit detection logic (combinatorial, based on pipelined fine samples)
            hit_detected_edge <='0';
            if fine_samples_Sb1 = '1' and fine_samples_Sb2 = '0' then
                hit_detected_edge <= '1';
            end if;  
            internal_tdc_done <= hit_detected_edge;

            -- Readout latching
            if hit_detected_edge = '1' then
                -- latched_fine_time <= encode_fine_pattern(fine_samples_C); 
                latched_fine_time <= decoded_fine_time; 
            end if;              

        end if;
    end process;

    -- output_buf: process (clk_main)
    -- begin
    --     if rising_edge(clk_main) then
    --         latched_fine_time_buf <= latched_fine_time;
    --         internal_tdc_done_buf <= internal_tdc_done;
    --     end if;
    -- end process;   

    -- Output assignments
    t1_out <= latched_fine_time;
    t1_done <= internal_tdc_done;

end architecture behavioral;
