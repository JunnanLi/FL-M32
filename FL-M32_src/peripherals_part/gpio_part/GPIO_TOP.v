/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        GPIO_TOP.
 *  Description:        top module of GPIO.
 *  Last updated date:  2022.08.21.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module GPIO_TOP (
  input   wire                        i_clk,
  input   wire                        i_rst_n,
  //* gpio interface;
  input   wire  [           15:0]     i_gpio,
  output  wire  [           15:0]     o_gpio,
  output  wire  [           15:0]     o_gpio_en,       //* '1' is output;
  //* peri interface;
  input   wire  [ `NUM_PE*32-1:0]     i_addr_32b,
  input   wire  [    `NUM_PE-1:0]     i_wren,
  input   wire  [    `NUM_PE-1:0]     i_rden,
  input   wire  [ `NUM_PE*32-1:0]     i_din_32b,
  output  reg   [ `NUM_PE*32-1:0]     o_dout_32b,
  output  reg   [    `NUM_PE-1:0]     o_dout_32b_valid,
  output  wire  [    `NUM_PE-1:0]     o_interrupt,
  //* debug;
  output  wire                        d_en_1b,
  output  wire  [           15:0]     d_data_ctrl_16b,
  output  wire  [           15:0]     d_bm_int_16b,
  output  wire  [           15:0]     d_bm_clear_16b,
  output  wire  [           15:0]     d_pos_neg_16b,
  output  wire  [           15:0]     d_dir_16b,
  output  wire  [           15:0]     d_recvData_16b,
  output  wire  [           15:0]     d_sendData_16b,
  output  reg   [            3:0]     d_cnt_pe0_wr_4b,
  output  reg   [            3:0]     d_cnt_pe1_wr_4b,
  output  reg   [            3:0]     d_cnt_pe2_wr_4b,
  output  reg   [            3:0]     d_cnt_pe0_rd_4b,
  output  reg   [            3:0]     d_cnt_pe1_rd_4b,
  output  reg   [            3:0]     d_cnt_pe2_rd_4b,
  output  reg   [            3:0]     d_cnt_int_4b
);

  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* r_data_ctrl:  control bit, i.e., 0 is recv/send data, 1 is ctrl (irq);
  //* r_bm_int:     interrupt of gpio in bitmap;
  //* r_pos_neg:    posedge/negedge interrupt bit, i.e., 0 is pos, 1 is neg;
  //* r_bm_clear:   clear interrupt of gpio in bitmap;
  //* r_dir:        direction bit, i.e., 0 is to recv data, 1 is to send data;
  reg           [       15:0] r_dir, r_pos_neg, r_data_ctrl;
  reg           [       15:0] pre_recvData, r_sendData, r_bm_int, r_bm_clear;
  reg                         r_en;
  reg           [`NUM_PE-1:0] r_bit_pe; //* which PE is used to proc GPIO;
  wire          [       15:0] w_recvData;
  //* interrupt;
  assign        o_interrupt   = {`NUM_PE{|r_bm_int}} & r_bit_pe;
  //* gpio_data;
  assign        o_gpio        = r_sendData;
  assign        w_recvData    = i_gpio;
  assign        o_gpio_en     = r_dir;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //   GPIO
  //==============================================================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_bm_int                <= 16'b0;
      pre_recvData            <= 16'b0;
    end 
    else begin
      pre_recvData            <= w_recvData;
      if(r_en == 1'b1) begin
        for(i=0; i<16; i=i+1) begin
          //* int;
          if(r_data_ctrl[i] == 1'b1) begin
            r_bm_int[i]       <= ((r_pos_neg[i] == 1'b0 && pre_recvData[i] == 1'b0 && 
                                    w_recvData[i] == 1'b1) ||             //* posedge;
                                  (r_pos_neg[i] == 1'b1 && pre_recvData[i] == 1'b1 && 
                                    w_recvData[i] == 1'b0)) ?             //* negedge;
                                    1'b1: r_bm_int[i] & (~r_bm_clear[i]);   //* clear;
          end
          else begin
            r_bm_int[i]       <= 1'b0;
          end
        end
      end
      else begin
        r_bm_int              <= 16'b0;
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //   Peri
  //==============================================================//
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* peri interface;
      o_dout_32b_valid                  <= {`NUM_PE{1'b0}};
      o_dout_32b                        <= {`NUM_PE{32'b0}};
      //* gpio-related registers;
      r_sendData                        <= 16'b0;
      r_en                              <= 1'b0;
      r_data_ctrl                       <= 16'b0;
      r_bm_clear                        <= 16'b0;
      r_pos_neg                         <= 16'b0;
      r_dir                             <= 16'h0;
      r_bit_pe                          <= {`NUM_PE{1'b0}};
      //* debug;
      d_cnt_pe0_wr_4b                   <= 4'b0;
      d_cnt_pe1_wr_4b                   <= 4'b0;
      d_cnt_pe2_wr_4b                   <= 4'b0;
      d_cnt_pe0_rd_4b                   <= 4'b0;
      d_cnt_pe1_rd_4b                   <= 4'b0;
      d_cnt_pe2_rd_4b                   <= 4'b0;
    end 
    else begin
      o_dout_32b_valid                  <= i_wren | i_rden;
      r_bm_clear                        <= 16'b0 ;

      //* for NUM_PE = 3;
      //* for writing;
      casex(i_wren)
        3'bxx1: begin
          case(i_addr_32b[(0*32+2)+:3])
            3'd0: r_en                  <= i_din_32b[0];
            3'd1: r_data_ctrl           <= i_din_32b[0+:16];
            3'd2: r_pos_neg             <= i_din_32b[0+:16];
            // 3'd3: r_bm_int              <= i_din_32b[0+:16];
            3'd4: r_bm_clear            <= i_din_32b[0+:16];
            3'd5: r_dir                 <= i_din_32b[0+:16];
            3'd7: r_sendData            <= i_din_32b[0+:16];
            default: begin
            end
          endcase
          r_bit_pe                      <= 3'b001;
          d_cnt_pe0_wr_4b               <= d_cnt_pe0_wr_4b + 4'd1;
        end
        3'bx10: begin
          case(i_addr_32b[(1*32+2)+:3])
            3'd0: r_en                  <= i_din_32b[1*32];
            3'd1: r_data_ctrl           <= i_din_32b[1*32+:16];
            3'd2: r_pos_neg             <= i_din_32b[1*32+:16];
            // 3'd3: r_bm_int              <= i_din_32b[1*32+:16];
            3'd4: r_bm_clear            <= i_din_32b[1*32+:16];
            3'd5: r_dir                 <= i_din_32b[1*32+:16];
            3'd7: r_sendData            <= i_din_32b[1*32+:16];
            default: begin
            end
          endcase
          r_bit_pe                      <= 3'b010;
          d_cnt_pe1_wr_4b               <= d_cnt_pe1_wr_4b + 4'd1;
        end
        3'b100: begin
          case(i_addr_32b[(2*32+2)+:3])
            3'd0: r_en                  <= i_din_32b[2*32];
            3'd1: r_data_ctrl           <= i_din_32b[2*32+:16];
            3'd2: r_pos_neg             <= i_din_32b[2*32+:16];
            // 3'd3: r_bm_int              <= i_din_32b[2*32+:16];
            3'd4: r_bm_clear            <= i_din_32b[2*32+:16];
            3'd5: r_dir                 <= i_din_32b[2*32+:16];
            3'd7: r_sendData            <= i_din_32b[2*32+:16];
            default: begin
            end
          endcase
          r_bit_pe                      <= 3'b100;
          d_cnt_pe2_wr_4b               <= d_cnt_pe2_wr_4b + 4'd1;
        end
        default: begin
          r_en                          <= r_en       ;
          r_data_ctrl                   <= r_data_ctrl;
          r_dir                         <= r_dir      ;
          r_sendData                    <= r_sendData ;
        end
      endcase

      //* for reading;
      for(i_pe =0; i_pe <`NUM_PE; i_pe = i_pe+1) begin
        case(i_addr_32b[(i_pe*32+2)+:3])
          3'd0: o_dout_32b[i_pe*32+:32] <= {31'b0,r_en};
          3'd1: o_dout_32b[i_pe*32+:32] <= {16'b0,r_data_ctrl};
          3'd2: o_dout_32b[i_pe*32+:32] <= {16'b0,r_pos_neg};
          3'd3: o_dout_32b[i_pe*32+:32] <= {16'b0,r_bm_int};
          3'd4: o_dout_32b[i_pe*32+:32] <= {16'b0,r_bm_clear};
          3'd5: o_dout_32b[i_pe*32+:32] <= {16'b0,r_dir};
          3'd6: o_dout_32b[i_pe*32+:32] <= {16'b0,(~r_data_ctrl)&(~r_dir)&w_recvData};
          3'd7: o_dout_32b[i_pe*32+:32] <= {16'b0,r_sendData};
          default: begin
                o_dout_32b[i_pe*32+:32] <= 32'b0;
          end
        endcase
      end
      d_cnt_pe0_rd_4b                   <= (i_rden[0] == 1'b1)? d_cnt_pe0_rd_4b + 4'd1: d_cnt_pe0_rd_4b;
      d_cnt_pe1_rd_4b                   <= (i_rden[1] == 1'b1)? d_cnt_pe1_rd_4b + 4'd1: d_cnt_pe1_rd_4b;
      d_cnt_pe2_rd_4b                   <= (i_rden[2] == 1'b1)? d_cnt_pe2_rd_4b + 4'd1: d_cnt_pe2_rd_4b;
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //   debug
  //==============================================================//
  assign  d_dir_16b                     = r_dir;
  assign  d_data_ctrl_16b               = r_data_ctrl;
  assign  d_bm_int_16b                  = r_bm_int;
  assign  d_bm_clear_16b                = r_bm_clear;
  assign  d_pos_neg_16b                 = r_pos_neg;
  assign  d_en_1b                       = r_en;
  assign  d_recvData_16b                = w_recvData;
  assign  d_sendData_16b                = r_sendData;

  reg     pre_interrupt;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      d_cnt_int_4b                      <= 4'b0;
      pre_interrupt                     <= 1'b0;
    end 
    else begin
      pre_interrupt                     <= |o_interrupt;
      d_cnt_int_4b                      <= (|o_interrupt == 1'b1 && pre_interrupt == 1'b0)? (d_cnt_int_4b + 4'd1): d_cnt_int_4b;
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
