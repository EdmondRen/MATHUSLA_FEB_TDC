# Set project variables
set proj_name "TDCsystem"
set proj_dir "./vivado_project"
set project_target_language VHDL
set part "xc7z010clg400-1"

# List board files
set_param board.repoPaths [list redpitaya/board]

# Create project
create_project $proj_name $proj_dir -part $part
set_property BOARD_PART redpitaya.com:redpitaya:part0:1.1 [current_project]
set_property target_language $project_target_language [current_project]


# Add HDL source files
add_files [glob ./src/*.vhd]
add_files [glob ./src/AXI/*.vhd]
add_files [glob ./src/Trigger/*.vhd]
add_files [glob ./src/TDCCore/*.vhd]

# Add simulation files
add_files -fileset sim_1 [glob ./sim/*.vhd]

# Add constraint files
add_files -fileset constrs_1 [glob ./constraints/*.xdc]
add_files -fileset constrs_1 [glob ./redpitaya/board/*.xdc]


# Create and validate Block Design from exported .tcl file
source ./blockdesigns/create_block_design.tcl
validate_bd_design

# Create HDL wrapper and add it to the fileset
make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/$proj_name/$proj_name.bd] -top
add_files -norecurse $proj_dir/$proj_name.srcs/sources_1/bd/$proj_name/hdl/${proj_name}_wrapper.vhd


# Set top module (replace with your actual top entity if needed)
set_property top ${proj_name}_wrapper [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

puts "Project created and all files added."
