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

def encrypt_128bit_line(file_addr, data_str, key, base_addr):
    """Encrypt a single 128-bit (32 hex char) data line at the given file address."""
    if len(data_str) != 32:
        data_str = data_str.zfill(32)

    chunks_hex = [data_str[i:i+8] for i in range(0, 32, 8)]

    encrypted_chunks = []
    for i, chunk_hex in enumerate(chunks_hex):
        offset = (3 - i) * 4
        word = int(chunk_hex, 16)
        enc_addr = (file_addr + offset + base_addr) & 0xFFFFFFFF
        keystream = ctr_keystream_generator(key, enc_addr)
        enc_word = word ^ keystream
        encrypted_chunks.append(f"{enc_word:08X}")

    return "".join(encrypted_chunks)


def process_file(input_file, output_file, key, base_addr, fill_to=None):
    try:
        # First pass: read all entries and track addresses
        entries = {}
        with open(input_file, 'r') as f_in:
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
                    entries[file_addr] = data_str
                except ValueError:
                    print(f"Skipping invalid numbers in line: {line}")

        if not entries:
            print("Warning: No valid entries found in input file.")
            return

        min_addr = min(entries.keys())
        max_addr = max(entries.keys())

        # Each line covers 16 bytes (128 bits)
        line_step = 16

        # Determine fill range
        if fill_to is not None:
            # fill_to is in SoC address space, convert to file address space
            fill_to_file = fill_to - base_addr
            end_addr = max(max_addr, fill_to_file)
        else:
            end_addr = max_addr

        # Second pass: write output with gaps filled by encrypted zeros
        filled_count = 0
        with open(output_file, 'w') as f_out:
            addr = min_addr
            while addr <= end_addr:
                addr_str = f"{addr:08X}"
                if addr in entries:
                    data_str = entries[addr]
                else:
                    data_str = "00000000000000000000000000000000"
                    filled_count += 1

                encrypted_data_str = encrypt_128bit_line(addr, data_str, key, base_addr)
                f_out.write(f"{addr_str} {encrypted_data_str}\n")
                addr += line_step

        if filled_count > 0:
            print(f"Filled {filled_count} lines with encrypted zeros "
                  f"(range: 0x{min_addr:08X}-0x{end_addr:08X}, "
                  f"SoC: 0x{min_addr + base_addr:08X}-0x{end_addr + base_addr:08X})")

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
    parser.add_argument(
        "--fill-to",
        default=0x80080000,
        help="Fill with encrypted zeros up to this SoC address (e.g., 0x80040000). "
             "Ensures BSS, scratch, and heap areas are properly initialized for SECURE_LAYER2."
    )
    
    args = parser.parse_args()
    
    try:
        key_val = int(args.key, 16)
        base_addr_val = int(args.base_addr, 0) # handles 0x or plain
        fill_to_val = args.fill_to if isinstance(args.fill_to, int) else (int(args.fill_to, 0) if args.fill_to else None)
    except ValueError:
        print("Error: Invalid key, base address, or fill-to format.")
        sys.exit(1)

    process_file(args.input, args.output, key_val, base_addr_val, fill_to_val)

if __name__ == "__main__":
    main()
