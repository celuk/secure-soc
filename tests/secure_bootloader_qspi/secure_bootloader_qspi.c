#include <stdint.h>
#include "qspi.h"
//#include "uart.h"

#define CODE_RAM_BASE_ADDR 0x2000 //0x80000000 //0x00010000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

// AES constants
#define AES_Nk 8  // Number of 32-bit words in the key (AES-256)
#define AES_Nb 4  // Number of 32-bit words in a block (always 4 for AES)
#define AES_Nr 14 // Number of rounds for AES-256

// S-Box
static const uint8_t s_box[256] = {
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
};

// Rcon (Round Constant) - extended for AES-256
static const uint32_t Rcon[14] = {
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1b000000, 0x36000000,
    0x6c000000, 0xd8000000, 0xab000000, 0x4d000000
};

// Helper: xtime for Galois Field multiplication GF(2^8)
static uint8_t xtime(uint8_t x) {
    return ((x << 1) ^ ((x & 0x80) ? 0x1B : 0x00));
}

static uint8_t mul_by_02(uint8_t num) { return xtime(num); }
static uint8_t mul_by_03(uint8_t num) { return xtime(num) ^ num; }

// Key Expansion helpers
static uint32_t RotWord(uint32_t word) {
    return (word << 8) | (word >> 24);
}

static uint32_t SubWord(uint32_t word) {
    uint32_t result = 0;
    result |= (uint32_t)s_box[(word >> 24) & 0xFF] << 24;
    result |= (uint32_t)s_box[(word >> 16) & 0xFF] << 16;
    result |= (uint32_t)s_box[(word >>  8) & 0xFF] <<  8;
    result |= (uint32_t)s_box[(word >>  0) & 0xFF] <<  0;
    return result;
}

// Key Expansion function
static void KeyExpansion(uint32_t* expanded_keys, const uint32_t* key) {
    int i;
    uint32_t temp;

    for (i = 0; i < AES_Nk; i++) {
        expanded_keys[i] = key[i];
    }

    for (i = AES_Nk; i < AES_Nb * (AES_Nr + 1); i++) {
        temp = expanded_keys[i - 1];
        if (i % AES_Nk == 0) {
            temp = SubWord(RotWord(temp)) ^ Rcon[i / AES_Nk - 1];
        }
        // For AES-256, apply SubWord to every 4th word after the first 6 rounds
        if (AES_Nk > 6 && (i % AES_Nk == 4)) {
            temp = SubWord(temp);
        }
        expanded_keys[i] = expanded_keys[i - AES_Nk] ^ temp;
    }
}

// Convert input block parts to state matrix (state[row][col])
static void block_to_state(uint32_t b0, uint32_t b1, uint32_t b2, uint32_t b3, uint8_t state[4][4]) {
    uint32_t block_parts[4] = {b0, b1, b2, b3};
    for (int c = 0; c < 4; ++c) {
        state[0][c] = (block_parts[c] >> 24) & 0xFF;
        state[1][c] = (block_parts[c] >> 16) & 0xFF;
        state[2][c] = (block_parts[c] >>  8) & 0xFF;
        state[3][c] = (block_parts[c] >>  0) & 0xFF;
    }
}

// Convert state matrix to output block array
static void state_to_block(const uint8_t state[4][4], uint32_t* block_array) {
    for (int c = 0; c < 4; ++c) {
        block_array[c] = ((uint32_t)state[0][c] << 24) |
                         ((uint32_t)state[1][c] << 16) |
                         ((uint32_t)state[2][c] <<  8) |
                         ((uint32_t)state[3][c] <<  0);
    }
}

static void AddRoundKey(uint8_t state[4][4], const uint32_t* round_key_words) {
    for (int c = 0; c < AES_Nb; ++c) {
        state[0][c] ^= (round_key_words[c] >> 24) & 0xFF;
        state[1][c] ^= (round_key_words[c] >> 16) & 0xFF;
        state[2][c] ^= (round_key_words[c] >>  8) & 0xFF;
        state[3][c] ^= (round_key_words[c] >>  0) & 0xFF;
    }
}

// GCM uses forward AES encryption (not inverse)
static void SubBytes(uint8_t state[4][4]) {
    for (int r = 0; r < 4; ++r) {
        for (int c = 0; c < 4; ++c) {
            state[r][c] = s_box[state[r][c]];
        }
    }
}

