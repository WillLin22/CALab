`include "csr_defines.vh"
module mycpu_core
#(
    parameter TLBNUM = 16
)
(
    input  wire        clk,
    input  wire        resetn,

    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,         
    input  wire [31:0] inst_sram_rdata,

    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0]  data_sram_size,
    output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok, 
    input  wire [31:0] data_sram_rdata,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
wire reset = ~resetn;

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
wire [31:0] inst = inst_sram_rdata;
reg  [31:0] pc;

wire [14:0] alu_op;
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

//-- inst
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
wire inst_slti, inst_sltui, inst_andi, inst_ori,
     inst_xori, inst_sll_w, inst_srl_w, inst_sra_w, inst_pcaddu12i,
     inst_mul_w, inst_mulh_w, inst_mulh_wu, inst_div_w, inst_mod_w,
     inst_div_wu, inst_mod_wu, inst_blt, inst_bge, inst_bltu, inst_bgeu,
     inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu, inst_st_b, inst_st_h;
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
wire        inst_rdcntid;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
// exp17
wire inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill;
wire inst_invtlb;
// 新的指令声明放这里
//-- INE
wire INE_ID;
assign INE_ID = ~(inst_sltui | inst_mod_w | inst_blt | inst_ld_hu | inst_or | inst_and | inst_syscall | inst_sltu | inst_add_w | inst_sra_w | inst_mod_wu | inst_csrwr | inst_ori | inst_b | inst_sub_w | inst_bne | inst_div_wu | inst_ld_h | inst_st_w | inst_beq | inst_div_w | inst_csrrd | inst_jirl | inst_andi | inst_xori | inst_srl_w | inst_ld_bu | inst_nor | inst_bltu | inst_mulh_wu | inst_slli_w | inst_mulh_w | inst_mul_w | inst_csrxchg | inst_xor | inst_ld_b | inst_bge | inst_st_b | inst_addi_w | inst_ld_w | inst_bgeu | inst_bl | inst_slti | inst_slt | inst_sll_w | inst_srli_w | inst_ertn | inst_lu12i_w | inst_st_h | inst_srai_w | inst_pcaddu12i | inst_break | inst_rdcntid | inst_rdcntvh_w | inst_rdcntvl_w | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb)
| (inst_invtlb && $unsigned(dest) > 5'd6);//updated:exp18:reserved command exc

//--

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

wire [3:0]  mem_offset_d;
wire [31:0] mem_rdata_w;
wire [15:0] mem_rdata_h;
wire [ 7:0] mem_rdata_b;
wire [31:0] mem_result;

// CSR接口起点声明
wire [13:0]csr_num_ID;  
wire [14:0]code_ID; 
wire csr_re_ID;   
wire csr_write_ID;
wire [31:0]csr_wmask_ID;

//* CSR模块接口
wire exception_WB;
wire flush_all;
wire csr_re; 
wire [13:0]csr_num; //input,目标csr编号
wire [31:0] csr_rvalue;//output,csr读取的值
wire csr_we; 
wire [31:0]csr_wmask; 
wire [31:0] csr_wvalue; 
wire [31:0] ex_entry;// output,送往pre-IF级的异常处理地址
wire has_int;// output,送往 ID 级的中断有效信号
wire [31:0] ertn_pc;// output,送往pre-IF级的异常返回地址
wire ertn_flush;// 来自WB级的ertn执行的有效信号
wire wb_ex;//来自wb级的异常触发信号 
wire [5:0] wb_ecode;
wire [8:0] wb_esubcode;
wire [31:0] wb_pc;// 来自WB级的异常发生地址
wire [31:0] wb_vaddr;// 来自WB级的异常发生地址

wire dst_is_rj;//寄存器写目标是否是rj，专为rdcntid指令设计，用于修改dest变量

wire csrr_is_rdcnts;//csr读指令是否是rdcnts指令，用于修改csr_num_EX
wire [13:0] csrr_rdcnts_num;//rdcnts指令的csr_num

wire req_inst, addr_ok_inst, data_ok_inst;
wire req_mem, addr_ok_mem, data_ok_mem;
//状态机
reg [2:0]state_IF;
reg state_ID;
reg [3:0] state_EX, state_MEM;
//异步的valid，表明该指令可以产生效果
wire effectful_IF, effectful_ID, effectful_EX, effectful_MEM, effectful_WB;

reg [31:0] nextpc_reg;
reg not_accepted;
//exp18
//ID阶段产生的对应csr的we接口的信号
wire we_ID;
//ID阶段产生的对应csr的wop接口的信号
wire [3:0] wop_ID;
//用于tlbfill指令中的分配一个新的tlb路。该线连接于模块tlballoc，定义于tlb.v中
wire [$clog2(TLBNUM)-1:0]tlbidx_alloc;
//为csr单独开的tlb接口，因为tlb相关操作会同时涉及多个csr的读写，没法复用先前的接口
//带in的均为csr模块的input，带out的均为csr模块的output，以下tlb部分也是一样
//write
wire                        csr_in_tlb_w_we;
wire [3:0]                  csr_in_tlb_w_op;
wire                        csr_in_tlb_w_e;
wire [$clog2(TLBNUM)-1:0]   csr_in_tlb_w_idx;
wire [18:0]                 csr_in_tlb_w_vppn;
wire [ 5:0]                 csr_in_tlb_w_ps;
wire [ 9:0]                 csr_in_tlb_w_asid;
wire                        csr_in_tlb_w_g;
wire [19:0]                 csr_in_tlb_w_ppn0;
wire [ 1:0]                 csr_in_tlb_w_plv0;
wire [ 1:0]                 csr_in_tlb_w_mat0;
wire                        csr_in_tlb_w_d0;
wire                        csr_in_tlb_w_v0;       
wire [19:0]                 csr_in_tlb_w_ppn1;
wire [ 1:0]                 csr_in_tlb_w_plv1;
wire [ 1:0]                 csr_in_tlb_w_mat1;
wire                        csr_in_tlb_w_d1;
wire                        csr_in_tlb_w_v1;
//read
wire                        csr_out_tlb_r_e;
wire [$clog2(TLBNUM)-1:0]   csr_out_tlb_r_idx;
wire [18:0]                 csr_out_tlb_r_vppn;
wire [ 5:0]                 csr_out_tlb_r_ps;
wire [ 9:0]                 csr_out_tlb_r_asid;
wire                        csr_out_tlb_r_g;
wire [19:0]                 csr_out_tlb_r_ppn0;
wire [ 1:0]                 csr_out_tlb_r_plv0;
wire [ 1:0]                 csr_out_tlb_r_mat0;
wire                        csr_out_tlb_r_d0;
wire                        csr_out_tlb_r_v0;
wire [19:0]                 csr_out_tlb_r_ppn1;
wire [ 1:0]                 csr_out_tlb_r_plv1;
wire [ 1:0]                 csr_out_tlb_r_mat1;
wire                        csr_out_tlb_r_d1;
wire                        csr_out_tlb_r_v1;
//tlb接口
//tlb为纯组合逻辑，不占时钟周期
//s0对应instfetch部分，因为exp18还没有实现虚拟内存，因此只是定义好了tlb的接口并连上了tlb，但cpu端还没有连东西
wire [18:0]                 tlb_in_s0_vppn;
wire                        tlb_in_s0_va_bit12;
wire [ 9:0]                 tlb_in_s0_asid;
wire                        tlb_out_s0_found;
wire [$clog2(TLBNUM)-1:0]   tlb_out_s0_idx;
wire [19:0]                 tlb_out_s0_ppn;
wire [ 5:0]                 tlb_out_s0_ps;
wire [ 1:0]                 tlb_out_s0_plv;
wire [ 1:0]                 tlb_out_s0_mat;
wire                        tlb_out_s0_d;
wire                        tlb_out_s0_v;
//s1对应ld/store部分，同上，cpu端还没有连东西
wire [18:0]                 tlb_in_s1_vppn;
wire                        tlb_in_s1_va_bit12;
wire [ 9:0]                 tlb_in_s1_asid;
wire                        tlb_out_s1_found;
wire [$clog2(TLBNUM)-1:0]   tlb_out_s1_idx;
wire [19:0]                 tlb_out_s1_ppn;
wire [ 5:0]                 tlb_out_s1_ps;
wire [ 1:0]                 tlb_out_s1_plv;
wire [ 1:0]                 tlb_out_s1_mat;
wire                        tlb_out_s1_d;
wire                        tlb_out_s1_v;
//用于invtlb指令，不出意外应该不会在exp19修改了我猜
wire                        tlb_in_invtlb_valid;
wire [4:0]                  tlb_in_invtlb_op;
wire [9:0]                  tlb_in_invtlb_asid;
wire [18:0]                 tlb_in_invtlb_va;
//tlb写端口
wire                        tlb_in_we;//写使能
wire [$clog2(TLBNUM)-1:0]   tlb_in_w_idx;
wire                        tlb_in_w_e;
wire [18:0]                 tlb_in_w_vppn;
wire [ 5:0]                 tlb_in_w_ps;
wire [ 9:0]                 tlb_in_w_asid;
wire                        tlb_in_w_g;
wire [19:0]                 tlb_in_w_ppn0;
wire [ 1:0]                 tlb_in_w_plv0;
wire [ 1:0]                 tlb_in_w_mat0;
wire                        tlb_in_w_d0;
wire                        tlb_in_w_v0;
wire [19:0]                 tlb_in_w_ppn1;
wire [ 1:0]                 tlb_in_w_plv1;
wire [ 1:0]                 tlb_in_w_mat1;
wire                        tlb_in_w_d1;
wire                        tlb_in_w_v1;
//tlb读端口，不占时钟周期
wire [$clog2(TLBNUM)-1:0]   tlb_in_r_idx;
wire                        tlb_out_r_e;
wire [18:0]                 tlb_out_r_vppn;
wire [ 5:0]                 tlb_out_r_ps;
wire [ 9:0]                 tlb_out_r_asid;
wire                        tlb_out_r_g;
wire [19:0]                 tlb_out_r_ppn0;
wire [ 1:0]                 tlb_out_r_plv0;
wire [ 1:0]                 tlb_out_r_mat0;
wire                        tlb_out_r_d0;
wire                        tlb_out_r_v0;
wire [19:0]                 tlb_out_r_ppn1;
wire [ 1:0]                 tlb_out_r_plv1;
wire [ 1:0]                 tlb_out_r_mat1;
wire                        tlb_out_r_d1;
wire                        tlb_out_r_v1;
//tlbsrch
//为tlbsrch指令单独开了以下四个端口
wire [18:0]                 tlb_in_srch_vppn;
wire [ 9:0]                 tlb_in_srch_asid;
wire                        tlb_out_srch_found;
wire [$clog2(TLBNUM)-1:0]   tlb_out_srch_idx;
//tlbdmw  --exp19
wire                        tlb_dmw0_plv0; // 为1表示在PLV0下可以使用该窗口进行直接映射地址翻译
wire                        tlb_dmw0_plv3; // 为1表示在PLV3下可以使用该窗口进行直接映射地址翻译
wire [ 1:0]                 tlb_dmw0_mat;  // 虚地址落在该映射窗口下访存操作的存储类型访问
wire [ 2:0]                 tlb_dmw0_pseg; // 直接映射窗口物理地址高3位
wire [ 2:0]                 tlb_dmw0_vseg; // 直接映射窗口虚地址高3位
wire                        tlb_dmw1_plv0;
wire                        tlb_dmw1_plv3;
wire [ 1:0]                 tlb_dmw1_mat;
wire [ 2:0]                 tlb_dmw1_pseg;
wire [ 2:0]                 tlb_dmw1_vseg;
//nextpc  --exp19
wire [31:0]                 nextpc_direct; // 直接地址翻译
wire [31:0]                 nextpc_dmw0, nextpc_dmw1; // 直接映射窗口地址翻译
wire [31:0]                 nextpc_tlb;    // tlb地址翻译
wire [31:0]                 nextpc_physical; // 物理地址

// addr_EX  --exp19
wire [31:0]                 addr_ex_direct; // 访存直接地址翻译
wire [31:0]                 addr_ex_dmw0, addr_ex_dmw1; // 访存直接映射窗口地址翻译
wire [31:0]                 addr_ex_tlb;    // 访存tlb地址翻译
wire [31:0]                 addr_ex_physical; // 访存物理地址

wire if_trans_direct, if_trans_dmw0, if_trans_dmw1, if_trans_tlb;  // IF 级翻译模式控制信号
wire ex_trans_direct, ex_trans_dmw0, ex_trans_dmw1, ex_trans_tlb;  // EX 级翻译模式控制信号

//新的定义的线或接口的声明写这里


//--  water flow control regs
//* allow_ready
wire allow_in_IF,allow_in_ID,allow_in_EX,allow_in_MEM,allow_in_WB;//下一时钟周期是否允许进入该流水段
wire ready_go_IF,ready_go_ID,ready_go_EX,ready_go_MEM,ready_go_WB;//这一时钟周期是否准备好数据
wire handshake_IF_ID = allow_in_ID & ready_go_IF;
wire handshake_ID_EX = allow_in_EX & ready_go_ID;
wire handshake_EX_MEM = allow_in_MEM & ready_go_EX;
wire handshake_MEM_WB = allow_in_WB & ready_go_MEM;
reg valid_IF;
reg valid_ID,valid_EX,valid_MEM,valid_WB;
//* data
wire [31:0] pc_IF;
reg [31:0] pc_ID;
reg [31:0] instreg_IF;//取指阶段若dataok到来时未握手则暂存指令
reg [31:0] inst_ID;//ID阶段的译码指令
wire [31:0] mem_wdata_ID;
reg [31:0] alu_src1_EX, alu_src2_EX, rj_value_EX,rj_value_MEM, rj_value_WB, rkd_value_EX,rkd_value_MEM, rkd_value_WB, mem_wdata_EX, pc_EX;//exp18 update:增加了rj_value_MEM, rj_value_WB, rkd_value_MEM, rkd_value_WB
reg [14:0] alu_op_EX;
reg [4:0] dest_EX;
reg mem_we_EX;
reg res_from_mem_EX, rf_we_EX;
reg [31:0] result_all_MEM, pc_MEM;
reg [4:0] dest_MEM;
reg res_from_mem_MEM,rf_we_MEM;
reg [4:0] dest_WB;
reg [31:0] final_result_WB, pc_WB;
reg rf_we_WB;

reg if_divider_EX;

wire data_sram_en_EX;
reg data_sram_en_MEM;
wire [3:0] data_sram_we_EX;
reg [3:0] data_sram_we_MEM;
wire [31:0] data_sram_addr_EX;
reg [31:0] data_sram_addr_MEM;
wire [31:0] data_sram_wdata_EX;
reg [31:0] data_sram_wdata_MEM;
reg [31:0] data_sram_rdata_reg;

reg mem_byte_EX, mem_half_EX, mem_word_EX;
reg mem_byte_MEM, mem_half_MEM, mem_word_MEM;

reg mem_signed_EX;
reg mem_signed_MEM;

reg[1:0] mem_offset_MEM;

reg inst_div_w_EX, inst_div_wu_EX, inst_mod_w_EX, inst_mod_wu_EX;
//异常处理相关数据通路
//* excs
reg flush_all_ID;
reg exc_adef_ID,        exc_adef_EX,        exc_adef_MEM,   exc_adef_WB;//取指阶段地址异常
reg exc_ine_EX,         exc_ine_MEM,        exc_ine_WB;//指令不存在
reg exc_int_EX,         exc_int_MEM,        exc_int_WB;//中断
reg exc_ale_MEM,        exc_ale_WB;//访存异常
reg exc_break_EX,       exc_break_MEM,      exc_break_WB;//inst_break
reg exc_syscall_EX,     exc_syscall_MEM,    exc_syscall_WB;//inst_syscall
//* csr
reg [13:0] csr_num_EX,  csr_num_MEM,        csr_num_WB;
reg [14:0] code_EX,     code_MEM,           code_WB;
reg csr_re_EX,          csr_re_MEM,         csr_re_WB;
reg csr_write_EX,       csr_write_MEM,      csr_write_WB;
reg [31:0] csr_wmask_EX, csr_wmask_MEM,     csr_wmask_WB;
reg ertn_flush_EX,      ertn_flush_MEM,     ertn_flush_WB;
reg flush_all_EX,       flush_all_MEM,      flush_all_WB;
reg [31:0] csr_wvalue_MEM, csr_wvalue_WB;
reg [31:0] vaddr_MEM,   vaddr_WB;

//exp18
reg invtlb_EX, invtlb_MEM, invtlb_WB;
reg we_EX, we_MEM, we_WB;
reg [3:0] wop_EX, wop_MEM, wop_WB;

//exp19
wire exc_fs_tlb_refill_IF;
reg exc_fs_tlb_refill_ID, exc_fs_tlb_refill_EX, exc_fs_tlb_refill_MEM, exc_fs_tlb_refill_WB;  // IF 级的 TLB 重填例外
wire exc_es_tlb_refill_EX;
reg exc_es_tlb_refill_MEM, exc_es_tlb_refill_WB;  // EX 级的 TLB 重填例外

wire exc_es_load_invalid_EX;
reg exc_es_load_invalid_MEM, exc_es_load_invalid_WB;  // EX 级的load操作页无效例外
wire exc_es_store_invalid_EX;
reg exc_es_store_invalid_MEM, exc_es_store_invalid_WB;  // EX 级的 store操作页无效例外
wire exc_fs_fetch_invalid_IF;
reg exc_fs_fetch_invalid_ID, exc_fs_fetch_invalid_EX, exc_fs_fetch_invalid_MEM, exc_fs_fetch_invalid_WB;  // IF 级的取指操作页无效例外
wire exc_es_modify_EX;
reg exc_es_modify_MEM, exc_es_modify_WB;  // EX 级的页修改例外
wire exc_fs_plv_invalid_IF;
reg exc_fs_plv_invalid_ID, exc_fs_plv_invalid_EX, exc_fs_plv_invalid_MEM, exc_fs_plv_invalid_WB;  // IF 级的页特权等级不合规例外
wire exc_es_plv_invalid_EX;
reg exc_es_plv_invalid_MEM, exc_es_plv_invalid_WB;  // EX 级的页特权等级不合规例外
wire to_csr_exc_fs_tlb_refill, to_csr_exc_fs_plv_invalid; // 送往 CSR 例外的信号，用于区分记录例外地址时是 pc（IF级） 还是 vaddr（EX级）
wire [1:0] crmd_datm;
wire [1:0] crmd_plv;

// tlb_crush_related --exp18&19
wire tlb_reflush;
wire [31:0] tlb_reflush_pc;
wire tlb_refetch_ID;
reg tlb_refetch_EX, tlb_refetch_MEM, tlb_refetch_WB;
wire tlb_refetch_tlb_inst_ID, tlb_refetch_csr_inst_ID;
wire inst_tlbrd_EX, inst_tlbrd_MEM, inst_tlbrd_WB;


//新的添加的通路声明放这里
//--  inst decode for ID
assign op_31_26  = inst_ID[31:26];
assign op_25_22  = inst_ID[25:22];
assign op_21_20  = inst_ID[21:20];
assign op_19_15  = inst_ID[19:15];

assign rd   = inst_ID[ 4: 0];
assign rj   = inst_ID[ 9: 5];
assign rk   = inst_ID[14:10];

assign i12  = inst_ID[21:10];
assign i20  = inst_ID[24: 5];
assign i16  = inst_ID[25:10];
assign i26  = {inst_ID[ 9: 0], inst_ID[25:10]};

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
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst_ID[25];


assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst_ID[25];

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

assign inst_csrrd = op_31_26_d[6'h1] & ~inst_ID[25] & ~inst_ID[24] & (rj==0);
assign inst_csrwr = op_31_26_d[6'h1] & ~inst_ID[25] & ~inst_ID[24] & (rj==1);
assign inst_csrxchg = op_31_26_d[6'h1] & ~inst_ID[25] & ~inst_ID[24] & (rj!=0 & rj!=1);
assign inst_ertn = op_31_26_d[6'h1] & op_25_22_d[4'h9] 
                 & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01110);
assign inst_syscall = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

assign inst_break = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntid = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (inst_ID[14:10] == 5'b11000) & (inst_ID[4:0] == 5'b00000);
assign inst_rdcntvl_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (inst_ID[14:10] == 5'b11000) & (inst_ID[9:5] == 5'b00000);
assign inst_rdcntvh_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (inst_ID[14:10] == 5'b11001) & (inst_ID[9:5] == 5'b00000);

assign inst_tlbsrch = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & inst_ID[14:10] == 5'b01010 & (~|inst[9:0]);
assign inst_tlbrd   = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & inst_ID[14:10] == 5'b01011 & (~|inst[9:0]);
assign inst_tlbwr   = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & inst_ID[14:10] == 5'b01100 & (~|inst[9:0]);
assign inst_tlbfill = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & inst_ID[14:10] == 5'b01101 & (~|inst[9:0]);

assign inst_invtlb  = op_31_26_d[6'h1] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

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
                       inst_st_w | inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csrxchg;

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
assign dst_is_rj     = inst_rdcntid;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_st_b & ~inst_st_h & ~inst_bge & ~inst_bgeu & ~inst_blt & ~inst_bltu & ~inst_ertn & ~inst_tlbsrch &~inst_tlbrd &~inst_tlbwr &~inst_tlbfill &~inst_invtlb;// updated:exp17, TLB 相关均无寄存器写  
assign mem_we        = inst_st_w|inst_st_b|inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : 
                      dst_is_rj ? rj : rd;


// EX exception --exp19
assign exc_es_tlb_refill_EX = ex_trans_tlb & (res_from_mem_EX | mem_we_EX) & ~tlb_out_s1_found; // 当访存操作的虚地址在 TLB 中查找没有匹配项时，触发该例外，通知系统软件进行 TLB 重填工作
assign exc_es_load_invalid_EX = ex_trans_tlb & res_from_mem_EX & tlb_out_s1_found & ~tlb_out_s1_v; // load 操作的虚地址在 TLB 中找到了匹配项但是匹配页表项的 V=0，将触发该例外。
assign exc_es_store_invalid_EX = ex_trans_tlb & mem_we_EX & tlb_out_s1_found & ~tlb_out_s1_v; // store 操作的虚地址在 TLB 中找到了匹配项但是匹配页表项的 V=0，将触发该例外。
assign exc_es_plv_invalid_EX = ex_trans_tlb & (res_from_mem_EX | mem_we_EX) & tlb_out_s1_found & tlb_out_s1_v & (crmd_plv > tlb_out_s1_plv); // load 操作的虚地址在 TLB 中找到了匹配项，且 V=1，但是特权等级不合规，将触发该例外。
assign exc_es_modify_EX = ex_trans_tlb & mem_we_EX & tlb_out_s1_found & tlb_out_s1_v & ~tlb_out_s1_d & (crmd_plv <= tlb_out_s1_plv); // store 操作的虚地址在 TLB 中找到了匹配，且 V=1，且特权等级合规的项，但是该页表项的 D 位为 0，将触发该例外。

// EX 虚实地址转换 --exp19
assign addr_ex_direct = alu_result;
assign tlb_in_s1_vppn = alu_result[31:13];
assign tlb_in_s1_va_bit12 = alu_result[12];
assign tlb_in_s1_asid = csr_out_tlb_r_asid;
assign addr_ex_dmw0 = {tlb_dmw0_pseg, alu_result[28:0]};
assign addr_ex_dmw1 = {tlb_dmw1_pseg, alu_result[28:0]};
assign addr_ex_tlb = {tlb_out_s1_ppn, alu_result[11:0]};

assign ex_trans_direct = crmd_da & ~crmd_pg;
assign ex_trans_dmw0 = ((crmd_plv == 0 && tlb_dmw0_plv0) || (crmd_plv == 3 && tlb_dmw0_plv3)) && (crmd_datm == tlb_dmw0_mat) && (alu_result[31:29] == tlb_dmw0_vseg);
assign ex_trans_dmw1 = ((crmd_plv == 0 && tlb_dmw1_plv0) || (crmd_plv == 3 && tlb_dmw1_plv3)) && (crmd_datm == tlb_dmw1_mat) && (alu_result[31:29] == tlb_dmw1_vseg);
assign ex_trans_tlb = ~crmd_da & crmd_pg & ~ex_trans_dmw0 & ~ex_trans_dmw1;
assign addr_ex_physical = ex_trans_direct ? addr_ex_direct 
                        : (ex_trans_dmw0 ? addr_ex_dmw0 
                        : (ex_trans_dmw1 ? addr_ex_dmw1 
                        : (ex_trans_tlb ? addr_ex_tlb : 32'b0)));

assign  mem_wdata_ID = rkd_value;

//* Mem instrs
wire mem_byte, mem_half, mem_word, mem_signed;
assign mem_byte = inst_ld_b | inst_st_b | inst_ld_bu;
assign mem_half = inst_ld_h | inst_st_h | inst_ld_hu;
assign mem_word = inst_ld_w | inst_st_w;
assign mem_signed = inst_ld_b | inst_ld_h | inst_ld_w;


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
                   || inst_blt  &&  $signed(rj_value) < $signed(rkd_value)
                   || inst_bge  &&  $signed(rj_value) >= $signed(rkd_value)
                   || inst_bltu &&  $unsigned(rj_value) < $unsigned(rkd_value)
                   || inst_bgeu &&  $unsigned(rj_value) >= $unsigned(rkd_value)
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (pc_ID + br_offs) :
                                                /*inst_jirl*/(rj_value + jirl_offs) ;

assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;
//CSR 通路起点
assign csr_num_ID       = csrr_is_rdcnts ? csrr_rdcnts_num : inst_ID[23:10];
assign code_ID          = inst_ID[14:0];
assign csr_re_ID        = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
assign csr_write_ID     = inst_csrwr || inst_csrxchg;
assign csr_wmask_ID     = inst_csrxchg ? rj_value : {32{inst_csrwr}};  //mask <-- rj

//exp18
assign wop_ID = {inst_tlbfill, inst_tlbwr, inst_tlbrd, inst_tlbsrch};
assign we_ID = |wop_ID;

//--  Waterflow
//IF, ID, EX, MEM, WB
//--  Handshake

//--  Pre-IF stage
wire WAR;
always @(posedge clk) begin
    if(reset)begin
        nextpc_reg <= 32'h0;
        not_accepted <= 1'b0;
    end
    else if(exception_WB & flush_all & ~allow_in_IF)begin
        nextpc_reg <= ex_entry;
        not_accepted <= 1'b1;
    end
    else if(ertn_flush_WB & ~allow_in_IF)begin
        nextpc_reg <= ertn_pc;
        not_accepted <= 1'b1;
    end
    else if(tlb_reflush & ~allow_in_IF) begin
        nextpc_reg <= tlb_reflush_pc;
        not_accepted <= 1'b1;
    end
    else if(br_taken & effectful_ID & ~allow_in_IF)begin
        nextpc_reg <= br_target;
        not_accepted <= 1'b1;
    end
    else if(allow_in_IF)begin
        nextpc_reg <= seq_pc;
        not_accepted <= 1'b0;
    end
end
assign seq_pc       = pc + 3'h4;
assign inst_sram_wr = 1'b0;
assign nextpc = not_accepted &~flush_all ? nextpc_reg : (exception_WB&&flush_all ? ex_entry : (ertn_flush_WB ? ertn_pc : (tlb_reflush ? tlb_reflush_pc : (br_taken & effectful_ID ? br_target : seq_pc))));
// --exp19



assign nextpc_direct = nextpc;
assign tlb_in_s0_vppn = nextpc[31:13];
assign tlb_in_s0_va_bit12 = nextpc[12];
assign tlb_in_s0_asid = csr_out_tlb_r_asid;
assign nextpc_dmw0 = {tlb_dmw0_pseg, nextpc[28:0]};
assign nextpc_dmw1 = {tlb_dmw1_pseg, nextpc[28:0]};
assign nextpc_tlb = {tlb_out_s0_ppn, nextpc[11:0]};
// 选择 nextpc 的来源 翻译为物理地址
assign if_trans_direct = crmd_da & ~crmd_pg;
assign if_trans_dmw0 = ((crmd_plv == 0 && tlb_dmw0_plv0) || (crmd_plv == 3 && tlb_dmw0_plv3)) && (nextpc[31:29] == tlb_dmw0_vseg); // 虚地址的最高 3 位（[31:29]位）与配置窗口寄存器中的[31:29]相等，且当前特权等级在该配置窗口中被允许。 讲义5.2.1节
assign if_trans_dmw1 = ((crmd_plv == 0 && tlb_dmw1_plv0) || (crmd_plv == 3 && tlb_dmw1_plv3)) && (nextpc[31:29] == tlb_dmw1_vseg); // 虚地址的最高 3 位（[31:29]位）与配置窗口寄存器中的[31:29]相等，且当前特权等级在该配置窗口中被允许。 讲义5.2.1节
assign if_trans_tlb = ~crmd_da & crmd_pg & ~if_trans_dmw0 & ~if_trans_dmw1;
assign nextpc_physical = if_trans_direct ? nextpc_direct : (if_trans_dmw0 ? nextpc_dmw0 : (if_trans_dmw1 ? nextpc_dmw1 : (if_trans_tlb ? nextpc_tlb : 32'b0)));

assign inst_sram_req = ~ex_IF & req_inst;
assign inst_sram_we = |inst_sram_wstrb;
assign inst_sram_size = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr = nextpc_physical_reg;
assign inst_sram_wdata = 32'b0;
assign addr_ok_inst = inst_sram_addr_ok;
assign data_ok_inst = inst_sram_data_ok;

reg [32:0] nextpc_physical_reg;
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
        nextpc_physical_reg <= 32'h1bfffffc;
    end
    else if(allow_in_IF) begin
        pc <= nextpc;
        nextpc_physical_reg <= nextpc_physical;
    end
end

// tlb_exception --exp19
assign exc_fs_tlb_refill_IF = if_trans_tlb & ~tlb_out_s0_found;
assign exc_fs_fetch_invalid_IF = if_trans_tlb & tlb_out_s0_found & ~tlb_out_s0_v; // 取指操作的虚地址在 TLB 中找到了匹配项但是匹配页表项的 V=0
assign exc_fs_plv_invalid_IF = if_trans_tlb & tlb_out_s0_found & tlb_out_s0_v & (crmd_plv > tlb_out_s0_plv); // 访存操作的虚地址在 TLB 中找到了匹配且 V=1 的项，但是访问的特权等级不合规，将触发该例外。特权等级不合规体现为，该页表项的 CSR.CRMD.PLV 值大于页表项中的 PLV。

//-- IF stage
always @(posedge clk) begin
    if(reset)
        instreg_IF <= 32'h0;
    else if(data_ok_inst)
        instreg_IF <= inst_sram_rdata;
end
wire IF_ADEF = |nextpc_physical[1:0];//取指错误：pc非对齐

always @(posedge clk) begin
    if (reset || tlb_reflush) begin
        pc_ID <= 32'h0;
        exc_adef_ID <= 1'b0;
        exc_fs_tlb_refill_ID <= 1'b0;
        exc_fs_plv_invalid_ID <= 1'b0;
        exc_fs_fetch_invalid_ID <= 1'b0;
        flush_all_ID <= 1'b0;
    end
    else if(allow_in_IF) begin
        pc_ID <= pc;
        exc_adef_ID <= IF_ADEF;
        exc_fs_tlb_refill_ID <= exc_fs_tlb_refill_IF;
        exc_fs_plv_invalid_ID <= exc_fs_plv_invalid_IF;
        exc_fs_fetch_invalid_ID <= exc_fs_fetch_invalid_IF;
        flush_all_ID <= ex_IF&&~flush_all;//!flush_all时需要清空所有的flush_all信号
    end
end
wire ex_IF = IF_ADEF || exc_fs_tlb_refill_IF || exc_fs_plv_invalid_IF || exc_fs_fetch_invalid_IF;

always @(posedge clk) begin
    if(reset)
        valid_IF <= 1'b0;
    else if(allow_in_IF)
        valid_IF <= 1'b1;
    else if(flush_all)
        valid_IF <= 1'b0;
    else if(br_taken & effectful_ID)
        valid_IF <= 1'b0;
end

assign pc_IF=pc;

//-- ID stage

//*inst save for wait
always @(posedge clk) begin
    if(reset)
        inst_ID <= 32'h0;
    else if(handshake_IF_ID)
        inst_ID <= state_IF[0] ? instreg_IF : inst;
end
//*reg forward
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

assign rf_rd1_is_forward = (|accept_forward1)&rf_rd1_nz;//!0号寄存器不需要前递
assign rf_rd2_is_forward = (|accept_forward2)&rf_rd2_nz;
assign rf_rdata1_forward = result_forward[2]&{32{accept_forward1[2]}}|result_forward[1]&{32{accept_forward1[1]}}|result_forward[0]&{32{accept_forward1[0]}};
assign rf_rdata2_forward = result_forward[2]&{32{accept_forward2[2]}}|result_forward[1]&{32{accept_forward2[1]}}|result_forward[0]&{32{accept_forward2[0]}};

//decide to wait or not
wire [4:0] reg_want_write_EX, reg_want_write_MEM, reg_want_write_WB;

wire rf_rd1_in_war, rf_rd2_in_war;
assign rf_rd1_in_war = (rf_raddr1 == reg_want_write_EX) || (rf_raddr1 == reg_want_write_MEM) || (rf_raddr1 == reg_want_write_WB);
assign rf_rd2_in_war = (rf_raddr2 == reg_want_write_EX) || (rf_raddr2 == reg_want_write_MEM) || (rf_raddr2 == reg_want_write_WB);

//war for csr
wire reg_csr_in_war, used_regs;
assign used_regs = (used_rj&&rf_rd1_nz || used_rkd&&rf_rd2_nz);
assign reg_csr_in_war = used_regs && (csr_re_EX && effectful_EX || csr_re_MEM && effectful_MEM || csr_re_WB && effectful_WB);

//decide ready_go_ID
wire used_rj,used_rkd;

assign used_rj=~(inst_bl||inst_b)&~src1_is_pc;
assign used_rkd=~src2_is_imm|inst_st_w|inst_st_b|inst_st_h;
assign WAR = (rf_rd1_in_war&used_rj&~rf_rd1_is_forward&rf_rd1_nz)
                      | (rf_rd2_in_war&used_rkd&~rf_rd2_is_forward&rf_rd2_nz)
                      | reg_csr_in_war;
//* end WAR

// tlb_refetch --exp19
assign tlb_refetch_tlb_inst_ID = inst_tlbwr | inst_tlbfill | inst_tlbrd | inst_invtlb;
assign tlb_refetch_csr_inst_ID = (inst_csrwr | inst_csrxchg) && (csr_num_ID == `CSR_CRMD || csr_num_ID == `CSR_DMW0 || csr_num_ID == `CSR_DMW1 || csr_num_ID == `CSR_ASID);
assign tlb_refetch_ID = tlb_refetch_tlb_inst_ID && tlb_refetch_csr_inst_ID;


always @(posedge clk) begin
    if (reset || tlb_reflush) begin
        alu_src1_EX <= 32'b0;
        alu_src2_EX <= 32'b0;
        alu_op_EX   <= 12'b0;
        rj_value_EX <= 32'b0;
        rkd_value_EX <= 32'b0;
        dest_EX     <= 5'b0;
        mem_wdata_EX <= 32'b0;
        res_from_mem_EX <= 1'b0;
        rf_we_EX    <= 1'b0;
        mem_we_EX   <= 1'b0;
        pc_EX       <= 32'b0;

        mem_byte_EX <= 1'b0;
        mem_half_EX <= 1'b0;
        mem_word_EX <= 1'b0;
        mem_signed_EX <= 1'b0;

        if_divider_EX <= 1'b0;

        inst_div_w_EX <= 1'b0;
        inst_div_wu_EX <= 1'b0;
        inst_mod_w_EX <= 1'b0;
        inst_mod_wu_EX <= 1'b0;

        csr_num_EX <= 14'b0;
        exc_syscall_EX <= 1'b0;
        code_EX <= 15'b0;
        csr_re_EX <= 1'b0;
        csr_write_EX <= 1'b0;
        csr_wmask_EX <= 32'b0;
        ertn_flush_EX <= 1'b0;

        flush_all_EX <= 1'b0;
        exc_adef_EX <= 1'b0;
        exc_ine_EX <= 1'b0;
        exc_int_EX <= 1'b0;
        exc_break_EX     <= 1'b0;
        //exp19
        exc_fs_tlb_refill_EX <= 1'b0;
        exc_fs_fetch_invalid_EX <= 1'b0;
        exc_fs_plv_invalid_EX <= 1'b0;
        tlb_refetch_EX <= 1'b0;
        //exp18
        we_EX <= 1'b0;
        wop_EX <= 4'b0;
        invtlb_EX <= 1'b0;
    end
    else if(handshake_ID_EX)begin
        alu_src1_EX <= alu_src1;
        alu_src2_EX <= alu_src2;
        alu_op_EX   <= alu_op;
        rj_value_EX <= rj_value;
        rkd_value_EX <= rkd_value;
        dest_EX     <= dest;
        mem_wdata_EX <= mem_wdata_ID;
        mem_we_EX   <= mem_we;
        res_from_mem_EX <= res_from_mem;
        rf_we_EX    <= gr_we & valid;
        pc_EX <= pc_ID;

        mem_byte_EX <= mem_byte;
        mem_half_EX <= mem_half;
        mem_word_EX <= mem_word;
        mem_signed_EX <= mem_signed;

        if_divider_EX <= if_divider;

        inst_div_w_EX <= inst_div_w;
        inst_div_wu_EX <= inst_div_wu;
        inst_mod_w_EX <= inst_mod_w;
        inst_mod_wu_EX <= inst_mod_wu;

        csr_num_EX <= csr_num_ID;
        code_EX <= code_ID;
        csr_re_EX <= csr_re_ID;
        csr_write_EX <= csr_write_ID;
        csr_wmask_EX <= csr_wmask_ID;  //mask <-- rj


        flush_all_EX <= (ex_ID|flush_all_ID)&~flush_all;
        //* excs        
        ertn_flush_EX <= inst_ertn;
        exc_syscall_EX <= inst_syscall;
        exc_ine_EX <= INE_ID;
        exc_adef_EX <= exc_adef_ID;
        exc_int_EX <= has_int;
        exc_break_EX <= inst_break;
            //excs --exp19
        exc_fs_tlb_refill_EX <= exc_fs_tlb_refill_ID;
        exc_fs_fetch_invalid_EX <= exc_fs_fetch_invalid_ID;
        exc_fs_plv_invalid_EX <= exc_fs_plv_invalid_ID;
        tlb_refetch_EX <= tlb_refetch_ID;
        //exp18
        we_EX <= we_ID;
        wop_EX <= wop_ID;
        invtlb_EX <= inst_invtlb;
    end
    else if(ertn_flush_WB)
        ertn_flush_EX <= 1'b0;
end
wire ex_ID=(inst_ertn | inst_syscall | has_int | INE_ID | inst_break);//将异常与valid分离

always @(posedge clk) begin
    if (reset) begin
        valid_ID <= 1'b0;
    end
    else if(flush_all)
        valid_ID <= 1'b0;
    else if(br_taken && effectful_ID && handshake_IF_ID) begin //只有IF取了错指令，而且ID指令有效，且EX准备接受，才把valid=0传下去
        valid_ID <= 1'b0;
    end
    else if(handshake_IF_ID) begin
        valid_ID <= valid_IF;
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

//* Divider
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
reg [31:0] divider_res_reg, divider_remain_reg;
always @(posedge clk) begin
    if(reset)begin
        divider_res_reg <= 32'b0;
        divider_remain_reg <= 32'b0;
    end
    else if(unsigned_dout_tvalid)begin
        divider_res_reg <= unsigned_divider_res[63:32];
        divider_remain_reg <= unsigned_divider_res[31:0];
    end
    else if(signed_dout_tvalid)begin
        divider_res_reg <= signed_divider_res[63:32];
        divider_remain_reg <= signed_divider_res[31:0];
    end
end


wire found_flush_all_EX;
assign found_flush_all_EX = (flush_all_MEM|flush_all_WB);

wire [31:0] div_result;
// assign div_result = (inst_div_wu_EX) ? unsigned_divider_res[63:32] : 
//                     (inst_div_w_EX)  ? signed_divider_res[63:32] : 
//                     (inst_mod_wu_EX) ? unsigned_divider_res[31:0] : signed_divider_res[31:0];
assign div_result = (inst_div_wu_EX | inst_div_w_EX) ? divider_res_reg : divider_remain_reg;

//* end Divider

wire[31:0] result_all;
assign result_all = if_divider_EX ? div_result : alu_result;
wire[1:0] mem_offset;
assign mem_offset = alu_result[1:0];


// EX --> MEM CSR 的信号和数据传递


always @(posedge clk) begin
    if (reset || tlb_reflush) begin
        res_from_mem_MEM <= 1'b0;
        rf_we_MEM <= 1'b0;
        dest_MEM <= 5'b0;
        result_all_MEM <= 32'b0;
        pc_MEM <= 32'b0;
        //exp18 added
        rj_value_MEM <= 32'b0;
        rkd_value_MEM <= 32'b0;

        data_sram_en_MEM <= 1'b0;
        data_sram_we_MEM <= 4'b0;
        data_sram_addr_MEM <= 32'b0;
        data_sram_wdata_MEM <= 32'b0;

        mem_byte_MEM <= 1'b0;
        mem_half_MEM <= 1'b0;
        mem_word_MEM <= 1'b0;
        mem_signed_MEM <= 1'b0;

        mem_offset_MEM <= 2'b00;

        csr_num_MEM <= 14'b0;
        code_MEM <= 15'b0;
        csr_re_MEM <= 1'b0;
        csr_write_MEM <= 1'b0;
        csr_wmask_MEM <= 32'b0;
        ertn_flush_MEM <= 1'b0;
        csr_wvalue_MEM <= 32'b0;

        flush_all_MEM <= 1'b0;
        vaddr_MEM <= 32'b0;

        exc_syscall_MEM <= 1'b0;
        exc_adef_MEM <= 1'b0;
        exc_ine_MEM <= 1'b0;
        exc_int_MEM <= 1'b0;
        exc_ale_MEM <= 1'b0;
        exc_break_MEM <= 1'b0;
        //exp18
        we_MEM <= 1'b0;
        wop_MEM <= 4'b0;
        invtlb_MEM <= 1'b0;
        // exp19
        exc_fs_tlb_refill_MEM <= 1'b0;
        exc_fs_fetch_invalid_MEM <= 1'b0;
        exc_fs_plv_invalid_MEM <= 1'b0;
        exc_es_tlb_refill_MEM <= 1'b0;
        exc_es_load_invalid_MEM <= 1'b0;
        exc_es_store_invalid_MEM <= 1'b0;
        exc_es_plv_invalid_MEM <= 1'b0;
        exc_es_modify_MEM <= 1'b0;
        tlb_refetch_MEM <= 1'b0;
    end
    else if(handshake_EX_MEM)begin
        res_from_mem_MEM <= res_from_mem_EX;
        rf_we_MEM <= rf_we_EX;
        result_all_MEM <= result_all;    
        dest_MEM <= dest_EX;
        pc_MEM <= pc_EX;
        //exp18 added
        rj_value_MEM <= rj_value_EX;
        rkd_value_MEM <= rkd_value_EX;

        data_sram_en_MEM <= data_sram_en_EX;
        data_sram_we_MEM <= data_sram_we_EX;
        data_sram_addr_MEM <= data_sram_addr_EX;
        data_sram_wdata_MEM <= data_sram_wdata_EX;

        mem_byte_MEM <= mem_byte_EX;
        mem_half_MEM <= mem_half_EX;
        mem_word_MEM <= mem_word_EX;
        mem_signed_MEM <= mem_signed_EX;

        mem_offset_MEM <= mem_offset;

        csr_num_MEM <= csr_num_EX;
        code_MEM <= code_EX;
        csr_re_MEM <= csr_re_EX;
        csr_write_MEM <= csr_write_EX;
        csr_wmask_MEM <= csr_wmask_EX;
        ertn_flush_MEM <= ertn_flush_EX;
        csr_wvalue_MEM <= rkd_value_EX;

        flush_all_MEM <= (flush_all_EX|ex_EX)&~flush_all;
        vaddr_MEM <= alu_result;

        exc_syscall_MEM <= exc_syscall_EX;
        exc_adef_MEM <= exc_adef_EX;
        exc_ine_MEM <= exc_ine_EX;
        exc_int_MEM <= exc_int_EX;
        exc_ale_MEM <= ALE_EX;
        exc_break_MEM <= exc_break_EX;
        //exp18
        we_MEM <= we_EX;
        wop_MEM <= wop_EX;
        invtlb_MEM <= invtlb_EX;
        // exp19
        exc_fs_tlb_refill_MEM <= exc_fs_tlb_refill_EX;
        exc_fs_fetch_invalid_MEM <= exc_fs_fetch_invalid_EX;
        exc_fs_plv_invalid_MEM <= exc_fs_plv_invalid_EX;
        exc_es_tlb_refill_MEM <= exc_es_tlb_refill_EX;
        exc_es_load_invalid_MEM <= exc_es_load_invalid_EX;
        exc_es_store_invalid_MEM <= exc_es_store_invalid_EX;
        exc_es_plv_invalid_MEM <= exc_es_plv_invalid_EX;
        exc_es_modify_MEM <= exc_es_modify_EX;
        tlb_refetch_MEM <= tlb_refetch_EX;
    end
    else if(ertn_flush_WB)
        ertn_flush_MEM <= 1'b0;
end
wire ex_EX;
assign ex_EX = ALE_EX | exc_es_load_invalid_EX | exc_es_store_invalid_EX | exc_es_modify_EX | exc_es_plv_invalid_EX | exc_es_tlb_refill_EX;

assign result_forward[0] = alu_result;
//!计算的结果是内存地址，不要前递
assign dest_forward[0] = dest_EX & {5{~res_from_mem_EX & rf_we_EX & effectful_EX & ready_go_EX}};//If the result will WB, then forward.

assign reg_want_write_EX = dest_EX & {5{rf_we_EX & effectful_EX}};

always @(posedge clk) begin
    if (reset) begin
        valid_EX <= 1'b0;
    end
    else if (flush_all) //!如果ID级判出INE，则不应该执行该指令
        valid_EX <= 1'b0;
    else if(handshake_ID_EX)
        valid_EX <= valid_ID;
    else if(handshake_EX_MEM) begin
        valid_EX <= 1'b0;
    end
end

//-- MEM stage

wire ALE_EX;
wire mem_en = (mem_we_EX || res_from_mem_EX) &&~reset && effectful_EX //实际上要有EX的寄存器发请求，MEM才能接受 
            && ~found_flush_all_EX;//正在刷新流水线时不发请求
assign data_sram_en_EX    = mem_en &~ex_EX;
                        
assign data_sram_we_EX    = mem_we_EX? {mem_word_EX|(mem_half_EX&mem_offset[1])|(mem_byte_EX&mem_offset[1]&mem_offset[0])
                                    ,mem_word_EX|(mem_half_EX&mem_offset[1])|(mem_byte_EX&mem_offset[1]&~mem_offset[0])
                                    ,mem_word_EX|(mem_half_EX&~mem_offset[1])|(mem_byte_EX&~mem_offset[1]&mem_offset[0])
                                    ,mem_word_EX|(mem_half_EX&~mem_offset[1])|(mem_byte_EX&~mem_offset[1]&~mem_offset[0])}//! half/byte的写入掩码与offset有关
                                    : 4'b0;
assign data_sram_addr_EX  = addr_ex_physical;
always @(posedge clk) begin
    if(reset)
        data_sram_rdata_reg <= 32'b0;
    else if(data_ok_mem)
        data_sram_rdata_reg <= data_sram_rdata;
end

assign mem_rdata_w = data_sram_rdata_reg;
assign mem_rdata_h = mem_offset_d[2] ? data_sram_rdata_reg[31:16] :data_sram_rdata_reg[15:0];
assign mem_rdata_b = {{8{mem_offset_d[0]}} & data_sram_rdata_reg[7:0]} | {{8{mem_offset_d[1]}} & data_sram_rdata_reg[15:8]} |
                    {{8{mem_offset_d[2]}} & data_sram_rdata_reg[23:16]} | {{8{mem_offset_d[3]}} & data_sram_rdata_reg[31:24]};

assign mem_result   = mem_byte_MEM ? {{24{mem_signed_MEM & mem_rdata_b[7]}}, mem_rdata_b[7:0]} :
                      mem_half_MEM ? {{16{mem_signed_MEM & mem_rdata_h[15]}}, mem_rdata_h[15:0]} :
                    mem_rdata_w;

assign ALE_EX = mem_en && (mem_word_EX&& |alu_result[1:0] || mem_half_EX&&alu_result[0]);//访存错误：地址非对齐

decoder_2_4 u_dec4(
    .in(mem_offset_MEM),
    .out(mem_offset_d)
);


// assign mem_wdata = mem_wdata_EX;
assign data_sram_wdata_EX = ({32{mem_word_EX}}&mem_wdata_EX)
                        |({32{mem_half_EX}}&{2{mem_wdata_EX[15:0]}})
                        |({32{mem_byte_EX}}&{4{mem_wdata_EX[7:0]}});//! 在内存将要写入的位置连接上正确的数据
wire[31:0] final_result_MEM;
assign final_result_MEM = res_from_mem_MEM ? mem_result : result_all_MEM;

// MEM --> WB CSR 的信号和数据传递

always @(posedge clk) begin
    if (reset || tlb_reflush) begin
        final_result_WB <= 32'b0;
        pc_WB <= 32'b0;
        dest_WB <= 5'b0;
        rf_we_WB <= 1'b0;
        //exp18 added
        rj_value_WB <= 32'b0;
        rkd_value_WB <= 32'b0;

        csr_num_WB <= 14'b0;
        exc_syscall_WB <= 1'b0;
        code_WB <= 15'b0;
        csr_re_WB <= 1'b0;
        csr_write_WB <= 1'b0;
        csr_wmask_WB <= 32'b0;
        ertn_flush_WB <= 1'b0;
        csr_wvalue_WB <= 32'b0;

        flush_all_WB <= 1'b0;
        vaddr_WB <= 32'b0;

        exc_int_WB <= 1'b0;
        exc_adef_WB <= 1'b0;
        exc_ine_WB <= 1'b0;
        exc_ale_WB <= 1'b0;
        exc_break_WB <= 1'b0;
        //exp18
        we_WB <= 1'b0;
        wop_WB <= 4'b0;
        invtlb_WB <= 1'b0;
        // exp19
        exc_fs_tlb_refill_WB <= 1'b0;
        exc_fs_fetch_invalid_WB <= 1'b0;
        exc_fs_plv_invalid_WB <= 1'b0;
        exc_es_tlb_refill_WB <= 1'b0;
        exc_es_load_invalid_WB <= 1'b0;
        exc_es_store_invalid_WB <= 1'b0;
        exc_es_plv_invalid_WB <= 1'b0;
        exc_es_modify_WB <= 1'b0;
        tlb_refetch_WB <= 1'b0;
    end
    else if(handshake_MEM_WB) begin
        final_result_WB <= final_result_MEM;
        pc_WB <= pc_MEM;
        dest_WB <= dest_MEM;
        rf_we_WB <= rf_we_MEM;
        //exp18 added
        rj_value_WB <= rj_value_MEM;
        rkd_value_WB <= rkd_value_MEM;

        csr_num_WB <= csr_num_MEM;
        exc_syscall_WB <= exc_syscall_MEM;
        code_WB <= code_MEM;
        csr_re_WB <= csr_re_MEM;
        csr_write_WB <= csr_write_MEM;
        csr_wmask_WB <= csr_wmask_MEM;
        ertn_flush_WB <= ertn_flush_MEM;
        csr_wvalue_WB <= csr_wvalue_MEM;

        flush_all_WB <= flush_all_MEM&~flush_all;
        vaddr_WB <= vaddr_MEM;

        exc_int_WB <= exc_int_MEM;
        exc_adef_WB <= exc_adef_MEM;
        exc_ine_WB <= exc_ine_MEM;
        exc_ale_WB <= exc_ale_MEM;
        exc_break_WB <= exc_break_MEM;
        //exp18
        we_WB <= we_MEM;
        wop_WB <= wop_MEM;
        invtlb_WB <= invtlb_MEM;
        // exp19
        exc_fs_tlb_refill_WB <= exc_fs_tlb_refill_MEM;
        exc_fs_fetch_invalid_WB <= exc_fs_fetch_invalid_MEM;
        exc_fs_plv_invalid_WB <= exc_fs_plv_invalid_MEM;
        exc_es_tlb_refill_WB <= exc_es_tlb_refill_MEM;
        exc_es_load_invalid_WB <= exc_es_load_invalid_MEM;
        exc_es_store_invalid_WB <= exc_es_store_invalid_MEM;
        exc_es_plv_invalid_WB <= exc_es_plv_invalid_MEM;
        exc_es_modify_WB <= exc_es_modify_MEM;
        tlb_refetch_WB <= tlb_refetch_MEM;
    end
    else if(ertn_flush_WB)
        ertn_flush_WB <= 1'b0;
end

assign result_forward[1] = final_result_MEM;
assign dest_forward[1] = dest_MEM & {5{rf_we_MEM & effectful_MEM & ready_go_MEM}};

always @(posedge clk) begin
    if (reset) begin
        valid_MEM <= 1'b0;
    end
    else if(flush_all)
        valid_MEM <= 1'b0;
    else if(handshake_EX_MEM)
        valid_MEM <= valid_EX;
    else if(handshake_MEM_WB)
        valid_MEM <= 1'b0;
end

assign reg_want_write_MEM = dest_MEM & {5{rf_we_MEM & effectful_MEM}};

//-- WB stage
assign rf_we    = rf_we_WB && effectful_WB;
assign rf_waddr = dest_WB;
assign rf_wdata = csr_re_WB? csr_rvalue : final_result_WB;
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
//--  debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

always @(posedge clk) begin
    if (reset) begin
        valid_WB <= 1'b0;
    end
    else if (flush_all)
        valid_WB <= 1'b0;
    else if (handshake_MEM_WB) 
        valid_WB <= valid_MEM;
    else if(ready_go_WB)
        valid_WB <= 1'b0;
end

assign result_forward[2] = final_result_WB;
assign dest_forward[2] = dest_WB & {5{rf_we_WB & effectful_WB & ready_go_WB}};

assign ready_go_WB = 1'b1;

assign reg_want_write_WB = dest_WB & {5{rf_we_WB & effectful_WB}};

//* CSR --added by exp19
assign exception_WB = exc_syscall_WB|exc_int_WB|exc_adef_WB|exc_ine_WB|exc_ale_WB|exc_break_WB|exc_fs_fetch_invalid_WB|exc_fs_tlb_refill_WB|exc_fs_plv_invalid_WB|exc_es_load_invalid_WB|exc_es_store_invalid_WB|exc_es_tlb_refill_WB|exc_es_plv_invalid_WB|exc_es_modify_WB;//异常信号
assign flush_all = flush_all_WB & valid_WB; //flush_all传到WB级时，则刷新流水线

assign csr_re = csr_re_WB;
assign csr_num = csr_num_WB;
assign csr_we = csr_write_WB && effectful_WB;
assign csr_wmask = csr_wmask_WB;
assign csr_wvalue = csr_wvalue_WB;

assign ertn_flush = ertn_flush_WB & valid_WB;
assign wb_ex = exception_WB & flush_all;// 来自WB级的异常触发信号
// added by exp19
assign wb_ecode = exc_int_WB ? `ECODE_INT : //异常类型
                      exc_adef_WB? `ECODE_ADE :
                      exc_ale_WB ? `ECODE_ALE :
                      exc_syscall_WB? `ECODE_SYS:
                      exc_break_WB? `ECODE_BRK :
                      exc_ine_WB ? `ECODE_INE : 
                      exc_fs_fetch_invalid_WB ? `ECODE_PIF :
                      (exc_fs_tlb_refill_WB | exc_es_tlb_refill_WB) ? `ECODE_TLBR :
                      (exc_fs_plv_invalid_WB | exc_es_plv_invalid_WB) ? `ECODE_PPI :
                      exc_es_load_invalid_WB ? `ECODE_PIL :
                      exc_es_store_invalid_WB ? `ECODE_PIS :
                      exc_es_modify_WB ? `ECODE_PME : 6'h0;
assign wb_esubcode = exc_adef_WB ? `ESUBCODE_ADEF : 9'h0;
assign wb_pc = pc_WB;// 来自WB级的异常发生地址
assign wb_vaddr = vaddr_WB;// 来自WB级的异常发生地址 
assign to_csr_exc_fs_tlb_refill = exc_fs_tlb_refill_WB;
assign to_csr_exc_fs_plv_invalid = exc_fs_plv_invalid_WB;

