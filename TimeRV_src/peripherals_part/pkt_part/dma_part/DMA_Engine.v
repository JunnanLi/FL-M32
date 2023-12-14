/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Engine.
 *  Description:        This module is used to dma packets.
 *  Last updated date:  2022.06.16.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module DMA_Engine(
   input  wire                    i_clk
  ,input  wire                    i_rst_n

  //* data to DMA;
  ,(* mark_debug = "true"*)input  wire                    i_data_valid
  ,(* mark_debug = "true"*)input  wire  [         133:0]  i_data
  ,output wire  [   `NUM_PE-1:0]  o_alf_dma
  //* data to output;
  ,output wire                    o_data_valid
  ,output wire  [         133:0]  o_data
  //* DMA (communicaiton with data SRAM);
  ,(* mark_debug = "true"*)output wire  [   `NUM_PE-1:0]  o_dma_rden
  ,(* mark_debug = "true"*)output wire  [   `NUM_PE-1:0]  o_dma_wren
  ,(* mark_debug = "true"*)output wire  [`NUM_PE*32-1:0]  o_dma_addr
  ,(* mark_debug = "true"*)output wire  [`NUM_PE*32-1:0]  o_dma_wdata
  ,(* mark_debug = "true"*)input  wire  [`NUM_PE*32-1:0]  i_dma_rdata
  ,(* mark_debug = "true"*)input  wire  [   `NUM_PE-1:0]  i_dma_rvalid
  ,(* mark_debug = "true"*)input  wire  [   `NUM_PE-1:0]  i_dma_gnt
  //* configuration interface for DMA;
  ,(* mark_debug = "true"*)input  wire  [   `NUM_PE-1:0]  i_peri_rden
  ,(* mark_debug = "true"*)input  wire  [   `NUM_PE-1:0]  i_peri_wren
  ,(* mark_debug = "true"*)input  wire  [`NUM_PE*32-1:0]  i_peri_addr
  ,(* mark_debug = "true"*)input  wire  [`NUM_PE*32-1:0]  i_peri_wdata
  ,(* mark_debug = "true"*)input  wire  [ `NUM_PE*4-1:0]  i_peri_wstrb
  ,(* mark_debug = "true"*)output wire  [`NUM_PE*32-1:0]  o_peri_rdata
  ,(* mark_debug = "true"*)output wire  [   `NUM_PE-1:0]  o_peri_ready
  ,(* mark_debug = "true"*)output wire  [   `NUM_PE-1:0]  o_peri_int
  //* debug;
  ,output wire  [           2:0]  d_dmaDist_inc_pkt_3b   
  ,output wire                    d_dmaDist_state_dist_1b
  ,output wire  [           3:0]  d_dmaOut_state_out_4b

  ,output wire  [           2:0]  d_alf_dma_3b      
  ,output wire  [           2:0]  d_empty_dmaWR_3b  
  ,output wire  [          29:0]  d_usedw_dmaWR_30b 
  ,output wire  [           2:0]  d_empty_pBufWR_3b 
  ,output wire  [           2:0]  d_empty_pBufRD_3b 
  ,output wire  [          29:0]  d_usedw_pBufRD_30b
  ,output wire  [           2:0]  d_empty_int_3b    
  ,output wire  [           2:0]  d_empty_length_3b 
  ,output wire  [           2:0]  d_empty_low16b_3b 
  ,output wire  [           2:0]  d_empty_high16b_3b
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* fifo;
  //* dmaWR for data to write to SRAM;
  wire  [   `NUM_PE-1:0]    w_rden_dmaWR, w_wren_dmaWR;
  wire  [         133:0]    w_dout_dmaWR[`NUM_PE-1:0], w_din_dmaWR;
  wire  [   `NUM_PE-1:0]    w_empty_dmaWR;
  wire  [`NUM_PE*10-1:0]    w_usedw_dmaWR;

  //* pBufWR for data to write to SRAM (pBuf addr);
  //* pBufRD for data to read from SRAM (pBuf addr);
  wire  [   `NUM_PE-1:0]    w_rden_pBufWR, w_rden_pBufRD, w_wren_pBufWR, w_wren_pBufRD;
  wire  [          47:0]    w_dout_pBufWR[`NUM_PE-1:0];
  wire  [          63:0]    w_dout_pBufRD[`NUM_PE-1:0];
  wire  [   `NUM_PE-1:0]    w_empty_pBufWR, w_empty_pBufRD;
  wire  [           9:0]    w_usedw_pBufRD[`NUM_PE-1:0];
  wire  [          47:0]    w_din_pBufWR[`NUM_PE-1:0];
  wire  [          63:0]    w_din_pBufRD[`NUM_PE-1:0];

  //* int for finishing writing/reading SRAM event;
  wire  [          31:0]    w_din_int[`NUM_PE-1:0];
  wire  [   `NUM_PE-1:0]    w_wren_int, w_rden_int;
  wire  [          31:0]    w_dout_int[`NUM_PE-1:0];
  wire  [   `NUM_PE-1:0]    w_empty_int;

  //* length;
  wire  [          15:0]    w_din_length;
  wire  [   `NUM_PE-1:0]    w_wren_length, w_rden_length;
  wire  [          15:0]    w_dout_length[`NUM_PE-1:0];
  wire  [   `NUM_PE-1:0]    w_empty_length;
  
  //* for output data (two 16b fifo);
  wire  [`NUM_PE*20-1:0]    w_din_low16b;
  wire  [`NUM_PE*17-1:0]    w_din_high16b;
  wire  [   `NUM_PE-1:0]    w_wren_low16b, w_rden_low16b, w_wren_high16b, w_rden_high16b;
  wire  [`NUM_PE*20-1:0]    w_dout_low16b;
  wire  [`NUM_PE*17-1:0]    w_dout_high16b;
  wire  [   `NUM_PE-1:0]    w_empty_low16b, w_empty_high16b;
  wire  [           8:0]    w_usedw_32b[`NUM_PE-1:0];

  //* filter pkt;
  wire  [   `NUM_PE-1:0]    w_filter_en;
  wire  [   `NUM_PE-1:0]    w_filter_dmac_en;
  wire  [   `NUM_PE-1:0]    w_filter_smac_en;
  wire  [   `NUM_PE-1:0]    w_filter_type_en;
  wire  [ `NUM_PE*8-1:0]    w_filter_dmac   ;
  wire  [ `NUM_PE*8-1:0]    w_filter_smac   ;
  wire  [ `NUM_PE*8-1:0]    w_filter_type   ;

  //* wait new pBufWR;
  wire  [   `NUM_PE-1:0]    w_wait_free_pBufWR;
  //* start_en, '1' is valid;
  wire  [   `NUM_PE-1:0]    w_start_en;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //*   Dispatch
  //==============================================================//
  DMA_Dispatch DMA_Dispatch(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* TODO, to be deleted, calc pkt's length;
    .i_pkt_valid            (i_data_valid             ),
    .i_pkt                  (i_data                   ),
    .o_pkt_valid            (w_wren_dmaWR             ),
    .o_pkt                  (w_din_dmaWR              ),
    .i_usedw_dmaWR          (w_usedw_dmaWR            ),
    //* length out;
    .o_din_length           (w_din_length             ),
    .o_wren_length          (w_wren_length            ),
    //* filter pkt;
    .i_filter_en            (w_filter_en              ),
    .i_filter_dmac_en       (w_filter_dmac_en         ),
    .i_filter_smac_en       (w_filter_smac_en         ),
    .i_filter_type_en       (w_filter_type_en         ),
    .i_filter_dmac          (w_filter_dmac            ),
    .i_filter_smac          (w_filter_smac            ),
    .i_filter_type          (w_filter_type            ), 
    //* start_en
    .i_start_en             (w_start_en               ),
    //* debug;
    .d_inc_pkt_3b           (d_dmaDist_inc_pkt_3b     ),
    .d_state_dist_1b        (d_dmaDist_state_dist_1b  )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //*   DMA_Out_Data
  //==============================================================//
  DMA_Out_Data DMA_Out_Data(
    //* clk & rst_n;
    .i_clk                  (i_clk                    ),
    .i_rst_n                (i_rst_n                  ),
    //* pkt out;
    .o_data_valid           (o_data_valid             ),
    .o_data                 (o_data                   ),
    //* 16b data in;
    .o_rden_low16b          (w_rden_low16b            ),
    .i_dout_low16b          (w_dout_low16b            ),
    .o_rden_high16b         (w_rden_high16b           ),
    .i_dout_high16b         (w_dout_high16b           ),
    .i_wren_16b             (w_wren_high16b           ),
    `ifdef PE3_EN
      .i_endTag             ({w_din_high16b[17*4-1],
                              w_din_high16b[17*3-1],
                              w_din_high16b[17*2-1],
                              w_din_high16b[17*1-1]}  ),
    `elsif PE2_EN
      .i_endTag             ({w_din_high16b[17*3-1],
                              w_din_high16b[17*2-1],
                              w_din_high16b[17*1-1]}  ),
    `elsif PE1_EN
      .i_endTag             ({w_din_high16b[17*2-1],
                              w_din_high16b[17*1-1]}  ),
    `else
      .i_endTag             ( w_din_high16b[16]       ),
    `endif
    //* debug;
    .d_state_out_4b         (d_dmaOut_state_out_4b    )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe=i_pe+1) begin : DMA_PE
      //======================= DMA_Wr_Rd_DataRam =======================//
      DMA_Wr_Rd_DataRAM DMA_Wr_Rd_DataRam(
        //* clk & rst_n;
        .i_clk                  (i_clk                    ),
        .i_rst_n                (i_rst_n                  ),
        //* pkt in;
        .i_empty_data           (w_empty_dmaWR[i_pe]      ),
        .o_data_rden            (w_rden_dmaWR[i_pe]       ),
        .i_data                 (w_dout_dmaWR[i_pe]       ),
        //* 16b data out;
        .o_din_low16b           (w_din_low16b[i_pe*20+:20]),
        .o_wren_low16b          (w_wren_low16b[i_pe]      ),
        .o_din_high16b          (w_din_high16b[i_pe*17+:17]),
        .o_wren_high16b         (w_wren_high16b[i_pe]     ),
        .i_usedw_9b             (w_usedw_32b[i_pe]        ),
        //* dma interface;
        .o_dma_rden             (o_dma_rden[i_pe]         ),
        .o_dma_wren             (o_dma_wren[i_pe]         ),
        .o_dma_addr             (o_dma_addr[i_pe*32+:32]  ),
        .o_dma_wdata            (o_dma_wdata[i_pe*32+:32] ),
        .i_dma_rdata            (i_dma_rdata[i_pe*32+:32] ),
        .i_dma_rvalid           (i_dma_rvalid[i_pe]       ),
        .i_dma_gnt              (i_dma_gnt[i_pe]          ),
        //* pBuf in interface;
        .o_rden_pBufWR          (w_rden_pBufWR[i_pe]      ),
        .i_dout_pBufWR          (w_dout_pBufWR[i_pe]      ),
        .i_empty_pBufWR         (w_empty_pBufWR[i_pe]     ),
        .o_rden_pBufRD          (w_rden_pBufRD[i_pe]      ),
        .i_dout_pBufRD          (w_dout_pBufRD[i_pe]      ),
        .i_empty_pBufRD         (w_empty_pBufRD[i_pe]     ),
        .i_usedw_pBufRD         (w_usedw_pBufRD[i_pe]     ),
        //* wait free pBufWR;
        .o_wait_free_pBufWR     (w_wait_free_pBufWR[i_pe] ),
        //* int out;
        .o_din_int              (w_din_int[i_pe]          ),
        .o_wren_int             (w_wren_int[i_pe]         )
      );
      //==============================================================//

      //======================= DMA Peri       =======================//
      DMA_Peri DMA_Peri(
        //* clk & rst_n;
        .i_clk                  (i_clk                    ),
        .i_rst_n                (i_rst_n                  ),
        //* periperal interface;
        .i_peri_rden            (i_peri_rden[i_pe]        ),
        .i_peri_wren            (i_peri_wren[i_pe]        ),
        .i_peri_addr            (i_peri_addr[i_pe*32+:32] ),
        .i_peri_wdata           (i_peri_wdata[i_pe*32+:32]),
        .i_peri_wstrb           (i_peri_wstrb[i_pe*4+:4]  ),
        .o_peri_rdata           (o_peri_rdata[i_pe*32+:32]),
        .o_peri_ready           (o_peri_ready[i_pe]       ),
        .o_peri_int             (o_peri_int[i_pe]         ),
        //* pBuf out;
        .o_din_pBufWR           (w_din_pBufWR[i_pe]       ),
        .o_wren_pBufWR          (w_wren_pBufWR[i_pe]      ),
        .o_din_pBufRD           (w_din_pBufRD[i_pe]       ),
        .o_wren_pBufRD          (w_wren_pBufRD[i_pe]      ),
        //* int in;
        .o_rden_int             (w_rden_int[i_pe]         ),
        .i_dout_int             (w_dout_int[i_pe]         ),
        .i_empty_int            (w_empty_int[i_pe]        ),
        //* length out;
        .o_rden_length          (w_rden_length[i_pe]      ),
        .i_dout_length          (w_dout_length[i_pe]      ),
        .i_empty_length         (w_empty_length[i_pe]     ),
        //* filter pkt;
        .o_filter_en            (w_filter_en[i_pe]        ),
        .o_filter_dmac_en       (w_filter_dmac_en[i_pe]   ),
        .o_filter_smac_en       (w_filter_smac_en[i_pe]   ),
        .o_filter_type_en       (w_filter_type_en[i_pe]   ),
        .o_filter_dmac          (w_filter_dmac[i_pe*8+:8] ),
        .o_filter_smac          (w_filter_smac[i_pe*8+:8] ),
        .o_filter_type          (w_filter_type[i_pe*8+:8] ),
        //* wait free pBufWR;
        .i_wait_free_pBufWR     (w_wait_free_pBufWR[i_pe] ),
        //* start_en
        .o_start_en             (w_start_en[i_pe]         )
      );
      //==============================================================//

      //======================= reset        =======================//
      // DMA_Reset DMA_Reset(
      //   //* clk & rst_n;
      //   .i_clk                  (i_clk                    ),
      //   .i_rst_n                (i_rst_n                  ),
      //   //* reset dma req/resp;
      //   .i_resetDMA_req         (w_resetDMA_req[i_pe]     ),
      //   .i_state_DMA_out        (i_state_DMA_out[i_pe]    ),
      //   .o_resetDMA_resp        (w_resetDMA_resp[i_pe]    )
      // );
      //======================= reset        =======================//
    end
  endgenerate

  //======================= fifos          =======================//
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: fifo_dma
      /** fifo used to buffer pBuf_wr*/
      regfifo_48b_8 fifo_pBufWR (
        .clk                (i_clk                    ),  //* input wire clk
        .srst               (!i_rst_n                 ),  //* input wire srst
        .din                (w_din_pBufWR[i_pe]       ),  //* input wire [47 : 0] din
        .wr_en              (w_wren_pBufWR[i_pe]      ),  //* input wire wr_en
        .rd_en              (w_rden_pBufWR[i_pe]      ),  //* input wire rd_en
        .dout               (w_dout_pBufWR[i_pe]      ),  //* output wire [47 : 0] dout
        .full               (                         ),  //* output wire full
        .empty              (w_empty_pBufWR[i_pe]     )   //* output wire empty
      );

      /** fifo used to buffer pBuf_rd, 16b_length, 32b_addr*/
      regfifo_64b_8 fifo_pBufRD (
        .clk                (i_clk                    ),  //* input wire clk
        .srst               (!i_rst_n                 ),  //* input wire srst
        .din                (w_din_pBufRD[i_pe]       ),  //* input wire [63 : 0] din
        .wr_en              (w_wren_pBufRD[i_pe]      ),  //* input wire wr_en
        .rd_en              (w_rden_pBufRD[i_pe]      ),  //* input wire rd_en
        .dout               (w_dout_pBufRD[i_pe]      ),  //* output wire [63 : 0] dout
        .full               (                         ),  //* output wire full
        .empty              (w_empty_pBufRD[i_pe]     ),  //* output wire empty
        .data_count         (w_usedw_pBufRD[i_pe]     )
      );

      /** fifo used to buffer interrupt, 1b_wr/rd, 32b_addr, '1' is wr*/ 
      regfifo_32b_4 fifo_int (
        .clk                (i_clk                    ),  //* input wire clk
        .srst               (!i_rst_n                 ),  //* input wire srst
        .din                (w_din_int[i_pe]          ),  //* input wire [31 : 0] din
        .wr_en              (w_wren_int[i_pe]         ),  //* input wire wr_en
        .rd_en              (w_rden_int[i_pe]         ),  //* input wire rd_en
        .dout               (w_dout_int[i_pe]         ),  //* output wire [31 : 0] dout
        .full               (                         ),  //* output wire full
        .empty              (w_empty_int[i_pe]        )   //* output wire empty
      );

      `ifdef XILINX_FIFO_RAM
        //* fifo used to buffer dma pkt;
        fifo_134b_512 fifo_dmaWR (
          .clk                (i_clk                    ),  //* input wire clk
          .srst               (!i_rst_n                 ),  //* input wire srst
          .din                (w_din_dmaWR              ),  //* input wire [133 : 0] din
          .wr_en              (w_wren_dmaWR[i_pe]       ),  //* input wire wr_en
          .rd_en              (w_rden_dmaWR[i_pe]       ),  //* input wire rd_en
          .dout               (w_dout_dmaWR[i_pe]       ),  //* output wire [133 : 0] dout
          .full               (                         ),  //* output wire full
          .empty              (w_empty_dmaWR[i_pe]      ),  //* output wire empty
          .data_count         (w_usedw_dmaWR[i_pe*10+:10])
        );

        /** fifo used to buffer pBuf_wr*/
        fifo_16b_512 fifo_length (
          .clk                (i_clk                    ),  //* input wire clk
          .srst               (!i_rst_n                 ),  //* input wire srst
          .din                (w_din_length             ),  //* input wire [16 : 0] din
          .wr_en              (w_wren_length[i_pe]      ),  //* input wire wr_en
          .rd_en              (w_rden_length[i_pe]      ),  //* input wire rd_en
          .dout               (w_dout_length[i_pe]      ),  //* output wire [16 : 0] dout
          .full               (                         ),  //* output wire full
          .empty              (w_empty_length[i_pe]     )   //* output wire empty
        );

        /** fifo used to output data*/
        fifo_17b_512 fifo_high16b (  //* high 16b;
          .clk                (i_clk                    ),  //* input wire clk
          .srst               (!i_rst_n                 ),  //* input wire srst
          .din                (w_din_high16b[i_pe*17+:17]), //* input wire [16 : 0] din
          .wr_en              (w_wren_high16b[i_pe]     ),  //* input wire wr_en
          .rd_en              (w_rden_high16b[i_pe]     ),  //* input wire rd_en
          .dout               (w_dout_high16b[i_pe*17+:17]),//* output wire [16 : 0] dout
          .full               (                         ),  //* output wire full
          .empty              (w_empty_high16b[i_pe]    ),  //* output wire empty
          .data_count         (w_usedw_32b[i_pe]        )
        );
        fifo_20b_512 fifo_low16b (  //* low 16b;
          .clk                (i_clk                    ),  //* input wire clk
          .srst               (!i_rst_n                 ),  //* input wire srst
          .din                (w_din_low16b[i_pe*20+:20]),  //* input wire [19 : 0] din
          .wr_en              (w_wren_low16b[i_pe]      ),  //* input wire wr_en
          .rd_en              (w_rden_low16b[i_pe]      ),  //* input wire rd_en
          .dout               (w_dout_low16b[i_pe*20+:20]), //* output wire [19 : 0] dout
          .full               (                         ),  //* output wire full
          .empty              (w_empty_low16b[i_pe]     )   //* output wire empty
        );
      `elsif SIM_FIFO_RAM
        //* fifo used to buffer dma pkt;
        syncfifo fifo_dmaWR (
          .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_dmaWR              ),  //* The Inport of data 
          .wrreq                (w_wren_dmaWR[i_pe]       ),  //* active-high
          .rdreq                (w_rden_dmaWR[i_pe]       ),  //* active-high
          .q                    (w_dout_dmaWR[i_pe]       ),  //* The output of data
          .empty                (w_empty_dmaWR[i_pe]      ),  //* Read domain empty
          .usedw                (w_usedw_dmaWR[i_pe*10+:7]),  //* Usedword
          .full                 (                         )   //* Full
        );
        defparam  fifo_dmaWR.width = 134,
                  fifo_dmaWR.depth = 7,
                  fifo_dmaWR.words = 128;
        assign w_usedw_dmaWR[(i_pe*10+7)+:3] = 3'b0;

        /** fifo used to buffer pBuf_wr*/
        syncfifo fifo_length (
          .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_length             ),  //* The Inport of data 
          .wrreq                (w_wren_length[i_pe]      ),  //* active-high
          .rdreq                (w_rden_length[i_pe]      ),  //* active-high
          .q                    (w_dout_length[i_pe]      ),  //* The output of data
          .empty                (w_empty_length[i_pe]     ),  //* Read domain empty
          .usedw                (                         ),  //* Usedword
          .full                 (                         )   //* Full
        );
        defparam  fifo_length.width = 16,
                  fifo_length.depth = 5,
                  fifo_length.words = 32;

        /** fifo used to output data*/
        syncfifo fifo_high16b (
          .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_high16b[i_pe*17+:17]), //* The Inport of data 
          .wrreq                (w_wren_high16b[i_pe]     ),  //* active-high
          .rdreq                (w_rden_high16b[i_pe]     ),  //* active-high
          .q                    (w_dout_high16b[i_pe*17+:17]),//* The output of data
          .empty                (w_empty_high16b[i_pe]    ),  //* Read domain empty
          .usedw                (w_usedw_32b[i_pe]        ),  //* Usedword
          .full                 (                         )   //* Full
        );
        defparam  fifo_high16b.width = 17,
                  fifo_high16b.depth = 9,
                  fifo_high16b.words = 512;
        syncfifo fifo_low16b (
          .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_low16b[i_pe*20+:20]),  //* The Inport of data 
          .wrreq                (w_wren_low16b[i_pe]      ),  //* active-high
          .rdreq                (w_rden_low16b[i_pe]      ),  //* active-high
          .q                    (w_dout_low16b[i_pe*20+:20]), //* The output of data
          .empty                (w_empty_low16b[i_pe]     ),  //* Read domain empty
          .usedw                (                         ),  //* Usedword
          .full                 (                         )   //* Full
        );
        defparam  fifo_low16b.width = 20,
                  fifo_low16b.depth = 9,
                  fifo_low16b.words = 512;
      `else
        // /** fifo used to buffer pBuf_wr*/
        // SYNCFIFO_32x48 fifo_pBufWR (
        //   .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
        //   .aclr                 (!i_rst_n                 ),  //* Reset the all signal
        //   .data                 (w_din_pBufWR[i_pe]       ),  //* The Inport of data 
        //   .wrreq                (w_wren_pBufWR[i_pe]      ),  //* active-high
        //   .rdreq                (w_rden_pBufWR[i_pe]      ),  //* active-high
        //   .q                    (w_dout_pBufWR[i_pe]      ),  //* The output of data
        //   .rdempty              (w_empty_pBufWR[i_pe]     ),  //* Read domain empty
        //   .wrusedw              (                         ),  //* Write-usedword
        //   .rdusedw              (                         )   //* Read-usedword
        // );

        // /** fifo used to buffer pBuf_rd, 16b_length, 32b_addr*/
        // SYNCFIFO_32x64 fifo_pBufRD (
        //   .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
        //   .aclr                 (!i_rst_n                 ),  //* Reset the all signal
        //   .data                 (w_din_pBufRD[i_pe]       ),  //* The Inport of data 
        //   .wrreq                (w_wren_pBufRD[i_pe]      ),  //* active-high
        //   .rdreq                (w_rden_pBufRD[i_pe]      ),  //* active-high
        //   .q                    (w_dout_pBufRD[i_pe]      ),  //* The output of data
        //   .rdempty              (w_empty_pBufRD[i_pe]     ),  //* Read domain empty
        //   .wrusedw              (                         ),  //* Write-usedword
        //   .rdusedw              (w_usedw_pBufRD[i_pe][4:0])   //* Read-usedword
        // );
        // assign w_usedw_pBufRD[i_pe][9:5] = 5'b0;

        // /** fifo used to buffer interrupt, 1b_wr/rd, 32b_addr, '1' is wr*/ 
        // SYNCFIFO_32x32 fifo_int (
        //   .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
        //   .aclr                 (!i_rst_n                 ),  //* Reset the all signal
        //   .data                 (w_din_int[i_pe]          ),  //* The Inport of data 
        //   .wrreq                (w_wren_int[i_pe]         ),  //* active-high
        //   .rdreq                (w_rden_int[i_pe]         ),  //* active-high
        //   .q                    (w_dout_int[i_pe]         ),  //* The output of data
        //   .rdempty              (w_empty_int[i_pe]        ),  //* Read domain empty
        //   .wrusedw              (                         ),  //* Write-usedword
        //   .rdusedw              (                         )   //* Read-usedword
        // );

        //* fifo used to buffer dma pkt;
        SYNCFIFO_128x134 fifo_dmaWR (
          .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_dmaWR              ),  //* The Inport of data 
          .wrreq                (w_wren_dmaWR[i_pe]       ),  //* active-high
          .rdreq                (w_rden_dmaWR[i_pe]       ),  //* active-high
          .q                    (w_dout_dmaWR[i_pe]       ),  //* The output of data
          .rdempty              (w_empty_dmaWR[i_pe]      ),  //* Read domain empty
          .wrusedw              (w_usedw_dmaWR[i_pe*10+:7]),  //* Write-usedword
          .rdusedw              (                         )   //* Read-usedword
        );
        assign w_usedw_dmaWR[(i_pe*10+7)+:3] = 3'b0;

        /** fifo used to buffer pBuf_wr*/
        SYNCFIFO_32x16 fifo_length (
          .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_length             ),  //* The Inport of data 
          .wrreq                (w_wren_length[i_pe]      ),  //* active-high
          .rdreq                (w_rden_length[i_pe]      ),  //* active-high
          .q                    (w_dout_length[i_pe]      ),  //* The output of data
          .rdempty              (w_empty_length[i_pe]     ),  //* Read domain empty
          .wrusedw              (                         ),  //* Write-usedword
          .rdusedw              (                         )   //* Read-usedword
        );

        /** fifo used to output data*/
        SYNCFIFO_512x17 fifo_high16b (
          .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_high16b[i_pe*17+:17]), //* The Inport of data 
          .wrreq                (w_wren_high16b[i_pe]     ),  //* active-high
          .rdreq                (w_rden_high16b[i_pe]     ),  //* active-high
          .q                    (w_dout_high16b[i_pe*17+:17]),//* The output of data
          .rdempty              (w_empty_high16b[i_pe]    ),  //* Read domain empty
          .wrusedw              (w_usedw_32b[i_pe]        ),  //* Write-usedword
          .rdusedw              (                         )   //* Read-usedword
        );
        SYNCFIFO_512x20 fifo_low16b (
          .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
          .aclr                 (!i_rst_n                 ),  //* Reset the all signal
          .data                 (w_din_low16b[i_pe*20+:20]),  //* The Inport of data 
          .wrreq                (w_wren_low16b[i_pe]      ),  //* active-high
          .rdreq                (w_rden_low16b[i_pe]      ),  //* active-high
          .q                    (w_dout_low16b[i_pe*20+:20]), //* The output of data
          .rdempty              (w_empty_low16b[i_pe]     ),  //* Read domain empty
          .wrusedw              (                         ),  //* Write-usedword
          .rdusedw              (                         )   //* Read-usedword
        );
      `endif
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* alf;
  assign o_alf_dma[0]           = w_usedw_dmaWR[9:0]   > 10'd20;
  `ifdef PE1_EN
    assign o_alf_dma[1]         = w_usedw_dmaWR[19:10] > 10'd20;
  `endif
  `ifdef PE2_EN
    assign o_alf_dma[2]         = w_usedw_dmaWR[29:20] > 10'd20;
  `endif
  `ifdef PE3_EN
    assign o_alf_dma[3]         = w_usedw_dmaWR[39:30] > 10'd20;
  `endif

  //* debug;
  assign d_alf_dma_3b           = o_alf_dma;
  assign d_empty_dmaWR_3b       = w_empty_dmaWR;
  assign d_usedw_dmaWR_30b      = w_usedw_dmaWR;
  assign d_empty_pBufWR_3b      = w_empty_pBufWR;
  assign d_empty_pBufRD_3b      = w_empty_pBufRD;
  assign d_usedw_pBufRD_30b     = {w_usedw_pBufRD[2],w_usedw_pBufRD[1],w_usedw_pBufRD[0]};
  assign d_empty_int_3b         = w_empty_int;
  assign d_empty_length_3b      = w_empty_length;
  assign d_empty_low16b_3b      = w_empty_low16b;
  assign d_empty_high16b_3b     = w_empty_high16b;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


endmodule