static void ShiftRows(uint8_t state[4][4]) {
    uint8_t temp;
    // Row 1: 1 byte left shift
    temp = state[1][0];
    state[1][0] = state[1][1]; state[1][1] = state[1][2]; state[1][2] = state[1][3]; state[1][3] = temp;
    // Row 2: 2 bytes left shift
    temp = state[2][0]; state[2][0] = state[2][2]; state[2][2] = temp;
    temp = state[2][1]; state[2][1] = state[2][3]; state[2][3] = temp;
    // Row 3: 3 bytes left shift (1 byte right shift)
    temp = state[3][3];
    state[3][3] = state[3][2]; state[3][2] = state[3][1]; state[3][1] = state[3][0]; state[3][0] = temp;
}

static void MixColumns(uint8_t state[4][4]) {
    uint8_t t[4];
    for (int c = 0; c < 4; ++c) {
        t[0] = mul_by_02(state[0][c]) ^ mul_by_03(state[1][c]) ^ state[2][c]            ^ state[3][c];
        t[1] = state[0][c]            ^ mul_by_02(state[1][c]) ^ mul_by_03(state[2][c]) ^ state[3][c];
        t[2] = state[0][c]            ^ state[1][c]            ^ mul_by_02(state[2][c]) ^ mul_by_03(state[3][c]);
        t[3] = mul_by_03(state[0][c]) ^ state[1][c]            ^ state[2][c]            ^ mul_by_02(state[3][c]);
        state[0][c] = t[0]; state[1][c] = t[1]; state[2][c] = t[2]; state[3][c] = t[3];
    }
}

// AES-ECB forward encryption (used by GCM's CTR mode)
void aes_encrypt(uint32_t block_part0, uint32_t block_part1, uint32_t block_part2, uint32_t block_part3,
                 uint32_t key_part0, uint32_t key_part1, uint32_t key_part2, uint32_t key_part3,
                 uint32_t key_part4, uint32_t key_part5, uint32_t key_part6, uint32_t key_part7,
                 uint32_t* result_block) {
    uint8_t state[4][4];
    uint32_t initial_key[AES_Nk];
    static uint32_t round_keys[AES_Nb * (AES_Nr + 1)];

    initial_key[0] = key_part0; initial_key[1] = key_part1;
    initial_key[2] = key_part2; initial_key[3] = key_part3;
    initial_key[4] = key_part4; initial_key[5] = key_part5;
    initial_key[6] = key_part6; initial_key[7] = key_part7;

    block_to_state(block_part0, block_part1, block_part2, block_part3, state);

    KeyExpansion(round_keys, initial_key);

    AddRoundKey(state, &round_keys[0]);

    for (int round = 1; round < AES_Nr; ++round) {
        SubBytes(state);
        ShiftRows(state);
        MixColumns(state);
        AddRoundKey(state, &round_keys[round * AES_Nb]);
    }

    // Final round (no MixColumns)
    SubBytes(state);
    ShiftRows(state);
    AddRoundKey(state, &round_keys[AES_Nr * AES_Nb]);

    state_to_block(state, result_block);
}

uint32_t little_endian(uint32_t value) {
    return ((value & 0x000000FF) << 24) |
           ((value & 0x0000FF00) << 8)  |
           ((value & 0x00FF0000) >> 8)  |
           ((value & 0xFF000000) >> 24);
}

// GF(2^128) multiplication for GHASH
static void gf128_mul(uint8_t* x, const uint8_t* y, uint8_t* result) {
    uint8_t v[16];
    uint8_t z[16];
    int i, j;

    for (i = 0; i < 16; i++) {
        v[i] = y[i];
        z[i] = 0;
    }

    for (i = 0; i < 128; i++) {
        if (x[i / 8] & (0x80 >> (i % 8))) {
            for (j = 0; j < 16; j++)
                z[j] ^= v[j];
        }
        uint8_t lsb = v[15] & 1;
        for (j = 15; j > 0; j--)
            v[j] = (v[j] >> 1) | (v[j-1] << 7);
        v[0] >>= 1;
        if (lsb)
            v[0] ^= 0xE1;  // reduction polynomial
    }

    for (i = 0; i < 16; i++)
        result[i] = z[i];
}

// XOR 16-byte blocks
static void xor_block(uint8_t* dst, const uint8_t* src) {
    for (int i = 0; i < 16; i++)
        dst[i] ^= src[i];
}

