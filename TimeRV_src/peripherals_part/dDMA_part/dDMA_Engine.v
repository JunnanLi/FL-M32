/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        dDMA_Engine.
 *  Description:        This module is used to dma data with AiPE.
 *  Last updated date:  2022.08.22.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 */

`timescale 1 ns / 1 ps

module dDMA_Engine(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* DMA (communicaiton with data AiPE);
  ,output wire                    o_dDMA_AIPE_rden
  ,output wire                    o_dDMA_AIPE_wren
  ,output wire  [          31:0]  o_dDMA_AIPE_addr
  ,output wire  [         127:0]  o_dDMA_AIPE_wdata
  ,input  wire  [         127:0]  i_dDMA_AIPE_rdata
  ,input  wire                    i_dDMA_AIPE_rvalid
  //* DMA (communicaiton with data SRAM);
  ,output wire                    o_dDMA_rden
  ,output wire                    o_dDMA_wren
  ,output wire  [          31:0]  o_dDMA_addr
  ,output wire  [          31:0]  o_dDMA_wdata
  ,input  wire  [          31:0]  i_dDMA_rdata
  ,input  wire                    i_dDMA_rvalid
  ,input  wire                    i_dDMA_gnt
  //* configuration interface for DMA;
  ,input  wire  [   `NUM_PE-1:0]  i_peri_rden
  ,input  wire  [   `NUM_PE-1:0]  i_peri_wren
  ,input  wire  [`NUM_PE*32-1:0]  i_peri_addr
  ,input  wire  [`NUM_PE*32-1:0]  i_peri_wdata
  ,input  wire  [ `NUM_PE*4-1:0]  i_peri_wstrb
  ,output wire  [`NUM_PE*32-1:0]  o_peri_rdata
  ,output wire  [   `NUM_PE-1:0]  o_peri_ready
  ,output wire  [   `NUM_PE-1:0]  o_peri_int
  //* debug signals;
  ,output wire                    d_tag_start_dDMA_1b
  ,output wire                    d_tag_resp_dDMA_1b
  ,output wire  [          31:0]  d_addr_RAM_32b     
  ,output wire  [          15:0]  d_len_RAM_16b      
  ,output wire  [          31:0]  d_addr_RAM_AIPE_32b
  ,output wire  [          15:0]  d_len_RAM_AIPE_16b 
  ,output wire                    d_dir_1b     
  ,output wire  [           3:0]  d_cnt_pe0_rd_4b
  ,output wire  [           3:0]  d_cnt_pe0_wr_4b
  ,output wire  [           3:0]  d_cnt_pe1_rd_4b
  ,output wire  [           3:0]  d_cnt_pe1_wr_4b
  ,output wire  [           3:0]  d_cnt_pe2_rd_4b
  ,output wire  [           3:0]  d_cnt_pe2_wr_4b
  ,output wire  [           3:0]  d_state_dDMA_4b
  ,output wire  [           3:0]  d_cnt_int_4b    

);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* wire, connect dMDA_Wr_Rd_Data with dDMA_Peri;
  //* addr/length are byte-aligned;
  //* w_dir: '0' from RAM to AiPE;
  //* w_tag_start_dDMA != w_tag_resp_dDMA, means to request dDMA;
  wire          [31:0]            w_addr_RAM, w_addr_RAM_AIPE;
  wire          [15:0]            w_len_RAM, w_len_RAM_AIPE;
  wire                            w_dir;
  wire                            w_tag_start_dDMA, w_tag_resp_dDMA;
  //* wire, irq;
  //* w_bit_PE, bitmap represents to irq which PE;
  wire                            w_peri_int;
  wire          [`NUM_PE-1:0]     w_bit_PE;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Using dDMA to rd/wr data
  //====================================================================//
  dDMA_Rd_Wr_Data dDMA_Rd_Wr_Data(
    //* clk & rst_n;
    .i_clk                (i_clk                        ),
    .i_rst_n              (i_rst_n                      ),
    //* to aiPE;
    .o_dDMA_AIPE_rden     (o_dDMA_AIPE_rden             ),
    .o_dDMA_AIPE_wren     (o_dDMA_AIPE_wren             ),
    .o_dDMA_AIPE_addr     (o_dDMA_AIPE_addr             ),
    .o_dDMA_AIPE_wdata    (o_dDMA_AIPE_wdata            ),
    .i_dDMA_AIPE_rdata    (i_dDMA_AIPE_rdata            ),
    .i_dDMA_AIPE_rvalid   (i_dDMA_AIPE_rvalid           ),
    //* to DataRAM;
    .o_dDMA_rden          (o_dDMA_rden                  ),
    .o_dDMA_wren          (o_dDMA_wren                  ),
    .o_dDMA_addr          (o_dDMA_addr                  ),
    .o_dDMA_wdata         (o_dDMA_wdata                 ),
    .i_dDMA_rdata         (i_dDMA_rdata                 ),
    .i_dDMA_rvalid        (i_dDMA_rvalid                ),
    .i_dDMA_gnt           (i_dDMA_gnt                   ),
    
    //* dDMA configuring interface;
    .i_tag_start_dDMA     (w_tag_start_dDMA             ),
    .o_tag_resp_dDMA      (w_tag_resp_dDMA              ),
    .i_addr_RAM           (w_addr_RAM                   ),
    .i_len_RAM            (w_len_RAM                    ),
    .i_addr_RAM_AIPE      (w_addr_RAM_AIPE              ),
    .i_len_RAM_AIPE       (w_len_RAM_AIPE               ),
    .i_dir                (w_dir                        ),
    .o_peri_int           (w_peri_int                   ),
    //* debug;
    .d_state_dDMA_4b      (d_state_dDMA_4b              ),
    .d_cnt_int_4b         (d_cnt_int_4b                 )
  );
  assign  o_peri_int      = {3{w_peri_int}} & w_bit_PE;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Configure dDMA by Peri interface;
  //====================================================================//
  dDMA_Peri dDMA_Peri(
    //* clk & rst_n;
    .i_clk                (i_clk                        ),
    .i_rst_n              (i_rst_n                      ),
    //* dDMA configuring interface;
    .o_tag_start_dDMA     (w_tag_start_dDMA             ),
    .i_tag_resp_dDMA      (w_tag_resp_dDMA              ),
    .o_addr_RAM           (w_addr_RAM                   ),
    .o_len_RAM            (w_len_RAM                    ),
    .o_addr_RAM_AIPE      (w_addr_RAM_AIPE              ),
    .o_len_RAM_AIPE       (w_len_RAM_AIPE               ),
    .o_dir                (w_dir                        ),
    //* peri interface;
    .i_peri_rden          (i_peri_rden                  ),
    .i_peri_wren          (i_peri_wren                  ),
    .i_peri_addr          (i_peri_addr                  ),
    .i_peri_wdata         (i_peri_wdata                 ),
    .i_peri_wstrb         (i_peri_wstrb                 ),
    .o_peri_rdata         (o_peri_rdata                 ),
    .o_peri_ready         (o_peri_ready                 ),
    .o_bit_PE             (w_bit_PE                     ),
    //* debug;
    .d_cnt_pe0_rd_4b      (d_cnt_pe0_rd_4b              ),
    .d_cnt_pe0_wr_4b      (d_cnt_pe0_wr_4b              ),
    .d_cnt_pe1_rd_4b      (d_cnt_pe1_rd_4b              ),
    .d_cnt_pe1_wr_4b      (d_cnt_pe1_wr_4b              ),
    .d_cnt_pe2_rd_4b      (d_cnt_pe2_rd_4b              ),
    .d_cnt_pe2_wr_4b      (d_cnt_pe2_wr_4b              )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   debug
  //====================================================================//
  assign d_tag_start_dDMA_1b  = w_tag_start_dDMA;
  assign d_tag_resp_dDMA_1b   = w_tag_resp_dDMA;
  assign d_addr_RAM_32b       = w_addr_RAM;
  assign d_len_RAM_16b        = w_len_RAM;
  assign d_addr_RAM_AIPE_32b  = w_addr_RAM_AIPE;
  assign d_len_RAM_AIPE_16b   = w_len_RAM_AIPE;
  assign d_dir_1b             = w_dir;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
