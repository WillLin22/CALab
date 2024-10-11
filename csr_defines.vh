//寄存器号
`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
`define CSR_ECFG 14'h4
`define CSR_ESTAT 14'h5
`define CSR_ERA 14'h6
`define CSR_BADV 14'h7
`define CSR_EENTRY 14'hc
`define CSR_SAVE0 14'h30
`define CSR_SAVE1 14'h31
`define CSR_SAVE2 14'h32
`define CSR_SAVE3 14'h33
`define CSR_TID 14'h40
`define CSR_TCFG 14'h41
`define CSR_TVAL 14'h42
`define CSR_TICLR 14'h44


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
`define CSR_TCFG_PERIODIC 1
`define CSR_TCFG_INITVAL 31:2

//CSR_TICLR
`define CSR_TICLR_CLR 0
`define CSR_TICLR_ZERO 31:1


//ECODE


//ESUBCODE
