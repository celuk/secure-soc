// PRINCE Lightweight Block Cipher
// Adapted from "PRINCE – A Low-Latency Block Cipher for Pervasive Computing" paper and reference implementation:
// https://github.com/huljar/prince-vhdl

module prince_enc_dec #(
    parameter [127:0] KEY = 128'hDEADBEEF_CAFEF00D_BAADF00D_12345678
) (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [31:0] addr,
    input  wire [31:0] data_in,
    input  wire        mode,      // 0 = encrypt, 1 = decrypt
    output reg  [31:0] data_out
);

    wire [63:0] block_in  = {addr, data_in};
    wire [63:0] block_out;

    // Key decomposition
    wire [63:0] k0 = KEY[127:64];
    wire [63:0] k1 = KEY[63:0];

    // k0' derived key per PRINCE spec: rotate right by 1 and XOR bit 0 into MSB
    wire [63:0] k0_prime = {k0[0], k0[63:2], k0[1] ^ k0[63]};

    // Alpha constant for decryption
    localparam [63:0] ALPHA = 64'hC0AC29B7C97C50DD;

    // Whitening keys depend on mode
    wire [63:0] k_pre  = (mode == 1'b0) ? k0       : k0_prime;
    wire [63:0] k_post = (mode == 1'b0) ? k0_prime  : k0;
    wire [63:0] k_core = (mode == 1'b0) ? k1        : (k1 ^ ALPHA);

    // Core input/output
    wire [63:0] core_in  = block_in ^ k_pre;
    wire [63:0] core_out;

    assign block_out = core_out ^ k_post;

    // PRINCE core - purely combinational
    prince_core_combinational i_prince_core (
        .data_in  (core_in),
        .key      (k_core),
        .data_out (core_out)
    );

    // Register output
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            data_out <= '0;
        else
            data_out <= block_out[31:0];
    end

endmodule


// PRINCE core: 12 rounds (round 0 through 11), fully combinational.
// Round structure:
//   R0:     XOR key, XOR RC0
//   R1–R5:  S-box --> M layer --> XOR key, XOR RCi
//   Middle: S-box --> M' --> S-box^-1
//   R6–R10: XOR key, XOR RCi --> M^-1 --> S-box^-1
//   R11:    XOR key, XOR RC11
module prince_core_combinational (
    input  wire [63:0] data_in,
    input  wire [63:0] key,
    output wire [63:0] data_out
);

    // Round constants
    localparam [63:0] RC0  = 64'h0000000000000000;
    localparam [63:0] RC1  = 64'h13198A2E03707344;
    localparam [63:0] RC2  = 64'hA4093822299F31D0;
    localparam [63:0] RC3  = 64'h082EFA98EC4E6C89;
    localparam [63:0] RC4  = 64'h452821E638D01377;
    localparam [63:0] RC5  = 64'hBE5466CF34E90C6C;
    localparam [63:0] RC6  = 64'h7EF84F78FD955CB1;
    localparam [63:0] RC7  = 64'h85840851F1AC43AA;
    localparam [63:0] RC8  = 64'hC882D32F25323C54;
    localparam [63:0] RC9  = 64'h64A51195E0E3610D;
    localparam [63:0] RC10 = 64'hD3B5A399CA0C2399;
    localparam [63:0] RC11 = 64'hC0AC29B7C97C50DD;

    // S-box lookup (PRINCE 4-bit S-box)
    function automatic [3:0] sbox;
        input [3:0] x;
        case (x)
            4'h0: sbox = 4'hB;
            4'h1: sbox = 4'hF;
            4'h2: sbox = 4'h3;
            4'h3: sbox = 4'h2;
            4'h4: sbox = 4'hA;
            4'h5: sbox = 4'hC;
            4'h6: sbox = 4'h9;
            4'h7: sbox = 4'h1;
            4'h8: sbox = 4'h6;
            4'h9: sbox = 4'h7;
            4'hA: sbox = 4'h8;
            4'hB: sbox = 4'h0;
            4'hC: sbox = 4'hE;
            4'hD: sbox = 4'h5;
            4'hE: sbox = 4'hD;
            4'hF: sbox = 4'h4;
            default: sbox = 4'hx;
        endcase
    endfunction

    // Inverse S-box
    function automatic [3:0] sbox_inv;
        input [3:0] x;
        case (x)
            4'h0: sbox_inv = 4'hB;
            4'h1: sbox_inv = 4'h7;
            4'h2: sbox_inv = 4'h3;
            4'h3: sbox_inv = 4'h2;
            4'h4: sbox_inv = 4'hF;
            4'h5: sbox_inv = 4'hD;
            4'h6: sbox_inv = 4'h8;
            4'h7: sbox_inv = 4'h9;
            4'h8: sbox_inv = 4'hA;
            4'h9: sbox_inv = 4'h6;
            4'hA: sbox_inv = 4'h4;
            4'hB: sbox_inv = 4'h0;
            4'hC: sbox_inv = 4'h5;
            4'hD: sbox_inv = 4'hE;
            4'hE: sbox_inv = 4'hC;
            4'hF: sbox_inv = 4'h1;
            default: sbox_inv = 4'hx;
        endcase
    endfunction

    // Apply S-box to all 16 nibbles
    function automatic [63:0] apply_sbox;
        input [63:0] d;
        integer i;
        for (i = 0; i < 16; i = i + 1)
            apply_sbox[4*i +: 4] = sbox(d[4*i +: 4]);
    endfunction

    // Apply inverse S-box to all 16 nibbles
    function automatic [63:0] apply_sbox_inv;
        input [63:0] d;
        integer i;
        for (i = 0; i < 16; i = i + 1)
            apply_sbox_inv[4*i +: 4] = sbox_inv(d[4*i +: 4]);
    endfunction

    // M' matrix multiplication
    function automatic [63:0] mprime;
        input [63:0] d;
        begin
            mprime[63] = d[59] ^ d[55] ^ d[51];
            mprime[62] = d[62] ^ d[54] ^ d[50];
            mprime[61] = d[61] ^ d[57] ^ d[49];
            mprime[60] = d[60] ^ d[56] ^ d[52];
            mprime[59] = d[63] ^ d[59] ^ d[55];
            mprime[58] = d[58] ^ d[54] ^ d[50];
            mprime[57] = d[61] ^ d[53] ^ d[49];
            mprime[56] = d[60] ^ d[56] ^ d[48];
            mprime[55] = d[63] ^ d[59] ^ d[51];
            mprime[54] = d[62] ^ d[58] ^ d[54];
            mprime[53] = d[57] ^ d[53] ^ d[49];
            mprime[52] = d[60] ^ d[52] ^ d[48];
            mprime[51] = d[63] ^ d[55] ^ d[51];
            mprime[50] = d[62] ^ d[58] ^ d[50];
            mprime[49] = d[61] ^ d[57] ^ d[53];
            mprime[48] = d[56] ^ d[52] ^ d[48];
            mprime[47] = d[47] ^ d[43] ^ d[39];
            mprime[46] = d[42] ^ d[38] ^ d[34];
            mprime[45] = d[45] ^ d[37] ^ d[33];
            mprime[44] = d[44] ^ d[40] ^ d[32];
            mprime[43] = d[47] ^ d[43] ^ d[35];
            mprime[42] = d[46] ^ d[42] ^ d[38];
            mprime[41] = d[41] ^ d[37] ^ d[33];
            mprime[40] = d[44] ^ d[36] ^ d[32];
            mprime[39] = d[47] ^ d[39] ^ d[35];
            mprime[38] = d[46] ^ d[42] ^ d[34];
            mprime[37] = d[45] ^ d[41] ^ d[37];
            mprime[36] = d[40] ^ d[36] ^ d[32];
            mprime[35] = d[43] ^ d[39] ^ d[35];
            mprime[34] = d[46] ^ d[38] ^ d[34];
            mprime[33] = d[45] ^ d[41] ^ d[33];
            mprime[32] = d[44] ^ d[40] ^ d[36];
            mprime[31] = d[31] ^ d[27] ^ d[23];
            mprime[30] = d[26] ^ d[22] ^ d[18];
            mprime[29] = d[29] ^ d[21] ^ d[17];
            mprime[28] = d[28] ^ d[24] ^ d[16];
            mprime[27] = d[31] ^ d[27] ^ d[19];
            mprime[26] = d[30] ^ d[26] ^ d[22];
            mprime[25] = d[25] ^ d[21] ^ d[17];
            mprime[24] = d[28] ^ d[20] ^ d[16];
            mprime[23] = d[31] ^ d[23] ^ d[19];
            mprime[22] = d[30] ^ d[26] ^ d[18];
            mprime[21] = d[29] ^ d[25] ^ d[21];
            mprime[20] = d[24] ^ d[20] ^ d[16];
            mprime[19] = d[27] ^ d[23] ^ d[19];
            mprime[18] = d[30] ^ d[22] ^ d[18];
            mprime[17] = d[29] ^ d[25] ^ d[17];
            mprime[16] = d[28] ^ d[24] ^ d[20];
            mprime[15] = d[11] ^ d[7]  ^ d[3];
            mprime[14] = d[14] ^ d[6]  ^ d[2];
            mprime[13] = d[13] ^ d[9]  ^ d[1];
            mprime[12] = d[12] ^ d[8]  ^ d[4];
            mprime[11] = d[15] ^ d[11] ^ d[7];
            mprime[10] = d[10] ^ d[6]  ^ d[2];
            mprime[9]  = d[13] ^ d[5]  ^ d[1];
            mprime[8]  = d[12] ^ d[8]  ^ d[0];
            mprime[7]  = d[15] ^ d[11] ^ d[3];
            mprime[6]  = d[14] ^ d[10] ^ d[6];
            mprime[5]  = d[9]  ^ d[5]  ^ d[1];
            mprime[4]  = d[12] ^ d[4]  ^ d[0];
            mprime[3]  = d[15] ^ d[7]  ^ d[3];
            mprime[2]  = d[14] ^ d[10] ^ d[2];
            mprime[1]  = d[13] ^ d[9]  ^ d[5];
            mprime[0]  = d[8]  ^ d[4]  ^ d[0];
        end
    endfunction

    // M = M' followed by nibble-wise shift rows
    function automatic [63:0] linear_m;
        input [63:0] d;
        reg [63:0] mp;
        begin
            mp = mprime(d);
            linear_m[63:60] = mp[63:60];
            linear_m[59:56] = mp[43:40];
            linear_m[55:52] = mp[23:20];
            linear_m[51:48] = mp[3:0];
            linear_m[47:44] = mp[47:44];
            linear_m[43:40] = mp[27:24];
            linear_m[39:36] = mp[7:4];
            linear_m[35:32] = mp[51:48];
            linear_m[31:28] = mp[31:28];
            linear_m[27:24] = mp[11:8];
            linear_m[23:20] = mp[55:52];
            linear_m[19:16] = mp[35:32];
            linear_m[15:12] = mp[15:12];
            linear_m[11:8]  = mp[59:56];
            linear_m[7:4]   = mp[39:36];
            linear_m[3:0]   = mp[19:16];
        end
    endfunction

    // M^-1 = inverse shift rows followed by M'
    function automatic [63:0] linear_m_inv;
        input [63:0] d;
        reg [63:0] mp_in;
        begin
            mp_in[63:60] = d[63:60];
            mp_in[59:56] = d[11:8];
            mp_in[55:52] = d[23:20];
            mp_in[51:48] = d[35:32];
            mp_in[47:44] = d[47:44];
            mp_in[43:40] = d[59:56];
            mp_in[39:36] = d[7:4];
            mp_in[35:32] = d[19:16];
            mp_in[31:28] = d[31:28];
            mp_in[27:24] = d[43:40];
            mp_in[23:20] = d[55:52];
            mp_in[19:16] = d[3:0];
            mp_in[15:12] = d[15:12];
            mp_in[11:8]  = d[27:24];
            mp_in[7:4]   = d[39:36];
            mp_in[3:0]   = d[51:48];
            linear_m_inv = mprime(mp_in);
        end
    endfunction

    wire [63:0] ims0, ims1, ims2, ims3, ims4, ims5;
    wire [63:0] ims6, ims7, ims8, ims9, ims10, ims11;
    wire [63:0] sb1, sb2, sb3, sb4, sb5;
    wire [63:0] m1, m2, m3, m4, m5;
    wire [63:0] middle1, middle2;
    wire [63:0] mi6, mi7, mi8, mi9, mi10;
    wire [63:0] si6, si7, si8, si9, si10;

    // Round 0: key addition + round constant
    assign ims0 = data_in ^ key ^ RC0;

    // Rounds 1–5: S-box --> M --> key + RC
    assign sb1 = apply_sbox(ims0);
    assign m1  = linear_m(sb1);
    assign ims1 = m1 ^ key ^ RC1;

    assign sb2 = apply_sbox(ims1);
    assign m2  = linear_m(sb2);
    assign ims2 = m2 ^ key ^ RC2;

    assign sb3 = apply_sbox(ims2);
    assign m3  = linear_m(sb3);
    assign ims3 = m3 ^ key ^ RC3;

    assign sb4 = apply_sbox(ims3);
    assign m4  = linear_m(sb4);
    assign ims4 = m4 ^ key ^ RC4;

    assign sb5 = apply_sbox(ims4);
    assign m5  = linear_m(sb5);
    assign ims5 = m5 ^ key ^ RC5;

    // Middle layer: S-box --> M' --> S-box^-1
    assign middle1 = apply_sbox(ims5);
    assign middle2 = mprime(middle1);
    assign ims6    = apply_sbox_inv(middle2);

    // Rounds 6–10: key + RC --> M^-1 --> S-box^-1
    assign mi6  = ims6  ^ key ^ RC6;
    assign si6  = linear_m_inv(mi6);
    assign ims7 = apply_sbox_inv(si6);

    assign mi7  = ims7  ^ key ^ RC7;
    assign si7  = linear_m_inv(mi7);
    assign ims8 = apply_sbox_inv(si7);

    assign mi8  = ims8  ^ key ^ RC8;
    assign si8  = linear_m_inv(mi8);
    assign ims9 = apply_sbox_inv(si8);

    assign mi9  = ims9  ^ key ^ RC9;
    assign si9  = linear_m_inv(mi9);
    assign ims10 = apply_sbox_inv(si9);

    assign mi10  = ims10 ^ key ^ RC10;
    assign si10  = linear_m_inv(mi10);
    assign ims11 = apply_sbox_inv(si10);

    // Round 11: key + round constant
    assign data_out = ims11 ^ key ^ RC11;

endmodule
