module tlb
#(
    parameter TLBNUM = 16
)
(
    input  wire                         clk,
    input  wire                         rst,
    //searchport 0(forfetch)
    input  wire [18:0]                  s0_vppn,
    input  wire                         s0_va_bit12,
    input  wire [ 9:0]                  s0_asid,
    output wire                         s0_found,
    output wire [$clog2(TLBNUM)-1:0]    s0_index,
    output wire [19:0]                  s0_ppn,
    output wire [ 5:0]                  s0_ps,
    output wire [ 1:0]                  s0_plv,
    output wire [ 1:0]                  s0_mat,
    output wire                         s0_d,
    output wire                         s0_v,
    //searchport 1(forload/store)
    input  wire [18:0]                  s1_vppn,
    input  wire                         s1_va_bit12,
    input  wire [ 9:0]                  s1_asid,
    output wire                         s1_found,
    output wire [$clog2(TLBNUM)-1:0]    s1_index,
    output wire [19:0]                  s1_ppn,
    output wire [ 5:0]                  s1_ps,
    output wire [ 1:0]                  s1_plv,
    output wire [ 1:0]                  s1_mat,
    output wire                         s1_d,
    output wire                         s1_v,
    //invtlbopcode
    input  wire                         invtlb_valid,
    input  wire [ 4:0]                  invtlb_op,
    input  wire [ 9:0]                  invtlb_asid, 
    input  wire [18:0]                  invtlb_va,
    //writeport
    input  wire                         we, //w(rite)e(nable)
    input  wire  [$clog2(TLBNUM)-1:0]   w_index,
    input  wire                         w_e,
    input  wire [18:0]                  w_vppn,
    input  wire [ 5:0]                  w_ps,
    input  wire [ 9:0]                  w_asid,
    input  wire                         w_g,
    input  wire [19:0]                  w_ppn0,
    input  wire [ 1:0]                  w_plv0,
    input  wire [ 1:0]                  w_mat0, 
    input  wire                         w_d0,
    input  wire                         w_v0,
    input  wire [19:0]                  w_ppn1,
    input  wire [ 1:0]                  w_plv1,
    input  wire [ 1:0]                  w_mat1,
    input  wire                         w_d1,
    input  wire                         w_v1,
    //read port
    input  wire [$clog2(TLBNUM)-1:0]    r_index,
    output wire                         r_e,
    output wire [18:0]                  r_vppn,
    output wire [ 5:0]                  r_ps,
    output wire [ 9:0]                  r_asid,
    output wire                         r_g,
    output wire [19:0]                  r_ppn0,
    output wire [ 1:0]                  r_plv0,
    output wire [ 1:0]                  r_mat0,
    output wire                         r_d0,
    output wire                         r_v0,
    output wire [19:0]                  r_ppn1,
    output wire [ 1:0]                  r_plv1,
    output wire [ 1:0]                  r_mat1,
    output wire                         r_d1,
    output wire                         r_v1,
    // ports for tlb_srch
    input wire  [18:0]                  tlbsrch_vppn,
    input wire  [ 9:0]                  tlbsrch_asid,
    output wire                         tlbsrch_found,
    output wire [$clog2(TLBNUM)-1:0]    tlbsrch_index
);
/* 
invop:
0, 1:clear all
10: clear G==1
11: clear G==0
100:clear G==0&&asid == asid
101:clear G==0&&(asid == asid&&VA==VA)
110:clear G==1||(asid == asid&&VA==VA)
 */

reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB;
reg [18:0]       tlb_vppn   [TLBNUM-1:0];
reg [ 9:0]       tlb_asid   [TLBNUM-1:0];
reg              tlb_g      [TLBNUM-1:0];
reg [19:0]       tlb_ppn0   [TLBNUM-1:0];
reg [ 1:0]       tlb_plv0   [TLBNUM-1:0];
reg [ 1:0]       tlb_mat0   [TLBNUM-1:0];
reg [TLBNUM-1:0]            tlb_d0     ;
reg [TLBNUM-1:0]             tlb_v0     ;
reg [19:0]       tlb_ppn1   [TLBNUM-1:0];
reg [ 1:0]       tlb_plv1   [TLBNUM-1:0];
reg [ 1:0]       tlb_mat1   [TLBNUM-1:0];
reg [TLBNUM-1:0]             tlb_d1     ;
reg [TLBNUM-1:0]             tlb_v1     ;
//search
wire [TLBNUM-1:0] s0_mtch, s1_mtch, tlbsrch_mtch;
wire s0_error, s1_error, srch_error;
wire match_error = s0_found&s0_error|s1_found&s1_error|tlbsrch_found&srch_error;
tlb_search_match s0
(
    .s_vppn(s0_vppn),
    .s_asid(s0_asid),
    .tlb_e_0(tlb_e[0]),
    .tlb_e_1(tlb_e[1]),
    .tlb_e_2(tlb_e[2]),
    .tlb_e_3(tlb_e[3]),
    .tlb_e_4(tlb_e[4]),
    .tlb_e_5(tlb_e[5]),
    .tlb_e_6(tlb_e[6]),
    .tlb_e_7(tlb_e[7]),
    .tlb_e_8(tlb_e[8]),
    .tlb_e_9(tlb_e[9]),
    .tlb_e_10(tlb_e[10]),
    .tlb_e_11(tlb_e[11]),
    .tlb_e_12(tlb_e[12]),
    .tlb_e_13(tlb_e[13]),
    .tlb_e_14(tlb_e[14]),
    .tlb_e_15(tlb_e[15]),
    .tlb_vppn_0(tlb_vppn[0]),
    .tlb_vppn_1(tlb_vppn[1]),
    .tlb_vppn_2(tlb_vppn[2]),
    .tlb_vppn_3(tlb_vppn[3]),
    .tlb_vppn_4(tlb_vppn[4]),
    .tlb_vppn_5(tlb_vppn[5]),
    .tlb_vppn_6(tlb_vppn[6]),
    .tlb_vppn_7(tlb_vppn[7]),
    .tlb_vppn_8(tlb_vppn[8]),
    .tlb_vppn_9(tlb_vppn[9]),
    .tlb_vppn_10(tlb_vppn[10]),
    .tlb_vppn_11(tlb_vppn[11]),
    .tlb_vppn_12(tlb_vppn[12]),
    .tlb_vppn_13(tlb_vppn[13]),
    .tlb_vppn_14(tlb_vppn[14]),
    .tlb_vppn_15(tlb_vppn[15]),
    .tlb_ps4MB_0(tlb_ps4MB[0]),
    .tlb_ps4MB_1(tlb_ps4MB[1]),
    .tlb_ps4MB_2(tlb_ps4MB[2]),
    .tlb_ps4MB_3(tlb_ps4MB[3]),
    .tlb_ps4MB_4(tlb_ps4MB[4]),
    .tlb_ps4MB_5(tlb_ps4MB[5]),
    .tlb_ps4MB_6(tlb_ps4MB[6]),
    .tlb_ps4MB_7(tlb_ps4MB[7]),
    .tlb_ps4MB_8(tlb_ps4MB[8]),
    .tlb_ps4MB_9(tlb_ps4MB[9]),
    .tlb_ps4MB_10(tlb_ps4MB[10]),
    .tlb_ps4MB_11(tlb_ps4MB[11]),
    .tlb_ps4MB_12(tlb_ps4MB[12]),
    .tlb_ps4MB_13(tlb_ps4MB[13]),
    .tlb_ps4MB_14(tlb_ps4MB[14]),
    .tlb_ps4MB_15(tlb_ps4MB[15]),
    .tlb_asid_0(tlb_asid[0]),
    .tlb_asid_1(tlb_asid[1]),
    .tlb_asid_2(tlb_asid[2]),
    .tlb_asid_3(tlb_asid[3]),
    .tlb_asid_4(tlb_asid[4]),
    .tlb_asid_5(tlb_asid[5]),
    .tlb_asid_6(tlb_asid[6]),
    .tlb_asid_7(tlb_asid[7]),
    .tlb_asid_8(tlb_asid[8]),
    .tlb_asid_9(tlb_asid[9]),
    .tlb_asid_10(tlb_asid[10]),
    .tlb_asid_11(tlb_asid[11]),
    .tlb_asid_12(tlb_asid[12]),
    .tlb_asid_13(tlb_asid[13]),
    .tlb_asid_14(tlb_asid[14]),
    .tlb_asid_15(tlb_asid[15]),
    .tlb_g_0(tlb_g[0]),
    .tlb_g_1(tlb_g[1]),
    .tlb_g_2(tlb_g[2]),
    .tlb_g_3(tlb_g[3]),
    .tlb_g_4(tlb_g[4]),
    .tlb_g_5(tlb_g[5]),
    .tlb_g_6(tlb_g[6]),
    .tlb_g_7(tlb_g[7]),
    .tlb_g_8(tlb_g[8]),
    .tlb_g_9(tlb_g[9]),
    .tlb_g_10(tlb_g[10]),
    .tlb_g_11(tlb_g[11]),
    .tlb_g_12(tlb_g[12]),
    .tlb_g_13(tlb_g[13]),
    .tlb_g_14(tlb_g[14]),
    .tlb_g_15(tlb_g[15]),
    .match(s0_found),
    .index(s0_index),
    .mtch(s0_mtch)
);
encoder_16_check s0_check
(
    .in(s0_mtch),
    .error(s0_error)
);
tlb_search_match s1
(
    .s_vppn(s1_vppn),
    .s_asid(s1_asid),
    .tlb_e_0(tlb_e[0]),
    .tlb_e_1(tlb_e[1]),
    .tlb_e_2(tlb_e[2]),
    .tlb_e_3(tlb_e[3]),
    .tlb_e_4(tlb_e[4]),
    .tlb_e_5(tlb_e[5]),
    .tlb_e_6(tlb_e[6]),
    .tlb_e_7(tlb_e[7]),
    .tlb_e_8(tlb_e[8]),
    .tlb_e_9(tlb_e[9]),
    .tlb_e_10(tlb_e[10]),
    .tlb_e_11(tlb_e[11]),
    .tlb_e_12(tlb_e[12]),
    .tlb_e_13(tlb_e[13]),
    .tlb_e_14(tlb_e[14]),
    .tlb_e_15(tlb_e[15]),
    .tlb_vppn_0(tlb_vppn[0]),
    .tlb_vppn_1(tlb_vppn[1]),
    .tlb_vppn_2(tlb_vppn[2]),
    .tlb_vppn_3(tlb_vppn[3]),
    .tlb_vppn_4(tlb_vppn[4]),
    .tlb_vppn_5(tlb_vppn[5]),
    .tlb_vppn_6(tlb_vppn[6]),
    .tlb_vppn_7(tlb_vppn[7]),
    .tlb_vppn_8(tlb_vppn[8]),
    .tlb_vppn_9(tlb_vppn[9]),
    .tlb_vppn_10(tlb_vppn[10]),
    .tlb_vppn_11(tlb_vppn[11]),
    .tlb_vppn_12(tlb_vppn[12]),
    .tlb_vppn_13(tlb_vppn[13]),
    .tlb_vppn_14(tlb_vppn[14]),
    .tlb_vppn_15(tlb_vppn[15]),
    .tlb_ps4MB_0(tlb_ps4MB[0]),
    .tlb_ps4MB_1(tlb_ps4MB[1]),
    .tlb_ps4MB_2(tlb_ps4MB[2]),
    .tlb_ps4MB_3(tlb_ps4MB[3]),
    .tlb_ps4MB_4(tlb_ps4MB[4]),
    .tlb_ps4MB_5(tlb_ps4MB[5]),
    .tlb_ps4MB_6(tlb_ps4MB[6]),
    .tlb_ps4MB_7(tlb_ps4MB[7]),
    .tlb_ps4MB_8(tlb_ps4MB[8]),
    .tlb_ps4MB_9(tlb_ps4MB[9]),
    .tlb_ps4MB_10(tlb_ps4MB[10]),
    .tlb_ps4MB_11(tlb_ps4MB[11]),
    .tlb_ps4MB_12(tlb_ps4MB[12]),
    .tlb_ps4MB_13(tlb_ps4MB[13]),
    .tlb_ps4MB_14(tlb_ps4MB[14]),
    .tlb_ps4MB_15(tlb_ps4MB[15]),
    .tlb_asid_0(tlb_asid[0]),
    .tlb_asid_1(tlb_asid[1]),
    .tlb_asid_2(tlb_asid[2]),
    .tlb_asid_3(tlb_asid[3]),
    .tlb_asid_4(tlb_asid[4]),
    .tlb_asid_5(tlb_asid[5]),
    .tlb_asid_6(tlb_asid[6]),
    .tlb_asid_7(tlb_asid[7]),
    .tlb_asid_8(tlb_asid[8]),
    .tlb_asid_9(tlb_asid[9]),
    .tlb_asid_10(tlb_asid[10]),
    .tlb_asid_11(tlb_asid[11]),
    .tlb_asid_12(tlb_asid[12]),
    .tlb_asid_13(tlb_asid[13]),
    .tlb_asid_14(tlb_asid[14]),
    .tlb_asid_15(tlb_asid[15]),
    .tlb_g_0(tlb_g[0]),
    .tlb_g_1(tlb_g[1]),
    .tlb_g_2(tlb_g[2]),
    .tlb_g_3(tlb_g[3]),
    .tlb_g_4(tlb_g[4]),
    .tlb_g_5(tlb_g[5]),
    .tlb_g_6(tlb_g[6]),
    .tlb_g_7(tlb_g[7]),
    .tlb_g_8(tlb_g[8]),
    .tlb_g_9(tlb_g[9]),
    .tlb_g_10(tlb_g[10]),
    .tlb_g_11(tlb_g[11]),
    .tlb_g_12(tlb_g[12]),
    .tlb_g_13(tlb_g[13]),
    .tlb_g_14(tlb_g[14]),
    .tlb_g_15(tlb_g[15]),
    .match(s1_found),
    .index(s1_index),
    .mtch(s1_mtch)
);
encoder_16_check s1_check
(
    .in(s1_mtch),
    .error(s1_error)
);

