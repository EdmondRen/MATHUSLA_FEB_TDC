
## False path
# hit signal
set_false_path -from [get_cells -hierarchical *hit_signal*]
set_false_path -from [get_cells -hierarchical *hit_signal_extended_reg*]
# reset signal
set_false_path -from [get_ports system_i/tdc_2ch_0/U0/tdc1/rst_n]
set_false_path -from [get_ports system_i/tdc_2ch_0/U0/tdc2/rst_n]
#  input signal
set_false_path -from [get_pins -hierarchical *hit_detected_edge_reg/C] -to [get_pins -hierarchical *fine_samples_Q_reg*/CLR]

## TDC1
# Bus skew constraint for the LUT buffer tree
set_bus_skew 0.1 -from [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/hit_signal_extended_reg/C"}] -to [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_S_reg[*]/D"}]

# Bus skew for Alignment of 16 phases after the sampler
set_bus_skew -from [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_S_reg[*]/C"}] -to [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_Q_reg[*]/D"}] 0.150
# Together with max delay 
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_S_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_Q_reg[*]"}] 2 -datapath_only
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_Q_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_C_reg[*]"}] 2 -datapath_only
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*fine_samples_C_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*latched_fine_time_reg[*]"}] 1

## TDC2
# Bus skew constraint for the LUT buffer tree
set_bus_skew 0.15 -from [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/hit_signal_extended_reg/C"}] -to [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_Q_reg[*]/D"}]

# Bus skew for Alignment of 16 phases after the sampler
set_bus_skew -from [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_S_reg[*]/C"}] -to [get_pins -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_Q_reg[*]/D"}] 0.150
# Together with max delay 
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_S_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_Q_reg[*]"}] 2 -datapath_only
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_Q_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_C_reg[*]"}] 2 -datapath_only
set_max_delay -from [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*fine_samples_C_reg[*]"}] -to [get_cells -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*latched_fine_time_reg[*]"}] 1


