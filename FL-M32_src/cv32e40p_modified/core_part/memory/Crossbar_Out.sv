/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Crossbar_Out.
 *  Description:        instr/data memory of timelyRV core.
 *  Last updated date:  2022.06.17.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 *    This module is used to store instruction & data. And we use
 *      "conf_sel" to distinguish configuring or running mode.
 */

module Crossbar_Out (
  //* clk & rst_n;
  input                                 i_clk,
  input                                 i_rst_n,
  //* input;
  input                                 i_peID,
  input                                 i_dout,
  //* output;
  output                                o_valid,
  output                                o_rdata
);
  parameter   num_inPort  = 4,  //* e.g., number of srams
              num_outPort = 4,  //* e.g., number of read req
              width       = 32;

  //* input;
  wire  [num_inPort-1:0][num_outPort-1:0] i_peID;
  wire  [num_inPort-1:0][width-1      :0] i_dout;
  //* output;
  wire  [num_outPort-1:0]                 o_valid;
  wire  [num_outPort-1:0][width-1     :0] o_rdata;

  //====================================================================//
  // internal reg/wire/param declarations
  //====================================================================//
  //*delay two clks;
  //* i_peID: a bitmap sel for each pe of ram, i.e., SRAM_x chose which PE/Config;
  //* r_peID_pe: a bitmap represents whether PE_x get data from form 4 SRAM;
  reg   [num_inPort-1            :0]    r_reverse_peID[num_outPort-1:0], r_reverse_peID_0[num_outPort-1:0];
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  // memory out
  //====================================================================//
  //* 1) chose which inport to output; 
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      for(i=0; i<num_outPort; i=i+1) begin
        r_reverse_peID_0[i]      <= {`num_inPort{1'b0}};
        r_reverse_peID[i]        <= {`num_inPort{1'b0}};
      end
    end 
    else begin
      for(i=0; i<num_outPort; i=i+1) begin
        //* for 4 SRAM
        r_peID_pe_0[i]      <=  (i_peID[0][i])? 4'd1 :
                                (i_peID[1][i])? 4'd2 :
                                (i_peID[2][i])? 4'd4 :
                                (i_peID[3][i])? 4'd8 : 4'd0;
        r_peID_pe[i]        <=  r_peID_pe_0[i];
      end
    end
  end
  //* 2) output data;
  genvar idx;
  generate
    for (idx = 0; idx < num_outPort; idx=idx+1) begin : mux
      //* for 4 SRAM
      assign o_rdata[num_outPort] = r_peID_pe[idx][0]? i_dout[0]: 
                                    r_peID_pe[idx][1]? i_dout[1]: 
                                    r_peID_pe[idx][2]? i_dout[2]: i_dout[3];
      assign o_valid[num_outPort] = |r_peID_pe[idx];
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule