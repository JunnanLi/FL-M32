/*
 *  Project:            timelyRV_v1.4.x -- a RISCV-32IMC SoC.
 *  Module name:        PE_Array_Wrapper.
 *  Description:        Top Module of PE_Array.
 *  Last updated date:  2022.09.01. (checked)
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 *    1) CPI's 134b pkt data definition: 
 *      [133:132] head tag, 2'b10 is head, 2'b01 is tail;
 *      [131:128] invalid tag, 4'b0 means sixteen 8b data is valid;
 *      [127:0]   pkt data, invalid part is padded with x;
 *    2) PE_Array's 134b pkt data definition: 
 *      [133:132] head tag, 2'b01 is head, 2'b10 is tail;
 *      [131:128] valid tag, 4'b1111 means sixteen 8b data is valid;
 *      [127:0]   pkt data, invalid part is padded with x;
 *    3) the riscv-32imc core is a modified cv32e40p;
 *
 *  Space = 2;
 */

`timescale 1ns / 1ps

module PE_Array_Wrapper(
  //======================= clock & resets  ============================//
   input  wire              i_sys_clk                                 
  ,input  wire              i_sys_rst_n                               
  ,input  wire              i_pe_clk                                   
  ,input  wire              i_rst_n
  ,input  wire              i_spi_clk                                 
  //======================= pkt from/to CPI ============================//
  //* MAC for conf;
  ,input  wire  [47:0]      i_pe_conf_mac
  //* pkt in;                                                      
  ,input  wire              i_pkt_valid     //* pkt in valid;         
  ,input  wire  [133:0]     i_pkt           //* pkt;                 
  ,input  wire              i_meta_valid    //* valid with pkt's head;
  ,input  wire  [167:0]     i_meta          //* meta;
  ,output wire              o_alf           //* '1' is almost full;
  //* pkt out;
  ,output wire              o_pkt_valid     //* pkt out valid;
  ,output wire  [133:0]     o_pkt           //* pkt out;
  ,output wire              o_meta_valid    //* valid with pkt's head;
  ,output wire  [167:0]     o_meta          //* meta;
  ,input  wire              i_alf           //* '1' is almost full;
  //======================= Conf from/to CMCU ==========================//
  `ifdef CMCU
    //* input command
    ,input  wire              i_command_wr_slave     
    ,input  wire  [63:0]      i_command_slave
    ,output wire              o_command_alf_slave
    //* output command 
    ,output wire              o_command_wr_slave
    ,output wire  [63:0]      o_command_slave
    ,input  wire              i_command_alf_slave
    //======================= Command to CMCU   ==========================//
    //* input command
    ,input  wire              i_command_wr_master     
    ,input  wire  [63:0]      i_command_master
    ,output wire              o_command_alf_master
    //* output command 
    ,output wire              o_command_wr_master
    ,output wire  [63:0]      o_command_master
    ,input  wire              i_command_alf_master
  `endif
  //======================= uart (3 Ports)  ============================//
  ,input  wire  [`NUM_PE-1:0] i_uart_rx
  ,output wire  [`NUM_PE-1:0] o_uart_tx
  ,input  wire  [`NUM_PE-1:0] i_uart_cts
  ,output wire  [`NUM_PE-1:0] o_uart_rts
  //======================= SPI             ============================//
  `ifdef SPI_EN
    ,output wire              o_spi_clk       
    ,output wire              o_spi_csn       
    ,output wire              o_spi_mosi      
    ,input  wire              i_spi_miso      
  `endif
  //======================= GPIO            ============================//
  `ifdef GPIO_EN
    ,input  wire  [15:0]      i_gpio
    ,output wire  [15:0]      o_gpio
    ,output wire  [15:0]      o_gpio_en       //* '1' is output;
  `endif
  //======================= system_time     ============================//
  ,output wire  [63:0]      o_system_time
  //======================= Pads            ============================//
  ,input  wire  [3:0]       i_start_en_pad
  `ifdef SPI_EN
    ,output wire              o_finish_inilization
    ,output wire              o_error_inilization
  `endif
  ,output wire              o_second_pulse
);

`ifdef CMCU
  //====================================================================//
  //* internal reg/wire/param declarations
  //====================================================================//
  //* 1) localbus: PE_ARRAY <---> CMCU;
  wire                      w_cs_conf,        w_cs_debug;    
  wire                      w_wr_rd_conf,     w_wr_rd_debug;  
  wire          [19:0]      w_address_conf,   w_address_debug;
  wire          [31:0]      w_data_in_conf,   w_data_in_debug;
  wire                      w_ack_n_conf,     w_ack_n_debug;
  wire          [31:0]      w_data_out_conf,  w_data_out_debug;
  //* 2) command: Local_Parser_Conf ---> Local_Parser_Debug;
  wire                      w_command_wr_conf2debug;     
  wire          [63:0]      w_command_conf2debug;
  wire                      w_command_alf_debug2conf;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //* CMCU_CONFIGURE/DEBUG
  //====================================================================//
  //* 1) config;
  LOCAL_PARSE Local_Parser_Conf(
    .clk                    (i_pe_clk                 ),
    .rst_n                  (i_rst_n                  ),
    .MDID                   (7'h30                    ),  //* module ID
    .command_wr             (i_command_wr_slave       ),  //* command
    .command                (i_command_slave          ),
    .command_alf            (o_command_alf_slave      ),
    .next_command_wr        (w_command_wr_conf2debug  ),
    .next_command           (w_command_conf2debug     ),
    .next_command_alf       (w_command_alf_debug2conf ),
    .cs                     (w_cs_conf                ),  //* active low
    .wr_rd                  (w_wr_rd_conf             ),  //* 0:read 1:write
    .address                (w_address_conf           ),
    .data_in                (w_data_in_conf           ),
    .ack_n                  (w_ack_n_conf             ),
    .data_out               (w_data_out_conf          )
  );
  //* 2) debug;
  LOCAL_PARSE Local_Parser_Debug(
    .clk                    (i_pe_clk                 ),
    .rst_n                  (i_rst_n                  ),
    .MDID                   (7'h31                    ),  //* module ID
    .command_wr             (w_command_wr_conf2debug  ),  //* command
    .command                (w_command_conf2debug     ),
    .command_alf            (w_command_alf_debug2conf ),
    .next_command_wr        (o_command_wr_slave       ),
    .next_command           (o_command_slave          ),
    .next_command_alf       (i_command_alf_slave      ),
    .cs                     (w_cs_debug               ),  //* active low
    .wr_rd                  (w_wr_rd_debug            ),  //* 0:read 1:write
    .address                (w_address_debug          ),
    .data_in                (w_data_in_debug          ),
    .ack_n                  (w_ack_n_debug            ),
    .data_out               (w_data_out_debug         )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
`endif

  //====================================================================//
  //*   PE_ARRAY
  //====================================================================//
  //* 1) Format exchange: {SOP_133b, EOP_132b} <---> {EOP_133b, SOP_132b};
  wire [133:0]  w_i_pkt, w_o_pkt;
  assign        w_i_pkt =   {i_pkt[132],      i_pkt[133],  
                            ~i_pkt[131:128],  i_pkt[127:0]  };
  assign        o_pkt   =   {w_o_pkt[132],    w_o_pkt[133],
                            ~w_o_pkt[131:128],w_o_pkt[127:0]};
  //* 2) PE_ARRAY;
  PE_ARRAY PE_ARRAY_inst(
    //* clock & resets;
    .i_sys_clk              (i_sys_clk                ),
    .i_sys_rst_n            (i_sys_rst_n              ),
    .i_pe_clk               (i_pe_clk                 ),
    .i_rst_n                (i_rst_n                  ),
    .i_spi_clk              (i_spi_clk                ), 
    //* pkt from/to CPI:
    .i_pe_conf_mac          (i_pe_conf_mac            ),
    //* 1) pkt from CPI;
    .i_data_valid           (i_pkt_valid              ),
    .i_data                 (w_i_pkt                  ),
    .i_meta_valid           (i_meta_valid             ),
    .i_meta                 (i_meta                   ),
    .o_alf                  (o_alf                    ),
    //* 2) pkt to CPI;
    .o_data_valid           (o_pkt_valid              ),
    .o_data                 (w_o_pkt                  ),
    .o_meta_valid           (o_meta_valid             ),
    .o_meta                 (o_meta                   ),
    .i_alf                  (i_alf                    ),
    `ifdef CMCU
      //* configure;
      .i_cs_conf              (w_cs_conf                ),
      .i_wr_rd_conf           (w_wr_rd_conf             ),
      .i_address_conf         (w_address_conf           ),
      .i_data_in_conf         (w_data_in_conf           ),
      .o_ack_n_conf           (w_ack_n_conf             ),
      .o_data_out_conf        (w_data_out_conf          ),
      //* debug;
      .i_cs_debug             (w_cs_debug               ),
      .i_wr_rd_debug          (w_wr_rd_debug            ),
      .i_address_debug        (w_address_debug          ),
      .i_data_in_debug        (w_data_in_debug          ),
      .o_ack_n_debug          (w_ack_n_debug            ),
      .o_data_out_debug       (w_data_out_debug         ),
    `endif
    `ifdef SPI_EN
      //* spi;
      .o_spi_clk              (o_spi_clk                ),
      .o_spi_csn              (o_spi_csn                ), 
      .o_spi_mosi             (o_spi_mosi               ), 
      .i_spi_miso             (i_spi_miso               ),
      //* command;
      .i_command_wr           (i_command_wr_master      ),
      .i_command              (i_command_master         ),
      .o_command_alf          (o_command_alf_master     ),
      .o_command_wr           (o_command_wr_master      ),
      .o_command              (o_command_master         ),
      .i_command_alf          (i_command_alf_master     ),
    `endif
    `ifdef GPIO_EN
      //* gpio;
      .i_gpio                 (i_gpio                   ),
      .o_gpio                 (o_gpio                   ),
      .o_gpio_en              (o_gpio_en                ),
    `endif
    //* uart;
    .i_uart_rx              (i_uart_rx                ),
    .o_uart_tx              (o_uart_tx                ),
    .i_uart_cts             (i_uart_cts               ),
    .o_uart_rts             (o_uart_rts               ),
    //* system_time
    .o_system_time          (o_system_time            ),
    //* pads
    .i_start_en_pad         (i_start_en_pad           ),
    
    `ifdef SPI_EN
      .o_finish_inilization   (o_finish_inilization     ),
      .o_error_inilization    (o_error_inilization      ),
    `endif
    .o_second_pulse         (o_second_pulse           )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


endmodule
