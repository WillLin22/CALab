`include "cache.vh"


//FIFO, can be upgraded
module CacheIdxGen (
    input reset,
    input clk,
    input en,
    output reg [$clog2(WAY)-1:0] way
);
always @(posedge clk) begin
    if (reset) begin
        way <= 0;
    end else if (en) begin
        way <= way + 1;
    end
end
endmodule

module TagVWrapper (
    input reset,
    input clk,
    input en,
    input wr, // 1 for wr, 0 for rd
    input  [INDEXLEN-1:0]       idx,
    input  [TAGLEN-1:0]         Tag,
    input                       V,
    output                      hit,
    output                      error
);
//TODO: add instantiation of RAM
//rd
wire [TAGVLEN-1:0] tagv_rd1, tagv_rd2;
assign hit = tagv_rd1[TAGR] == Tag && tagv_rd1[TAGV] == V ||
            tagv_rd2[TAGR] == Tag && tagv_rd2[TAGV] == V;
assign error = tagv_rd1[TAGR] == Tag && tagv_rd1[TAGV] == V &&
              tagv_rd2[TAGR] == Tag && tagv_rd2[TAGV] == V;
//wr
wire [TAGVLEN-1:0] tagv_wr = {Tag, V};
wire [WAY-1:0]     way_wr;
CacheIdxGen idxgen(
    .reset(reset),
    .clk(clk),
    .en(en),
    .way(way_wr)
); 
endmodule

module DataWrapper (
    input reset,
    input clk,
    input en,
    input [$clog2(WAY)-1:0]         way,
    input [OFFSETLEN-1:0]           offset1,
    input [1:0]                     mode1, //0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes, 3 for 8 bytes 
    input [OFFSETLEN-1:0]           offset2,
    input [1:0]                     mode2, //0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes, 3 for 8 bytes
    input [INDEXLEN-1:0]            idx,
    input [WIDTH-1:0]               wr, // 1 for wr, 0 for rd for each bit
    input [WIDTH*8-1:0]             data1,// data input, stored in low bits
    input [WIDTH*8-1:0]             data2,// data input, stored in low bits
    output [WIDTH*8-1:0]            rd1, // data read, stored in low bits
    output [WIDTH*8-1:0]            rd2, // data read, stored in low bits
    output reg ok,// 1 for read/write over
    output error
);
wire [1:0] mode[2];
assign mode[0] = mode1;
assign mode[1] = mode2;
wire [3:0] mode_d[2];
decoder_2_4 dec1(
    .in(mode[0]),
    .out(mode_d[0])  
);
decoder_2_4 dec2(
    .in(mode[1]),
    .out(mode_d[1])
);
wire [OFFSETLEN-1:0] offset[2];
assign offset[0] = offset1;
assign offset[1] = offset2;
// check:
// 1. offset in such mode is valid
// 2. offset in such mode is the same as wr
wire [1:0]errors;
genvar i;
generate for(i = 0;i < 2; i=i+1) begin : error_gen
    assign errors[i] = ~|mode[i] || offset[i][0] & mode_d[i][1] || 
                (offset[i][1] | offset[i][0]) & mode_d[i][2] ||
                (offset[i][2] | offset[i][1] | offset[i][0]) & mode_d[i][3] ||
                mode_d[i][1] &~(&wr[(offset[i]&~1)+1:(offset[i]&~1)] || (~|wr[(offset[i]&~1)+1:(offset[i]&~1)])) ||
                mode_d[i][2] & (&wr[(offset[i]&~3)+3:(offset[i]&~3)] || (~|wr[(offset[i]&~3)+3:(offset[i]&~3)])) ||
                mode_d[i][3] & (&wr[(offset[i]&~7)+7:(offset[i]&~7)] || (~|wr[(offset[i]&~7)+7:(offset[i]&~7)]));
end
endgenerate
assign error = |errors;
//TODO: add instantiation of RAM
always @(posedge clk) begin
    if (reset) begin
        ok <= 0;
    end else if (en) begin
        ok <= 1;
    end
    else begin
        ok <= 0;
    end
end
//rd
wire [WIDTH*8-1:0] rd[2];
wire [WIDTH*8-1:0]  data_rd [2];
wire [8-1:0]        rd1byte [2];
wire [16-1:0]       rd2bytes[2];
wire [32-1:0]       rd4bytes[2];
wire [64-1:0]       rd8bytes[2];
genvar j;
generate for (j = 0;j < 2; j=j+1) begin : rd_gen
    assign rd1byte[j] = data_rd[j][(offset[j]&~1)+7:offset[j]&~1];
    assign rd2bytes[j] = data_rd[j][(offset[j]&~3)+15:offset[j]&~3];
    assign rd4bytes[j] = data_rd[j][(offset[j]&~7)+31:offset[j]&~7];
    assign rd8bytes[j] = data_rd[j][(offset[j]&~15)+63:offset[j]&~15];
    // auto-fill high bits, for no use
    assign rd[j] = {8{mode_d[j][0]}} & rd1byte[j] | 
            {16{mode_d[j][1]}} & rd2bytes[j] | 
            {32{mode_d[j][2]}} & rd4bytes[j] | 
            {64{mode_d[j][3]}} & rd8bytes[j];
end
endgenerate
assign rd1 = rd[0];
assign rd2 = rd[1];
//wr
wire [WIDTH*8-1:0] data[2];
assign data[0] = data1;
assign data[1] = data2;
wire [WIDTH*8-1:0] data_wrs[2], data_wr;
WrAlign wralign1(
    .data(data[0]),
    .offset(offset[0]),
    .mode_d(mode_d[0]),
    .data_aligned(data_wrs[0])
);
WrAlign wralign2(
    .data(data[1]),
    .offset(offset[1]),
    .mode_d(mode_d[1]),
    .data_aligned(data_wrs[1])
);
assign data_wr = data_wrs[0] | data_wrs[1];


endmodule

module WrAlign (
    input [WIDTH*8-1:0] data,// input data, stored in low bits
    input [OFFSETLEN-1:0] offset,
    input [3:0] mode_d,
    output [WIDTH*8-1:0] data_aligned// aligned data, other bits 0
);

wire [63:0]block8bytes_m0 = {
    data[7:0] & {8{offset[2:0] == 3'b111}},
    data[7:0] & {8{offset[2:0] == 3'b110}},
    data[7:0] & {8{offset[2:0] == 3'b101}},
    data[7:0] & {8{offset[2:0] == 3'b100}},
    data[7:0] & {8{offset[2:0] == 3'b011}},
    data[7:0] & {8{offset[2:0] == 3'b010}},
    data[7:0] & {8{offset[2:0] == 3'b001}},
    data[7:0] & {8{offset[2:0] == 3'b000}}
};
wire [63:0]block8bytes_m1 = {
    data[15:0] & {16{offset[2:1] == 2'b11}},
    data[15:0] & {16{offset[2:1] == 2'b10}},
    data[15:0] & {16{offset[2:1] == 2'b01}},
    data[15:0] & {16{offset[2:1] == 2'b00}}
};
wire [63:0]block8bytes_m2 = {
    data[31:0] & {32{offset[2] == 1'b1}},
    data[31:0] & {32{offset[2] == 1'b0}}
};
wire [63:0]block8bytes_m3 = data[63:0];
wire [63:0]block8bytes = block8bytes_m0 &{64{mode_d[0]}} | 
                        block8bytes_m1 &{64{mode_d[1]}} | 
                        block8bytes_m2 &{64{mode_d[2]}} | 
                        block8bytes_m3 &{64{mode_d[3]}};
genvar i;
generate for(i = 0;i < WIDTH/8; i=i+1) begin : data_gen
    assign data_aligned[i*64+63:i*64] = block8bytes & {64{offset[OFFSETLEN-1:0] == i}};
end 
endgenerate
endmodule

module MissState (
    
);
    
endmodule
