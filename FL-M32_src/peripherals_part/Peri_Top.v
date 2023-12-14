/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Peri_Top.
 *  Description:        This module is used to connect PE with Periperals.
 *  Last updated date:  2022.04.01.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Space = 2;
 */

module Peri_Top(
  //======================= clock & resets  ======================//
   input  wire                                  i_pe_clk
  ,input  wire                                  i_rst_n
  ,input  wire                                  i_spi_clk
  ,input  wire                                  i_sys_clk
  ,input  wire                                  i_sys_rst_n
  //======================= Periperals      ======================//
  //* SPI
  `ifdef SPI_PERI
    ,output wire                                o_spi_clk       //* spi master clock, divide by 2 sysclk
    ,output wire                                o_spi_csn       //* spi chip select
    ,output wire                                o_spi_mosi      //* spi master send slave receive
    ,input  wire                                i_spi_miso      //* spi master receive slave send
    //* inilization by flash (spi);
    ,output wire                                o_conf_wren_spi 
    ,output wire  [                      31:0]  o_conf_addr_spi 
    ,output wire  [                      31:0]  o_conf_wdata_spi
    ,output wire  [                       3:0]  o_conf_en_spi   
    ,output wire                                o_finish_inilization
    ,output wire                                o_error_inilization 
  `endif
  `ifdef CMCU
    //* command;
    ,input  wire                                i_command_wr 
    ,input  wire  [                      63:0]  i_command    
    ,output wire                                o_command_alf
    ,output wire                                o_command_wr 
    ,output wire  [                      63:0]  o_command    
    ,input  wire                                i_command_alf
  `endif
  //* UART
  ,input  wire                                  i_uart_rx
  ,output wire                                  o_uart_tx
  ,input  wire                                  i_uart_cts
  //* GPIO
  `ifdef GPIO_PERI
    ,input  wire  [                      15:0]  i_gpio
    ,output wire  [                      15:0]  o_gpio
    ,output wire  [                      15:0]  o_gpio_en       //* '1' is output;
  `endif
  //* CSR, CSRAM
  //* DMA, dDMA
  ,output wire  [              `NUM_PE*32-1:0]  o_addr_2peri 
  ,output wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  o_wren_2peri 
  ,output wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  o_rden_2peri 
  ,output wire  [              `NUM_PE*32-1:0]  o_wdata_2peri
  ,output wire  [               `NUM_PE*4-1:0]  o_wstrb_2peri
  ,input  wire  [`NUM_PE*`NUM_PERI_OUT*32-1:0]  i_rdata_2PBUS
  ,input  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  i_ready_2PBUS
  ,input  wire  [   `NUM_PE*`NUM_PERI_OUT-1:0]  i_int_2PBUS  

  //* Peri interface (for 4 PEs)
  ,input  wire  [               `NUM_PE_T-1:0]  i_peri_rden 
  ,input  wire  [               `NUM_PE_T-1:0]  i_peri_wren 
  ,input  wire  [            `NUM_PE_T*32-1:0]  i_peri_addr 
  ,input  wire  [            `NUM_PE_T*32-1:0]  i_peri_wdata
  ,input  wire  [             `NUM_PE_T*4-1:0]  i_peri_wstrb
  ,output wire  [            `NUM_PE_T*32-1:0]  o_peri_rdata
  ,output wire  [               `NUM_PE_T-1:0]  o_peri_ready

  //* irq interface (for 3 PEs)
  ,output wire  [              `NUM_PE*32-1:0]  o_irq    
  ,input  wire  [                 `NUM_PE-1:0]  i_irq_ack
  ,input  wire  [               `NUM_PE*5-1:0]  i_irq_id 

  //* system time;
  ,input  wire                                  i_update_valid
  ,input  wire  [64:0]                          i_update_system_time
  ,output wire  [63:0]                          o_system_time
  ,output wire                                  o_second_pulse
  //* debug;
  //* csr;
  ,output wire  [3:0]                           d_csr_cnt_pe0_wr_4b           
  ,output wire  [3:0]                           d_csr_cnt_pe1_wr_4b           
  ,output wire  [3:0]                           d_csr_cnt_pe2_wr_4b           
  ,output wire  [3:0]                           d_csr_cnt_pe0_rd_4b           
  ,output wire  [3:0]                           d_csr_cnt_pe1_rd_4b           
  ,output wire  [3:0]                           d_csr_cnt_pe2_rd_4b           
  ,output wire  [31:0]                          d_csr_pe0_instr_offsetAddr_32b
  ,output wire  [31:0]                          d_csr_pe1_instr_offsetAddr_32b
  ,output wire  [31:0]                          d_csr_pe2_instr_offsetAddr_32b
  ,output wire  [31:0]                          d_csr_pe0_data_offsetAddr_32b 
  ,output wire  [31:0]                          d_csr_pe1_data_offsetAddr_32b 
  ,output wire  [31:0]                          d_csr_pe2_data_offsetAddr_32b 
  ,output wire  [2:0]                           d_csr_guard_3b     
  ,output wire  [3:0]                           d_csr_cnt_pe0_int_4b          
  ,output wire  [3:0]                           d_csr_cnt_pe1_int_4b          
  ,output wire  [3:0]                           d_csr_cnt_pe2_int_4b          
  ,output wire  [3:0]                           d_csr_start_en_4b             
  //* gpio;
  ,output wire                                  d_gpio_en_1b
  ,output wire  [15:0]                          d_gpio_data_ctrl_16b
  ,output wire  [15:0]                          d_gpio_bm_int_16b
  ,output wire  [15:0]                          d_gpio_bm_clear_16b
  ,output wire  [15:0]                          d_gpio_pos_neg_16b
  ,output wire  [15:0]                          d_gpio_dir_16b
  ,output wire  [15:0]                          d_gpio_recvData_16b
  ,output wire  [15:0]                          d_gpio_sendData_16b
  ,output wire  [3:0]                           d_gpio_cnt_pe0_wr_4b
  ,output wire  [3:0]                           d_gpio_cnt_pe1_wr_4b
  ,output wire  [3:0]                           d_gpio_cnt_pe2_wr_4b
  ,output wire  [3:0]                           d_gpio_cnt_pe0_rd_4b
  ,output wire  [3:0]                           d_gpio_cnt_pe1_rd_4b
  ,output wire  [3:0]                           d_gpio_cnt_pe2_rd_4b
  ,output wire  [3:0]                           d_gpio_cnt_int_4b
  //* csram;
  ,output wire  [3:0]                           d_csram_cnt_pe0_wr_4b
  ,output wire  [3:0]                           d_csram_cnt_pe1_wr_4b
  ,output wire  [3:0]                           d_csram_cnt_pe2_wr_4b
  ,output wire  [3:0]                           d_csram_cnt_pe0_rd_4b
  ,output wire  [3:0]                           d_csram_cnt_pe1_rd_4b
  ,output wire  [3:0]                           d_csram_cnt_pe2_rd_4b
  //* spi;
  ,output wire  [3:0]                           d_spi_state_read_4b
  ,output wire  [3:0]                           d_spi_state_spi_4b
  ,output wire  [3:0]                           d_spi_state_resp_4b
  ,output wire  [3:0]                           d_spi_cnt_pe0_rd_4b
  ,output wire  [3:0]                           d_spi_cnt_pe1_rd_4b
  ,output wire  [3:0]                           d_spi_cnt_pe2_rd_4b
  ,output wire  [3:0]                           d_spi_cnt_pe0_wr_4b
  ,output wire  [3:0]                           d_spi_cnt_pe1_wr_4b
  ,output wire  [3:0]                           d_spi_cnt_pe2_wr_4b
  ,output wire                                  d_spi_empty_spi_1b
  ,output wire  [6:0]                           d_spi_usedw_spi_7b
  //* ready * irq;
  ,output wire  [3:0]                           d_peri_ready_4b
  ,output wire  [8:0]                           d_pe0_int_9b
  ,output wire  [8:0]                           d_pe1_int_9b
  ,output wire  [8:0]                           d_pe2_int_9b
);

  //======================= internal reg/wire/param declarations =//
  //* wire, used to connect SPI, UART, GPIO, CSR, CSRAM, DMA, dDMA, DRA;
  wire  [31:0]                  w_addr_peri[`NUM_PE-1:0];
  wire  [`NUM_PERI-1:0]         w_wren_peri[`NUM_PE-1:0];
  wire  [`NUM_PERI-1:0]         w_rden_peri[`NUM_PE-1:0];
  wire  [31:0]                  w_wdata_peri[`NUM_PE-1:0];
  wire  [3:0]                   w_wstrb_peri[`NUM_PE-1:0];
  wire  [`NUM_PERI*32-1:0]      w_rdata_peri[`NUM_PE-1:0];
  wire  [`NUM_PERI-1:0]         w_ready_peri[`NUM_PE-1:0];
  wire  [`NUM_PERI:0]           w_int_peri[`NUM_PE-1:0];

  wire  [31:0]                  w_addr_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN-1:0]      w_wren_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN-1:0]      w_rden_peri_in[`NUM_PE-1:0];
  wire  [31:0]                  w_wdata_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN*4-1:0]    w_wstrb_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN*32-1:0]   w_rdata_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN-1:0]      w_ready_peri_in[`NUM_PE-1:0];
  wire  [`NUM_PERI_IN-1:0]      w_int_peri_in[`NUM_PE-1:0];

  //* time interrupt;
  wire  [`NUM_PE-1:0]           w_time_int;
  //==============================================================//

  //======================= Combine Peri_out/in ==================//
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe=i_pe+1) begin : Peri_PE
      assign o_addr_2peri[i_pe*32+:32]    = w_addr_peri[i_pe];
      assign w_addr_peri_in[i_pe]         = w_addr_peri[i_pe];
      assign {o_wren_2peri[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT],        w_wren_peri_in[i_pe]}   = w_wren_peri[i_pe];
      assign {o_rden_2peri[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT],        w_rden_peri_in[i_pe]}   = w_rden_peri[i_pe];
      assign o_wdata_2peri[i_pe*32+:32]   = w_wdata_peri[i_pe];
      assign w_wdata_peri_in[i_pe]        = w_wdata_peri[i_pe];
      assign o_wstrb_2peri[i_pe*4+:4]     = w_wstrb_peri[i_pe];
      assign w_wstrb_peri_in[i_pe]        = w_wstrb_peri[i_pe];

      assign w_rdata_peri[i_pe] = {i_rdata_2PBUS[i_pe*`NUM_PERI_OUT*32+:`NUM_PERI_OUT*32],  w_rdata_peri_in[i_pe]};
      assign w_ready_peri[i_pe] = {i_ready_2PBUS[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT],        w_ready_peri_in[i_pe]};
      assign w_int_peri[i_pe]   = {w_time_int[i_pe], i_int_2PBUS[i_pe*`NUM_PERI_OUT+:`NUM_PERI_OUT], w_int_peri_in[i_pe]};
    end
  endgenerate
  //==============================================================//

  //======================= Periperal_Bus ========================//
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_bus
      Periperal_Bus Periperal_Bus (
        //* clk & rst_n;
        .i_clk              (i_pe_clk                     ),
        .i_rst_n            (i_rst_n                      ),
        //* peri interface;
        .i_peri_rden        (i_peri_rden[i_pe]            ),
        .i_peri_wren        (i_peri_wren[i_pe]            ),
        .i_peri_addr        (i_peri_addr[i_pe*32+:32]     ),
        .i_peri_wdata       (i_peri_wdata[i_pe*32+:32]    ),
        .i_peri_wstrb       (i_peri_wstrb[i_pe*4+:4]      ),
        .o_peri_rdata       (o_peri_rdata[i_pe*32+:32]    ),
        .o_peri_ready       (o_peri_ready[i_pe]           ),
        .o_peri_gnt         (                             ),
        //* conncet DMA, dDMA, CSRAM, CSR, SPI, GPIO, UART;
        .o_addr_2peri       (w_addr_peri[i_pe]            ),
        .o_wren_2peri       (w_wren_peri[i_pe]            ),
        .o_rden_2peri       (w_rden_peri[i_pe]            ),
        .o_wdata_2peri      (w_wdata_peri[i_pe]           ),
        .o_wstrb_2peri      (w_wstrb_peri[i_pe]           ),
        .i_rdata_2PBUS      (w_rdata_peri[i_pe]           ),
        .i_ready_2PBUS      (w_ready_peri[i_pe]           )
      );
    end
  endgenerate
  //==============================================================//

  //======================= Interrupt_Ctrl & Uart ================//
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_int
      //* INT_CTRL;
      Interrupt_Ctrl Interrupt_Ctrl(
        .i_clk              (i_pe_clk                     ),
        .i_rst_n            (i_rst_n                      ),
        .i_irq              (w_int_peri[i_pe]             ),
        .o_irq              (o_irq[i_pe*32+:32]           ),
        .i_irq_ack          (i_irq_ack[i_pe]              ),
        .i_irq_id           (i_irq_id[i_pe*5+:5]          )
      );
    end
  endgenerate

  //* UART; 
    wire  [`NUM_PE*32-1:0]    w_uart_addr_peri_in;
    wire  [`NUM_PE-1:0]       w_uart_wren_peri_in;
    wire  [`NUM_PE-1:0]       w_uart_rden_peri_in;
    wire  [`NUM_PE*32-1:0]    w_uart_wdata_peri_in;
    wire  [`NUM_PE*32-1:0]    w_uart_rdata_peri_in;
    wire  [`NUM_PE-1:0]       w_uart_ready_peri_in;
    generate
      for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_gpio
        assign w_uart_addr_peri_in[i_pe*32+:32]   = w_addr_peri_in[i_pe];
        assign w_uart_wren_peri_in[i_pe]          = w_wren_peri_in[i_pe][`UART];
        assign w_uart_rden_peri_in[i_pe]          = w_rden_peri_in[i_pe][`UART];
        assign w_uart_wdata_peri_in[i_pe*32+:32]  = w_wdata_peri_in[i_pe];
        assign w_rdata_peri_in[i_pe][`UART*32+:32]= w_uart_rdata_peri_in[i_pe*32+:32];
        assign w_ready_peri_in[i_pe][`UART]       = w_uart_ready_peri_in[i_pe];
      end
    endgenerate
  UART_TOP UART_TOP(
    //* clk & rst_n;
    .i_clk              (i_pe_clk                           ),
    .i_rst_n            (i_rst_n                            ),
    .i_sys_clk          (i_sys_clk                          ),
    .i_sys_rst_n        (i_sys_rst_n                        ),
    //* uart recv/trans;
    .o_uart_tx          (o_uart_tx                          ),
    .i_uart_rx          (i_uart_rx                          ),
    .i_uart_cts         (i_uart_cts                         ),
    //* peri interface;
    .i_addr_32b         (w_uart_addr_peri_in                ),
    .i_wren             (w_uart_wren_peri_in                ),
    .i_rden             (w_uart_rden_peri_in                ),
    .i_din_32b          (w_uart_wdata_peri_in               ),
    .o_dout_32b         (w_uart_rdata_peri_in               ),
    .o_dout_32b_valid   (w_uart_ready_peri_in               ),
    .o_interrupt        (w_int_peri_in[0][`UART]            )
  );
  `ifdef PE1_EN
    assign w_int_peri_in[1][`UART] = 1'b0;
  `endif
  `ifdef PE2_EN
    assign w_int_peri_in[2][`UART] = 1'b0;
  `endif
  `ifdef PE3_EN
    assign w_int_peri_in[3][`UART] = 1'b0;
  `endif
  //==============================================================//

  //======================= Control Status Registers =============//
  wire  [`NUM_PE*32-1:0]    w_addr_peri_in_CSR;
  wire  [`NUM_PE-1:0]       w_wren_peri_in_CSR;
  wire  [`NUM_PE-1:0]       w_rden_peri_in_CSR;
  wire  [`NUM_PE*32-1:0]    w_wdata_peri_in_CSR;
  wire  [`NUM_PE*32-1:0]    w_rdata_peri_in_CSR;
  wire  [`NUM_PE-1:0]       w_ready_peri_in_CSR;
  wire  [`NUM_PE-1:0]       w_int_peri_in_CSR;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_csr
      assign w_addr_peri_in_CSR[i_pe*32+:32]    = w_addr_peri_in[i_pe];
      assign w_wren_peri_in_CSR[i_pe]           = w_wren_peri_in[i_pe][`CSR];
      assign w_rden_peri_in_CSR[i_pe]           = w_rden_peri_in[i_pe][`CSR];
      assign w_wdata_peri_in_CSR[i_pe*32+:32]   = w_wdata_peri_in[i_pe];
      assign w_rdata_peri_in[i_pe][`CSR*32+:32] = w_rdata_peri_in_CSR[i_pe*32+:32];
      assign w_ready_peri_in[i_pe][`CSR]        = w_ready_peri_in_CSR[i_pe];
      assign w_int_peri_in[i_pe][`CSR]          = w_int_peri_in_CSR[i_pe];
    end
  endgenerate

  //* test;
  wire [31:0] w_csr;
  assign w_csr = `CSR;

  //* CSR module
  CSR_TOP CSR_TOP(
    //* clk & rst_n;
    .i_clk                  (i_pe_clk                           ),
    .i_rst_n                (i_rst_n                            ),
    //* peri interface;
    .i_addr_32b             (w_addr_peri_in_CSR                 ),
    .i_wren                 (w_wren_peri_in_CSR                 ),
    .i_rden                 (w_rden_peri_in_CSR                 ),
    .i_din_32b              (w_wdata_peri_in_CSR                ),
    .o_dout_32b             (w_rdata_peri_in_CSR                ),
    .o_dout_32b_valid       (w_ready_peri_in_CSR                ),
    .o_interrupt            (w_int_peri_in_CSR                  ),
    .o_time_int             (w_time_int                         ),
    //* system time;
    .i_update_valid         (i_update_valid                     ),
    .i_update_system_time   (i_update_system_time               ),
    .o_system_time          (o_system_time                      ),
    .o_second_pulse         (o_second_pulse                     ),
    //* debug;
    .d_cnt_pe0_wr_4b              (d_csr_cnt_pe0_wr_4b           ),
    .d_cnt_pe1_wr_4b              (d_csr_cnt_pe1_wr_4b           ),
    .d_cnt_pe2_wr_4b              (d_csr_cnt_pe2_wr_4b           ),
    .d_cnt_pe0_rd_4b              (d_csr_cnt_pe0_rd_4b           ),
    .d_cnt_pe1_rd_4b              (d_csr_cnt_pe1_rd_4b           ),
    .d_cnt_pe2_rd_4b              (d_csr_cnt_pe2_rd_4b           ),
    .d_pe0_instr_offsetAddr_32b   (d_csr_pe0_instr_offsetAddr_32b),
    .d_pe1_instr_offsetAddr_32b   (d_csr_pe1_instr_offsetAddr_32b),
    .d_pe2_instr_offsetAddr_32b   (d_csr_pe2_instr_offsetAddr_32b),
    .d_pe0_data_offsetAddr_32b    (d_csr_pe0_data_offsetAddr_32b ),
    .d_pe1_data_offsetAddr_32b    (d_csr_pe1_data_offsetAddr_32b ),
    .d_pe2_data_offsetAddr_32b    (d_csr_pe2_data_offsetAddr_32b ),
    .d_guard_3b                   (d_csr_guard_3b                ),
    .d_cnt_pe0_int_4b             (d_csr_cnt_pe0_int_4b          ),
    .d_cnt_pe1_int_4b             (d_csr_cnt_pe1_int_4b          ),
    .d_cnt_pe2_int_4b             (d_csr_cnt_pe2_int_4b          ),
    .d_start_en_4b                (d_csr_start_en_4b             )
  );
  //==============================================================//

  //======================= GPIO           =======================//
  `ifdef GPIO_EN
    wire  [`NUM_PE*32-1:0]    w_gpio_addr_peri_in;
    wire  [`NUM_PE-1:0]       w_gpio_wren_peri_in;
    wire  [`NUM_PE-1:0]       w_gpio_rden_peri_in;
    wire  [`NUM_PE*32-1:0]    w_gpio_wdata_peri_in;
    wire  [`NUM_PE*32-1:0]    w_gpio_rdata_peri_in;
    wire  [`NUM_PE-1:0]       w_gpio_ready_peri_in;
    wire  [`NUM_PE-1:0]       w_gpio_int_peri_in;
    generate
      for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_gpio
        assign w_gpio_addr_peri_in[i_pe*32+:32]   = w_addr_peri_in[i_pe];
        assign w_gpio_wren_peri_in[i_pe]          = w_wren_peri_in[i_pe][`GPIO];
        assign w_gpio_rden_peri_in[i_pe]          = w_rden_peri_in[i_pe][`GPIO];
        assign w_gpio_wdata_peri_in[i_pe*32+:32]  = w_wdata_peri_in[i_pe];
        assign w_rdata_peri_in[i_pe][`GPIO*32+:32]= w_gpio_rdata_peri_in[i_pe*32+:32];
        assign w_ready_peri_in[i_pe][`GPIO]       = w_gpio_ready_peri_in[i_pe];
        assign w_int_peri_in[i_pe][`GPIO]         = w_gpio_int_peri_in[i_pe];
      end
    endgenerate

    GPIO_TOP GPIO_TOP(
      //* clk & rst_n;
      .i_clk                  (i_pe_clk                 ),
      .i_rst_n                (i_rst_n                  ),
      //* gpio recv/trans;
      .i_gpio                 (i_gpio                   ),
      .o_gpio                 (o_gpio                   ),
      .o_gpio_en              (o_gpio_en                ),
      //* peri interface;
      .i_addr_32b             (w_gpio_addr_peri_in      ),
      .i_wren                 (w_gpio_wren_peri_in      ),
      .i_rden                 (w_gpio_rden_peri_in      ),
      .i_din_32b              (w_gpio_wdata_peri_in     ),
      .o_dout_32b             (w_gpio_rdata_peri_in     ),
      .o_dout_32b_valid       (w_gpio_ready_peri_in     ),
      .o_interrupt            (w_gpio_int_peri_in       ),
      //* debug;
      .d_en_1b                (d_gpio_en_1b             ),
      .d_data_ctrl_16b        (d_gpio_data_ctrl_16b     ),
      .d_bm_int_16b           (d_gpio_bm_int_16b        ),
      .d_bm_clear_16b         (d_gpio_bm_clear_16b      ),
      .d_pos_neg_16b          (d_gpio_pos_neg_16b       ),
      .d_dir_16b              (d_gpio_dir_16b           ),
      .d_recvData_16b         (d_gpio_recvData_16b      ),
      .d_sendData_16b         (d_gpio_sendData_16b      ),
      .d_cnt_pe0_wr_4b        (d_gpio_cnt_pe0_wr_4b     ),
      .d_cnt_pe1_wr_4b        (d_gpio_cnt_pe1_wr_4b     ),
      .d_cnt_pe2_wr_4b        (d_gpio_cnt_pe2_wr_4b     ),
      .d_cnt_pe0_rd_4b        (d_gpio_cnt_pe0_rd_4b     ),
      .d_cnt_pe1_rd_4b        (d_gpio_cnt_pe1_rd_4b     ),
      .d_cnt_pe2_rd_4b        (d_gpio_cnt_pe2_rd_4b     ),
      .d_cnt_int_4b           (d_gpio_cnt_int_4b        )
    );
  `else 
    // assign w_ready_peri_in[0][`GPIO] = 1'b0;
    // assign w_ready_peri_in[1][`GPIO] = 1'b0;
    // assign w_ready_peri_in[2][`GPIO] = 1'b0;
  `endif
  //==============================================================//

  //======================= SPI           =======================//
  `ifdef SPI_EN
    wire  [`NUM_PE*32-1:0]    w_addr_peri_in_SPI;
    wire  [`NUM_PE-1:0]       w_wren_peri_in_SPI;
    wire  [`NUM_PE-1:0]       w_rden_peri_in_SPI;
    wire  [`NUM_PE*32-1:0]    w_wdata_peri_in_SPI;
    wire  [`NUM_PE*32-1:0]    w_rdata_peri_in_SPI;
    wire  [`NUM_PE-1:0]       w_ready_peri_in_SPI;
    wire  [`NUM_PE-1:0]       w_int_peri_in_SPI;
    generate
      for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_spi
        assign w_addr_peri_in_SPI[i_pe*32+:32]    = w_addr_peri_in[i_pe];
        assign w_wren_peri_in_SPI[i_pe]           = w_wren_peri_in[i_pe][`SPI];
        assign w_rden_peri_in_SPI[i_pe]           = w_rden_peri_in[i_pe][`SPI];
        assign w_wdata_peri_in_SPI[i_pe*32+:32]   = w_wdata_peri_in[i_pe];
        assign w_rdata_peri_in[i_pe][`SPI*32+:32] = w_rdata_peri_in_SPI[i_pe*32+:32];
        assign w_ready_peri_in[i_pe][`SPI]        = w_ready_peri_in_SPI[i_pe];
        assign w_int_peri_in[i_pe][`SPI]          = w_int_peri_in_SPI[i_pe];
      end
    endgenerate

    SPI_PERI_TOP SPI_PERI_TOP(
      //* clk & rst_n;
      .i_clk              (i_pe_clk                     ),
      .i_rst_n            (i_rst_n                      ),
      .i_spi_clk          (i_spi_clk                    ),
      //* gpio recv/trans;
      .o_spi_clk          (o_spi_clk                    ),
      .o_spi_csn          (o_spi_csn                    ),
      .o_spi_mosi         (o_spi_mosi                   ),
      .i_spi_miso         (i_spi_miso                   ),
      //* peri interface;
      .i_addr_32b         (w_addr_peri_in_SPI           ),
      .i_wren             (w_wren_peri_in_SPI           ),
      .i_rden             (w_rden_peri_in_SPI           ),
      .i_din_32b          (w_wdata_peri_in_SPI          ),
      .o_dout_32b         (w_rdata_peri_in_SPI          ),
      .o_dout_32b_valid   (w_ready_peri_in_SPI          ),
      .o_interrupt        (w_int_peri_in_SPI            ),
      //* inilization by flash (spi);
      .o_conf_wren        (o_conf_wren_spi              ),
      .o_conf_addr        (o_conf_addr_spi              ),
      .o_conf_wdata       (o_conf_wdata_spi             ),
      .o_conf_en          (o_conf_en_spi                ),
      .o_finish_inilization(o_finish_inilization        ),
      .o_error_inilization (o_error_inilization         ),
      //* command;
      .i_command_wr       (i_command_wr                 ),
      .i_command          (i_command                    ),
      .o_command_alf      (o_command_alf                ),
      .o_command_wr       (o_command_wr                 ),
      .o_command          (o_command                    ),
      .i_command_alf      (i_command_alf                ),
      //* debug;
      .d_state_read_4b    (d_spi_state_read_4b          ),
      .d_state_spi_4b     (d_spi_state_spi_4b           ),              
      .d_state_resp_4b    (d_spi_state_resp_4b          ),
      .d_cnt_pe0_rd_4b    (d_spi_cnt_pe0_rd_4b          ),
      .d_cnt_pe1_rd_4b    (d_spi_cnt_pe1_rd_4b          ),
      .d_cnt_pe2_rd_4b    (d_spi_cnt_pe2_rd_4b          ),
      .d_cnt_pe0_wr_4b    (d_spi_cnt_pe0_wr_4b          ),
      .d_cnt_pe1_wr_4b    (d_spi_cnt_pe1_wr_4b          ),
      .d_cnt_pe2_wr_4b    (d_spi_cnt_pe2_wr_4b          ),
      .d_empty_spi_1b     (d_spi_empty_spi_1b           ),              
      .d_usedw_spi_7b     (d_spi_usedw_spi_7b           )              
    );
  `else 
    // assign w_ready_peri_in[0][`SPI] = 1'b0;
    // assign w_ready_peri_in[1][`SPI] = 1'b0;
    // assign w_ready_peri_in[2][`SPI] = 1'b0;
  `endif
  //==============================================================//

  //======================= Control Status RAM   =================//
  `ifdef CSRAM_EN
    wire  [`NUM_PE_T*32-1:0]    w_addr_peri_in_CSRAM;
    wire  [`NUM_PE_T-1:0]       w_wren_peri_in_CSRAM;
    wire  [`NUM_PE_T-1:0]       w_rden_peri_in_CSRAM;
    wire  [`NUM_PE_T*32-1:0]    w_wdata_peri_in_CSRAM;
    wire  [`NUM_PE_T*32-1:0]    w_rdata_peri_in_CSRAM;
    wire  [`NUM_PE_T-1:0]       w_ready_peri_in_CSRAM;
    wire  [`NUM_PE_T-1:0]       w_int_peri_in_CSRAM;
    generate
      for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe+1) begin: peri_csram
        assign w_addr_peri_in_CSRAM[i_pe*32+:32]    = w_addr_peri_in[i_pe];
        assign w_wren_peri_in_CSRAM[i_pe]           = w_wren_peri_in[i_pe][`CSRAM];
        assign w_rden_peri_in_CSRAM[i_pe]           = w_rden_peri_in[i_pe][`CSRAM];
        assign w_wdata_peri_in_CSRAM[i_pe*32+:32]   = w_wdata_peri_in[i_pe];
        assign w_rdata_peri_in[i_pe][`CSRAM*32+:32] = w_rdata_peri_in_CSRAM[i_pe*32+:32];
        assign w_ready_peri_in[i_pe][`CSRAM]        = w_ready_peri_in_CSRAM[i_pe];
        assign w_int_peri_in[i_pe][`CSRAM]          = w_int_peri_in_CSRAM[i_pe];
      end
    endgenerate
    `ifdef AIPE_ID
        assign w_addr_peri_in_CSRAM[`AIPE_ID*32+:32]  = i_peri_addr[`AIPE_ID*32+:32];
        assign w_wren_peri_in_CSRAM[`AIPE_ID]         = i_peri_wren[`AIPE_ID];
        assign w_rden_peri_in_CSRAM[`AIPE_ID]         = i_peri_rden[`AIPE_ID];
        assign w_wdata_peri_in_CSRAM[`AIPE_ID*32+:32] = i_peri_wdata[`AIPE_ID*32+:32];
        assign o_peri_rdata[`AIPE_ID*32+:32]          = w_rdata_peri_in_CSRAM[`AIPE_ID*32+:32];
        assign o_peri_ready[`AIPE_ID]                 = w_ready_peri_in_CSRAM[`AIPE_ID];
    `endif

    //* CSR module
    CSRAM_TOP CSRAM_TOP(
      //* clk & rst_n;
      .i_clk                  (i_pe_clk                           ),
      .i_rst_n                (i_rst_n                            ),
      //* peri interface;
      .i_addr_32b             (w_addr_peri_in_CSRAM               ),
      .i_wren                 (w_wren_peri_in_CSRAM               ),
      .i_rden                 (w_rden_peri_in_CSRAM               ),
      .i_din_32b              (w_wdata_peri_in_CSRAM              ),
      .o_dout_32b             (w_rdata_peri_in_CSRAM              ),
      .o_dout_32b_valid       (w_ready_peri_in_CSRAM              ),
      .o_interrupt            (w_int_peri_in_CSRAM                ),
      //* debug;
      .d_cnt_pe0_wr_4b        (d_csram_cnt_pe0_wr_4b              ),
      .d_cnt_pe1_wr_4b        (d_csram_cnt_pe1_wr_4b              ),
      .d_cnt_pe2_wr_4b        (d_csram_cnt_pe2_wr_4b              ),
      .d_cnt_pe0_rd_4b        (d_csram_cnt_pe0_rd_4b              ),
      .d_cnt_pe1_rd_4b        (d_csram_cnt_pe1_rd_4b              ),
      .d_cnt_pe2_rd_4b        (d_csram_cnt_pe2_rd_4b              )
    );
  `endif
  //==============================================================//

  //* debug;
  // assign d_peri_ready_4b        = o_peri_ready;
  // assign d_pe0_int_9b           = w_int_peri[0];
  // assign d_pe1_int_9b           = w_int_peri[1];
  // assign d_pe2_int_9b           = w_int_peri[2];
  assign d_peri_ready_4b        = 4'b0;
  assign d_pe0_int_9b           = 9'b0;
  assign d_pe1_int_9b           = 9'b0;
  assign d_pe2_int_9b           = 9'b0;

endmodule    
