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

DEFAULT_KEY = 0xDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210
CONST_VAL = 0x9E3779B9
DEFAULT_BASE_ADDR = 0x80000000

def ctr_keystream_generator(key, row_number):
    MASK_256 = (1 << 256) - 1
    MASK_32 = 0xFFFFFFFF
    
    # assign temp_0 = key ^ {8{row_number}};
    row_repeated = 0
    for i in range(8):
        row_repeated |= (row_number << (32 * i))
    
    temp_0 = key ^ row_repeated
    
    # assign temp_1 = temp_0 ^ (temp_0 << 13) ^ (temp_0 >> 17);
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

def process_file(input_file, output_file, key, base_addr):
    try:
        with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
            for line in f_in:
                line = line.strip()
                if not line:
                    continue
                
                parts = line.split()
                if len(parts) != 2:
                    print(f"Skipping invalid line: {line}")
                    continue
                
                addr_str, data_str = parts
                
                try:
                    file_addr = int(addr_str, 16)
                    
                    if len(data_str) != 32:
                         # Padding if necessary, though format expects 32 hex chars
                         data_str = data_str.zfill(32)

                    # Split hex string into 4 chunks of 8 characters (32-bit words)
                    # data_str is e.g. "MSW...LSW"
                    chunks_hex = [data_str[i:i+8] for i in range(0, 32, 8)]
                    
                    encrypted_chunks = []
                    for i, chunk_hex in enumerate(chunks_hex):
                        # Corresponding offsets: 
                        # i=0 (Leftmost 8 chars) -> Offset 12 (Word 3)
                        # i=1 -> Offset 8 (Word 2)
                        # i=2 -> Offset 4 (Word 1)
                        # i=3 (Rightmost 8 chars) -> Offset 0 (Word 0)
                        offset = (3 - i) * 4
                        
                        word = int(chunk_hex, 16)
                        enc_addr = (file_addr + offset + base_addr) & 0xFFFFFFFF
                        
                        keystream = ctr_keystream_generator(key, enc_addr)
                        enc_word = word ^ keystream
                        
                        encrypted_chunks.append(f"{enc_word:08X}")
                    
                    encrypted_data_str = "".join(encrypted_chunks)
                    
                    f_out.write(f"{addr_str} {encrypted_data_str}\n")
                    
                except ValueError:
                    print(f"Skipping invalid numbers in line: {line}")
                    
    except FileNotFoundError:
        print(f"Error: Input file {input_file} not found.")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Encrypt mem_init hex file (Addr Data128) using CTR keystream generator algorithm."
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Path to the input mem_init file."
    )
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Path for the output mem_init file."
    )
    parser.add_argument(
        "--key",
        default=hex(DEFAULT_KEY),
        help="256-bit Key in hex format (default: DEADBEEF...)"
    )
    parser.add_argument(
        "--base-addr",
        default=hex(DEFAULT_BASE_ADDR),
        help="Base address to add to file address (default: 0x80000000)."
    )
    
    args = parser.parse_args()
    
    try:
        key_val = int(args.key, 16)
        base_addr_val = int(args.base_addr, 0) # handles 0x or plain
    except ValueError:
        print("Error: Invalid key or base address format.")
        sys.exit(1)

    process_file(args.input, args.output, key_val, base_addr_val)

if __name__ == "__main__":
    main()
