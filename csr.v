`include "csr_defines.vh"

module csr(
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

    input wire   [31:0] wb_vaddr // 来自WB级的访存地址
);

/* ------------------ CRMD 当前模式信息 ------------------*/
    reg  [ 1: 0] csr_crmd_plv;      //CRMD的PLV域，当前特权等级
    reg          csr_crmd_ie;       //CRMD的全局中断使能信号
    wire          csr_crmd_da;       //CRMD的直接地址翻译使能
    wire          csr_crmd_pg;
    wire  [ 6: 5] csr_crmd_datf;
    wire  [ 8: 7] csr_crmd_datm;

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


// 目前处理器仅支持直接地址翻译模式，所以CRMD 的 DA、PG、DATF、DATM 域可以暂时置为常值。
assign csr_crmd_da = 1'b1;
assign csr_crmd_pg = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;

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

//-- csr_badv

wire wb_ex_addr_err = wb_ecode==`ECODE_ADE ||wb_ecode==`ECODE_ALE;
reg[31:0] csr_badv_vaddr;

always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err) begin  
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
        wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
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
                    | {32{csr_num==`CSR_STABLE_COUNTER_LO}} & csr_stable_counter_lvalue;

assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie; // 送往ID级的中断有效信号 中断的使能情况分两个层次：低层次是与各中断一一对应的局部中断使能，通过 ECFG 控制寄存器的 LIE（Local Interrupt Enable）域的 11, 9..0 位来控制；高层次是全局中断使能，通过 CRMD 控制状态寄存器的 IE（Interrupt Enable）位来控制。
assign ex_entry = csr_eentey_rvalue; // 送往pre-IF级的异常处理入口地址
assign ertn_pc = csr_era_rvalue; // 送往pre-IF级的异常返回地址

//TLBIDX
//3-0 index:tlbsrch写，tlbr/w读
//29-24 ps:rd写，wr/fill读
//31 NE:srch和rd写，wr和fill在CSR.ESTAT.Ecode!=0x3F读取反值，在不满足时读取1

// TLBEHI
// 31-13 vppn:srch/wr/fill的虚地址来源，rd写入
// 异常处理：写入vaddr[31:13]至该寄存器：inst/load/store页无效，写允许3例外和特权等级不合规

// TLBELO0、TLBELO1：wr/fill读，rd写
// 0 V
// 1 D
// 3-2 PLV
// 5-4 MAT
// 6 G
// 27-8 PPN

// ASID
// 9-0 ASID 取指、访存、srch、wr、fill读，rd写
// 23-16 ASIDBITS=8'd10

// TLBRENTRY
// 31-6 PA TLB重填例外入口地址31-6位

endmodule
