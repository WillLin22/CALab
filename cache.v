`include "cache.vh"

module cache (
    input resetn,
    input clk,
    //cpu interface
    input                   valid,
    input                   op,//1 for write, 0 for read
    input [`INDEXLEN-1:0]   index,
    input [`TAGLEN-1:0]     tag,
    input [`OFFSETLEN-1:0]  offset,
    input [3:0]             wstrb,
    input [31:0]            wdata,
    
    output                  addr_ok,
    output                  data_ok,
    output [31:0]           rdata,

    output                  rd_req,
    output [2:0]            rd_type,//000 for byte, 001 for halfword, 010 for word, 100 for cache line
    output [31:0]           rd_addr,
    input                   rd_rdy,
    input                   ret_valid,
    input                   ret_last,
    input  [31:0]           ret_data,
    output                  wr_req,    
    output [2:0]            wr_type,
    output [31:0]           wr_addr,
    output [3:0]            wr_wstrb,// only when wr_type is 010 or 001 or 000 make sense
    output [`WIDTH*8-1:0]   wr_data,
    input                   wr_rdy,
    // added for uncache
    input                   uncache, // 是否为非缓存访问
    // added for cacop, separate path
    input                   cacop_en,
    input  [31:0]           cacop_va,
    input  [1:0]            code_4_3,
    output cacop_ok
);
wire reset = ~resetn;
//Cache and cpu/tlb interface
wire                        in_valid = valid;// enable
wire                        in_op = op;//1 for write, 0 for read
wire [3:0]                  in_wstrb = wstrb;
wire [31:0]                 in_wdata = wdata;
wire                        out_addrok;
wire                        out_dataok;
wire [31:0]                 out_rdata;
assign addr_ok = out_addrok;
assign data_ok = out_dataok;
assign rdata = out_rdata;
wire [`INDEXLEN-1:0]        in_idx = index;
wire [`OFFSETLEN-1:0]       in_offset = offset;
wire [`TAGLEN-1:0]          in_tag = tag;

(*mark_debug = "true"*)reg [4:0] state;// refill miss lookup idle
wire IDLE = state == 5'b00001;
wire LOOKUP = state == 5'b00010;
wire MISS = state == 5'b00100;
wire REPLACE = state == 5'b01000;
wire REFILL = state == 5'b10000;
wire error_state = !IDLE&&!LOOKUP&&!MISS&&!REPLACE&&!REFILL;
(*mark_debug = "true"*)wire [`INDEXLEN-1:0]             Idx;
(*mark_debug = "true"*)wire [`OFFSETLEN-1:0]            Offset;
(*mark_debug = "true"*)wire [`TAGLEN-1:0]               Tag;
(*mark_debug = "true"*)wire hit;
(*mark_debug = "true"*)wire hitway;

wire [31:0] pa_from_tlb = {in_tag, Idx, in_offset};
reg  [31:0] pa_reg;

reg  wr_reg;
reg  [`WIDTH-1:0]  wstrb_reg;
reg  [`WIDTH*8-1:0]  wdata_reg;

wire [`TAGVLEN-1:0]              tagvrd[1:0];
reg  [`TAGVLEN-1:0]              tagv_reg[1:0];
wire [`TAGVLEN-1:0]              tagv[1:0];
assign tagv[0] = LOOKUP ? tagvrd[0] : tagv_reg[0];
assign tagv[1] = LOOKUP ? tagvrd[1] : tagv_reg[1];

wire [`WIDTH*8-1:0]              datard[1:0];
reg  [32-1:0]                   datard_reg[`WIDTH/4-1:0];
wire [`WIDTH*8-1:0]              datard_combined;
reg  [`WIDTH*8-1:0]              datawr_reg;

wire                            Drd[1:0];
// uncache
reg                             uncache_reg;
reg  [3:0]                      wstrb32_reg;

// wr state control reg / rd state control reg
reg miss_rding;
reg miss_wring;


// cacop
reg cacop_en_reg;
reg [31:0] cacop_va_reg;
reg [1:0] code_4_3_reg;
wire [31:0]Cacop_va                     = cacop_ok ? cacop_va : cacop_va_reg;
wire [1:0]Code_4_3                      = cacop_ok ? code_4_3 : code_4_3_reg;
wire cacop_use_va                       = Code_4_3 == 2'b00 || Code_4_3 == 2'b01;
wire [`INDEXLEN-1:0] cacop_idx          = cacop_use_va?Cacop_va[`VAIDXR]:Idx;
wire cacop_way                          = cacop_use_va?Cacop_va[0]:hitway;
// global use variable
wire [`INDEXLEN-1:0] index_global       = cacop_en ? cacop_idx : Idx;
wire [`TAGLEN-1:0] tag_global           = Tag;

