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

module ctr_enc_dec #(parameter KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210) (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [31:0] row_number,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out
);

    wire [31:0] keystream_val;

    ctr_keystream_generator keygen (
        .key        (KEY),
        .row_number (row_number),
        .keystream  (keystream_val)
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            data_out <= '0;
        end else begin
            data_out <= data_in ^ keystream_val;
        end
    end
endmodule
