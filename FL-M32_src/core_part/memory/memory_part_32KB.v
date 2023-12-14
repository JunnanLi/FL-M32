/*
 *  Project:            timelyRV_v1.0 -- a RISCV-32IMC SoC.
 *  Module name:        memory_part.
 *  Description:        instr/data memory of timelyRV core.
 *  Last updated date:  2022.05.13.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    This module is used to store instruction & data. And we use
 *      "conf_sel" to distinguish configuring or running mode.
 */


  module memory_instr_part (
      input                 clk,
      input                 rst_n,
      //* prot a
      input                 rda,
      input                 wea,
      input         [31:0]  addra,
      input         [31:0]  dina,
      output  wire  [31:0]  douta,
      //* prot b
      input                 rdb,
      input                 web,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      output  wire  [31:0]  doutb
  );

    `ifdef XILINX_FIFO_RAM
      `ifdef MEM_128KB
        ram_32_8192 mem(
          .clka   (clk                            ),
          .wea    (wea                            ),
          .addra  (addra[0+:13]                   ),
          .dina   (dina                           ),
          .douta  (douta                          ),
          .clkb   (clk                            ),
          .web    ('b0                            ),
          .addrb  (addrb[0+:13]                   ),
          .dinb   ('b0                            ),
          .doutb  (doutb                          )
        );
      `elsif MEM_64KB
        ram_32_4096 mem(
          .clka   (clk                            ),
          .wea    (wea                            ),
          .addra  (addra[0+:12]                   ),
          .dina   (dina                           ),
          .douta  (douta                          ),
          .clkb   (clk                            ),
          .web    ('b0                            ),
          .addrb  (addrb[0+:12]                   ),
          .dinb   ('b0                            ),
          .doutb  (doutb                          )
        );
      `elsif MEM_32KB
        ram_32_2048 mem(
          .clka   (clk                            ),
          .wea    (wea                            ),
          .addra  (addra[0+:11]                   ),
          .dina   (dina                           ),
          .douta  (douta                          ),
          .clkb   (clk                            ),
          .web    ('b0                            ),
          .addrb  (addrb[0+:11]                   ),
          .dinb   ('b0                            ),
          .doutb  (doutb                          )
        );
      `endif
    `elsif SIM_FIFO_RAM
      `ifdef MEM_128KB
        localparam  SRAM_ADDR_WIDTH = 13;
      `elsif MEM_64KB
        localparam  SRAM_ADDR_WIDTH = 12;
      `elsif MEM_32KB
        localparam  SRAM_ADDR_WIDTH = 11;
      `endif
        localparam  SRAM_WORDS      = 2**SRAM_ADDR_WIDTH;
        
      syncram mem(
        .address_a  (addra[0+:SRAM_ADDR_WIDTH]      ),
        .address_b  (addrb[0+:SRAM_ADDR_WIDTH]      ),
        .clock      (clk                            ),
        .data_a     (dina                           ),
        .data_b     ('b0                            ),
        .rden_a     (rda                            ),
        .rden_b     (rdb                            ),
        .wren_a     (wea                            ),
        .wren_b     ('b0                            ),
        .q_a        (douta                          ),
        .q_b        (doutb                          )
      );
      defparam  mem.width = 32,
                mem.depth = SRAM_ADDR_WIDTH,
                mem.words = SRAM_WORDS;
    `else
      // dualportsram8192x8 mem(
      //   .aclr       (~rst_n             ), //* asynchronous reset
      //   .address_a  (addra[12:0]        ), //* port A: address
      //   .address_b  (addrb[12:0]        ), //* port B: address
      //   .clock      (clk                ), //* port A & B: clock
      //   .data_a     (dina[8*i_ram+:8]   ), //* port A: data input
      //   .data_b     (dinb[8*i_ram+:8]   ), //* port B: data input
      //   .rden_a     (!wea[i_ram]        ), //* port A: read enable
      //   .rden_b     (!web[i_ram]        ), //* port B: read enable
      //   .wren_a     (wea[i_ram]         ), //* port A: write enable
      //   .wren_b     (web[i_ram]         ), //* port B: write enable
      //   .q_a        (douta[8*i_ram+:8]  ), //* port A: data output
      //   .q_b        (doutb[8*i_ram+:8]  )  //* port B: data output
      //   );
    `endif
  endmodule

  module memory_data_part (
      input                 clk,
      input                 rst_n,
      //* prot a
      input         [3:0]   wea,
      input         [31:0]  addra,
      input         [31:0]  dina,
      output  wire  [31:0]  douta,
      //* prot b
      input         [3:0]   web,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      output  wire  [31:0]  doutb
  );

    genvar i_ram;
    generate
      for (i_ram = 0; i_ram < 4; i_ram = i_ram+1) begin: mem_part
        `ifdef XILINX_FIFO_RAM
          `ifdef MEM_128KB
            ram_8_8192 mem(
              .clka   (clk                ),
              .wea    (wea[i_ram]         ),
              .addra  (addra[0+:13]       ),
              .dina   (dina[8*i_ram+:8]   ),
              .douta  (douta[8*i_ram+:8]  ),
              .clkb   (clk                ),
              .web    (web[i_ram]         ),
              .addrb  (addrb[0+:13]       ),
              .dinb   (dinb[8*i_ram+:8]   ),
              .doutb  (doutb[8*i_ram+:8]  )
            );
          `elsif MEM_64KB
            ram_8_4096 mem(
              .clka   (clk                ),
              .wea    (wea[i_ram]         ),
              .addra  (addra[0+:12]       ),
              .dina   (dina[8*i_ram+:8]   ),
              .douta  (douta[8*i_ram+:8]  ),
              .clkb   (clk                ),
              .web    (web[i_ram]         ),
              .addrb  (addrb[0+:12]       ),
              .dinb   (dinb[8*i_ram+:8]   ),
              .doutb  (doutb[8*i_ram+:8]  )
            );
          `elsif MEM_32KB
            ram_8_2048 mem(
              .clka   (clk                ),
              .wea    (wea[i_ram]         ),
              .addra  (addra[0+:11]       ),
              .dina   (dina[8*i_ram+:8]   ),
              .douta  (douta[8*i_ram+:8]  ),
              .clkb   (clk                ),
              .web    (web[i_ram]         ),
              .addrb  (addrb[0+:11]       ),
              .dinb   (dinb[8*i_ram+:8]   ),
              .doutb  (doutb[8*i_ram+:8]  )
            );
          `endif
        `elsif SIM_FIFO_RAM
          `ifdef MEM_128KB
            localparam  SRAM_ADDR_WIDTH = 13;
          `elsif MEM_64KB
            localparam  SRAM_ADDR_WIDTH = 12;
          `elsif MEM_32KB
            localparam  SRAM_ADDR_WIDTH = 11;
          `endif
            localparam  SRAM_WORDS      = 2**SRAM_ADDR_WIDTH;
          
          syncram mem(
            .address_a  (addra[0+:SRAM_ADDR_WIDTH]  ),
            .address_b  (addrb[0+:SRAM_ADDR_WIDTH]  ),
            .clock      (clk                        ),
            .data_a     (dina[8*i_ram+:8]           ),
            .data_b     (dinb[8*i_ram+:8]           ),
            .rden_a     (1'b1                       ),
            .rden_b     (1'b1                       ),
            .wren_a     (wea[i_ram]                 ),
            .wren_b     (web[i_ram]                 ),
            .q_a        (douta[8*i_ram+:8]          ),
            .q_b        (doutb[8*i_ram+:8]          )
          );
          defparam  mem.width = 8,
                    mem.depth = SRAM_ADDR_WIDTH,
                    mem.words = SRAM_WORDS;
        `else
          // dualportsram8192x8 mem(
          //   .aclr       (~rst_n             ), //* asynchronous reset
          //   .address_a  (addra[12:0]        ), //* port A: address
          //   .address_b  (addrb[12:0]        ), //* port B: address
          //   .clock      (clk                ), //* port A & B: clock
          //   .data_a     (dina[8*i_ram+:8]   ), //* port A: data input
          //   .data_b     (dinb[8*i_ram+:8]   ), //* port B: data input
          //   .rden_a     (!wea[i_ram]        ), //* port A: read enable
          //   .rden_b     (!web[i_ram]        ), //* port B: read enable
          //   .wren_a     (wea[i_ram]         ), //* port A: write enable
          //   .wren_b     (web[i_ram]         ), //* port B: write enable
          //   .q_a        (douta[8*i_ram+:8]  ), //* port A: data output
          //   .q_b        (doutb[8*i_ram+:8]  )  //* port B: data output
          // );
        `endif
      end
    endgenerate
  endmodule