integer i;
wire s0_odd = (|(tlb_ps4MB&s0_mtch)) ? s0_vppn[8] : s0_va_bit12;
wire s1_odd = (|(tlb_ps4MB&s1_mtch)) ? s1_vppn[8] : s1_va_bit12;

assign s0_ppn = s0_odd ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s1_ppn = s1_odd ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s0_ps  = (|(tlb_ps4MB&s0_mtch)) ?6'd21:6'd12;
assign s1_ps  = (|(tlb_ps4MB&s1_mtch)) ?6'd21:6'd12;
assign s0_plv = s0_odd ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s1_plv = s1_odd ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s0_mat = s0_odd ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s1_mat = s1_odd ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s0_d   = s0_odd ? (|(tlb_d1&s0_mtch)) : (|(tlb_d0&s0_mtch));
assign s1_d   = s1_odd ? (|(tlb_d1&s1_mtch)) : (|(tlb_d0&s1_mtch));
assign s0_v   = s0_odd ? (|(tlb_v1&s0_mtch)) : (|(tlb_v0&s0_mtch));
assign s1_v   = s1_odd ? (|(tlb_v1&s1_mtch)) : (|(tlb_v0&s1_mtch));

//tlbsrch
tlb_search_match tlb_srch
(
    .s_vppn(tlbsrch_vppn),
    .s_asid(tlbsrch_asid),
    .tlb_e_0(tlb_e[0]),
    .tlb_e_1(tlb_e[1]),
    .tlb_e_2(tlb_e[2]),
    .tlb_e_3(tlb_e[3]),
    .tlb_e_4(tlb_e[4]),
    .tlb_e_5(tlb_e[5]),
    .tlb_e_6(tlb_e[6]),
    .tlb_e_7(tlb_e[7]),
    .tlb_e_8(tlb_e[8]),
    .tlb_e_9(tlb_e[9]),
    .tlb_e_10(tlb_e[10]),
    .tlb_e_11(tlb_e[11]),
    .tlb_e_12(tlb_e[12]),
    .tlb_e_13(tlb_e[13]),
    .tlb_e_14(tlb_e[14]),
    .tlb_e_15(tlb_e[15]),
    .tlb_vppn_0(tlb_vppn[0]),
    .tlb_vppn_1(tlb_vppn[1]),
    .tlb_vppn_2(tlb_vppn[2]),
    .tlb_vppn_3(tlb_vppn[3]),
    .tlb_vppn_4(tlb_vppn[4]),
    .tlb_vppn_5(tlb_vppn[5]),
    .tlb_vppn_6(tlb_vppn[6]),
    .tlb_vppn_7(tlb_vppn[7]),
    .tlb_vppn_8(tlb_vppn[8]),
    .tlb_vppn_9(tlb_vppn[9]),
    .tlb_vppn_10(tlb_vppn[10]),
    .tlb_vppn_11(tlb_vppn[11]),
    .tlb_vppn_12(tlb_vppn[12]),
    .tlb_vppn_13(tlb_vppn[13]),
    .tlb_vppn_14(tlb_vppn[14]),
    .tlb_vppn_15(tlb_vppn[15]),
    .tlb_ps4MB_0(tlb_ps4MB[0]),
    .tlb_ps4MB_1(tlb_ps4MB[1]),
    .tlb_ps4MB_2(tlb_ps4MB[2]),
    .tlb_ps4MB_3(tlb_ps4MB[3]),
    .tlb_ps4MB_4(tlb_ps4MB[4]),
    .tlb_ps4MB_5(tlb_ps4MB[5]),
    .tlb_ps4MB_6(tlb_ps4MB[6]),
    .tlb_ps4MB_7(tlb_ps4MB[7]),
    .tlb_ps4MB_8(tlb_ps4MB[8]),
    .tlb_ps4MB_9(tlb_ps4MB[9]),
    .tlb_ps4MB_10(tlb_ps4MB[10]),
    .tlb_ps4MB_11(tlb_ps4MB[11]),
    .tlb_ps4MB_12(tlb_ps4MB[12]),
    .tlb_ps4MB_13(tlb_ps4MB[13]),
    .tlb_ps4MB_14(tlb_ps4MB[14]),
    .tlb_ps4MB_15(tlb_ps4MB[15]),
    .tlb_asid_0(tlb_asid[0]),
    .tlb_asid_1(tlb_asid[1]),
    .tlb_asid_2(tlb_asid[2]),
    .tlb_asid_3(tlb_asid[3]),
    .tlb_asid_4(tlb_asid[4]),
    .tlb_asid_5(tlb_asid[5]),
    .tlb_asid_6(tlb_asid[6]),
    .tlb_asid_7(tlb_asid[7]),
    .tlb_asid_8(tlb_asid[8]),
    .tlb_asid_9(tlb_asid[9]),
    .tlb_asid_10(tlb_asid[10]),
    .tlb_asid_11(tlb_asid[11]),
    .tlb_asid_12(tlb_asid[12]),
    .tlb_asid_13(tlb_asid[13]),
    .tlb_asid_14(tlb_asid[14]),
    .tlb_asid_15(tlb_asid[15]),
    .tlb_g_0(tlb_g[0]),
    .tlb_g_1(tlb_g[1]),
    .tlb_g_2(tlb_g[2]),
    .tlb_g_3(tlb_g[3]),
    .tlb_g_4(tlb_g[4]),
    .tlb_g_5(tlb_g[5]),
    .tlb_g_6(tlb_g[6]),
    .tlb_g_7(tlb_g[7]),
    .tlb_g_8(tlb_g[8]),
    .tlb_g_9(tlb_g[9]),
    .tlb_g_10(tlb_g[10]),
    .tlb_g_11(tlb_g[11]),
    .tlb_g_12(tlb_g[12]),
    .tlb_g_13(tlb_g[13]),
    .tlb_g_14(tlb_g[14]),
    .tlb_g_15(tlb_g[15]),
    .match(tlbsrch_found),
    .index(tlbsrch_index),
    .mtch(tlbsrch_mtch)
);
encoder_16_check tlbsrch_check
(
    .in(tlbsrch_mtch),
    .error(srch_error)
);


