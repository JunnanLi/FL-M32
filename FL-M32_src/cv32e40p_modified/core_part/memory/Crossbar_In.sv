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
  input                         rden_i,
  input                         wren_i,
  input                         wstrb_i,
  input                         addr_i,
  input                         wdata_i,

  output                        peID_o,
  output                        wstrb_o,
  output                        addr_o,
  output                        wdata_o
);
  parameter   num_inPort  = 4,  //* e.g., number of read req
              num_outPort = 4,  //* e.g., number of srams
              width       = 32;

  wire  [num_inPort-1:0]        rden_i;
  wire  [num_inPort-1:0]        wren_i;
  wire  [num_inPort-1:0][3:0]   wstrb_i;
  wire  [num_inPort-1:0][31:0]  addr_i;
  wire  [num_inPort-1:0][31:0]  wdata_i;

  wire  [num_outPort-1:0][num_inPort-1:0]  peID_o;
  wire  [num_outPort-1:0][3:0]  wstrb_o;
  wire  [num_outPort-1:0][31:0] addr_o;
  wire  [num_outPort-1:0][31:0] wdata_o;
  //* input part: 1) dmux for each PE; 2) MUX for each port of SRAM;
  //* dmux;
  //* rden_pe[x] is a bitmap sel for each ram of PE_x, i.e., RE_x chose which SRAM;
  //* peID_o[x] is a bitmap sel for each pe of ram, i.e., SRAM_x chose which PE;
  wire  [num_inPort-1][num_outPort-1:0]   rden_pe, wren_pe;

  //* TODO, fixed memory size;
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < num_inPort; i_pe=i_pe+1) begin : dmux
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
    for (i_ram = 0; i_ram < num_outPort; i_ram=i_ram+1) begin : mux

        //*** for num_inPort = 4;
        assign peID_o[i_ram]          = {(rden_pe[3][i_ram] | wren_pe[3][i_ram]) &
                                        ~(rden_pe[2][i_ram] | wren_pe[2][i_ram]|
                                          rden_pe[1][i_ram] | rden_pe[0][i_ram]|wren_pe[1][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[2]
                                        (rden_pe[2][i_ram]  | wren_pe[2][i_ram]) &
                                        ~(rden_pe[1][i_ram] | rden_pe[0][i_ram]|wren_pe[1][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[1]
                                        (rden_pe[1][i_ram]  | wren_pe[1][i_ram]) & ~(rden_pe[0][i_ram]|wren_pe[0][i_ram]),
                                        //* bit[0]
                                        rden_pe[0][i_ram]   | wren_pe[0][i_ram]};
        assign wstrb_o[i_ram*4+:4]    = peID_o[i_ram][1]? wstrb_i[1]:  
                                        peID_o[i_ram][2]? wstrb_i[2]: 
                                        peID_o[i_ram][3]? wstrb_i[3]: 4'b0;
        assign addr_o[i_ram*32+:32]   = peID_o[i_ram][0]? addr_i[0]: 
                                        peID_o[i_ram][1]? addr_i[1]:  
                                        peID_o[i_ram][2]? addr_i[2]: addr_i[3];
        assign wdata_o[i_ram*32+:32]  = peID_o[i_ram][0]? wdata_i[0]: 
                                        peID_o[i_ram][1]? wdata_i[1]: 
                                        peID_o[i_ram][2]? wdata_i[2]: wdata_i[3];
                                      

    end
  endgenerate
endmodule