// cacop writeback
wire cacop_wb = cacop_en_reg && hit && Drd[hitway] && Code_4_3 != 2'b00;
// cache ready
wire ready = IDLE||LOOKUP&&!wr_reg&&hit&&!uncache_reg&&!cacop_en_reg||REFILL 
            ||LOOKUP&&!cacop_wb&&cacop_en_reg||MISS&&misswr_ok&&cacop_en_reg;

assign Idx = out_addrok ? in_idx : pa_reg[`VAIDXR];
assign Offset = out_addrok ? in_offset : pa_reg[`VAOFFR];
assign Tag = pa_reg[`VATAGR];


//IDLE
assign out_addrok = ready&&in_valid&&!cacop_en;
assign cacop_ok   = ready&&in_valid&&cacop_en;
wire [`WIDTH*8-1:0]  wdata_extended;
wire [`WIDTH-1:0]  Wstrb;
Extend_32_128 extend_32_128_inst(
    .in(in_wdata),
    .off(in_offset),
    .strb_in(in_wstrb),
    .strb_out(Wstrb),
    .out(wdata_extended)
);
//LOOKUP
(*mark_debug = "true"*)wire hiterror;
HitGen hitgen(
    .reset(reset),
    .clk(clk),
    .idx(index_global),
    .tagv1(tagv[0]),
    .tagv2(tagv[1]),
    .Tag(Tag),
    .uncache(uncache_reg),
    .en_for_miss((REPLACE)&&!uncache_reg),
    .hit(hit),
    .way(hitway),
    .cacop_way_en(cacop_use_va),
    .cacop_way(cacop_va[0]),
    .error(hiterror)
);
//MISS
//wr
wire missrd_ok;
wire misswr_ok;
assign wr_data = uncache_reg ?  wdata_reg : datawr_reg;
assign wr_wstrb = wstrb32_reg;
assign wr_type  = uncache_reg?3'b010:3'b100;
assign wr_addr  = uncache_reg?{Tag, Idx, Offset[3:2], 2'b0}:{tagv[hitway][`TAGR], index_global, 4'b0};
assign misswr_ok = wr_req;
assign wr_req = miss_wring&&wr_rdy;
//rd
assign rd_type = uncache_reg?3'b010:3'b100;
assign rd_addr = uncache_reg?{Tag, Idx, Offset[3:2], 2'b0}:{Tag, Idx, 4'b0};
reg [$clog2(`WIDTH/4)-1:0] cnt;
always @(posedge clk) begin
    if(reset)
        cnt <= 2'b00;
    else if(MISS&&(ret_valid||ret_last)&&!uncache_reg)
        cnt <= cnt+2'b01;
end
integer j;
always @(posedge clk) begin
    if(reset)begin
        for(j=0;j<`WIDTH/4;j=j+1)begin
            datard_reg[j] <= 32'h0;
        end
    end
    else if(ret_valid)
        datard_reg[cnt] <= ret_data;
end
genvar i;
generate for(i=0;i<`WIDTH/4;i=i+1)begin:gendgenerate
    assign datard_combined[i*32+31:i*32] = datard_reg[i];
end
endgenerate
(*mark_debug = "true"*)wire error_rdstate;
MissRdState missrdstate(
    .reset(reset),
    .clk(clk),
    .en(miss_rding),
    .rd_rdy(rd_rdy),
    .rd_req(rd_req),
    .rd_ok(missrd_ok),
    .ret_valid(ret_valid),
    .ret_last(ret_last),
    .error(error_rdstate)
);
(*mark_debug = "true"*)wire error_rd = !MISS&&cnt!=2'b00||(ret_last&&cnt!=2'b11&&!uncache_reg)||error_rdstate;

(*mark_debug = "true"*)wire error_miss = !MISS&&(miss_rding||miss_wring||missrd_ok||misswr_ok);
//REPLACE
reg replace;// 1 for have been missed, 0 for not
//REFILL
assign out_dataok = REFILL||LOOKUP&&hit&&!wr_reg;
(*mark_debug = "true"*)wire error_refill = REFILL&&!hit&&!uncache_reg;
Fetch_128_32 fetch_128_32_inst(
    .offset(Offset),
    .uncache(uncache_reg),
    .in(replace? datard_combined :LOOKUP?datard[hitway]:datawr_reg),
    .out(out_rdata)
);

always @(posedge clk) begin
    if(reset)begin
        pa_reg <= 32'h0;
        wr_reg <= 1'b0;
        wstrb_reg <= 4'h0;
        wdata_reg <= 128'h0;
        uncache_reg <= 1'b0;
        wstrb32_reg <= 4'h0;
        tagv_reg[0] <= 10'h0;
        tagv_reg[1] <= 10'h0;
        datawr_reg <= 128'h0;
        miss_rding <= 1'b0;
        miss_wring <= 1'b0;
        replace <= 1'b0;
        cacop_en_reg <= 1'b0;
    end
    else if(out_addrok||cacop_ok)begin
        pa_reg <= pa_from_tlb;
        wr_reg <= in_op;
        wstrb_reg <= Wstrb;
        wdata_reg <= wdata_extended;
        uncache_reg <= uncache&&!cacop_en;
        wstrb32_reg <= in_wstrb;
        cacop_en_reg <= cacop_en;
        cacop_va_reg <= cacop_va;
        code_4_3_reg <= code_4_3;
    end
    else if(LOOKUP)begin
        tagv_reg[0] <= tagvrd[0];
        tagv_reg[1] <= tagvrd[1];
        datawr_reg  <= datard[hitway];
        miss_rding  <= !hit&&!uncache_reg || uncache_reg&&!wr_reg;
        miss_wring  <= cacop_en_reg?cacop_wb:(!hit&&Drd[hitway]&&!uncache_reg || uncache_reg&&wr_reg);
    end
    else if(MISS)begin
        if(missrd_ok)
            miss_rding <= 1'b0;
        if(misswr_ok)
            miss_wring <= 1'b0;
    end
    else if(REPLACE)begin
        tagv_reg[hitway] <= {Tag, 1'b1};
        replace <= 1'b1;
    end
    else if(REFILL)begin
        replace <= 1'b0;
    end
end

//state control
always @(posedge clk) begin
    if(reset)
        state <= 5'b00001;
    else if(out_addrok||cacop_ok)
        state <= 5'b00010;
    else if(LOOKUP && hit && wr_reg&&!cacop_en_reg||REPLACE)
        state <= 5'b10000;
    else if(LOOKUP && !hit && !cacop_en_reg|| cacop_wb)
        state <= 5'b00100;
    else if(MISS &&(!miss_rding||missrd_ok)&&(!miss_wring||misswr_ok))
        if(cacop_en_reg)
            state <= 5'b00001;
        else 
            state <= 5'b01000;
    else if(REFILL||LOOKUP&&hit&&!wr_reg&&!cacop_en_reg||LOOKUP&&(Code_4_3==2'b00||!hit)&&cacop_en_reg)
        state <= 5'b00001;
end

TagVWrapper tagvwrapper(
    .clk(clk),
    .en(out_addrok||cacop_ok||(REPLACE)&&!uncache_reg||LOOKUP&&cacop_en_reg&&hit),
    .idx(index_global),
    .tagvr1(tagvrd[0]),
    .tagvr2(tagvrd[1]),
    .wr(REPLACE||LOOKUP&&cacop_en_reg&&hit),
    .wr_way(hitway),
    .Tag(cacop_en_reg?`TAGLEN'b0:Tag)
);
DataWrapper datawrapper(
    .clk(clk),
    .en(out_addrok||cacop_ok||(REPLACE||REFILL&&wr_reg)&&!uncache_reg),
    .idx(index_global),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .wstrb(REPLACE? 16'hffff :wstrb_reg),
    .wdata(REPLACE? datard_combined :wdata_reg),
    .rd1(datard[0]),
    .rd2(datard[1])
);
DWrapper dwrapper(
    .clk(clk),
    .en(out_addrok||cacop_ok||(REPLACE||REFILL&&wr_reg)&&!uncache_reg),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .idx(index_global),
    .set(REFILL&&wr_reg),
    .D0(Drd[0]),
    .D1(Drd[1])
);

(*mark_debug = "true"*)wire error = error_state||error_rd||error_miss||error_refill;

    
endmodule