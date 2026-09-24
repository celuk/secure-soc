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

#ifndef QSPI_H
#define QSPI_H

#include <stdint.h>

#define QSPI_BASE_ADDR  0xFF010000
#define QSPI_CCR_OFFSET 0x00
#define QSPI_ADR_OFFSET 0x04
#define QSPI_DR0_OFFSET 0x08
#define QSPI_DR1_OFFSET 0x0C
#define QSPI_DR2_OFFSET 0x10
#define QSPI_DR3_OFFSET 0x14
#define QSPI_DR4_OFFSET 0x18
#define QSPI_DR5_OFFSET 0x1C
#define QSPI_DR6_OFFSET 0x20
#define QSPI_DR7_OFFSET 0x24
#define QSPI_STA_OFFSET 0x28

#define QSPI_CCR (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_CCR_OFFSET))
#define QSPI_ADR (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_ADR_OFFSET))
#define QSPI_DR0 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR0_OFFSET))
#define QSPI_DR1 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR1_OFFSET))
#define QSPI_DR2 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR2_OFFSET))
#define QSPI_DR3 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR3_OFFSET))
#define QSPI_DR4 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR4_OFFSET))
#define QSPI_DR5 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR5_OFFSET))
#define QSPI_DR6 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR6_OFFSET))
#define QSPI_DR7 (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_DR7_OFFSET))
#define QSPI_STA (*(volatile uint32_t*) (QSPI_BASE_ADDR + QSPI_STA_OFFSET))

// QSPI Commands
#define CMD_READ 0x03
#define CMD_DOR 0x3B
#define CMD_QOR 0x6B
#define CMD_PP 0x02
#define CMD_QPP 0x32
#define CMD_SE 0xD8
#define CMD_READ_ID 0x90
#define CMD_RDID 0x9F
#define CMD_RES 0xAB
#define CMD_RDSR1 0x05
#define CMD_RDSR2 0x07
#define CMD_RDCR 0x35
#define CMD_WRR 0x01
#define CMD_WRDI 0x04
#define CMD_WREN 0x06
#define CMD_CLSR 0x30
#define CMD_RESET 0xF0

typedef union
{
	struct {
        // the least significant bit is at the beginning
		unsigned int inst_value         : 8;
		unsigned int data_mod 	        : 2;
		unsigned int wr_flash	        : 1;
		unsigned int dummy_cycle        : 5;
        // number of bytes to read: data_size + 1
        unsigned int data_size          : 9;
        unsigned int prescaler          : 6;
        unsigned int clear_status_reg   : 1;
	} fields;
	uint32_t bits;
}qspi_ccr;

typedef union
{
	struct {
        // the least significant bit is at the beginning
		unsigned int transaction_done : 1;
        unsigned int busy             : 1;
        unsigned int reserved         : 30;
	} fields;
	uint32_t bits;
}qspi_sta;

void qspi_init(); //(unsigned int time);
void qspi_set_ccr(unsigned int inst_value, unsigned int data_mod, unsigned int wr_flash, unsigned int dummy_cycle, unsigned int data_size, unsigned int prescaler, unsigned int clear_status_reg);
void wait_for_not_busy();
unsigned int read_status_register(unsigned int cmd);
void wait_for_wel_set();
void wait_for_wip_done();
void wait_for_wel_down();
void qspi_enable_quad_mode();
void qspi_disable_quad_mode();

//void qspi_wait_for_not_busy();
//void qspi_wait_for_transaction_done();
//void qspi_write_enable();
//void qspi_write_disable();
//void qspi_clear_status_register();
//void qspi_reset();
//void qspi_read(uint32_t address, uint32_t* data, uint32_t size);
//void qspi_write(uint32_t address, uint32_t* data, uint32_t size);
//void qspi_erase_sector(uint32_t address);
//void qspi_read_id(uint32_t* data);
//void qspi_read_status_register(uint32_t* data);
//void qspi_read_status_register2(uint32_t* data);
//void qspi_read_configuration_register(uint32_t* data);
//void qspi_write_register(uint32_t address, uint32_t data);
//void qspi_read_register(uint32_t address, uint32_t* data);

#endif
