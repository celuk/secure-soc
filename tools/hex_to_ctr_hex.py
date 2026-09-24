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

# Default Key
DEFAULT_KEY = 0xDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210
CONST_VAL = 0x9E3779B9

def ror(val, r, width=256):
    return ((val >> r) | (val << (width - r))) & ((1 << width) - 1)

def rol(val, r, width=256):
    return ((val << r) | (val >> (width - r))) & ((1 << width) - 1)

def ctr_keystream_generator(key, row_number):
    MASK_256 = (1 << 256) - 1
    MASK_32 = 0xFFFFFFFF
    
    # assign temp_0 = key ^ {8{row_number}};
    row_repeated = 0
    for i in range(8):
        row_repeated |= (row_number << (32 * i))
    
    temp_0 = key ^ row_repeated
    
    # assign temp_1 = temp_0 ^ (temp_0 << 13) ^ (temp_0 >> 17);
    # Verilog shift semantics: << pads with 0, >> pads with 0
    t0_shl_13 = (temp_0 << 13) & MASK_256
    t0_shr_17 = (temp_0 >> 17)
    temp_1 = temp_0 ^ t0_shl_13 ^ t0_shr_17
    
    # assign temp_2 = temp_1 + {8{32'h9E3779B9}};
    const_repeated = 0
    for i in range(8):
        const_repeated |= (CONST_VAL << (32 * i))
    
    temp_2 = (temp_1 + const_repeated) & MASK_256
    
    # assign temp_3 = temp_2 ^ (temp_2 << 7) ^ (temp_2 >> 12);
    t2_shl_7 = (temp_2 << 7) & MASK_256
    t2_shr_12 = (temp_2 >> 12)
    temp_3 = temp_2 ^ t2_shl_7 ^ t2_shr_12
    
    # assign keystream = temp_3[255:224] ^ ... ^ temp_3[31:0];
    keystream = 0
    for i in range(8):
        chunk = (temp_3 >> (32 * i)) & MASK_32
        keystream ^= chunk
        
    return keystream

def process_file(input_file, output_file, key=DEFAULT_KEY, start_row=0x80000000):
    try:
        with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
            row = start_row
            for line in f_in:
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data_in = int(line, 16)
                    keystream = ctr_keystream_generator(key, row)
                    data_out = data_in ^ keystream
                    
                    f_out.write(f"{data_out:08x}\n")
                    
                    row += 4
                except ValueError:
                    print(f"Skipping invalid line: {line}")

                    
    except FileNotFoundError:
        print(f"Error: Input file {input_file} not found.")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Encrypt hex file using CTR keystream generator algorithm."
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Path to the input hex file."
    )
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Path for the output hex file."
    )
    parser.add_argument(
        "--key",
        default=hex(DEFAULT_KEY),
        help="256-bit Key in hex format (default: DEADBEEF...)"
    )
    parser.add_argument(
        "--start-row",
        type=lambda x: int(x, 0),
        default=0x80000000,
        help="Starting row number (default: 0x80000000). Increments by 4 for each line."
    )
    
    args = parser.parse_args()
    
    try:
        key_val = int(args.key, 16)
    except ValueError:
        print("Error: Invalid key format.")
        sys.exit(1)

    process_file(args.input, args.output, key_val, args.start_row)

if __name__ == "__main__":
    main()
