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

module ctr_keystream_generator (
    input  wire [255:0] key,
    input  wire [31:0]  row_number,
    output wire [31:0]  keystream
);

    wire [255:0] temp_0;
    wire [255:0] temp_1;
    wire [255:0] temp_2;
    wire [255:0] temp_3;

    assign temp_0 = key ^ {8{row_number}};
    assign temp_1 = temp_0 ^ (temp_0 << 13) ^ (temp_0 >> 17);
    assign temp_2 = temp_1 + {8{32'h9E3779B9}};
    assign temp_3 = temp_2 ^ (temp_2 << 7) ^ (temp_2 >> 12);

    assign keystream = temp_3[255:224] ^ temp_3[223:192] ^ temp_3[191:160] ^ temp_3[159:128] ^
                       temp_3[127:96]  ^ temp_3[95:64]   ^ temp_3[63:32]   ^ temp_3[31:0];
endmodule
