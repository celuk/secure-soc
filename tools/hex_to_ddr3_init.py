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
                # Output format:
                # Addr (32-bit hex) Data (128-bit hex, big-endian equivalent for the line?)
                # The original script does: bytes_16.reverse() then join.
                # If bytes_16 is [b0, b1, ... b15] where b0 is at addr, b15 at addr+15.
                # limit: Data bus width is 128? Or is it just a hex format for a loading tool?
                # Reversing bytes_16 makes the byte at addr+15 come first in string, and byte at addr come last.
                # This corresponds to Little Endian memory view if interpreted as one large integer, 
                # or Big Endian if data_word is written as MSB first.
                # Example: Memory 0: 0x17. Memory 1: 0xF1.
                # bytes defined: [17, F1, ...]
                # reversed: [..., F1, 17]
                # string: "...F117"
                # This matches the Hex file input logic reversed.
                # Input "0003F117" -> 17 at addr, F1 at addr+1, 03 at addr+2, 00 at addr+3.
                # If we read back:
                # bytes: [17, F1, 03, 00, ...]
                # reversed chunk of 4: [00, 03, F1, 17] -> "0003F117"
                # So preserving the original script's output formatting logic is correct.
                
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
