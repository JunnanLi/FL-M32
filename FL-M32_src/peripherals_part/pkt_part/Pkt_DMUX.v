/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_Asyn_Proc.
 *  Description:        This module is used to recv packets.
 *  Last updated date:  2023.11.25.
 *
 *  Copyright (C) 2021-2023 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */
// `define VCS
`timescale 1 ns / 1 ps

module Pkt_DMUX(
   input  wire              i_pe_clk
  ,input  wire              i_rst_n
  //* interface for recv/send pkt;
  ,input  wire  [47:0]      i_pe_conf_mac
  ,input  wire              i_data_valid
  ,input  wire  [133:0]     i_data
  ,input  wire              i_meta_valid
  ,input  wire  [167:0]     i_meta
  //* output;
  ,output reg               o_data_DMA_valid
  ,output reg   [133:0]     o_data_DMA 
  ,output reg               o_data_DRA_valid
  ,output reg   [133:0]     o_data_DRA
  ,output wire              o_alf
  //* for network configure;
  ,output reg               o_data_conf_valid
  ,output reg   [133:0]     o_data_conf  
  //* alf;
  ,input  wire              i_alf_dra
  ,input  wire  [`NUM_PE-1:0]   i_alf_dma
  //* current configuring port (bitmap);
  ,output reg   [7:0]       o_conf_port 
  //* debug;
  ,output wire  [3:0]       d_inc_pkt_4b
);

  //======================= internal reg/wire/param declarations =//
  //* state;
  reg           [2:0]       state_recv;
  localparam                IDLE_S          = 3'd0,
                            OUTPUT_META_0_S = 3'd1,
                            OUTPUT_META_1_S = 3'd2,
                            OUTPUT_PKT_S    = 3'd3,
                            OUTPUT_CONF_S   = 3'd4,
                            DISCARD_S       = 3'd5,
                            DISCARD_CONF_S  = 3'd6;

  //==============================================================//
 
  //======================= DMUX =================================//
  //* output to dma & pe_conf;
  reg [133:0] r_temp_pkt[1:0];
  always @(posedge i_pe_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* output;
      o_data_DMA                <= 134'b0;
      o_data_DMA_valid          <= 1'b0;
      o_data_DRA                <= 134'b0;
      o_data_DRA_valid          <= 1'b0;
      o_data_conf               <= 134'b0;
      o_data_conf_valid         <= 1'b0;
      r_temp_pkt[0]             <= 134'b0;
      r_temp_pkt[1]             <= 134'b0;
      //* state;
      state_recv                <= IDLE_S;
    end else begin
      {r_temp_pkt[1],r_temp_pkt[0]} <= {r_temp_pkt[0],i_data};
      //* configure r_back_pressure;
      case(state_recv)
        IDLE_S: begin
          o_data_DMA_valid      <= 1'b0;
          o_data_DRA_valid      <= 1'b0;
          o_data_conf_valid     <= 1'b0;
          
          //* get o_conf_port;
          o_conf_port           <= o_conf_port;
          if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01 && 
            i_data[31:16] == 16'h9005)
          begin
            o_conf_port         <= i_meta[159-:8];
            o_data_conf_valid   <= (i_pe_conf_mac == i_data[127:80]);
            o_data_conf         <= i_data;
            state_recv          <= (i_pe_conf_mac == i_data[127:80])? OUTPUT_CONF_S: DISCARD_S;
          end
          else if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01 &&
            // i_alf_dma == 1'b0 && 
            i_meta[119] == 1'b1) 
          begin
            o_data_DMA_valid    <= 1'b1;
            // o_data_DMA          <= {2'b11,4'h0,128'b0};            

            o_data_DMA          <= {2'b11,4'h0,i_data[87:80],
                                    i_data[39:32],i_data[23:16],
                                    i_meta[167:64]};

            state_recv          <= OUTPUT_META_1_S;
          end
          `ifdef DRA_EN
            else if(i_data_valid == 1'b0 && i_data[133:132] == 2'b01 &&
              // i_alf_dra == 1'b0 && 
              i_meta[119] == 1'b0) 
            begin
              o_data_DRA_valid  <= 1'b1;
              o_data_DRA        <= {2'b11,4'h0,24'b0,i_meta[167:64]};

              state_recv        <= OUTPUT_META_1_S;
            end
          `endif
          else begin
            state_recv          <= IDLE_S;
          end
        end
        OUTPUT_META_1_S: begin
          //* output the second meta;
          o_data_DMA_valid      <= o_data_DMA_valid;
          // o_data_DMA            <= {2'b11,4'h0,64'b0,64'b0};
          o_data_DMA            <= {2'b11,4'h0,64'b0,i_meta[63:0]};
          o_data_DRA_valid      <= o_data_DRA_valid;
          o_data_DRA            <= {2'b11,4'h0,64'b0,i_meta[63:0]};

          state_recv            <= OUTPUT_PKT_S;
        end
        OUTPUT_PKT_S: begin
          //* output pkt;
          o_data_DMA_valid      <= o_data_DMA_valid;
          o_data_DMA            <= r_temp_pkt[1];
          o_data_DRA_valid      <= o_data_DRA_valid;
          o_data_DRA            <= r_temp_pkt[1];
          if(r_temp_pkt[1][133:132] == 2'b10) begin
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= OUTPUT_PKT_S;
          end
        end
        OUTPUT_CONF_S: begin
          //* output pkt;
          o_data_conf_valid     <= 1'b1;
          o_data_conf           <= i_data;
          if(i_data[133:132] == 2'b10) begin
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= OUTPUT_CONF_S;
          end
        end
        DISCARD_S: begin
          if(i_data[133:132] == 2'b10) begin
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= DISCARD_S;
          end
        end
      endcase
    end
  end
  //==============================================================//


endmodule