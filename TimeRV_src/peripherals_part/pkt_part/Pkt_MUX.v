/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_MUX.
 *  Description:        This module is used to dispatch packets.
 *  Last updated date:  2022.07.22.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_MUX(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* interface for recv DRA/DMA pkt;
  ,input  wire              i_data_DRA_valid
  ,input  wire  [ 133:0]    i_data_DRA
  ,input  wire              i_data_DMA_valid
  ,input  wire  [ 133:0]    i_data_DMA
  ,input  wire              i_data_conf_valid
  ,input  wire  [ 133:0]    i_data_conf   
  //* output pkt & meta; 
  ,output reg               o_data_valid
  ,output reg   [ 133:0]    o_data
  ,output reg               o_meta_valid
  ,output reg   [ 167:0]    o_meta
  ,input  wire              i_alf 
  //* current configuring port (bitmap);
  ,input  wire  [   7:0]    i_conf_port 
  //* debug;
  ,output wire  [   3:0]    d_state_mux_4b
  ,output wire              d_inc_dra_pkt_1b
  ,output wire              d_inc_dma_pkt_1b
  ,output wire              d_inc_conf_pkt_1b
  ,output wire  [   6:0]    d_usedw_pktDMA_7b
  ,output wire  [   6:0]    d_usedw_pktDRA_7b
  ,output wire  [   6:0]    d_usedw_conf_7b
);
  
  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* dma-related signals (fifo);
  reg   [133:0]             din_pktDMA;
  reg                       rden_pktDMA, wren_pktDMA;
  wire  [133:0]             dout_pktDMA;
  wire                      empty_pktDMA;
  wire  [7:0]               usedw_pktDMA;
  //* dra-related signals (fifo);
  reg   [133:0]             din_pktDRA;
  reg                       rden_pktDRA, wren_pktDRA;
  wire  [133:0]             dout_pktDRA;
  wire                      empty_pktDRA;
  wire  [7:0]               usedw_pktDRA;
  //* conf-related signals (fifo);
  reg                       rden_pktConf;
  wire  [133:0]             dout_pktConf;
  wire                      empty_pktConf;
  
  //* state;
  reg   [3:0]               state_mux_out, state_dma_in, state_dra_in;
  localparam                IDLE_S            = 4'd0,
                            WAIT_PKT_END_S    = 4'd1,
                            SEND_DMA_META_0_S = 4'd2,
                            SEND_DMA_META_1_S = 4'd3,
                            SEND_DMA_HEAD_S   = 4'd4,
                            SEND_DMA_S        = 4'd5,
                            SEND_DRA_META_0_S = 4'd6,
                            SEND_DRA_META_1_S = 4'd7,
                            SEND_DRA_S        = 4'd8,
                            SEND_CONF_META_S  = 4'd9,
                            SEND_CONF_S       = 4'd10,
                            DISCARD_S         = 4'd11;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//  

  //==============================================================//
  //   dma_data/dra_data -> o_data
  //==============================================================//
  //* read dma_fifo;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* fifo;
      rden_pktDMA                   <= 1'b0;
      rden_pktDRA                   <= 1'b0;
      rden_pktConf                  <= 1'b0;
      //* output
      o_data                        <= 134'b0;
      o_data_valid                  <= 1'b0;
      o_meta                        <= 168'b0;
      o_meta_valid                  <= 1'b0;
      state_mux_out                 <= IDLE_S;
    end 
    else begin

      //* output pkt from dma/dra/conf;
      case(state_mux_out)
        IDLE_S: begin
          o_data_valid              <= 1'b0;
          if(empty_pktDMA == 1'b0 && rden_pktDMA == 1'b0 && i_data_DRA_valid == 1'b0 &&
            i_alf == 1'b0) 
          begin //* read pkt from dma_fifo;
            rden_pktDMA             <= 1'b1;
            state_mux_out           <= SEND_DMA_META_0_S;
          end
          else if(empty_pktDRA == 1'b0 && i_alf == 1'b0) begin //* read pkt from dra_fifo;
            rden_pktDRA             <= 1'b1;
            state_mux_out           <= SEND_DRA_META_0_S;
          end
          else if(empty_pktConf == 1'b0 && i_alf == 1'b0) begin
            // rden_pktConf            <= 1'b1;
            state_mux_out           <= SEND_CONF_META_S;
          end
          else begin
            state_mux_out           <= IDLE_S;
          end
        end
        SEND_DMA_META_0_S: begin
          o_meta                    <= {dout_pktDMA[103:0],64'b0};
          state_mux_out             <= SEND_DMA_META_1_S;
        end
        SEND_DMA_META_1_S: begin
          o_meta                    <= {o_meta[167:64], dout_pktDMA[63:0]};
          state_mux_out             <= SEND_DMA_HEAD_S;
        end
        SEND_DMA_HEAD_S: begin
          o_meta_valid              <= 1'b1;
          o_data_valid              <= 1'b1;
          o_data                    <= {2'b01, dout_pktDMA[131:0]};
          state_mux_out             <= SEND_DMA_S;
        end
        SEND_DMA_S: begin
          o_meta_valid              <= 1'b0;
          o_data_valid              <= rden_pktDMA;
          o_data                    <= dout_pktDMA;
          if(rden_pktDMA == 1'b1 && dout_pktDMA[133:132] == 2'b10) begin
            //* end;
            state_mux_out           <= IDLE_S;
            rden_pktDMA             <= 1'b0;
          end
          else begin
            rden_pktDMA             <= ~i_alf;
          end
        end
        SEND_DRA_META_0_S: begin
          o_meta                    <= {dout_pktDRA[103:0],64'b0};
          state_mux_out             <= SEND_DRA_META_1_S;
        end
        SEND_DRA_META_1_S: begin
          o_meta                    <= {o_meta[167:64], dout_pktDRA[63:0]};
          state_mux_out             <= SEND_DRA_S;
        end
        SEND_DRA_S: begin
          o_meta_valid              <= (dout_pktDRA[133:132] == 2'b01);
          o_data_valid              <= rden_pktDRA;
          o_data                    <= dout_pktDRA;
          
          if(dout_pktDRA[133:132] == 2'b10 && rden_pktDRA == 1'b1) begin
            state_mux_out           <= IDLE_S;
            rden_pktDRA             <= 1'b0;
          end
          else begin
            rden_pktDRA             <= ~i_alf;
          end
        end
        SEND_CONF_META_S: begin
          o_meta                    <= {i_conf_port, 8'h80, 152'b0};
          rden_pktConf              <= 1'b1;
          state_mux_out             <= SEND_CONF_S;
        end
        SEND_CONF_S: begin
          o_meta_valid              <= (dout_pktConf[133:132] == 2'b01);
          o_data_valid              <= rden_pktConf;
          o_data                    <= dout_pktConf;
          if(dout_pktConf[133:132] == 2'b10 && rden_pktConf == 1'b1) begin
            state_mux_out           <= IDLE_S;
            rden_pktConf            <= 1'b0;
          end
          else begin
            rden_pktConf            <= ~i_alf;
          end
        end
        default: begin
          state_mux_out             <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  //==============================================================//
  //   Write dma FIFO
  //==============================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      din_pktDMA                    <= 134'b0;
      wren_pktDMA                   <= 1'b0;
      state_dma_in                  <= IDLE_S;
    end else begin
      din_pktDMA                    <= i_data_DMA;
      case(state_dma_in)
        IDLE_S: begin
          wren_pktDMA               <= 1'b0;
          if(i_data_DMA_valid == 1'b1 && i_data_DMA[133:132] == 2'b01) begin
            state_dma_in            <= (usedw_pktDMA < 8'd150)? WAIT_PKT_END_S: 
                                            DISCARD_S;
            wren_pktDMA             <= (usedw_pktDMA < 8'd150)? 1'b1 : 1'b0;
          end
          else begin
            state_dma_in            <= IDLE_S;
          end
        end
        WAIT_PKT_END_S: begin
          wren_pktDMA               <= i_data_DMA_valid;
          state_dma_in              <= WAIT_PKT_END_S;
          
          if(i_data_DMA_valid == 1'b1 && i_data_DMA[133:132] == 2'b10) begin
            state_dma_in            <= IDLE_S;
          end
        end
        DISCARD_S: begin
          if(i_data_DMA_valid == 1'b1 && i_data_DMA[133:132] == 2'b10) begin
            state_dma_in            <= IDLE_S;
          end
          else begin
            state_dma_in            <= DISCARD_S;
          end
        end
        default: begin
          state_dma_in              <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //   Write dra FIFO
  //==============================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      din_pktDRA                    <= 134'b0;
      wren_pktDRA                   <= 1'b0;
      state_dra_in                  <= IDLE_S;
    end else begin
      case(state_dra_in)
        IDLE_S: begin
          wren_pktDRA               <= 1'b0;
          din_pktDRA                <= i_data_DRA;
          state_dra_in              <= IDLE_S;
          if(i_data_DRA_valid == 1'b1 && i_data_DRA[133:132] == 2'b11) begin
            state_dra_in            <= (usedw_pktDRA < 8'd150)? WAIT_PKT_END_S:
                                        DISCARD_S;
            wren_pktDRA             <= (usedw_pktDRA < 8'd150)? 1'b1: 1'b0;
          end
        end
        WAIT_PKT_END_S: begin
          wren_pktDRA               <= i_data_DRA_valid;
          din_pktDRA                <= i_data_DRA;
          state_dra_in              <= WAIT_PKT_END_S;
          if(i_data_DRA[133:132] == 2'b10) begin
            state_dra_in            <= IDLE_S;
          end
          else begin
            state_dra_in            <= WAIT_PKT_END_S;
          end
        end
        DISCARD_S: begin
          if(i_data_DRA[133:132] == 2'b10) begin
            state_dra_in            <= IDLE_S;
          end
          else begin
            state_dra_in            <= DISCARD_S;
          end
        end
        default: begin
          state_dra_in              <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  
  `ifdef XILINX_FIFO_RAM
    wire [1:0]  padDMA_2b, padDRA_2b;
    fifo_134b_512 fifo_pktDMA (
      .clk    (i_clk              ),  // input wire clk
      .srst   (!i_rst_n           ),  // input wire srst
      .din    (din_pktDMA         ),  // input wire [133 : 0] din
      .wr_en  (wren_pktDMA        ),  // input wire wr_en
      .rd_en  (rden_pktDMA        ),  // input wire rd_en
      .dout   (dout_pktDMA        ),  // output wire [133 : 0] dout
      .empty  (empty_pktDMA       ),  // output wire empty
      .data_count({padDMA_2b,usedw_pktDMA}    )
    );
    fifo_134b_512 fifo_pktDRA (
      .clk    (i_clk              ),  // input wire clk
      .srst   (!i_rst_n           ),  // input wire srst
      .din    (i_data_DRA         ),  // input wire [133 : 0] din
      .wr_en  (i_data_DRA_valid   ),  // input wire wr_en
      .rd_en  (rden_pktDRA        ),  // input wire rd_en
      .dout   (dout_pktDRA        ),  // output wire [133 : 0] dout
      .empty  (empty_pktDRA       ),  // output wire empty
      .data_count({padDRA_2b,usedw_pktDRA}    )
    );
    fifo_134b_512 fifo_pktConf (
      .clk    (i_clk              ),  // input wire clk
      .srst   (!i_rst_n           ),  // input wire srst
      .din    (i_data_conf        ),  // input wire [133 : 0] din
      .wr_en  (i_data_conf_valid  ),  // input wire wr_en
      .rd_en  (rden_pktConf       ),  // input wire rd_en
      .dout   (dout_pktConf       ),  // output wire [133 : 0] dout
      .empty  (empty_pktConf      )   // output wire empty
    );
  `elsif SIM_FIFO_RAM
    //* fifo used to buffer dma pkt;
    syncfifo fifo_pktDMA (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_pktDMA               ),  //* The Inport of data 
      .wrreq                (wren_pktDMA              ),  //* active-high
      .rdreq                (rden_pktDMA              ),  //* active-high
      .q                    (dout_pktDMA              ),  //* The output of data
      .empty                (empty_pktDMA             ),  //* Read domain empty
      .usedw                (usedw_pktDMA             ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktDMA.width = 134,
              fifo_pktDMA.depth = 8,
              fifo_pktDMA.words = 256;
    //* fifo used to buffer dra pkt;
    syncfifo fifo_pktDRA (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_data_DRA               ),  //* The Inport of data 
      .wrreq                (i_data_DRA_valid         ),  //* active-high
      .rdreq                (rden_pktDRA              ),  //* active-high
      .q                    (dout_pktDRA              ),  //* The output of data
      .empty                (empty_pktDRA             ),  //* Read domain empty
      .usedw                (usedw_pktDRA             ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktDRA.width = 134,
              fifo_pktDRA.depth = 8,
              fifo_pktDRA.words = 256;
    //* fifo used to buffer conf pkt;
    syncfifo fifo_pktConf (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_data_conf              ),  //* The Inport of data 
      .wrreq                (i_data_conf_valid        ),  //* active-high
      .rdreq                (rden_pktConf             ),  //* active-high
      .q                    (dout_pktConf             ),  //* The output of data
      .empty                (empty_pktConf            ),  //* Read domain empty
      .usedw                (                        ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktConf.width = 134,
              fifo_pktConf.depth = 8,
              fifo_pktConf.words = 256;
  `else
    SYNCFIFO_256x134 fifo_pktDMA (
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_pktDMA               ),  //* The Inport of data 
      .rdreq                (rden_pktDMA              ),  //* active-high
      .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                (wren_pktDMA              ),  //* active-high
      .q                    (dout_pktDMA              ),  //* The output of data
      .rdempty              (empty_pktDMA             ),  //* Read domain empty
      .rdalempty            (                         ),  //* Read domain almost-empty
      .wrusedw              (                         ),  //* Write-usedword
      .rdusedw              (usedw_pktDMA             )   //* Read-usedword
    );
    SYNCFIFO_256x134 fifo_pktDRA (
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_data_DRA               ),  //* The Inport of data 
      .rdreq                (rden_pktDRA              ),  //* active-high
      .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                (i_data_DRA_valid         ),  //* active-high
      .q                    (dout_pktDRA              ),  //* The output of data
      .rdempty              (empty_pktDRA             ),  //* Read domain empty
      .rdalempty            (                         ),  //* Read domain almost-empty
      .wrusedw              (                         ),  //* Write-usedword
      .rdusedw              (usedw_pktDRA             )   //* Read-usedword
    );
    SYNCFIFO_128x134 fifo_pktConf (
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_data_conf              ),  //* The Inport of data 
      .rdreq                (rden_pktConf             ),  //* active-high
      .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                (i_data_conf_valid        ),  //* active-high
      .q                    (dout_pktConf             ),  //* The output of data
      .rdempty              (empty_pktConf            ),  //* Read domain empty
      .rdalempty            (                         ),  //* Read domain almost-empty
      .wrusedw              (                         ),  //* Write-usedword
      .rdusedw              (d_usedw_conf_7b          )   //* Read-usedword
    );
  `endif

  //* debug;
  assign  d_state_mux_4b    = state_mux_out;
  assign  d_inc_dra_pkt_1b  = (rden_pktDRA == 1'b1 && dout_pktDRA[133:132] == 2'b10);
  assign  d_inc_dma_pkt_1b  = (rden_pktDMA == 1'b1 && dout_pktDMA[133:132] == 2'b10);
  assign  d_inc_conf_pkt_1b = (rden_pktConf == 1'b1&& dout_pktConf[133:132]== 2'b10);
  assign  d_usedw_pktDMA_7b = usedw_pktDMA[6:0];
  assign  d_usedw_pktDRA_7b = usedw_pktDRA[6:0];

endmodule