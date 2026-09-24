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

import argparse 
import os

COE_HEADER = 'memory_initialization_radix = 16;\n' + \
             'memory_initialization_vector =\n'

parser = argparse.ArgumentParser(description='Parse objcopy verilog outputs and convert them into Vivado block mem initialization (.coe) files')

parser.add_argument('--iaddr' , '-i', default=0x10000, help='start address of the instruction memory')
parser.add_argument('--daddr' , '-d', default=0x40000000, help='start address of the data memory')
parser.add_argument('--vhfile' , '-vh', default='coremark_baremetal.vh', help='specify verilog header file that is obtained by gcc objcopy')

args = parser.parse_args()
imem_base_addr = args.iaddr
dmem_base_addr = args.daddr
vhFile = args.vhfile

print('Args:',args)

# read and parse the vh file
f = open(vhFile)
prev_addr = imem_base_addr
curr_addr = imem_base_addr
parsing_imem = False
parsing_dmem = False
coe_buffer = ""
for line in f.readlines():
    if line.startswith('@'): # this is an address
        address = int(line[1:], base=16)
        print('Found address:', address)
        if not parsing_imem and not parsing_dmem:
            prev_addr = address
            curr_addr = address
            if address == imem_base_addr:
                parsing_imem = True
        # assuming imem always comes before dmem in address space
        elif address == dmem_base_addr:
            imem_coe_file = open('imem.coe','w')
            imem_coe_file.write(COE_HEADER)
            # discard the last comma and newline characters
            imem_coe_file.write(coe_buffer[:-2] + ';')
            prev_addr = address
            curr_addr = address
            coe_buffer = ""
            parsing_imem = False
            parsing_dmem = True
        else:
            if address - curr_addr > 0:
                print('Found empty memory address range between', curr_addr, 'and', address, '\nFilling with zeros...')
                for i in range (int((address - curr_addr) / 4)):
                    coe_buffer += "00000000,\n"
                curr_addr = address

    else: # assuming this has to be data
        bytes = line.split()
        no_bytes = len(bytes)
        for i in range(int(len(bytes)/4)):
            arr = bytes[i*4:i*4+4]
            arr.reverse()
            coe_buffer += ''.join(arr) + ',\n'
            no_bytes -= 4
            curr_addr += 4
        if no_bytes > 0:
            curr_addr += no_bytes
            arr = bytes[-no_bytes:] + ['00']*(4-no_bytes)
            arr.reverse()
            coe_buffer += ''.join(arr) + ',\n'

dmem_coe_file = open(vhFile[:-3] + '_dmem.coe','w')
dmem_coe_file.write(COE_HEADER)
# discard the last comma and newline characters
dmem_coe_file.write(coe_buffer[:-2] + ';')

