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
import sys
from collections import OrderedDict

BASE_ADDRESS = 0x80000000
KERNEL_OFFSET = 0x00400000
DTB_OFFSET = 0x01400000

def convert_hex_to_mem_init(input_files, output_file):
    memory = OrderedDict()

    for input_file, offset_type in input_files:
        # Determine starting address based on offset type
        # Addresses in memory are relative to BASE_ADDRESS (so 0 means 0x80000000)
        current_address = 0
        if offset_type == 'i':
            current_address = 0
        elif offset_type == 'i2':
            current_address = KERNEL_OFFSET
        elif offset_type == 'i3':
            current_address = DTB_OFFSET
        
        try:
            with open(input_file, 'r') as f_in:
                for line in f_in:
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        # Parse 32-bit hex word
                        val = int(line, 16)
                        
                        # Store as 4 bytes, little-endian
                        for i in range(4):
                            byte_val = (val >> (8 * i)) & 0xFF
                            memory[current_address] = byte_val
                            current_address += 1
                            
                    except ValueError:
                        print(f"Warning: Skipping invalid line in {input_file}: {line}")
                        pass
        except FileNotFoundError:
            print(f"Error: Input file not found at {input_file}")
            sys.exit(1)

    if not memory:
        open(output_file, 'w').close()
        return

    with open(output_file, 'w') as f_out:
        start_addr = min(memory.keys())
        end_addr = max(memory.keys())

        # Align start address to 16-byte boundary
        aligned_start = start_addr & ~15

        for addr in range(aligned_start, end_addr + 16, 16):
            bytes_16 = []
            has_data = False
            for i in range(16):
                byte_addr = addr + i
                byte_val = memory.get(byte_addr, 0x00)
                bytes_16.append(byte_val)
                if byte_addr in memory:
                    has_data = True
            
            if has_data:
                bytes_16.reverse()
                hex_parts = [f"{byte:02X}" for byte in bytes_16]
                data_word = "".join(hex_parts)
                f_out.write(f"{addr:08X} {data_word}\n")

def main():
    parser = argparse.ArgumentParser(
        description="Convert hex files (32-bit words) to a mem_init.txt file for the DDR3 model.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-i", "--input",
        help="Path to the input hex file."
    )
    parser.add_argument(
        "-i2",
        help="Path to the vmlinux hex file."
    )
    parser.add_argument(
        "-i3",
        help="Path to the dtb hex file."
    )
    parser.add_argument(
        "-o", "--output",
        default="mem_init.txt",
        help="Path for the output file."
    )
    args = parser.parse_args()

    input_files = []
    if args.input:
        input_files.append((args.input, 'i'))
    if args.i2:
        input_files.append((args.i2, 'i2'))
    if args.i3:
        input_files.append((args.i3, 'i3'))

    if not input_files:
        print("Error: No input files provided. Use -i, -i2, or -i3.")
        sys.exit(1)

    convert_hex_to_mem_init(input_files, args.output)

if __name__ == "__main__":
    main()
