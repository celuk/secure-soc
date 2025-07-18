#include <stdint.h>
#include "qspi.h"
//#include "uart.h"

#define CODE_RAM_BASE_ADDR 0x00002000 //0x00010000
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

// Inverse S-Box
static const uint8_t inv_s_box[256] = {
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
};

// Rcon (Round Constant) - extended for AES-256
static const uint32_t Rcon[14] = {
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1b000000, 0x36000000,
    0x6c000000, 0xd8000000, 0xab000000, 0x4d000000
};

// Helper: xtime for Galois Field multiplication GF(2^8)
// Multiplies by x (equals to 2 in GF(2^8))
static uint8_t xtime(uint8_t x) {
    return ((x << 1) ^ ((x & 0x80) ? 0x1B : 0x00));
}

static uint8_t mul_by_09(uint8_t num) { return xtime(xtime(xtime(num))) ^ num; }
static uint8_t mul_by_0b(uint8_t num) { return xtime(xtime(xtime(num))) ^ xtime(num) ^ num; }
static uint8_t mul_by_0d(uint8_t num) { return xtime(xtime(xtime(num))) ^ xtime(xtime(num)) ^ num; }
static uint8_t mul_by_0e(uint8_t num) { return xtime(xtime(xtime(num))) ^ xtime(xtime(num)) ^ xtime(num); }

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
// expanded_keys is an array of AES_Nb * (AES_Nr + 1) words
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

static void InvSubBytes(uint8_t state[4][4]) {
    for (int r = 0; r < 4; ++r) {
        for (int c = 0; c < 4; ++c) {
            state[r][c] = inv_s_box[state[r][c]];
        }
    }
}

static void InvShiftRows(uint8_t state[4][4]) {
    uint8_t temp;
    // Row 1: 1 byte right shift
    temp = state[1][3];
    state[1][3] = state[1][2]; state[1][2] = state[1][1]; state[1][1] = state[1][0]; state[1][0] = temp;
    // Row 2: 2 bytes right shift
    temp = state[2][0]; state[2][0] = state[2][2]; state[2][2] = temp;
    temp = state[2][1]; state[2][1] = state[2][3]; state[2][3] = temp;
    // Row 3: 3 bytes right shift (1 byte left shift)
    temp = state[3][0];
    state[3][0] = state[3][1]; state[3][1] = state[3][2]; state[3][2] = state[3][3]; state[3][3] = temp;
}

static void InvMixColumns(uint8_t state[4][4]) {
    uint8_t t[4];
    for (int c = 0; c < 4; ++c) {
        t[0] = mul_by_0e(state[0][c]) ^ mul_by_0b(state[1][c]) ^ mul_by_0d(state[2][c]) ^ mul_by_09(state[3][c]);
        t[1] = mul_by_09(state[0][c]) ^ mul_by_0e(state[1][c]) ^ mul_by_0b(state[2][c]) ^ mul_by_0d(state[3][c]);
        t[2] = mul_by_0d(state[0][c]) ^ mul_by_09(state[1][c]) ^ mul_by_0e(state[2][c]) ^ mul_by_0b(state[3][c]);
        t[3] = mul_by_0b(state[0][c]) ^ mul_by_0d(state[1][c]) ^ mul_by_09(state[2][c]) ^ mul_by_0e(state[3][c]);
        state[0][c] = t[0]; state[1][c] = t[1]; state[2][c] = t[2]; state[3][c] = t[3];
    }
}

void aes_decrypt(uint32_t block_part0, uint32_t block_part1, uint32_t block_part2, uint32_t block_part3,
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

    // Start with AddRoundKey using the last round key
    AddRoundKey(state, &round_keys[AES_Nr * AES_Nb]);

    for (int round = AES_Nr - 1; round > 0; --round) {
        InvShiftRows(state);
        InvSubBytes(state);
        AddRoundKey(state, &round_keys[round * AES_Nb]);
        InvMixColumns(state);
    }

    // Final round (round 0, no InvMixColumns before this)
    InvShiftRows(state);
    InvSubBytes(state);
    AddRoundKey(state, &round_keys[0]);

    state_to_block(state, result_block);
}

uint32_t little_endian(uint32_t value) {
    return ((value & 0x000000FF) << 24) |
           ((value & 0x0000FF00) << 8)  |
           ((value & 0x00FF0000) >> 8)  |
           ((value & 0xFF000000) >> 24);
}

void secure_boot()
{
    qspi_init();
    qspi_enable_quad_mode();
    uint32_t address = 0x00000000;
    uint32_t* data;
    uint32_t key_data[8];
    uint32_t decrypted_block[AES_Nb];

    // Phase 1: get key from root of trust
    // TODO: generate key for first time boot that would be another phase
    data = qspi_read_qor(address);
    for (int i = 0; i < 8; i++) {
        key_data[i] = data[i];
    }
    if (key_data[0] == 0xFFFFFFFF) {
        return;
    }

    address += 32;

    //init_uart   ();
    //tekno_printf("key_data[0]: %x\n", key_data[0]);
    //tekno_printf("key_data[1]: %x\n", key_data[1]);
    //tekno_printf("key_data[2]: %x\n", key_data[2]);
    //tekno_printf("key_data[3]: %x\n", key_data[3]);

    // Phase 2: decrypt the code by the given key
    //address += (4 * 8);
    while(data[7] != 0xFFFFFFFF) {
        data = qspi_read_qor(address);

        if(data[0] == 0xFFFFFFFF) {
            break;
        }
        if(data[1] == 0xFFFFFFFF) {
            break;
        }
        if(data[2] == 0xFFFFFFFF) {
            break;
        }
        if(data[3] == 0xFFFFFFFF) {
            break;
        }

        aes_decrypt(data[0], data[1], data[2], data[3],
                    key_data[0], key_data[1], key_data[2], key_data[3],
                    key_data[4], key_data[5], key_data[6], key_data[7], decrypted_block);
        
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[0]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[1]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[2]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[3]);
        address += 4;

        //tekno_printf("Decrypted block at address %x: %x %x %x %x\n",
        //            address-32, little_endian(decrypted_block[0]), little_endian(decrypted_block[1]),
        //            little_endian(decrypted_block[2]), little_endian(decrypted_block[3]));

        if(data[4] == 0xFFFFFFFF) {
            break;
        }
        if(data[5] == 0xFFFFFFFF) {
            break;
        }
        if(data[6] == 0xFFFFFFFF) {
            break;
        }
        if(data[7] == 0xFFFFFFFF) {
            break;
        }
        aes_decrypt(data[4], data[5], data[6], data[7],
                    key_data[0], key_data[1], key_data[2], key_data[3],
                    key_data[4], key_data[5], key_data[6], key_data[7], decrypted_block);

        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[0]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[1]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[2]);
        address += 4;
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address-32) = little_endian(decrypted_block[3]);
        address += 4;

        //tekno_printf("Decrypted block at address %x: %x %x %x %x\n",
        //    address-32, little_endian(decrypted_block[0]), little_endian(decrypted_block[1]),
        //    little_endian(decrypted_block[2]), little_endian(decrypted_block[3]));
    }
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x2000    \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_loaded_software()
{
    asm volatile ("j 0x2100");
}

int main()
{
    secure_boot();
    update_trap_vector_base_address();
    jump_to_loaded_software();
    return 0;
}
