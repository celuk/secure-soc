import argparse

def ctr_keystream_generator(key, row_number):
    key = key & 0xFFFFFFFF
    row_number = row_number & 0xFFFFFFFF
    
    temp_0 = key ^ row_number
    temp_0 = temp_0 & 0xFFFFFFFF
    
    left_shift = (temp_0 << 13) & 0xFFFFFFFF
    right_shift = temp_0 >> 17
    temp_1 = temp_0 ^ left_shift ^ right_shift
    temp_1 = temp_1 & 0xFFFFFFFF
    
    temp_2 = (temp_1 + 0x9E3779B9) & 0xFFFFFFFF
    
    left_shift_2 = (temp_2 << 7) & 0xFFFFFFFF
    right_shift_2 = temp_2 >> 12
    keystream = temp_2 ^ left_shift_2 ^ right_shift_2
    
    return keystream & 0xFFFFFFFF

def ctr_encoder_decoder(row_number, data_in, key):
    keystream_val = ctr_keystream_generator(key, row_number)
    data_out = data_in ^ keystream_val
    return data_out & 0xFFFFFFFF

def encrypt_32bit_word_ctr(word_val, address, key):
    return ctr_encoder_decoder(address, word_val, key)

def process_vmem_file_for_encryption(input_file):
    encrypted_output_bytes = []
    current_address = 0
    
    SECRET_KEY = 0xDEADBEEF
    
    with open(input_file, 'r') as file:
        for line in file:
            line = line.strip()
            if not line:
                continue
                
            if line.startswith('@'):
                current_address = int(line[1:], 16)
                continue
            
            data_bytes_str = line.split()
            
            for i in range(0, len(data_bytes_str), 4):
                word_bytes = data_bytes_str[i:i+4]
                
                while len(word_bytes) < 4:
                    word_bytes.append('00')
                
                word_val = 0
                for j, byte_str in enumerate(word_bytes):
                    byte_val = int(byte_str, 16)
                    word_val |= (byte_val << (j * 8))
                
                word_address = current_address + (i // 4)
                
                encrypted_word = encrypt_32bit_word_ctr(word_val, word_address, SECRET_KEY)
                
                for j in range(4):
                    encrypted_byte = (encrypted_word >> (j * 8)) & 0xFF
                    encrypted_output_bytes.append(f'{encrypted_byte:02X}')
    
    key_bytes = [0xDE, 0xAD, 0xBE, 0xEF]
    print('@00000000')
    print(' '.join([f'{k:02X}' for k in key_bytes]))
    
    bytes_per_line = 16
    for i in range(0, len(encrypted_output_bytes), bytes_per_line):
        line_of_bytes = encrypted_output_bytes[i:i + bytes_per_line]
        print(' '.join(line_of_bytes))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Encrypt a vmem file.')
    parser.add_argument('--file', '-f', type=str, help='The input vmem file')

    args = parser.parse_args()
    process_vmem_file_for_encryption(args.file)
