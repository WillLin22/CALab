module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
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

reg         valid;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [15:0] alu_op;
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

//--  water flow control regs

wire allow_in_IF,allow_in_ID,allow_in_EX,allow_in_MEM,allow_in_WB;
wire ready_go_IF,ready_go_ID,ready_go_EX,ready_go_MEM,ready_go_WB;
reg valid_IF,valid_ID,valid_EX,valid_MEM,valid_WB;

wire [31:0] pc_IF;
reg [31:0] pc_ID;
reg [31:0] alu_src1_EX, alu_src2_EX, rj_value_EX, rkd_value_EX, data_sram_wdata_EX, pc_EX, br_target_EX;
reg [11:0] alu_op_EX;
reg [4:0] dest_EX;
reg [3:0] mem_we_EX;
reg mem_en_EX, res_from_mem_EX, rf_we_EX, br_taken_EX;
reg [31:0] result_all_MEM, pc_MEM;
reg [4:0] dest_MEM;
reg res_from_mem_MEM,rf_we_MEM;
reg [4:0] dest_WB;
reg [31:0] final_result_WB, pc_WB;
reg rf_we_WB;


assign inst_sram_we    = 4'b0;
assign inst_sram_wdata = 32'b0;

//--  inst decode for ID
assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

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
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

//--  new instr
wire inst_slti, inst_sltui, inst_andi, inst_ori,
     inst_xori, inst_sll_w, inst_srl_w, inst_sra_w, inst_pcaddu12i,
     inst_mul_w, inst_mulh_w, inst_mulh_wu, inst_div_w, inst_mod_w,
     inst_div_wu, inst_mod_wu, inst_blt, inst_bge, inst_bltu, inst_bgeu,
     inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu, inst_st_b, inst_st_h;

assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h0e];

assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];

assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];


//--

assign alu_op[ 0] = inst_add_w | inst_addi_w 
                    | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu
                    | inst_st_w | inst_st_b | inst_st_h
                    | inst_jirl | inst_bl
                    | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu| inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or  | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;

wire if_divider;        //EX流水段是否需要等待多周期除法器结束计算，即是否是除法指令
assign if_divider = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w| inst_st_b | inst_st_h | inst_st_w | inst_ld_b | inst_ld_bu| inst_ld_h | inst_ld_hu | inst_ld_w | inst_slti | inst_sltui;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

