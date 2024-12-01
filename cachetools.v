`include "cache.vh"


//FIFO, can be upgraded
module CacheIdxGen (
    input reset,
    input clk,
    input en,
    output reg [$clog2(`WAY)-1:0] way
);
always @(posedge clk) begin
    if (reset) begin
        way <= 0;
    end else if (en) begin
        way <= way + 1;
    end
end
endmodule
module DWrapper (
    input reset,
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
    input [`TAGVLEN-1:0] tagv1,
    input [`TAGVLEN-1:0] tagv2,
    input [`TAGLEN-1:0] Tag,
    input en_for_miss,// set for 1 cycle each nothit, connect with REPLACE
    output hit,
    output [$clog2(`WAY)-1:0] way,
    output error
);
wire [`TAGVLEN-1:0] tagv[1:0];
assign tagv[0] = tagvr1;
assign tagv[1] = tagvr2;
wire [1:0] hitway;
wire way_e, way_gen;
genvar i;
generate for(i = 0;i < `WAY; i=i+1) begin : hitway_gen
    assign hitway[i] = tagv[i][`TAGR] == Tag && tagv[i][`VR] == 1;
end
endgenerate
assign hit = |hitway;
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
    .way(way_wr)
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
    assign strb_out[i+3:i] = {4{strb_4[i]}} & strb_in;
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
    input [1:0] ret_last
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
assign rd_ok = ret_last!=0;
    
endmodule
module Fetch_128_32 (
    input [3:0] offset,
    input [127:0] in,
    output [31:0] out
);
assign out = in[32*offset[3:2]+31:32*offset[3:2]];
endmodule