//invtlb
always @(posedge clk) begin
    if(rst) begin
        for(i=0;i<TLBNUM;i=i+1)begin
            tlb_e[i] <= 1'b0;
        end
    end
    else if(invtlb_valid)begin
        case(invtlb_op)
            5'b00000:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    tlb_e[i] <= 1'b0;
                end
            end
            5'b00001:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    tlb_e[i] <= 1'b0;
                end
            end
            5'b00010:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    if(tlb_g[i])begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
            5'b00011:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    if(!tlb_g[i])begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
            5'b00100:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    if(!tlb_g[i]&&tlb_asid[i]==invtlb_asid)begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
            5'b00101:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    if(!tlb_g[i]&&tlb_asid[i]==invtlb_asid&&tlb_vppn[i]==invtlb_va)begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
            5'b00110:begin
                for(i=0;i<TLBNUM;i=i+1)begin
                    if((tlb_g[i]||tlb_asid[i]==invtlb_asid)&&tlb_vppn[i]==invtlb_va)begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
        endcase
    end
    else if(we)
        tlb_e[w_index] <= w_e;
end
//write
always @(posedge clk) begin
    if (rst) begin
         for(i=0;i<TLBNUM;i=i+1)begin
            tlb_ps4MB[i] <= 1'b0;
            tlb_vppn[i] <= 18'd0;
            tlb_asid[i] <= 10'd0;
            tlb_g[i] <= 1'b0;
            tlb_ppn0[i] <= 18'd0;
            tlb_plv0[i] <= 6'd0;
            tlb_mat0[i] <= 6'd0;
            tlb_d0[i] <= 1'b0;
            tlb_v0[i] <= 1'b0;
            tlb_ppn1[i] <= 18'd0;
            tlb_plv1[i] <= 6'd0;
            tlb_mat1[i] <= 6'd0;
            tlb_d1[i] <= 1'b0;
            tlb_v1[i] <= 1'b0;
        end
    end
    else if(we)begin
        tlb_ps4MB[w_index] <= w_ps==6'd21;
        tlb_vppn[w_index] <= w_vppn;
        tlb_asid[w_index] <= w_asid;
        tlb_g[w_index] <= w_g;
        tlb_ppn0[w_index] <= w_ppn0;
        tlb_plv0[w_index] <= w_plv0;
        tlb_mat0[w_index] <= w_mat0;
        tlb_d0[w_index] <= w_d0;
        tlb_v0[w_index] <= w_v0;
        tlb_ppn1[w_index] <= w_ppn1;
        tlb_plv1[w_index] <= w_plv1;
        tlb_mat1[w_index] <= w_mat1;
        tlb_d1[w_index] <= w_d1;
        tlb_v1[w_index] <= w_v1;
    end
