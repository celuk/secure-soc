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

#include "timer.h"
#include "defines.h"

void init_timer()
{
    //TIM_PRE = 0;
    //TIM_ENA = 1;
    //TIM_MOD = 1;

    timer_set_clr(1);
    timer_set_evc(1);
    timer_set_pre(0);
    timer_set_are(0xFFFFFFFF);
    timer_set_ena(1);
    timer_set_mod(1);
    timer_set_evc(0);
    timer_set_clr(0);
}

void timer_set_pre (unsigned int pre){
    TIM_PRE = pre;
}

int timer_get_pre (){
    return TIM_PRE;
}

void timer_set_are (unsigned int are){
    TIM_ARE = are;
}

int timer_get_are (){
    return TIM_ARE;
}

void timer_set_clr (unsigned int clr){
    TIM_CLR = clr;
}

int timer_get_clr (){
    return TIM_CLR;
}

void timer_set_ena (unsigned int ena){
    TIM_ENA = ena;
}

int timer_get_ena (){
    return TIM_ENA;
}

void timer_set_mod (unsigned int mod){
    TIM_MOD = mod;
}

int timer_get_mod (){
    return TIM_MOD;
}

int timer_get_cnt (){
    return TIM_CNT;
}

int timer_get_evn (){
    return TIM_EVN;
}

void timer_set_evc (unsigned int evc){
    TIM_EVC = evc;
}

int timer_get_evc (){
    return TIM_EVC;
}

void wait_for(uint32_t time){
    init_timer();
	uint32_t start = timer_get_cnt();
	uint32_t end = timer_get_cnt();
    uint32_t diff = end - start;
	while(((diff)) < time){
		end = timer_get_cnt();
        if(end > start)
            diff = end - start;
        else
            diff = start - end;
	}
}

void wait_for_us(uint32_t time){
    wait_for(US(time));
}
