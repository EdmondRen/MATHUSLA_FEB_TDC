create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

set_input_delay -max 3.400 -clock adc_clk [get_ports adc_dat_a_i[*]]
set_input_delay -max 3.400 -clock adc_clk [get_ports adc_dat_b_i[*]]

create_clock -period 4.000 -name rx_clk [get_ports daisy_p_i[1]]

# ZYNQ clock, 125 MHz
#create_clock  -period 8.0 -name clk_fpga_0 [get_nets bd_TDCAXIFULL_ext_v2_i/ZYNQ_FCLK_CLK0]


set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks adc_clk]
set_false_path -from [get_clocks adc_clk] -to [get_clocks clk_fpga_0]
