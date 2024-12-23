`include "cache.vh"


//FIFO, can be upgraded
module CacheIdxGen (
    input reset,
    input clk,
    input en,
    input [`INDEXLEN-1:0]   idx,
    output gen
);
reg [`INDEX-1:0] way;
always @(posedge clk) begin
    if (reset) begin
        way <= 0;
    end else if (en) begin
        way[idx] <= way[idx] ^1'b1;
    end
end
assign gen = way[idx];
endmodule
module DWrapper (
    input clk,
    input en,
    input wr, // 1 for wr, 0 for rd
    input wr_way,
    input [`INDEXLEN-1:0] idx,
    input set,// 1 for set, 0 for clear
    output D0,
    output D1
);
D_bank1 Dinst1(
    .addra(idx),
    .clka(clk),
    .dina(set),
    .douta(D0),
    .ena(en),
    .wea(wr&&wr_way==0)
);
D_bank2 Dinst2(
    .addra(idx),
    .clka(clk),
    .dina(set),
    .douta(D1),
    .ena(en),
    .wea(wr&&wr_way==1)
);
endmodule

module TagVWrapper (
    input clk,
    input en,
    input wr, // 1 for wr, 0 for rd
    input wr_way,
    input  [`INDEXLEN-1:0]       idx,
    input  [`TAGLEN-1:0]         Tag,
    output [`TAGVLEN-1:0]        tagvr1,
    output [`TAGVLEN-1:0]        tagvr2
);
tagv_bank1 tagv1(
    .addra(idx),
    .clka(clk),
    .dina({Tag, 1'b1}),
    .douta(tagvr1),
    .ena(en),
    .wea(wr&&wr_way==0)
);
tagv_bank2 tagv2(
    .addra(idx),
    .clka(clk),
    .dina({Tag, 1'b1}),
    .douta(tagvr2),
    .ena(en),
    .wea(wr&&wr_way==1)
);
endmodule
module HitGen (
    input reset,
    input clk,
    input [`INDEXLEN-1:0] idx,
    input [`TAGVLEN-1:0] tagv1,
    input [`TAGVLEN-1:0] tagv2,
    input [`TAGLEN-1:0] Tag,
    input uncache,
    input en_for_miss,// set for 1 cycle each nothit, connect with REPLACE
    input cacop_way_en,// set for given specific way
    input cacop_way,
    output hit,
    output [$clog2(`WAY)-1:0] way,
    output error
);
wire [`TAGVLEN-1:0] tagv[1:0];
assign tagv[0] = tagv1;
assign tagv[1] = tagv2;
wire [1:0] hitway;
wire way_e, way_gen;
genvar i;
generate for(i = 0;i < `WAY; i=i+1) begin : hitway_gen
    assign hitway[i] = cacop_way_en?cacop_way:(tagv[i][`TAGR] == Tag && tagv[i][`VR] == 1);
end
endgenerate
assign hit = (|hitway)&&!uncache;
encoder_2_1 enc1(
    .in(hitway),
    .out(way_e),
    .error(error)
);
//TODO: en for 1 cycle
CacheIdxGen idxgen(
    .reset(reset),
    .clk(clk),
    .en(en_for_miss),
    .idx(idx),
    .gen(way_gen)
); 
assign way = hit ? way_e : way_gen;
endmodule

module DataWrapper (
    input clk,
    input en,
    input                           wr, // 1 for wr, 0 for rd for each bit
    input                           wr_way,
    input [`WIDTH-1:0]               wstrb,
    input [`WIDTH*8-1:0]             wdata,
    input [`INDEXLEN-1:0]            idx,
    output [`WIDTH*8-1:0]            rd1,
    output [`WIDTH*8-1:0]            rd2
);
data_bank1 data1(
    .addra(idx),
    .clka(clk),
    .dina(wdata),
    .douta(rd1),
    .ena(en),
    .wea({`WIDTH{wr&&wr_way==0}} & wstrb)
);
data_bank2 data2(
    .addra(idx),
    .clka(clk),
    .dina(wdata),
    .douta(rd2),
    .ena(en),
    .wea({`WIDTH{wr&&wr_way==1}} & wstrb)
);
endmodule

module Extend_32_128 (
    input [31:0] in,
    input [3:0]  off,
    input [3:0]  strb_in,
    output [15:0]  strb_out,
    output [127:0] out
);
wire [3:0] strb_4;
decoder_2_4 dec(
    .in(off[3:2]),
    .out(strb_4)
);
genvar i;
generate for(i = 0;i < 4; i=i+1) begin : strb_gen
    assign strb_out[i*4+3:i*4] = {4{strb_4[i]}} & strb_in;
end
endgenerate
assign out = {4{in}};
    
endmodule

module MissRdState (
    input reset,
    input clk,
    input en,
    input rd_rdy,
    output rd_req,
    output rd_ok,
    input ret_valid,
    input ret_last,
    input error
);
reg [2:0] state;
always @(posedge clk)begin
    if(reset) 
        state <= 3'b001;
    else if(state[0] && en)
        state <= 3'b010;
    else if(state[1] && rd_rdy)
        state <= 3'b100;
    else if(state[2] && ret_valid && ret_last!=0)
        state <= 3'b001;

end
assign rd_req = state[1] && rd_rdy;
assign rd_ok = ret_last;
assign error = !state[2] && ret_last || !ret_valid && ret_last;
    
endmodule
module Fetch_128_32 (
    input [3:0] offset,
    input [127:0] in,
    input uncache,
    output [31:0] out
);
wire [3:0] which;
decoder_2_4 dec(
    .in(offset[3:2]),
    .out(which)
);
wire [31:0] out_cache = in[31:0] & {32{which[0]}}  |
             in[63:32] & {32{which[1]}} |
             in[95:64] & {32{which[2]}} |
             in[127:96] & {32{which[3]}};
wire [31:0] out_uncache = in[31:0];
assign out = uncache ? out_uncache : out_cache;
endmodule
