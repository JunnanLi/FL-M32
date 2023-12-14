/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        dDMA_Rd_Wr_Data.
 *  Description:        This module is used to dma data with AiPE.
 *  Last updated date:  2022.09.07.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 */

`timescale 1 ns / 1 ps

module dDMA_Rd_Wr_Data(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* DMA (communicaiton with data AiPE);
  ,output reg                     o_dDMA_AIPE_rden
  ,output reg                     o_dDMA_AIPE_wren
  ,output reg   [         31:0]   o_dDMA_AIPE_addr
  ,output reg   [        127:0]   o_dDMA_AIPE_wdata
  ,input  wire  [        127:0]   i_dDMA_AIPE_rdata
  ,input  wire                    i_dDMA_AIPE_rvalid
  //* DMA (communicaiton with data SRAM);
  ,output reg                     o_dDMA_rden
  ,output reg                     o_dDMA_wren
  ,output reg   [         31:0]   o_dDMA_addr
  ,output reg   [         31:0]   o_dDMA_wdata
  ,input  wire  [         31:0]   i_dDMA_rdata
  ,input  wire                    i_dDMA_rvalid
  ,input  wire                    i_dDMA_gnt
  //* Configure DMA ;
  ,input  wire                    i_tag_start_dDMA
  ,output reg                     o_tag_resp_dDMA
  ,input  wire  [         31:0]   i_addr_RAM     
  ,input  wire  [         15:0]   i_len_RAM      
  ,input  wire  [         31:0]   i_addr_RAM_AIPE
  ,input  wire  [         15:0]   i_len_RAM_AIPE 
  ,input  wire                    i_dir
  //* irq;
  ,output reg                     o_peri_int   
  //* debug;
  ,output wire  [          3:0]   d_state_dDMA_4b
  ,output reg   [          3:0]   d_cnt_int_4b       
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* temp;
  reg           [         31:0]   r_next_addr_dDMA, r_next_addr_AIPE;
  reg           [         15:0]   r_next_len_dDMA, r_next_len_AIPE;
  reg           [          1:0]   r_cnt;
  reg           [        127:0]   r_temp_data_RAM_AIPE, r_pre_data_RAM_AIPE;
  //* state;
  reg           [          3:0]   state_dDMA;
  localparam                      IDLE_S        = 4'd0,
                                  WRITE_AIPE_S  = 4'd1,
                                  WAIT_1_S      = 4'd2,
                                  WAIT_2_S      = 4'd3,
                                  READ_RAM_S    = 4'd4,
                                  WRITE_SRAM_S  = 4'd5,
                                  WAIT_END_S    = 4'd6;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   dDMA
  //====================================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      state_dDMA                      <= IDLE_S;
      o_tag_resp_dDMA                 <= 1'b0;
      r_cnt                           <= 2'b0;
      //* from aiPE;
      r_temp_data_RAM_AIPE            <= 128'b0;
      r_pre_data_RAM_AIPE             <= 128'b0;
      o_dDMA_AIPE_rden                <= 1'b0;
      o_dDMA_AIPE_wren                <= 1'b0;
      o_dDMA_AIPE_addr                <= 32'b0;
      o_dDMA_AIPE_wdata               <= 128'b0;
      //* from Data;
      o_dDMA_rden                     <= 1'b0;
      o_dDMA_wren                     <= 1'b0;
      o_dDMA_addr                     <= 32'b0;
      o_dDMA_wdata                    <= 32'b0;
      //* temp register;
      r_next_addr_dDMA                <= 32'b0;
      r_next_addr_AIPE                <= 32'b0;
      r_next_len_dDMA                 <= 16'b0;
      r_next_len_AIPE                 <= 16'b0;
      //* peri;
      o_peri_int                      <= 1'b0;
    end 
    else begin
      case(state_dDMA)
        IDLE_S: begin
          o_dDMA_wren                 <= 1'b0;
          o_dDMA_AIPE_wren            <= 1'b0;
          o_peri_int                  <= 1'b0;  //* just maintain one clk;
          r_cnt                       <= 2'b0;
          if(o_tag_resp_dDMA != i_tag_start_dDMA && i_dDMA_gnt == 1'b1) begin
            if(i_dir == 1'b0) begin //* read Data SRAM, and write AIPE SRAM;
              o_dDMA_rden             <= 1'b1;
              o_dDMA_addr             <= i_addr_RAM;
              r_next_addr_dDMA        <= i_addr_RAM + 32'd1;
              r_next_len_dDMA         <= i_len_RAM - 16'd1;
              r_next_addr_AIPE        <= i_addr_RAM_AIPE;
              state_dDMA              <= WRITE_AIPE_S;
            end
            else begin //* read AIPE SRAM, and write Data SRAM;
              o_dDMA_AIPE_rden        <= 1'b1;
              o_dDMA_AIPE_addr        <= i_addr_RAM_AIPE;
              r_next_addr_AIPE        <= i_addr_RAM_AIPE + 32'd1;
              r_next_len_AIPE         <= i_len_RAM_AIPE;
              r_next_addr_dDMA        <= i_addr_RAM;
              state_dDMA              <= WAIT_1_S;
            end
          end
          else begin
            o_dDMA_rden               <= 1'b0;
            state_dDMA                <= IDLE_S;
          end
        end
        WRITE_AIPE_S: begin
          o_dDMA_AIPE_wren            <= 1'b0;
          //* get rdata;
          if(i_dDMA_rvalid == 1'b1) begin
            r_cnt                     <= r_cnt + 2'd1;
            case(r_cnt)
              2'd0: o_dDMA_AIPE_wdata[0*32+:32] <= i_dDMA_rdata;
              2'd1: o_dDMA_AIPE_wdata[1*32+:32] <= i_dDMA_rdata;
              2'd2: o_dDMA_AIPE_wdata[2*32+:32] <= i_dDMA_rdata;
              2'd3: begin 
                    o_dDMA_AIPE_wren            <= 1'b1;
                    o_dDMA_AIPE_addr            <= r_next_addr_AIPE;
                    o_dDMA_AIPE_wdata[3*32+:32] <= i_dDMA_rdata;
                    r_next_addr_AIPE            <= r_next_addr_AIPE + 32'd1;
              end
            endcase
          end
          else begin
            r_cnt                     <= r_cnt;
          end

          //* update addr;
          if(i_dDMA_gnt == 1'b1)begin
            if(r_next_len_dDMA != 16'b0) begin
              o_dDMA_rden             <= 1'b1;
              o_dDMA_addr             <= r_next_addr_dDMA;
              r_next_addr_dDMA        <= r_next_addr_dDMA + 32'd1;
              r_next_len_dDMA         <= r_next_len_dDMA - 16'd1;
              state_dDMA              <= WRITE_AIPE_S;
            end
            else begin
              o_dDMA_rden             <= (r_cnt == 2'd3 && i_dDMA_rvalid == 1'b1)? 1'b0: 1'b1;
              o_peri_int              <= (r_cnt == 2'd3 && i_dDMA_rvalid == 1'b1);
              state_dDMA              <= (r_cnt == 2'd3 && i_dDMA_rvalid == 1'b1)? IDLE_S: WRITE_AIPE_S;
              o_tag_resp_dDMA         <= (r_cnt == 2'd3 && i_dDMA_rvalid == 1'b1)? ~o_tag_resp_dDMA: o_tag_resp_dDMA;
            end
          end
          else begin
            o_dDMA_rden               <= 1'b1;
            state_dDMA                <= WRITE_AIPE_S;
          end
        end
        WAIT_1_S: begin
          o_dDMA_AIPE_rden            <= 1'b0;
          state_dDMA                  <= WAIT_2_S;
        end
        WAIT_2_S: begin
          state_dDMA                  <= READ_RAM_S;
        end
        READ_RAM_S: begin
          r_temp_data_RAM_AIPE        <= i_dDMA_AIPE_rdata;
          state_dDMA                  <= WRITE_SRAM_S;
        end
        WRITE_SRAM_S: begin
          r_pre_data_RAM_AIPE         <= (i_dDMA_AIPE_rvalid == 1'b1)? i_dDMA_AIPE_rdata: r_pre_data_RAM_AIPE;
          o_dDMA_AIPE_rden            <= 1'b0;
          o_dDMA_wren                 <= 1'b1;
          //* write rdata;
          if(i_dDMA_gnt == 1'b1) begin
            r_cnt                     <= r_cnt + 2'd1;
            o_dDMA_addr               <= r_next_addr_dDMA;
            r_next_addr_dDMA          <= r_next_addr_dDMA + 32'd1;
            case(r_cnt)
              2'd0: o_dDMA_wdata      <= r_temp_data_RAM_AIPE[0*32+:32];
              2'd1: o_dDMA_wdata      <= r_temp_data_RAM_AIPE[1*32+:32];
              2'd2: o_dDMA_wdata      <= r_temp_data_RAM_AIPE[2*32+:32];
              2'd3: o_dDMA_wdata      <= r_temp_data_RAM_AIPE[3*32+:32];
            endcase
            //* read next;
            if(r_cnt == 2'd0) begin
              o_dDMA_AIPE_rden        <= 1'b1;
              o_dDMA_AIPE_addr        <= r_next_addr_AIPE;
              r_next_addr_AIPE        <= r_next_addr_AIPE + 32'd1;
              r_next_len_AIPE         <= r_next_len_AIPE - 16'd1;
            end
            else begin
              o_dDMA_AIPE_rden        <= 1'b0;
            end
            if(r_cnt == 2'd3) begin
              r_temp_data_RAM_AIPE    <= (i_dDMA_AIPE_rvalid == 1'b1)? i_dDMA_AIPE_rdata:
                                          r_pre_data_RAM_AIPE;
            end
            else begin
              r_temp_data_RAM_AIPE    <= r_temp_data_RAM_AIPE;
            end
            if(r_next_len_AIPE == 16'b0 && r_cnt == 2'd3) begin
              state_dDMA              <= WAIT_END_S;
            end
            else begin
              state_dDMA              <= WRITE_SRAM_S;
            end
          end
          else begin
            state_dDMA                <= WRITE_SRAM_S;
          end
        end
        WAIT_END_S: begin
          o_dDMA_wren                 <= 1'b1;
          if(i_dDMA_gnt|i_dDMA_rvalid) begin
            o_dDMA_wren               <= 1'b0;
            o_peri_int                <= 1'b1;
            o_tag_resp_dDMA           <= ~o_tag_resp_dDMA;
            state_dDMA                <= IDLE_S;
          end
          else begin
            o_peri_int                <= 1'b0;
            state_dDMA                <= WAIT_END_S;
          end
        end
        default: begin
          state_dDMA                  <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   debug
  //====================================================================//
  assign d_state_dDMA_4b              = state_dDMA;

  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      d_cnt_int_4b                    <= 4'b0;
    end else begin
      d_cnt_int_4b                    <= (o_peri_int == 1'b1)? (d_cnt_int_4b + 4'd1): d_cnt_int_4b;
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