end
//read
assign r_e = tlb_e[r_index];
assign r_vppn = tlb_vppn[r_index];
assign r_ps = tlb_ps4MB[r_index]?6'd21:6'd12;
assign r_asid = tlb_asid[r_index];
assign r_g = tlb_g[r_index];
assign r_ppn0 = tlb_ppn0[r_index];
assign r_plv0 = tlb_plv0[r_index];
assign r_mat0 = tlb_mat0[r_index];
assign r_d0 = tlb_d0[r_index];
assign r_v0 = tlb_v0[r_index];
assign r_ppn1 = tlb_ppn1[r_index];
assign r_plv1 = tlb_plv1[r_index];
assign r_mat1 = tlb_mat1[r_index];
assign r_d1 = tlb_d1[r_index];
assign r_v1 = tlb_v1[r_index];



endmodule
//将匹配index逻辑单独抽象成一个模块，因为传参无法传array所以只能以这么冗长的形式进行定义。
module tlb_search_match
#(
    parameter TLBNUM = 16
)
(
    input  wire [18:0] s_vppn,
    input  wire [ 9:0] s_asid,
    input  wire tlb_e_0,
    input  wire tlb_e_1,
    input  wire tlb_e_2,
    input  wire tlb_e_3,
    input  wire tlb_e_4,
    input  wire tlb_e_5,
    input  wire tlb_e_6,
    input  wire tlb_e_7,
    input  wire tlb_e_8,
    input  wire tlb_e_9,
    input  wire tlb_e_10,
    input  wire tlb_e_11,
    input  wire tlb_e_12,
    input  wire tlb_e_13,
    input  wire tlb_e_14,
    input  wire tlb_e_15,
    input  wire [18:0] tlb_vppn_0,
    input  wire [18:0] tlb_vppn_1,
    input  wire [18:0] tlb_vppn_2,
    input  wire [18:0] tlb_vppn_3,
    input  wire [18:0] tlb_vppn_4,
    input  wire [18:0] tlb_vppn_5,
    input  wire [18:0] tlb_vppn_6,
    input  wire [18:0] tlb_vppn_7,
    input  wire [18:0] tlb_vppn_8,
    input  wire [18:0] tlb_vppn_9,
    input  wire [18:0] tlb_vppn_10,
    input  wire [18:0] tlb_vppn_11,
    input  wire [18:0] tlb_vppn_12,
    input  wire [18:0] tlb_vppn_13,
    input  wire [18:0] tlb_vppn_14,
    input  wire [18:0] tlb_vppn_15,
    input  wire        tlb_ps4MB_0,
    input  wire        tlb_ps4MB_1,
    input  wire        tlb_ps4MB_2,
    input  wire        tlb_ps4MB_3,
    input  wire        tlb_ps4MB_4,
    input  wire        tlb_ps4MB_5,
    input  wire        tlb_ps4MB_6,
    input  wire        tlb_ps4MB_7,
    input  wire        tlb_ps4MB_8,
    input  wire        tlb_ps4MB_9,
    input  wire        tlb_ps4MB_10,
    input  wire        tlb_ps4MB_11,
    input  wire        tlb_ps4MB_12,
    input  wire        tlb_ps4MB_13,
    input  wire        tlb_ps4MB_14,
    input  wire        tlb_ps4MB_15,
    input  wire [ 9:0] tlb_asid_0,
    input  wire [ 9:0] tlb_asid_1,
    input  wire [ 9:0] tlb_asid_2,
    input  wire [ 9:0] tlb_asid_3,
    input  wire [ 9:0] tlb_asid_4,
    input  wire [ 9:0] tlb_asid_5,
    input  wire [ 9:0] tlb_asid_6,
    input  wire [ 9:0] tlb_asid_7,
    input  wire [ 9:0] tlb_asid_8,
    input  wire [ 9:0] tlb_asid_9,
    input  wire [ 9:0] tlb_asid_10,
    input  wire [ 9:0] tlb_asid_11,
    input  wire [ 9:0] tlb_asid_12,
    input  wire [ 9:0] tlb_asid_13,
    input  wire [ 9:0] tlb_asid_14,
    input  wire [ 9:0] tlb_asid_15,
    input  wire        tlb_g_0,
    input  wire        tlb_g_1,
    input  wire        tlb_g_2,
    input  wire        tlb_g_3,
    input  wire        tlb_g_4,
    input  wire        tlb_g_5,
    input  wire        tlb_g_6,
    input  wire        tlb_g_7,
    input  wire        tlb_g_8,
    input  wire        tlb_g_9,
    input  wire        tlb_g_10,
    input  wire        tlb_g_11,
    input  wire        tlb_g_12,
    input  wire        tlb_g_13,
    input  wire        tlb_g_14,
    input  wire        tlb_g_15,
    output wire match,
    output wire [$clog2(TLBNUM)-1:0] index,
    output wire [TLBNUM-1:0] mtch
);
assign match = |mtch;
encoder_16_4 e(.in(mtch), .out(index));

