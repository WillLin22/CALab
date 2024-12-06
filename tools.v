module decoder_2_4(
    input  wire [ 1:0] in,
    output wire [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  wire [ 3:0] in,
    output wire [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule

module encoder_16_4(
    input  wire [15:0] in,
    output wire [ 3:0] out
);

assign out[0] = in[1] | in[3] | in[5] | in[7] | in[9] | in[11] | in[13] | in[15];
assign out[1] = in[2] | in[3] | in[6] | in[7] | in[10] | in[11] | in[14] | in[15];
assign out[2] = in[4] | in[5] | in[6] | in[7] | in[12] | in[13] | in[14] | in[15];
assign out[3] = in[8] | in[9] | in[10] | in[11] | in[12] | in[13] | in[14] | in[15];

endmodule

module encoder_16_check(
    input  wire [15:0] in,
    output wire error
);
wire [119:0]check;
genvar i, j;
generate
    for (i = 0; i < 15; i = i + 1) begin : gen_outer_loop
        for (j = i + 1; j < 16; j = j + 1) begin : gen_inner_loop
            assign check[(30-i+1)*i/2 + (j - i - 1)] = in[i] & in[j];
        end
    end
endgenerate
assign error = |check;
endmodule

module decoder_5_32(
    input  wire [ 4:0] in,
    output wire [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  wire [ 5:0] in,
    output wire [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module encoder_2_1 (
    input  wire [1:0] in,
    output wire out,
    output wire error
);
assign out = in[1];
assign error = &in;  
endmodule

module counter_ones_4_2(
    input wire [3:0] in,
    output reg [2:0] out
);
always @(*) begin
    case (in)
        4'b0000: out = 2'b00;
        4'b0001: out = 2'b00;
        4'b0010: out = 2'b00;
        4'b0011: out = 2'b01;
        4'b0100: out = 2'b00;
        4'b1000: out = 2'b00;
        4'b1100: out = 2'b01;
        4'b1111: out = 2'b10;
        default: out = 2'b10;
endcase
end

endmodule