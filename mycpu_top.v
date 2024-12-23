module mycpu_top(
    input  aclk   ,
    input  aresetn,

    // read req channel
    output [ 3:0] arid   , // 读请求ID
    output [31:0] araddr , // 读请求地址
    output [ 7:0] arlen  , // 读请求传输长度（数据传输拍数，固定为8'b0）
    output [ 2:0] arsize , // 读请求传输大小（数据传输每拍的字节数）
    output [ 1:0] arburst, // 传输类型（固定为2'b1）
    output [ 1:0] arlock , // 原子锁（固定为2'b0）
    output [ 3:0] arcache, // Cache属性（固定为4'b0）
    output [ 2:0] arprot , // 保护属性（固定为3'b0）
    output        arvalid, // 读请求地址有效
    input         arready, // Slave端准备好接收地址传输

    // read response channel
    input [ 3:0]  rid    , // 读请求ID号，同一请求rid与arid一致
    input [31:0]  rdata  , // 读请求读出的数据
    input [ 1:0]  rresp  , // 读请求是否完成(忽略)
    input         rlast  , // 读请求最后一拍数据的指示信号(忽略)
    input         rvalid , // 读请求数据有效
    output        rready , // Master端准备好接受数据

    // write req channel
    output [ 3:0] awid   , // 写请求的ID号（固定为4'b1）
    output [31:0] awaddr , // 写请求的地址
    output [ 7:0] awlen  , // 写请求传输长度（拍数，固定为8'b0）
    output [ 2:0] awsize , // 写请求传输每拍字节数
    output [ 1:0] awburst, // 写请求传输类型（固定为2'b1）
    output [ 1:0] awlock , // 原子锁（固定为2'b0）
    output [ 3:0] awcache, // Cache属性（固定为4'b0）
    output [ 2:0] awprot , // 保护属性（固定为3'b0）
    output        awvalid, // 写请求地址有效
    input         awready, // Slave端准备好接受地址传输   

    // write data channel
    output [ 3:0] wid    , // 写请求的ID号（固定为4'b1）
    output [31:0] wdata  , // 写请求的写数据
    output [ 3:0] wstrb  , // 写请求字节选通位
    output        wlast  , // 写请求的最后一拍数据的指示信号（固定为1'b1）
    output        wvalid , // 写数据有效
    input         wready , // Slave端准备好接受写数据传输   

    // write response channel
    input  [ 3:0] bid    , // 写请求的ID号(忽略)
    input  [ 1:0] bresp  , // 写请求完成信号(忽略)
    input         bvalid , // 写请求响应有效
    output        bready , // Master端准备好接收响应信号

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    // inst sram interface
    wire        inst_sram_req;
    wire        inst_sram_wr;
    wire [ 1:0] inst_sram_size;
    wire [ 3:0] inst_sram_wstrb;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire        inst_sram_addr_ok;
    wire        inst_sram_data_ok;
    wire [31:0] inst_sram_rdata;
    // data sram interface
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;

    //icache read channel
    wire        if_icache_uncache;
    wire [31:0] inst_virtual_addr;
    wire        icache_addr_ok;
    wire        icache_data_ok;
    wire [31:0] icache_rdata;
    wire        icache_rd_req;
    wire [ 2:0] icache_rd_type;
    wire [31:0] icache_rd_addr;
    wire        icache_rd_rdy;
    wire        icache_ret_valid;
    wire        icache_ret_last;
    wire [31:0] icache_ret_data;

    //icache write channel=meaning less ,all is 0        
    wire        icache_wr_req;
    wire [ 2:0] icache_wr_type;
    wire [31:0] icache_wr_addr;
    wire [ 3:0] icache_wr_strb;
    wire [127:0]icache_wr_data;
    wire        icache_wr_rdy=1'b0;     

    //dcache read channel
    wire        if_dcache_uncache;
    wire [31:0] data_virtual_addr;
    wire        dcache_addr_ok;
    wire        dcache_data_ok;
    wire [31:0] dcache_rdata;
    wire        dcache_rd_req;
    wire [ 2:0] dcache_rd_type;
    wire [31:0] dcache_rd_addr;
    wire        dcache_rd_rdy;
    wire        dcache_ret_valid;
    wire        dcache_ret_last;
    wire [31:0] dcache_ret_data;

    //dcache write channel
    wire        dcache_wr_req;
    wire [ 2:0] dcache_wr_type;
    wire [31:0] dcache_wr_addr;
    wire [ 3:0] dcache_wr_strb;
    wire[127:0] dcache_wr_data;
    wire        dcache_wr_rdy;

    //cacop interface
    wire [ 1:0] cacop_code_4_3;
    wire        cacop_Icache_en;
    wire        cacop_Icache_ok;
    wire        cacop_Dcache_en;
    wire        cacop_Dcache_ok;

    mycpu_core my_core(
        .clk            (aclk),
        .resetn         (aresetn),

        // inst sram interface
        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_size     (inst_sram_size),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (icache_addr_ok),   // exp21 修改，考虑icache是否传给cpu它的addr_ok
        .inst_sram_data_ok  (icache_data_ok),   // exp21 修改，考虑icache是否传给cpu它的data_ok
        .inst_sram_rdata    (icache_rdata),     // exp21 修改，输入给cpu处理的指令是icache的rdata
        .if_icache_uncache  (if_icache_uncache),

        // data sram interface
        .data_sram_req      (data_sram_req),
        .data_sram_wr       (data_sram_wr),
        .data_sram_size     (data_sram_size),
        .data_sram_wstrb    (data_sram_wstrb),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .data_sram_addr_ok  (dcache_addr_ok),   // exp22 修改，考虑dcache是否传给cpu它的addr_ok
        .data_sram_data_ok  (dcache_data_ok),   // exp22 修改，考虑dcache是否传给cpu它的data_ok
        .data_sram_rdata    (dcache_rdata),     // exp22 修改，输入给cpu处理的数据是dcache的rdata
        .if_dcache_uncache  (if_dcache_uncache),

        // trace debug interface
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata),

        .inst_virtual_addr  (inst_virtual_addr),
        .data_virtual_addr  (data_virtual_addr),

        .cacop_code_4_3     (cacop_code_4_3),
        .cacop_Icache_en    (cacop_Icache_en),
        .cacop_Icache_ok    (cacop_Icache_ok),
        .cacop_Dcache_en    (cacop_Dcache_en),
        .cacop_Dcache_ok    (cacop_Dcache_ok)
    ); 

    cpu_bridge_axi my_bridge_sram_axi(
        .aclk               (aclk),
        .aresetn            (aresetn),

        .arid               (arid),
        .araddr             (araddr),
        .arlen              (arlen),
        .arsize             (arsize),
        .arburst            (arburst),
        .arlock             (arlock),
        .arcache            (arcache),
        .arprot             (arprot),
        .arvalid            (arvalid),
        .arready            (arready),

        .rid                (rid),
        .rdata              (rdata),
        .rvalid             (rvalid),
        .rlast              (rlast),
        .rready             (rready),

        .awid               (awid),
        .awaddr             (awaddr),
        .awlen              (awlen),
        .awsize             (awsize),
        .awburst            (awburst),
        .awlock             (awlock),
        .awcache            (awcache),
        .awprot             (awprot),
        .awvalid            (awvalid),
        .awready            (awready),

        .wid                (wid),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .wlast              (wlast),
        .wvalid             (wvalid),
        .wready             (wready),

        .bid                (bid),
        .bvalid             (bvalid),
        .bready             (bready),

        .icache_rd_req      (icache_rd_req),
        .icache_rd_type     (icache_rd_type),
        .icache_rd_addr     (icache_rd_addr),
        .icache_rd_rdy      (icache_rd_rdy),
        .icache_ret_valid   (icache_ret_valid),
        .icache_ret_last    (icache_ret_last),
        .icache_ret_data    (icache_ret_data),

        .dcache_rd_req      (dcache_rd_req),
        .dcache_rd_type     (dcache_rd_type),
        .dcache_rd_addr     (dcache_rd_addr),
        .dcache_rd_rdy      (dcache_rd_rdy),
        .dcache_ret_valid   (dcache_ret_valid),
        .dcache_ret_last    (dcache_ret_last),
        .dcache_ret_data    (dcache_ret_data),

        .dcache_wr_req      (dcache_wr_req),
        .dcache_wr_type     (dcache_wr_type),
        .dcache_wr_addr     (dcache_wr_addr),
        .dcache_wr_wstrb    (dcache_wr_strb),
        .dcache_wr_data     (dcache_wr_data),
        .dcache_wr_rdy      (dcache_wr_rdy)
    );

    cache Icache (
        .resetn             (aresetn),
        .clk                (aclk),
        //----------cpu interface------
        .valid              (inst_sram_req||cacop_Icache_en),       //pre-if request valid
        .op                 (inst_sram_wr),        //always 0==read
        .index              (inst_virtual_addr[11:4]),
        .tag                (inst_sram_addr[31:12]),//from tlb:inst_sram_addr[31:12]=实地址
        .offset             (inst_virtual_addr[3:0]),
        .wstrb              (inst_sram_wstrb),
        .wdata              (inst_sram_wdata),
        .uncache            (if_icache_uncache),       

        .addr_ok            (icache_addr_ok),       //output 阻塞流水线的指令
        .data_ok            (icache_data_ok),       //output
        .rdata              (icache_rdata),         //output
        //--------AXI read interface-------
        .rd_req             (icache_rd_req),        //output
        .rd_type            (icache_rd_type),       //output
        .rd_addr            (icache_rd_addr),       //output
        .rd_rdy             (icache_rd_rdy),        //input 总线发来的
        .ret_valid          (icache_ret_valid),     //input
        .ret_last           (icache_ret_last),      //input
        .ret_data           (icache_ret_data),      //input
        //--------AXI write interface------
        .wr_req             (icache_wr_req),        //output,对于icache永远是0
        .wr_type            (icache_wr_type),       //output，icache 不会使用到
        .wr_addr            (icache_wr_addr),       //output，icache 不会使用到
        .wr_wstrb           (icache_wr_strb),       //output，icache 不会使用到
        .wr_data            (icache_wr_data),       //output，icache 不会使用到
        .wr_rdy             (icache_wr_rdy),         //input, icache不会写sram，置1即可
        .cacop_en           (cacop_Icache_en),
        .cacop_va           (inst_virtual_addr),
        .code_4_3           (cacop_code_4_3),
        .cacop_ok           (cacop_Icache_ok)
    );

    cache Dcache (
        .resetn             (aresetn),
        .clk                (aclk),
        //----------cpu interface------
        .valid              (data_sram_req||cacop_Dcache_en),       //pre-if request valid
        .op                 (data_sram_wr),        //always 0==read
        .index              (data_virtual_addr[11:4]),
        .tag                (data_sram_addr[31:12]),//from tlb:inst_sram_addr[31:12]=实地址
        .offset             (data_virtual_addr[3:0]),
        .wstrb              (data_sram_wstrb),
        .wdata              (data_sram_wdata),
        .uncache            (if_dcache_uncache),                 

        .addr_ok            (dcache_addr_ok),       //output 阻塞流水线的指令
        .data_ok            (dcache_data_ok),       //output
        .rdata              (dcache_rdata),         //output
        //--------AXI read interface-------
        .rd_req             (dcache_rd_req),        //output
        .rd_type            (dcache_rd_type),       //output
        .rd_addr            (dcache_rd_addr),       //output
        .rd_rdy             (dcache_rd_rdy),        //input 总线发来的
        .ret_valid          (dcache_ret_valid),     //input
        .ret_last           (dcache_ret_last),      //input
        .ret_data           (dcache_ret_data),      //input
        //--------AXI write interface------
        .wr_req             (dcache_wr_req),        //output,对于icache永远是0
        .wr_type            (dcache_wr_type),       //output
        .wr_addr            (dcache_wr_addr),       //output
        .wr_wstrb           (dcache_wr_strb),       //output
        .wr_data            (dcache_wr_data),       //output
        .wr_rdy             (dcache_wr_rdy),       //input, icache不会写sram，置1即可
        .cacop_en           (cacop_Dcache_en),
        .cacop_va           (data_virtual_addr),
        .code_4_3           (cacop_code_4_3),
        .cacop_ok           (cacop_Dcache_ok)
    );


endmodule