assign mtch[0] = (s_vppn[18:9] == tlb_vppn_0[18:9]) && (tlb_ps4MB_0 || s_vppn[8:0] == tlb_vppn_0[8:0]) && (s_asid == tlb_asid_0 || tlb_g_0) && tlb_e_0;
assign mtch[1] = (s_vppn[18:9] == tlb_vppn_1[18:9]) && (tlb_ps4MB_1 || s_vppn[8:0] == tlb_vppn_1[8:0]) && (s_asid == tlb_asid_1 || tlb_g_1) && tlb_e_1;
assign mtch[2] = (s_vppn[18:9] == tlb_vppn_2[18:9]) && (tlb_ps4MB_2 || s_vppn[8:0] == tlb_vppn_2[8:0]) && (s_asid == tlb_asid_2 || tlb_g_2) && tlb_e_2;
assign mtch[3] = (s_vppn[18:9] == tlb_vppn_3[18:9]) && (tlb_ps4MB_3 || s_vppn[8:0] == tlb_vppn_3[8:0]) && (s_asid == tlb_asid_3 || tlb_g_3) && tlb_e_3;
assign mtch[4] = (s_vppn[18:9] == tlb_vppn_4[18:9]) && (tlb_ps4MB_4 || s_vppn[8:0] == tlb_vppn_4[8:0]) && (s_asid == tlb_asid_4 || tlb_g_4) && tlb_e_4;
assign mtch[5] = (s_vppn[18:9] == tlb_vppn_5[18:9]) && (tlb_ps4MB_5 || s_vppn[8:0] == tlb_vppn_5[8:0]) && (s_asid == tlb_asid_5 || tlb_g_5) && tlb_e_5;
assign mtch[6] = (s_vppn[18:9] == tlb_vppn_6[18:9]) && (tlb_ps4MB_6 || s_vppn[8:0] == tlb_vppn_6[8:0]) && (s_asid == tlb_asid_6 || tlb_g_6) && tlb_e_6;
assign mtch[7] = (s_vppn[18:9] == tlb_vppn_7[18:9]) && (tlb_ps4MB_7 || s_vppn[8:0] == tlb_vppn_7[8:0]) && (s_asid == tlb_asid_7 || tlb_g_7) && tlb_e_7;
assign mtch[8] = (s_vppn[18:9] == tlb_vppn_8[18:9]) && (tlb_ps4MB_8 || s_vppn[8:0] == tlb_vppn_8[8:0]) && (s_asid == tlb_asid_8 || tlb_g_8) && tlb_e_8;
assign mtch[9] = (s_vppn[18:9] == tlb_vppn_9[18:9]) && (tlb_ps4MB_9 || s_vppn[8:0] == tlb_vppn_9[8:0]) && (s_asid == tlb_asid_9 || tlb_g_9) && tlb_e_9;
assign mtch[10] = (s_vppn[18:9] == tlb_vppn_10[18:9]) && (tlb_ps4MB_10 || s_vppn[8:0] == tlb_vppn_10[8:0]) && (s_asid == tlb_asid_10 || tlb_g_10) && tlb_e_10;
assign mtch[11] = (s_vppn[18:9] == tlb_vppn_11[18:9]) && (tlb_ps4MB_11 || s_vppn[8:0] == tlb_vppn_11[8:0]) && (s_asid == tlb_asid_11 || tlb_g_11) && tlb_e_11;
assign mtch[12] = (s_vppn[18:9] == tlb_vppn_12[18:9]) && (tlb_ps4MB_12 || s_vppn[8:0] == tlb_vppn_12[8:0]) && (s_asid == tlb_asid_12 || tlb_g_12) && tlb_e_12;
assign mtch[13] = (s_vppn[18:9] == tlb_vppn_13[18:9]) && (tlb_ps4MB_13 || s_vppn[8:0] == tlb_vppn_13[8:0]) && (s_asid == tlb_asid_13 || tlb_g_13) && tlb_e_13;
assign mtch[14] = (s_vppn[18:9] == tlb_vppn_14[18:9]) && (tlb_ps4MB_14 || s_vppn[8:0] == tlb_vppn_14[8:0]) && (s_asid == tlb_asid_14 || tlb_g_14) && tlb_e_14;
assign mtch[15] = (s_vppn[18:9] == tlb_vppn_15[18:9]) && (tlb_ps4MB_15 || s_vppn[8:0] == tlb_vppn_15[8:0]) && (s_asid == tlb_asid_15 || tlb_g_15) && tlb_e_15;

endmodule
//空闲tlb分配算法，该算法只是一个简单的循环，甚至连先入先出都做不到因为它不会在invtlb时检查空闲tlb。
//在exp19中可以对其进行改进
//目前其实例化于cpu_core中
module tlb_idx_alloc
#(
    parameter TLBNUM = 16
)
(
    input  wire rst,
    input  wire clk,
    input  wire tlballoc,
    output wire [$clog2(TLBNUM)-1:0] idx
);
reg [$clog2(TLBNUM)-1:0] cnt;
always @(posedge clk) begin
    if(rst)begin
        cnt <= 4'b0;
    end
    else if(tlballoc)begin
        cnt <= cnt + 1;
    end
end
assign idx = cnt;
endmodule