// This file is part of https://github.com/celuk/secure-soc
// Copyright (C) 2025  Seyyid Hikmet Celik
//                     seyyid4091@gmail.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// inspired and borrowed some parts from: https://github.com/agh-riscv/pixel_riscv_soc/tree/master/sw/bootloader

#include <stdint.h>
#include "qspi.h"

typedef struct {
    uint32_t *mem;
    uint32_t size;
} Code_ram;

/*
union Code_ram_word {
    uint8_t bytes[4];
    uint32_t word;
};
*/

static const uint32_t code_ram_base_address = 0x00002000; //0x00010000;
static const uint32_t depth = 2048; //4096;
static const uint8_t word_length = 4;
static const uint32_t size = depth * word_length;

Code_ram code_ram;

#define CODE_RAM_BASE_ADDR 0x00002000 //0x00010000
#define CODE_RAM (*(volatile uint32_t*) (CODE_RAM_BASE_ADDR))

void Code_ram_init(Code_ram *self, uint32_t base_address, uint32_t size) {
    self->mem = (uint32_t *)base_address;
    self->size = size;
}

uint32_t *Code_ram_set(Code_ram *self, uint32_t address) {
    return &(self->mem[address >> 2]);
}

uint32_t Code_ram_get_size(Code_ram *self) {
    return self->size;
}

void initialize_code_ram() {
    Code_ram_init(&code_ram, code_ram_base_address, size);
}

void load_code_through_qspi()
{
    qspi_init();
    qspi_enable_quad_mode();
    uint32_t address = 0x00000000;
    uint32_t* data; //= qspi_read_qor(address);
    for (uint32_t i = 0; i < Code_ram_get_size(&code_ram); i += 32) {
        data = qspi_read_qor(address);

        if(data[0] == 0xFFFFFFFF) {
            break;
        }
        
        //*Code_ram_set(&code_ram, address) = data[0];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[0];
        address += 4;

        if(data[1] == 0xFFFFFFFF) {
            break;
        }

        //*Code_ram_set(&code_ram, address) = data[1];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[1];
        address += 4;

        if(data[2] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[2];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[2];
        address += 4;

        if(data[3] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[3];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[3];
        address += 4;

        if(data[4] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[4];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[4];
        address += 4;

        if(data[5] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[5];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[5];
        address += 4;

        if(data[6] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[6];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[6];
        address += 4;

        if(data[7] == 0xFFFFFFFF) {
            break;
        }
        //*Code_ram_set(&code_ram, address) = data[7];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = data[7];
        address += 4;
    }

    for (uint32_t i = 0; i < 4096; i += 32) {
        //*Code_ram_set(&code_ram, address) = data[0];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[1];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[2];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[3];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[4];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[5];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[6];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
        //*Code_ram_set(&code_ram, address) = data[7];
        *(volatile uint32_t*)(CODE_RAM_BASE_ADDR + address) = 0x00000000;
        address += 4;
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
    asm ("j 0x2100");
}

int main()
{
    initialize_code_ram();
    load_code_through_qspi();
    update_trap_vector_base_address();
    jump_to_loaded_software();
    return 0;
}



