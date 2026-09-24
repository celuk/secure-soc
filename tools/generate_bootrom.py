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

#ADDR_WIDTH = 14

def generate_bootrom(hex_file):
    with open(hex_file, 'r') as f:
        lines = f.readlines()

    #print(f"`define ADDR_WIDTH {ADDR_WIDTH}\n")
    print("module bootrom (")
    print("   input logic [31:0] addr_i,")
    print("   output logic [31:0] rdata_o")
    print(");\n")
    print("always_comb begin")
    print("   case (addr_i)")

    for i, line in enumerate(lines):
        line = line.strip()
        if line:
            print(f"      {i}:    rdata_o = 32'h{line};")

    print(f"      default: rdata_o = 32'h00000000;")
    print("   endcase")
    print("end")
    print("endmodule\n")

parser = argparse.ArgumentParser(description='Generate bootrom from hex file.')
parser.add_argument('--file', '-f', type=str, help='The input hex file')
parser.add_argument('--addr_width', '-aw', type=int, help='Address width')

args = parser.parse_args()

ADDR_WIDTH = args.addr_width

generate_bootrom(args.file)
