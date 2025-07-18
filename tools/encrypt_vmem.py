import argparse

def encrypt_byte_and_format(byte_val, key, current_key_round_index):
    key_byte_index = current_key_round_index % len(key)
    encrypted = byte_val ^ key[key_byte_index]
    return f'{encrypted:02X}'

def process_vmem_file_for_encryption(input_file):
    encrypted_output_bytes = []
    key = [0xDE, 0xAD, 0xBE, 0xEF]
    global_byte_index = 0

    with open(input_file, 'r') as file:
        for line in file:
            if line.startswith('@'):
                continue  # Skip address lines

            # Process data lines
            data_bytes_str = line.strip().split()
            for byte_str in data_bytes_str:
                byte_val = int(byte_str, 16)
                encrypted_byte = encrypt_byte_and_format(byte_val, key, global_byte_index)
                encrypted_output_bytes.append(encrypted_byte)
                global_byte_index += 1

    print('@00000000')
    print(' '.join([f'{k:02X}' for k in key]))

    bytes_per_line = 16 
    for i in range(0, len(encrypted_output_bytes), bytes_per_line):
        line_of_bytes = encrypted_output_bytes[i : i + bytes_per_line]
        print(' '.join(line_of_bytes))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Encrypt a vmem file.')
    parser.add_argument('--file', '-f', type=str, help='The input vmem file')

    args = parser.parse_args()
    process_vmem_file_for_encryption(args.file)
