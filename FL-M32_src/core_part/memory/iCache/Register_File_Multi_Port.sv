/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Register_File_Multi_Port.
 *  Description:        instr cache of timelyRV core.
 *  Last updated date:  2023.12.06.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2023 NUDT.
 *
 *  Noted:
 */

      
module Register_File_Multi_Port 
#(
    parameter ADDR_WIDTH        = 4,
    parameter DATA_WIDTH        = 44,
    parameter N_READ            = 4,
    parameter N_WAY             = 4
)
(
  //* clk & reset;
  input   wire                                          i_clk,
  input   wire                                          i_rst_n,

  input   wire  [N_READ-1:0]                            i_ReadEnable,
  input   wire  [N_READ-1:0][ADDR_WIDTH-1:0]            i_ReadAddr,
  output  wire  [N_READ-1:0][N_WAY-1:0][DATA_WIDTH-1:0] o_ReadData,

  input   wire  [N_WAY-1:0]                             i_WriteEnable,
  input   wire  [ADDR_WIDTH-1:0]                        i_WriteAddr,
  input   wire  [DATA_WIDTH-1:0]                        i_WriteData
);

  localparam DATA_WORDS = 2**ADDR_WIDTH;

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  reg   [DATA_WORDS-1:0][N_WAY-1:0][DATA_WIDTH-1:0]     reg_data;
  wire  [DATA_WORDS-1:0][N_WAY-1:0]                     we_dec;
  
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  genvar idx_read, idx_way;
  generate
    for (idx_read = 0; idx_read < N_READ; idx_read=idx_read+1) begin
      for (idx_way = 0; idx_way < N_WAY; idx_way=idx_way+1) begin
        assign o_ReadData[idx_read][idx_way] = reg_data[i_ReadAddr[idx_read]][idx_way];
      end
    end
  endgenerate 

  integer i_way, i_word;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      reg_data          <= 'b0;
    end else begin
      for (i_word=0; i_word < DATA_WORDS; i_word=i_word+1) begin
        for(i_way=0; i_way < N_WAY; i_way=i_way+1) begin
          if (we_dec[i_word][i_way] == 1'b1 ) reg_data[i_word][i_way] <= i_WriteData;
        end
      end
    end
  end

  genvar gidx;
  generate
    for (gidx = 0; gidx < DATA_WORDS; gidx=gidx+1) begin : gen_we_decoder_icache
      assign we_dec[gidx] = (i_WriteAddr == gidx) ? i_WriteEnable : 'b0;
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule