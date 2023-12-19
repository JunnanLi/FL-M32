/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Memory_Top.
 *  Description:        instr/data memory of timelyRV core.
 *  Last updated date:  2022.06.17.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 */

module Memory_Top (
  //* clk & reset;
  input   wire                    i_clk,
  input   wire                    i_rst_n,

  //* interface for configuration;
  input   wire                    i_conf_rden,    //* support read/write
  input   wire                    i_conf_wren,
  input   wire  [          31:0]  i_conf_addr,
  input   wire  [          31:0]  i_conf_wdata,
  output  wire  [          31:0]  o_conf_rdata,   //* rdata is valid after two clk;
  input   wire  [           3:0]  i_conf_en,      //* for 4 PEs;

  //* interface for PEs (instr.);
  input   wire  [   `NUM_PE-1:0]  i_instr_req,
  input   wire  [`NUM_PE*32-1:0]  i_instr_addr,
  output  wire  [`NUM_PE*32-1:0]  o_instr_rdata,
  output  wire  [   `NUM_PE-1:0]  o_instr_rvalid,
  output  wire  [   `NUM_PE-1:0]  o_instr_gnt,

  //* interface for PEs (data);
  input   wire  [   `NUM_PE-1:0]  i_data_req,
  input   wire  [`NUM_PE*32-1:0]  i_data_addr,
  input   wire  [   `NUM_PE-1:0]  i_data_we,
  input   wire  [ `NUM_PE*4-1:0]  i_data_be,
  input   wire  [`NUM_PE*32-1:0]  i_data_wdata,
  output  wire  [`NUM_PE*32-1:0]  o_data_rdata,
  output  wire  [   `NUM_PE-1:0]  o_data_rvalid,
  output  wire  [   `NUM_PE-1:0]  o_data_gnt,
  
  //* interface for dDMA;
  `ifdef AIPE_EN
    input   wire                  i_dDMA_rden,
    input   wire                  i_dDMA_wren,
    input   wire  [        31:0]  i_dDMA_addr,
    input   wire  [        31:0]  i_dDMA_wdata,
    output  wire  [        31:0]  o_dDMA_rdata,
    output  wire                  o_dDMA_rvalid,
    output  wire                  o_dDMA_gnt,
  `endif

  //* interface for DMA;
  input   wire  [   `NUM_PE-1:0]  i_dma_rden,
  input   wire  [   `NUM_PE-1:0]  i_dma_wren,
  input   wire  [`NUM_PE*32-1:0]  i_dma_addr,
  input   wire  [`NUM_PE*32-1:0]  i_dma_wdata,
  output  wire  [`NUM_PE*32-1:0]  o_dma_rdata,
  output  wire  [   `NUM_PE-1:0]  o_dma_rvalid,
  output  wire  [   `NUM_PE-1:0]  o_dma_gnt
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* peID means which PE/Config has been chosed to access current SRAM, 
  //*   in format {(sram3){pes,conf},(sram2){pes,conf},...};
  //* wren for sram, i.e., wstrb, means to write which 8b SRAM, in format 
  //*   {sram3_wstrb,sram2_wstrb,...};
  //* addr for sram, in format {sram3_addr,sram2_addr,...};
  //* din for sram, in format {sram3_din,sram2_din,...};
  //* dout for sram, in format {sram3_dout,sram2_dout,...};
  wire  [`MUX_OUT*`MUX_IN-1:0]  peID_data_a,  peID_data_b;
  wire  [`MUX_OUT*4-1:0]        wren_data_a,  wren_data_b; 
  wire  [`MUX_OUT*32-1:0]       addr_data_a,  addr_data_b;
  wire  [`MUX_OUT*32-1:0]       din_data_a,   din_data_b;
  wire  [`MUX_OUT*32-1:0]       dout_data_a,  dout_data_b;

  //* Crossbar_in (port a & b)
  //* wstrb for {dma0,pe1,pe0,config/pe3}/{dDMA/dma3,dma2,dma1,pe2};
  //* rden for {dma0,pe1,pe0,config/pe3}/{dDMA/dma3,dma2,dma1,pe2};
  //* addr for {dma0,pe1,pe0,config/pe3}/{dDMA/dma3,dma2,dma1,pe2};
  wire  [`MUX_IN*4-1:0]         wstrb_data_dmux_a;
  wire  [`MUX_IN-1:0]           rden_data_dmux_a,   wren_data_dmux_a;
  wire  [`MUX_IN*32-1:0]        addr_data_dmux_a,   wdata_data_dmux_a;
  wire  [`MUX_IN*4-1:0]         wstrb_data_dmux_b;
  wire  [`MUX_IN-1:0]           rden_data_dmux_b,   wren_data_dmux_b;
  wire  [`MUX_IN*32-1:0]        addr_data_dmux_b,   wdata_data_dmux_b;

  //* Crossbar_out (port a & b)
  //* rvalid for {dma0,pe1,pe0,config/pe3}/{dDMA/dma3,dma2,dma1,pe2};
  //* rdata for {dma0,pe1,pe0,config/pe3}/{dDMA/dma3,dma2,dma1,pe2};
  wire  [`MUX_IN-1:0]           rvalid_data_mux_a,  rvalid_data_mux_b;
  wire  [`MUX_IN*32-1:0]        rdata_data_mux_a,   rdata_data_mux_b;
  
  //* mux for pe3/pe_conf, dma3/dDMA;
  wire                          w_rden_dmux_pe4_conf, w_rden_mux_pe4_dDMA;
  wire                          w_wren_dmux_pe4_conf, w_wren_mux_pe4_dDMA;
  wire  [ 3:0]                  w_wstrb_dmux_pe4_conf;
  wire  [31:0]                  w_addr_dmux_pe4_conf, w_addr_mux_pe4_dDMA;
  wire  [31:0]                  w_wdata_dmux_pe4_conf,w_wdata_mux_pe4_dDMA;
  //* wire for pe_0/1/2/
  wire  [2:0]                   w_data_we, w_data_req;
  wire  [31:0]                  w_data_addr[2:0],w_data_wdata[2:0];
  wire  [ 3:0]                  w_data_be[2:0];
  wire  [2:0]                   w_dma_rden, w_dma_wren;
  wire  [31:0]                  w_dma_addr[2:0], w_dma_wdata[2:0];

  wire  [`NUM_PE-1:0][31:0]     w_icache_addr;
  wire  [`NUM_PE-1:0][31:0]     w_icache_rdata;

  //* interface for reading SRAM by Icache;
  wire                          w_mm_rden;
  wire  [             31:0]     w_mm_addr;
  wire  [            127:0]     w_mm_rdata;
  wire                          w_mm_rvalid;
  wire                          w_mm_gnt;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  //* a port {DMA0, PE_1, PE_0, CONF};
  //******************************************************************************************************//
  assign rden_data_dmux_a   = {w_dma_rden[0],         (~w_data_we[1])&w_data_req[1],  (~w_data_we[0])&w_data_req[0],  w_rden_dmux_pe4_conf  };
  assign wren_data_dmux_a   = {w_dma_wren[0],         w_data_we[1]&w_data_req[1],     w_data_we[0]&w_data_req[0],     w_wren_dmux_pe4_conf  };
  assign wstrb_data_dmux_a  = {4'hf,                  w_data_be[1],                   w_data_be[0],                   w_wstrb_dmux_pe4_conf };
  assign addr_data_dmux_a   = {w_dma_addr[0],         w_data_addr[1],                 w_data_addr[0],                 w_addr_dmux_pe4_conf  };
  assign wdata_data_dmux_a  = {w_dma_wdata[0],        w_data_wdata[1],                w_data_wdata[0],                w_wdata_dmux_pe4_conf };
  //******************************************************************************************************//

  //* b port {EMPTY, DMA_1, PE_1}, TODO, left for dDMA;
  //********************************************************************************************************//
  assign rden_data_dmux_b   = {w_rden_mux_pe4_dDMA,   w_dma_rden[2], w_dma_rden[1],         (~w_data_we[2])&w_data_req[2] };
  assign wren_data_dmux_b   = {w_wren_mux_pe4_dDMA,   w_dma_wren[2], w_dma_wren[1],         w_data_we[2]   &w_data_req[2] };
  assign wstrb_data_dmux_b  = {4'hf,                  4'hf,          4'hf,                  w_data_be[2]                  };
  assign addr_data_dmux_b   = {w_addr_mux_pe4_dDMA,   w_dma_addr[2], w_dma_addr[1],         w_data_addr[2]                };
  assign wdata_data_dmux_b  = {w_wdata_mux_pe4_dDMA,  w_dma_wdata[2],w_dma_wdata[1],        w_data_wdata[2]               };
  //******************************************************************************************************//
 
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Crossbar_In
  //====================================================================//
  //* input part: 1) dmux for each PE; 2) MUX for each port of SRAM;

  Crossbar_In Crossbar_In_Data_a (
    .rden_i                 (rden_data_dmux_a         ),
    .wren_i                 (wren_data_dmux_a         ),
    .wstrb_i                (wstrb_data_dmux_a        ),
    .addr_i                 (addr_data_dmux_a         ),
    .wdata_i                (wdata_data_dmux_a        ),
    .peID_o                 (peID_data_a              ),
    .wstrb_o                (wren_data_a              ),
    .addr_o                 (addr_data_a              ),
    .wdata_o                (din_data_a               )
  );

  Crossbar_In Crossbar_In_Data_b (
    .rden_i                 (rden_data_dmux_b         ),
    .wren_i                 (wren_data_dmux_b         ),
    .wstrb_i                (wstrb_data_dmux_b        ),
    .addr_i                 (addr_data_dmux_b         ),
    .wdata_i                (wdata_data_dmux_b        ),
    .peID_o                 (peID_data_b              ),
    .wstrb_o                (wren_data_b              ),
    .addr_o                 (addr_data_b              ),
    .wdata_o                (din_data_b               )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Crossbar_Out
  //====================================================================//
  //* output part: 1) dmux for each port; 2) mux for each PE;
  Crossbar_Out Crossbar_Out_Data_a (
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    .i_peID                 (peID_data_a              ),  //* two clk earlier;
    .i_dout                 (dout_data_a              ),
    .o_valid                (rvalid_data_mux_a        ),
    .o_rdata                (rdata_data_mux_a         )
  );

  Crossbar_Out Crossbar_Out_Data_b (
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    .i_peID                 (peID_data_b              ),  //* two clk earlier;
    .i_dout                 (dout_data_b              ),
    .o_valid                (rvalid_data_mux_b        ),
    .o_rdata                (rdata_data_mux_b         )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   4KB iCache
  //====================================================================//
  genvar i_pe;
   generate
      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1)
      begin
         assign w_icache_addr[i_pe]         = i_instr_addr[i_pe*32+:32];
         assign o_instr_rdata[i_pe*32+:32]  = w_icache_rdata[i_pe];
      end
   endgenerate

  iCache_Top iCache_Top (
    //* clk & reset;
    .i_clk            (i_clk                      ),
    .i_rst_n          (i_rst_n                    ),

    //* interface for PEs (instr.);
    .i_icache_req     (i_instr_req                ),
    .i_icache_addr    (w_icache_addr              ),
    .o_icache_rdata   (w_icache_rdata             ),
    .o_icache_rvalid  (o_instr_rvalid             ),
    .o_icache_gnt     (o_instr_gnt                ),

    //* interface for reading SRAM by Icache;
    .o_mm_rden        (w_mm_rden                  ),
    .o_mm_addr        (w_mm_addr                  ),
    .i_mm_rdata       (w_mm_rdata                 ),
    .i_mm_rvalid      (w_mm_rvalid                ),
    .i_mm_gnt         (1'b1                       )
  );

  reg [1:0] temp_mm_rden;
  assign w_mm_rvalid = temp_mm_rden[1];
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      temp_mm_rden  <= 2'b0;
    end else begin
      temp_mm_rden  <= {temp_mm_rden[0],w_mm_rden};
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   128KB Instr/Data RAM
  //====================================================================//
  genvar i_ram;
  generate
    for (i_ram = 0; i_ram < 4; i_ram = i_ram+1) begin: ram_mem
      `ifdef MEM_128KB
        //* instr;
        memory_instr_part_32KB instr_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (i_conf_wren & (~i_conf_addr[`BIT_CONF]) & 
                    (i_conf_addr[1:0] == i_ram)   ),  
          .addra  ({2'b0,i_conf_addr[31:2]}       ),
          .dina   (i_conf_wdata                   ),
          .douta  (o_conf_rdata                   ),
          .web    ('b0                            ),  
          .addrb  ({2'b0,w_mm_addr[31:2]}         ),
          .dinb   ('b0                            ),
          .doutb  (w_mm_rdata[i_ram*32+:32]       )
        );
        
        //* data;
        memory_part_32KB data_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (wren_data_a[i_ram*4+:4]        ),  
          .addra  (addr_data_a[i_ram*32+:32]      ),
          .dina   (din_data_a[i_ram*32+:32]       ),
          .douta  (dout_data_a[i_ram*32+:32]      ),
          .web    (wren_data_b[i_ram*4+:4]        ),  
          .addrb  (addr_data_b[i_ram*32+:32]      ),
          .dinb   (din_data_b[i_ram*32+:32]       ),
          .doutb  (dout_data_b[i_ram*32+:32]      )
        );
      `elsif MEM_64KB
        //* instr;
        memory_instr_part_16KB instr_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (i_conf_wren & (~i_conf_addr[`BIT_CONF]) & 
                    (i_conf_addr[1:0] == i_ram)   ),  
          .addra  (i_conf_addr                    ),
          .dina   (i_conf_wdata                   ),
          .douta  (o_conf_rdata                   ),
          .web    ('b0                            ),  
          .addrb  ({2'b0,w_mm_addr[31:2]}         ),
          .dinb   ('b0                            ),
          .doutb  (w_mm_rdata[i_ram*32+:32]       )
        );
        
        //* data;
        memory_part_16KB data_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (wren_data_a[i_ram*4+:4]        ),  
          .addra  (addr_data_a[i_ram*32+:32]      ),
          .dina   (din_data_a[i_ram*32+:32]       ),
          .douta  (dout_data_a[i_ram*32+:32]      ),
          .web    (wren_data_b[i_ram*4+:4]        ),  
          .addrb  (addr_data_b[i_ram*32+:32]      ),
          .dinb   (din_data_b[i_ram*32+:32]       ),
          .doutb  (dout_data_b[i_ram*32+:32]      )
        );
      `elsif MEM_32KB
        //* instr;
        memory_instr_part_8KB instr_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (i_conf_wren & (~i_conf_addr[`BIT_CONF]) & 
                    (i_conf_addr[1:0] == i_ram)   ),  
          .addra  (i_conf_addr                    ),
          .dina   (i_conf_wdata                   ),
          .douta  (o_conf_rdata                   ),
          .web    ('b0                            ),  
          .addrb  ({2'b0,w_mm_addr[31:2]}         ),
          .dinb   ('b0                            ),
          .doutb  (w_mm_rdata[i_ram*32+:32]       )
        );
        
        //* data;
        memory_part_8KB data_mem(
          .clk    (i_clk                          ),
          .rst_n  (i_rst_n                        ),
          .wea    (wren_data_a[i_ram*4+:4]        ),  
          .addra  (addr_data_a[i_ram*32+:32]      ),
          .dina   (din_data_a[i_ram*32+:32]       ),
          .douta  (dout_data_a[i_ram*32+:32]      ),
          .web    (wren_data_b[i_ram*4+:4]        ),  
          .addrb  (addr_data_b[i_ram*32+:32]      ),
          .dinb   (din_data_b[i_ram*32+:32]       ),
          .doutb  (dout_data_b[i_ram*32+:32]      )
        );
      `endif
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  
  //====================================================================//
  //*   input for MUX
  //====================================================================//
  //* input for mux;
  `ifdef PE3_EN
    //* data mux;
    assign w_rden_dmux_pe4_conf = (i_conf_rden&i_conf_addr[`BIT_CONF]) | ((~i_data_we[3])&i_data_req[3]);
    assign w_wren_dmux_pe4_conf = (i_conf_wren&i_conf_addr[`BIT_CONF]) | (i_data_we[3]&i_data_req[3]);
    assign w_wstrb_dmux_pe4_conf= (i_conf_wren)? {4{i_conf_wren}}: i_data_be[3*4+:4];
    assign w_addr_dmux_pe4_conf = (i_conf_rden|i_conf_wren)? i_conf_addr: i_data_addr[3*32+:32];
    assign w_wdata_dmux_pe4_conf= (i_conf_wren)? i_conf_wdata: i_data_wdata[3*32+:32];
  `else
    //* data mux;
    assign w_rden_dmux_pe4_conf = (i_conf_rden&i_conf_addr[`BIT_CONF]);
    assign w_wren_dmux_pe4_conf = (i_conf_wren&i_conf_addr[`BIT_CONF]);
    assign w_wstrb_dmux_pe4_conf= {4{i_conf_wren}};
    assign w_addr_dmux_pe4_conf = i_conf_addr;
    assign w_wdata_dmux_pe4_conf= i_conf_wdata;
  `endif

  `ifdef PE3_EN
    assign w_rden_mux_pe4_dDMA = i_dma_rden[3];
    assign w_wren_mux_pe4_dDMA = i_dma_wren[3];
    assign w_addr_mux_pe4_dDMA = i_dma_addr[3*32+:32];
    assign w_wdata_mux_pe4_dDMA= i_dma_wdata[3*32+:32];
  `elsif AIPE_EN
    assign w_rden_mux_pe4_dDMA = i_dDMA_rden;
    assign w_wren_mux_pe4_dDMA = i_dDMA_wren;
    assign w_addr_mux_pe4_dDMA = i_dDMA_addr;
    assign w_wdata_mux_pe4_dDMA= i_dDMA_wdata;
  `else
    assign w_rden_mux_pe4_dDMA = 1'b0;
    assign w_wren_mux_pe4_dDMA = 1'b0;
    assign w_addr_mux_pe4_dDMA = 32'b0;
    assign w_wdata_mux_pe4_dDMA= 32'b0;
  `endif

  `ifdef PE2_EN
    assign w_data_we[2]     = i_data_we[2];
    assign w_data_req[2]    = i_data_req[2];
    assign w_data_addr[2]   = i_data_addr[2*32+:32];
    assign w_data_wdata[2]  = i_data_wdata[2*32+:32];
    assign w_data_be[2]     = i_data_be[2*4+:4];
    assign w_dma_rden[2]    = i_dma_rden[2];
    assign w_dma_wren[2]    = i_dma_wren[2];
    assign w_dma_addr[2]    = i_dma_addr[2*32+:32];
    assign w_dma_wdata[2]   = i_dma_wdata[2*32+:32];
  `else
    assign w_data_we[2]     = 1'b0;
    assign w_data_req[2]    = 1'b0;
    assign w_data_addr[2]   = 32'b0;
    assign w_data_wdata[2]  = 32'b0;
    assign w_data_be[2]     = 4'b0;
    assign w_dma_rden[2]    = 1'b0;
    assign w_dma_wren[2]    = 1'b0;
    assign w_dma_addr[2]    = 32'b0;
    assign w_dma_wdata[2]   = 32'b0;
  `endif

  `ifdef PE1_EN
    assign w_data_we[1]     = i_data_we[1];
    assign w_data_req[1]    = i_data_req[1];
    assign w_data_addr[1]   = i_data_addr[1*32+:32];
    assign w_data_wdata[1]  = i_data_wdata[1*32+:32];
    assign w_data_be[1]     = i_data_be[1*4+:4];
    assign w_dma_rden[1]    = i_dma_rden[1];
    assign w_dma_wren[1]    = i_dma_wren[1];
    assign w_dma_addr[1]    = i_dma_addr[1*32+:32];
    assign w_dma_wdata[1]   = i_dma_wdata[1*32+:32];
  `else
    assign w_data_we[1]     = 1'b0;
    assign w_data_req[1]    = 1'b0;
    assign w_data_addr[1]   = 32'b0;
    assign w_data_wdata[1]  = 32'b0;
    assign w_data_be[1]     = 4'b0;
    assign w_dma_rden[1]    = 1'b0;
    assign w_dma_wren[1]    = 1'b0;
    assign w_dma_addr[1]    = 32'b0;
    assign w_dma_wdata[1]   = 32'b0;
  `endif

    assign w_data_we[0]     = i_data_we[0];
    assign w_data_req[0]    = i_data_req[0];
    assign w_data_addr[0]   = i_data_addr[0*32+:32];
    assign w_data_wdata[0]  = i_data_wdata[0*32+:32];
    assign w_data_be[0]     = i_data_be[0*4+:4];
    assign w_dma_rden[0]    = i_dma_rden[0];
    assign w_dma_wren[0]    = i_dma_wren[0];
    assign w_dma_addr[0]    = i_dma_addr[0*32+:32];
    assign w_dma_wdata[0]   = i_dma_wdata[0*32+:32];
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  
  //====================================================================//
  //*   ouput for DMUX
  //====================================================================//
  //* output for DMUX
  // assign o_conf_rdata       = (rvalid_instr_mux_a[0] == 1'b1)? rdata_instr_mux_a[0+:32]: 
  //                               (rvalid_data_mux_a[0] == 1'b1)? rdata_data_mux_a[0+:32]: 32'b0;
  `ifdef PE3_EN
    assign o_data_rvalid[3]       = (i_conf_en[3] == 1'b0)? rvalid_data_mux_a[0]: 1'b0;
    assign o_data_rdata[3*32+:32] = rdata_data_mux_a[0+:32];
    assign o_dma_rvalid[3]        = rvalid_data_mux_b[3];
    assign o_dma_rdata[3*32+:32]  = rdata_data_mux_b[32*3+:32];
  `endif
  `ifdef PE2_EN
    assign o_data_rvalid[2]       = rvalid_data_mux_b[0];
    assign o_data_rdata[2*32+:32] = rdata_data_mux_b[0+:32];
    assign o_dma_rvalid[2]        = rvalid_data_mux_b[2];
    assign o_dma_rdata[2*32+:32]  = rdata_data_mux_b[32*2+:32];
  `endif
  `ifdef PE1_EN
    assign o_data_rvalid[1]       = rvalid_data_mux_a[2];
    assign o_data_rdata[1*32+:32] = rdata_data_mux_a[2*32+:32];
    assign o_dma_rvalid[1]        = rvalid_data_mux_b[1];
    assign o_dma_rdata[1*32+:32]  = rdata_data_mux_b[32*1+:32];
  `endif
    assign o_data_rvalid[0]       = rvalid_data_mux_a[1];
    assign o_data_rdata[0*32+:32] = rdata_data_mux_a[1*32+:32];
    assign o_dma_rvalid[0]        = rvalid_data_mux_a[3];
    assign o_dma_rdata[0*32+:32]  = rdata_data_mux_a[32*3+:32];
  `ifdef AIPE_EN
    assign o_dDMA_rvalid          = rvalid_data_mux_b[3];
    assign o_dDMA_rdata           = rdata_data_mux_b[32*3+:32];
  `endif


  //* gnt is valid when peID corresponding bit is '1', or req is '0', TODO;  
  `ifdef PE3_EN
    assign o_data_gnt[3]    = 1'b1;
    assign o_dma_gnt[3]     = peID_data_b[15]  | 
                              peID_data_b[11]  | 
                              peID_data_b[7]   | 
                              peID_data_b[3]   | ~(i_dma_rden[3]|i_dma_wren[3]); 
  `endif
  `ifdef PE2_EN
    assign o_data_gnt[2]    = 1'b1;
    assign o_dma_gnt[2]     = peID_data_b[14]  | 
                              peID_data_b[10]  | 
                              peID_data_b[6]   | 
                              peID_data_b[2]   | ~(i_dma_rden[2]|i_dma_wren[2]);
  `endif
  `ifdef PE1_EN
    assign o_data_gnt[1]    = peID_data_a[14]  | 
                              peID_data_a[10]  | 
                              peID_data_a[6]   | 
                              peID_data_a[2]   | ~i_data_req[1];
    assign o_dma_gnt[1]     = peID_data_b[13]  | 
                              peID_data_b[9]   | 
                              peID_data_b[5]   | 
                              peID_data_b[1]   | ~(i_dma_rden[1]|i_dma_wren[1]); 
  `endif
  assign o_data_gnt[0]      = peID_data_a[13]  | 
                              peID_data_a[9]   | 
                              peID_data_a[5]   | 
                              peID_data_a[1]   | ~i_data_req[0]; 
  assign o_dma_gnt[0]       = peID_data_a[15]  | 
                              peID_data_a[11]  | 
                              peID_data_a[7]   | 
                              peID_data_a[3]   | ~(i_dma_rden[0]|i_dma_wren[0]); 
  `ifdef AIPE_EN
    //* dDMA;
    assign o_dDMA_gnt       = peID_data_b[15]  | 
                              peID_data_b[11]  | 
                              peID_data_b[7]   | 
                              peID_data_b[3]   | ~(i_dDMA_rden|i_dDMA_wren);
  `endif

  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule