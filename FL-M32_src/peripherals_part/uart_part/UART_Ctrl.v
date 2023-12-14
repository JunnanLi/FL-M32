/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        UART_Ctrl.
 *  Description:        controller of uart.
 *  Last updated date:  2021.11.20.
 *
 *  Copyright (C) 2021-2023 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 */

module UART_Ctrl(
  //* clk & reset;
   input  wire              i_clk
  ,input  wire              i_rst_n
  ,input  wire              i_sys_clk
  ,input  wire              i_sys_rst_n
  //* peri interface;
  ,input  wire  [ `NUM_PE*32-1:0]     i_addr_32b
  ,input  wire  [    `NUM_PE-1:0]     i_wren
  ,input  wire  [    `NUM_PE-1:0]     i_rden
  ,input  wire  [ `NUM_PE*32-1:0]     i_din_32b
  ,output reg   [    `NUM_PE-1:0]     o_dout_32b_valid
  ,output reg   [ `NUM_PE*32-1:0]     o_dout_32b
  ,output wire              o_interrupt
  //* uart interface;
  ,input  wire  [  7:0]     i_din_8b
  ,input  wire              i_din_valid
  ,output wire  [  7:0]     o_dout_8b
  ,output wire              o_dout_valid
  ,input  wire              i_tx_busy
);


  //==============================================================//
  //  internal reg/wire/param declarations
  //==============================================================//
  //* fifo;
  reg                       r_rden_rx, r_rden_tx, r_wren_tx;
  reg           [7:0]       r_din_tx;
  wire          [7:0]       w_dout_rx, w_dout_tx;
  wire                      w_empty_rx, w_empty_tx;

  //* registers (8b);
  /*------------------------------------------------------------------------------------
   *    name    | offset  |  description
   *------------------------------------------------------------------------------------
   *   UART_RBR |   0x0   | Receive Buffer Register, read-only,
   *            |         |   read 8b data from rx_fifo
   *------------------------------------------------------------------------------------
   *   UART_THR |   0x4   | Transmitter Holding Register, write-only, 
   *                      |   write 8b data to tx_fifo
   *------------------------------------------------------------------------------------
   *   UART_DLL |   0x8   | Divisor Latch LSB, read/write, configure baud rate (low 8b)
   *------------------------------------------------------------------------------------
   *   UART_DLM |   0xc   | Divisor Latch MSB, read/write, configure baud rate (high 8b)
   *------------------------------------------------------------------------------------
   *   UART_IER |   0x10  | Interrupt Enable Register, read/write
   *            |         |   2: 1 means open check-error interrupt
   *            |         |   1: 1 means open TX-FIFO-empty interrupt
   *            |         |   0: 1 means open RX-FIFO-Threshold interrupt
   *------------------------------------------------------------------------------------
   *   UART_IIR |   0x14  | Interrupt Idenfitication Register, read
   *            |         |   [3:0]: 4 is TX-FIFO-empty interrupt, 8 is RX-FIFO-Threshold interrupt
   *            |         |         12 is check-error interrupt
   *------------------------------------------------------------------------------------
   *   UART_FCR |   0x18  | FIFO Control Register, write-only
   *            |         |   [7:6]: trigger threshold, 0 is 1B, 1 is 2B, 2 is 4B, 3 is 8B
   *            |         |   2: '1' means reset TX-FIFO
   *            |         |   1: '1' means reset RX-FIFO
   *------------------------------------------------------------------------------------
   *   UART_LCR |   0x1c  | Line Control Register, read/write
   *            |         |   7: read/write, '1' for configuring UART_DLL/UART_DLM
   *            |         |   [5:4]: read/write, check mode, 0 is odd, 1 is even, 2 is space, 3 is mark
   *            |         |   3: read/write, '1' for opening check mode
   *            |         |   2: read/write, number of stop bit, 0 is 1-bit, 1 is 2-bit 
   *            |         |   [1:0]: read/write, lenth of each transmittion, 0 is 5bit, 1 is 6bit, 2 is 7bit, 3 is 8bit
   *------------------------------------------------------------------------------------
   *   UART_LSR |   0x20  | Line State Register, read-only
   *            |         |   5: read-only, '1' means TX-FIFO is empty
   *            |         |   2: read-only, '1' means meeting check error
   *            |         |   0: read-only, '1' means RX-FIFO is not empty
   *------------------------------------------------------------------------------------
   */
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  UART_Peri
  //==============================================================//
  assign o_dout_8b          = w_dout_tx;
  assign o_dout_valid       = r_rden_tx;
  //* TODO...
  assign o_interrupt        = ~w_empty_rx;

  reg   [3:0]   state_reg;
  localparam    IDLE_S      = 4'd0;

  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      r_rden_rx             <= 1'b0;
      r_wren_tx             <= 1'b0;
      r_din_tx              <= 8'b0;
      o_dout_32b_valid      <= {`NUM_PE{1'b0}};
      o_dout_32b            <= {`NUM_PE{32'b0}};
      state_reg             <= IDLE_S;
    end
    else begin
      //* read/write registers;
      o_dout_32b_valid      <= {`NUM_PE{1'b0}};
      r_wren_tx             <= 1'b0;
      r_rden_rx             <= 1'b0;
      case(state_reg)
        IDLE_S: begin
          state_reg         <= IDLE_S;
          //* TODO...
          if(i_addr_32b[5:2] == 4'h0 && i_rden[0] == 1'b1) begin
            o_dout_32b[31:0]<= (w_empty_rx == 1'b0)? {24'b0,w_dout_rx}: {1'b1,31'b0};
            r_rden_rx       <= (w_empty_rx == 1'b0)? 1'b1: 1'b0;
          end

          if(i_addr_32b[5:2] == 4'h1 && i_wren[0] == 1'b1) begin
            r_wren_tx       <= 1'b1;
            r_din_tx        <= i_din_32b[7:0];
            `ifdef OPEN_DISPLAY
              $write("%c", i_din_32b[7:0]);
              $fflush();
            `endif
          end
          `ifdef PE1_EN
            else if(i_addr_32b[32*1+2+:4] == 4'h1 && i_wren[1] == 1'b1) begin
              r_wren_tx       <= 1'b1;
              r_din_tx        <= i_din_32b[32*1+:8];
              `ifdef OPEN_DISPLAY
                $write("%c", i_din_32b[32*1+:8]);
                $fflush();
              `endif
            end
          `endif
          `ifdef PE2_EN
            else if(i_addr_32b[32*2+2+:4] == 4'h1 && i_wren[2] == 1'b1) begin
              r_wren_tx       <= 1'b1;
              r_din_tx        <= i_din_32b[32*2+:8];
              `ifdef OPEN_DISPLAY
                $write("%c", i_din_32b[32*2+:8]);
                $fflush();
              `endif
            end
          `endif
          `ifdef PE3_EN
            else if(i_addr_32b[32*3+2+:4] == 4'h1 && i_wren[3] == 1'b1) begin
              r_wren_tx       <= 1'b1;
              r_din_tx        <= i_din_32b[32*3+:8];
              `ifdef OPEN_DISPLAY
                $write("%c", i_din_32b[32*3+:8]);
                $fflush();
              `endif
            end
          `endif

          for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1)
            o_dout_32b_valid[i_pe]  <= i_rden[i_pe]|i_wren[i_pe];
          // if((i_addr_32b[5:2] == 4'h0 || i_addr_32b[5:2] == 4'h1) && (i_rden == 1'b1 || i_wren == 1'b1)) begin
          //   o_dout_32b_valid<= 1'b1; //* finish reading and writing;
          // end
        end
        default: begin
          state_reg         <= IDLE_S;
        end
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  //==============================================================//
  //  UART_Controller
  //==============================================================//
  always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
    if(!i_sys_rst_n) begin
      r_rden_tx             <= 1'b0;
    end
    else begin
      //* read tx_fifo, and write tx;
      if(w_empty_tx == 1'b0 && r_rden_tx == 1'b0 && i_tx_busy == 1'b0) begin
        r_rden_tx           <= 1'b1;
      end
      else begin
        r_rden_tx           <= 1'b0;
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  `ifdef XILINX_FIFO_RAM
    asfifo_8b_512 data_rx(
      .rst                    (!i_rst_n           ),
      .wr_clk                 (i_sys_clk          ),
      .rd_clk                 (i_clk              ),
      .din                    (i_din_8b           ),
      .wr_en                  (i_din_valid        ),
      .rd_en                  (r_rden_rx          ),
      .dout                   (w_dout_rx          ),
      .full                   (                   ),
      .empty                  (w_empty_rx         )
    );

    asfifo_8b_4096 data_tx(
      .rst                    (!i_rst_n           ),
      .wr_clk                 (i_clk              ),
      .rd_clk                 (i_sys_clk          ),
      .din                    (r_din_tx           ),
      .wr_en                  (r_wren_tx          ),
      .rd_en                  (r_rden_tx          ),
      .dout                   (w_dout_tx          ),
      .full                   (                   ),
      .empty                  (w_empty_tx         )
    );
  `elsif SIM_FIFO_RAM
    //* fifo used to buffer rx data;
    asyncfifo data_rx (
      .rdclk                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrclk                (i_sys_clk                ),  //* ASYNC WriteClk, SYNC use wrclk
      .rd_aclr              (!i_rst_n                 ),  //* Reset the all signal
      .wr_aclr              (!i_rst_n                 ),  //* Reset the all signal
      .data                 (i_din_8b                 ),  //* The Inport of data 
      .wrreq                (i_din_valid              ),  //* active-high
      .rdreq                (r_rden_rx                ),  //* active-high
      .q                    (w_dout_rx                ),  //* The output of data
      .empty                (w_empty_rx               ),  //* Read domain empty
      .wrusedw              (                         ),  //* Usedword
      .rdusedw              (                         )   //* Usedword
    );
    defparam  data_rx.width = 8,
              data_rx.depth = 9,
              data_rx.words = 512;

    //* fifo used to buffer tx data;
    asyncfifo data_tx (
      .rdclk                (i_sys_clk                ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrclk                (i_clk                    ),  //* ASYNC WriteClk, SYNC use wrclk
      .rd_aclr              (!i_rst_n                 ),  //* Reset the all signal
      .wr_aclr              (!i_rst_n                 ),  //* Reset the all signal
      .data                 (r_din_tx                 ),  //* The Inport of data 
      .wrreq                (r_wren_tx                ),  //* active-high
      .rdreq                (r_rden_tx                ),  //* active-high
      .q                    (w_dout_tx                ),  //* The output of data
      .empty                (w_empty_tx               ),  //* Read domain empty
      .wrusedw              (                         ),  //* Usedword
      .rdusedw              (                         )   //* Usedword
    );
    defparam  data_tx.width = 8,
              data_tx.depth = 12,
              data_tx.words = 4096;
  `else
    ASYNCFIFO_512x8 data_rx(
      .rd_aclr                (!i_rst_n             ),  //* Reset the all read signal
      .wr_aclr                (!i_sys_rst_n         ),  //* Reset the all write signal
      .data                   (i_din_8b             ),  //* The Inport of data 
      .rdclk                  (i_clk                ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_rx            ),  //* active-high
      .wrclk                  (i_sys_clk            ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                  (i_din_valid          ),  //* active-high
      .q                      (w_dout_rx            ),  //* The output of data
      .rdempty                (w_empty_rx           ),  //* Read domain empty
      .rdalempty              (                     ),  //* Read domain almost-empty
      .wrusedw                (                     ),  //* Write-usedword
      .rdusedw                (                     )   //* Read-usedword
    );

    ASYNCFIFO_4096x8 data_tx(
      .rd_aclr                (!i_sys_rst_n         ),  //* Reset the all read signal
      .wr_aclr                (!i_rst_n             ),  //* Reset the all write signal
      .data                   (r_din_tx             ),  //* The Inport of data 
      .rdclk                  (i_sys_clk            ),  //* ASYNC ReadClk
      .rdreq                  (r_rden_tx            ),  //* active-high
      .wrclk                  (i_clk                ),  //* ASYNC WriteClk, SYNC use wrclk
      .wrreq                  (r_wren_tx            ),  //* active-high
      .q                      (w_dout_tx            ),  //* The output of data
      .rdempty                (w_empty_tx           ),  //* Read domain empty
      .rdalempty              (                     ),  //* Read domain almost-empty
      .wrusedw                (                     ),  //* Write-usedword
      .rdusedw                (                     )   //* Read-usedword
    );
  `endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//



endmodule
