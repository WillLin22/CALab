`include "csr_defines.vh"

module csr
#(
    parameter TLBNUM = 16
)
(
    input wire clk,
    input wire rst,

    // 指令访问接口
    input wire  csr_re,              // 读使能
    input wire  [13:0] csr_num,      // 寄存器号
    output wire [31:0] csr_rvalue,  // 寄存器读返回值

    input wire  csr_we,              // 写使能
    input wire  [31:0] csr_wmask,    // 写掩码
    input wire  [31:0] csr_wvalue,   // 写数据

    // 与处理器核内部硬件电路逻辑直接较需的控制、状态信号接口
    output wire  [31:0] ex_entry,    // 送往pre-IF级的异常处理入口地址
    output wire  has_int,            // 送往ID级的中断有效信号
    output wire  [31:0] ertn_pc,     // 送往pre-IF级的异常返回地址
    input wire   ertn_flush,   // 来自WB级的ertn执行的有效信号
    input wire   wb_ex,        // 来自WB级的异常触发信号
    input wire   [5:0] wb_ecode,  // 来自WB级的异常类型1级码
    input wire   [8:0] wb_esubcode, // 来自WB级的异常类型2级码
    input wire   [31:0] wb_pc, // 来自WB级的异常发生地址

    input wire   [31:0] wb_vaddr, // 来自WB级的访存地址

    //TLB相关接口
    //write
    input  wire                         tlb_w_we,
    input  wire  [ 3:0]                 tlb_w_wop,//TLB写指令，0-3分别对应srch，rd，wr，fill
    input  wire                         tlb_w_e,
    input  wire  [$clog2(TLBNUM)-1:0]   tlb_w_idx,//TLB索引
    input  wire  [18:0]                 tlb_w_vppn,//TLB虚页号
    input  wire  [ 5:0]                 tlb_w_ps,//TLB页大小
    input  wire  [ 9:0]                 tlb_w_asid,//TLB地址空间标识符
    input  wire                         tlb_w_g,//TLB全局位
    input  wire [19:0]                  tlb_w_ppn0,
    input  wire [ 1:0]                  tlb_w_plv0,
    input  wire [ 1:0]                  tlb_w_mat0, 
    input  wire                         tlb_w_d0,
    input  wire                         tlb_w_v0,
    input  wire [19:0]                  tlb_w_ppn1,
    input  wire [ 1:0]                  tlb_w_plv1,
    input  wire [ 1:0]                  tlb_w_mat1,
    input  wire                         tlb_w_d1,
    input  wire                         tlb_w_v1,
    //read
    output wire                         tlb_r_e,
    output wire  [$clog2(TLBNUM)-1:0]   tlb_r_idx,//TLB索引
    output wire  [18:0]                 tlb_r_vppn,//TLB虚页号
    output wire  [ 5:0]                 tlb_r_ps,//TLB页大小
    output wire  [ 9:0]                 tlb_r_asid,//TLB地址空间标识符
    output wire                         tlb_r_g,//TLB全局位
    output wire [19:0]                  tlb_r_ppn0,
    output wire [ 1:0]                  tlb_r_plv0,
    output wire [ 1:0]                  tlb_r_mat0, 
    output wire                         tlb_r_d0,
    output wire                         tlb_r_v0,
    output wire [19:0]                  tlb_r_ppn1,
    output wire [ 1:0]                  tlb_r_plv1,
    output wire [ 1:0]                  tlb_r_mat1,
    output wire                         tlb_r_d1,
    output wire                         tlb_r_v1,
    // --exp19
    input  wire                         tlb_refill;  // tlb重填异常信号
    output wire [ 1:0]                  crmd_plv,     
    output wire                         crmd_da,      // 直接地址翻译模式的使能，高有效
    output wire                         crmd_pg,      // 映射地址翻译模式的使能，高有效
    output wire [ 1:0]                  crmd_datf,   // 直接地址翻译模式时，取指操作的存储访问类型
    output wire [ 1:0]                  crmd_datm,   // 直接地址翻译模式时，load 和 store 操作的存储访问类型

    //DMW 直接映射配置窗口 --exp19
    output wire                         tlb_dmw0_plv0,
    output wire                         tlb_dmw0_plv3,
    output wire [ 1:0]                  tlb_dmw0_mat,  // 虚地址落在该映射窗口下访存操作的存储访问类型
    output wire [ 2:0]                  tlb_dmw0_pseg, // 直接映射窗口的物理地址的[31:29]位
    output wire [ 2:0]                  tlb_dmw0_vseg, // 直接映射窗口的虚地址的[31:29]位
    output wire                         tlb_dmw1_plv0,
    output wire                         tlb_dmw1_plv3,
    output wire [ 1:0]                  tlb_dmw1_mat,
    output wire [ 2:0]                  tlb_dmw1_pseg,
    output wire [ 2:0]                  tlb_dmw1_vseg,

    output wire [ 5:0]                  estat_ecode,

    input wire                          exc_fs_tlb_refill // 发生在 IF 级的plv特权等级异常
    input wire                          exc_fs_plv_invalid, // 发生在 IF 级的plv特权等级异常
);

/* ------------------ CRMD 当前模式信息 ------------------*/
    reg [ 1: 0] csr_crmd_plv;      //CRMD的PLV域，当前特权等级
    reg         csr_crmd_ie;       //CRMD的全局中断使能信号
    reg         csr_crmd_da;       //CRMD的直接地址翻译使能
    reg         csr_crmd_pg;
    reg [ 6: 5] csr_crmd_datf;
    reg [ 8: 7] csr_crmd_datm;

always @(posedge clk) begin
    if (rst) begin
        csr_crmd_plv <= 2'b0;  // 复位时需要将 CRMD 的 PLV 域置为全 0 （最高优先级）
        csr_crmd_ie <= 1'b0;
    end
    else if (wb_ex)begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if (ertn_flush)begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if (csr_we && csr_num ==`CSR_CRMD) //在被CSR写操作（csrwr、csrxchg）更新时，需要考虑写掩码
    begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                       | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE]
                       | ~csr_wmask[`CSR_CRMD_PIE] & csr_crmd_ie;
    end
end

always @(posedge clk) begin
    if (reset) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
        csr_crmd_datf <= 2'b00;
        csr_crmd_datm <= 2'b00;
    end 
    else if (csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                       | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                       | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                       | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                       | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
    end
    else if (tlb_refill) begin 
        csr_crmd_da <= 1'b1; // 触发 TLB 重填例外时，将 da 设为1
        csr_crmd_pg <= 1'b0; // 触发 TLB 重填例外时，将 pg 设为0
    end
    else if (ertn_flush && csr_estat_ecode == 6'h3f) begin 
        csr_crmd_da <= 1'b0; //当执行 ERTN 指令从例外处理程序返回时，如果 CSR.ESTAT.Ecode=0x3F，则硬件将该域置为 0
        csr_crmd_pg <= 1'b1; // 当执行 ERTN 指令从例外处理程序返回时，如果 CSR.ESTAT.Ecode=0x3F，则硬件将该域置为 1。
    end
end
// 目前处理器仅支持直接地址翻译模式，所以CRMD 的 DA、PG、DATF、DATM 域可以暂时置为常值。 --exp19 需要完善！！
//TODO: fix it
assign crmd_da = csr_crmd_da;
assign crmd_pg = csr_crmd_pg;
assign crmd_datf = csr_crmd_datf;
assign crmd_datm = csr_crmd_datm;
assign crmd_plv = csr_crmd_plv;

/* ------------------ PRMD 例外前模式信息 ------------------*/
reg  [ 1: 0] csr_prmd_pplv;     //CRMD的PLV域旧值
reg          csr_prmd_pie;      //CRMD的IE域旧值

always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                        | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                        | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

/* ------------------ ECFG 例外配置 ------------------*/
reg  [12: 0] csr_ecfg_lie;      //局部中断使能位

always @(posedge clk) begin
    if (rst)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
end

/* ------------------ ESTAT 例外状态 ------------------*/
reg  [12: 0] csr_estat_is;      // 例外中断的状态位（8个硬件中断+1个定时器中断+1个核间中断+2个软件中断）
reg  [ 5: 0] csr_estat_ecode;   // 例外类型一级编码
reg  [ 8: 0] csr_estat_esubcode;// 例外类型二级编码

always @(posedge clk) begin
    if (rst)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT)begin
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                            | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    end
    // csr_estat_is[9:2] <= hw_int_in[7:0]; //硬中断
    csr_estat_is[9:2] <= 8'b0;
    csr_estat_is[ 10] <= 1'b0;

    // csr_estat_is[ 11] <= 1'b0;
    if (timer_cnt[31:0] == 32'b0) begin
        csr_estat_is[11] <= 1'b1;
    end
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) 
        csr_estat_is[11] <= 1'b0;

    // csr_estat_is[ 12] <= ipi_int_in;
    csr_estat_is[ 12] <= 1'b0;  // 核间中断
end

always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

/* ------------------ ERA 例外返回地址 ------------------*/
reg [31:0] csr_era_pc; 

always @(posedge clk) begin
    if (wb_ex)
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num == `CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                    | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end

/* ------------------ EENTRY 例外入口地址 ------------------*/
reg  [25: 0] csr_eentry_va;     // 例外中断入口高位地址

always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                        | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end
/* ------------------ SAVE0-SAVE3 数据保存 ------------------*/
reg  [31: 0] csr_save0_data, csr_save1_data, csr_save2_data, csr_save3_data;

always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

wire [31:0] csr_crmd_rvalue = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
// wire [31:0] csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
wire [31:0] csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
wire [31:0] csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
wire [31:0] csr_era_rvalue = csr_era_pc;
wire [31:0] csr_eentey_rvalue = {csr_eentry_va, 6'b0};
wire [31:0] csr_save0_rvalue = csr_save0_data;
wire [31:0] csr_save1_rvalue = csr_save1_data;
wire [31:0] csr_save2_rvalue = csr_save2_data;
wire [31:0] csr_save3_rvalue = csr_save3_data;

wire[31:0] csr_badv_rvalue, csr_tid_rvalue, csr_tcfg_rvalue, csr_tval_rvalue;
wire[31:0] csr_tlbidx_rvalue, csr_tlbehi_rvalue, csr_tlbelo0_rvalue, csr_tlbelo1_rvalue, csr_asid_rvalue, csr_tlbrentry_rvalue;

//-- csr_badv

wire wb_ex_addr_err = wb_ecode==`ECODE_ADE ||wb_ecode==`ECODE_ALE||(wb_ecode == `ECODE_TLBR) || (wb_ecode == `ECODE_PIL) || (wb_ecode == `ECODE_PIS) || (wb_ecode == `ECODE_PIF) || (wb_ecode == `ECODE_PME) || (wb_ecode == `ECODE_PPI);
reg[31:0] csr_badv_vaddr;

always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err) begin  
        csr_badv_vaddr <= ((wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) || (wb_ecode == `ECODE_PIF) ||
                              (wb_ecode == `ECODE_PPI && exc_fs_plv_invalid) ||
                              (wb_ecode == `ECODE_TLBR && exc_fs_tlb_refill)) ? wb_pc : wb_vaddr;
    end
end

assign csr_badv_rvalue = csr_badv_vaddr;

//-- csr_tid

reg[31:0] csr_tid_tid;
wire[31:0] coreid_in = 0;

always @(posedge clk) begin
    if (rst)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]| ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end

assign csr_tid_rvalue = csr_tid_tid;

//-- csr_tcfg
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg[29:0] csr_tcfg_initval;
always @(posedge clk) begin
    if (rst)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN] | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD] | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV] | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
end
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
//--csr_tval
wire [31:0] tcfg_next_value;
reg [31:0] timer_cnt;
assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0] | ~csr_wmask[31:0]&{csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (rst)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval_rvalue = timer_cnt[31:0];

//--csr_ticlr
wire csr_ticlr_clr;
assign csr_ticlr_clr = 1'b0;
wire [31:0] csr_ticlr_rvalue = {29'b0, csr_ticlr_clr};

//--csr_stable_counter
reg [63:0] csr_stable_counter;
always @(posedge clk) begin
    if (rst)
        csr_stable_counter <= 64'h0;
    else
        csr_stable_counter <= csr_stable_counter + 1'b1;
end
wire [31:0] csr_stable_counter_hvalue = csr_stable_counter[63:32];
wire [31:0] csr_stable_counter_lvalue = csr_stable_counter[31:0];

//-- rvalue

assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
                  | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
                 | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
                  | {32{csr_num==`CSR_EENTRY}} & csr_eentey_rvalue
                  | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
                 | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
                 | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
                 | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue
                 | {32{csr_num==`CSR_TICLR}} & csr_ticlr_rvalue
                 | {32{csr_num==`CSR_STABLE_COUNTER_HI}} & csr_stable_counter_hvalue
                    | {32{csr_num==`CSR_STABLE_COUNTER_LO}} & csr_stable_counter_lvalue
                    | {32{csr_num==`CSR_TLBIDX}} & csr_tlbidx_rvalue
                    | {32{csr_num==`CSR_TLBEHI}} & csr_tlbehi_rvalue
                    | {32{csr_num==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
                    | {32{csr_num==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
                    | {32{csr_num==`CSR_ASID}} & csr_asid_rvalue
                    | {32{csr_num==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue;

assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie; // 送往ID级的中断有效信号 中断的使能情况分两个层次：低层次是与各中断一一对应的局部中断使能，通过 ECFG 控制寄存器的 LIE（Local Interrupt Enable）域的 11, 9..0 位来控制；高层次是全局中断使能，通过 CRMD 控制状态寄存器的 IE（Interrupt Enable）位来控制。
assign ex_entry = csr_eentey_rvalue; // 送往pre-IF级的异常处理入口地址
assign ertn_pc = csr_era_rvalue; // 送往pre-IF级的异常返回地址

wire tlb_srch = tlb_w_we & tlb_w_wop[0];
wire tlb_rd = tlb_w_we & tlb_w_wop[1];
wire tlb_wr = tlb_w_we & tlb_w_wop[2];
wire tlb_fill = tlb_w_we & tlb_w_wop[3];
    // else if (csr_we && csr_num == `CSR_ERA)
    //     csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
    //                 | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
//TLBIDX
//3-0 index:tlbsrch写，tlbr/w读
//29-24 ps:rd写，wr/fill读
//31 NE:srch和rd写，wr和fill在CSR.ESTAT.Ecode!=0x3F读取反值，在不满足时读取1
reg [3:0] tlbidx_idx;
reg [5:0] tlbidx_ps;
reg tlbidx_ne;
assign tlb_r_idx = tlbidx_idx;
assign tlb_r_ps = tlbidx_ps;
assign tlb_r_e = (csr_estat_ecode == 6'h3F)? 1'b1 : ~tlbidx_ne;
always @(posedge clk) begin
    if(tlb_srch)begin
        tlbidx_idx <= tlb_w_idx;
        tlbidx_ne  <=~tlb_w_e;
    end
    else if(tlb_rd)begin
        tlbidx_ps <= tlb_w_ps;
        tlbidx_ne <=~tlb_w_e;
    end
    else if(csr_we && csr_num == `CSR_TLBIDX)begin
        tlbidx_idx <= csr_wmask[`TLBIDX_IDX] & csr_wvalue[`TLBIDX_IDX]
                      | ~csr_wmask[`TLBIDX_IDX] & tlbidx_idx;
        tlbidx_ps <= csr_wmask[`TLBIDX_PS] & csr_wvalue[`TLBIDX_PS]
                      | ~csr_wmask[`TLBIDX_PS] & tlbidx_ps;
        tlbidx_ne <= csr_wmask[`TLBIDX_NE] & csr_wvalue[`TLBIDX_NE]
                      | ~csr_wmask[`TLBIDX_NE] & tlbidx_ne;
    end
end
assign csr_tlbidx_rvalue = {tlbidx_ne, 1'b0, tlbidx_ps, 20'b0, tlbidx_idx};
// TLBEHI(该寄存器包含 TLB 指令操作时与 TLB 表项高位部分虚页号相关的信息)
// 31-13 vppn:srch/wr/fill的虚地址来源，rd写入
// 异常处理：写入vaddr[31:13]至该寄存器：inst/load/store页无效，写允许3例外和特权等级不合规
/* 例外种类
PIL     load操作页无效例外
PIS     store操作页无效例外
PIF     取指操作页无效例外
PME     页修改例外
PPI     页特权等级不合规例外
TLBR    TLB重填例外
*/
reg [18:0] tlbehi_vppn;
wire ex_elbehi;
assign ex_elbehi = (wb_ecode == `ECODE_PIL) || (wb_ecode == `ECODE_PIS) || (wb_ecode == `ECODE_PIF) || 
                   (wb_ecode == `ECODE_PME) || (wb_ecode == `ECODE_PPI) || (wb_ecode == `ECODE_TLBR);
assign tlb_r_vppn = tlbehi_vppn;
always @(posedge clk) begin
    if(tlb_rd)begin
        tlbehi_vppn <= tlb_w_vppn;
    end
    else if(csr_we && csr_num == `CSR_TLBEHI)begin
        tlbehi_vppn <= csr_wmask[`TLBEHI_VPPN] & csr_wvalue[`TLBEHI_VPPN]
                      | ~csr_wmask[`TLBEHI_VPPN] & tlbehi_vppn;
    end
    else if (wb_ex &&ex_elbehi) begin
        tlbehi_vppn <= ((wb_ecode == `ECODE_PIF) || (wb_ecode == `ECODE_PPI && exc_fs_plv_invalid) || (wb_ecode == `ECODE_TLBR && exc_fs_tlb_refill)) ? wb_pc[31:13] : wb_vaddr[31:13]; // 例外处理：页无效(PIL/PIS/PIF/PME/PPI/TLBR) ?
    end
end
assign csr_tlbehi_rvalue = {tlbehi_vppn, 13'b0};

// TLBELO0、TLBELO1：wr/fill读，rd写
// 0 V
// 1 D
// 3-2 PLV
// 5-4 MAT
// 6 G
// 27-8 PPN
reg tlbelo0_v, tlbelo0_d, tlbelo0_g;
reg [1:0] tlbelo0_plv, tlbelo0_mat;
reg [19:0] tlbelo0_ppn;
assign tlb_r_v0 = tlbelo0_v;
assign tlb_r_d0 = tlbelo0_d;
assign tlb_r_plv0 = tlbelo0_plv;
assign tlb_r_mat0 = tlbelo0_mat;
assign tlb_r_ppn0 = tlbelo0_ppn;
always @(posedge clk) begin
    if(tlb_rd)begin
        tlbelo0_v <= tlb_w_v0;
        tlbelo0_d <= tlb_w_d0;
        tlbelo0_plv <= tlb_w_plv0;
        tlbelo0_mat <= tlb_w_mat0;
        tlbelo0_g <= tlb_w_g;
        tlbelo0_ppn <= tlb_w_ppn0;
    end
    else if(csr_we && csr_num == `CSR_TLBELO0)begin
        tlbelo0_v <= csr_wmask[`TLBELO_V] & csr_wvalue[`TLBELO_V]
                      | ~csr_wmask[`TLBELO_V] & tlbelo0_v;
        tlbelo0_d <= csr_wmask[`TLBELO_D] & csr_wvalue[`TLBELO_D]
                      | ~csr_wmask[`TLBELO_D] & tlbelo0_d;
        tlbelo0_plv <= csr_wmask[`TLBELO_PLV] & csr_wvalue[`TLBELO_PLV]
                      | ~csr_wmask[`TLBELO_PLV] & tlbelo0_plv;
        tlbelo0_mat <= csr_wmask[`TLBELO_MAT] & csr_wvalue[`TLBELO_MAT]
                      | ~csr_wmask[`TLBELO_MAT] & tlbelo0_mat;
        tlbelo0_g <= csr_wmask[`TLBELO_G] & csr_wvalue[`TLBELO_G]
                      | ~csr_wmask[`TLBELO_G] & tlbelo0_g;
        tlbelo0_ppn <= csr_wmask[`TLBELO_PPN] & csr_wvalue[`TLBELO_PPN]
                      | ~csr_wmask[`TLBELO_PPN] & tlbelo0_ppn;
    end
end
assign csr_tlbelo0_rvalue = {4'b0, tlbelo0_ppn, 1'b0, tlbelo0_g, tlbelo0_mat, tlbelo0_plv, tlbelo0_d, tlbelo0_v};
reg tlbelo1_v, tlbelo1_d, tlbelo1_g;
reg [1:0] tlbelo1_plv, tlbelo1_mat;
reg [19:0] tlbelo1_ppn;
assign tlb_r_v1 = tlbelo1_v;
assign tlb_r_d1 = tlbelo1_d;
assign tlb_r_plv1 = tlbelo1_plv;
assign tlb_r_mat1 = tlbelo1_mat;
assign tlb_r_ppn1 = tlbelo1_ppn;
assign tlb_r_g = tlbelo0_g & tlbelo1_g;
always @(posedge clk) begin
    if(tlb_rd)begin
        tlbelo1_v <= tlb_w_v1;
        tlbelo1_d <= tlb_w_d1;
        tlbelo1_plv <= tlb_w_plv1;
        tlbelo1_mat <= tlb_w_mat1;
        tlbelo1_g <= tlb_w_g;
        tlbelo1_ppn <= tlb_w_ppn1;
    end
    else if(csr_we && csr_num == `CSR_TLBELO1)begin
        tlbelo1_v <= csr_wmask[`TLBELO_V] & csr_wvalue[`TLBELO_V]
                      | ~csr_wmask[`TLBELO_V] & tlbelo1_v;
        tlbelo1_d <= csr_wmask[`TLBELO_D] & csr_wvalue[`TLBELO_D]
                      | ~csr_wmask[`TLBELO_D] & tlbelo1_d;
        tlbelo1_plv <= csr_wmask[`TLBELO_PLV] & csr_wvalue[`TLBELO_PLV]
                      | ~csr_wmask[`TLBELO_PLV] & tlbelo1_plv;
        tlbelo1_mat <= csr_wmask[`TLBELO_MAT] & csr_wvalue[`TLBELO_MAT]
                      | ~csr_wmask[`TLBELO_MAT] & tlbelo1_mat;
        tlbelo1_g <= csr_wmask[`TLBELO_G] & csr_wvalue[`TLBELO_G]
                      | ~csr_wmask[`TLBELO_G] & tlbelo1_g;
        tlbelo1_ppn <= csr_wmask[`TLBELO_PPN] & csr_wvalue[`TLBELO_PPN]
                      | ~csr_wmask[`TLBELO_PPN] & tlbelo1_ppn;
    end

end
assign csr_tlbelo1_rvalue = {4'b0, tlbelo1_ppn, 1'b0, tlbelo1_g, tlbelo1_mat, tlbelo1_plv, tlbelo1_d, tlbelo1_v};

// ASID
// 9-0 ASID 取指、访存、srch、wr、fill读，rd写
// 23-16 ASIDBITS=8'd10
reg [9:0] asid_asid;
reg [7:0] asid_asidbits;
always @(posedge clk) begin
    if(rst)
        asid_asidbits <= 8'd10;
end
always @(posedge clk) begin
    if(tlb_rd)begin
        asid_asid <= tlb_w_asid;
    end
    else if(csr_we && csr_num == `CSR_ASID)begin
        asid_asid <= csr_wmask[`ASID_ASID] & csr_wvalue[`ASID_ASID]
                      | ~csr_wmask[`ASID_ASID] & asid_asid;
    end
end
assign tlb_r_asid = asid_asid;
assign csr_asid_rvalue = {8'b0, asid_asidbits, 6'b0, asid_asid};

// TLBRENTRY
// 31-6 PA TLB重填例外入口地址31-6位
reg [25:0] tlbrentry_pa;
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_TLBRENTRY)begin
        tlbrentry_pa <= csr_wmask[`TLBRENTRY_PA] & csr_wvalue[`TLBRENTRY_PA]
                      | ~csr_wmask[`TLBRENTRY_PA] & tlbrentry_pa;
    end
end
assign csr_tlbrentry_rvalue = {tlbrentry_pa, 6'b0};
//TODO: complete it considering port ertn_pc
assign tlb_r_TLBR = csr_estat_ecode == 6'h3F;
//复位：所有实现的CSR.DMW中的PLV0、PLV3均为0；

// DMW0 直接映射配置窗口0 见讲义5.2.1节
reg         dmw0_plv0, dmw0_plv3;
reg [1:0]   dmw0_mat;
reg [2:0]   dmw0_pseg;
reg [2:0]   dmw0_vseg;

always @(posedge clk) begin
    if(rst) begin
        dmw0_plv0 <= 1'b0;
        dmw0_plv3 <= 1'b0;
        dmw0_mat  <= 2'h0;
        dmw0_pseg <= 3'h0;
        dmw0_vseg <= 3'h0;
    end
    else if(csr_we && csr_num == `CSR_DMW0) begin
        dmw0_plv0 <= csr_wmask[`DMW_PLV0] & csr_wvalue[`DMW_PLV0] | ~csr_wmask[`DMW_PLV0] & dmw0_plv0;
        dmw0_plv3 <= csr_wmask[`DMW_PLV3] & csr_wvalue[`DMW_PLV3] | ~csr_wmask[`DMW_PLV3] & dmw0_plv3;
        dmw0_mat  <= csr_wmask[`DMW_MAT]  & csr_wvalue[`DMW_MAT]  | ~csr_wmask[`DMW_MAT]  & dmw0_mat;
        dmw0_pseg <= csr_wmask[`DMW_PSEG] & csr_wvalue[`DMW_PSEG] | ~csr_wmask[`DMW_PSEG] & dmw0_pseg;
        dmw0_vseg <= csr_wmask[`DMW_VSEG] & csr_wvalue[`DMW_VSEG] | ~csr_wmask[`DMW_VSEG] & dmw0_vseg;
    end
end
assign tlb_dmw0_plv0 = dmw0_plv0;
assign tlb_dmw0_plv3 = dmw0_plv3;
assign tlb_dmw0_mat  = dmw0_mat;
assign tlb_dmw0_pseg = dmw0_pseg;
assign tlb_dmw0_vseg = dmw0_vseg;

// DMW1 直接映射配置窗口1 见讲义5.2.1节
reg         dmw1_plv0, dmw1_plv3;
reg [1:0]   dmw1_mat;
reg [2:0]   dmw1_pseg;
reg [2:0]   dmw1_vseg;

always @(posedge clk) begin
    if(rst) begin
        dmw1_plv0 <= 1'b0;
        dmw1_plv3 <= 1'b0;
        dmw1_mat  <= 2'h0;
        dmw1_pseg <= 3'h0;
        dmw1_vseg <= 3'h0;
    end
    else if(csr_we && csr_num == `CSR_DMW1) begin
        dmw1_plv0 <= csr_wmask[`DMW_PLV0] & csr_wvalue[`DMW_PLV0] | ~csr_wmask[`DMW_PLV0] & dmw1_plv0;
        dmw1_plv3 <= csr_wmask[`DMW_PLV3] & csr_wvalue[`DMW_PLV3] | ~csr_wmask[`DMW_PLV3] & dmw1_plv3;
        dmw1_mat  <= csr_wmask[`DMW_MAT]  & csr_wvalue[`DMW_MAT]  | ~csr_wmask[`DMW_MAT]  & dmw1_mat;
        dmw1_pseg <= csr_wmask[`DMW_PSEG] & csr_wvalue[`DMW_PSEG] | ~csr_wmask[`DMW_PSEG] & dmw1_pseg;    
        dmw1_vseg <= csr_wmask[`DMW_VSEG] & csr_wvalue[`DMW_VSEG] | ~csr_wmask[`DMW_VSEG] & dmw1_vseg;
    end
end
assign tlb_dmw1_plv0 = dmw1_plv0;
assign tlb_dmw1_plv3 = dmw1_plv3;
assign tlb_dmw1_mat  = dmw1_mat;
assign tlb_dmw1_pseg = dmw1_pseg;
assign tlb_dmw1_vseg = dmw1_vseg;

endmodule
