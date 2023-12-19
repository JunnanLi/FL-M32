/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Crossbar_In.
 *  Description:        instr/data memory of timelyRV core.
 *  Last updated date:  2022.06.17.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 */

  //======================= Combine Peri_out/in ==================//
module Crossbar_In (
  input   wire  [`MUX_IN-1:0]           rden_i,
  input   wire  [`MUX_IN-1:0]           wren_i,
  input   wire  [`MUX_IN*4-1:0]         wstrb_i,
  input   wire  [`MUX_IN*32-1:0]        addr_i,
  input   wire  [`MUX_IN*32-1:0]        wdata_i,

  output  wire  [`MUX_OUT*`MUX_IN-1:0]  peID_o,
  output  wire  [`MUX_OUT*4-1:0]        wstrb_o,
  output  wire  [`MUX_OUT*32-1:0]       addr_o,
  output  wire  [`MUX_OUT*32-1:0]       wdata_o
);
  //* input part: 1) dmux for each PE; 2) MUX for each port of SRAM;
  //* dmux;
  //* rden_pe[x] is a bitmap sel for each ram of PE_x, i.e., RE_x chose which SRAM;
  //* peID_ram[x] is a bitmap sel for each pe of ram, i.e., SRAM_x chose which PE;
  wire          [`MUX_OUT-1:0]          rden_pe[`MUX_IN-1:0], wren_pe[`MUX_IN-1:0];
  wire          [3:0]                   wstrb_pe[`MUX_IN-1:0];
  wire          [31:0]                  addr_pe[`MUX_IN-1:0], wdata_pe[`MUX_IN-1:0];
  wire          [`MUX_IN-1:0]           peID_ram[`MUX_OUT-1:0];

  //* TODO, fixed memory size;
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `MUX_IN; i_pe=i_pe+1) begin : dmux
      assign addr_pe[i_pe]  = addr_i[32*i_pe+:32];
      assign wstrb_pe[i_pe] = wstrb_i[4*i_pe+:4] & {4{wren_i[i_pe]}};
      assign wdata_pe[i_pe] = wdata_i[32*i_pe+:32];
      assign rden_pe[i_pe]  = (4'd1 << addr_pe[i_pe][(`BIT_CONF-1)-:2])&{4{rden_i[i_pe]}};  //*** 4 sram;
      assign wren_pe[i_pe]  = (4'd1 << addr_pe[i_pe][(`BIT_CONF-1)-:2])&{4{wren_i[i_pe]}};  //*** 4 sram;
    end
  endgenerate
  
  //* mux, chose one PE;
  genvar i_ram;
  generate
    for (i_ram = 0; i_ram < `MUX_OUT; i_ram=i_ram+1) begin : mux

        //*** for MUX_IN = 4;
        assign peID_ram[i_ram]        = {(rden_pe[3][i_ram] | wren_pe[3][i_ram]) &
                                        ~(rden_pe[2][i_ram] | wren_pe[2][i_ram]|
                                          rden_pe[1][i_ram] | rden_pe[0][i_ram]|wren_pe[1][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[2]
                                        (rden_pe[2][i_ram]  | wren_pe[2][i_ram]) &
                                        ~(rden_pe[1][i_ram] | rden_pe[0][i_ram]|wren_pe[1][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[1]
                                        (rden_pe[1][i_ram]  | wren_pe[1][i_ram]) & ~(rden_pe[0][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[0]
                                        rden_pe[0][i_ram]   | wren_pe[0][i_ram]};
        assign wstrb_o[i_ram*4+:4]    = peID_ram[i_ram][0]? wstrb_pe[0]: 
                                        peID_ram[i_ram][1]? wstrb_pe[1]:  
                                        peID_ram[i_ram][2]? wstrb_pe[2]: 
                                        peID_ram[i_ram][3]? wstrb_pe[3]: 4'b0;
        assign addr_o[i_ram*32+:32]   = peID_ram[i_ram][0]? addr_pe[0]: 
                                        peID_ram[i_ram][1]? addr_pe[1]:  
                                        peID_ram[i_ram][2]? addr_pe[2]: addr_pe[3];
        assign wdata_o[i_ram*32+:32]  = peID_ram[i_ram][0]? wdata_pe[0]: 
                                        peID_ram[i_ram][1]? wdata_pe[1]: 
                                        peID_ram[i_ram][2]? wdata_pe[2]: wdata_pe[3];
                                        
        assign peID_o[i_ram*4+:4]     = peID_ram[i_ram];

    end
  endgenerate
endmodule
