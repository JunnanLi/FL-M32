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
  input   wire                          i_clk,
  input   wire                          i_rst_n,
  //* input;
  input   wire  [`MUX_OUT*`MUX_IN-1:0]  i_peID,
  input   wire  [`MUX_OUT*32-1:0]       i_dout,
  //* output;
  output  wire  [`MUX_IN-1:0]           o_valid,
  output  wire  [`MUX_IN*32-1:0]        o_rdata
);

  //======================= internal reg/wire/param declarations =//
  //*delay two clks;
  //* w_peID_ram: a bitmap sel for each pe of ram, i.e., SRAM_x chose which PE/Config;
  //* r_peID_pe: a bitmap represents whether PE_x get data from form 4 SRAM;
  wire          [`MUX_IN-1:0]           w_peID_ram[`MUX_OUT-1:0];   
  reg           [`MUX_OUT:0]            r_peID_pe[`MUX_IN-1:0], r_peID_pe_0[`MUX_IN-1:0];
  //==============================================================//

  //======================= dmux & mux ===========================//
  //* output part: 1) dmux for each port; 2) mux for each PE;
  genvar i_ram;
  generate
    for (i_ram = 0; i_ram < `MUX_OUT; i_ram=i_ram+1) begin : dmux
      assign w_peID_ram[i_ram]  = i_peID[i_ram*`MUX_OUT+:`MUX_IN];                
    end
  endgenerate

  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      for(i=0; i<`MUX_IN; i=i+1) begin
        r_peID_pe_0[i]      <= {`MUX_OUT{1'b0}};
        r_peID_pe[i]        <= {`MUX_OUT{1'b0}};
      end
    end 
    else begin
      for(i=0; i<`MUX_IN; i=i+1) begin
        //* for 4 SRAM
        r_peID_pe_0[i]      <=  (w_peID_ram[0][i])? 4'd1 :
                                (w_peID_ram[1][i])? 4'd2 :
                                (w_peID_ram[2][i])? 4'd4 :
                                (w_peID_ram[3][i])? 4'd8 : 4'd0;
        r_peID_pe[i]        <=  r_peID_pe_0[i];
      end
    end
  end
  //==============================================================//

  //======================= mux        ===========================//
  //* mux, output rdata for each PE/Config;
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `MUX_IN; i_pe=i_pe+1) begin : mux
      //* for 4 SRAM
      assign o_rdata[i_pe*32+:32] = r_peID_pe[i_pe][0]? i_dout[0+:32]: 
                                    r_peID_pe[i_pe][1]? i_dout[32+:32]: 
                                    r_peID_pe[i_pe][2]? i_dout[64+:32]: i_dout[96+:32];
      assign o_valid[i_pe]        = |r_peID_pe[i_pe];
    end
  endgenerate
  //==============================================================//

endmodule