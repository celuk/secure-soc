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

`timescale 1ns / 1ps

module timer(
    input clk_i,
    input rst_i,
    input [31:0] TIM_PRE,
    input [31:0] TIM_ARE,
    input [31:0] TIM_CLR,
    input [31:0] TIM_ENA,
    input [31:0] TIM_MOD,
    input [31:0] TIM_EVC,
    output [31:0] TIM_CNT,
    output [31:0] TIM_EVN
);

reg [31:0] TIM_CNT_R;
reg [31:0] TIM_CNT_NEXT_R;
reg [31:0] TIM_EVN_R;
reg [31:0] TIM_EVN_NEXT_R;

assign TIM_CNT = TIM_CNT_R;
assign TIM_EVN = TIM_EVN_R;

reg [63:0] counter;
reg [63:0] counter_next;

wire basa_don = TIM_CNT_R == TIM_ARE;
wire amount = (counter == TIM_PRE);

always_comb begin
    TIM_CNT_NEXT_R = TIM_CNT_R;
    TIM_EVN_NEXT_R = TIM_EVN_R;

    counter_next = counter + 1;
    if(counter == TIM_PRE) begin
        counter_next = 0;
    end

    if(TIM_ENA[0]) begin
        case({TIM_CLR[0], TIM_EVC[0], basa_don})
            3'b000: begin
                TIM_CNT_NEXT_R = TIM_MOD ? (TIM_CNT_R + amount) : (TIM_CNT_R - amount);
                TIM_EVN_NEXT_R = TIM_EVN_R;
                if(counter == TIM_PRE) begin
                    counter_next = 0;
                end else begin
                    counter_next = counter + 1;
                end
            end
            3'b001: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = TIM_EVN_R + 1;
                if(counter == TIM_PRE) begin
                    counter_next = 0;
                end else begin
                    counter_next = counter + 1;
                end
            end
            3'b010: begin
                TIM_CNT_NEXT_R = TIM_MOD ? (TIM_CNT_R + amount) : (TIM_CNT_R - amount);
                TIM_EVN_NEXT_R = 0;
                if(counter == TIM_PRE) begin
                    counter_next = 0;
                end else begin
                    counter_next = counter + 1;
                end
            end
            3'b011: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = 0;
                if(counter == TIM_PRE) begin
                    counter_next = 0;
                end else begin
                    counter_next = counter + 1;
                end
            end
            3'b100: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = TIM_EVN_R;
                counter_next = 0;
                
            end
            3'b101: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = TIM_EVN_R + 1;
                counter_next = 0;
            end
            3'b110: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = 0;
                counter_next = 0;
            end
            3'b111: begin
                TIM_CNT_NEXT_R = 0;
                TIM_EVN_NEXT_R = 0;
                counter_next = 0;
            end
        endcase  
    end else begin
        if(TIM_EVC[0]) begin
            TIM_EVN_NEXT_R = 0;
        end
    
        if(TIM_CLR[0]) begin
            TIM_CNT_NEXT_R = 0;
            counter_next = 0;     
        end
    end
end

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        TIM_CNT_R <= 0;
        TIM_EVN_R <= 0;
        counter <= 0;
    end
    else begin
        TIM_CNT_R <= TIM_CNT_NEXT_R;
        TIM_EVN_R <= TIM_EVN_NEXT_R;
        counter <= counter_next;
    end
end

endmodule