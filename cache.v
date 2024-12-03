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
    input                   wr_rdy
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

reg [4:0] state;// refill miss lookup idle
wire IDLE = state == 5'b00001;
wire LOOKUP = state == 5'b00010;
wire MISS = state == 5'b00100;
wire REPLACE = state == 5'b01000;
wire REFILL = state == 5'b10000;
wire error_state = !IDLE&&!LOOKUP&&!MISS&&!REPLACE&&!REFILL;
wire [`INDEXLEN-1:0]             Idx;
wire [`OFFSETLEN-1:0]            Offset;
wire [`TAGLEN-1:0]               Tag;
wire hit;
wire hitway;

wire [31:0] pa_from_tlb = {in_tag, Idx, 4'b0};
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

// wr state control reg / rd state control reg
reg miss_rding;
reg miss_wring;

assign Idx = in_valid ? in_idx : pa_reg[`VAIDXR];
assign Offset = in_valid ? in_offset : pa_reg[`VAOFFR];
assign Tag = pa_reg[`VATAGR];


//IDLE
assign out_addrok = IDLE&&in_valid;
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
wire hiterror;
HitGen hitgen(
    .reset(reset),
    .clk(clk),
    .idx(Idx),
    .tagv1(tagv[0]),
    .tagv2(tagv[1]),
    .Tag(Tag),
    .en_for_miss(REPLACE),
    .hit(hit),
    .way(hitway),
    .error(hiterror)
);
//MISS
//wr
wire missrd_ok;
wire misswr_ok;
assign wr_data = datawr_reg;
assign wr_wstrb = 4'b0000;// 一直都是写cache行，因此不需要wstrb
assign wr_type  = 3'b100;
assign wr_addr  = {tagv[hitway][`TAGR], Idx, 4'b0};
assign misswr_ok = wr_req;
assign wr_req = miss_wring&&wr_rdy;
//rd
assign rd_type = 3'b100;
assign rd_addr = {Tag, Idx, 4'b0};
reg [$clog2(`WIDTH/4)-1:0] cnt;
always @(posedge clk) begin
    if(reset)
        cnt <= 2'b00;
    else if(ret_valid||ret_last)
        cnt <= cnt+2'b01;
end
always @(posedge clk) begin
    if(ret_valid)
        datard_reg[cnt] <= ret_data;
end
genvar i;
generate for(i=0;i<`WIDTH/4;i=i+1)begin:gendgenerate
    assign datard_combined[i*32+31:i*32] = datard_reg[i];
end
endgenerate
MissRdState missrdstate(
    .reset(reset),
    .clk(clk),
    .en(miss_rding),
    .rd_rdy(rd_rdy),
    .rd_req(rd_req),
    .rd_ok(missrd_ok),
    .ret_valid(ret_valid),
    .ret_last(ret_last)
);
wire error_rd = !MISS&&cnt!=2'b00||ret_last&&cnt!=2'b11;

wire error_miss = !MISS&&(miss_rding||miss_wring||missrd_ok||misswr_ok);
//REPLACE
reg replace;// 1 for have been missed, 0 for not
//REFILL
assign out_dataok = REFILL;
wire error_refill = REFILL&&!hit;
Fetch_128_32 fetch_128_32_inst(
    .offset(Offset),
    .in(replace? datard_combined :datawr_reg),
    .out(out_rdata)
);

always @(posedge clk) begin
    if(IDLE&&in_valid)begin
        pa_reg <= pa_from_tlb;
        wr_reg <= in_op;
        wstrb_reg <= Wstrb;
        wdata_reg <= wdata_extended;

    end
    else if(LOOKUP)begin
        tagv_reg[0] <= tagvrd[0];
        tagv_reg[1] <= tagvrd[1];
        datawr_reg  <= datard[hitway];
        miss_rding  <= !hit;
        miss_wring  <= !hit&&Drd[hitway];
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
    if(reset||REFILL)
        state <= 5'b00001;
    else if(IDLE && in_valid)
        state <= 5'b00010;
    else if(LOOKUP && hit||REPLACE)
        state <= 5'b10000;
    else if(LOOKUP && !hit)
        state <= 5'b00100;
    else if(MISS &&(!miss_rding||missrd_ok)&&(!miss_wring||misswr_ok))
        state <= 5'b01000;
end

TagVWrapper tagvwrapper(
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE),
    .idx(Idx),
    .tagvr1(tagvrd[0]),
    .tagvr2(tagvrd[1]),
    .wr(REPLACE),
    .wr_way(hitway),
    .Tag(Tag)
);
DataWrapper datawrapper(
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE||REFILL&&wr_reg),
    .idx(Idx),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .wstrb(REPLACE? 16'hffff :wstrb_reg),
    .wdata(REPLACE? datard_combined :wdata_reg),
    .rd1(datard[0]),
    .rd2(datard[1])
);
DWrapper dwrapper(
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE||REFILL&&wr_reg),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .idx(Idx),
    .set(REFILL&&wr_reg),
    .D0(Drd[0]),
    .D1(Drd[1])
);

wire error = error_state||error_rd||error_miss||error_refill;

    
endmodule