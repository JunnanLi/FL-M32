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

`ifdef MEM_128KB

  
  module memory_instr_part_32KB (
      input                 clk,
      input                 rst_n,
      //* prot a
      input                 wea,
      input         [31:0]  addra,
      input         [31:0]  dina,
      output  wire  [31:0]  douta,
      //* prot b
      input                 web,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      output  wire  [31:0]  doutb
  );

    `ifdef XILINX_FIFO_RAM
      ram_32_8192 mem(
        .clka   (clk                            ),
        .wea    (wea                            ),
        .addra  (addra[12:0]                    ),
        .dina   (dina                           ),
        .douta  (douta                          ),
        .clkb   (clk                            ),
        .web    ('b0                            ),
        .addrb  (addrb[12:0]                    ),
        .dinb   ('b0                            ),
        .doutb  (doutb                          )
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[12:0]                    ),
        .address_b  (addrb[12:0]                    ),
        .clock      (clk                            ),
        .data_a     (dina                           ),
        .data_b     ('b0                            ),
        .rden_a     (1'b1                           ),
        .rden_b     (1'b1                           ),
        .wren_a     (wea                            ),
        .wren_b     ('b0                            ),
        .q_a        (douta                          ),
        .q_b        (doutb                          )
      );
      defparam  mem.width = 32,
                mem.depth = 13,
                mem.words = 8192;
    `else
    `endif

  endmodule

  module memory_part_32KB (
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
          ram_8_8192 mem(
            .clka   (clk                ),
            .wea    (wea[i_ram]         ),
            .addra  (addra[12:0]        ),
            .dina   (dina[8*i_ram+:8]   ),
            .douta  (douta[8*i_ram+:8]  ),
            .clkb   (clk                ),
            .web    (web[i_ram]         ),
            .addrb  (addrb[12:0]        ),
            .dinb   (dinb[8*i_ram+:8]   ),
            .doutb  (doutb[8*i_ram+:8]  )
          );
        `elsif SIM_FIFO_RAM
          syncram mem(
            .address_a  (addra[12:0]            ),
            .address_b  (addrb[12:0]            ),
            .clock      (clk                    ),
            .data_a     (dina[8*i_ram+:8]       ),
            .data_b     (dinb[8*i_ram+:8]       ),
            .rden_a     (1'b1                   ),
            .rden_b     (1'b1                   ),
            .wren_a     (wea[i_ram]             ),
            .wren_b     (web[i_ram]             ),
            .q_a        (douta[8*i_ram+:8]      ),
            .q_b        (doutb[8*i_ram+:8]      )
          );
          defparam  mem.width = 8,
                    mem.depth = 13,
                    mem.words = 8192;
        `else
          dualportsram8192x8 mem(
            .aclr       (~rst_n             ), //* asynchronous reset
            .address_a  (addra[12:0]        ), //* port A: address
            .address_b  (addrb[12:0]        ), //* port B: address
            .clock      (clk                ), //* port A & B: clock
            .data_a     (dina[8*i_ram+:8]   ), //* port A: data input
            .data_b     (dinb[8*i_ram+:8]   ), //* port B: data input
            .rden_a     (!wea[i_ram]        ), //* port A: read enable
            .rden_b     (!web[i_ram]        ), //* port B: read enable
            .wren_a     (wea[i_ram]         ), //* port A: write enable
            .wren_b     (web[i_ram]         ), //* port B: write enable
            .q_a        (douta[8*i_ram+:8]  ), //* port A: data output
            .q_b        (doutb[8*i_ram+:8]  )  //* port B: data output
            );
        `endif
      end
    endgenerate


  endmodule

`elsif MEM_64KB
  
  module memory_instr_part_16KB (
      input                 clk,
      input                 rst_n,
      //* prot a
      input                 wea,
      input         [31:0]  addra,
      input         [31:0]  dina,
      output  wire  [31:0]  douta,
      //* prot b
      input                 web,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      output  wire  [31:0]  doutb
  );

    `ifdef XILINX_FIFO_RAM
      ram_32_4096 mem(
        .clka   (clk                            ),
        .wea    (wea                            ),
        .addra  (addra[11:0]                    ),
        .dina   (dina                           ),
        .douta  (douta                          ),
        .clkb   (clk                            ),
        .web    ('b0                            ),
        .addrb  (addrb[11:0]                    ),
        .dinb   ('b0                            ),
        .doutb  (doutb                          )
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[11:0]                    ),
        .address_b  (addrb[11:0]                    ),
        .clock      (clk                            ),
        .data_a     (dina                           ),
        .data_b     ('b0                            ),
        .rden_a     (1'b1                           ),
        .rden_b     (1'b1                           ),
        .wren_a     (wea                            ),
        .wren_b     ('b0                            ),
        .q_a        (douta                          ),
        .q_b        (doutb                          )
      );
      defparam  mem.width = 32,
                mem.depth = 12,
                mem.words = 4096;
    `else
    `endif

  endmodule


  module memory_part_16KB (
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
          ram_8_4096 mem(
            .clka   (clk                ),
            .wea    (wea[i_ram]         ),
            .addra  (addra[11:0]        ),
            .dina   (dina[8*i_ram+:8]   ),
            .douta  (douta[8*i_ram+:8]  ),
            .clkb   (clk                ),
            .web    (web[i_ram]         ),
            .addrb  (addrb[11:0]        ),
            .dinb   (dinb[8*i_ram+:8]   ),
            .doutb  (doutb[8*i_ram+:8]  )
          );
        `elsif SIM_FIFO_RAM
          syncram mem(
            .address_a  (addra[11:0]            ),
            .address_b  (addrb[11:0]            ),
            .clock      (clk                    ),
            .data_a     (dina[8*i_ram+:8]       ),
            .data_b     (dinb[8*i_ram+:8]       ),
            .rden_a     (1'b1                   ),
            .rden_b     (1'b1                   ),
            .wren_a     (wea[i_ram]             ),
            .wren_b     (web[i_ram]             ),
            .q_a        (douta[8*i_ram+:8]      ),
            .q_b        (doutb[8*i_ram+:8]      )
          );
          defparam  mem.width = 8,
                    mem.depth = 12,
                    mem.words = 4096;
        `endif
      end
    endgenerate


  endmodule
`elsif MEM_32KB

  module memory_instr_part_8KB (
      input                 clk,
      input                 rst_n,
      //* prot a
      input                 wea,
      input         [31:0]  addra,
      input         [31:0]  dina,
      output  wire  [31:0]  douta,
      //* prot b
      input                 web,
      input         [31:0]  addrb,
      input         [31:0]  dinb,
      output  wire  [31:0]  doutb
  );

    `ifdef XILINX_FIFO_RAM
      ram_32_2048 mem(
        .clka   (clk                            ),
        .wea    (wea                            ),
        .addra  (addra[10:0]                    ),
        .dina   (dina                           ),
        .douta  (douta                          ),
        .clkb   (clk                            ),
        .web    ('b0                            ),
        .addrb  (addrb[10:0]                    ),
        .dinb   ('b0                            ),
        .doutb  (doutb                          )
      );
    `elsif SIM_FIFO_RAM
      syncram mem(
        .address_a  (addra[10:0]                    ),
        .address_b  (addrb[10:0]                    ),
        .clock      (clk                            ),
        .data_a     (dina                           ),
        .data_b     ('b0                            ),
        .rden_a     (1'b1                           ),
        .rden_b     (1'b1                           ),
        .wren_a     (wea                            ),
        .wren_b     ('b0                            ),
        .q_a        (douta                          ),
        .q_b        (doutb                          )
      );
      defparam  mem.width = 32,
                mem.depth = 11,
                mem.words = 2048;
    `else
    `endif

  endmodule

  module memory_part_8KB (
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
          ram_8_2048 mem(
            .clka   (clk                ),
            .wea    (wea[i_ram]         ),
            .addra  (addra[10:0]        ),
            .dina   (dina[8*i_ram+:8]   ),
            .douta  (douta[8*i_ram+:8]  ),
            .clkb   (clk                ),
            .web    (web[i_ram]         ),
            .addrb  (addrb[10:0]        ),
            .dinb   (dinb[8*i_ram+:8]   ),
            .doutb  (doutb[8*i_ram+:8]  )
          );
        `elsif SIM_FIFO_RAM
          syncram mem(
            .address_a  (addra[10:0]            ),
            .address_b  (addrb[10:0]            ),
            .clock      (clk                    ),
            .data_a     (dina[8*i_ram+:8]       ),
            .data_b     (dinb[8*i_ram+:8]       ),
            .rden_a     (1'b1                   ),
            .rden_b     (1'b1                   ),
            .wren_a     (wea[i_ram]             ),
            .wren_b     (web[i_ram]             ),
            .q_a        (douta[8*i_ram+:8]      ),
            .q_b        (doutb[8*i_ram+:8]      )
          );
          defparam  mem.width = 8,
                    mem.depth = 11,
                    mem.words = 2048;
        `endif
      end
    endgenerate


  endmodule
`endif

// module memory_part_0KB (
//   input   wire          clk,
//   //* prot a
//   input   wire  [3:0]   wea,
//   input   wire  [31:0]  addra,
//   input   wire  [31:0]  dina,
//   output  wire  [31:0]  douta,
//   //* prot b
//   input   wire  [3:0]   web,
//   input   wire  [31:0]  addrb,
//   input   wire  [31:0]  dinb,
//   output  wire  [31:0]  doutb
// );

//   assign douta = 32'b0;
//   assign doutb = 32'b0;
// endmodule