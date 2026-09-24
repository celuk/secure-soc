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

#include "defines.h"
#include "uart.h"
#include "timer.h"
#include "dram.h"

#define DDR3_AXI_BASE_ADDR 0x80000000

void write_to_ddr3(unsigned int offset_in_ddr, unsigned int data) {
    (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + offset_in_ddr)) = data;
}

unsigned int read_from_ddr3(unsigned int offset_in_ddr) {
    return (*(volatile uint32_t*)(DDR3_AXI_BASE_ADDR + offset_in_ddr));
}

int main()
{
    init_uart();
    init_timer();
    wait_for_us(500);

    write_to_ddr3(0x100, 0x1241BAEF);
    write_to_ddr3(0x200, 0x1241BEEF);
    write_to_ddr3(0x300, 0x1242BAEF);

    tekno_printf("Value read: %x\n", read_from_ddr3(0x200));

    return 0;
}
