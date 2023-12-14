 /*
  *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
  *  Module name:        PE_Config.
  *  Description:        This module is used to configure itcm and dtcm of CPU.
  *  Last updated date:  2022.10.11. 
  *
  *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
  *  Copyright (C) 2021-2022 NUDT.
  *
  *  Noted:
  *   1) localbus address defination: 
  *     1xxxx: configure/read conf_en;
  *     0xxxx: configure/read instr/data mem;
  *     8xxx0: low 32b system time to update;
  *     8xxx1: high 32b system time to update;
  *     8xxx2: request to update system time, '0' is minus, '1' is add;
 */

`timescale 1 ns / 1 ps

module PE_Config(
  //* clk & rst_n
   input                    i_clk
  ,input                    i_rst_n
  //* localbus interface;
  ,input  wire              i_cs            //* active low
  ,input  wire              i_wr_rd         //* 0:read 1:write
  ,input  wire [    19:0]   i_address
  ,input  wire [    31:0]   i_data_in
  ,output reg               o_ack_n
  ,output reg  [    31:0]   o_data_out
  //* network;
  ,input  wire              i_data_conf_valid
  ,input  wire [   133:0]   i_data_conf      
  ,output reg               o_data_conf_valid
  ,output reg  [   133:0]   o_data_conf      
  //* config interface;
  ,output reg               o_conf_rden     //* configure interface
  ,output reg               o_conf_wren
  ,output reg   [   31:0]   o_conf_addr
  ,output reg   [   31:0]   o_conf_wdata
  ,input        [   31:0]   i_conf_rdata
  ,output reg   [    3:0]   o_conf_en       //* '1' means configuring is valid;
  //* config by flash (spi);
  ,input  wire              i_conf_wren_spi
  ,input  wire  [   31:0]   i_conf_addr_spi
  ,input  wire  [   31:0]   i_conf_wdata_spi
  ,input  wire  [    3:0]   i_conf_en_spi   //* '1' means configuring is valid;
  ,input  wire              i_finish_inilization
  //* system_time;
  ,output reg               o_update_valid
  ,output reg   [   64:0]   o_update_system_time  //* '0' is minus;
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  /** state_conf is used to configure (read or write) itcm and dtcm
  *   stat_out is used to output "print" in the program running on CPU
  */
  reg [3:0] state_conf, state_out;
  parameter IDLE_S          = 4'd0,
            WAIT_1_S        = 4'd1,
            WAIT_2_S        = 4'd2,
            RD_PROG_S       = 4'd3,
            RESP_ACK_S      = 4'd4,
            WAIT_END_S      = 4'd5,
            WR_SEL_NET_S    = 4'd6,
            RD_SEL_NET_S    = 4'd7,
            WR_PROG_NET_S   = 4'd8,
            RD_PROG_NET_S   = 4'd9,
            DISCARD_NET_S   = 4'd10,
            PREPARE_S       = 4'd11,
            //* state_out;
            SEND_HEAD_NET   = 4'd1,
            SEND_HEAD_0     = 4'd2,
            SEND_HEAD_1     = 4'd3,
            SEND_HEAD_2     = 4'd4,
            SEND_HEAD_3     = 4'd5,
            SEND_HEAD_WR    = 4'd6;

  /** r_read_sel_tag is used to identify whether need to read "sel", i.e., 
   *    running mode of CPU;
   *  r_write_tag is used to respond a pkt for writing action;
  */
  reg                       r_read_sel_tag[1:0];
  reg                       r_write_tag[1:0];

  //* fifo used to buffer read data;
  wire                      w_empty_rdata;
  wire      [       63:0]   w_dout_rdata;
  reg       [       63:0]   r_fake_dout_rdata;
  reg                       r_rden_rdata;
  //* temp;
  reg       [       31:0]   r_addr_temp[1:0];
  reg       [        1:0]   r_rden_temp;
  reg       [       47:0]   r_local_mac, r_dst_mac;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   parser pkt and config MEM
  //====================================================================//
  /** state machine for configuring itcm and dtcm:
  *   1) distinguish action type according to ethernet_type filed;
  *   2) configure running mode, i.e., "conf_sel_dtcm", 0 is configure, 
  *     while 1 is running;
  *   3) read running mode, i.e., toggle "r_read_sel_tag[0]";
  *   4) write program, including itcm and dtcm;
  *   5) read program, including itcm and dtcm;
  */
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      //* config interface;
      o_conf_rden             <= 1'b0;
      o_conf_wren             <= 1'b0;
      o_conf_addr             <= 32'b0;
      o_conf_wdata            <= 32'b0;
      //* localbus;
      o_conf_en               <= 4'hf;
      o_ack_n                 <= 1'b1;
      o_data_out              <= 32'b0;
      //* system_time;
      o_update_valid          <= 1'b0;
      o_update_system_time    <= 65'b0;
      //* temp;
      r_read_sel_tag[0]       <= 1'b0;
      r_write_tag[0]          <= 1'b0;
      r_local_mac             <= 48'h1111_2222_4444;
      r_dst_mac               <= 48'h1111_2222_3333;
      state_conf              <= PREPARE_S;
    end
    else begin
      o_conf_wren             <= 1'b0;
      o_conf_rden             <= 1'b0;
      o_update_valid          <= 1'b0;

      case(state_conf)
        PREPARE_S: begin  //* initialize instr/data mem by flash;
          //* configure by flash;
          o_conf_wren               <= i_conf_wren_spi;
          o_conf_wdata              <= i_conf_wdata_spi;
          o_conf_addr               <= i_conf_addr_spi;
          o_conf_en                 <= i_conf_en_spi;

          if(i_finish_inilization == 1'b1) begin
            state_conf              <= IDLE_S;
          end
          else if(i_cs == 1'b0) begin //* configure by localbus;
            o_conf_wren             <= i_wr_rd & ~i_address[19];
            o_conf_rden             <= ~i_wr_rd & ~i_address[19];
            o_conf_addr             <= {16'b0, i_address[15:0]};
            if(i_address[19] == 1'b0) begin
              (*full_case, parallel_case*)
              case({i_wr_rd,i_address[16]})
                2'b01: begin
                        o_data_out  <= {28'b0, o_conf_en};
                        state_conf  <= RESP_ACK_S;
                end
                2'b00: begin
                        state_conf  <= WAIT_1_S;
                end
                2'b11: begin
                        o_conf_en   <= i_data_in[3:0];
                        state_conf  <= RESP_ACK_S;
                end
                2'b10: begin
                        o_conf_wdata<= i_data_in;
                        state_conf  <= RESP_ACK_S;
                end
              endcase
            end
            else begin  //* configure system_time;
              state_conf            <= RESP_ACK_S;
              case({i_wr_rd,i_address[1:0]})
                3'b100: o_update_system_time[31:0]  <= i_data_in;
                3'b101: o_update_system_time[63:32] <= i_data_in;
                3'b110: begin
                        o_update_system_time[64]    <= i_data_in[0];
                                  o_update_valid    <= 1'b1;
                end
                //* read;
                3'b000: o_data_out                  <= o_update_system_time[31:0];
                3'b001: o_data_out                  <= o_update_system_time[63:32];
                3'b010: o_data_out                  <= o_update_system_time[64];
                default:          o_update_valid    <= 1'b0;
              endcase
            end
          end
          //* configure by network directly;
          else if(i_data_conf_valid == 1'b1 && i_data_conf[133:132] == 2'b01) begin
            (*full_case, parallel_case*)
            case(i_data_conf[1:0])
              2'd1: state_conf    <= WR_SEL_NET_S;
              2'd2: state_conf    <= RD_SEL_NET_S;
              2'd3: state_conf    <= WR_PROG_NET_S;
              2'd0: state_conf    <= RD_PROG_NET_S;
              // 2'd0: state_conf  <= IDLE_S;
            endcase
            r_dst_mac             <= i_data_conf[32+:48];
            r_local_mac           <= i_data_conf[80+:48];
          end
          else begin
            state_conf            <= PREPARE_S;
          end
        end
        IDLE_S: begin
          //* configure by localbus;
          if(i_cs == 1'b0) begin
            o_conf_wren           <= i_wr_rd & ~i_address[19];
            o_conf_rden           <= ~i_wr_rd & ~i_address[19];
            o_conf_addr           <= {16'b0, i_address[15:0]};
            if(i_address[19] == 1'b0) begin
              (*full_case, parallel_case*)
              case({i_wr_rd,i_address[16]})
                2'b01: begin
                        o_data_out  <= {28'b0, o_conf_en};
                        state_conf  <= RESP_ACK_S;
                end
                2'b00: begin
                        state_conf  <= WAIT_1_S;
                end
                2'b11: begin
                        o_conf_en   <= i_data_in[3:0];
                        state_conf  <= RESP_ACK_S;
                end
                2'b10: begin
                        o_conf_wdata<= i_data_in;
                        state_conf  <= RESP_ACK_S;
                end
              endcase
            end
            else begin  //* configure system_time;
              state_conf            <= RESP_ACK_S;
              case({i_wr_rd,i_address[1:0]})
                3'b100: o_update_system_time[31:0]  <= i_data_in;
                3'b101: o_update_system_time[63:32] <= i_data_in;
                3'b110: begin
                        o_update_system_time[64]    <= i_data_in[0];
                                  o_update_valid    <= 1'b1;
                end
                //* read;
                3'b000: o_data_out                  <= o_update_system_time[31:0];
                3'b001: o_data_out                  <= o_update_system_time[63:32];
                3'b010: o_data_out                  <= o_update_system_time[64];
                default:          o_update_valid    <= 1'b0;
              endcase
            end
          end
          //* configure by network directly;
          else if(i_data_conf_valid == 1'b1 && i_data_conf[133:132] == 2'b01) begin
            (*full_case, parallel_case*)
            case(i_data_conf[1:0])
              2'd1: state_conf    <= WR_SEL_NET_S;
              2'd2: state_conf    <= RD_SEL_NET_S;
              2'd3: state_conf    <= WR_PROG_NET_S;
              2'd0: state_conf    <= RD_PROG_NET_S;
              // 2'd0: state_conf  <= IDLE_S;
            endcase
            r_dst_mac             <= i_data_conf[32+:48];
            r_local_mac           <= i_data_conf[80+:48];
          end
          else begin
            state_conf            <= IDLE_S;
          end
        end
        ////////////////////////////////////////////
        //* localbus;
        ////////////////////////////////////////////
          WAIT_1_S: begin
            state_conf              <= WAIT_2_S;
          end
          WAIT_2_S: begin
            state_conf              <= RD_PROG_S;
          end
          RD_PROG_S: begin
            o_data_out              <= i_conf_rdata;
            state_conf              <= RESP_ACK_S;
          end
          RESP_ACK_S: begin
            o_update_valid          <= 1'b0;
            o_ack_n                 <= 1'b0;
            state_conf              <= WAIT_END_S;
          end
          WAIT_END_S: begin
            if(i_cs == 1'b1) begin
              o_ack_n               <= 1'b1;
              state_conf            <= IDLE_S;
            end
            else begin
              o_ack_n               <= o_ack_n;
              state_conf            <= WAIT_END_S;
            end
          end
        ////////////////////////////////////////////
        //* network;
        ////////////////////////////////////////////
          WR_SEL_NET_S: begin
            o_conf_en             <= i_data_conf[19:16];
            state_conf            <= DISCARD_NET_S;
          end
          RD_SEL_NET_S: begin
            state_conf            <= DISCARD_NET_S;
            r_read_sel_tag[0]     <= ~r_read_sel_tag[0];
          end
          WR_PROG_NET_S: begin
            o_conf_wren           <= 1'b1;
            o_conf_addr           <= i_data_conf[47:16];
            o_conf_wdata          <= i_data_conf[79:48];

            state_conf            <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? IDLE_S: WR_PROG_NET_S;
            r_write_tag[0]        <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? ~r_write_tag[0]: r_write_tag[0];
          end
          RD_PROG_NET_S: begin
            // TODO:
            state_conf        <= DISCARD_NET_S;
            o_conf_rden       <= 1'b1;
            o_conf_addr       <= i_data_conf[47:16];
          end
          DISCARD_NET_S: begin
            state_conf            <= (i_data_conf[133:132] == 2'b10 || 
                                      i_data_conf_valid == 1'b0)? IDLE_S: DISCARD_NET_S;
          end
        default: begin
          state_conf              <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  //====================================================================//
  //*     return config_en or radata
  //====================================================================//
  /** state machine used to output reading result or print value:
  *   1) configure metadata_0&1 (according to fast packet format);
  *   2) output reading result or print value which is distinguished
  *     by ethernet_type filed;
  */
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      // reset
      o_data_conf_valid           <= 1'b0;
      o_data_conf                 <= 134'b0;
      r_read_sel_tag[1]           <= 1'b0;
      r_write_tag[1]              <= 1'b0;
      //* temp;
      r_rden_temp                 <= 2'b0;
      r_addr_temp[0]              <= 32'b0;
      r_addr_temp[1]              <= 32'b0;
      //* fifo;
      r_rden_rdata                <= 1'b0;
      //* state;
      state_out                   <= IDLE_S;
    end
    else begin
      case(state_out)
        IDLE_S: begin
          o_data_conf_valid       <= 1'b0;
          if(r_read_sel_tag[1] != r_read_sel_tag[0]) begin
            state_out             <= SEND_HEAD_0;
          end
          else if(r_write_tag[1] != r_write_tag[0]) begin
            state_out             <= SEND_HEAD_WR;
          end
          else if(w_empty_rdata == 1'b0) begin
            o_data_conf[133:32]   <= {2'b01,4'hf,r_dst_mac, r_local_mac}; 
            o_data_conf[31:0]     <= {16'h9005,16'h14};
            o_data_conf_valid     <= 1'b1;
            r_rden_rdata          <= 1'b1;
            state_out             <= SEND_HEAD_NET;
          end
          else begin
            state_out             <= IDLE_S;
          end
        end
        SEND_HEAD_0: begin
          state_out               <= SEND_HEAD_1;
          o_data_conf_valid       <= 1'b1;
          o_data_conf[31:0]       <= {16'h9005,16'h12};
          o_data_conf[133:32]     <= {2'b01,4'hf,r_dst_mac, r_local_mac};  
          r_read_sel_tag[1]       <= r_read_sel_tag[0];    
        end
        SEND_HEAD_WR: begin
          state_out               <= SEND_HEAD_1;
          o_data_conf_valid       <= 1'b1;
          o_data_conf[31:0]       <= {16'h9005,16'd12};
          o_data_conf[133:32]     <= {2'b01,4'hf,r_dst_mac, r_local_mac};
          r_write_tag[1]          <= r_write_tag[0];
        end
        SEND_HEAD_1: begin
          o_data_conf[111:16]     <= {88'b0,o_conf_en};
          o_data_conf[133:112]    <= {2'b0,4'hf,16'b0};
          o_data_conf[15:0]       <= 16'b0;
          state_out               <= SEND_HEAD_2;
        end
        SEND_HEAD_NET: begin
          r_rden_rdata            <= 1'b0;
          o_data_conf[133:112]    <= {2'b0,4'hf,16'b0};
          o_data_conf[111:16]     <= {32'b0,w_dout_rdata};
          o_data_conf[15:0]       <= 16'b0;
          state_out               <= SEND_HEAD_2;
        end
        SEND_HEAD_2: begin
          o_data_conf             <= {2'b0,4'hf,128'd1};
          state_out               <= SEND_HEAD_3;
        end
        SEND_HEAD_3: begin
          o_data_conf             <= {2'b10,4'hf,128'd2};
          state_out               <= IDLE_S;
        end
        default: begin
          state_out               <= IDLE_S;
        end
      endcase

      //* temp;
      r_rden_temp                     <= {r_rden_temp[0],o_conf_rden};
      {r_addr_temp[1],r_addr_temp[0]} <= {r_addr_temp[0],o_conf_addr};
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  // `ifdef XILINX_FIFO_RAM
  //   /** fifo used to buffer reading result*/
  //   fifo_64b_512 rdata_buffer(
  //     .clk    (i_clk                      ),
  //     .srst   (!i_rst_n                   ),
  //     .din    ({i_conf_rdata, r_addr_temp[1]} ),
  //     .wr_en  (r_rden_temp[1]             ),
  //     .rd_en  (r_rden_rdata               ),
  //     .dout   (w_dout_rdata               ),
  //     .full   (                           ),
  //     .empty  (w_empty_rdata              )
  //   );
  // `else 
  //   SYNCFIFO_64x64 rdata_buffer (
  //     .aclr      (!i_rst_n                ),  //* Reset the all signal
  //     .data      ({i_conf_rdata, r_addr_temp[1]}),  //* The Inport of data 
  //     .rdreq     (r_rden_rdata            ),  //* active-high
  //     .clk       (i_clk                   ),  //* ASYNC WriteClk, SYNC use wrclk
  //     .wrreq     (r_rden_temp[1]          ),  //* active-high
  //     .q         (w_dout_rdata            ),  //* The output of data
  //     .rdempty   (w_empty_rdata           ),  //* Read domain empty
  //     .rdalempty (                        ),  //* Read domain almost-empty
  //     .wrusedw   (                        ),  //* Write-usedword
  //     .rdusedw   (                        )   //* Read-usedword
  //   );
  // `endif
    
  //* fake fifo;
  reg [1:0] cnt_rdata;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      // reset
      r_fake_dout_rdata           <= 64'b0;
      cnt_rdata                   <= 2'b0;
    end
    else begin
      r_fake_dout_rdata           <= (r_rden_temp[1] == 1'b1)? {i_conf_rdata, r_addr_temp[1]}:
                                      r_fake_dout_rdata;
      case({r_rden_temp[1],r_rden_rdata})
        2'b00: cnt_rdata          <= cnt_rdata;
        2'b01: cnt_rdata          <= cnt_rdata - 2'd1;
        2'b10: cnt_rdata          <= cnt_rdata + 2'd1;
        2'b11: cnt_rdata          <= cnt_rdata;
        default: begin end
      endcase
    end
  end
  assign w_dout_rdata   = r_fake_dout_rdata;
  assign w_empty_rdata  = (cnt_rdata == 2'b0);

endmodule
