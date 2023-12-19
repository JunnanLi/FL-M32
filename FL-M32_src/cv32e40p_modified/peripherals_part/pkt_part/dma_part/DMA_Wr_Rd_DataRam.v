/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        DMA_Wr_Rd_DataRAM.
 *  Description:        This module is used to dma packets.
 *  Last updated date:  2022.06.16.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps
    
module DMA_Wr_Rd_DataRAM(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* data to DMA;
  ,input  wire              i_empty_data
  ,output reg               o_data_rden
  ,input  wire  [133:0]     i_data
  //* DMA (communicaiton with data SRAM);
  ,output reg               o_dma_rden
  ,output reg               o_dma_wren
  ,output reg   [31:0]      o_dma_addr
  ,output wire  [31:0]      o_dma_wdata
  ,input  wire  [31:0]      i_dma_rdata
  ,input  wire              i_dma_rvalid
  ,input  wire              i_dma_gnt
  //* 16b data out;
  ,output wire  [19:0]      o_din_low16b
  ,output wire              o_wren_low16b
  ,output wire  [16:0]      o_din_high16b
  ,output wire              o_wren_high16b
  ,input  wire  [8:0]       i_usedw_9b
  //* pBuf in interface;
  ,output reg               o_rden_pBufWR
  ,input  wire  [47:0]      i_dout_pBufWR
  ,input  wire              i_empty_pBufWR
  ,output reg               o_rden_pBufRD
  ,input  wire  [63:0]      i_dout_pBufRD
  ,input  wire              i_empty_pBufRD
  ,input  wire  [9:0]       i_usedw_pBufRD
  //* wait new pBufWR;
  ,output wire              o_wait_free_pBufWR
  //* int out;
  ,output reg   [31:0]      o_din_int
  ,output reg               o_wren_int
);

  //======================= internal reg/wire/param declarations =//
  //* output related register;
  reg   [15:0]              r_din_16bData[1:0];
  reg   [1:0]               w_wren_16bData;
  reg                       r_din_endTag;
  reg   [3:0]               r_din_validTag;

  assign o_din_high16b                  = {r_din_endTag, r_din_16bData[0]};
  assign o_din_low16b                   = {r_din_validTag, r_din_16bData[1]};
  assign {o_wren_low16b, o_wren_high16b}= w_wren_16bData;
  
  //* DMA (Direct Memory Access)
  localparam  IDLE_S                    = 4'd0,
              DMA_WRITE_S               = 4'd1,
              WAIT_FREE_PBUF_S          = 4'd2,
              DMA_READ_DATA_TOP_2B_S    = 4'd3,
              DMA_READ_DATA_S           = 4'd4,
              WAIT_NEXT_PBUF_S          = 4'd5,
              READ_END_PBUF_S           = 4'd6,
              WAIT_1_S                  = 4'd7,
              DISCARD_S                 = 4'd8;
  //==============================================================//


  //======================= Write & Read SRAM ====================//
  //* write SRAM & read SRAM; 
  reg [3:0]   state_dma;
  reg [15:0]  r_length_pBuf;  //* length of current pBuf;
  reg [31:0]  r_tempData_wr[3:0];
  reg [1:0]   r_cnt_wr, r_tag_head_end;
  reg         r_tag_wait_end;
  reg [1:0]   r_temp_dma_rden;
  integer i;
  //* for test; 
  reg [15:0]  cnt_clk;
  assign      o_dma_wdata = (o_data_rden == 1'b1)? {i_data[103:96],i_data[111:104],i_data[119:112],i_data[127:120]}: 
              (r_cnt_wr == 2'b0)?               {r_tempData_wr[0][7:0],  r_tempData_wr[0][15:8],
                                                 r_tempData_wr[0][23:16],r_tempData_wr[0][31:24]}:
              (r_cnt_wr == 2'd1)?               {r_tempData_wr[1][7:0],  r_tempData_wr[1][15:8],
                                                 r_tempData_wr[1][23:16],r_tempData_wr[1][31:24]}:
              (r_cnt_wr == 2'd2)?               {r_tempData_wr[2][7:0],  r_tempData_wr[2][15:8],
                                                 r_tempData_wr[2][23:16],r_tempData_wr[2][31:24]}:
                                                {r_tempData_wr[3][7:0],  r_tempData_wr[3][15:8],
                                                 r_tempData_wr[3][23:16],r_tempData_wr[3][31:24]};
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_dma_rden                          <= 1'b0;
      o_dma_wren                          <= 1'b0;
      // o_dma_wdata                         <= 32'b0;
      o_dma_addr                          <= 32'b0;
      //* fifo;
      o_data_rden                         <= 1'b0;
      o_rden_pBufWR                       <= 1'b0;
      o_rden_pBufRD                       <= 1'b0;
      o_wren_int                          <= 1'b0;
      o_din_int                           <= 32'b0;
      r_length_pBuf                       <= 16'b0;
      r_cnt_wr                            <= 2'b0;
      r_tag_head_end                      <= 2'b0;
      r_tag_wait_end                      <= 1'b0;
      r_temp_dma_rden                     <= 2'b0;
      for(i=0; i<4; i=i+1)
        r_tempData_wr[i]                  <= 32'b0;
      {r_din_16bData[0],r_din_16bData[1]} <= 32'b0;
      w_wren_16bData                      <= 2'b0;
      {r_din_endTag, r_din_validTag}      <= 5'b0;

      state_dma                           <= IDLE_S;
      cnt_clk                             <= 16'b0;
    end 
    else begin
      r_temp_dma_rden                     <= {r_temp_dma_rden[0], o_dma_rden};
      case(state_dma)
        IDLE_S: begin
          o_wren_int                      <= 1'b0;
          w_wren_16bData                  <= 2'b0;
          o_dma_wren                      <= 1'b0;
          o_data_rden                     <= 1'b0;
          //* dma_wr;
          if(i_empty_data == 1'b0 && i_empty_pBufWR == 1'b0) begin 
            //* check head tag;
            if(i_data[133:132] == 2'b11) begin
              o_data_rden                 <= 1'b1;
              o_rden_pBufWR               <= 1'b1;
              r_cnt_wr                    <= 2'b0;
              o_din_int                   <= {1'b1, i_dout_pBufWR[30:0]};
              state_dma                   <= DMA_WRITE_S;
            end
            else begin
              //* discard pkt data untile meeting a new head;
              o_data_rden                 <= 1'b1;
              state_dma                   <= DISCARD_S;
            end
          end
          //* dma_rd;
          else if((i_usedw_pBufRD[9:1] != 9'b0) && 
            (i_usedw_9b < 9'd100)) 
          begin
            o_rden_pBufRD                 <= 1'b1;
            r_cnt_wr                      <= 2'b0;
            if(i_dout_pBufRD[1:0] == 2'd2)
              state_dma                   <= DMA_READ_DATA_TOP_2B_S;
            else
              state_dma                   <= DMA_READ_DATA_S;
            o_din_int                     <= {1'b0, i_dout_pBufRD[30:0]};
            r_din_validTag                <= (i_dout_pBufRD[48+:4] - 4'd1);
            r_din_endTag                  <= 1'b0;
            r_tag_wait_end                <= 1'b0;
          end
          else begin
            state_dma                     <= IDLE_S;
          end
        end
        DMA_WRITE_S: begin
          o_data_rden                     <= 1'b0;
          o_rden_pBufWR                   <= 1'b0;
          o_dma_wren                      <= 1'b1;
          //* decrease r_length_pBuf after finish four writing;
          r_length_pBuf                   <= (o_data_rden == 1'b1)? r_length_pBuf - 16'd16: r_length_pBuf;
          //* get r_tempData_wr;
          if(o_data_rden == 1'b1) begin
            {r_tag_head_end, r_tempData_wr[0], r_tempData_wr[1], r_tempData_wr[2],
                                r_tempData_wr[3]} <= {i_data[133:132], i_data[127:0]};
          end
          //* get {r_length_pBuf, o_dma_addr};
          if(o_rden_pBufWR == 1'b1) begin
            {r_length_pBuf, o_dma_addr}   <= {i_dout_pBufWR[47:32],2'b0,i_dout_pBufWR[31:2]};
            r_cnt_wr                      <= 2'b0;
          end
          else begin
            //* increase o_dma_addr after finish one writing;
            o_dma_addr                    <= (i_dma_gnt == 1'b1)? (o_dma_addr + 32'd1): o_dma_addr;
            //* increase r_cnt_wr after finish one writing;
            r_cnt_wr                      <= (i_dma_gnt == 1'b1)? (r_cnt_wr + 2'd1): r_cnt_wr;
            //* update o_dma_wdata;
            // (*full_case, paralle_case*)
            // case(r_cnt_wr)
            //   2'd0: o_dma_wdata           <= (o_data_rden == 1'b1)? {i_data[103:96],i_data[111:104],i_data[119:112],i_data[127:120]}: 
            //                               {r_tempData_wr[0][7:0],  r_tempData_wr[0][15:8],
            //                                 r_tempData_wr[0][23:16],r_tempData_wr[0][31:24]};
            //   2'd1: o_dma_wdata           <= {r_tempData_wr[1][7:0],  r_tempData_wr[1][15:8],
            //                                 r_tempData_wr[1][23:16],r_tempData_wr[1][31:24]};
            //   2'd2: o_dma_wdata           <= {r_tempData_wr[2][7:0],  r_tempData_wr[2][15:8],
            //                                 r_tempData_wr[2][23:16],r_tempData_wr[2][31:24]};
            //   2'd3: o_dma_wdata           <= {r_tempData_wr[3][7:0],  r_tempData_wr[3][15:8],
            //                                 r_tempData_wr[3][23:16],r_tempData_wr[3][31:24]};
            // endcase
          end
          
          //* finish writing;
          if(r_tag_head_end == 2'b10 && r_cnt_wr == 2'd3 && i_dma_gnt == 1'b1) begin 
            o_wren_int                    <= 1'b1;  //* gen a int.
            state_dma                     <= WAIT_1_S;
            o_dma_wren                    <= 1'b0;
          end
          //* read next pBuf
          else if((r_length_pBuf[15:4] == 12'b0 || r_length_pBuf == 16'h10) && 
            (r_cnt_wr == 2'd3) && i_dma_gnt == 1'b1) 
          begin
            if(i_empty_pBufWR == 1'b0) 
            begin
              o_data_rden                 <= 1'b1;
              o_rden_pBufWR               <= 1'b1;
            end
            else
              state_dma                   <= WAIT_FREE_PBUF_S;
            o_dma_wren                    <= 1'b0;
          end
          //* read next data;
          else if(r_cnt_wr == 2'd3 && i_dma_gnt == 1'b1) begin
            o_data_rden                   <= 1'b1;
          end
        end
        WAIT_FREE_PBUF_S: begin
          cnt_clk                         <= 16'd1 + cnt_clk;
          o_dma_wren                      <= 1'b0;
          if(i_empty_pBufWR == 1'b0) begin
            cnt_clk                       <= 16'b0;
            o_data_rden                   <= 1'b1;
            o_rden_pBufWR                 <= 1'b1;
            state_dma                     <= (i_dout_pBufWR[31] == 1'b1)? DISCARD_S: DMA_WRITE_S;
          end
        end
        DMA_READ_DATA_TOP_2B_S: begin //* for ethernet;
          o_rden_pBufRD                   <= 1'b0;
          o_dma_rden                      <= 1'b1;

          //* get {r_length_pBuf, o_dma_addr};
          if(o_rden_pBufRD == 1'b1) begin
            o_dma_addr                    <= {2'b0, i_dout_pBufRD[31:2]};
            r_length_pBuf                 <= i_dout_pBufRD[47:32] - 16'd2;
          end
          else begin
            //* increase o_dma_addr after one dma reading;
            o_dma_addr                    <= (i_dma_gnt == 1'b1)? (o_dma_addr + 32'd1): o_dma_addr;
            //* decrease o_dma_addr after one dma reading;
            r_length_pBuf                 <= (i_dma_gnt == 1'b1)? (r_length_pBuf - 16'd4): r_length_pBuf;
          end

          if(r_cnt_wr[0] == 1'b1 && i_dma_rvalid == 1'b1) begin
            w_wren_16bData[1]             <= 1'b1;
            r_din_16bData[1]              <= {i_dma_rdata[23:16],i_dma_rdata[31:24]};
          end
          else if(i_dma_rvalid == 1'b1) begin 
            w_wren_16bData[0]             <= 1'b1;
            r_din_16bData[0]              <= {i_dma_rdata[23:16],i_dma_rdata[31:24]};
          end
          r_cnt_wr                        <= (i_dma_rvalid == 1'b1)? 2'd1 + r_cnt_wr: r_cnt_wr;
          state_dma                       <= (i_dma_rvalid == 1'b1)? DMA_READ_DATA_S: 
                                              DMA_READ_DATA_TOP_2B_S;
        end
        DMA_READ_DATA_S: begin
          o_rden_pBufRD                   <= 1'b0;
          o_dma_rden                      <= 1'b1;

          w_wren_16bData                  <= (i_dma_rvalid == 1'b1)? 2'd3: 2'd0;
          if(r_cnt_wr[0] == 1'b1) begin
            r_din_16bData[1]              <= {i_dma_rdata[7:0],   i_dma_rdata[15:8]};
            r_din_16bData[0]              <= {i_dma_rdata[23:16], i_dma_rdata[31:24]};
          end
          else begin 
            r_din_16bData[0]              <= {i_dma_rdata[7:0],   i_dma_rdata[15:8]};
            r_din_16bData[1]              <= {i_dma_rdata[23:16], i_dma_rdata[31:24]};
          end
          
          //* get {r_length_pBuf, o_dma_addr};
          o_dma_addr                      <= (i_dma_gnt == 1'b1)? (o_dma_addr + 32'd1): o_dma_addr;
          if(o_rden_pBufRD == 1'b1) begin
            {r_length_pBuf, o_dma_addr}   <= {(i_dout_pBufRD[47:32]-16'd4), 
                                                2'b0, i_dout_pBufRD[31:2]};
          end
          //* wait next pbuf;
          else if((r_length_pBuf == 16'h4 || r_length_pBuf[15:2] == 14'b0) && i_dma_gnt == 1'b1) begin
            o_dma_rden                    <= ~r_tag_wait_end;
            r_tag_wait_end                <= 1'b1;
            r_length_pBuf                 <= r_length_pBuf;
            state_dma                     <= (r_temp_dma_rden[0] == 1'b0)? 
                                              WAIT_NEXT_PBUF_S: DMA_READ_DATA_S;
            if(r_temp_dma_rden[0] == 1'b0 && r_length_pBuf[1] == 1'b1) begin
              //* write 16b (high or low);
              r_cnt_wr                    <= r_cnt_wr + 2'd1;
              w_wren_16bData              <= (r_cnt_wr[0] == 1'b0)? 2'd1: 2'd2;
            end
          end
          else begin
            r_length_pBuf                 <= (i_dma_gnt == 1'b1)? (r_length_pBuf - 16'd4): r_length_pBuf;
          end
        end
        WAIT_NEXT_PBUF_S: begin
          o_dma_rden                      <= 1'b0;
          r_tag_wait_end                  <= 1'b0;
          w_wren_16bData                  <= 2'd0;
          if(i_empty_pBufRD == 1'b0) 
          begin
            o_rden_pBufRD                 <= 1'b1;

            if(i_dout_pBufRD[31:0] == 32'h80000000) 
            begin
              o_wren_int                  <= 1'b1; //* tell cpu;
              w_wren_16bData              <= 2'd3;
              r_din_endTag                <= 1'b1;
              r_din_16bData[0]            <= 16'b0;
              r_din_16bData[1]            <= 16'b0;

              state_dma                   <= READ_END_PBUF_S;
            end
            else begin
              o_rden_pBufRD               <= 1'b1;
              if(i_dout_pBufRD[1:0] == 2'b10) 
              begin
                state_dma                 <= DMA_READ_DATA_TOP_2B_S;
              end
              else
                state_dma                 <= DMA_READ_DATA_S;
              o_din_int     <= {1'b0, i_dout_pBufRD[30:0]};
            end
          end
        end
        READ_END_PBUF_S: begin
          o_wren_int                      <= 1'b0;
          o_rden_pBufRD                   <= 1'b0;
          w_wren_16bData                  <= (r_cnt_wr[0] == 1'b1)? 2'b10: 2'b0;
          state_dma                       <= IDLE_S;
        end
        WAIT_1_S: begin
          o_wren_int                      <= 1'b0;
          o_dma_wren                      <= 1'b0;
          state_dma                       <= IDLE_S;
        end
        DISCARD_S: begin
          o_rden_pBufWR                   <= 1'b0;
          if(i_data[133:132] == 2'b10) begin
            o_data_rden                   <= 1'b0;
            state_dma                     <= WAIT_1_S;
          end
          else begin
            o_data_rden                   <= o_data_rden;
            state_dma                     <= DISCARD_S;
          end
        end
        default: begin 
          state_dma                       <= IDLE_S;
        end
      endcase
    end
  end
  //==============================================================//

  assign  o_wait_free_pBufWR  = (state_dma == WAIT_FREE_PBUF_S);

endmodule
