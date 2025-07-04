# Multi-channel TDC with Coincidence Trigger

This repository implements a Time-to-Digital Converter (TDC) with a coincidence trigger, designed for media-level resolution (~0.1ns rms) time measurements in multi-channel systems. The TDC leverages a multi-phase clock sampling architecture to achieve sub-nanosecond resolution, making it suitable for physics experiments, time-of-flight measurements, and other applications requiring precise timing. The multi-phase clock sampling method is less prone to temperature variation compared to the delay line method, and can achieve better INL without calibration.

## Features
- Multi-channel TDC 
    - 16-phase, 250 MHz clock sampling (8 phases separated by 22.5°, using both rising and falling edges)
    - Time resolution: 0.1 ns rms, 0.25 ns LSB
    - DNL: +/- 0.3 LSB
    - INL: +/- 0.5 LSB
    - Measurement range: XX.XX ms
    - Dead time: ~12 ns
    - Max speed: ~70 MS/s    
- Trigger logic  
    - Selectable between single channel, two-channel coincidence, two-channel coincidence with energy veto
- Designed for FPGA implementation (tested on Redpitaya STEMlab 125-10)
- Automated bitstream upload script for rapid development



## Instructions

A Redpitaya STEMlab 125-10 board with ZYNQ xc7z010clg400-1 FPGA is used for testing.
The TDC core algorithm can be adapted to any FPGA.

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd <repo-folder>
   ```
2. **Install Vivado:**
   - Recommended Vivado version: 2024.2
   - Ensure Vivado is in your system PATH.
3. **Set up Redpitaya:**
   - Connect the Redpitaya STEMlab 125-10 to your network.
   - Note its IP address for SSH access.
4. **Create vivado project**
    - Method one: open Vivado GUI, and use the Tcl Console to navigate to the "zynq_tdc/" folder and execute "source create_project.tcl"
    - Method two: in terminal, navigate to the current folder and run `vivado -mode tcl -source create_project.tcl`
    - Run synthesis & implementation steps
    - Generate bitstream

### Bitstream Upload
A bash script is provided to upload the bitstream to the board via SSH.

1. Add the content of `utils/upload_bit.sh` to your `.bashrc` (Change the IP address to the board you have):
   ```bash
   cat utils/upload_bit.sh >> ~/.bashrc
   ```
2. In the Vivado project folder, run:
   ```bash
   bit_load
   ```
   This will upload the generated bitstream to the Redpitaya for testing.

## Usage
- After uploading the bitstream, the TDC will operate according to the implemented logic.
- Connect your input signals to the appropriate Redpitaya inputs.
- Data acquisition and further processing can be implemented as needed (see source code for details).

## Directory Structure
- `src/`           – HDL source files for the TDC and trigger logic
- `utils/`         – Utility scripts (e.g., bitstream upload)
- `README.md`      – Project documentation
- `vivado_project/`– Vivado project files (if present)


## Contact
For questions or support, please contact runzeren2023 at u.northwestern.edu. 