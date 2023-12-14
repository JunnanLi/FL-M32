/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Pkt_Asyn_Proc.
 *  Description:        This module is used to recv packets.
 *  Last updated date:  2022.07.22.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

`timescale 1 ns / 1 ps

module Pkt_Asyn_Recv(
   input  wire              i_sys_clk
  ,input  wire              i_sys_rst_n
  ,input  wire              i_pe_clk
  ,input  wire              i_rst_n
  //* interface for recv/send pkt;
  ,input  wire  [47:0]      i_pe_conf_mac
  ,(* mark_debug = "true"*)input  wire              i_data_valid
  ,(* mark_debug = "true"*)input  wire  [133:0]     i_data
  ,(* mark_debug = "true"*)input  wire              i_meta_valid
  ,(* mark_debug = "true"*)input  wire  [167:0]     i_meta
  //* output;
  ,(* mark_debug = "true"*)output reg               o_data_DMA_valid
  ,(* mark_debug = "true"*)output reg   [133:0]     o_data_DMA 
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
  //* asyn recv pkt & conf_pkt;
  reg           [133:0]     r_din_asfifo;
  reg                       r_rden_asfifo, r_wren_asfifo;
  wire          [133:0]     w_dout_asfifo;
  wire          [9:0]       w_usedw_asfifo;
  reg           [133:0]     r_din_conf;
  reg                       r_rden_conf, r_wren_conf;
  wire          [133:0]     w_dout_conf;
  reg                       r_rden_conf_valid, r_wren_conf_valid;
  wire                      w_empty_conf_valid;
  reg           [1:0]       r_tag_conf_normal;
  //* asyn recv meta;
  reg                       r_rden_meta, r_wren_meta;
  reg           [167:0]     r_din_meta;
  wire                      w_empty_meta;
  wire          [167:0]     w_dout_meta;
  //* tag to back pressure CMP;
  reg                       r_back_pressure;
  //* state;
  (* mark_debug = "true"*)reg           [2:0]       state_recv;
  localparam                IDLE_S          = 3'd0,
                            OUTPUT_META_0_S = 3'd1,
                            OUTPUT_META_1_S = 3'd2,
                            OUTPUT_PKT_S    = 3'd3,
                            OUTPUT_CONF_S   = 3'd4,
                            DISCARD_S       = 3'd5,
                            DISCARD_CONF_S  = 3'd6;

  //==============================================================//
 
  //======================= Read Pkt From AsFIFO =================//
  //* write meta_fifo & conf_pkt;
  always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
    if(~i_sys_rst_n) begin
      r_wren_meta           <= 1'b0;
      r_din_meta            <= 168'b0;
      r_wren_conf           <= 1'b0;
      r_wren_conf_valid     <= 1'b0;
      r_din_conf            <= 134'b0;
      r_wren_asfifo         <= 1'b0;
      r_din_asfifo          <= 134'b0;
      r_back_pressure       <= 1'b0;
      o_conf_port           <= 8'h1;
      r_tag_conf_normal     <= 2'b0;
    end else begin
      //* configure r_back_pressure;
      if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01 && 
        i_data[31:16] == 16'h9005 && i_data[3:0] == 4'd6 &&
        i_pe_conf_mac == i_data[127:80])
      begin
        r_back_pressure     <= i_data[8];
      end
      else begin
        r_back_pressure     <= r_back_pressure;
      end
      //* get o_conf_port;
      if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01 && 
        i_data[31:16] == 16'h9005 && i_pe_conf_mac == i_data[127:80])
      begin
        o_conf_port         <= r_din_meta[159-:8];
      end
      else begin
        o_conf_port         <= o_conf_port;
      end

      //* meta;
      r_din_meta            <= (i_meta_valid == 1'b1)? i_meta: r_din_meta;
      r_wren_meta           <= (r_wren_asfifo == 1'b1 && r_din_asfifo[133:132] == 2'b10);
      //* conf_pkt;
      r_wren_conf           <= r_tag_conf_normal[1] & i_data_valid;
      r_din_conf            <= i_data;
      //* normal_pkt;
      r_wren_asfifo         <= r_tag_conf_normal[0] & i_data_valid;
      r_din_asfifo          <= i_data;
      r_tag_conf_normal     <= r_tag_conf_normal;
      if(i_data_valid == 1'b1 && i_data[133:132] == 2'b01) begin 
        r_wren_conf         <= (i_data[31:16] == 16'h9005);
        r_tag_conf_normal[1]<= (i_data[31:16] == 16'h9005);
        r_wren_asfifo       <= (i_data[31:16] != 16'h9005) & ((w_usedw_asfifo < 10'd150)|r_back_pressure);
        r_tag_conf_normal[0]<= (i_data[31:16] != 16'h9005) & ((w_usedw_asfifo < 10'd150)|r_back_pressure);
      end
      else if(i_data[133:132] == 2'b10) begin
        r_tag_conf_normal   <= 2'b0;
      end
      r_wren_conf_valid     <= (r_wren_conf == 1'b1 && r_din_conf[133:132] == 2'b10)? 1'b1: 1'b0;
      `ifdef SIM_ENV
        r_wren_conf_valid   <= (r_wren_conf == 1'b1 && r_din_conf[133:132] == 2'b01)? 1'b1: 1'b0;
      `endif
    end
  end
  //==============================================================//

  //======================= Read Pkt From AsFIFO =================//
  //* output o_alf;
  reg [15:0]  test_cnt_clk;
  assign  o_alf                 = (w_usedw_asfifo > 10'd240)? r_back_pressure: 1'b0;
  //* read pkt & meta from asyn_fifo;
  always @(posedge i_pe_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_rden_asfifo             <= 1'b0;
      r_rden_meta               <= 1'b0;
      r_rden_conf               <= 1'b0;
      r_rden_conf_valid         <= 1'b0;
      //* output;
      o_data_DMA                <= 134'b0;
      o_data_DMA_valid          <= 1'b0;
      o_data_DRA                <= 134'b0;
      o_data_DRA_valid          <= 1'b0;
      o_data_conf               <= 134'b0;
      o_data_conf_valid         <= 1'b0;
      //* state;
      state_recv                <= IDLE_S;

      test_cnt_clk              <= 16'b0;
    end 
    else begin
      //* all to configure;      
      r_rden_meta               <= 1'b0;
      r_rden_conf_valid         <= 1'b0;
      case(state_recv)
        IDLE_S: begin
          test_cnt_clk          <= 16'b0;

          o_data_DMA_valid      <= 1'b0;
          o_data_DRA_valid      <= 1'b0;
          o_data_conf_valid     <= 1'b0;
          r_rden_meta           <= 1'b0;
          //* read meta & output in pkt header;
          if(w_empty_conf_valid == 1'b0) begin
            r_rden_conf_valid   <= 1'b1;
            r_rden_conf         <= 1'b1;
            state_recv          <= (i_pe_conf_mac == w_dout_conf[127:80] && 
                                    w_dout_conf[31:16] == 16'h9005)? 
                                      OUTPUT_CONF_S: DISCARD_CONF_S;
          end
          //* discard;
          else if(w_empty_meta == 1'b0 && w_dout_meta[118] == 1'b1) 
          begin
            r_rden_meta         <= 1'b1;
            state_recv          <= DISCARD_S;
          end
          //* DMA;
          else if(w_empty_meta == 1'b0 && o_data_DMA_valid == 1'b0 && 
            i_alf_dma == 3'b0 && w_dout_meta[119] == 1'b1) 
          begin
            o_data_DMA_valid    <= 1'b1;
            o_data_DMA          <= {2'b11,4'h0,w_dout_asfifo[87:80],
                                    w_dout_asfifo[39:32],w_dout_asfifo[23:16],
                                    w_dout_meta[167:64]};
            state_recv          <= OUTPUT_META_1_S;
          end
          //* DRA;
          else if(w_empty_meta == 1'b0 && o_data_DMA_valid == 1'b0 && 
            i_alf_dra == 1'b0 && w_dout_meta[119] == 1'b0) 
          begin
            o_data_DRA_valid    <= 1'b1;
            o_data_DRA          <= {2'b11,4'h0,24'b0,w_dout_meta[167:64]};
            state_recv          <= OUTPUT_META_1_S;
          end
          else begin
            state_recv          <= IDLE_S;
          end
        end
        OUTPUT_META_1_S: begin
          //* output the second meta;
          o_data_DMA_valid      <= o_data_DMA_valid;
          o_data_DRA_valid      <= o_data_DRA_valid;
          o_data_DMA            <= {2'b11,4'h0,64'b0,w_dout_meta[63:0]};
          o_data_DRA            <= {2'b11,4'h0,64'b0,w_dout_meta[63:0]};
          r_rden_asfifo         <= 1'b1;
          r_rden_meta           <= 1'b1;
          state_recv            <= OUTPUT_PKT_S;
        end
        OUTPUT_PKT_S: begin
          test_cnt_clk          <= 16'd1 + test_cnt_clk;
          r_rden_meta           <= 1'b0;
          //* output pkt;
          o_data_DMA_valid      <= o_data_DMA_valid;
          o_data_DRA_valid      <= o_data_DRA_valid;
          o_data_DMA            <= w_dout_asfifo;
          o_data_DRA            <= w_dout_asfifo;
          if(w_dout_asfifo[133:132] == 2'b10) begin
            r_rden_asfifo       <= 1'b0;
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= OUTPUT_PKT_S;
          end
        end
        OUTPUT_CONF_S: begin
          r_rden_meta           <= 1'b0;
          //* output pkt;
          o_data_conf_valid     <= 1'b1;
          o_data_conf           <= w_dout_conf;
          if(w_dout_conf[133:132] == 2'b10) begin
            r_rden_conf       <= 1'b0;
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= OUTPUT_CONF_S;
          end
        end
        DISCARD_S: begin
          r_rden_meta           <= 1'b0;
          r_rden_asfifo         <= 1'b1;
          if(w_dout_asfifo[133:132] == 2'b10) begin
            r_rden_asfifo       <= 1'b0;
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= DISCARD_S;
          end
        end
        DISCARD_CONF_S: begin
          r_rden_conf           <= 1'b1;
          if(w_dout_conf[133:132] == 2'b10) begin
            r_rden_conf         <= 1'b0;
            state_recv          <= IDLE_S;
          end
          else begin
            state_recv          <= DISCARD_CONF_S;
          end
        end
        default: begin
          state_recv            <= IDLE_S;
        end
      endcase
    end
  end
  //==============================================================//



  `ifdef XILINX_FIFO_RAM
    asfifo_134_512 asfifo_recv_data(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_sys_clk            ),
      .rd_clk                 (i_pe_clk             ),
      .din                    (r_din_asfifo         ),
      .wr_en                  (r_wren_asfifo        ),
      .rd_en                  (r_rden_asfifo        ),
      .dout                   (w_dout_asfifo        ),
      .full                   (                     ),
      .empty                  (                     ),
      .wr_data_count          (w_usedw_asfifo       )
    );

    asfifo_168b_512 asfifo_recv_meta(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_sys_clk            ),
      .rd_clk                 (i_pe_clk             ),
      .din                    (r_din_meta           ),
      .wr_en                  (r_wren_meta          ),
      .rd_en                  (r_rden_meta          ),
      .dout                   (w_dout_meta          ),
      .full                   (                     ),
      .empty                  (w_empty_meta         )
    );

    asfifo_134_512 asfifo_recv_conf(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_sys_clk            ),
      .rd_clk                 (i_pe_clk             ),
      .din                    (r_din_conf           ),
      .wr_en                  (r_wren_conf          ),
      .rd_en                  (r_rden_conf          ),
      .dout                   (w_dout_conf          ),
      .full                   (                     ),
      .empty                  (                     ),
      .wr_data_count          (                     )
    );

    asfifo_1b_512 asfifo_recv_conf_valid(
      .rst                    (!i_rst_n             ),
      .wr_clk                 (i_sys_clk            ),
      .rd_clk                 (i_pe_clk             ),
      .din                    (1'b0                 ),
      .wr_en                  (r_wren_conf_valid    ),
      .rd_en                  (r_rden_conf_valid    ),
      .dout                   (                     ),
      .full                   (                     ),
      .empty                  (w_empty_conf_valid   )
    );
  `else 
    ASYNCFIFO_256x134 asfifo_recv_data(
      .rd_aclr                (!i_rst_n             ),  //* Reset the all read signal
      .wr_aclr                (!i_sys_rst_n         ),  //* Reset the all write signal
      .data                   (r_din_asfifo         ),  //* The Inport of data 
      .rdclk                  (i_pe_clk             ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_asfifo        ),  //* active-high
      .wrclk                  (i_sys_clk            ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                  (r_wren_asfifo        ),  //* active-high
      .q                      (w_dout_asfifo        ),  //* The output of data
      .rdempty                (                     ),  //* Read domain empty
      .rdalempty              (                     ),  //* Read domain almost-empty
      .wrusedw                (w_usedw_asfifo[7:0]  ),  //* Write-usedword
      .rdusedw                (                     )   //* Read-usedword
    );
    assign w_usedw_asfifo[9:8] = 2'b0;

    ASYNCFIFO_64x168 asfifo_recv_meta(
      .rd_aclr                (!i_rst_n             ),  //* Reset the all read signal
      .wr_aclr                (!i_sys_rst_n         ),  //* Reset the all write signal
      // `ifdef VCS
      //   .data                 (i_meta               ),  //* The Inport of data 
      //   .wrreq                (i_meta_valid         ),  //* active-high
      // `else
        .data                 (r_din_meta           ),  //* The Inport of data 
        .wrreq                (r_wren_meta          ),  //* active-high
      // `endif
      .rdclk                  (i_pe_clk             ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_meta          ),  //* active-high
      .wrclk                  (i_sys_clk            ),  //* ASYNC WriteClk, SYNC use wrclk
      .q                      (w_dout_meta          ),  //* The output of data
      .rdempty                (w_empty_meta         )   //* Read domain empty
    );

    //* for conf_pkt;
    ASYNCFIFO_128x134 asfifo_recv_conf(
      .rd_aclr                (!i_rst_n             ),  //* Reset the all read signal
      .wr_aclr                (!i_sys_rst_n         ),  //* Reset the all write signal
      .data                   (r_din_conf           ),  //* The Inport of data 
      .rdclk                  (i_pe_clk             ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_conf          ),  //* active-high
      .wrclk                  (i_sys_clk            ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                  (r_wren_conf          ),  //* active-high
      .q                      (w_dout_conf          ),  //* The output of data
      .rdempty                (                     ),  //* Read domain empty
      .rdalempty              (                     ),  //* Read domain almost-empty
      .wrusedw                (                     ),  //* Write-usedword
      .rdusedw                (                     )   //* Read-usedword
    );

    ASYNCFIFO_32x2 asfifo_recv_conf_valid(
      .rd_aclr                (!i_rst_n             ),  //* Reset the all read signal
      .wr_aclr                (!i_sys_rst_n         ),  //* Reset the all write signal
      .data                   (2'b0                 ),  //* The Inport of data 
      .rdclk                  (i_pe_clk             ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_conf_valid    ),  //* active-high
      .wrclk                  (i_sys_clk            ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                  (r_wren_conf_valid    ),  //* active-high
      .q                      (                     ),  //* The output of data
      .rdempty                (w_empty_conf_valid   ),  //* Read domain empty
      .rdalempty              (                     ),  //* Read domain almost-empty
      .wrusedw                (                     ),  //* Write-usedword
      .rdusedw                (                     )   //* Read-usedword
    );
  `endif

  //* debug;
  assign  d_inc_pkt_4b[0] = (r_rden_meta == 1'b1);  //* dma & dra & discard (discard tag);
  assign  d_inc_pkt_4b[1] = (o_data_DMA_valid == 1'b1 &&
                              o_data_DMA[133:132] == 2'b10);     //* dma;
  assign  d_inc_pkt_4b[2] = (o_data_DRA_valid == 1'b1 &&
                              o_data_DRA[133:132] == 2'b10);  //* dra;
  assign  d_inc_pkt_4b[3] = (o_data_conf_valid == 1'b1 &&
                              o_data_conf[133:132] == 2'b10);  //* conf;

endmodule