//tlb_reflush
assign tlb_reflush = tlb_refetch_WB;
assign tlb_reflush_pc = pc_WB;

//exp18
wire wop_srch = wop_WB[0];
wire wop_rd   = wop_WB[1];
wire wop_wr   = wop_WB[2];
wire wop_fill = wop_WB[3];
assign csr_in_tlb_w_we = we_WB&effectful_WB;
assign csr_in_tlb_w_op = wop_WB;
assign csr_in_tlb_w_e  = wop_srch & tlb_out_srch_found | wop_rd & tlb_out_r_e;
assign csr_in_tlb_w_idx= tlb_out_srch_idx;
assign csr_in_tlb_w_vppn    = tlb_out_r_e ? tlb_out_r_vppn : 19'b0;
assign csr_in_tlb_w_ps      = tlb_out_r_e ? tlb_out_r_ps   : 6'b0;
assign csr_in_tlb_w_asid    = tlb_out_r_e ? tlb_out_r_asid : 10'b0;
assign csr_in_tlb_w_g       = tlb_out_r_e ? tlb_out_r_g    : 1'b0;
assign csr_in_tlb_w_ppn0    = tlb_out_r_e ? tlb_out_r_ppn0 : 20'b0;
assign csr_in_tlb_w_plv0    = tlb_out_r_e ? tlb_out_r_plv0 : 2'b0;
assign csr_in_tlb_w_mat0    = tlb_out_r_e ? tlb_out_r_mat0 : 2'b0;
assign csr_in_tlb_w_d0      = tlb_out_r_e ? tlb_out_r_d0   : 1'b0;
assign csr_in_tlb_w_v0      = tlb_out_r_e ? tlb_out_r_v0   : 1'b0;
assign csr_in_tlb_w_ppn1    = tlb_out_r_e ? tlb_out_r_ppn1 : 20'b0;
assign csr_in_tlb_w_plv1    = tlb_out_r_e ? tlb_out_r_plv1 : 2'b0;
assign csr_in_tlb_w_mat1    = tlb_out_r_e ? tlb_out_r_mat1 : 2'b0;
assign csr_in_tlb_w_d1      = tlb_out_r_e ? tlb_out_r_d1   : 1'b0;
assign csr_in_tlb_w_v1      = tlb_out_r_e ? tlb_out_r_v1   : 1'b0;
csr u_csr(
    .clk                (clk),
    .rst              (reset),
    
    .csr_re             (csr_re),
    .csr_num            (csr_num),
    .csr_rvalue         (csr_rvalue),

    .csr_we             (csr_we),
    .csr_wmask          (csr_wmask),
    .csr_wvalue         (csr_wvalue),

    .ex_entry           (ex_entry),      
    .has_int            (has_int),       
    .ertn_pc            (ertn_pc),       
    .ertn_flush         (ertn_flush), 
    .wb_ex              (wb_ex), 
    .wb_ecode           (wb_ecode),
    .wb_esubcode        (wb_esubcode),
    .wb_pc              (wb_pc),         
    .wb_vaddr           (wb_vaddr),
    //exp18 
    //write   
    .tlb_w_we           (csr_in_tlb_w_we),
    .tlb_w_wop          (csr_in_tlb_w_op),
    .tlb_w_e            (csr_in_tlb_w_e),
    .tlb_w_idx          (csr_in_tlb_w_idx),
    .tlb_w_vppn         (csr_in_tlb_w_vppn),
    .tlb_w_ps           (csr_in_tlb_w_ps),
    .tlb_w_asid         (csr_in_tlb_w_asid),
    .tlb_w_g            (csr_in_tlb_w_g),
    .tlb_w_ppn0         (csr_in_tlb_w_ppn0),
    .tlb_w_plv0         (csr_in_tlb_w_plv0),
    .tlb_w_mat0         (csr_in_tlb_w_mat0),
    .tlb_w_d0           (csr_in_tlb_w_d0),
    .tlb_w_v0           (csr_in_tlb_w_v0),
    .tlb_w_ppn1         (csr_in_tlb_w_ppn1),
    .tlb_w_plv1         (csr_in_tlb_w_plv1),
    .tlb_w_mat1         (csr_in_tlb_w_mat1),
    .tlb_w_d1           (csr_in_tlb_w_d1),
    .tlb_w_v1           (csr_in_tlb_w_v1),
    //read
    .tlb_r_e            (csr_out_tlb_r_e),
    .tlb_r_idx          (csr_out_tlb_r_idx),
    .tlb_r_vppn         (csr_out_tlb_r_vppn),
    .tlb_r_ps           (csr_out_tlb_r_ps),
    .tlb_r_asid         (csr_out_tlb_r_asid),
    .tlb_r_g            (csr_out_tlb_r_g),
    .tlb_r_ppn0         (csr_out_tlb_r_ppn0),
    .tlb_r_plv0         (csr_out_tlb_r_plv0),
    .tlb_r_mat0         (csr_out_tlb_r_mat0),
    .tlb_r_d0           (csr_out_tlb_r_d0),
    .tlb_r_v0           (csr_out_tlb_r_v0),
    .tlb_r_ppn1         (csr_out_tlb_r_ppn1),
    .tlb_r_plv1         (csr_out_tlb_r_plv1),
    .tlb_r_mat1         (csr_out_tlb_r_mat1),
    .tlb_r_d1           (csr_out_tlb_r_d1),
    .tlb_r_v1           (csr_out_tlb_r_v1),
    
    .tlb_refill         (exc_es_tlb_refill_WB),

    .crmd_plv           (crmd_plv),
    .crmd_da            (crmd_da),
    .crmd_pg            (crmd_pg),
    .crmd_datf          (crmd_datf),
    .crmd_datm          (crmd_datm),

    .tlb_dmw0_plv0       (tlb_dmw0_plv0),
    .tlb_dmw0_plv3       (tlb_dmw0_plv3),
    .tlb_dmw0_mat        (tlb_dmw0_mat),
    .tlb_dmw0_pseg       (tlb_dmw0_pseg),
    .tlb_dmw0_vseg       (tlb_dmw0_vseg),

    .tlb_dmw1_plv0       (tlb_dmw1_plv0),
    .tlb_dmw1_plv3       (tlb_dmw1_plv3),
    .tlb_dmw1_mat        (tlb_dmw1_mat),
    .tlb_dmw1_pseg       (tlb_dmw1_pseg),
    .tlb_dmw1_vseg       (tlb_dmw1_vseg),

    .estat_ecode         (estat_ecode),

    .exc_fs_plv_invalid  (to_csr_exc_fs_plv_invalid),
    .exc_fs_tlb_refill   (to_csr_exc_fs_tlb_refill)
);

