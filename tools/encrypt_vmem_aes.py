import argparse

# AES constants
AES_Nk = 4  # Number of 32-bit words in the key (AES-128)
AES_Nb = 4  # Number of 32-bit words in a block (always 4 for AES)
AES_Nr = 10 # Number of rounds for AES-128

# S-Box
S_BOX = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
]

# Inverse S-Box
INV_S_BOX = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
]

# Rcon (Round Constant)
RCON = [
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1b000000, 0x36000000
]

# Helper: xtime for Galois Field multiplication GF(2^8)
def xtime(a):
    # Multiply by x (equals to 2 in GF(2^8))
    # If MSB is 1, XOR with 0x1B, else just left shift
    # Ensure result stays within a byte
    return (((a << 1) & 0xff) ^ 0x1b) if (a & 0x80) else ((a << 1) & 0xff)

# Optimized Galois Field multiplications for MixColumns
def mul_by_02(num): return xtime(num)
def mul_by_03(num): return xtime(num) ^ num
def mul_by_09(num): return xtime(xtime(xtime(num))) ^ num
def mul_by_0b(num): return xtime(xtime(xtime(num))) ^ xtime(num) ^ num
def mul_by_0d(num): return xtime(xtime(xtime(num))) ^ xtime(xtime(num)) ^ num
def mul_by_0e(num): return xtime(xtime(xtime(num))) ^ xtime(xtime(num)) ^ xtime(num)

# Key Expansion helpers
def rot_word(word): # word is a 32-bit int
    # Rotate left by 8 bits
    return ((word << 8) & 0xFFFFFFFF) | (word >> 24)

def sub_word(word): # word is a 32-bit int
    # Apply S_BOX to each byte of the word
    return (
        (S_BOX[(word >> 24) & 0xFF] << 24) |
        (S_BOX[(word >> 16) & 0xFF] << 16) |
        (S_BOX[(word >>  8) & 0xFF] <<  8) |
        (S_BOX[(word >>  0) & 0xFF] <<  0)
    )

