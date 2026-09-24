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

// timer_controller.sv
`timescale 1ns / 1ps

`include "header.vh"

module timer_controller (
   input wire clk_i,
   input wire rst_i,

   input  wire [ 7:0] wb_adr_i,
   input  wire [31:0] wb_dat_i,
   input  wire        wb_we_i ,
   input  wire        wb_stb_i,
   input  wire [ 3:0] wb_sel_i,
   input  wire        wb_cyc_i,
   output reg         wb_ack_o,
   output reg  [31:0] wb_dat_o
   
);

reg [31:0] wb_read_data_r;
reg [31:0] wb_read_data_next_r;
assign wb_dat_o = wb_read_data_r;

reg wb_ack_r;
reg wb_ack_next_r;
assign wb_ack_o = wb_ack_r;

reg [31:0] TIM_PRE;
reg [31:0] TIM_PRE_NEXT;
reg [31:0] TIM_ARE;
reg [31:0] TIM_ARE_NEXT;
reg [31:0] TIM_CLR;
reg [31:0] TIM_CLR_NEXT;
reg [31:0] TIM_ENA;
reg [31:0] TIM_ENA_NEXT;
reg [31:0] TIM_MOD;
reg [31:0] TIM_MOD_NEXT;
reg [31:0] TIM_EVC;
reg [31:0] TIM_EVC_NEXT;

wire[31:0] TIM_CNT;
wire[31:0] TIM_EVN;

always_comb begin
   wb_ack_next_r = 0;
   wb_read_data_next_r = 0;
   TIM_PRE_NEXT = TIM_PRE;
   TIM_ARE_NEXT = TIM_ARE;
   TIM_CLR_NEXT = TIM_CLR;
   TIM_ENA_NEXT = TIM_ENA;
   TIM_MOD_NEXT = TIM_MOD;
   TIM_EVC_NEXT = TIM_EVC;

   if(wb_cyc_i) begin
      wb_ack_next_r = wb_stb_i & !wb_ack_r;
      if(wb_stb_i & wb_we_i & !wb_ack_o) begin // write
         case(wb_adr_i)
            8'h00: begin
               TIM_PRE_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_PRE[7:0  ];
               TIM_PRE_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_PRE[15:8 ];
               TIM_PRE_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_PRE[23:16];
               TIM_PRE_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_PRE[31:24];
            end
            8'h04: begin
               TIM_ARE_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_ARE[7:0  ];
               TIM_ARE_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_ARE[15:8 ];
               TIM_ARE_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_ARE[23:16];
               TIM_ARE_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_ARE[31:24];
            end
            8'h08: begin
               TIM_CLR_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_CLR[7:0  ];
               TIM_CLR_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_CLR[15:8 ];
               TIM_CLR_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_CLR[23:16];
               TIM_CLR_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_CLR[31:24];
            end
            8'h0C: begin
               TIM_ENA_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_ENA[7:0  ];
               TIM_ENA_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_ENA[15:8 ];
               TIM_ENA_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_ENA[23:16];
               TIM_ENA_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_ENA[31:24];
            end
            8'h10: begin
               TIM_MOD_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_MOD[7:0  ];
               TIM_MOD_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_MOD[15:8 ];
               TIM_MOD_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_MOD[23:16];
               TIM_MOD_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_MOD[31:24];
            end
            8'h1C: begin
               TIM_EVC_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : TIM_EVC[7:0  ];
               TIM_EVC_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : TIM_EVC[15:8 ];
               TIM_EVC_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : TIM_EVC[23:16];
               TIM_EVC_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : TIM_EVC[31:24];
            end
         endcase
      end 
      else if(~wb_we_i) begin // read
         case(wb_adr_i)
            8'h00: begin
               wb_read_data_next_r = TIM_PRE;
            end
            8'h04: begin
               wb_read_data_next_r = TIM_ARE;
            end
            8'h08: begin
               wb_read_data_next_r = TIM_CLR;
            end
            8'h0C: begin
               wb_read_data_next_r = TIM_ENA;
            end
            8'h10: begin
               wb_read_data_next_r = TIM_MOD;
            end
            8'h14: begin
               wb_read_data_next_r = TIM_CNT;
            end
            8'h18: begin
               wb_read_data_next_r = TIM_EVN;
            end
            8'h1C: begin
               wb_read_data_next_r = TIM_EVC;
            end
         endcase
      end
   end
end

always_ff @(posedge clk_i) begin
   if (rst_i) begin
      wb_ack_r <= 0;
      wb_read_data_r <= 0;

      TIM_PRE <= 0;
      TIM_ARE <= 0;
      TIM_CLR <= 0;
      TIM_ENA <= 0;
      TIM_MOD <= 0;
      TIM_EVC <= 0;
   end else begin
      wb_ack_r <= wb_ack_next_r;
      wb_read_data_r <= wb_read_data_next_r;

      TIM_PRE <= TIM_PRE_NEXT;
      TIM_ARE <= TIM_ARE_NEXT;
      TIM_CLR <= TIM_CLR_NEXT;
      TIM_ENA <= TIM_ENA_NEXT;
      TIM_MOD <= TIM_MOD_NEXT;
      TIM_EVC <= TIM_EVC_NEXT;
   end 
   
end

timer tt(
   .clk_i(clk_i),
   .rst_i(rst_i),
   .TIM_PRE(TIM_PRE),
   .TIM_ARE(TIM_ARE),
   .TIM_CLR(TIM_CLR),
   .TIM_ENA(TIM_ENA),
   .TIM_MOD(TIM_MOD),
   .TIM_EVC(TIM_EVC),
   .TIM_CNT(TIM_CNT),
   .TIM_EVN(TIM_EVN)
);

endmodule