assign csrr_is_rdcnts = inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
assign csrr_rdcnts_num = {14{inst_rdcntid}} & `CSR_TID | 
                         {14{inst_rdcntvl_w}} & `CSR_STABLE_COUNTER_LO  | 
                         {14{inst_rdcntvh_w}} & `CSR_STABLE_COUNTER_HI;

//IF
always @(posedge clk) begin
    if(reset)
        state_IF <= 3'b001;
    else if((state_IF[2] | state_IF[0]) & handshake_IF_ID)
        state_IF <= 3'b010;
    else if(state_IF[2] & data_ok_inst | state_IF[1] & ex_IF)
        state_IF <= 3'b001;
    else if(state_IF[1] & addr_ok_inst)
        state_IF <= 3'b100;
end
assign req_inst = state_IF[1];
assign ready_go_IF = state_IF[0] | state_IF[2] & data_ok_inst;
assign allow_in_IF = handshake_IF_ID;

//ID
always @(posedge clk) begin
    if(reset)
        state_ID <= 1'b0;
    else if(~state_ID & handshake_IF_ID | state_ID & handshake_IF_ID & handshake_ID_EX)
        state_ID <= 1'b1;
    else if(state_ID & handshake_ID_EX)
        state_ID <= 1'b0;
end
assign allow_in_ID = handshake_ID_EX |~state_ID;
assign ready_go_ID = state_ID & ~( (rf_rd1_in_war&used_rj&~rf_rd1_is_forward&rf_rd1_nz)
                      | (rf_rd2_in_war&used_rkd&~rf_rd2_is_forward&rf_rd2_nz)//If forward, then go.
                      | reg_csr_in_war);
//EX
wire unsigned_handshake = unsigned_dividend_tvalid & unsigned_divisor_tvalid & unsigned_dividend_tready & unsigned_divisor_tready;
wire signed_handshake = signed_dividend_tvalid & signed_divisor_tvalid & signed_dividend_tready & signed_divisor_tready;
always @(posedge clk) begin
    if(reset)
        state_EX <= 4'b0001;
    else if((state_EX[0] & handshake_ID_EX & effectful_ID | state_EX[3] & handshake_ID_EX & handshake_EX_MEM & effectful_ID) & if_divider)
        state_EX <= 4'b0010;
    else if(state_EX[1] & (unsigned_handshake | signed_handshake))
        state_EX <= 4'b0100;
    else if(state_EX[2] & (unsigned_dout_tvalid | signed_dout_tvalid) | 
    state_EX[0] & handshake_ID_EX & (~if_divider | ~effectful_ID)|
    state_EX[3] & handshake_ID_EX & handshake_EX_MEM & (~if_divider |~effectful_ID)
    )
        state_EX <= 4'b1000;
    else if(state_EX[3] & handshake_EX_MEM &~handshake_ID_EX)
        state_EX <= 4'b0001; 
end
assign allow_in_EX = state_EX[0] | state_EX[3] & handshake_EX_MEM;
assign ready_go_EX = state_EX[3];
assign signed_dividend_tvalid = state_EX[1] & (inst_div_w_EX | inst_mod_w_EX);
assign signed_divisor_tvalid = state_EX[1] & (inst_div_w_EX | inst_mod_w_EX);
assign unsigned_dividend_tvalid = state_EX[1] & (inst_div_wu_EX | inst_mod_wu_EX);
assign unsigned_divisor_tvalid = state_EX[1] & (inst_div_wu_EX | inst_mod_wu_EX);
//MEM
always @(posedge clk) begin
    if(reset)
        state_MEM <= 4'b0001;
    else if(state_MEM[0] & handshake_EX_MEM & (data_sram_en_EX & effectful_EX) |
            state_MEM[3] & handshake_EX_MEM & handshake_MEM_WB & (data_sram_en_EX & effectful_EX))
        state_MEM <= 4'b0010;
    else if(state_MEM[1] & addr_ok_mem)
        state_MEM <= 4'b0100;
    else if(state_MEM[2] & data_ok_mem | 
            state_MEM[0] & handshake_EX_MEM &(~data_sram_en_EX | ~effectful_EX) |
            state_MEM[3] & handshake_EX_MEM & handshake_MEM_WB &(~data_sram_en_EX | ~effectful_EX))
        state_MEM <= 4'b1000;
    else if(state_MEM[3] & handshake_MEM_WB & ~handshake_EX_MEM)
        state_MEM <= 4'b0001;
end
assign allow_in_MEM = state_MEM[0] | state_MEM[3] & handshake_MEM_WB;
assign ready_go_MEM = state_MEM[3];

assign req_mem = state_MEM[1];
assign data_sram_req = data_sram_en_MEM & req_mem;
assign data_sram_wr = |data_sram_wstrb;
assign data_sram_size = mem_byte_MEM ? 2'b0 : 
                        mem_half_MEM ? 2'b1 :
                        2'b10;
assign data_sram_wstrb = data_sram_we_MEM & {4{state_MEM[1]}};
assign data_sram_addr = data_sram_addr_MEM;
assign data_sram_wdata = data_sram_wdata_MEM;
assign addr_ok_mem = data_sram_addr_ok;
assign data_ok_mem = data_sram_data_ok;
//WB
assign allow_in_WB = 1'b1;
assign ready_go_WB = 1'b1;

assign effectful_IF = valid_IF & ~ex_IF & ~flush_all;
assign effectful_ID = valid_ID & ~ex_ID & ~flush_all & ~flush_all_ID &~WAR;//写后读阻塞中显然是无效的。
assign effectful_EX = valid_EX & ~flush_all & ~flush_all_EX;
assign effectful_MEM = valid_MEM & ~flush_all & ~flush_all_MEM;
assign effectful_WB = valid_WB & ~flush_all & ~flush_all_WB;
//exp18
assign tlb_in_invtlb_valid = invtlb_WB & effectful_WB;
assign tlb_in_invtlb_op = dest_WB;
assign tlb_in_invtlb_asid = tlb_in_invtlb_op[2] ? rj_value_WB[9:0] : 9'b0;
assign tlb_in_invtlb_va   = tlb_in_invtlb_op[2]&(|tlb_in_invtlb_op[1:0]) ? rkd_value_WB[31:13] : 19'b0;

assign tlb_in_we = (|wop_WB[3:2]) & effectful_WB;
assign tlb_in_w_idx = wop_WB[2] ? csr_out_tlb_r_idx : tlbidx_alloc;
tlb_idx_alloc u_tlb_idx_alloc(
    .rst(reset),
    .clk(clk),
    .tlballoc(wop_WB[3] & effectful_WB),
    .idx(tlbidx_alloc)
);
assign tlb_in_w_e       = csr_out_tlb_r_e;
assign tlb_in_w_vppn    = csr_out_tlb_r_vppn;
assign tlb_in_w_ps      = csr_out_tlb_r_ps;
assign tlb_in_w_asid    = csr_out_tlb_r_asid;
assign tlb_in_w_g       = csr_out_tlb_r_g;
assign tlb_in_w_ppn0    = csr_out_tlb_r_ppn0;
assign tlb_in_w_plv0    = csr_out_tlb_r_plv0;
assign tlb_in_w_mat0    = csr_out_tlb_r_mat0;
assign tlb_in_w_d0      = csr_out_tlb_r_d0;
assign tlb_in_w_v0      = csr_out_tlb_r_v0;
assign tlb_in_w_ppn1    = csr_out_tlb_r_ppn1;
assign tlb_in_w_plv1    = csr_out_tlb_r_plv1;
assign tlb_in_w_mat1    = csr_out_tlb_r_mat1;
assign tlb_in_w_d1      = csr_out_tlb_r_d1;
assign tlb_in_w_v1      = csr_out_tlb_r_v1;

assign tlb_in_r_idx     = csr_out_tlb_r_idx;

assign tlb_in_srch_vppn = csr_out_tlb_r_vppn;
assign tlb_in_srch_asid = csr_out_tlb_r_asid;

tlb u_tlb(
    .clk            (clk),
    .rst            (reset),
    //searchport0(for fetch)
    .s0_vppn        (tlb_in_s0_vppn),
    .s0_va_bit12    (tlb_in_s0_va_bit12),
    .s0_asid        (tlb_in_s0_asid),
    .s0_found       (tlb_out_s0_found),
    .s0_index       (tlb_out_s0_idx),
    .s0_ppn         (tlb_out_s0_ppn),
    .s0_ps          (tlb_out_s0_ps),
    .s0_plv         (tlb_out_s0_plv),
    .s0_mat         (tlb_out_s0_mat),
    .s0_d           (tlb_out_s0_d),
    .s0_v           (tlb_out_s0_v),
    //searchport1(for load/store)
    .s1_vppn        (tlb_in_s1_vppn),
    .s1_va_bit12    (tlb_in_s1_va_bit12),
    .s1_asid        (tlb_in_s1_asid),
    .s1_found       (tlb_out_s1_found),
    .s1_index       (tlb_out_s1_idx),
    .s1_ppn         (tlb_out_s1_ppn),
    .s1_ps          (tlb_out_s1_ps),
    .s1_plv         (tlb_out_s1_plv),
    .s1_mat         (tlb_out_s1_mat),
    .s1_d           (tlb_out_s1_d),
    .s1_v           (tlb_out_s1_v),
    //invtlbopcode
    .invtlb_valid   (tlb_in_invtlb_valid),
    .invtlb_op      (tlb_in_invtlb_op),
    .invtlb_asid    (tlb_in_invtlb_asid),
    .invtlb_va      (tlb_in_invtlb_va),
    //write ports
    .we             (tlb_in_we),
    .w_index        (tlb_in_w_idx),
    .w_e            (tlb_in_w_e),
    .w_vppn         (tlb_in_w_vppn),
    .w_ps           (tlb_in_w_ps),
    .w_asid         (tlb_in_w_asid),
    .w_g            (tlb_in_w_g),
    .w_ppn0         (tlb_in_w_ppn0),
    .w_plv0         (tlb_in_w_plv0),
    .w_mat0         (tlb_in_w_mat0),
    .w_d0           (tlb_in_w_d0),
    .w_v0           (tlb_in_w_v0),
    .w_ppn1         (tlb_in_w_ppn1),
    .w_plv1         (tlb_in_w_plv1),
    .w_mat1         (tlb_in_w_mat1),
    .w_d1           (tlb_in_w_d1),
    .w_v1           (tlb_in_w_v1),
    //read ports
    .r_index        (tlb_in_r_idx),
    .r_e            (tlb_out_r_e),
    .r_vppn         (tlb_out_r_vppn),
    .r_ps           (tlb_out_r_ps),
    .r_asid         (tlb_out_r_asid),
    .r_g            (tlb_out_r_g),
    .r_ppn0         (tlb_out_r_ppn0),
    .r_plv0         (tlb_out_r_plv0),
    .r_mat0         (tlb_out_r_mat0),
    .r_d0           (tlb_out_r_d0),
    .r_v0           (tlb_out_r_v0),
    .r_ppn1         (tlb_out_r_ppn1),
    .r_plv1         (tlb_out_r_plv1),
    .r_mat1         (tlb_out_r_mat1),
    .r_d1           (tlb_out_r_d1),
    .r_v1           (tlb_out_r_v1),
    //tlbsrch
    .tlbsrch_vppn   (tlb_in_srch_vppn),
    .tlbsrch_asid   (tlb_in_srch_asid),
    .tlbsrch_found  (tlb_out_srch_found),
    .tlbsrch_index  (tlb_out_srch_idx)

    
);

endmodule