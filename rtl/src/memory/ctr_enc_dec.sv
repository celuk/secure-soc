module ctr_encoder_decoder #(parameter KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210) (
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