## Place the remaining logic in the nearby Pblock
create_pblock Pblock_TDC0
set_property IS_SOFT FALSE [get_pblocks Pblock_TDC0]
resize_pblock [get_pblocks Pblock_TDC0] -add {SLICE_X34Y51:SLICE_X43Y65}
add_cells_to_pblock [get_pblocks Pblock_TDC0] [get_cells -quiet -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc1/*"}] 
add_cells_to_pblock [get_pblocks Pblock_TDC0] [get_cells -quiet -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/tdc2/*"}] 


create_pblock Pblock_TDC0_out
set_property IS_SOFT FALSE [get_pblocks Pblock_TDC0_out]
resize_pblock [get_pblocks Pblock_TDC0_out] -add {SLICE_X28Y51:SLICE_X33Y65}
add_cells_to_pblock [get_pblocks Pblock_TDC0_out] [get_cells -quiet -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/fast_data_builder_inst/*"}] 
add_cells_to_pblock [get_pblocks Pblock_TDC0_out] [get_cells -quiet -hierarchical -filter {NAME =~ "system_i/tdc_2ch_0/U0/trigger/*"}] 

set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[0].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y51 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[0].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[0].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y52 [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[0].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[1].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y53 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[1].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b1_gen[0].b1_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y54 [get_cells system_i/tdc_2ch_0/U0/tdc1/b1_gen[0].b1_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[2].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y55 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[2].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[1].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y56 [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[1].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[3].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y57 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[3].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b0_gen/lut1_i]
set_property LOC SLICE_X38Y58 [get_cells system_i/tdc_2ch_0/U0/tdc1/b0_gen/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[4].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y59 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[4].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[2].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y60 [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[2].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[5].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y61 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[5].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b1_gen[1].b1_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y62 [get_cells system_i/tdc_2ch_0/U0/tdc1/b1_gen[1].b1_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[6].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y63 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[6].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[3].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y64 [get_cells system_i/tdc_2ch_0/U0/tdc1/b2_gen[3].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[7].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X38Y65 [get_cells system_i/tdc_2ch_0/U0/tdc1/b3_gen[7].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[0].fine_samples_S_reg[0]]
set_property LOC SLICE_X36Y51 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[0].fine_samples_S_reg[0]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[0].fine_samples_S_reg[8]]
set_property LOC SLICE_X37Y51 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[0].fine_samples_S_reg[8]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[1].fine_samples_S_reg[1]]
set_property LOC SLICE_X36Y53 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[1].fine_samples_S_reg[1]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[1].fine_samples_S_reg[9]]
set_property LOC SLICE_X37Y53 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[1].fine_samples_S_reg[9]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[2].fine_samples_S_reg[2]]
set_property LOC SLICE_X36Y55 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[2].fine_samples_S_reg[2]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[2].fine_samples_S_reg[10]]
set_property LOC SLICE_X37Y55 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[2].fine_samples_S_reg[10]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[3].fine_samples_S_reg[3]]
set_property LOC SLICE_X36Y57 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[3].fine_samples_S_reg[3]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[3].fine_samples_S_reg[11]]
set_property LOC SLICE_X37Y57 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[3].fine_samples_S_reg[11]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[4].fine_samples_S_reg[4]]
set_property LOC SLICE_X36Y59 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[4].fine_samples_S_reg[4]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[4].fine_samples_S_reg[12]]
set_property LOC SLICE_X37Y59 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[4].fine_samples_S_reg[12]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[5].fine_samples_S_reg[5]]
set_property LOC SLICE_X36Y61 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[5].fine_samples_S_reg[5]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[5].fine_samples_S_reg[13]]
set_property LOC SLICE_X37Y61 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[5].fine_samples_S_reg[13]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[6].fine_samples_S_reg[6]]
set_property LOC SLICE_X36Y63 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[6].fine_samples_S_reg[6]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[6].fine_samples_S_reg[14]]
set_property LOC SLICE_X37Y63 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[6].fine_samples_S_reg[14]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[7].fine_samples_S_reg[7]]
set_property LOC SLICE_X36Y65 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[7].fine_samples_S_reg[7]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[7].fine_samples_S_reg[15]]
set_property LOC SLICE_X37Y65 [get_cells system_i/tdc_2ch_0/U0/tdc1/sampler_gen[7].fine_samples_S_reg[15]]


set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[0].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y51 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[0].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[0].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y52 [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[0].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[1].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y53 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[1].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b1_gen[0].b1_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y54 [get_cells system_i/tdc_2ch_0/U0/tdc2/b1_gen[0].b1_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[2].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y55 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[2].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[1].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y56 [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[1].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[3].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y57 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[3].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b0_gen/lut1_i]
set_property LOC SLICE_X42Y58 [get_cells system_i/tdc_2ch_0/U0/tdc2/b0_gen/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[4].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y59 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[4].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[2].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y60 [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[2].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[5].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y61 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[5].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b1_gen[1].b1_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y62 [get_cells system_i/tdc_2ch_0/U0/tdc2/b1_gen[1].b1_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[6].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y63 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[6].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[3].b2_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y64 [get_cells system_i/tdc_2ch_0/U0/tdc2/b2_gen[3].b2_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[7].b3_buffer_inst/lut1_i]
set_property LOC SLICE_X42Y65 [get_cells system_i/tdc_2ch_0/U0/tdc2/b3_gen[7].b3_buffer_inst/lut1_i]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[0].fine_samples_S_reg[0]]
set_property LOC SLICE_X40Y51 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[0].fine_samples_S_reg[0]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[0].fine_samples_S_reg[8]]
set_property LOC SLICE_X41Y51 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[0].fine_samples_S_reg[8]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[1].fine_samples_S_reg[1]]
set_property LOC SLICE_X40Y53 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[1].fine_samples_S_reg[1]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[1].fine_samples_S_reg[9]]
set_property LOC SLICE_X41Y53 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[1].fine_samples_S_reg[9]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[2].fine_samples_S_reg[2]]
set_property LOC SLICE_X40Y55 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[2].fine_samples_S_reg[2]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[2].fine_samples_S_reg[10]]
set_property LOC SLICE_X41Y55 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[2].fine_samples_S_reg[10]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[3].fine_samples_S_reg[3]]
set_property LOC SLICE_X40Y57 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[3].fine_samples_S_reg[3]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[3].fine_samples_S_reg[11]]
set_property LOC SLICE_X41Y57 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[3].fine_samples_S_reg[11]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[4].fine_samples_S_reg[4]]
set_property LOC SLICE_X40Y59 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[4].fine_samples_S_reg[4]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[4].fine_samples_S_reg[12]]
set_property LOC SLICE_X41Y59 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[4].fine_samples_S_reg[12]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[5].fine_samples_S_reg[5]]
set_property LOC SLICE_X40Y61 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[5].fine_samples_S_reg[5]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[5].fine_samples_S_reg[13]]
set_property LOC SLICE_X41Y61 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[5].fine_samples_S_reg[13]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[6].fine_samples_S_reg[6]]
set_property LOC SLICE_X40Y63 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[6].fine_samples_S_reg[6]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[6].fine_samples_S_reg[14]]
set_property LOC SLICE_X41Y63 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[6].fine_samples_S_reg[14]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[7].fine_samples_S_reg[7]]
set_property LOC SLICE_X40Y65 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[7].fine_samples_S_reg[7]]
set_property DONT_TOUCH TRUE [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[7].fine_samples_S_reg[15]]
set_property LOC SLICE_X41Y65 [get_cells system_i/tdc_2ch_0/U0/tdc2/sampler_gen[7].fine_samples_S_reg[15]]


