/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_Distribute.
 *  Description:        This module is used to dispatch packets.
 *  Last updated date:  2022.06.24.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_Distribute(
   input  wire              i_pe_clk
  ,input  wire              i_rst_n
  //* interface for recv/send pkt;
  ,input  wire  [47:0]      i_pe_conf_mac
  ,input  wire              i_data_valid
  ,input  wire  [133:0]     i_data
  ,input  wire              i_meta_valid
  ,input  wire  [167:0]     i_meta 
  //* DMA & DRA;
  ,output wire              o_data_dma_valid
  ,output wire  [133:0]     o_data_dma 
  ,output wire              o_data_dra_valid
  ,output wire  [133:0]     o_data_dra
  ,input  wire              i_data_dma_valid
  ,input  wire  [133:0]     i_data_dma 
  ,input  wire              i_data_dra_valid
  ,input  wire  [133:0]     i_data_dra
  //* Output;
  ,output wire              o_data_valid
  ,output wire  [133:0]     o_data
  ,output wire              o_meta_valid
  ,output wire  [167:0]     o_meta
  //* for network configure;
  ,output wire              o_data_conf_valid
  ,output wire  [133:0]     o_data_conf      
  ,input  wire              i_data_conf_valid
  ,input  wire  [133:0]     i_data_conf 
  //* ready;
  ,output wire              o_alf
  ,input  wire              i_alf
  //* alf;
  ,input  wire              i_alf_dra
  ,input  wire  [`NUM_PE-1:0]   i_alf_dma
  //* debug;
  ,output wire  [3:0]       d_AsynRev_inc_pkt_4b  
  ,output wire  [3:0]       d_PktMUX_state_mux_4b   
  ,output wire              d_PktMUX_inc_dra_pkt_1b 
  ,output wire              d_PktMUX_inc_dma_pkt_1b 
  ,output wire              d_PktMUX_inc_conf_pkt_1b
  ,output wire  [6:0]       d_PktMUX_usedw_pktDMA_7b
  ,output wire  [6:0]       d_PktMUX_usedw_pktDRA_7b
  ,output wire  [6:0]       d_PktMUX_usedw_conf_7b
);

  //======================= internal reg/wire/param declarations =//
  //* calculate checksum for TCP;
  wire                      w_data_crc_valid;
  wire          [133:0]     w_data_crc;
  //* current configuring port (bitmap);
  wire          [7:0]       w_conf_port;
  //==============================================================//

  //======================= Asyn recv pkt  =======================//
  Pkt_DMUX Pkt_DMUX(
    //* clk & rst_n;
    .i_pe_clk               (i_pe_clk                 ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for recv/send pkt;
    .i_pe_conf_mac          (i_pe_conf_mac            ),
    .i_data_valid           (i_data_valid             ),
    .i_data                 (i_data                   ),
    .i_meta_valid           (i_meta_valid             ),
    .i_meta                 (i_meta                   ),
    //* to DRA
    .o_data_DRA_valid       (o_data_dra_valid         ),
    .o_data_DRA             (o_data_dra               ),
    //* to DMA
    .o_data_DMA_valid       (o_data_dma_valid         ),
    .o_data_DMA             (o_data_dma               ),
    .o_alf                  (o_alf                    ),
    //* to configure
    .o_data_conf_valid      (o_data_conf_valid        ),
    .o_data_conf            (o_data_conf              ),
    //* alf;
    .i_alf_dra              (i_alf_dra                ),
    .i_alf_dma              (i_alf_dma                ),
    //* current configuring port (bitmap);
    .o_conf_port            (w_conf_port              ),
    //* debug;
    .d_inc_pkt_4b           (d_AsynRev_inc_pkt_4b     )
  );
  //==============================================================//

  Pkt_TCP_CRC Pkt_TCP_CRC(
    .i_clk                  (i_pe_clk                 ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for calculate tcp's crc;
    .i_data_valid           (i_data_dma_valid         ),
    .i_data                 (i_data_dma               ),
    .o_data_valid           (w_data_crc_valid         ),
    .o_data                 (w_data_crc               )
  );

  //======================= MUX for pkt    =======================//
  Pkt_MUX Pkt_MUX(
    //* clk & rst_n;
    .i_clk                  (i_pe_clk                 ),
    .i_rst_n                (i_rst_n                  ),
    //* interface for DMA/DRA pkt;
    .i_data_DRA_valid       (i_data_dra_valid         ),
    .i_data_DRA             (i_data_dra               ),
    .i_data_DMA_valid       (w_data_crc_valid         ),
    .i_data_DMA             (w_data_crc               ),
    .i_data_conf_valid      (i_data_conf_valid        ),
    .i_data_conf            (i_data_conf              ),
    //* output
    .o_data_valid           (o_data_valid             ),
    .o_data                 (o_data                   ),
    .o_meta_valid           (o_meta_valid             ),
    .o_meta                 (o_meta                   ),
    .i_alf                  (i_alf                    ),
    //* current configuring port (bitmap);
    .i_conf_port            (w_conf_port              ),
    //* debug;
    .d_state_mux_4b         (d_PktMUX_state_mux_4b    ),
    .d_inc_dra_pkt_1b       (d_PktMUX_inc_dra_pkt_1b  ),
    .d_inc_dma_pkt_1b       (d_PktMUX_inc_dma_pkt_1b  ),
    .d_inc_conf_pkt_1b      (d_PktMUX_inc_conf_pkt_1b ),
    .d_usedw_pktDMA_7b      (d_PktMUX_usedw_pktDMA_7b ),
    .d_usedw_pktDRA_7b      (d_PktMUX_usedw_pktDRA_7b ),
    .d_usedw_conf_7b        (d_PktMUX_usedw_conf_7b   )
  );
  //==============================================================//
  
  

endmodule