//new need_ui12
wire need_ui12;
assign need_ui12 =  inst_andi | inst_ori | inst_xori;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
            need_ui5 || need_si12  ?{{20{i12[11]}}, i12[11:0]}  :
            /*need_ui12*/{{20'b0}, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                       inst_st_w | inst_st_b | inst_st_h;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i |
                    
                       inst_ld_w   | inst_ld_b | inst_ld_h   | inst_ld_bu | inst_ld_hu  |
                       inst_st_w   | inst_st_b | inst_st_h |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w |inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_st_b & ~inst_st_h;
assign mem_we        = inst_st_w|inst_st_b|inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : rd;

wire [31:0] data_sram_wdata_ID;
assign data_sram_wdata_ID = rkd_value;
//* reg read replace for forward

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

wire rf_rd1_is_forward,rf_rd2_is_forward;
wire[31:0] rf_rdata1_forward,rf_rdata2_forward;
//select forward or not
assign rj_value  =rf_rd1_is_forward?rf_rdata1_forward: rf_rdata1;
assign rkd_value = rf_rd2_is_forward?rf_rdata2_forward: rf_rdata2;
//* end
assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign mem_result   = data_sram_rdata;


//--  debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

//--  Waterflow
//IF, ID, EX, MEM, WB
//--  Handshake
assign allow_in_IF = (allow_in_ID && ready_go_IF)&valid;
assign allow_in_ID = (allow_in_EX && ready_go_ID)&valid;
assign allow_in_EX = (allow_in_MEM && ready_go_EX)&valid;
assign allow_in_MEM = (allow_in_WB && ready_go_MEM)&valid;
assign allow_in_WB = ready_go_WB && valid;

//--  Pre-IF stage
wire br_concel;

assign seq_pc       = pc + 3'h4;
assign nextpc       = br_taken&valid_ID ? br_target : seq_pc;
assign inst_sram_en = 1'b1;
assign inst_sram_addr = pc;

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1c000000;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(allow_in_IF) begin
        pc <= nextpc;
    end
end
//-- IF stage

always @(posedge clk) begin
    if (reset) begin
        pc_ID <= 32'h0;
    end
    else if(allow_in_IF) begin
        pc_ID <= pc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        valid_IF <= 1'b0;
    end
    else begin
        valid_IF <= 1'b1;
    end
end
assign ready_go_IF = 1'b1;

assign pc_IF=pc;

//-- ID stage

//* WAR
//inst save for wait
reg[31:0] inst_reg;

reg use_inst_reg;
assign inst            = use_inst_reg? inst_reg : inst_sram_rdata;//如果下一周期不接受新指令，则需要把当前指令保存起来，以便下一周期使用
always @(posedge clk) begin  
    if (reset) begin
        use_inst_reg <= 1'b0;
    end
    else begin
        use_inst_reg <= ~allow_in_ID;
    end
end

always @(posedge clk) begin
    if (reset) begin
        inst_reg <= 32'b0;
    end
    else if(~allow_in_ID) begin
        inst_reg <= inst;
    end
end
//reg forward
//0 EX, 1 MEM, 2 WB
wire[31:0] result_forward[2:0];
wire[4:0] dest_forward[2:0];

//match
wire[2:0] match_forward1,match_forward2;
assign match_forward1 = {dest_forward[2]==rf_raddr1,dest_forward[1]==rf_raddr1,dest_forward[0]==rf_raddr1};
assign match_forward2 = {dest_forward[2]==rf_raddr2,dest_forward[1]==rf_raddr2,dest_forward[0]==rf_raddr2};

//accept by priority
wire[2:0] accept_forward1,accept_forward2;
assign accept_forward1 = {match_forward1[2]&~match_forward1[1]&~match_forward1[0],match_forward1[1]&~match_forward1[0],match_forward1[0]};
assign accept_forward2 = {match_forward2[2]&~match_forward2[1]&~match_forward2[0],match_forward2[1]&~match_forward2[0],match_forward2[0]};

//forward selector
wire rf_rd1_nz,rf_rd2_nz;
assign rf_rd1_nz = (|rf_raddr1);
assign rf_rd2_nz = (|rf_raddr2);

assign rf_rd1_is_forward = (|accept_forward1)&rf_rd1_nz;//!读0号寄存器不需要前递
assign rf_rd2_is_forward = (|accept_forward2)&rf_rd2_nz;
assign rf_rdata1_forward = result_forward[2]&{32{accept_forward1[2]}}|result_forward[1]&{32{accept_forward1[1]}}|result_forward[0]&{32{accept_forward1[0]}};
assign rf_rdata2_forward = result_forward[2]&{32{accept_forward2[2]}}|result_forward[1]&{32{accept_forward2[1]}}|result_forward[0]&{32{accept_forward2[0]}};

//decide to wait or not
reg[31:0] reg_for_writeback;
wire[31:0] reg_is_writing, reg_want_writing,rf_waddr_dec, dest_dec, reg_is_war;
decoder_5_32 reg_dec(
    .in(rf_waddr),
    .out(rf_waddr_dec)
);
decoder_5_32 reg_dec2(
    .in(dest),
    .out(dest_dec)
);
assign reg_is_writing = rf_waddr_dec&{32{rf_we}};
assign reg_want_writing = dest_dec&{32{valid_ID&gr_we&valid&dest!=5'd0&allow_in_EX&ready_go_ID}};

always @(posedge clk) begin
    if (reset) begin
        reg_for_writeback <= 32'b0;
    end
    else begin 
        reg_for_writeback <= (reg_for_writeback | reg_want_writing)&~reg_is_writing;
    end
end
//decide ready_go_ID
wire used_rj,used_rkd;

assign used_rj=~(inst_bl||inst_b)&~src1_is_pc;
assign used_rkd=~src2_is_imm|inst_st_w|inst_st_b|inst_st_h;
assign reg_is_war = reg_is_writing|reg_for_writeback;//当前正在写或者还没写回的寄存器
assign ready_go_ID =~( (reg_is_war[rf_raddr1]&used_rj&~rf_rd1_is_forward&rf_rd1_nz)
                      |(reg_is_war[rf_raddr2]&used_rkd&~rf_rd2_is_forward&rf_rd2_nz));//If forward, then go.
// end WAR

always @(posedge clk) begin
    if (reset) begin
        alu_src1_EX <= 32'b0;
        alu_src2_EX <= 32'b0;
        alu_op_EX   <= 12'b0;
        rj_value_EX <= 32'b0;
        rkd_value_EX <= 32'b0;
        dest_EX     <= 5'b0;
        data_sram_wdata_EX <= 32'b0;
        res_from_mem_EX <= 1'b0;
        rf_we_EX    <= 1'b0;
        mem_we_EX   <= 4'b0;
        mem_en_EX   <= 1'b0;
        pc_EX       <= 32'b0;
    end
    else if(allow_in_ID)begin
        alu_src1_EX <= alu_src1;
        alu_src2_EX <= alu_src2;
        alu_op_EX   <= alu_op;
        rj_value_EX <= rj_value;
        rkd_value_EX <= rkd_value;
        dest_EX     <= dest;
        data_sram_wdata_EX <= data_sram_wdata_ID;
        mem_we_EX   <= mem_we;
        mem_en_EX   <= res_from_mem;
        res_from_mem_EX <= res_from_mem;
        rf_we_EX    <= gr_we & valid;
        pc_EX <= pc_ID;
    end
end

always @(posedge clk) begin
    if (reset) begin
        valid_ID <= 1'b0;
    end
    else if(br_taken && valid_ID && ready_go_ID) begin //只有IF取了错指令，而且ID指令有效，而且EX准备接受，才把valid=0传下去
        valid_ID <= 1'b0;
    end
    else if(allow_in_ID) begin
        valid_ID <= valid_IF && ready_go_IF;
    end
end

//-- EX stage

alu u_alu(
    .alu_op     (alu_op_EX    ),
    .alu_src1   (alu_src1_EX  ),
    .alu_src2   (alu_src2_EX  ),
    .alu_result (alu_result) //contain mul type insts
    );

wire [31:0] divider_dividend,divider_divisor;
wire [63:0] unsigned_divider_res,signed_divider_res;

wire unsigned_dividend_tready,unsigned_dividend_tvalid,unsigned_divisor_tready,unsigned_divisor_tvalid,unsigned_dout_tvalid;
wire signed_dividend_tready,signed_dividend_tvalid,signed_divisor_tready,signed_divisor_tvalid,signed_dout_tvalid;

assign divider_dividend = rj_value_EX;
assign divider_divisor  = rkd_value_EX;

unsigned_divider u_unsigned_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (unsigned_dividend_tready),
    .s_axis_dividend_tvalid (unsigned_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (unsigned_divisor_tready),
    .s_axis_divisor_tvalid  (unsigned_divisor_tvalid),
    .m_axis_dout_tdata      (unsigned_divider_res),
    .m_axis_dout_tvalid     (unsigned_dout_tvalid)
);

signed_divider u_signed_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (signed_dividend_tready),
    .s_axis_dividend_tvalid (signed_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (signed_divisor_tready),
    .s_axis_divisor_tvalid  (signed_divisor_tvalid),
    .m_axis_dout_tdata      (signed_divider_res),
    .m_axis_dout_tvalid     (signed_dout_tvalid)
);

reg signed_dividend_tvalid_reg, signed_divisor_tvalid_reg;
reg unsigned_dividend_tvalid_reg, unsigned_divisor_tvalid_reg;

always@(posedge clk) begin
    if(reset) begin
        unsigned_dividend_tvalid_reg <= 1'b0;
        unsigned_divisor_tvalid_reg <= 1'b0;
    end
    else if (unsigned_dividend_tready && unsigned_divisor_tready) begin //如果实际运行的时候发现dividend_tready和divisor_tready不一定是同时拉高，可能需要把两个always块拆成四个
        unsigned_dividend_tvalid_reg <= 1'b0;
        unsigned_divisor_tvalid_reg <= 1'b0;
    end
    else if (allow_in_EX && (inst_div_wu | inst_mod_wu)) begin
        unsigned_dividend_tvalid_reg <= 1'b1;
        unsigned_divisor_tvalid_reg <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        signed_dividend_tvalid_reg <= 1'b0;
        signed_divisor_tvalid_reg <= 1'b0;
    end
    else if (signed_dividend_tready && signed_divisor_tready) begin
        signed_dividend_tvalid_reg <= 1'b0;
        signed_divisor_tvalid_reg <= 1'b0;
    end
    else if (allow_in_EX && (inst_div_w | inst_mod_w)) begin
        signed_dividend_tvalid_reg <= 1'b1;
        signed_divisor_tvalid_reg <= 1'b1;
    end
end

assign unsigned_dividend_tvalid = unsigned_dividend_tvalid_reg;
assign unsigned_divisor_tvalid = unsigned_divisor_tvalid_reg;
assign signed_dividend_tvalid = signed_dividend_tvalid_reg;
assign signed_divisor_tvalid = signed_divisor_tvalid_reg;

wire [31:0] div_result;
assign div_result = (inst_div_wu) ? unsigned_divider_res[63:32] : 
                    (inst_div_w)  ? signed_divider_res[63:32] : 
                    (inst_mod_wu) ? unsigned_divider_res[31:0] : signed_divider_res[31:0];

wire[31:0] result_all;
assign result_all = if_divider ? div_result : alu_result;

always @(posedge clk) begin
    if (reset) begin
        res_from_mem_MEM <= 1'b0;
        rf_we_MEM <= 1'b0;
        dest_MEM <= 5'b0;
        result_all_MEM <= 32'b0;
        pc_MEM <= 32'b0;
    end
    else if(allow_in_EX)begin
        res_from_mem_MEM <= res_from_mem_EX;
        rf_we_MEM <= rf_we_EX;
        result_all_MEM <= result_all;    
        dest_MEM <= dest_EX;
        pc_MEM <= pc_EX;
    end
end

assign result_forward[0] = alu_result;
//!计算的结果是内存地址，不需要前递
assign dest_forward[0] = dest_EX & {5{~res_from_mem_EX & rf_we_EX & valid_EX & ready_go_EX}};//If the result will WB, then forward.

always @(posedge clk) begin
    if (reset) begin
        valid_EX <= 1'b0;
    end
    else if(allow_in_EX) begin
        valid_EX <= valid_ID && ready_go_ID;
    end
end

assign ready_go_EX = if_divider ? (unsigned_dout_tvalid || signed_dout_tvalid) : 1'b1;


//-- MEM stage

assign data_sram_en    = (mem_we_EX||res_from_mem_EX) && valid && valid_EX && ready_go_EX; //实际上要有EX的寄存器发请求，MEM才能接受
assign data_sram_we    = mem_we_EX? 4'b1111 : 4'b0;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = data_sram_wdata_EX;
wire[31:0] final_result_MEM;
assign final_result_MEM = res_from_mem_MEM ? mem_result : result_all_MEM;

always @(posedge clk) begin
    if (reset) begin
        final_result_WB <= 32'b0;
        pc_WB <= 32'b0;
        dest_WB <= 5'b0;
        rf_we_WB <= 1'b0;
    end
    else if(allow_in_MEM) begin
        final_result_WB <= final_result_MEM;
        pc_WB <= pc_MEM;
        dest_WB <= dest_MEM;
        rf_we_WB <= rf_we_MEM;
    end
end

assign result_forward[1] = final_result_MEM;
assign dest_forward[1] = dest_MEM & {5{rf_we_MEM & valid_MEM & ready_go_MEM}};

always @(posedge clk) begin
    if (reset) begin
        valid_MEM <= 1'b0;
    end
    else if(allow_in_MEM) begin
        valid_MEM <= valid_EX && ready_go_EX;
    end
end

assign ready_go_MEM = 1'b1;

//-- WB stage

assign rf_we    = rf_we_WB && valid_WB;
assign rf_waddr = dest_WB;
assign rf_wdata = final_result_WB;
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

always @(posedge clk) begin
    if (reset) begin
        valid_WB <= 1'b0;
    end
    else if(allow_in_WB) begin
        valid_WB <= valid_MEM && ready_go_MEM;
    end
end

assign result_forward[2] = final_result_WB;
assign dest_forward[2] = dest_WB & {5{rf_we_WB & valid_WB & ready_go_WB}};

assign ready_go_WB = 1'b1;

endmodule