# Key Expansion function
def key_expansion(key_parts): # key_parts is a list of 4 32-bit ints
    round_keys = [0] * (AES_Nb * (AES_Nr + 1)) # 4 * (10 + 1) = 44 words

    for i in range(AES_Nk): # First Nk words are the original key
        round_keys[i] = key_parts[i]

    for i in range(AES_Nk, AES_Nb * (AES_Nr + 1)):
        temp = round_keys[i - 1]
        if i % AES_Nk == 0:
            temp = sub_word(rot_word(temp)) ^ RCON[i // AES_Nk - 1]
        # No AES_Nk > 6 and i % AES_Nk == 4 condition for AES-128
        round_keys[i] = round_keys[i - AES_Nk] ^ temp
    return round_keys

# Convert input block parts to state matrix (state[row][col])
def block_to_state(b0, b1, b2, b3):
    state = [[0]*AES_Nb for _ in range(4)] # 4x4 matrix of bytes
    block_parts_list = [b0, b1, b2, b3]
    for c in range(AES_Nb): # column
        state[0][c] = (block_parts_list[c] >> 24) & 0xFF
        state[1][c] = (block_parts_list[c] >> 16) & 0xFF
        state[2][c] = (block_parts_list[c] >>  8) & 0xFF
        state[3][c] = (block_parts_list[c] >>  0) & 0xFF
    return state

# Convert state matrix to output block list
def state_to_block(state):
    block_array = [0]*AES_Nb # list of 4 32-bit integers
    for c in range(AES_Nb): # column
        block_array[c] = (
            (state[0][c] << 24) |
            (state[1][c] << 16) |
            (state[2][c] <<  8) |
            (state[3][c] <<  0)
        )
    return block_array

# AES round transformations (modify state in-place)
def sub_bytes(state):
    for r in range(4):
        for c in range(AES_Nb):
            state[r][c] = S_BOX[state[r][c]]

def shift_rows(state):
    # Row 0: no shift
    # Row 1: 1 byte left shift
    state[1][0], state[1][1], state[1][2], state[1][3] = state[1][1], state[1][2], state[1][3], state[1][0]
    # Row 2: 2 bytes left shift
    state[2][0], state[2][1], state[2][2], state[2][3] = state[2][2], state[2][3], state[2][0], state[2][1]
    # Row 3: 3 bytes left shift (1 byte right shift)
    state[3][0], state[3][1], state[3][2], state[3][3] = state[3][3], state[3][0], state[3][1], state[3][2]

def mix_columns(state):
    for c in range(AES_Nb):
        s0, s1, s2, s3 = state[0][c], state[1][c], state[2][c], state[3][c] # Current column
        state[0][c] = mul_by_02(s0) ^ mul_by_03(s1) ^ s2            ^ s3
        state[1][c] = s0            ^ mul_by_02(s1) ^ mul_by_03(s2) ^ s3
        state[2][c] = s0            ^ s1            ^ mul_by_02(s2) ^ mul_by_03(s3)
        state[3][c] = mul_by_03(s0) ^ s1            ^ s2            ^ mul_by_02(s3)

def add_round_key(state, round_key_words_for_round): # round_key_words is a list of AES_Nb 32-bit words
    for c in range(AES_Nb):
        key_col_word = round_key_words_for_round[c]
        state[0][c] ^= (key_col_word >> 24) & 0xFF
        state[1][c] ^= (key_col_word >> 16) & 0xFF
        state[2][c] ^= (key_col_word >>  8) & 0xFF
        state[3][c] ^= (key_col_word >>  0) & 0xFF

# Inverse AES round transformations (modify state in-place)
def inv_sub_bytes(state):
    for r in range(4):
        for c in range(AES_Nb):
            state[r][c] = INV_S_BOX[state[r][c]]

def inv_shift_rows(state):
    # Row 0: no shift
    # Row 1: 1 byte right shift
    state[1][0], state[1][1], state[1][2], state[1][3] = state[1][3], state[1][0], state[1][1], state[1][2]
    # Row 2: 2 bytes right shift
    state[2][0], state[2][1], state[2][2], state[2][3] = state[2][2], state[2][3], state[2][0], state[2][1]
    # Row 3: 3 bytes right shift (1 byte left shift)
    state[3][0], state[3][1], state[3][2], state[3][3] = state[3][1], state[3][2], state[3][3], state[3][0]

def inv_mix_columns(state):
    for c in range(AES_Nb):
        s0, s1, s2, s3 = state[0][c], state[1][c], state[2][c], state[3][c] # Current column
        state[0][c] = mul_by_0e(s0) ^ mul_by_0b(s1) ^ mul_by_0d(s2) ^ mul_by_09(s3)
        state[1][c] = mul_by_09(s0) ^ mul_by_0e(s1) ^ mul_by_0b(s2) ^ mul_by_0d(s3)
        state[2][c] = mul_by_0d(s0) ^ mul_by_09(s1) ^ mul_by_0e(s2) ^ mul_by_0b(s3)
        state[3][c] = mul_by_0b(s0) ^ mul_by_0d(s1) ^ mul_by_09(s2) ^ mul_by_0e(s3)

# Main encryption function
def aes_encrypt(block_part0, block_part1, block_part2, block_part3,
                key_part0, key_part1, key_part2, key_part3):
    state = block_to_state(block_part0, block_part1, block_part2, block_part3)
    initial_key = [key_part0, key_part1, key_part2, key_part3]
    key_schedule = key_expansion(initial_key)

    add_round_key(state, key_schedule[0:AES_Nb]) # Round 0

    for round_num in range(1, AES_Nr): # Rounds 1 to Nr-1
        sub_bytes(state)
        shift_rows(state)
        mix_columns(state)
        add_round_key(state, key_schedule[round_num * AES_Nb : (round_num + 1) * AES_Nb])

    # Final round (Round Nr) - no MixColumns
    sub_bytes(state)
    shift_rows(state)
    add_round_key(state, key_schedule[AES_Nr * AES_Nb : (AES_Nr + 1) * AES_Nb])

    return state_to_block(state) # Returns a list of 4 32-bit integers

# Main decryption function
def aes_decrypt(block_part0, block_part1, block_part2, block_part3,
                key_part0, key_part1, key_part2, key_part3):
    state = block_to_state(block_part0, block_part1, block_part2, block_part3)
    initial_key = [key_part0, key_part1, key_part2, key_part3]
    key_schedule = key_expansion(initial_key) # Key expansion is the same

    # Start with AddRoundKey using the last round key (from round Nr)
    add_round_key(state, key_schedule[AES_Nr * AES_Nb : (AES_Nr + 1) * AES_Nb])

    for round_num in range(AES_Nr - 1, 0, -1): # Rounds Nr-1 down to 1
        inv_shift_rows(state)
        inv_sub_bytes(state)
        add_round_key(state, key_schedule[round_num * AES_Nb : (round_num + 1) * AES_Nb])
        inv_mix_columns(state)

    # Final round (inverse of Round 0) - no InvMixColumns after this
    inv_shift_rows(state)
    inv_sub_bytes(state)
    add_round_key(state, key_schedule[0:AES_Nb])

    return state_to_block(state) # Returns a list of 4 32-bit integers

def hex_str_to_u8_list(line):
    return [int(b, 16) for b in line.strip().split()]

def u32_from_bytes(b0, b1, b2, b3):
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3

def bytes_from_u32(word):
    return [(word >> shift) & 0xFF for shift in (24, 16, 8, 0)]

def process_vmem_file_for_aes_encryption(input_file):
    data_bytes = []

    # Read data ignoring address lines
    with open(input_file, 'r') as file:
        for line in file:
            if line.startswith('@'):
                continue
            data_bytes.extend(hex_str_to_u8_list(line))

    # Pad data_bytes to a multiple of 16 bytes (128 bits)
    while len(data_bytes) % 16 != 0:
        data_bytes.append(0x00)

    # AES key parts (128-bit key)
    k0 = 0x2b7e1516
    k1 = 0x28aed2a6
    k2 = 0xabf71588
    k3 = 0x09cf4f3c
    #k0 = 0xc0a1d2e3
    #k1 = 0x34f9851b
    #k2 = 0x2a47c932
    #k3 = 0x6fbd8a7e

    

    encrypted_bytes = []

    for i in range(0, len(data_bytes), 16):
        block = data_bytes[i:i+16]

        b0 = u32_from_bytes(*block[ 0: 4])
        b1 = u32_from_bytes(*block[ 4: 8])
        b2 = u32_from_bytes(*block[ 8:12])
        b3 = u32_from_bytes(*block[12:16])

        e0, e1, e2, e3 = aes_encrypt(b0, b1, b2, b3, k0, k1, k2, k3)

        #if i < 10 * 16:
        #    print("Encrypting block:")
        #    print(f"  Data : {b0:08X} {b1:08X} {b2:08X} {b3:08X}")
        #    print(f"  Key  : {k0:08X} {k1:08X} {k2:08X} {k3:08X}")
        #    print(f"  Encrypted: {e0:08X} {e1:08X} {e2:08X} {e3:08X}")

        encrypted_bytes.extend(bytes_from_u32(e0)[::-1])
        encrypted_bytes.extend(bytes_from_u32(e1)[::-1])
        encrypted_bytes.extend(bytes_from_u32(e2)[::-1])
        encrypted_bytes.extend(bytes_from_u32(e3)[::-1])

    # Output in VMEM format
    print('@00000000')
    key_bytes = sum([bytes_from_u32(k)[::-1] for k in [k0, k1, k2, k3]], [])
    print(' '.join(f'{b:02X}' for b in key_bytes))

    for i in range(0, len(encrypted_bytes), 16):
        line_bytes = encrypted_bytes[i:i+16]
        print(' '.join(f'{b:02X}' for b in line_bytes))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='AES encrypt a vmem file.')
    parser.add_argument('--file', '-f', type=str, help='The input vmem file')

    args = parser.parse_args()
    process_vmem_file_for_aes_encryption(args.file)
