/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_TCP_CRC.
 *  Description:        This module is used to calc. tcp's checksum;
 *  Last updated date:  2022.09.19.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_TCP_CRC(
   input  wire              i_clk
  ,input  wire              i_rst_n
  //* calculate crc;
  ,input  wire              i_data_valid
  ,input  wire  [133:0]     i_data
  ,output wire              o_data_valid
  ,output wire  [133:0]     o_data
);

  
  //======================= internal reg/wire/param declarations =//
  reg           [133:0]     r_data_calc       ;
  reg                       r_data_calc_valid ;

  //* fifo;
  //* fifo_calc_pkt;
  reg   [133:0]             din_pkt, temp_din_pkt;
  reg                       rden_pkt, wren_pkt, temp_wren_pkt;
  wire  [133:0]             dout_pkt;
  wire                      empty_pkt;
  
  //* fifo crc;
  reg   [15:0]              din_crc;
  reg                       rden_crc, wren_crc;
  wire  [15:0]              dout_crc;
  wire                      empty_crc;

  //* temp;
  reg   [31:0]              r_crcRst[7:0];  
  wire  [15:0]              w_bm_invalid_Byte;
  
  
  //* state;
  reg   [3:0]               state_calc, state_out;
  localparam                IDLE_S            = 4'd0,
                            READ_META_1_S     = 4'd1,
                            READ_DATA_0_S     = 4'd2,
                            READ_DATA_1_S     = 4'd3,
                            READ_DATA_2_S     = 4'd4,
                            READ_DATA_3_S     = 4'd5,
                            WAIT_END_S        = 4'd6,
                            CALC_CRC_0_S      = 4'd7,
                            CALC_CRC_1_S      = 4'd8,
                            WRITE_CRC_S       = 4'd9,
                            READ_META_0_S     = 4'd10;

  assign                    o_data            = r_data_calc;
  assign                    o_data_valid      = r_data_calc_valid;
  //* change 4b tag_valid to 16b bm_invalid;
  assign                    w_bm_invalid_Byte = 16'h7f >> i_data[131:128];
  //==============================================================//

  //======================= calc crc       =======================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      //* temp;
      for(i=0; i<8; i=i+1) begin
        r_crcRst[i]               <= 32'b0;
      end
      din_crc                     <= 16'b0;
      wren_crc                    <= 1'b0;
      //* state
      state_calc                  <= IDLE_S;
    end
    else begin
      case(state_calc)
        IDLE_S: begin
          wren_crc            <= 1'b0;
          if(i_data_valid == 1'b1) begin
            state_calc            <= (i_data[51] == 1'b1)? READ_META_1_S: WAIT_END_S;
            for(i=0; i<8; i=i+1) begin
              r_crcRst[i]         <= 32'b0;
            end
          end
          else begin
            state_calc            <= IDLE_S;
          end
        end
        READ_META_1_S: begin
          state_calc              <= (i_data_valid == 1'b1)? READ_DATA_0_S: READ_META_1_S;
        end
        READ_DATA_0_S: begin
          state_calc              <= (i_data_valid == 1'b1)? READ_DATA_1_S: READ_DATA_0_S;
        end
        READ_DATA_1_S: begin
          if(i_data_valid == 1'b1) begin
            state_calc            <= READ_DATA_2_S;
            //* add proto, len, ip_addr;
            r_crcRst[0]           <= 32'h6;
            r_crcRst[1]           <= {16'b0, i_data[127:112] - 16'd20};
            r_crcRst[2]           <= {16'b0, i_data[47:32]};
            r_crcRst[3]           <= {16'b0, i_data[31:16]};
            r_crcRst[4]           <= {16'b0, i_data[15:0]};
          end
          else begin
            state_calc            <= READ_DATA_1_S;
          end
        end
        READ_DATA_2_S: begin
          if(i_data_valid == 1'b1) begin
            for(i=0; i<8; i=i+1) begin
              r_crcRst[i]         <= {16'b0,i_data[i*16+:16]} + r_crcRst[i];
            end
            state_calc            <= READ_DATA_3_S;
          end
          else begin
            state_calc            <= READ_DATA_2_S;
          end
        end
        READ_DATA_3_S: begin
          if(i_data_valid == 1'b1) begin
            for(i=0; i<6; i=i+1) begin
              r_crcRst[i]         <= {16'b0,i_data[i*16+:16]} + r_crcRst[i];
            end
            r_crcRst[7]           <= {16'b0,i_data[7*16+:16]} + r_crcRst[7];
            state_calc            <= WAIT_END_S;
          end
          else begin
            state_calc            <= READ_DATA_3_S;
          end
        end
        WAIT_END_S: begin
          if(i_data_valid == 1'b1) begin
            //* invalid end;
            if(i_data[133:132] == 2'b11) begin
              //* pkt tail;
              for(i=0; i<6; i=i+1) begin
                r_crcRst[i]       <= r_crcRst[i];
              end
            end
            else begin
              //* pkt body
              for(i=0; i<8; i=i+1) begin
                r_crcRst[i]       <= (w_bm_invalid_Byte[i] == 1'b0)? ({16'b0,i_data[i*16+:16]} + r_crcRst[i]): r_crcRst[i];
              end
            end
            
            state_calc            <= (i_data[133:132] == 2'b11)? CALC_CRC_0_S: WAIT_END_S;
          end
          else begin
            state_calc            <= WAIT_END_S;
          end
        end
        CALC_CRC_0_S: begin
          r_crcRst[0]             <= r_crcRst[0]+ r_crcRst[3]+ r_crcRst[6];
          r_crcRst[1]             <= r_crcRst[1]+ r_crcRst[4]+ r_crcRst[7];
          r_crcRst[2]             <= r_crcRst[2]+ r_crcRst[5];
          state_calc              <= CALC_CRC_1_S;
        end
        CALC_CRC_1_S: begin
          r_crcRst[0]             <= r_crcRst[0]+ r_crcRst[1]+ r_crcRst[2];
          state_calc              <= WRITE_CRC_S;
        end
        WRITE_CRC_S: begin
          din_crc                 <= ~ (r_crcRst[0][15:0]+ r_crcRst[0][31:16]);
          wren_crc                <= 1'b1;
          state_calc              <= IDLE_S;
        end
        default: begin
          state_calc              <= IDLE_S;
        end
      endcase
    end
  end
  //==============================================================//

  //======================Write pktCalc to FIFO ==================//
  //* write dma_fifo;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      din_pkt                     <= 134'b0;
      wren_pkt                    <= 1'b0;
      temp_din_pkt                <= 134'b0;
      temp_wren_pkt               <= 1'b0;
    end else begin
      temp_din_pkt                <= i_data;
      temp_wren_pkt               <= i_data_valid;
      wren_pkt                    <= temp_wren_pkt;
      din_pkt                     <= temp_din_pkt;

      //* Last data should be ignored, in format {2'b11, xxx};
      //* Noted that metadata in dma_pkt is in format {2'b01, xxx} & {2'b00, xxx};
      if(i_data_valid == 1'b1 && i_data[133:132] == 2'b11) begin
        din_pkt                   <= {2'b10,i_data[131:128],
                                          temp_din_pkt[127:0]};
      end
      else if(temp_wren_pkt == 1'b1 && temp_din_pkt[133:132] == 2'b11)
        wren_pkt                  <= 1'b0;
    end
  end
  //==============================================================//

  //======================Output Pkt (calc)  =====================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* fifo;
      rden_crc                    <= 1'b0;
      rden_pkt                    <= 1'b0;
      //* output;
      r_data_calc_valid           <= 1'b0;
      r_data_calc                 <= 134'b0;
      //* state;
      state_out                  <= IDLE_S;
    end else begin
      case(state_out)
        IDLE_S: begin
          rden_crc                <= 1'b0;
          r_data_calc_valid       <= 1'b0;
          if(empty_crc == 1'b0) begin
            rden_pkt              <= 1'b1;
            state_out             <= READ_META_0_S;
          end
          else begin
            state_out             <= IDLE_S;
          end
        end
        READ_META_0_S: begin
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          state_out               <= (dout_pkt[51] == 1'b1)? READ_META_1_S: WAIT_END_S;
          rden_crc                <= (dout_pkt[51] == 1'b1)? 1'b0: 1'b1;
        end
        READ_META_1_S: begin
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          state_out               <= READ_DATA_0_S;
        end
        READ_DATA_0_S: begin
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          state_out               <= READ_DATA_1_S;
        end
        READ_DATA_1_S: begin
          rden_crc                <= 1'b0;
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          state_out               <= READ_DATA_2_S;
        end
        READ_DATA_2_S: begin
          rden_crc                <= 1'b1;
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          state_out               <= READ_DATA_3_S;
        end
        READ_DATA_3_S: begin
          rden_crc                <= 1'b0;
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          r_data_calc[111:96]     <= dout_crc;
          rden_pkt                <= (dout_pkt[133:132] == 2'b10)? 1'b0: 1'b1;
          state_out               <= (dout_pkt[133:132] == 2'b10)? IDLE_S: WAIT_END_S;
        end
        WAIT_END_S: begin
          rden_crc                <= 1'b0;
          r_data_calc_valid       <= 1'b1;
          r_data_calc             <= dout_pkt;
          rden_pkt                <= (dout_pkt[133:132] == 2'b10)? 1'b0: 1'b1;
          state_out               <= (dout_pkt[133:132] == 2'b10)? IDLE_S: WAIT_END_S;
        end
        default: begin
          state_out               <= IDLE_S;
        end
      endcase
    end
  end
  //==============================================================//

  `ifdef XILINX_FIFO_RAM
    fifo_134b_512 fifo_pktDMA_calc (
      .clk                  (i_clk                    ),  // input wire clk
      .srst                 (!i_rst_n                 ),  // input wire srst
      .din                  (din_pkt                  ),  // input wire [133 : 0] din
      .wr_en                (wren_pkt                 ),  // input wire wr_en
      .rd_en                (rden_pkt                 ),  // input wire rd_en
      .dout                 (dout_pkt                 ),  // output wire [133 : 0] dout
      .empty                (empty_pkt                )   // output wire empty
    );

    fifo_16b_512 fifo_crc_calc (
      .clk                  (i_clk                    ),  // input wire clk
      .srst                 (!i_rst_n                 ),  // input wire srst
      .din                  (din_crc                  ),  // input wire [133 : 0] din
      .wr_en                (wren_crc                 ),  // input wire wr_en
      .rd_en                (rden_crc                 ),  // input wire rd_en
      .dout                 (dout_crc                 ),  // output wire [133 : 0] dout
      .empty                (empty_crc                )   // output wire empty
    );
  `elsif SIM_FIFO_RAM
    syncfifo fifo_pktDMA_calc (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_pkt                  ),  //* The Inport of data 
      .wrreq                (wren_pkt                 ),  //* active-high
      .rdreq                (rden_pkt                 ),  //* active-high
      .q                    (dout_pkt                 ),  //* The output of data
      .empty                (empty_pkt                ),  //* Read domain empty
      .usedw                (                         ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_pktDMA_calc.width = 134,
              fifo_pktDMA_calc.depth = 7,
              fifo_pktDMA_calc.words = 128;

    syncfifo fifo_crc_calc (
      .clock                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_crc                  ),  //* The Inport of data 
      .wrreq                (wren_crc                 ),  //* active-high
      .rdreq                (rden_crc                 ),  //* active-high
      .q                    (dout_crc                 ),  //* The output of data
      .empty                (empty_crc                ),  //* Read domain empty
      .usedw                (                         ),  //* Usedword
      .full                 (                         )   //* Full
    );
    defparam  fifo_crc_calc.width = 16,
              fifo_crc_calc.depth = 7,
              fifo_crc_calc.words = 128;

  `else
    SYNCFIFO_128x134 fifo_pkt (
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_pkt                  ),  //* The Inport of data 
      .rdreq                (rden_pkt                 ),  //* active-high
      .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                (wren_pkt                 ),  //* active-high
      .q                    (dout_pkt                 ),  //* The output of data
      .rdempty              (empty_pkt                ),  //* Read domain empty
      .rdalempty            (                         ),  //* Read domain almost-empty
      .wrusedw              (                         ),  //* Write-usedword
      .rdusedw              (                         )   //* Read-usedword
    );


    SYNCFIFO_32x16 fifo_crc_calc (
      .aclr                 (!i_rst_n                 ),  //* Reset the all signal
      .data                 (din_crc                  ),  //* The Inport of data 
      .rdreq                (rden_crc                 ),  //* active-high
      .clk                  (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                (wren_crc                 ),  //* active-high
      .q                    (dout_crc                 ),  //* The output of data
      .rdempty              (empty_crc                ),  //* Read domain empty
      .rdalempty            (                         ),  //* Read domain almost-empty
      .wrusedw              (                         ),  //* Write-usedword
      .rdusedw              (                         )   //* Read-usedword
    );

  `endif

endmodule