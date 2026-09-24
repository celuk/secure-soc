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

#include <stdint.h>
#include "timer.h"

#define DDR3_AXI_BASE_ADDR 0x80000000

void init()
{
    init_timer();
    wait_for_us(500);
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x80000000 \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_dram()
{
    asm volatile (
        "lui   t0, 0x80000 \n"
        "addi  t0, t0, 0x100 \n"
        "jalr  x0, t0, 0 \n"
    );
}

int main()
{
    init();
    update_trap_vector_base_address();
    jump_to_dram();
    return 0;
}
