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

#include "qspi.h"
#include "uart.h"
#include "timer.h"
#include "core_portme.h"

int main(){
    init_uart();

    wait_for_us(500);

    qspi_set_ccr(
        /*inst_value*/       CMD_RESET,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    wait_for_us(500);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_READ_ID,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        1,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    ee_printf("READID: %x\n", QSPI_DR0);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_READ,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    ee_printf("READ1: %x\n", QSPI_DR0);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_RDCR,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    ee_printf("quad_enabled?: %x\n", QSPI_DR0);

    qspi_enable_quad_mode();

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_RDCR,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    ee_printf("quad_enabled: %x\n", QSPI_DR0);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_QOR,
        /*data_mod*/         3,
        /*wr_flash*/         0,
        /*dummy_cycle*/      8, // if below 50mhz it can be 0
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    ee_printf("DR0: %x\n", QSPI_DR0);
    ee_printf("DR1: %x\n", QSPI_DR1);
    ee_printf("DR2: %x\n", QSPI_DR2);
    ee_printf("DR3: %x\n", QSPI_DR3);
    ee_printf("DR4: %x\n", QSPI_DR4);
    ee_printf("DR5: %x\n", QSPI_DR5);
    ee_printf("DR6: %x\n", QSPI_DR6);
    ee_printf("DR7: %x\n", QSPI_DR7);

    qspi_disable_quad_mode();
    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_RDCR,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    ee_printf("quad_disabled?: %x\n", QSPI_DR0);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_READ,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_SE,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_DR0 = 0xaaaaaaaa;
    QSPI_DR1 = 0xaaaaaaaa;
    QSPI_DR2 = 0xaaaaaaaa;
    QSPI_DR3 = 0xaaaaaaaa;
    QSPI_DR4 = 0xaaaaaaaa;
    QSPI_DR5 = 0xaaaaaaaa;
    QSPI_DR6 = 0xaaaaaaaa;
    QSPI_DR7 = 0xaaaaaaaa;

    ee_printf("DR0: %x\n", QSPI_DR0);
    ee_printf("DR1: %x\n", QSPI_DR1);
    ee_printf("DR2: %x\n", QSPI_DR2);
    ee_printf("DR3: %x\n", QSPI_DR3);
    ee_printf("DR4: %x\n", QSPI_DR4);
    ee_printf("DR5: %x\n", QSPI_DR5);
    ee_printf("DR6: %x\n", QSPI_DR6);
    ee_printf("DR7: %x\n", QSPI_DR7);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_PP,
        /*data_mod*/         1,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    ee_printf("DR0: %x\n", QSPI_DR0);
    ee_printf("DR1: %x\n", QSPI_DR1);
    ee_printf("DR2: %x\n", QSPI_DR2);
    ee_printf("DR3: %x\n", QSPI_DR3);
    ee_printf("DR4: %x\n", QSPI_DR4);
    ee_printf("DR5: %x\n", QSPI_DR5);
    ee_printf("DR6: %x\n", QSPI_DR6);
    ee_printf("DR7: %x\n", QSPI_DR7);

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_RDCR,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    ee_printf("quad_enabled?: %x\n", QSPI_DR0);

    qspi_enable_quad_mode();

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_RDCR,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    ee_printf("quad_enabled: %x\n", QSPI_DR0);

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_DR0 = 0xbbbbbbbb;
    QSPI_DR1 = 0xbbbbbbbb;
    QSPI_DR2 = 0xbbbbbbbb;
    QSPI_DR3 = 0xbbbbbbbb;
    QSPI_DR4 = 0xbbbbbbbb;
    QSPI_DR5 = 0xbbbbbbbb;
    QSPI_DR6 = 0xbbbbbbbb;
    QSPI_DR7 = 0xbbbbbbbb;

    QSPI_ADR = 0x00000f00;
    qspi_set_ccr(
        /*inst_value*/       CMD_QPP,
        /*data_mod*/         3,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    qspi_set_ccr(
        /*inst_value*/       CMD_WRDI,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_down();

    QSPI_ADR = 0x00000000;
    qspi_set_ccr(
        /*inst_value*/       CMD_QOR,
        /*data_mod*/         3,
        /*wr_flash*/         0,
        /*dummy_cycle*/      8,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    QSPI_ADR = 0x00000f00;
    qspi_set_ccr(
        /*inst_value*/       CMD_QOR,
        /*data_mod*/         3,
        /*wr_flash*/         0,
        /*dummy_cycle*/      8,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    ee_printf("DR0: %x\n", QSPI_DR0);
    ee_printf("DR1: %x\n", QSPI_DR1);
    ee_printf("DR2: %x\n", QSPI_DR2);
    ee_printf("DR3: %x\n", QSPI_DR3);
    ee_printf("DR4: %x\n", QSPI_DR4);
    ee_printf("DR5: %x\n", QSPI_DR5);
    ee_printf("DR6: %x\n", QSPI_DR6);
    ee_printf("DR7: %x\n", QSPI_DR7);

    return 0;
}
