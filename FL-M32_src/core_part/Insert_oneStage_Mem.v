/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Insert_oneStage_Mem.
 *  Description:        Insert one stage before memory.
 *  Last updated date:  2022.06.17. (checked)
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Space = 2
 */

 `timescale 1 ns / 1 ps

module Insert_oneStage_Mem(
   input    wire                    i_clk
  ,input    wire                    i_rst_n
  //* interface with PE;
  ,input    wire  [`NUM_PE*32-1:0]  i_instr_addr
  ,input    wire  [`NUM_PE-1:0]     i_instr_req
  ,input    wire  [`NUM_PE*32-1:0]  i_data_addr
  ,input    wire  [`NUM_PE*32-1:0]  i_data_wdata
  ,input    wire  [`NUM_PE-1:0]     i_data_we
  ,input    wire  [`NUM_PE-1:0]     i_data_req
  ,input    wire  [`NUM_PE*4-1:0]   i_data_be
  //* interface with MEM;
  ,output   reg   [`NUM_PE*32-1:0]  o_instr_addr
  ,output   reg   [`NUM_PE-1:0]     o_instr_req
  ,input    wire  [`NUM_PE-1:0]     i_instr_gnt
  ,output   reg   [`NUM_PE*32-1:0]  o_data_addr
  ,output   reg   [`NUM_PE*32-1:0]  o_data_wdata
  ,output   reg   [`NUM_PE-1:0]     o_data_we
  ,output   reg   [`NUM_PE-1:0]     o_data_req
  ,output   reg   [`NUM_PE*4-1:0]   o_data_be
  ,input    wire  [`NUM_PE-1:0]     i_data_gnt
);

  //====================================================================//
  //*   insert 1 clk
  //====================================================================//
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_instr_addr                  <= 96'b0;
      o_instr_req                   <= 3'b0;
      o_data_addr                   <= 96'b0;
      o_data_we                     <= 3'b0;
      o_data_req                    <= 3'b0;
      o_data_wdata                  <= 96'b0;
      o_data_be                     <= 12'b0;
    end else begin
      //* send next req after receiving gnt;
      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        //* instr;
        if(i_instr_gnt[i_pe] == 1'b1) begin
          o_instr_addr[i_pe*32+:32] <= i_instr_addr[i_pe*32+:32] + 
                                {2'b0, i_instr_offset_addr[(i_pe*32+31)-:30]};
          o_instr_req[i_pe]         <= i_instr_req[i_pe];
        end
        else begin
          o_instr_addr[i_pe*32+:32] <= o_instr_addr[i_pe*32+:32];
          o_instr_req[i_pe]         <= o_instr_req[i_pe];
        end
        //* data;
        if(i_data_gnt[i_pe] == 1'b1) begin
          o_data_we[i_pe]           <= i_data_we[i_pe];
          o_data_req[i_pe]          <= i_data_req[i_pe];
          o_data_wdata[i_pe*32+:32] <= i_data_wdata[i_pe*32+:32];
          o_data_be[i_pe*4+:4]      <= i_data_be[i_pe*4+:4];
          o_data_addr[i_pe*32+:32]  <= i_data_addr[i_pe*32+:32] + 
                                {2'b0, i_data_offset_addr[(i_pe*32+31)-:30]};
        end
        else begin
          o_data_we[i_pe]           <= o_data_we[i_pe];
          o_data_req[i_pe]          <= o_data_req[i_pe];
          o_data_wdata[i_pe*32+:32] <= o_data_wdata[i_pe*32+:32];
          o_data_be[i_pe*4+:4]      <= o_data_be[i_pe*4+:4];
          o_data_addr[i_pe*32+:32]  <= o_data_addr[i_pe*32+:32];
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
endmodule

