import argparse
import sys

KEY = 0xDEADBEEF_CAFEF00D_BAADF00D_12345678
NONCE = 0x00000000

SBOX = [0xB, 0xF, 0x3, 0x2, 0xA, 0xC, 0x9, 0x1,
        0x6, 0x7, 0x8, 0x0, 0xE, 0x5, 0xD, 0x4]

SBOX_INV = [0xB, 0x7, 0x3, 0x2, 0xF, 0xD, 0x8, 0x9,
            0xA, 0x6, 0x4, 0x0, 0x5, 0xE, 0xC, 0x1]

RC = [
    0x0000000000000000, 0x13198A2E03707344, 0xA4093822299F31D0,
    0x082EFA98EC4E6C89, 0x452821E638D01377, 0xBE5466CF34E90C6C,
    0x7EF84F78FD955CB1, 0x85840851F1AC43AA, 0xC882D32F25323C54,
    0x64A51195E0E3610D, 0xD3B5A399CA0C2399, 0xC0AC29B7C97C50DD,
]

MASK64 = 0xFFFFFFFFFFFFFFFF

def apply_sbox(val):
    out = 0
    for i in range(16):
        out |= SBOX[(val >> (i * 4)) & 0xF] << (i * 4)
    return out

def apply_sbox_inv(val):
    out = 0
    for i in range(16):
        out |= SBOX_INV[(val >> (i * 4)) & 0xF] << (i * 4)
    return out

def bit(val, pos):
    return (val >> pos) & 1

def mprime(d):
    r = 0
    def s(pos, val):
        nonlocal r
        r |= (val & 1) << pos
    s(63, bit(d,59)^bit(d,55)^bit(d,51))
    s(62, bit(d,62)^bit(d,54)^bit(d,50))
    s(61, bit(d,61)^bit(d,57)^bit(d,49))
    s(60, bit(d,60)^bit(d,56)^bit(d,52))
    s(59, bit(d,63)^bit(d,59)^bit(d,55))
    s(58, bit(d,58)^bit(d,54)^bit(d,50))
    s(57, bit(d,61)^bit(d,53)^bit(d,49))
    s(56, bit(d,60)^bit(d,56)^bit(d,48))
    s(55, bit(d,63)^bit(d,59)^bit(d,51))
    s(54, bit(d,62)^bit(d,58)^bit(d,54))
    s(53, bit(d,57)^bit(d,53)^bit(d,49))
    s(52, bit(d,60)^bit(d,52)^bit(d,48))
    s(51, bit(d,63)^bit(d,55)^bit(d,51))
    s(50, bit(d,62)^bit(d,58)^bit(d,50))
    s(49, bit(d,61)^bit(d,57)^bit(d,53))
    s(48, bit(d,56)^bit(d,52)^bit(d,48))
    s(47, bit(d,47)^bit(d,43)^bit(d,39))
    s(46, bit(d,42)^bit(d,38)^bit(d,34))
    s(45, bit(d,45)^bit(d,37)^bit(d,33))
    s(44, bit(d,44)^bit(d,40)^bit(d,32))
    s(43, bit(d,47)^bit(d,43)^bit(d,35))
    s(42, bit(d,46)^bit(d,42)^bit(d,38))
    s(41, bit(d,41)^bit(d,37)^bit(d,33))
    s(40, bit(d,44)^bit(d,36)^bit(d,32))
    s(39, bit(d,47)^bit(d,39)^bit(d,35))
    s(38, bit(d,46)^bit(d,42)^bit(d,34))
    s(37, bit(d,45)^bit(d,41)^bit(d,37))
    s(36, bit(d,40)^bit(d,36)^bit(d,32))
    s(35, bit(d,43)^bit(d,39)^bit(d,35))
    s(34, bit(d,46)^bit(d,38)^bit(d,34))
    s(33, bit(d,45)^bit(d,41)^bit(d,33))
    s(32, bit(d,44)^bit(d,40)^bit(d,36))
    s(31, bit(d,31)^bit(d,27)^bit(d,23))
    s(30, bit(d,26)^bit(d,22)^bit(d,18))
    s(29, bit(d,29)^bit(d,21)^bit(d,17))
    s(28, bit(d,28)^bit(d,24)^bit(d,16))
    s(27, bit(d,31)^bit(d,27)^bit(d,19))
    s(26, bit(d,30)^bit(d,26)^bit(d,22))
    s(25, bit(d,25)^bit(d,21)^bit(d,17))
    s(24, bit(d,28)^bit(d,20)^bit(d,16))
    s(23, bit(d,31)^bit(d,23)^bit(d,19))
    s(22, bit(d,30)^bit(d,26)^bit(d,18))
    s(21, bit(d,29)^bit(d,25)^bit(d,21))
    s(20, bit(d,24)^bit(d,20)^bit(d,16))
    s(19, bit(d,27)^bit(d,23)^bit(d,19))
    s(18, bit(d,30)^bit(d,22)^bit(d,18))
    s(17, bit(d,29)^bit(d,25)^bit(d,17))
    s(16, bit(d,28)^bit(d,24)^bit(d,20))
    s(15, bit(d,11)^bit(d,7)^bit(d,3))
    s(14, bit(d,14)^bit(d,6)^bit(d,2))
    s(13, bit(d,13)^bit(d,9)^bit(d,1))
    s(12, bit(d,12)^bit(d,8)^bit(d,4))
    s(11, bit(d,15)^bit(d,11)^bit(d,7))
    s(10, bit(d,10)^bit(d,6)^bit(d,2))
    s(9,  bit(d,13)^bit(d,5)^bit(d,1))
    s(8,  bit(d,12)^bit(d,8)^bit(d,0))
    s(7,  bit(d,15)^bit(d,11)^bit(d,3))
    s(6,  bit(d,14)^bit(d,10)^bit(d,6))
    s(5,  bit(d,9)^bit(d,5)^bit(d,1))
    s(4,  bit(d,12)^bit(d,4)^bit(d,0))
    s(3,  bit(d,15)^bit(d,7)^bit(d,3))
    s(2,  bit(d,14)^bit(d,10)^bit(d,2))
    s(1,  bit(d,13)^bit(d,9)^bit(d,5))
    s(0,  bit(d,8)^bit(d,4)^bit(d,0))
    return r

def nibbles(val, pos):
    return (val >> (pos * 4)) & 0xF

def set_nibble(val, pos, nib):
    return (val & ~(0xF << (pos * 4))) | ((nib & 0xF) << (pos * 4))

def shift_rows(mp):
    out = 0
    for dst, src in [(15,15),(14,10),(13,5),(12,0),(11,11),(10,6),(9,1),(8,12),
                     (7,7),(6,2),(5,13),(4,8),(3,3),(2,14),(1,9),(0,4)]:
        out = set_nibble(out, dst, nibbles(mp, src))
    return out

def shift_rows_inv(d):
    out = 0
    for dst, src in [(15,15),(14,2),(13,5),(12,8),(11,11),(10,14),(9,1),(8,4),
                     (7,7),(6,10),(5,13),(4,0),(3,3),(2,6),(1,9),(0,12)]:
        out = set_nibble(out, dst, nibbles(d, src))
    return out

def linear_m(d):
    return shift_rows(mprime(d))

def linear_m_inv(d):
    return mprime(shift_rows_inv(d))

def prince_core(data_in, key):
    state = data_in ^ key ^ RC[0]
    for r in range(1, 6):
        state = apply_sbox(state)
        state = linear_m(state)
        state = (state ^ key ^ RC[r]) & MASK64
    middle = apply_sbox(state)
    middle = mprime(middle)
    state = apply_sbox_inv(middle)
    for r in range(6, 11):
        state = (state ^ key ^ RC[r]) & MASK64
        state = linear_m_inv(state)
        state = apply_sbox_inv(state)
    return (state ^ key ^ RC[11]) & MASK64

def prince_encrypt_word(addr, data_in, key128, nonce):
    k0 = (key128 >> 64) & MASK64
    k1 = key128 & MASK64
    k0_prime = ((k0 & 1) << 63) | (((k0 >> 2) & 0x3FFFFFFFFFFFFFFF) << 1) | ((((k0 >> 1) & 1) ^ ((k0 >> 63) & 1)) & 1)

    prince_input = ((nonce & 0xFFFFFFFF) << 32) | (addr & 0xFFFFFFF8)
    core_in = (prince_input ^ k0) & MASK64
    core_out = prince_core(core_in, k1)
    keystream_block = (core_out ^ k0_prime) & MASK64

    if (addr >> 2) & 1:
        keystream_word = (keystream_block >> 32) & 0xFFFFFFFF
    else:
        keystream_word = keystream_block & 0xFFFFFFFF

    return (data_in ^ keystream_word) & 0xFFFFFFFF

def process_file(input_file, output_file, key=KEY, nonce=NONCE, start_row=0x80000000):
    try:
        with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
            row = start_row
            for line in f_in:
                line = line.strip()
                if not line:
                    continue
                try:
                    data_in = int(line, 16)
                    data_out = prince_encrypt_word(row, data_in, key, nonce)
                    f_out.write(f"{data_out:08x}\n")
                    row += 4
                except ValueError:
                    print(f"Skipping invalid line: {line}")
    except FileNotFoundError:
        print(f"Error: Input file {input_file} not found.")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Encrypt hex file using PRINCE cipher in CTR mode."
    )
    parser.add_argument("-i", "--input", required=True)
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--key", default=hex(KEY))
    parser.add_argument("--nonce", type=lambda x: int(x, 0), default=NONCE)
    parser.add_argument("--start-row", type=lambda x: int(x, 0), default=0x80000000)
    args = parser.parse_args()

    try:
        key_val = int(args.key, 16)
    except ValueError:
        print("Error: Invalid key format.")
        sys.exit(1)

    process_file(args.input, args.output, key_val, args.nonce, args.start_row)

if __name__ == "__main__":
    main()
