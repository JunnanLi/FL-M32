/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_Proc_Top.
 *  Description:        This module is used to process pkt (DMA & DRA).
 *  Last updated date:  2022.07.21.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Space = 2;
 */

module Pkt_Proc_Top(
  //* clock & rst_n;
   input  wire                      i_sys_clk   
  ,input  wire                      i_sys_rst_n
  ,input  wire                      i_pe_clk    
  ,input  wire                      i_rst_n     
  //* To/From CPI, TODO
  ,input  wire  [47:0]              i_pe_conf_mac
  ,input  wire                      i_data_valid
  ,input  wire  [133:0]             i_data
  ,output wire                      o_data_valid
  ,output wire  [133:0]             o_data
  ,input  wire                      i_meta_valid
  ,input  wire  [167:0]             i_meta
  ,output wire                      o_meta_valid
  ,output wire  [167:0]             o_meta 
  //* for network configure;
  ,output wire                      o_data_conf_valid
  ,output wire  [133:0]             o_data_conf      
  ,input  wire                      i_data_conf_valid
  ,input  wire  [133:0]             i_data_conf      

  //* Peri interface (DRA, DMA)
  ,input  wire  [`NUM_PE*(`DRA_OUT+1)-1:0]    i_peri_rden 
  ,input  wire  [`NUM_PE*(`DRA_OUT+1)-1:0]    i_peri_wren 
  ,input  wire  [`NUM_PE*32-1:0]              i_peri_addr 
  ,input  wire  [`NUM_PE*32-1:0]              i_peri_wdata
  ,input  wire  [`NUM_PE*4-1:0]               i_peri_wstrb
  ,output wire  [`NUM_PE*(`DRA_OUT+1)*32-1:0] o_peri_rdata
  ,output wire  [`NUM_PE*(`DRA_OUT+1)-1:0]    o_peri_ready
  ,output wire  [`NUM_PE*(`DRA_OUT+1)-1:0]    o_peri_int  
  //* DRA interface, TODO;
  ,input  wire  [`NUM_PE-1:0]       i_reg_rd   
  ,input  wire  [`NUM_PE*32-1:0]    i_reg_raddr
  ,output wire  [511:0]             o_reg_rdata      
  ,output wire  [`NUM_PE-1:0]       o_reg_rvalid     
  ,output wire  [`NUM_PE-1:0]       o_reg_rvalid_desp
  ,input  wire  [`NUM_PE-1:0]       i_reg_wr     
  ,input  wire  [`NUM_PE-1:0]       i_reg_wr_desp
  ,input  wire  [`NUM_PE*32-1:0]    i_reg_waddr  
  ,input  wire  [`NUM_PE*512-1:0]   i_reg_wdata  
  ,input  wire  [`NUM_PE*32-1:0]    i_status     
  ,output wire  [`NUM_PE*32-1:0]    o_status   
  //* DMA interface;
  ,output wire  [`NUM_PE-1:0]       o_dma_rden 
  ,output wire  [`NUM_PE-1:0]       o_dma_wren 
  ,output wire  [`NUM_PE*32-1:0]    o_dma_addr 
  ,output wire  [`NUM_PE*32-1:0]    o_dma_wdata
  ,input  wire  [`NUM_PE*32-1:0]    i_dma_rdata
  ,input  wire  [`NUM_PE-1:0]       i_dma_rvalid
  ,input  wire  [`NUM_PE-1:0]       i_dma_gnt
  //* ready;
  ,output wire                      o_alf
  ,input  wire                      i_alf
  //* debug;
  ,output wire  [3:0]               d_AsynRev_inc_pkt_4b 
  ,output wire  [3:0]               d_PktMUX_state_mux_4b   
  ,output wire                      d_PktMUX_inc_dra_pkt_1b 
  ,output wire                      d_PktMUX_inc_dma_pkt_1b 
  ,output wire                      d_PktMUX_inc_conf_pkt_1b
  ,output wire  [6:0]               d_PktMUX_usedw_pktDMA_7b
  ,output wire  [6:0]               d_PktMUX_usedw_pktDRA_7b
  ,output wire  [6:0]               d_PktMUX_usedw_conf_7b

  ,output wire  [2:0]               d_dmaDist_inc_pkt_3b   
  ,output wire                      d_dmaDist_state_dist_1b
  ,output wire  [3:0]               d_dmaOut_state_out_4b
  ,output wire  [2:0]               d_dma_alf_dma_3b      
  ,output wire  [2:0]               d_dma_empty_dmaWR_3b  
  ,output wire  [29:0]              d_dma_usedw_dmaWR_30b 
  ,output wire  [2:0]               d_dma_empty_pBufWR_3b 
  ,output wire  [2:0]               d_dma_empty_pBufRD_3b 
  ,output wire  [29:0]              d_dma_usedw_pBufRD_30b
  ,output wire  [2:0]               d_dma_empty_int_3b    
  ,output wire  [2:0]               d_dma_empty_length_3b 
  ,output wire  [2:0]               d_dma_empty_low16b_3b 
  ,output wire  [2:0]               d_dma_empty_high16b_3b

  ,output wire                      d_dra_empty_pktRecv_1b 
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_despRecv_3b
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_despSend_3b
  ,output wire  [   `NUM_PE-1:0]    d_dra_empty_writeReq_3b
  ,output wire  [           9:0]    d_dra_usedw_pktRecv_10b
);
  
  //======================= internal reg/wire/param declarations =//
  wire          [133:0]             w_data_to_dma, w_data_from_dma;
  wire          [133:0]             w_data_to_dra, w_data_from_dra;
  wire                              w_data_to_dma_valid, w_data_from_dma_valid;
  wire                              w_data_to_dra_valid, w_data_from_dra_valid;
  //* alf;
  wire          [`NUM_PE-1:0]       w_alf_dma;
  wire                              w_alf_dra;
  wire                              w_alf_pktDist;
  //* peri;
  wire  [`NUM_PE-1:0]               w_peri_rden_dra, w_peri_rden_dma;
  wire  [`NUM_PE-1:0]               w_peri_wren_dra, w_peri_wren_dma;
  wire  [`NUM_PE*32-1:0]            w_peri_rdata_dra, w_peri_rdata_dma;
  wire  [`NUM_PE-1:0]               w_peri_ready_dra, w_peri_ready_dma;
  wire  [`NUM_PE-1:0]               w_peri_int_dra  , w_peri_int_dma  ;
  genvar i_pe;
  generate
    `ifdef DRA_EN
      for (i_pe = 0; i_pe < `NUM_PE; i_pe=i_pe+1) begin : Peri_dma_dra
        assign w_peri_rden_dra[i_pe]      = i_peri_rden[2*i_pe+1];
        assign w_peri_wren_dra[i_pe]      = i_peri_wren[2*i_pe+1];
        assign w_peri_rden_dma[i_pe]      = i_peri_rden[2*i_pe];
        assign w_peri_wren_dma[i_pe]      = i_peri_wren[2*i_pe];
        assign o_peri_rdata[i_pe*64+:64]  = {w_peri_rdata_dra[i_pe*32+:32],w_peri_rdata_dma[i_pe*32+:32]};
        assign o_peri_ready[i_pe*2+:2]    = {w_peri_ready_dra[i_pe],w_peri_ready_dma[i_pe]};
        assign o_peri_int[i_pe*2+:2]      = {w_peri_int_dra[i_pe],w_peri_int_dma[i_pe]};
      end
    `else
      for (i_pe = 0; i_pe < `NUM_PE; i_pe=i_pe+1) begin : Peri_dma
        assign o_peri_rdata[i_pe*64+:64]  = {32'b0,w_peri_rdata_dma[i_pe*32+:32]};
        assign o_peri_ready[i_pe*2+:2]    = {1'b0,w_peri_ready_dma[i_pe]};
        assign o_peri_int[i_pe*2+:2]      = {1'b0,w_peri_int_dma[i_pe]};
        assign w_peri_rden_dma[i_pe]      = i_peri_rden[2*i_pe];
        assign w_peri_wren_dma[i_pe]      = i_peri_wren[2*i_pe];
      end
    `endif
  endgenerate
  //==============================================================//

  //* dispatch;
  Pkt_Distribute Pkt_Distribute(
    //* clk & rst_n;
    .i_pe_clk                 (i_pe_clk                 ),
    .i_rst_n                  (i_rst_n                  ),
    //* interface for recv/send pkt;
    .i_pe_conf_mac            (i_pe_conf_mac            ),
    .i_data_valid             (i_data_valid             ),
    .i_data                   (i_data                   ),
    .o_data_valid             (o_data_valid             ),
    .o_data                   (o_data                   ),
    .i_meta_valid             (i_meta_valid             ),
    .i_meta                   (i_meta                   ),
    .o_meta_valid             (o_meta_valid             ),
    .o_meta                   (o_meta                   ),
    //* for network configuration
    .o_data_conf_valid        (o_data_conf_valid        ),
    .o_data_conf              (o_data_conf              ),
    .i_data_conf_valid        (i_data_conf_valid        ),
    .i_data_conf              (i_data_conf              ),
    //* DMA & DRA;
    .o_data_dma_valid         (w_data_to_dma_valid      ),
    .o_data_dma               (w_data_to_dma            ),
    .o_data_dra_valid         (w_data_to_dra_valid      ),
    .o_data_dra               (w_data_to_dra            ),
    .i_data_dma_valid         (w_data_from_dma_valid    ),
    .i_data_dma               (w_data_from_dma          ),
    .i_data_dra_valid         (w_data_from_dra_valid    ),
    .i_data_dra               (w_data_from_dra          ),
    //* ready
    .o_alf                    (o_alf                    ),
    .i_alf                    (i_alf                    ),
    //* alf;
    .i_alf_dra                (w_alf_dra                ),
    .i_alf_dma                (w_alf_dma                ),
    //* debug;
    .d_AsynRev_inc_pkt_4b     (d_AsynRev_inc_pkt_4b     ),
    .d_PktMUX_state_mux_4b    (d_PktMUX_state_mux_4b    ),
    .d_PktMUX_inc_dra_pkt_1b  (d_PktMUX_inc_dra_pkt_1b  ),
    .d_PktMUX_inc_dma_pkt_1b  (d_PktMUX_inc_dma_pkt_1b  ),
    .d_PktMUX_inc_conf_pkt_1b (d_PktMUX_inc_conf_pkt_1b ),
    .d_PktMUX_usedw_pktDMA_7b (d_PktMUX_usedw_pktDMA_7b ),
    .d_PktMUX_usedw_pktDRA_7b (d_PktMUX_usedw_pktDRA_7b ),
    .d_PktMUX_usedw_conf_7b   (d_PktMUX_usedw_conf_7b   )
  );

  `ifdef DRA_EN
    DRA_Engine DRA_Engine(
      .i_clk                  (i_pe_clk                 ),
      .i_rst_n                (i_rst_n                  ),
      //* interface for recv/send pkt;
      .i_data_valid           (w_data_to_dra_valid      ),
      .i_data                 (w_data_to_dra            ),
      .o_data_valid           (w_data_from_dra_valid    ),
      .o_data                 (w_data_from_dra          ),
      //* alf;
      .o_alf_dra              (w_alf_dra                ),
      //* DRA;
      .i_reg_rd               (i_reg_rd                 ),
      .i_reg_raddr            (i_reg_raddr              ),
      .o_reg_rdata            (o_reg_rdata              ),
      .o_reg_rvalid           (o_reg_rvalid             ),
      .o_reg_rvalid_desp      (o_reg_rvalid_desp        ),
      .i_reg_wr               (i_reg_wr                 ),
      .i_reg_wr_desp          (i_reg_wr_desp            ),
      .i_reg_waddr            (i_reg_waddr              ),
      .i_reg_wdata            (i_reg_wdata              ),
      .i_status               (i_status                 ),
      .o_status               (o_status                 ),
      //* peri interface;
      .i_peri_rden            (w_peri_rden_dra          ),
      .i_peri_wren            (w_peri_wren_dra          ),
      .i_peri_addr            (i_peri_addr              ),
      .i_peri_wdata           (i_peri_wdata             ),
      .i_peri_wstrb           (i_peri_wstrb             ),
      .o_peri_rdata           (w_peri_rdata_dra         ),
      .o_peri_ready           (w_peri_ready_dra         ),
      .o_peri_int             (w_peri_int_dra           ),
      .d_dra_empty_pktRecv_1b (d_dra_empty_pktRecv_1b   ),
      .d_dra_empty_despRecv_3b(d_dra_empty_despRecv_3b  ),
      .d_dra_empty_despSend_3b(d_dra_empty_despSend_3b  ),
      .d_dra_empty_writeReq_3b(d_dra_empty_writeReq_3b  ),
      .d_dra_usedw_pktRecv_10b(d_dra_usedw_pktRecv_10b  )
    );
    // assign w_data_from_dra_valid = 1'b0;
    // assign w_alf_dra          = 1'b0;
    // assign o_status           = {`NUM_PE{32'b0}};
    // assign o_reg_rvalid_desp  = {`NUM_PE{1'b0}};
    // assign o_reg_rvalid       = {`NUM_PE{1'b0}};
    // assign o_reg_rdata        = 512'b0;
    // assign o_peri_ready[5]    = 1'b0;
    // assign o_peri_ready[3]    = 1'b0;
    // assign o_peri_ready[1]    = 1'b0;
    // assign o_peri_int[5]      = 1'b0;
    // assign o_peri_int[3]      = 1'b0;
    // assign o_peri_int[1]      = 1'b0;
  `endif

  DMA_Engine DMA_Engine(
    //* clk & rst_n;
    .i_clk                  (i_pe_clk                 ),
    .i_rst_n                (i_rst_n                  ),
    //* pkt in & out;
    .i_data_valid           (w_data_to_dma_valid      ),
    .i_data                 (w_data_to_dma            ),
    .o_data_valid           (w_data_from_dma_valid    ),
    .o_data                 (w_data_from_dma          ),
    //* alf;
    .o_alf_dma              (w_alf_dma                ),
    //* dma interface;
    .o_dma_rden             (o_dma_rden               ),
    .o_dma_wren             (o_dma_wren               ),
    .o_dma_addr             (o_dma_addr               ),
    .o_dma_wdata            (o_dma_wdata              ),
    .i_dma_rdata            (i_dma_rdata              ),
    .i_dma_rvalid           (i_dma_rvalid             ),
    .i_dma_gnt              (i_dma_gnt                ),
    //* peri interface, related with PEs;
    .i_peri_rden            (w_peri_rden_dma          ),
    .i_peri_wren            (w_peri_wren_dma          ),
    .i_peri_addr            (i_peri_addr              ),
    .i_peri_wdata           (i_peri_wdata             ),
    .i_peri_wstrb           (i_peri_wstrb             ),
    .o_peri_rdata           (w_peri_rdata_dma         ),
    .o_peri_ready           (w_peri_ready_dma         ),
    .o_peri_int             (w_peri_int_dma           ),
    //* debug;
    .d_dmaDist_inc_pkt_3b     (d_dmaDist_inc_pkt_3b     ),
    .d_dmaDist_state_dist_1b  (d_dmaDist_state_dist_1b  ),
    .d_dmaOut_state_out_4b    (d_dmaOut_state_out_4b    ),
    .d_alf_dma_3b             (d_dma_alf_dma_3b         ),
    .d_empty_dmaWR_3b         (d_dma_empty_dmaWR_3b     ),
    .d_usedw_dmaWR_30b        (d_dma_usedw_dmaWR_30b    ),
    .d_empty_pBufWR_3b        (d_dma_empty_pBufWR_3b    ),
    .d_empty_pBufRD_3b        (d_dma_empty_pBufRD_3b    ),
    .d_usedw_pBufRD_30b       (d_dma_usedw_pBufRD_30b   ),
    .d_empty_int_3b           (d_dma_empty_int_3b       ),
    .d_empty_length_3b        (d_dma_empty_length_3b    ),
    .d_empty_low16b_3b        (d_dma_empty_low16b_3b    ),
    .d_empty_high16b_3b       (d_dma_empty_high16b_3b   )
  );

endmodule    
