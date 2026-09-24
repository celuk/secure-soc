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


module uart_controller_obi (
   input  wire        clk_i,
   input  wire        rst_ni,
   input  wire        req_i,
   input  wire        we_i,
   input  wire [ 3:0] be_i,
   output wire        gnt_o,
   input  wire [31:0] addr_i,
   input  wire [31:0] wdata_i,
   output reg         rvalid_o,
   output reg  [31:0] rdata_o,
   input  wire        rx_i,
   output wire        tx_o
);

   reg         wb_cyc_r;
   reg         wb_stb_r;
   wire        wb_ack_w;
   wire [31:0] wb_dat_o_w;

   uart_controller uart_iface_dut (
      .clk_i    (clk_i),
      .rst_i    (~rst_ni),
      .wb_adr_i (addr_i),
      .wb_dat_i (wdata_i),
      .wb_we_i  (we_i),
      .wb_stb_i (wb_stb_r),
      .wb_sel_i (be_i),
      .wb_cyc_i (wb_cyc_r),
      .wb_ack_o (wb_ack_w),
      .wb_dat_o (wb_dat_o_w),
      .uart_rx_i(rx_i),
      .uart_tx_o(tx_o)
   );

   always @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
         wb_cyc_r <= 1'b0;
         wb_stb_r <= 1'b0;
         rvalid_o <= 1'b0;
         rdata_o  <= 32'b0;
      end else begin
         if (req_i && gnt_o) begin
            wb_cyc_r <= 1'b1;
            wb_stb_r <= 1'b1;
         end else if (wb_ack_w) begin
            wb_cyc_r <= 1'b0;
            wb_stb_r <= 1'b0;
         end

         rvalid_o <= wb_ack_w;
         if (wb_ack_w) begin
            rdata_o <= wb_dat_o_w;
         end
      end
   end

   assign gnt_o = ~wb_cyc_r;

endmodule
