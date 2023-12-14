/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Icache_Top.
 *  Description:        instr cache of timelyRV core.
 *  Last updated date:  2023.12.06.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2023 NUDT.
 *
 *  Noted:
 */

module iCache_Top 
#(
    parameter TAG_ADDR_WIDTH          = 6,
    parameter TAG_WIDTH               = 8,  // valid + tag_addr;
    parameter DATA_WIDTH              = 128,
    parameter N_WAY                   = 4
)
(
  //* clk & reset;
  input   wire                        i_clk,
  input   wire                        i_rst_n,

  //* interface for PEs (instr.);
  input   wire  [`NUM_PE-1:0]         i_icache_req,
  input   wire  [`NUM_PE-1:0][31:0]   i_icache_addr,
  output  wire  [`NUM_PE-1:0][31:0]   o_icache_rdata,
  output  wire  [`NUM_PE-1:0]         o_icache_rvalid,
  output  wire  [`NUM_PE-1:0]         o_icache_gnt,

  //* interface for reading SRAM by Icache;
  output  wire                        o_mm_rden,
  output  wire  [             31:0]   o_mm_addr,
  input   wire  [            127:0]   i_mm_rdata,
  input   wire                        i_mm_rvalid,
  input   wire                        i_mm_gnt
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire  [`NUM_PE-1:0]                                 w_inst_tag_rden;
  wire  [`NUM_PE-1:0][TAG_ADDR_WIDTH-1:0]             w_inst_tag_addr;
  wire  [`NUM_PE-1:0][N_WAY-1:0][TAG_WIDTH-1:0]       w_inst_tag_rdata;
  wire  [`NUM_PE-1:0][N_WAY-1:0][DATA_WIDTH-1:0]      w_inst_data_rdata;
  wire               [N_WAY-1:0]                      w_inst_tag_upd;
  wire                          [TAG_ADDR_WIDTH-1:0]  w_inst_tag_addr_upd;
  wire                          [TAG_WIDTH-1:0]       w_inst_tag_wdata_upd;
  wire                          [DATA_WIDTH-1:0]      w_inst_data_wdata_upd;

  wire  [`NUM_PE-1:0]                                 w_cache_miss;
  wire  [`NUM_PE-1:0][31:0]                           w_addr_miss;
  wire  [`NUM_PE-1:0][N_WAY-1:0]                      w_vic_miss;
  wire  [`NUM_PE-1:0]                                 w_resp_miss;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
    Register_File_Multi_Port
    #(
       .ADDR_WIDTH    ( TAG_ADDR_WIDTH      ),
       .DATA_WIDTH    ( TAG_WIDTH           ),
       .N_READ        ( `NUM_PE             ),
       .N_WAY         ( N_WAY               )
    )
    inst_tag
    (
       .i_clk         (i_clk                ),
       .i_rst_n       (i_rst_n              ),

       .i_ReadEnable  (w_inst_tag_rden      ),
       .i_ReadAddr    (w_inst_tag_addr      ),
       .o_ReadData    (w_inst_tag_rdata     ),

       .i_WriteEnable (w_inst_tag_upd       ),
       .i_WriteAddr   (w_inst_tag_addr_upd  ),
       .i_WriteData   (w_inst_tag_wdata_upd )
    );


   Register_File_Multi_Port
   #(
      .ADDR_WIDTH    ( TAG_ADDR_WIDTH       ),
      .DATA_WIDTH    ( DATA_WIDTH           ),
      .N_READ        ( `NUM_PE              )
   )
   inst_data
   (
      .i_clk         (i_clk                 ),
      .i_rst_n       (i_rst_n               ),

      .i_ReadEnable   (w_inst_tag_rden      ),
      .i_ReadAddr     (w_inst_tag_addr      ),
      .o_ReadData     (w_inst_data_rdata    ),

      .i_WriteEnable  (w_inst_tag_upd       ),
      .i_WriteAddr    (w_inst_tag_addr_upd  ),
      .i_WriteData    (w_inst_data_wdata_upd)
   );

  genvar gidx;
  generate
    for (gidx = 0; gidx < `NUM_PE; gidx=gidx+1) begin : icache_search_pes
      iCache_Search
      #(
        .ADDR_WIDTH     ( TAG_ADDR_WIDTH        ),
        .TAG_WIDTH      ( TAG_WIDTH             ),
        .DATA_WIDTH     ( DATA_WIDTH            ),
        .N_WAY          ( N_WAY                 ),
        .ID_WAY         ( 4'b1 << gidx          )
      )
      icache_search
      (
        .i_clk          (i_clk                  ),
        .i_rst_n        (i_rst_n                ),

        .i_icache_req   (i_icache_req[gidx]     ),
        .i_icache_addr  (i_icache_addr[gidx]    ),
        .o_icache_rdata (o_icache_rdata[gidx]   ),
        .o_icache_rvalid(o_icache_rvalid[gidx]  ),
        .o_icache_gnt   (o_icache_gnt[gidx]     ),

        .o_tag_rden     (w_inst_tag_rden[gidx]  ),
        .o_tag_addr     (w_inst_tag_addr[gidx]  ),
        .i_tag_rdata    (w_inst_tag_rdata[gidx] ),
        .i_data_rdata   (w_inst_data_rdata[gidx]),

        .o_cache_miss   (w_cache_miss[gidx]     ),
        .o_addr_miss    (w_addr_miss[gidx]      ),
        .o_vic_miss     (w_vic_miss[gidx]       ),
        .i_resp_miss    (w_resp_miss[gidx]      )
      );
    end
  endgenerate

  iCache_Update
  #(
    .ADDR_WIDTH     ( TAG_ADDR_WIDTH    ),
    .TAG_WIDTH      ( TAG_WIDTH         ),
    .DATA_WIDTH     ( DATA_WIDTH        ),
    .N_WAY          ( N_WAY             )
  )
  icache_update
  (
    .i_clk          (i_clk              ),
    .i_rst_n        (i_rst_n            ),

    .i_cache_miss   (w_cache_miss       ),
    .i_addr_miss    (w_addr_miss        ),
    .i_vic_miss     (w_vic_miss         ),
    .o_resp_miss    (w_resp_miss        ),

    .o_mm_rden      (o_mm_rden          ),
    .o_mm_addr      (o_mm_addr          ),
    .i_mm_gnt       (i_mm_gnt           ),
    .i_mm_rdata     (i_mm_rdata         ),
    .i_mm_rvalid    (i_mm_rvalid        ),

    .o_inst_tag_upd         (w_inst_tag_upd       ),
    .o_inst_tag_addr_upd    (w_inst_tag_addr_upd  ),
    .o_inst_tag_wdata_upd   (w_inst_tag_wdata_upd ),
    .o_inst_data_wdata_upd  (w_inst_data_wdata_upd)
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule