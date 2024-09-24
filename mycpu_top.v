module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

`define PRE_IF 5
`define IF 4
`define ID 3
`define EXE 2
`define MEM 1
`define WB 0



wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;

//写后读阻塞相关变量声明
reg  [31:0]RAWreg;
wire RAWblock;
//写后读前递相关变量声明
wire [2:0] checkequ1;
wire [2:0] checkequ2;
wire isforward1;
wire [31:0]forwarddata1;
wire isforward2;
wire [31:0]forwarddata2;

reg [ 5:0]   valid;
reg block;
always @(posedge clk) begin
    if(reset) block <= 1'b0;
    else if(RAWblock) block <= block;
    else if(block == 1)
        block <= 1'b0;
    else if(br_taken)
        block <= 1'b1;
end
always @(posedge clk) begin
    if (reset) begin
        valid <= 6'b0;
    end
    else begin
        valid[5] <= 1'b1;
        valid[4] <= valid[5];
        valid[3] <= valid[4];
        valid[2] <= valid[3];
        valid[1] <= valid[2];
        valid[0] <= valid[1];
    end
end

wire [ 5:0]ready_go = valid & {~RAWblock, ~RAWblock, ~block &~RAWblock, 3'b111};
wire [ 5:0]allow_in = 6'b111111;


assign inst_sram_en = 1'b1;
assign data_sram_en = 1'b1;

assign seq_pc       = pc + 3'h4;
assign nextpc       = br_taken &&~block ? br_target : seq_pc;
//reg [31:0] last_pc;
reg [31:0] ID_pc;
reg [31:0] EXE_pc;
reg [31:0] MEM_pc;
reg [31:0] WB_pc;
//always @(posedge clk) begin
//    if(reset) begin
//        last_pc <= 32'h1bfffffc;
//    end
//    else if(RAWblock)
//        last_pc <= last_pc;
//    else begin
//        last_pc <= pc;
//    end
//end
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffff8;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(RAWblock) begin
        pc <= pc;
    end
    else begin
        pc <= nextpc;
    end
end
reg inst_in_RAW_control;
reg [31:0]inst_in_RAW;
assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst            = /*inst_sram_rdata*/inst_in_RAW_control ? inst_in_RAW : inst_sram_rdata;
always @(posedge clk)begin
    if(reset) inst_in_RAW_control <= 1'b0;
    else inst_in_RAW_control <= RAWblock;
end
always @(posedge clk)begin
    if(reset) inst_in_RAW <= 32'b0;
    else inst_in_RAW <= inst;
end
reg [31:0] ID_inst;
always @(posedge clk) begin
    if(reset)
        ID_inst <= 32'b0;
    else if(ready_go[4] && allow_in[3])
        ID_inst <= inst;
end

assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];

assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];

assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & valid[3];
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
    
assign rj_value  = isforward1 ? forwarddata1 : rf_rdata1;
assign rkd_value = isforward2 ? forwarddata2 : rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ID_pc/*pc*/ + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

// ID to EXE
reg [31:0] EXE_alu_src1;
reg [31:0] EXE_alu_src2;
reg [11:0] EXE_alu_op;
always @(posedge clk) begin
    if(reset)
        EXE_alu_src1 <= 32'b0;
    else if(ready_go[3] && allow_in[2])
        EXE_alu_src1 <= alu_src1;
//    else if(~ready_go[3] && allow_in[2])
//        EXE_alu_src1 <= 32'b0;//清理机制
end
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/)
        EXE_alu_src2 <= 32'b0;
    else if(ready_go[3] && allow_in[2])
        EXE_alu_src2 <= alu_src2;
end
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/)
        EXE_alu_op <= 12'b0;
    else if(ready_go[3] && allow_in[2])
        EXE_alu_op <= alu_op;
end
alu u_alu(
    .alu_op     (EXE_alu_op    ),
    .alu_src1   (EXE_alu_src1  ),
    .alu_src2   (EXE_alu_src2  ),
    .alu_result (alu_result)
    );
reg [3:0] EXE_data_sram_we;
always @(posedge clk) begin
    if(reset || ~ready_go[3] && allow_in[2])
        EXE_data_sram_we <= 4'b0;
    else if(ready_go[3] && allow_in[2])
        EXE_data_sram_we <= {4{mem_we}};
end
reg [31:0] EXE_rkd_value;
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/) EXE_rkd_value <= 32'b0;
    else if(ready_go[3] && allow_in[2]) EXE_rkd_value <= rkd_value;
end
assign data_sram_we    = /*{4{mem_we && valid}}*/ EXE_data_sram_we;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = EXE_rkd_value;
// EXE to MEM
reg EXE_res_from_mem;
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/) EXE_res_from_mem <= 1'b0;
    else if(ready_go[3] && allow_in[2]) EXE_res_from_mem <= res_from_mem;
end
reg MEM_res_from_mem;
always @(posedge clk) begin
    if(reset) MEM_res_from_mem <= 1'b0;
    else if(ready_go[2] && allow_in[1]) MEM_res_from_mem <= EXE_res_from_mem;
end

reg [31:0] MEM_alu_result;
always @(posedge clk) begin
    if(reset) MEM_alu_result <= 32'b0;
    else if(ready_go[2] && allow_in[1]) MEM_alu_result <= alu_result;
end
//reg [31:0] MEM_mem_result;
//always @(posedge clk) begin
//    if(reset) MEM_mem_result <= 32'b0;
//    else if(ready_go[2] && allow_in[1]) MEM_mem_result <= data_sram_rdata;
//end
assign mem_result   = data_sram_rdata/*MEM_mem_result*/;
wire [31:0] final_result = MEM_res_from_mem ? mem_result : MEM_alu_result;
// MEM to WB
reg EXE_gr_we;
always @(posedge clk) begin
    if(reset || ~ready_go[3] && allow_in[2]) EXE_gr_we <= 1'b0;
    else if(ready_go[3] && allow_in[2]) EXE_gr_we <= gr_we;
end
reg MEM_gr_we;
always @(posedge clk) begin
    if(reset) MEM_gr_we <= 1'b0;
    else if(ready_go[2] && allow_in[1]) MEM_gr_we <= EXE_gr_we;
end
reg WB_gr_we;
always @(posedge clk) begin
    if(reset) WB_gr_we <= 1'b0;
    else if(ready_go[1] && allow_in[0]) WB_gr_we <= MEM_gr_we;
end
reg [31:0] WB_final_result;
always @(posedge clk) begin
    if(reset) WB_final_result <= 32'b0;
    else if(ready_go[1] && allow_in[0]) WB_final_result <= final_result;
end
reg [4:0] EXE_dest;
reg [4:0] MEM_dest;
reg [4:0] WB_dest;
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/) EXE_dest <= 5'b0;
    else if(ready_go[3] && allow_in[2]) EXE_dest <= dest;
end
always @(posedge clk) begin
    if(reset) MEM_dest <= 5'b0;
    else if(ready_go[2] && allow_in[1]) MEM_dest <= EXE_dest;
end
always @(posedge clk) begin
    if(reset) WB_dest <= 5'b0;
    else if(ready_go[1] && allow_in[0]) WB_dest <= MEM_dest;
end

assign rf_we    = WB_gr_we/* && valid*/;
assign rf_waddr = WB_dest;
assign rf_wdata = WB_final_result;

always @(posedge clk) begin
    if(reset) ID_pc <= 32'b0;
    else if(ready_go[4] && allow_in[3]) ID_pc <= pc;
end
always @(posedge clk) begin
    if(reset/* || ~ready_go[3] && allow_in[2]*/) EXE_pc <= 32'b0;
    else if(ready_go[3] && allow_in[2]) EXE_pc <= ID_pc;
end
always @(posedge clk) begin
    if(reset) MEM_pc <= 32'b0;
    else if(ready_go[2] && allow_in[1]) MEM_pc <= EXE_pc;
end
always @(posedge clk) begin
    if(reset) WB_pc <= 32'b0;
    else if(ready_go[1] && allow_in[0]) WB_pc <= MEM_pc;
