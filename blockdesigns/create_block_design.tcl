
################################################################
# This is a generated script based on design: system
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2024.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source system_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# tdc_2ch, FIFO_AXI4_Stream_Wrap

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7z010clg400-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name TDCsystem

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:c_counter_binary:12.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:xlslice:1.0\
xilinx.com:ip:axi_fifo_mm_s:4.3\
xilinx.com:ip:fifo_generator:13.2\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:processing_system7:5.5\
xilinx.com:ip:proc_sys_reset:5.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
tdc_2ch\
FIFO_AXI4_Stream_Wrap\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: ZYNQ
proc create_hier_cell_ZYNQ { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ZYNQ() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR

  create_bd_intf_pin -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_GP0


  # Create pins
  create_bd_pin -dir O -type clk FCLK_CLK0
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_reset
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn

  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [list \
    CONFIG.PCW_ACT_APU_PERIPHERAL_FREQMHZ {666.666687} \
    CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.158730} \
    CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {125.000000} \
    CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_TTC0_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_WDT_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_CLK0_FREQ {125000000} \
    CONFIG.PCW_CLK1_FREQ {10000000} \
    CONFIG.PCW_CLK2_FREQ {10000000} \
    CONFIG.PCW_CLK3_FREQ {10000000} \
    CONFIG.PCW_DDR_RAM_HIGHADDR {0x1FFFFFFF} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125} \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
    CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ {533.333374} \
  ] $processing_system7_0


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_pins DDR] [get_bd_intf_pins processing_system7_0/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_pins FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins M_AXI_GP0] [get_bd_intf_pins processing_system7_0/M_AXI_GP0]

  # Create port connections
  connect_bd_net -net PS_FCLK_CLK0  [get_bd_pins processing_system7_0/FCLK_CLK0] \
  [get_bd_pins FCLK_CLK0] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
  [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_0_peripheral_reset  [get_bd_pins proc_sys_reset_0/peripheral_reset] \
  [get_bd_pins peripheral_reset]
  connect_bd_net -net processing_system7_0_FCLK_RESET0_N  [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: hit_in
proc create_hier_cell_hit_in { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_hit_in() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 7 -to 0 exp_p_tri_io
  create_bd_pin -dir O -from 0 -to 0 Dout
  create_bd_pin -dir O -from 0 -to 0 Dout1

  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {1} \
    CONFIG.DIN_TO {1} \
    CONFIG.DIN_WIDTH {8} \
  ] $xlslice_1


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property CONFIG.DIN_WIDTH {8} $xlslice_0


  # Create port connections
  connect_bd_net -net exp_p_tri_io_1  [get_bd_pins exp_p_tri_io] \
  [get_bd_pins xlslice_0/Din] \
  [get_bd_pins xlslice_1/Din]
  connect_bd_net -net xlslice_0_Dout  [get_bd_pins xlslice_0/Dout] \
  [get_bd_pins Dout1]
  connect_bd_net -net xlslice_1_Dout  [get_bd_pins xlslice_1/Dout] \
  [get_bd_pins Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: clock_125M_8phases
proc create_hier_cell_clock_125M_8phases { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_clock_125M_8phases() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -type rst reset
  create_bd_pin -dir O -type clk clk_out1
  create_bd_pin -dir O -type clk clk_out2
  create_bd_pin -dir O -type clk clk_out3
  create_bd_pin -dir O -type clk clk_out4
  create_bd_pin -dir I -type clk clk_in1
  create_bd_pin -dir O -type clk clk_out5
  create_bd_pin -dir O -type clk clk_out6
  create_bd_pin -dir O -type clk clk_out7
  create_bd_pin -dir O -type clk clk_out8

  # Create instance: clk_wiz_1, and set properties
  set clk_wiz_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_1 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_JITTER {79.446} \
    CONFIG.CLKOUT1_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT2_JITTER {79.446} \
    CONFIG.CLKOUT2_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT2_REQUESTED_PHASE {22.5} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {BUFG} \
    CONFIG.CLKOUT3_JITTER {79.446} \
    CONFIG.CLKOUT3_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT3_REQUESTED_PHASE {45} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_DRIVES {BUFG} \
    CONFIG.CLKOUT4_JITTER {79.446} \
    CONFIG.CLKOUT4_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT4_REQUESTED_PHASE {67.5} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_DRIVES {BUFG} \
    CONFIG.CLKOUT6_DRIVES {BUFG} \
    CONFIG.CLKOUT7_DRIVES {BUFG} \
    CONFIG.JITTER_SEL {Min_O_Jitter} \
    CONFIG.MMCM_BANDWIDTH {HIGH} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {6} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {6} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT1_PHASE {22.500} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT2_PHASE {45.000} \
    CONFIG.MMCM_CLKOUT3_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT3_PHASE {67.500} \
    CONFIG.MMCM_COMPENSATION {INTERNAL} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.NUM_OUT_CLKS {4} \
    CONFIG.OVERRIDE_MMCM {true} \
    CONFIG.PRIMITIVE {PLL} \
    CONFIG.PRIM_IN_FREQ {250} \
    CONFIG.USE_LOCKED {false} \
  ] $clk_wiz_1


  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {80.0} \
    CONFIG.CLKOUT1_JITTER {95.013} \
    CONFIG.CLKOUT1_PHASE_ERROR {86.070} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
    CONFIG.JITTER_SEL {Min_O_Jitter} \
    CONFIG.MMCM_BANDWIDTH {HIGH} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {9.500} \
    CONFIG.MMCM_CLKIN1_PERIOD {8.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.750} \
    CONFIG.PRIM_IN_FREQ {125} \
    CONFIG.USE_LOCKED {false} \
  ] $clk_wiz_0


  # Create instance: clk_wiz_2, and set properties
  set clk_wiz_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_2 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_JITTER {79.446} \
    CONFIG.CLKOUT1_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT1_REQUESTED_PHASE {90} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT2_JITTER {79.446} \
    CONFIG.CLKOUT2_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT2_REQUESTED_PHASE {112.5} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {BUFG} \
    CONFIG.CLKOUT3_JITTER {79.446} \
    CONFIG.CLKOUT3_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT3_REQUESTED_PHASE {135} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_DRIVES {BUFG} \
    CONFIG.CLKOUT4_JITTER {79.446} \
    CONFIG.CLKOUT4_PHASE_ERROR {72.667} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT4_REQUESTED_PHASE {157.5} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_DRIVES {BUFG} \
    CONFIG.CLKOUT6_DRIVES {BUFG} \
    CONFIG.CLKOUT7_DRIVES {BUFG} \
    CONFIG.JITTER_SEL {Min_O_Jitter} \
    CONFIG.MMCM_BANDWIDTH {HIGH} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {6} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {6} \
    CONFIG.MMCM_CLKOUT0_PHASE {90.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT1_PHASE {112.500} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT2_PHASE {135.000} \
    CONFIG.MMCM_CLKOUT3_DIVIDE {6} \
    CONFIG.MMCM_CLKOUT3_PHASE {157.500} \
    CONFIG.MMCM_COMPENSATION {INTERNAL} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.NUM_OUT_CLKS {4} \
    CONFIG.OVERRIDE_MMCM {true} \
    CONFIG.PRIMITIVE {PLL} \
    CONFIG.PRIM_IN_FREQ {250} \
    CONFIG.USE_LOCKED {false} \
  ] $clk_wiz_2


  # Create port connections
  connect_bd_net -net clk_wiz_0_clk_out1  [get_bd_pins clk_wiz_0/clk_out1] \
  [get_bd_pins clk_wiz_2/clk_in1] \
  [get_bd_pins clk_wiz_1/clk_in1]
  connect_bd_net -net clk_wiz_1_clk_out1  [get_bd_pins clk_wiz_1/clk_out1] \
  [get_bd_pins clk_out1]
  connect_bd_net -net clk_wiz_1_clk_out2  [get_bd_pins clk_wiz_1/clk_out2] \
  [get_bd_pins clk_out2]
  connect_bd_net -net clk_wiz_1_clk_out3  [get_bd_pins clk_wiz_1/clk_out3] \
  [get_bd_pins clk_out3]
  connect_bd_net -net clk_wiz_1_clk_out4  [get_bd_pins clk_wiz_1/clk_out4] \
  [get_bd_pins clk_out4]
  connect_bd_net -net clk_wiz_2_clk_out1  [get_bd_pins clk_wiz_2/clk_out1] \
  [get_bd_pins clk_out5]
  connect_bd_net -net clk_wiz_2_clk_out2  [get_bd_pins clk_wiz_2/clk_out2] \
  [get_bd_pins clk_out6]
  connect_bd_net -net clk_wiz_2_clk_out3  [get_bd_pins clk_wiz_2/clk_out3] \
  [get_bd_pins clk_out7]
  connect_bd_net -net clk_wiz_2_clk_out4  [get_bd_pins clk_wiz_2/clk_out4] \
  [get_bd_pins clk_out8]
  connect_bd_net -net proc_sys_reset_0_peripheral_reset  [get_bd_pins reset] \
  [get_bd_pins clk_wiz_0/reset] \
  [get_bd_pins clk_wiz_2/reset] \
  [get_bd_pins clk_wiz_1/reset]
  connect_bd_net -net processing_system7_0_FCLK_CLK0  [get_bd_pins clk_in1] \
  [get_bd_pins clk_wiz_0/clk_in1]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: FIFO
proc create_hier_cell_FIFO { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_FIFO() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI


  # Create pins
  create_bd_pin -dir I -type clk S00_ACLK
  create_bd_pin -dir I -type rst S00_ARESETN
  create_bd_pin -dir I -from 63 -to 0 din
  create_bd_pin -dir I wr_en
  create_bd_pin -dir I -type clk wr_clk

  # Create instance: axi_fifo_mm_s_0, and set properties
  set axi_fifo_mm_s_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s:4.3 axi_fifo_mm_s_0 ]
  set_property -dict [list \
    CONFIG.C_AXIS_TUSER_WIDTH {8} \
    CONFIG.C_DATA_INTERFACE_TYPE {1} \
    CONFIG.C_S_AXI4_DATA_WIDTH {64} \
    CONFIG.C_TX_FIFO_PF_THRESHOLD {507} \
    CONFIG.C_USE_RX_CUT_THROUGH {true} \
    CONFIG.C_USE_RX_DATA {1} \
    CONFIG.C_USE_TX_CTRL {0} \
    CONFIG.C_USE_TX_DATA {0} \
  ] $axi_fifo_mm_s_0


  # Create instance: FIFO_AXI4_Stream_Wrap_0, and set properties
  set block_name FIFO_AXI4_Stream_Wrap
  set block_cell_name FIFO_AXI4_Stream_Wrap_0
  if { [catch {set FIFO_AXI4_Stream_Wrap_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $FIFO_AXI4_Stream_Wrap_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  set_property -dict [ list \
   CONFIG.FREQ_HZ {125000000} \
 ] [get_bd_intf_pins /FIFO/FIFO_AXI4_Stream_Wrap_0/m_axis]

  # Create instance: fifo_generator_0, and set properties
  set fifo_generator_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:fifo_generator:13.2 fifo_generator_0 ]
  set_property -dict [list \
    CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
    CONFIG.Input_Data_Width {64} \
    CONFIG.Input_Depth {512} \
    CONFIG.Reset_Pin {false} \
  ] $fifo_generator_0


  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net FIFO_AXI4_Stream_Wrap_0_m_axis [get_bd_intf_pins FIFO_AXI4_Stream_Wrap_0/m_axis] [get_bd_intf_pins axi_fifo_mm_s_0/AXI_STR_RXD]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_fifo_mm_s_0/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_fifo_mm_s_0/S_AXI_FULL]
  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins S00_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

  # Create port connections
  connect_bd_net -net FIFO_AXI4_Stream_Wrap_0_fifo_read_enable  [get_bd_pins FIFO_AXI4_Stream_Wrap_0/fifo_read_enable] \
  [get_bd_pins fifo_generator_0/rd_en]
  connect_bd_net -net fifo_generator_0_dout  [get_bd_pins fifo_generator_0/dout] \
  [get_bd_pins FIFO_AXI4_Stream_Wrap_0/fifo_read_data]
  connect_bd_net -net fifo_generator_0_empty  [get_bd_pins fifo_generator_0/empty] \
  [get_bd_pins FIFO_AXI4_Stream_Wrap_0/fifo_empty]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins S00_ARESETN] \
  [get_bd_pins axi_interconnect_0/S00_ARESETN] \
  [get_bd_pins axi_interconnect_0/M00_ARESETN] \
  [get_bd_pins axi_interconnect_0/ARESETN] \
  [get_bd_pins axi_interconnect_0/M01_ARESETN] \
  [get_bd_pins axi_fifo_mm_s_0/s_axi_aresetn]
  connect_bd_net -net processing_system7_0_FCLK_CLK0  [get_bd_pins S00_ACLK] \
  [get_bd_pins axi_interconnect_0/S00_ACLK] \
  [get_bd_pins axi_interconnect_0/M00_ACLK] \
  [get_bd_pins axi_interconnect_0/ACLK] \
  [get_bd_pins axi_interconnect_0/M01_ACLK] \
  [get_bd_pins FIFO_AXI4_Stream_Wrap_0/fifo_rd_clk] \
  [get_bd_pins axi_fifo_mm_s_0/s_axi_aclk] \
  [get_bd_pins fifo_generator_0/rd_clk]
  connect_bd_net -net tdc_2ch_0_dout  [get_bd_pins din] \
  [get_bd_pins fifo_generator_0/din]
  connect_bd_net -net tdc_2ch_0_dout_valid  [get_bd_pins wr_en] \
  [get_bd_pins fifo_generator_0/wr_en]
  connect_bd_net -net wr_clk_1  [get_bd_pins wr_clk] \
  [get_bd_pins fifo_generator_0/wr_clk]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]

  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]


  # Create ports
  set exp_p_tri_io [ create_bd_port -dir I -from 7 -to 0 exp_p_tri_io ]
  set led_o [ create_bd_port -dir O -from 0 -to 0 led_o ]
  set exp_n_tri_io [ create_bd_port -dir O -from 7 -to 0 exp_n_tri_io ]

  # Create instance: FIFO
  create_hier_cell_FIFO [current_bd_instance .] FIFO

  # Create instance: c_counter_binary_0, and set properties
  set c_counter_binary_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_counter_binary:12.0 c_counter_binary_0 ]
  set_property CONFIG.Output_Width {26} $c_counter_binary_0


  # Create instance: clock_125M_8phases
  create_hier_cell_clock_125M_8phases [current_bd_instance .] clock_125M_8phases

  # Create instance: hit_in
  create_hier_cell_hit_in [current_bd_instance .] hit_in

  # Create instance: tdc_2ch_0, and set properties
  set block_name tdc_2ch
  set block_cell_name tdc_2ch_0
  if { [catch {set tdc_2ch_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $tdc_2ch_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property CONFIG.NUM_PORTS {8} $xlconcat_0


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {25} \
    CONFIG.DIN_TO {25} \
    CONFIG.DIN_WIDTH {26} \
  ] $xlslice_0


  # Create instance: ZYNQ
  create_hier_cell_ZYNQ [current_bd_instance .] ZYNQ

  # Create interface connections
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins ZYNQ/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins ZYNQ/FIXED_IO]
  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins ZYNQ/M_AXI_GP0] [get_bd_intf_pins FIFO/S00_AXI]

  # Create port connections
  connect_bd_net -net PS_FCLK_CLK0  [get_bd_pins ZYNQ/FCLK_CLK0] \
  [get_bd_pins FIFO/S00_ACLK] \
  [get_bd_pins clock_125M_8phases/clk_in1] \
  [get_bd_pins c_counter_binary_0/CLK]
  connect_bd_net -net c_counter_binary_0_Q  [get_bd_pins c_counter_binary_0/Q] \
  [get_bd_pins xlslice_0/Din]
  connect_bd_net -net clk_wiz_1_clk_out1  [get_bd_pins clock_125M_8phases/clk_out1] \
  [get_bd_pins tdc_2ch_0/clk0] \
  [get_bd_pins FIFO/wr_clk]
  connect_bd_net -net clk_wiz_1_clk_out2  [get_bd_pins clock_125M_8phases/clk_out2] \
  [get_bd_pins tdc_2ch_0/clk1]
  connect_bd_net -net clk_wiz_1_clk_out3  [get_bd_pins clock_125M_8phases/clk_out3] \
  [get_bd_pins tdc_2ch_0/clk2]
  connect_bd_net -net clk_wiz_1_clk_out4  [get_bd_pins clock_125M_8phases/clk_out4] \
  [get_bd_pins tdc_2ch_0/clk3]
  connect_bd_net -net clk_wiz_2_clk_out1  [get_bd_pins clock_125M_8phases/clk_out5] \
  [get_bd_pins tdc_2ch_0/clk4]
  connect_bd_net -net clk_wiz_2_clk_out2  [get_bd_pins clock_125M_8phases/clk_out6] \
  [get_bd_pins tdc_2ch_0/clk5]
  connect_bd_net -net clk_wiz_2_clk_out3  [get_bd_pins clock_125M_8phases/clk_out7] \
  [get_bd_pins tdc_2ch_0/clk6]
  connect_bd_net -net clk_wiz_2_clk_out4  [get_bd_pins clock_125M_8phases/clk_out8] \
  [get_bd_pins tdc_2ch_0/clk7]
  connect_bd_net -net exp_p_tri_io_1  [get_bd_ports exp_p_tri_io] \
  [get_bd_pins hit_in/exp_p_tri_io]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins ZYNQ/peripheral_aresetn] \
  [get_bd_pins tdc_2ch_0/rst_n] \
  [get_bd_pins FIFO/S00_ARESETN]
  connect_bd_net -net proc_sys_reset_0_peripheral_reset  [get_bd_pins ZYNQ/peripheral_reset] \
  [get_bd_pins clock_125M_8phases/reset]
  connect_bd_net -net tdc_2ch_0_dout  [get_bd_pins tdc_2ch_0/dout] \
  [get_bd_pins FIFO/din]
  connect_bd_net -net tdc_2ch_0_hit_1_out  [get_bd_pins tdc_2ch_0/hit_1_out] \
  [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net tdc_2ch_0_hit_2_out  [get_bd_pins tdc_2ch_0/hit_2_out] \
  [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net tdc_2ch_0_trigger_decision_out  [get_bd_pins tdc_2ch_0/trigger_decision_out] \
  [get_bd_pins xlconcat_0/In5]
  connect_bd_net -net wr_en_1  [get_bd_pins tdc_2ch_0/dout_valid] \
  [get_bd_pins FIFO/wr_en]
  connect_bd_net -net xlconcat_0_dout  [get_bd_pins xlconcat_0/dout] \
  [get_bd_ports exp_n_tri_io]
  connect_bd_net -net xlconstant_0_dout  [get_bd_pins xlconstant_0/dout] \
  [get_bd_pins tdc_2ch_0/overflow_count_rstn]
  connect_bd_net -net xlslice_0_Dout  [get_bd_pins hit_in/Dout1] \
  [get_bd_pins tdc_2ch_0/hit_1]
  connect_bd_net -net xlslice_0_Dout1  [get_bd_pins xlslice_0/Dout] \
  [get_bd_ports led_o]
  connect_bd_net -net xlslice_1_Dout  [get_bd_pins hit_in/Dout] \
  [get_bd_pins tdc_2ch_0/hit_2]

  # Create address segments
  assign_bd_address -offset 0x43C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces ZYNQ/processing_system7_0/Data] [get_bd_addr_segs FIFO/axi_fifo_mm_s_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x43C10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces ZYNQ/processing_system7_0/Data] [get_bd_addr_segs FIFO/axi_fifo_mm_s_0/S_AXI_FULL/Mem1] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


