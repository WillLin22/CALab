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

// always @(*) begin
//     if(in[0] == 1) out = 0;
//     else if(in[1] == 1) out = 1;
//     else if(in[2] == 1) out = 2;
//     else if(in[3] == 1) out = 3;
//     else if(in[4] == 1) out = 4;
//     else if(in[5] == 1) out = 5;
//     else if(in[6] == 1) out = 6;
//     else if(in[7] == 1) out = 7;
//     else if(in[8] == 1) out = 8;
//     else if(in[9] == 1) out = 9;
//     else if(in[10] == 1) out = 10; 
//     else if(in[11] == 1) out = 11;
//     else if(in[12] == 1) out = 12;
//     else if(in[13] == 1) out = 13;
//     else if(in[14] == 1) out = 14;
//     else if(in[15] == 1) out = 15;
//     else out = 0;
// end

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