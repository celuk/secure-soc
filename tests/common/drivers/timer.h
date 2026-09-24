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

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

#define TIM_BASE_ADDR  0xFF050000
#define TIM_PRE_OFFSET 0x00
#define TIM_ARE_OFFSET 0x04
#define TIM_CLR_OFFSET 0x08
#define TIM_ENA_OFFSET 0x0C
#define TIM_MOD_OFFSET 0x10
#define TIM_CNT_OFFSET 0x14
#define TIM_EVN_OFFSET 0x18
#define TIM_EVC_OFFSET 0x1C

#define TIM_PRE (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_PRE_OFFSET))
#define TIM_ARE (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_ARE_OFFSET))
#define TIM_CLR (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_CLR_OFFSET))
#define TIM_ENA (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_ENA_OFFSET))
#define TIM_MOD (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_MOD_OFFSET))
#define TIM_CNT (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_CNT_OFFSET))
#define TIM_EVN (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_EVN_OFFSET))
#define TIM_EVC (*(volatile uint32_t*) (TIM_BASE_ADDR + TIM_EVC_OFFSET))

void init_timer();
void timer_set_pre (unsigned int pre);
int timer_get_pre ();
void timer_set_are (unsigned int are);
int timer_get_are ();
void timer_set_clr (unsigned int clr);
int timer_get_clr ();
void timer_set_ena (unsigned int ena);
int timer_get_ena ();
void timer_set_mod (unsigned int mod);
int timer_get_mod ();
int timer_get_cnt ();
int timer_get_evn ();
void timer_set_evc (unsigned int evc);
int timer_get_evc ();
void wait_for(uint32_t time);
void wait_for_us(uint32_t time);

#endif