// Convert uint32_t to big-endian bytes
static void u32_to_bytes(uint32_t val, uint8_t* out) {
    out[0] = (val >> 24) & 0xFF;
    out[1] = (val >> 16) & 0xFF;
    out[2] = (val >>  8) & 0xFF;
    out[3] = (val >>  0) & 0xFF;
}

// Convert big-endian bytes to uint32_t
static uint32_t bytes_to_u32(const uint8_t* b) {
    return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
           ((uint32_t)b[2] << 8)  | ((uint32_t)b[3]);
}

// Increment last 32 bits of 16-byte counter block
static void inc32(uint8_t* counter) {
    uint32_t val = bytes_to_u32(&counter[12]);
    val++;
    u32_to_bytes(val, &counter[12]);
}

void secure_boot()
{
    qspi_init();
    qspi_enable_quad_mode();
    uint32_t address = 0x00000000;
    uint32_t* data;
    uint32_t key_data[8];
    uint32_t iv_data[4];
    uint32_t tag_data[4];
    uint32_t encrypted_block[AES_Nb];

    // Phase 1: get key from root of trust
    data = qspi_read_qor(address);
    for (int i = 0; i < 8; i++) {
        key_data[i] = data[i];
    }
    if (key_data[0] == 0xFFFFFFFF) {
        return;
    }
    address += 32;

    // Phase 2: read IV (12 bytes in first 3 words, 4th word is padding)
    data = qspi_read_qor(address);
    for (int i = 0; i < 4; i++) {
        iv_data[i] = data[i];
    }

    // Read tag (16 bytes)
    for (int i = 0; i < 4; i++) {
        tag_data[i] = data[i + 4];
    }
    address += 32;

    // Build initial counter block: IV || 0x00000001
    uint8_t counter[16];
    u32_to_bytes(iv_data[0], &counter[0]);
    u32_to_bytes(iv_data[1], &counter[4]);
    u32_to_bytes(iv_data[2], &counter[8]);
    counter[12] = 0x00; counter[13] = 0x00; counter[14] = 0x00; counter[15] = 0x01;

    // Compute H = AES_K(0^128)
    uint8_t H[16];
    uint32_t h_block[4];
    aes_encrypt(0, 0, 0, 0,
                key_data[0], key_data[1], key_data[2], key_data[3],
                key_data[4], key_data[5], key_data[6], key_data[7], h_block);
    u32_to_bytes(h_block[0], &H[0]);
    u32_to_bytes(h_block[1], &H[4]);
    u32_to_bytes(h_block[2], &H[8]);
    u32_to_bytes(h_block[3], &H[12]);

    // Encrypt J0 = AES_K(IV || 0x00000001) for tag verification
    uint32_t j0_block[4];
    aes_encrypt(bytes_to_u32(&counter[0]), bytes_to_u32(&counter[4]),
                bytes_to_u32(&counter[8]), bytes_to_u32(&counter[12]),
                key_data[0], key_data[1], key_data[2], key_data[3],
                key_data[4], key_data[5], key_data[6], key_data[7], j0_block);

    // GCM decryption via CTR mode (counter starts at 2)
    inc32(counter);

    uint8_t ghash_state[16] = {0};
    uint32_t total_cipher_bytes = 0;

    while(data[7] != 0xFFFFFFFF) {
        data = qspi_read_qor(address);

        if(data[0] == 0xFFFFFFFF) break;
        if(data[1] == 0xFFFFFFFF) break;
        if(data[2] == 0xFFFFFFFF) break;
        if(data[3] == 0xFFFFFFFF) break;

        // GHASH: accumulate ciphertext block
        uint8_t cipher_block[16];
        u32_to_bytes(data[0], &cipher_block[0]);
        u32_to_bytes(data[1], &cipher_block[4]);
        u32_to_bytes(data[2], &cipher_block[8]);
        u32_to_bytes(data[3], &cipher_block[12]);
        xor_block(ghash_state, cipher_block);
        uint8_t tmp[16];
        gf128_mul(ghash_state, H, tmp);
        for (int i = 0; i < 16; i++) ghash_state[i] = tmp[i];
        total_cipher_bytes += 16;

        // CTR decrypt: encrypt counter, XOR with ciphertext
        aes_encrypt(bytes_to_u32(&counter[0]), bytes_to_u32(&counter[4]),
                    bytes_to_u32(&counter[8]), bytes_to_u32(&counter[12]),
                    key_data[0], key_data[1], key_data[2], key_data[3],
                    key_data[4], key_data[5], key_data[6], key_data[7], encrypted_block);
        inc32(counter);

        uint32_t decrypted[4];
        decrypted[0] = data[0] ^ encrypted_block[0];
        decrypted[1] = data[1] ^ encrypted_block[1];
        decrypted[2] = data[2] ^ encrypted_block[2];
        decrypted[3] = data[3] ^ encrypted_block[3];

        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[0]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[1]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[2]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[3]);
        address += 4;

        if(data[4] == 0xFFFFFFFF) break;
        if(data[5] == 0xFFFFFFFF) break;
        if(data[6] == 0xFFFFFFFF) break;
        if(data[7] == 0xFFFFFFFF) break;

        // GHASH: accumulate second ciphertext block
        u32_to_bytes(data[4], &cipher_block[0]);
        u32_to_bytes(data[5], &cipher_block[4]);
        u32_to_bytes(data[6], &cipher_block[8]);
        u32_to_bytes(data[7], &cipher_block[12]);
        xor_block(ghash_state, cipher_block);
        gf128_mul(ghash_state, H, tmp);
        for (int i = 0; i < 16; i++) ghash_state[i] = tmp[i];
        total_cipher_bytes += 16;

        // CTR decrypt second block
        aes_encrypt(bytes_to_u32(&counter[0]), bytes_to_u32(&counter[4]),
                    bytes_to_u32(&counter[8]), bytes_to_u32(&counter[12]),
                    key_data[0], key_data[1], key_data[2], key_data[3],
                    key_data[4], key_data[5], key_data[6], key_data[7], encrypted_block);
        inc32(counter);

        decrypted[0] = data[4] ^ encrypted_block[0];
        decrypted[1] = data[5] ^ encrypted_block[1];
        decrypted[2] = data[6] ^ encrypted_block[2];
        decrypted[3] = data[7] ^ encrypted_block[3];

        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[0]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[1]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[2]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-64) = little_endian(decrypted[3]);
        address += 4;
    }

    // Finalize GHASH: process length block (no AAD, so aad_len=0)
    uint8_t len_block[16] = {0};
    uint64_t cipher_bits = (uint64_t)total_cipher_bytes * 8;
    len_block[8]  = (cipher_bits >> 56) & 0xFF;
    len_block[9]  = (cipher_bits >> 48) & 0xFF;
    len_block[10] = (cipher_bits >> 40) & 0xFF;
    len_block[11] = (cipher_bits >> 32) & 0xFF;
    len_block[12] = (cipher_bits >> 24) & 0xFF;
    len_block[13] = (cipher_bits >> 16) & 0xFF;
    len_block[14] = (cipher_bits >>  8) & 0xFF;
    len_block[15] = (cipher_bits >>  0) & 0xFF;
    xor_block(ghash_state, len_block);
    uint8_t final_hash[16];
    gf128_mul(ghash_state, H, final_hash);

    // Compute expected tag: GHASH XOR E(K, J0)
    uint8_t computed_tag[16];
    uint8_t j0_bytes[16];
    u32_to_bytes(j0_block[0], &j0_bytes[0]);
    u32_to_bytes(j0_block[1], &j0_bytes[4]);
    u32_to_bytes(j0_block[2], &j0_bytes[8]);
    u32_to_bytes(j0_block[3], &j0_bytes[12]);
    for (int i = 0; i < 16; i++)
        computed_tag[i] = final_hash[i] ^ j0_bytes[i];

    // Verify tag
    uint8_t expected_tag[16];
    u32_to_bytes(tag_data[0], &expected_tag[0]);
    u32_to_bytes(tag_data[1], &expected_tag[4]);
    u32_to_bytes(tag_data[2], &expected_tag[8]);
    u32_to_bytes(tag_data[3], &expected_tag[12]);

    for (int i = 0; i < 16; i++) {
        if (computed_tag[i] != expected_tag[i]) {
            return; // Tag mismatch, authentication failed
        }
    }
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        //"li    t0, 0x80000000    \n"
        "li    t0, 0x2000    \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_loaded_software()
{
    asm volatile (
        //"li    t0, 0x80000100 \n"
        "li    t0, 0x2100 \n"
        "jalr  x0, t0, 0 \n"
    );
}

int main()
{
    secure_boot();
    update_trap_vector_base_address();
    jump_to_loaded_software();
    return 0;
}
