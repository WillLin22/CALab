//寄存器号
`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
`define CSR_ECFG 14'h4
`define CSR_ESTAT 14'h5
`define CSR_ERA 14'h6
`define CSR_BADV 14'h7
`define CSR_EENTRY 14'hc
`define CSR_TLBIDX 14'h10
`define CSR_TLBEHI 14'h11
`define CSR_TLBELO0 14'h12
`define CSR_TLBELO1 14'h13
`define CSR_ASID    14'h18
`define CSR_SAVE0 14'h30
`define CSR_SAVE1 14'h31
`define CSR_SAVE2 14'h32
`define CSR_SAVE3 14'h33
`define CSR_TID 14'h40
`define CSR_TCFG 14'h41
`define CSR_TVAL 14'h42
`define CSR_TICLR 14'h44
`define CSR_STABLE_COUNTER_HI 14'h45
`define CSR_STABLE_COUNTER_LO 14'h46
`define CSR_TLBRENTRY 14'h88


//CSR分区
//CSR_CRMD
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_PIE 2:2
`define CSR_CRMD_DA 3:3
`define CSR_CRMD_PG 4:4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7
`define CSR_CRMD_ZERO 31:9

//CSR_PRMD
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2:2
`define CSR_PRMD_ZERO 31:3

//CSR_ESTAT
`define CSR_ESTAT_IS10  1 :0    
`define CSR_ESTAT_IS_HARD 9:2   
`define CSR_ESTAT_IS_LEFT1 10    
`define CSR_ESTAT_IS_TI 11       
`define CSR_ESTAT_IS_IPI 12       
`define CSR_ESTAT_LEFT2 15:13  
`define CSR_ESTAT_ECODE 21:16  
`define CSR_ESTAT_ESUBCODE 30:22 
`define CSR_ESTAT_ZERO 31  

//CSR_ERA
`define CSR_ERA_PC 31:0

//CSR_EENTRY
`define CSR_EENTRY_ZERO 5:0
`define CSR_EENTRY_VA 31:6

//CSR_SAVR0-3
`define CSR_SAVE_DATA 31:0

//CSR_BADV
`define CSR_BADV_VADDR 31:0

//CSR_ECFG
`define CSR_ECFG_LIE 12:0
`define CSR_ECFG_ZERO 31:13

//CSR_TID
`define CSR_TID_TID 31:0

//CSR_TCFG
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

//CSR_TICLR
`define CSR_TICLR_CLR 0
`define CSR_TICLR_ZERO 31:1


//ECODE
`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2
`define ECODE_PIF 6'h3
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hB
`define ECODE_BRK 6'hC
`define ECODE_INE 6'hD
`define ECODE_IPE 6'hE
`define ECODE_FPD 6'hF 
`define ECODE_FPE 6'h12
`define ECODE_TLBR 6'h3F

//ESUBCODE
`define ESUBCODE_ADEF 9'h0
`define ESUBCODE_ADEM 9'h1

//TLBIDX
`define TLBIDX_IDX 3:0
`define TLBIDX_PS  29:24
`define TLBIDX_NE  31

//TLBEHI
`define TLBEHI_VPPN 31:13

//TLBELO
`define TLBELO_PPN 27:8
`define TLBELO_G 6
`define TLBELO_MAT 5:4
`define TLBELO_PLV 3:2
`define TLBELO_D 1
`define TLBELO_V 0

//ASID
`define ASID_ASID 9:0
`define ASID_BITS 23:16

//TLBRENTRY
`define TLBRENTRY_PA 31:6

// DMW0-1
`define CSR_DMW0 14'h180  // EXP19
`define CSR_DMW1 14'h181  // EXP19

`define DMW_PLV0 0
`define DMW_PLV1 1
`define DMW_PLV2 2
`define DMW_PLV3 3
`define DMW_MAT 5:4
`define DMW_PSEG 27:25
`define DMW_VSEG 31:29