/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Periperal_Bus.
 *  Description:        This module is used to connect timelyRV_top with 
 *                       configuration, pkt sram, can, and uart.
 *  Last updated date:  2022.06.17.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module Periperal_Bus(
  //* clk & rst_n
  input  wire                     i_clk,
  input  wire                     i_rst_n,
  //* peri interface with PEs;
  input  wire                     i_peri_rden,
  input  wire                     i_peri_wren,
  input  wire [            31:0]  i_peri_addr,
  input  wire [            31:0]  i_peri_wdata,
  input  wire [             3:0]  i_peri_wstrb,
  output reg                      o_peri_ready,
  output reg  [            31:0]  o_peri_rdata,
  output wire                     o_peri_gnt,

  //* peri interface wit Peris;
  output reg  [            31:0]  o_addr_2peri,
  output reg  [   `NUM_PERI-1:0]  o_wren_2peri,
  output reg  [   `NUM_PERI-1:0]  o_rden_2peri,
  output reg  [            31:0]  o_wdata_2peri,
  output reg  [             3:0]  o_wstrb_2peri,
  input       [   `NUM_PERI-1:0]  i_ready_2PBUS,
  input       [`NUM_PERI*32-1:0]  i_rdata_2PBUS
);


  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire        [             7:0]  w_ready_2PBUS;
  wire        [        32*8-1:0]  w_rdata_2PBUS;
  assign      w_ready_2PBUS       ={{(8-`NUM_PERI){1'b0}},i_ready_2PBUS};
  assign      w_rdata_2PBUS       ={{(8-`NUM_PERI){32'b0}},i_rdata_2PBUS};
  //* TODO, currently do not care;
  assign      o_peri_gnt          = 1'b1;
  //==============================================================//

  //======================= Periral Bus   ========================//
  //* TODO, current bus is simple, just one stage;
  integer i_peri;
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      //* Connected with PE;
      o_peri_ready                <= 1'b0;
      o_peri_rdata                <= 32'b0;

      //* Connected with Periperals;
      o_addr_2peri                <= 32'b0;
      o_wren_2peri                <= {`NUM_PERI{1'b0}};
      o_rden_2peri                <= {`NUM_PERI{1'b0}};
      o_wdata_2peri               <= 32'b0;
      o_wstrb_2peri               <= 4'b0;
    end
    else begin
      //* initilization
      o_wren_2peri                <= {`NUM_PERI{1'b0}};
      o_rden_2peri                <= {`NUM_PERI{1'b0}};
      o_addr_2peri                <= i_peri_addr;
      o_wdata_2peri               <= i_peri_wdata;
      o_wstrb_2peri               <= i_peri_wstrb;

      //* output rdata to PEs;
      o_peri_ready                <= |i_ready_2PBUS;
      
      //* NUM_PERI is 8
      case(w_ready_2PBUS[7:0])
        8'b0000_0001: o_peri_rdata  <= w_rdata_2PBUS[31:0];
        8'b0000_0010: o_peri_rdata  <= w_rdata_2PBUS[1*32+:32];
        8'b0000_0100: o_peri_rdata  <= w_rdata_2PBUS[2*32+:32];
        8'b0000_1000: o_peri_rdata  <= w_rdata_2PBUS[3*32+:32];
        8'b0001_0000: o_peri_rdata  <= w_rdata_2PBUS[4*32+:32];
        8'b0010_0000: o_peri_rdata  <= w_rdata_2PBUS[5*32+:32];
        8'b0100_0000: o_peri_rdata  <= w_rdata_2PBUS[6*32+:32];
        8'b1000_0000: o_peri_rdata  <= w_rdata_2PBUS[7*32+:32];
        default:      o_peri_rdata  <= 32'b0;
      endcase

      //* output addr/wdata to Peris;  
      case(i_peri_addr[19:16])
       `ifdef UART_EN
          4'd1: begin //* UART;
            o_wren_2peri[`UART]   <= i_peri_wren;
            o_rden_2peri[`UART]   <= i_peri_rden;
          end
        `endif
        `ifdef GPIO_EN
          4'd2: begin //* GPIO;
            o_wren_2peri[`GPIO]   <= i_peri_wren;
            o_rden_2peri[`GPIO]   <= i_peri_rden;
          end
        `endif
        `ifdef SPI_EN
          4'd3: begin //* SPI;
            o_wren_2peri[`SPI]    <= i_peri_wren;
            o_rden_2peri[`SPI]    <= i_peri_rden;
          end
        `endif
        `ifdef CSR_EN
          4'd4: begin //* CSR;
            o_wren_2peri[`CSR]    <= i_peri_wren;
            o_rden_2peri[`CSR]    <= i_peri_rden;
          end
        `endif
        `ifdef CSRAM_EN
          4'd5: begin //* CSRAM;
            o_wren_2peri[`CSRAM]  <= i_peri_wren;
            o_rden_2peri[`CSRAM]  <= i_peri_rden;
          end
        `endif
        `ifdef dDMA_EN
          4'd6: begin //* dDMA;
            o_wren_2peri[`dDMA]   <= i_peri_wren;
            o_rden_2peri[`dDMA]   <= i_peri_rden;
          end
        `endif
        `ifdef DMA_EN
          4'd7: begin //* DMA;
            o_wren_2peri[`DMA]    <= i_peri_wren;
            o_rden_2peri[`DMA]    <= i_peri_rden;
          end
        `endif
        `ifdef DRA_EN
          4'd8: begin //* DRA;
            o_wren_2peri[`DRA]    <= i_peri_wren;
            o_rden_2peri[`DRA]    <= i_peri_rden;
          end
        `endif
        `ifdef CAN_EN
          4'd9: begin //* DRA;
            o_wren_2peri[`CAN]    <= i_peri_wren;
            o_rden_2peri[`CAN]    <= i_peri_rden;
          end
        `endif
          default: begin
            o_wren_2peri[`UART]   <= i_peri_wren;
            o_rden_2peri[`UART]   <= i_peri_rden;
          end
      endcase
    end
  end


endmodule    
