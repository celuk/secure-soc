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

// uart_verici.v
`timescale 1ns / 1ps


// RX paketleri circuilar bir queue ya konulur.
module uart_rx (
   input  wire        clk_i,
   input  wire        rst_i,
   input  wire [15:0] baud_div_i,
   input  wire        re_i,
   input  wire [ 1:0] stop_bit_i,
   input  wire        stall_i,
   output wire [ 7:0] data_o,
   output wire        full_o,
   output wire        empty_o,
   input  wire        rx_i
);

   reg [4:0] state;
   reg [4:0] next;

   localparam IDLE      = 4'd0,
              START_BIT = 4'd1,
              DATA_0    = 4'd2,
              DATA_1    = 4'd3,
              DATA_2    = 4'd4,
              DATA_3    = 4'd5,
              DATA_4    = 4'd6,
              DATA_5    = 4'd7,
              DATA_6    = 4'd8,
              DATA_7    = 4'd9,
              STOP_BIT_ONLY_ONE     = 4'd10,
              STOP_BIT_ONE_________ = 4'd11,
              STOP_BIT_ONE_AND_HALF = 4'd12,
              STOP_BIT_ONE_OF_TWO   = 4'd13,
              STOP_BIT_TWO_OF_TWO   = 4'd14;

   reg  [ 7:0] queue                [1:0];
   reg  [ 0:0] read_ptr;
   reg  [ 0:0] write_ptr;
   reg  [15:0] counter;
   reg         uart_clk_pulse;

   wire [ 4:0] limit = read_ptr - 1;
   assign full_o  = (limit == write_ptr);
   assign empty_o = (read_ptr == write_ptr);
   assign data_o  = queue[read_ptr];

   reg [3:0] start_pattern;
   reg       start_r;

   always @(posedge clk_i) begin
      if (rst_i) state <= IDLE;
      else if (uart_clk_pulse) state <= next;

      if (rst_i) begin
         read_ptr       <= 0;
         write_ptr      <= 0;
         counter        <= 0;
         uart_clk_pulse <= 0;
         start_pattern  <= 0;
         start_r        <= 0;
      end else begin
         if (re_i) begin
            read_ptr <= read_ptr + 1;
         end
         if (uart_clk_pulse) begin
            if ((state == STOP_BIT_ONLY_ONE) && (next == IDLE) && rx_i) begin
               write_ptr <= write_ptr + 1;
               start_r   <= 1'b0;
            end
            if ((state == STOP_BIT_ONLY_ONE) && (next == IDLE) && !rx_i) begin
               start_r <= 1'b0;
               queue[write_ptr] <= 0;
            end
            if ((state == STOP_BIT_ONE_AND_HALF) && (next == IDLE) && rx_i) begin
               write_ptr <= write_ptr + 1;
               start_r   <= 1'b0;
            end
            if ((state == STOP_BIT_ONE_AND_HALF) && (next == IDLE) && !rx_i) begin
               start_r <= 1'b0;
               queue[write_ptr] <= 0;
            end
            if ((state == STOP_BIT_TWO_OF_TWO) && (next == IDLE) && rx_i) begin
               write_ptr <= write_ptr + 1;
               start_r   <= 1'b0;
            end
            if ((state == STOP_BIT_TWO_OF_TWO) && (next == IDLE) && !rx_i) begin
               start_r <= 1'b0;
               queue[write_ptr] <= 0;
            end
            case (state)
               DATA_0: queue[write_ptr][0] <= rx_i;
               DATA_1: queue[write_ptr][1] <= rx_i;
               DATA_2: queue[write_ptr][2] <= rx_i;
               DATA_3: queue[write_ptr][3] <= rx_i;
               DATA_4: queue[write_ptr][4] <= rx_i;
               DATA_5: queue[write_ptr][5] <= rx_i;
               DATA_6: queue[write_ptr][6] <= rx_i;
               DATA_7: queue[write_ptr][7] <= rx_i;
               default: begin
               end
            endcase
         end
         if (counter == baud_div_i) begin
            counter        <= (next == STOP_BIT_ONE_AND_HALF) ? (baud_div_i / 2) : 0;
            uart_clk_pulse <= 1'b1;
         end else begin
            if (start_r) counter <= counter + 1;
            uart_clk_pulse <= 1'b0;
         end
         start_pattern <= {start_pattern[2:0], rx_i};
      end
      if (start_pattern == 4'b1100) begin
         start_r <= 1'b1;
         if (~start_r) begin
            uart_clk_pulse <= 1'b1;
            counter <= baud_div_i;
         end
      end
   end

   always @(*) begin
      case (state)
         IDLE:      if (start_r && ~stall_i) next = START_BIT;
 else next = IDLE;
         START_BIT: next = DATA_0;
         DATA_0:    next = DATA_1;
         DATA_1:    next = DATA_2;
         DATA_2:    next = DATA_3;
         DATA_3:    next = DATA_4;
         DATA_4:    next = DATA_5;
         DATA_5:    next = DATA_6;
         DATA_6:    next = DATA_7;
         // verilog_format: off
         DATA_7: next = (stop_bit_i == 2'b00) ? STOP_BIT_ONLY_ONE     :
                        (stop_bit_i == 2'b01) ? STOP_BIT_ONE_________ :
                        (stop_bit_i == 2'b10) ? STOP_BIT_ONE_OF_TWO   :
                                                           IDLE       ;
         // verilog_format: on
         STOP_BIT_ONLY_ONE:     next = IDLE;
         STOP_BIT_ONE_________: next = rx_i ? STOP_BIT_ONE_AND_HALF : IDLE;
         STOP_BIT_ONE_AND_HALF: next = IDLE;
         STOP_BIT_ONE_OF_TWO:   next = rx_i ? STOP_BIT_TWO_OF_TWO : IDLE;
         STOP_BIT_TWO_OF_TWO:   next = IDLE;
         default:  next = IDLE;
      endcase
   end
endmodule
