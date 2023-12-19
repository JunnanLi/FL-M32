/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        dDMA_Peri.
 *  Description:        This module is used to configure dDMA.
 *  Last updated date:  2022.09.07.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 *    1) support pipelined-reading/writing;
 *    2) can be closed without AiPE;
 *    3) address/length counted in byte;
 */

`timescale 1 ns / 1 ps

module dDMA_Peri(
   input  wire                    i_clk
  ,input  wire                    i_rst_n
  //* Configure DMA ;
  ,output reg                     o_tag_start_dDMA
  ,input  wire                    i_tag_resp_dDMA
  ,output reg   [          31:0]  o_addr_RAM     
  ,output reg   [          15:0]  o_len_RAM      
  ,output reg   [          31:0]  o_addr_RAM_AIPE
  ,output reg   [          15:0]  o_len_RAM_AIPE 
  ,output reg                     o_dir          
  //* configuration interface for DMA;
  ,input  wire  [   `NUM_PE-1:0]  i_peri_rden
  ,input  wire  [   `NUM_PE-1:0]  i_peri_wren
  ,input  wire  [`NUM_PE*32-1:0]  i_peri_addr
  ,input  wire  [`NUM_PE*32-1:0]  i_peri_wdata
  ,input  wire  [ `NUM_PE*4-1:0]  i_peri_wstrb
  ,output reg   [`NUM_PE*32-1:0]  o_peri_rdata
  ,output reg   [   `NUM_PE-1:0]  o_peri_ready
  ,output reg   [   `NUM_PE-1:0]  o_bit_PE
  //* debug
  ,output reg   [           3:0]  d_cnt_pe0_rd_4b
  ,output reg   [           3:0]  d_cnt_pe0_wr_4b
  ,output reg   [           3:0]  d_cnt_pe1_rd_4b
  ,output reg   [           3:0]  d_cnt_pe1_wr_4b
  ,output reg   [           3:0]  d_cnt_pe2_rd_4b
  ,output reg   [           3:0]  d_cnt_pe2_wr_4b
);

  //====================================================================//
  //*   Peri
  //====================================================================//
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* peri interface;
      o_peri_rdata                        <= {`NUM_PE{32'b0}};
      o_peri_ready                        <= {`NUM_PE{1'b0}};
      o_bit_PE                            <= {`NUM_PE{1'b0}};
      //* configure dDMA info;
      o_tag_start_dDMA                    <= 1'b0;
      o_addr_RAM                          <= 32'b0;
      o_len_RAM                           <= 16'b0;
      o_addr_RAM_AIPE                     <= 32'b0;
      o_len_RAM_AIPE                      <= 16'b0;
      o_dir                               <= 1'b0;
      //* debug;
      d_cnt_pe0_rd_4b                     <= 4'b0;
      d_cnt_pe1_rd_4b                     <= 4'b0;
      d_cnt_pe2_rd_4b                     <= 4'b0;
      d_cnt_pe0_wr_4b                     <= 4'b0;
      d_cnt_pe1_wr_4b                     <= 4'b0;
      d_cnt_pe2_wr_4b                     <= 4'b0;
    end 
    else begin
      o_peri_ready                        <= i_peri_rden | i_peri_wren;
      
      `ifdef QUAD_CORE
        o_addr_RAM                        <= o_addr_RAM;
        o_len_RAM                         <= o_len_RAM;
        o_addr_RAM_AIPE                   <= o_addr_RAM_AIPE;
        o_len_RAM_AIPE                    <= o_len_RAM_AIPE;
        o_dir                             <= o_dir;
        //* for writing;
        casex(i_peri_wren)
          3'bxx1: begin
            case(i_peri_addr[(32*0+2)+:3])
              3'd0: o_addr_RAM            <= {2'b0,i_peri_wdata[(0*32+2)+:30]};
              3'd1: o_len_RAM             <= i_peri_wdata[(0*32+2)+:15];
              3'd2: o_addr_RAM_AIPE       <= {4'b0,i_peri_wdata[(0*32+4)+:28]};
              3'd3: o_len_RAM_AIPE        <= i_peri_wdata[(0*32+4)+:15];
              3'd4: o_dir                 <= i_peri_wdata[0*32];
              3'd5: o_tag_start_dDMA      <= (o_tag_start_dDMA == i_tag_resp_dDMA)? 
                                              ~o_tag_start_dDMA: o_tag_start_dDMA;
              default: begin
              end
            endcase
            o_bit_PE                      <= 3'b001;
            d_cnt_pe0_wr_4b               <= d_cnt_pe0_wr_4b + 4'd1;
          end
          3'bx10: begin
            case(i_peri_addr[(32*1+2)+:3])
              3'd0: o_addr_RAM            <= {2'b0,i_peri_wdata[(1*32+2)+:30]};
              3'd1: o_len_RAM             <= i_peri_wdata[(1*32+2)+:15];
              3'd2: o_addr_RAM_AIPE       <= {4'b0,i_peri_wdata[(1*32+4)+:28]};
              3'd3: o_len_RAM_AIPE        <= i_peri_wdata[(1*32+4)+:15];
              3'd4: o_dir                 <= i_peri_wdata[1*32];
              3'd5: o_tag_start_dDMA      <= (o_tag_start_dDMA == i_tag_resp_dDMA)? 
                                              ~o_tag_start_dDMA: o_tag_start_dDMA;
              default: begin
              end
            endcase
            o_bit_PE                      <= 3'b010;
            d_cnt_pe1_wr_4b               <= d_cnt_pe1_wr_4b + 4'd1;
          end
          3'b100: begin
            case(i_peri_addr[(32*2+2)+:3])
              3'd0: o_addr_RAM            <= {2'b0,i_peri_wdata[(2*32+2)+:30]};
              3'd1: o_len_RAM             <= i_peri_wdata[(2*32+2)+:15];
              3'd2: o_addr_RAM_AIPE       <= {4'b0,i_peri_wdata[(2*32+4)+:28]};
              3'd3: o_len_RAM_AIPE        <= i_peri_wdata[(2*32+4)+:15];
              3'd4: o_dir                 <= i_peri_wdata[2*32];
              3'd5: o_tag_start_dDMA      <= (o_tag_start_dDMA == i_tag_resp_dDMA)? 
                                              ~o_tag_start_dDMA: o_tag_start_dDMA;
              default: begin
              end
            endcase
            o_bit_PE                      <= 3'b100;
            d_cnt_pe2_wr_4b               <= d_cnt_pe2_wr_4b + 4'd1;
          end
        endcase
        
        //* for reading;
        for(i_pe =0; i_pe <`NUM_PE; i_pe = i_pe+1) begin
          case(i_peri_addr[(i_pe*32+2)+:3])
            3'd0: o_peri_rdata[i_pe*32+:32]   <= {        o_addr_RAM[29:0],     2'b0};
            3'd1: o_peri_rdata[i_pe*32+:32]   <= {16'b0,  o_len_RAM[13:0],      2'b0};
            3'd2: o_peri_rdata[i_pe*32+:32]   <= {        o_addr_RAM_AIPE[27:0],4'b0};
            3'd3: o_peri_rdata[i_pe*32+:32]   <= {16'b0,  o_len_RAM_AIPE[11:0], 4'b0};
            3'd4: o_peri_rdata[i_pe*32+:32]   <= {31'b0,  o_dir};
            3'd5: o_peri_rdata[i_pe*32+:32]   <= {31'b0,  (o_tag_start_dDMA == i_tag_resp_dDMA)};
            default: begin
                  o_peri_rdata[i_pe*32+:32]   <= 32'b0;
            end
          endcase
        end
        d_cnt_pe0_rd_4b                       <= (i_peri_rden[0] == 1'b1)? d_cnt_pe0_rd_4b + 4'd1: d_cnt_pe0_rd_4b;
        d_cnt_pe1_rd_4b                       <= (i_peri_rden[1] == 1'b1)? d_cnt_pe1_rd_4b + 4'd1: d_cnt_pe1_rd_4b;
        d_cnt_pe2_rd_4b                       <= (i_peri_rden[2] == 1'b1)? d_cnt_pe2_rd_4b + 4'd1: d_cnt_pe2_rd_4b;
      `endif
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