end
// debug info generate
assign debug_wb_pc       = WB_pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = WB_dest;
assign debug_wb_rf_wdata = WB_final_result;
//写后读处理逻辑
//wire isequalwrite = gr_we && dest && rf_we && (dest == WB_dest) && ready_go[3] && allow_in[2];//是否同时完成一个写和同时开始一个写
//reg [2:0] cnt[31:0];
//wire RAWreg1condition = gr_we && dest && ready_go[3] && allow_in[2] && (RAWreg[dest] == 0);
//wire RAWreg0condition = rf_we && WB_dest && (cnt[WB_dest] == 0);
//always @(posedge clk) begin
//    if(reset)
//        RAWreg <= 32'b0;
//    else if(isequalwrite) ;
//    else if(RAWreg1condition && RAWreg0condition)begin
//        RAWreg[dest] <= 1'b1;       // ID置一
//        RAWreg[WB_dest] <= 1'b0;    //WB置零
//    end
//    else if(RAWreg1condition)
//        RAWreg[dest] <= 1'b1;       // ID置一
//    else if(RAWreg0condition)
//        RAWreg[WB_dest] <= 1'b0;    //WB置零
//end
//integer i;
//wire cnt1cond = gr_we && dest && ready_go[3] && allow_in[2] && (RAWreg[dest] == 1);
//wire cnt0cond = rf_we && WB_dest && (cnt[WB_dest] > 0);
//always @(posedge clk) begin
//    if(reset)begin
//        for (i = 0; i < 32; i = i + 1) begin
//          cnt[i] <= 3'b000;
//        end
//    end
//    else if(isequalwrite) ;
//    else if(cnt1cond && cnt0cond)begin
//        cnt[dest] <= cnt[dest] + 1;
//        cnt[WB_dest] <= cnt[WB_dest] - 1;
//    end
//    else if(cnt1cond) begin
//        cnt[dest] <= cnt[dest] + 1;
//    end
//    else if(cnt0cond)
//        cnt[WB_dest] <= cnt[WB_dest] - 1;
//end

//// debug variable
//wire alwayszero = cnt[0][2] | cnt[1][2] | cnt[2][2] | cnt[3][2] |
//                      cnt[4][2] | cnt[5][2] | cnt[6][2] | cnt[7][2] |
//                      cnt[8][2] | cnt[9][2] | cnt[10][2] | cnt[11][2] |
//                      cnt[12][2] | cnt[13][2] | cnt[14][2] | cnt[15][2] |
//                      cnt[16][2] | cnt[17][2] | cnt[18][2] | cnt[19][2] |
//                      cnt[20][2] | cnt[21][2] | cnt[22][2] | cnt[23][2] |
//                      cnt[24][2] | cnt[25][2] | cnt[26][2] | cnt[27][2] |
//                      cnt[28][2] | cnt[29][2] | cnt[30][2] | cnt[31][2];
wire inread1 = ~(inst_bl || inst_b) &&~src1_is_pc;
wire inread2 = ~src2_is_imm | inst_st_w;
//assign RAWblock = rf_raddr1 && inread1 && RAWreg[rf_raddr1] || rf_raddr2 && inread2 && RAWreg[rf_raddr2]; 
assign RAWblock = (inread1 && rf_raddr1 != 0 || inread2 && rf_raddr2 != 0) &&
		(EXE_gr_we && EXE_res_from_mem &&(rf_raddr1 == EXE_dest || rf_raddr2 == EXE_dest));
//forward variable
assign checkequ1 = {WB_gr_we && WB_dest == rf_raddr1, MEM_gr_we && MEM_dest == rf_raddr1, EXE_gr_we && EXE_dest == rf_raddr1};
assign checkequ2 = {WB_gr_we && WB_dest == rf_raddr2, MEM_gr_we && MEM_dest == rf_raddr2, EXE_gr_we && EXE_dest == rf_raddr2};
assign isforward1 = inread1 && rf_raddr1 != 0 && |checkequ1;
assign forwarddata1 = checkequ1[0] ? alu_result :
				      checkequ1[1] ? final_result :
				      checkequ1[2] ? WB_final_result : 32'b0;
assign isforward2 = inread2 && rf_raddr2 != 0 && |checkequ2;
assign forwarddata2 = checkequ2[0] ? alu_result :
				      checkequ2[1] ? final_result :
				      checkequ2[2] ? WB_final_result : 32'b0;
endmodule
