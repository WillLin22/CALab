module cpu_bridge_axi(
    input               aclk,
    input               aresetn,

    /*
    axi:
    master: bridge ; slave: axi
    input:  axi --> bridge
    output: bridge --> axi
    */
    // ar: read req channel 读请求通道
    output  [ 3:0]      arid,    // 读请求ID
    output  [31:0]      araddr,  // 读请求地址
    output  [ 7:0]      arlen,   // 读请求传输长度（数据传输拍数，固定为8'b0）
    output  [ 2:0]      arsize,  // 读请求传输大小（数据传输每拍的字节数）
    output  [ 1:0]      arburst, // 传输类型（固定为2'b1）
    output  [ 1:0]      arlock,  // 原子锁（固定为2'b0）
    output  [ 3:0]      arcache, // Cache属性（固定为4'b0）
    output  [ 2:0]      arprot,  // 保护属性（固定为3'b0）
    output              arvalid, // 读请求地址有效
    input               arready, // Slave端准备好接收地址传输

    // r: read response channel 读响应通道
    input   [ 3:0]      rid,     // 读请求ID号，同一请求rid与arid一致
    input   [31:0]      rdata,   // 读请求读出的数据
    input   [ 1:0]      rresp,   // 读请求是否完成(忽略)
    input               rlast,   // 读请求最后一拍数据的指示信号(忽略)
    input              	rvalid,  // 读请求数据有效
    output             	rready,  // Master端准备好接受数据

    // aw: write req channel  写请求通道
    output  [ 3:0]      awid,    // 写请求的ID号（固定为4'b1）
    output  [31:0]      awaddr,  // 写请求的地址
    output  [ 7:0]      awlen,   // 写请求传输长度（拍数，固定为8'b0）
    output  [ 2:0]      awsize,  // 写请求传输每拍字节数
    output  [ 1:0]      awburst, // 写请求传输类型（固定为2'b1）
    output  [ 1:0]      awlock,  // 原子锁（固定为2'b0）
    output  [ 3:0]      awcache, // Cache属性（固定为4'b0）
    output  [ 2:0]      awprot,  // 保护属性（固定为3'b0）
    output              awvalid, // 写请求地址有效
    input              	awready, // Slave端准备好接受地址传输 

    // w: write data channel 写数据通道
    output  [ 3:0]      wid,      // 写请求的ID号（固定为4'b1）
    output  [31:0]      wdata,    // 写请求的写数据
    output  [ 3:0]      wstrb,    // 写请求字节选通位
    output          	wlast,    // 写请求的最后一拍数据的指示信号（固定为1'b1）
    output             	wvalid,   // 写数据有效
    input              	wready,   // Slave端准备好接受写数据传输

    // wr: write response channel 写请求通道
    input   [ 3:0]      bid,      // 写请求的ID号(忽略)
    input   [ 1:0]      bresp,    // 写请求完成信号(忽略)
    input              	bvalid,   // 写请求响应有效
    output             	bready,   // Master端准备好接收响应信号

    // inst sram interface
    /*
    inst sram:
    master: cpu ; slave: bridge
    input:  cpu --> bridge
    output: bridge --> cpu
    */
    input              	inst_sram_req,
    input              	inst_sram_wr,
    input   [ 1:0]      inst_sram_size,
    input   [31:0]      inst_sram_addr,
    input   [ 3:0]      inst_sram_wstrb,
    input   [31:0]      inst_sram_wdata,
    output              inst_sram_addr_ok,
    output              inst_sram_data_ok,
    output  [31:0]      inst_sram_rdata,

    // data sram interface
    /*
    data sram:
    master: cpu ; slave: bridge
    input:  cpu --> bridge
    output: bridge --> cpu
    */
    input               data_sram_req,
    input               data_sram_wr,
    input   [ 1:0]      data_sram_size,
    input   [31:0]      data_sram_addr,
    input   [31:0]      data_sram_wdata,
    input  	[ 3:0]      data_sram_wstrb,
    output              data_sram_addr_ok,
    output              data_sram_data_ok,
    output  [31:0]      data_sram_rdata
);

    localparam  // 读请求状态机
                AR_IDLE         = 3'b001,
                AR_REQ_START    = 3'b010,
                AR_REQ_END      = 3'b100,

                // 读响应状态机
                R_IDLE          = 3'b001,
                R_DATA_START    = 3'b010,
                R_DATA_END      = 3'b100,

                // 写请求 & 写数据状态机
                W_IDLE         = 5'b00001,
                W_REQ_START    = 5'b00010,
                W_ADDR_RESP    = 5'b00100,
                W_DATA_RESP    = 5'b01000,
                W_REQ_END      = 5'b10000,

                // 写响应状态机
                B_IDLE          = 3'b001,
                B_START         = 3'b010,
                B_END           = 3'b100;

    // 状态机状态寄存器
    reg [2:0] ar_current_state;
    reg [2:0] ar_next_state;
    reg [2:0] r_current_state;
    reg [2:0] r_next_state;
    reg [4:0] w_current_state;
    reg [4:0] w_next_state;
    reg [2:0] b_current_state;
    reg [2:0] b_next_state;

    // 请求已经握手成功而未响应的情况，用于计数
	reg [1:0] ar_wait_resp_cnt;
	reg [1:0] aw_wait_resp_cnt;
	reg [1:0] wd_wait_resp_cnt;

    wire read_block; // 写后读阻塞信号。只要有与读请求相同地址的写请求，就停止发起读请求直至Master 端收到写响应
    wire is_writing = (w_current_state == W_REQ_START) | (w_current_state == W_ADDR_RESP) | (w_current_state == W_DATA_RESP) | (w_current_state == W_REQ_END); // 有写操作
    assign read_block = (araddr == awaddr) && is_writing && (b_current_state != B_END); // 写后读(读写地址相同且写操作数据未写入)，则需要阻塞

    wire areset;
    assign areset = ~aresetn;

    wire rd_inst_req;
    wire wr_inst_req;
    wire rd_data_req;
    wire wr_data_req;

    // wr --> 0读 ; 1写
    assign rd_inst_req = inst_sram_req && ~inst_sram_wr;      
    assign wr_inst_req = inst_sram_req && inst_sram_wr;
    assign rd_data_req = data_sram_req && ~data_sram_wr;
    assign wr_data_req = data_sram_req && data_sram_wr;

    /* --------------------- 读请求状态机 ------------------------*/
    always @(posedge aclk) begin
        if(areset) begin
            ar_current_state <= AR_IDLE;
        end
        else begin
            ar_current_state <= ar_next_state;
        end
    end

    always @(*) begin
        case(ar_current_state)
            AR_IDLE: begin
                if(areset | read_block) begin 
                    ar_next_state = AR_IDLE;
                end
                else if(rd_inst_req | rd_data_req) begin // 如果有读数据/读地址请求，则进入读请求状态
                    ar_next_state = AR_REQ_START;
                end
                else begin
                    ar_next_state = AR_IDLE;
                end
            end
            AR_REQ_START: begin
                if(arvalid && arready) begin // 读请求握手成功，则进入读请求结束状态
                    ar_next_state = AR_REQ_END;
                end
                else begin
                    ar_next_state = AR_REQ_START;
                end
            end
            AR_REQ_END: begin
                ar_next_state = AR_IDLE;
            end
            default:
                ar_next_state = AR_IDLE;
        endcase
    end

    /* --------------------- 读响应状态机 ------------------------*/
    always @(posedge aclk) begin
        if(areset) begin
            r_current_state <= R_IDLE;
        end
        else begin
            r_current_state <= r_next_state;
        end
    end

    always @(*) begin
        case(r_current_state)
            R_IDLE: begin
                if(areset) begin
                    r_next_state = R_IDLE;
                end
                else if ((arvalid && arready) || (|ar_wait_resp_cnt)) begin // 读请求握手 或者 有读请求已经握手但未成功响应的情况，则进入读数据传输开始状态
                    r_next_state = R_DATA_START;
                end
                else begin
                    r_next_state = R_IDLE;
                end
            end
            R_DATA_START: begin
                if(rvalid && rready && rlast) begin // 传输完毕，则进入读数据传输结束状态
                    r_next_state = R_DATA_END;
                end
                else begin
                    r_next_state = R_DATA_START;
                end
            end
            R_DATA_END: begin
                r_next_state = R_IDLE;
            end
            default:
                r_next_state = R_IDLE;
        endcase
    end

    /* --------------------- 写请求、写数据状态机 ------------------------*/
    always @(posedge aclk) begin
        if(areset) begin
            w_current_state <= W_IDLE;
        end
        else begin
            w_current_state <= w_next_state;
        end
    end

    always @(*) begin
        case(w_current_state)
            W_IDLE: begin
                if(areset) begin
                    w_next_state = W_IDLE;
                end
                else if(wr_data_req | wr_inst_req) begin // 有写请求，则进入写请求开始状态
                    w_next_state = W_REQ_START;
                end
                else begin
                    w_next_state = W_IDLE;
                end
            end
            W_REQ_START: begin
                if((awvalid && awready && wvalid && wready) || ((|aw_wait_resp_cnt) && (|wd_wait_resp_cnt))) begin // 写请求地址和写请求数据同时握手 或者 写请求地址和写请求数据都存在已发送但是未收到响应的情况，则进入写请求结束状态
                    w_next_state = W_REQ_END;
                end
                else if ((awvalid && awready) || (|aw_wait_resp_cnt)) begin // 写请求地址握手 或者 存在写请求地址发送但未收到响应的情况（且没有写数据需要处理），则进入写请求地址响应状态
                    w_next_state = W_ADDR_RESP;
                end
                else if ((wvalid && wready) || (|wd_wait_resp_cnt)) begin // 写请求数据握手 或者 存在写请求数据发送但是未收到响应的情况（且没有写请求地址需要处理），则进入写请求数据响应状态
                    w_next_state = W_DATA_RESP;
                end
                else begin
                    w_next_state = W_REQ_START;
                end
            end
            W_ADDR_RESP: begin
                if(wvalid && wready) begin // 写请求数据握手
                    w_next_state = W_REQ_END;
                end
                else begin
                    w_next_state = W_ADDR_RESP;
                end
            end
            W_DATA_RESP: begin
                if (awvalid && awready) begin // 写请求地址握手
                    w_next_state = W_REQ_END;
                end
                else begin
                    w_next_state = W_DATA_RESP;
                end
            end
            W_REQ_END: begin
                if (bvalid && bready) begin  // 写响应握手，写请求结束，回到空闲状态
                    w_next_state = W_IDLE;
                end
                else begin
                    w_next_state = W_REQ_END;
                end
            end
            default:
                w_next_state = W_IDLE;
        endcase
    end

    /* --------------------- 写响应状态机 ------------------------*/
    always @(posedge aclk) begin
        if(areset) begin
            b_current_state <= B_START;
        end
        else begin
            b_current_state <= b_next_state;
        end
    end

    always @(*) begin
        case(b_current_state)
            B_IDLE: begin
                if(areset) begin
                    b_next_state = B_IDLE;
                end
                else if(bready) begin
                    b_next_state = B_START;
                end
                else begin
                    b_next_state = B_IDLE;
                end
            end
            B_START: begin
                if(bvalid && bready) begin
                    b_next_state = B_END;
                end
                else begin
                    b_next_state = B_START;
                end
            end
            B_END: begin
                b_next_state = B_START;
            end
            default:
                b_next_state = B_IDLE;
        endcase
    end

    /* --------------------- 读请求处理 ------------------------*/
    reg [3:0] arid_reg;
    reg [31:0] araddr_reg;
    reg [1:0] arsize_reg;

    always @(posedge aclk) begin
        if (areset) begin
            arid_reg <= 4'b0;
            araddr_reg <= 32'b0;
            arsize_reg <= 3'b0;
        end
        else if (ar_current_state == AR_IDLE) begin // 读请求状态机为空闲状态，更新数据
            arid_reg <= {3'b0, rd_data_req}; // 数据RAM请求优先于指令RAM
            araddr_reg <= rd_data_req ? data_sram_addr : inst_sram_addr;
            arsize_reg <= rd_data_req ? {1'b0, data_sram_size}  : {1'b0, inst_sram_size};
        end
    end

    assign arid    = arid_reg;
    assign araddr  = araddr_reg;
    assign arlen   = 8'b0;
    assign arsize  = arsize_reg;
    assign arburst = 2'b1;
    assign arlock  = 1'b0;
    assign arcache = 4'b0;
    assign arprot  = 3'b0;
    assign arvalid = (ar_current_state == AR_REQ_START); // 主方读请求地址有效，等待从方发送代表准备好接收地址传输的 arready 信号。
    
    /* --------------------- 读响应处理 ------------------------*/
    always @(posedge aclk) begin
		if(areset) begin
			ar_wait_resp_cnt <= 2'b0;
        end
		else if(arvalid && arready && rvalid && rready) begin // 读请求和读数据通道同时完成握手，请求得到响应
			ar_wait_resp_cnt <= ar_wait_resp_cnt;
        end		
		else if(arvalid && arready) begin // 读请求握手
			ar_wait_resp_cnt <= ar_wait_resp_cnt + 1'b1;
        end
		else if(rvalid && rready) begin // 读响应握手
			ar_wait_resp_cnt <= ar_wait_resp_cnt - 1'b1;
        end
	end

	assign rready = (r_current_state == R_DATA_START); // 主方准备好接收数据传输，等待从方发送代表读请求数据有效的 rvalid 信号
    
    /* --------------------- 写请求处理 ------------------------*/
    reg [31:0]  awaddr_reg;
    reg [2:0]   awsize_reg;

    always @(posedge aclk) begin
        if (areset) begin
            awaddr_reg <= 32'b0;
			awsize_reg <= 3'b0;
        end
        else if (w_current_state == W_IDLE) begin
            awaddr_reg <= data_sram_wr ? data_sram_addr : inst_sram_addr;
            awsize_reg <= data_sram_wr ? {1'b0, data_sram_size} : {1'b0, inst_sram_size};
        end
    end

    assign awid     = 4'b1;
    assign awaddr   = awaddr_reg;
    assign awlen    = 8'b0;
    assign awsize   = awsize_reg;
    assign awburst  = 2'b01;
    assign awlock   = 1'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    assign awvalid  = (w_current_state == W_REQ_START) | (w_current_state == W_DATA_RESP); // 主方写请求地址有效，等待从方发送代表准备好接收地址传输的 \verb|awready| 信号

    /* --------------------- 写数据处理 ------------------------*/
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;

    always @(posedge aclk) begin
        if (areset) begin
            wstrb_reg <= 4'b0;
            wdata_reg <= 32'b0;
        end
        else if (w_current_state == W_IDLE) begin
            wstrb_reg <= data_sram_wstrb;
            wdata_reg <= data_sram_wdata;
        end
    end

    assign wid      = 4'b1;
    assign wdata    = wdata_reg;
    assign wstrb    = wstrb_reg;
    assign wlast    = 1'b1;
    assign wvalid   = (w_current_state == W_REQ_START) | (w_current_state == W_ADDR_RESP); // 主方写请求数据有效，等待从方发送代表准备好接收数据传输的 wready 信号

    /* --------------------- 写响应处理 ------------------------*/
    always @(posedge aclk) begin
		if(areset) begin
			aw_wait_resp_cnt <= 2'b0;
		end
        else if(awvalid && awready && bvalid && bready) begin
            aw_wait_resp_cnt <= aw_wait_resp_cnt;
        end
		else if(awvalid && awready) begin// 写请求地址握手，计数器加一
			aw_wait_resp_cnt <= aw_wait_resp_cnt + 1'b1;
        end
		else if(bvalid && bready) begin// 写响应握手，计数器减一
			aw_wait_resp_cnt <= aw_wait_resp_cnt - 1'b1;
        end
	end

	always @(posedge aclk) begin
		if(areset) begin
			wd_wait_resp_cnt <= 2'b0;
		end
        else if(wvalid && wready && bvalid && bready) begin
            wd_wait_resp_cnt <= wd_wait_resp_cnt;
        end
		else if(wvalid && wready) begin // 写请求数据握手，计数器加一
			wd_wait_resp_cnt <= wd_wait_resp_cnt + 1'b1;
        end
		else if(bvalid && bready) begin // 写响应握手，计数器减一
			wd_wait_resp_cnt <= wd_wait_resp_cnt - 1'b1;
		end
	end

    assign bready = (w_current_state == W_REQ_END); // 主方准备好接收写响应，等待从方发送代表写请求响应有效的 bvalid 信号。

    /* --------------------- 传给cpu（rdata 缓冲区）------------------------*/
    reg [31:0] inst_sram_rdata_reg;
    reg [31:0] data_sram_rdata_reg;
    reg [3:0] rid_reg;

    always @(posedge aclk) begin
        if (areset) begin
            inst_sram_rdata_reg <= 32'b0;
            data_sram_rdata_reg <= 32'b0;
            rid_reg <= 4'b0;
        end
        else if (rvalid && rready) begin
            inst_sram_rdata_reg <= rdata & {32{~rid[0]}}; // 读请求读出的数据
            data_sram_rdata_reg <= rdata & {32{rid[0]}};
            rid_reg <= rid;
        end
    end

    assign inst_sram_rdata = inst_sram_rdata_reg;
    assign data_sram_rdata = data_sram_rdata_reg;

    assign inst_sram_addr_ok = (~arid[0] && arvalid && arready);
    assign data_sram_addr_ok = (arid[0] && arvalid && arready) | (wid[0] && awvalid && awready);
    assign inst_sram_data_ok = (~rid_reg[0] && (r_current_state == R_DATA_END)) | (~bid[0] && bvalid && bready);
    assign data_sram_data_ok = (rid_reg[0] && (r_current_state == R_DATA_END)) | (bid[0] && bvalid && bready);
endmodule