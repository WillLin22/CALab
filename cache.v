`include "cache.vh"

module Cache (
    input reset,
    input clk,
    output                  rd_req,
    output [2:0]            rd_type,//000 for byte, 001 for halfword, 010 for word, 100 for cache line
    output [31:0]           rd_addr,
    input                   rd_rdy,
    input                   ret_valid,
    input  [1:0]            ret_last,
    input  [31:0]           ret_data,
    output                  wr_req,    
    output [2:0]            wr_type,
    output [31:0]           wr_addr,
    output [3:0]            wr_wstrb,// only when wr_type is 010 or 001 or 000 make sense
    output [WIDTH*8-1:0]    wr_wdata,
    input                   wr_rdy
);
//Cache and cpu/tlb interface
wire                        in_valid;// enable
wire                        in_op;//1 for write, 0 for read
wire [3:0]                  in_wstrb;
wire [31:0]                 in_wdata;
wire                        out_addrok;
wire                        out_dataok;
wire [31:0]                 out_rdata;
wire [INDEXLEN-1:0]         in_idx;
wire [OFFSETLEN-1:0]        in_offset;

reg [4:0] state;// refill miss lookup idle
wire IDLE = state == 5'b00001;
wire LOOKUP = state == 5'b00010;
wire MISS = state == 5'b00100;
wire REPLACE = state == 5'b01000;
wire REFILL = state == 5'b10000;
wire error_state = !IDLE&&!LOOKUP&&!MISS&&!REPLACE&&!REFILL;
wire [INDEXLEN-1:0]             idx;
wire [OFFSETLEN-1:0]            offset;
wire [TAGLEN-1:0]               tag;
wire hit;
wire hitway;

wire [31:0] pa_from_tlb;
reg  [31:0] pa_reg;

reg  wr_reg;
reg  [WIDTH-1:0]  wstrb_reg;
reg  [WIDTH*8-1:0]  wdata_reg;

wire [TAGVLEN-1:0]              tagvrd[2];
reg  [TAGVLEN-1:0]              tagv_reg[2];
wire [TAGVLEN-1:0]              tagv[2];

wire [WIDTH*8-1:0]              datard[2];
reg  [32-1:0]                   datard_reg[WIDTH/4];
wire [WIDTH*8-1:0]              datard_combined;
reg  [WIDTH*8-1:0]              datawr_reg;

wire                            Drd[2];

// wr state control reg / rd state control reg
reg miss_rding;
reg miss_wring;

assign idx = in_valid ? in_idx : pa_reg[VAIDXR];
assign offset = in_valid ? in_offset : pa_reg[VAOFFR];
assign tag = pa_reg[VATAGR];


//IDLE
assign out_addrok = IDLE&&in_valid;
wire [WIDTH*8-1:0]  wdata_extended;
wire [WIDTH-1:0]  wstrb;
extend_32_128 extend_32_128_inst(
    .in(in_wdata),
    .off(in_offset),
    .strb_in(in_wstrb),
    .strb_out(wstrb),
    .out(wdata_extended)
);
//LOOKUP
wire hiterror;
HitGen hitgen(
    .reset(reset),
    .clk(clk),
    .tagv1(tagv[0]),
    .tagv2(tagv[1]),
    .Tag(tag),
    .en_for_miss(REPLACE),
    .hit(hit),
    .way(hitway),
    .error(hiterror)
);
//MISS
//wr
wire missrd_ok;
wire misswr_ok;
assign wr_wdata = datawr_reg;
assign wr_wstrb = 4'b0000;// 一直都是写cache行，因此不需要wstrb
assign wr_type  = 3'b100;
assign wr_addr  = {tag, idx, 4'b0};
assign misswr_ok = wr_req;
assign wr_req = miss_wring&&wr_rdy;
//rd
assign rd_type = 3'b100;
assign rd_addr = {tag, idx, 4'b0};
reg [$clog2(WIDTH/4):0] cnt;
always @(posedge clk) begin
    if(reset)
        cnt <= 0;
    else if(ret_valid||ret_last!=0)
        cnt <= cnt+1;
end
always @(posedge clk) begin
    if(ret_valid)
        datard_reg[cnt] <= ret_data;
end
genvar i;
generate for(i=0;i<WIDTH/4;i=i+1)begin:gendgenerate
    assign datard_combined[i*32-1:i] = datard_reg[i];
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
wire error_rd = !MISS&&cnt!=0||ret_last!=0&&cnt!=2'b11;

wire error_miss = !MISS&&(miss_rding||miss_wring||missrd_ok||misswr_ok);
//REPLACE
reg replace;// 1 for have been missed, 0 for not
//REFILL
assign out_dataok = REFILL;
wire error_refill = REFILL&&!hit;
Fetch_128_32 fetch_128_32_inst(
    .offset(offset),
    .in(replace? datard :datawr_reg),
    .out(out_rdata)
);

always @(posedge clk) begin
    if(IDLE&&in_valid)begin
        pa_reg <= pa_from_tlb;

        wr_reg <= in_op;
        wstrb_reg <= wstrb;
        wdata_reg <= wdata_extended;

    end
    else if(LOOKUP)begin
        tagv_reg[0] <= tagvrd[0];
        tagv_reg[1] <= tagvrd[1];
        datawr_reg  <= datard[hitway];
        miss_rding  <= !hit;
        miss_wring  <= !hit&&D[hitway];
    end
    else if(MISS)begin
        if(missrd_ok)
            miss_rding <= 0;
        if(misswr_ok)
            miss_wring <= 0;
    end
    else if(REPLACE)begin
        tagv_reg[hitway] <= {tag, 1};
        replace <= 1;
    end
    else if(REFILL)begin
        replace <= 0;
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
    .reset(reset),
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE),
    .idx(idx),
    .tagvr1(tagvrd[0]),
    .tagvr2(tagvrd[1]),
    .wr(REPLACE),
    .Tag(tag)
);
DataWrapper datawrapper(
    .reset(reset),
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE||REFILL&&wr_reg),
    .idx(idx),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .wstrb(REPLACE? 16'1 :wstrb_reg),
    .wdata(REPLACE? datard_combined :wdata_reg),
    .rd1(datard[0]),
    .rd2(datard[1])
);
DWrapper dwrapper(
    .reset(reset),
    .clk(clk),
    .en(IDLE&&in_valid||REPLACE||REFILL&&wr_reg),
    .wr(REPLACE||REFILL&&wr_reg),
    .wr_way(hitway),
    .idx(idx),
    .set(REFILL&&wr_reg),
    .D0(Drd[0]),
    .D1(Drd[1])
);

    
endmodule