# This file is part of https://github.com/celuk/secure-soc
# Copyright (C) 2025  Seyyid Hikmet Celik
#                     seyyid4091@gmail.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

## basys3.xdc

# CLOCK
set_property PACKAGE_PIN W5 [get_ports clk_i]
	set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
	create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk_i]

# RESET
set_property PACKAGE_PIN V17 [get_ports rst_ni]
	set_property IOSTANDARD LVCMOS33 [get_ports rst_ni]

# PROGRAMMING LED
set_property PACKAGE_PIN U16 [get_ports prog_mode_led_o]
	set_property IOSTANDARD LVCMOS33 [get_ports prog_mode_led_o]

# PROGRAMMING UART
#set_property PACKAGE_PIN K17 [get_ports program_rx_i]
#	set_property IOSTANDARD LVCMOS33 [get_ports program_rx_i]

# UART
set_property PACKAGE_PIN B18 [get_ports program_rx_i]
	set_property IOSTANDARD LVCMOS33 [get_ports program_rx_i]
set_property PACKAGE_PIN A18 [get_ports uart_tx_o]
	set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_o]

# QSPI
##Note that CCLK_0 cannot be placed in 7 series devices. You can access it using the
##STARTUPE2 primitive.
## ifdef BASYS3
set_property PACKAGE_PIN D18 [get_ports {qspi_data_io[0]}]				
	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[0]}]
set_property PACKAGE_PIN D19 [get_ports {qspi_data_io[1]}]				
	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[1]}]
set_property PACKAGE_PIN G18 [get_ports {qspi_data_io[2]}]				
	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[2]}]
set_property PACKAGE_PIN F18 [get_ports {qspi_data_io[3]}]				
	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[3]}]
set_property PACKAGE_PIN K19 [get_ports qspi_cs_n_o]					
	set_property IOSTANDARD LVCMOS33 [get_ports qspi_cs_n_o]

## ifdef EXT_FLASH 
#set_property PACKAGE_PIN K17 [get_ports qspi_sck_o]
#	set_property IOSTANDARD LVCMOS33 [get_ports qspi_sck_o]
#set_property PACKAGE_PIN M18 [get_ports qspi_cs_n_o]
#	set_property IOSTANDARD LVCMOS33 [get_ports qspi_cs_n_o]
#set_property PACKAGE_PIN L17 [get_ports {qspi_data_io[0]}]
#	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[0]}]
#set_property PACKAGE_PIN M19 [get_ports {qspi_data_io[1]}]
#	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[1]}]
#set_property PACKAGE_PIN P17 [get_ports {qspi_data_io[2]}]
#	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[2]}]
#set_property PACKAGE_PIN R18 [get_ports {qspi_data_io[3]}]
#	set_property IOSTANDARD LVCMOS33 [get_ports {qspi_data_io[3]}]
