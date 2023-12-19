/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Cv32e40p_Top.
 *  Description:        top module of timelyRV core.
 *  Last updated date:  2022.10.11. (checked)
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) irq for cv32e40p: {irq_fast, 4'b0, irq_external, 3'b0, irq_timer, 3'b0, 
 *                            irq_software, 3'b0};
 */

module Cv32e40p_Top(
   input    wire                    i_clk
  ,input    wire                    i_rst_n

  //* Instruction memory interface
  ,output   logic                   o_instr_req
  ,input    logic                   i_instr_gnt
  ,input    logic                   i_instr_rvalid
  ,output   logic [       31:0]     o_instr_addr
  ,input    logic [       31:0]     i_instr_rdata

  //* Data memory interface
  ,output   logic                   o_data_req
  ,input    logic                   i_data_gnt
  ,input    logic                   i_data_rvalid
  ,output   logic                   o_data_we
  ,output   logic [        3:0]     o_data_be
  ,output   logic [       31:0]     o_data_addr
  ,output   logic [       31:0]     o_data_wdata
  ,input    logic [       31:0]     i_data_rdata

  //* interface for peripheral
  ,output   wire                    o_peri_rden
  ,output   wire                    o_peri_wren
  ,output   wire  [       31:0]     o_peri_addr
  ,output   wire  [       31:0]     o_peri_wdata
  ,output   wire  [        3:0]     o_peri_wstrb
  ,input    wire  [       31:0]     i_peri_rdata
  ,input    wire                    i_peri_ready
  ,input    wire  [       31:0]     i_irq_bitmap
  ,input    wire                    i_peri_gnt
  ,output   wire                    o_irq_ack
  ,output   wire  [        4:0]     o_irq_id

  //* interface for DRA
  ,output   logic                   o_reg_rd
  ,output   logic [       31:0]     o_reg_raddr
  ,input    logic [      511:0]     i_reg_rdata
  ,input    logic                   i_reg_rvalid
  ,input    logic                   i_reg_rvalid_desp
  ,output   logic                   o_reg_wr
  ,output   logic                   o_reg_wr_desp
  ,output   logic [       31:0]     o_reg_waddr
  ,output   logic [      511:0]     o_reg_wdata
  ,input    logic [       31:0]     i_status
  ,output   logic [       31:0]     o_status

  //* debug;
  ,input    wire  [        5:0]     d_i_reg_id_6b  //* request reg's value;
  ,output   wire  [       31:0]     d_reg_value_32b
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  import          cv32e40p_apu_core_pkg::*;
  localparam      INSTR_RDATA_WIDTH = 32,
                  BOOT_ADDR         = 32'h180,  //* start addr. of Proc.
                  PULP_XPULP        = 0,        //* without PULP arch.
                  PULP_CLUSTER      = 0,        //* without Cluster
                  FPU               = 0,        //* without FPU
                  PULP_ZFINX        = 0,        //* without ZFINX instr.
                  NUM_MHPMCOUNTERS  = 1,        //* for metering performance
                  DM_HALTADDRESS    = 32'h1A110800;  

  //* 1) signals connecting core to memory
  logic                               w_data_req;
  logic                               w_data_gnt;
  logic                               w_data_rvalid;
  logic [                 31:0]       w_data_rdata, w_data_addr, w_instr_addr;

  //* 2) signals to debug unit
  // logic                               w_debug_req = 1'b0;
  logic                               w_core_sleep;

  //* 3) APU Core to FP Wrapper
  logic                               w_apu_req;
  logic [    APU_NARGS_CPU-1:0][31:0] w_apu_operands;
  logic [      APU_WOP_CPU-1:0]       w_apu_op;
  logic [ APU_NDSFLAGS_CPU-1:0]       w_apu_flags;

  //* 4) APU FP Wrapper to Core
  logic                               w_apu_gnt;
  logic                               w_apu_rvalid;
  logic [                 31:0]       w_apu_rdata;
  logic [ APU_NUSFLAGS_CPU-1:0]       w_apu_rflags;

  assign          o_instr_addr      = {2'b0,w_instr_addr[31:2]};
  assign          o_data_addr       = {2'b0,w_data_addr[31:2]};
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   cv32e40p_wrapper
  //====================================================================//
  cv32e40p_wrapper #(
    .PULP_XPULP             (PULP_XPULP           ),
    .PULP_CLUSTER           (PULP_CLUSTER         ),
    .FPU                    (FPU                  ),
    .PULP_ZFINX             (PULP_ZFINX           ),
    .NUM_MHPMCOUNTERS       (NUM_MHPMCOUNTERS     )
  ) wrapper_i (
    //* clk & rst_n;
    .clk_i                  (i_clk                ),
    .rst_ni                 (i_rst_n              ),
    //* plup info.
    .pulp_clock_en_i        (1'b1                 ),
    .scan_cg_en_i           (1'b0                 ),
    //* start addr. for Proc./IRQ/Debug
    .boot_addr_i            (BOOT_ADDR            ),
    .mtvec_addr_i           (32'h0                ),
    .dm_halt_addr_i         (DM_HALTADDRESS       ),
    .hart_id_i              (32'h0                ),
    .dm_exception_addr_i    (32'h0                ),
    //* instr access interface;
    .instr_addr_o           (w_instr_addr         ),
    .instr_req_o            (o_instr_req          ),
    .instr_rdata_i          (i_instr_rdata        ),
    .instr_gnt_i            (i_instr_gnt          ),
    .instr_rvalid_i         (i_instr_rvalid       ),
    //* data access interface;
    .data_addr_o            (w_data_addr          ),
    .data_wdata_o           (o_data_wdata         ),
    .data_we_o              (o_data_we            ),
    .data_req_o             (w_data_req           ),
    .data_be_o              (o_data_be            ),
    .data_rdata_i           (w_data_rdata         ),
    .data_gnt_i             (w_data_gnt           ),
    .data_rvalid_i          (w_data_rvalid        ),
    //* apu interface, have not been used;
    .apu_req_o              (w_apu_req            ),
    .apu_gnt_i              (w_apu_gnt            ),
    .apu_operands_o         (w_apu_operands       ),
    .apu_op_o               (w_apu_op             ),
    .apu_flags_o            (w_apu_flags          ),
    .apu_rvalid_i           (w_apu_rvalid         ),
    .apu_result_i           (w_apu_rdata          ),
    .apu_flags_i            (w_apu_rflags         ),
    //* irq interface;
    .irq_i                  (i_irq_bitmap         ),
    .irq_ack_o              (o_irq_ack            ),
    .irq_id_o               (o_irq_id             ),
    //* debug interface, have not been used;
    // .debug_req_i            (w_debug_req          ),
    .debug_req_i            (1'b0                 ),
    .debug_havereset_o      (                     ),
    .debug_running_o        (                     ),
    .debug_halted_o         (                     ),
    .d_i_reg_id_6b          (d_i_reg_id_6b        ),
    .d_reg_value_32b        (d_reg_value_32b      ),
    //* have not been used;
    .fetch_enable_i         (1'b1                 ),
    .core_sleep_o           (w_core_sleep         ),
    //* DRA interface;
    .reg_rd_o               (o_reg_rd             ),
    .reg_raddr_o            (o_reg_raddr          ),
    .reg_rdata_i            (i_reg_rdata          ),
    .reg_rvalid_i           (i_reg_rvalid         ),
    .reg_rvalid_desp_i      (i_reg_rvalid_desp    ),
    .reg_wr_o               (o_reg_wr             ),
    .reg_wr_desp_o          (o_reg_wr_desp        ),
    .reg_waddr_o            (o_reg_waddr          ),
    .reg_wdata_o            (o_reg_wdata          ),
    .status_i               (i_status             ),
    .status_o               (o_status             )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Initialize APU signals, has not been used;
  //====================================================================//
  //* TODO, to add FPU ...
  assign w_apu_gnt          = 1'b0;
  assign w_apu_rvalid       = 1'b0;
  assign w_apu_rdata        = 32'b0;
  assign w_apu_rflags       = 5'b0;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   MUX/DMUX for data/peri;                                         //
  //*                w_data_addr[31:28] == 0x0xxxxxxx                   //
  //*     1) w_data ------------------------------------> o_data        //
  //*                     + w_data_addr[31:28] == 0x?xxxxxxx            //
  //*                     ------------------------------------> o_peri  //
  //*                                                                   //
  //*                i_data_rvalid == 1'b1                              //
  //*     2) w_data <------------------------------------ i_data        //
  //*                     + i_peri_ready == 1'b1                        //
  //*                     ------------------------------------ i_peri   //
  //====================================================================//
  //* assign memory interface signals, top 4b of data sram is "0";
  assign o_data_req         = (w_data_addr[31:28] == 4'b0)? w_data_req : 1'b0;
  //* all (w_data_addr[31:28] != 4'b0) to peri;
  assign o_peri_wren        = (w_data_addr[31:28] != 4'b0) & w_data_req & o_data_we;
  assign o_peri_rden        = (w_data_addr[31:28] != 4'b0) & w_data_req & (o_data_we == 1'b0);
  assign o_peri_addr        = w_data_addr;
  assign o_peri_wdata       = o_data_wdata;
  assign o_peri_wstrb       = o_data_be;
  
  //* chose data from memory or peri;
  assign w_data_rdata       = (i_data_rvalid == 1'b1)? i_data_rdata: i_peri_rdata;
  assign w_data_rvalid      = i_data_rvalid | i_peri_ready;
  // assign w_data_gnt         = i_data_gnt | i_peri_gnt;
  // assign w_data_gnt         = 1'b1;
  assign w_data_gnt         = i_data_gnt;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* Noted that it is hard to allow accessing data/peri every clk as:
  //*   1) peri is slower than data, should resolve out of order problem,
  //*       i.e., responding returns at out of order;
  //*   2) peri is shared with 3 PEs, leading to no-pipelined design, should
  //*       reslove back pressure (mux) for data/peri; maybe & op is ok?

endmodule

