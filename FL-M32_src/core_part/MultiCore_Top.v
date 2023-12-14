/*
 *  Project:            timelyRV_v1.4.x -- a RISCV-32IMC SoC.
 *  Module name:        MultiCore_Top.
 *  Description:        top module of timelyRV core.
 *  Last updated date:  2022.10.14.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Noted:
 *    1) irq for cv32e40p: {irq_fast, 4'b0, irq_external, 3'b0,  
 *                            irq_timer, 3'b0, irq_software, 3'b0};
 */
 
  //====================================================================//
  //*   Connection Relationship                                         //
  //*                          <- instr/data_resp +------------------+  //
  //*         +-----------------------------------| +--------------+ |  //
  //*         |      instr/data_req ->            | | Cv32e40p_Top | |  //
  //*         |                                   | +--------------+ |  //
  //*  +------------+                             | +--------------+ |  //
  //*  | Memory_Top |-----------------------------| | Cv32e40p_Top | |  //
  //*  +------------+       instr/data_resp ->    | +--------------+ |  //
  //*      |                                      | +--------------+ |  //
  //*      | <>dDMA_req/resp                      | | Cv32e40p_Top | |  //
  //*      |                                      | +--------------+ |  //
  //*      |                                      | +--------------+ |  //
  //*  +------+                +------+           | | Cv32e40p_Top | |  //
  //*  | dDMA |----------------| AiPE |           | +--------------+ |  //
  //*  +------+     resp>      +------+           +------------------+  //
  //====================================================================//

 `timescale 1 ns / 1 ps

module MultiCore_Top(
  //* clk & rst_n
   input    wire                      i_clk
  ,input    wire                      i_rst_n
  //* interface for configuring memory
  ,input    wire                      i_conf_rden
  ,input    wire                      i_conf_wren
  ,input    wire  [            31:0]  i_conf_addr
  ,input    wire  [            31:0]  i_conf_wdata
  ,output   wire  [            31:0]  o_conf_rdata
  ,input    wire  [             3:0]  i_conf_en           //* for 4 PEs;
  //* interface for peripheral
  ,output   wire  [   `NUM_PE_T-1:0]  o_peri_rden
  ,output   wire  [   `NUM_PE_T-1:0]  o_peri_wren
  ,output   wire  [`NUM_PE_T*32-1:0]  o_peri_addr
  ,output   wire  [`NUM_PE_T*32-1:0]  o_peri_wdata
  ,output   wire  [ `NUM_PE_T*4-1:0]  o_peri_wstrb
  ,input    wire  [`NUM_PE_T*32-1:0]  i_peri_rdata
  ,input    wire  [   `NUM_PE_T-1:0]  i_peri_ready
  ,input    wire  [   `NUM_PE_T-1:0]  i_peri_gnt          //* allow next access;
  //* irq;
  ,input    wire  [  `NUM_PE*32-1:0]  i_irq_bitmap
  ,output   wire  [     `NUM_PE-1:0]  o_irq_ack
  ,output   wire  [   `NUM_PE*5-1:0]  o_irq_id
  //* DRA;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_rd            //* read req;
  ,output   wire  [  `NUM_PE*32-1:0]  o_reg_raddr         //* read addr;
  ,input    wire  [           511:0]  i_reg_rdata         //* read respond;
  ,input    wire  [     `NUM_PE-1:0]  i_reg_rvalid        //* read pkt's data;
  ,input    wire  [     `NUM_PE-1:0]  i_reg_rvalid_desp   //* read description;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_wr            //* write data req;
  ,output   wire  [     `NUM_PE-1:0]  o_reg_wr_desp       //* write description req;
  ,output   wire  [  `NUM_PE*32-1:0]  o_reg_waddr         //* write addr;
  ,output   wire  [ `NUM_PE*512-1:0]  o_reg_wdata         //* write data/description;
  ,input    wire  [  `NUM_PE*32-1:0]  i_status            //* cpu status;
  ,output   wire  [  `NUM_PE*32-1:0]  o_status            //* nic status;
  //* DMA;
  ,input    wire  [     `NUM_PE-1:0]  i_dma_rden
  ,input    wire  [     `NUM_PE-1:0]  i_dma_wren
  ,input    wire  [  `NUM_PE*32-1:0]  i_dma_addr
  ,input    wire  [  `NUM_PE*32-1:0]  i_dma_wdata
  ,output   wire  [  `NUM_PE*32-1:0]  o_dma_rdata
  ,output   wire  [     `NUM_PE-1:0]  o_dma_rvalid
  ,output   wire  [     `NUM_PE-1:0]  o_dma_gnt           //* allow next access;
  
  //* debug;
  ,output   wire  [            31:0]  d_pc_0
  ,output   wire  [            31:0]  d_pc_1
  ,output   wire  [            31:0]  d_pc_2
  ,input    wire  [   `NUM_PE*6-1:0]  d_i_reg_id_18b
  ,output   wire  [  `NUM_PE*32-1:0]  d_reg_value_96b
);

  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  //* 1) Mem flow: PE(w_instr_xxx_pe) <---> Insert_oneStage_Mem;
  //* to connect instr/data memory, similar to SRAM interface;
  wire  [`NUM_PE*32-1:0]    w_instr_addr;
  wire  [`NUM_PE*32-1:0]    w_instr_rdata;
  wire  [   `NUM_PE-1:0]    w_instr_req;
  wire  [   `NUM_PE-1:0]    w_instr_gnt,    w_instr_rvalid;
  wire  [`NUM_PE*32-1:0]    w_data_addr,    w_data_wdata;
  wire  [`NUM_PE*32-1:0]    w_data_rdata;
  wire  [   `NUM_PE-1:0]    w_data_we,      w_data_req; 
  wire  [   `NUM_PE-1:0]    w_data_gnt,     w_data_rvalid;
  wire  [ `NUM_PE*4-1:0]    w_data_be;
  // //* 1-2) Mem flow: Insert_oneStage_Mem(w_instr_xxx) <---> MEM;
  // wire  [`NUM_PE*32-1:0]    w_instr_addr_pe;
  // wire  [   `NUM_PE-1:0]    w_instr_req_pe;
  // wire  [`NUM_PE*32-1:0]    w_data_addr_pe, w_data_wdata_pe;
  // wire  [   `NUM_PE-1:0]    w_data_we_pe,   w_data_req_pe;
  // wire  [ `NUM_PE*4-1:0]    w_data_be_pe;
  
  //* 2) left for dDMA-related: AiPE <---> dDMA_Engine <---> MEM;
  
  //* 3) reset for PE;
  wire   [  `NUM_PE-1:0]    w_rst_n_pe;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  // //====================================================================//
  // //*   Insert_oneStage_Mem, maintain read/write request for judgement;
  // //====================================================================//
  // Insert_oneStage_Mem Insert_oneStage_Mem_inst(
  //   //* clk & rst_n;
  //   .i_clk                  (i_clk                        ),
  //   .i_rst_n                (i_rst_n                      ),
  //   //* interface with PE;
  //   .i_instr_addr           (w_instr_addr_pe              ),
  //   .i_instr_req            (w_instr_req_pe               ),
  //   .i_data_addr            (w_data_addr_pe               ),
  //   .i_data_wdata           (w_data_wdata_pe              ),
  //   .i_data_we              (w_data_we_pe                 ),
  //   .i_data_req             (w_data_req_pe                ),
  //   .i_data_be              (w_data_be_pe                 ),
  //   //* interface with MEM;
  //   .o_instr_addr           (w_instr_addr                 ),
  //   .o_instr_req            (w_instr_req                  ),
  //   .i_instr_gnt            (w_instr_gnt                  ),
  //   .o_data_addr            (w_data_addr                  ),
  //   .o_data_wdata           (w_data_wdata                 ),
  //   .o_data_we              (w_data_we                    ),
  //   .o_data_req             (w_data_req                   ),
  //   .o_data_be              (w_data_be                    ),
  //   .i_data_gnt             (w_data_gnt                   )
  // );
  // //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Cv32e40p_Top
  //====================================================================//
  genvar i_pe;
  generate
    for (i_pe = 0; i_pe < `NUM_PE; i_pe = i_pe + 1) begin: pe_cv32e40p
      `ifdef ASIC
        SyncResetForPE SyncResetForPE(
          .rstn             (i_rst_n            ),
          .clk              (i_clk              ),
          .conf_en          (i_conf_en[i_pe]    ),
          .start_en         (4'hf               ),
          .rstn_clk         (w_rst_n_pe[i_pe]   )
        );
      `endif
      
      //* top of timeRV core;
      Cv32e40p_Top Cv32e40p_Top(
        //* clk & rst_n;
        .i_clk              (i_clk                        ),
        `ifdef ASIC
          .i_rst_n          (w_rst_n_pe[i_pe]             ),
        `else
          .i_rst_n          (i_rst_n&~i_conf_en[i_pe]     ),
        `endif
        //* instr access interface;
        .o_instr_addr       (w_instr_addr[i_pe*32+:32] ),
        .o_instr_req        (w_instr_req[i_pe]         ),
        .i_instr_rdata      (w_instr_rdata[i_pe*32+:32]   ),
        .i_instr_gnt        (w_instr_gnt[i_pe]            ),
        .i_instr_rvalid     (w_instr_rvalid[i_pe]         ),
        //* data access interface;
        .o_data_addr        (w_data_addr[i_pe*32+:32]  ),
        .o_data_wdata       (w_data_wdata[i_pe*32+:32] ),
        .o_data_we          (w_data_we[i_pe]           ),
        .o_data_req         (w_data_req[i_pe]          ),
        .o_data_be          (w_data_be[i_pe*4+:4]      ),
        .i_data_rdata       (w_data_rdata[i_pe*32+:32]    ),
        .i_data_gnt         (w_data_gnt[i_pe]             ),
        .i_data_rvalid      (w_data_rvalid[i_pe]          ),
        //* peri access interface;
        .o_peri_rden        (o_peri_rden[i_pe]            ),
        .o_peri_wren        (o_peri_wren[i_pe]            ),
        .o_peri_addr        (o_peri_addr[i_pe*32+:32]     ),
        .o_peri_wdata       (o_peri_wdata[i_pe*32+:32]    ),
        .o_peri_wstrb       (o_peri_wstrb[i_pe*4+:4]      ),
        .i_peri_rdata       (i_peri_rdata[i_pe*32+:32]    ),
        .i_peri_ready       (i_peri_ready[i_pe]           ),
        .i_peri_gnt         (i_peri_gnt[i_pe]             ),
        //* irq interface;
        .i_irq_bitmap       (i_irq_bitmap[i_pe*32+:32]    ),
        .o_irq_ack          (o_irq_ack[i_pe]              ),
        .o_irq_id           (o_irq_id[i_pe*5+:5]          ),
        //* DRA interface;
        .o_reg_rd           (o_reg_rd[i_pe]               ),
        .o_reg_raddr        (o_reg_raddr[i_pe*32+:32]     ),
        .i_reg_rdata        (i_reg_rdata                  ),
        .i_reg_rvalid       (i_reg_rvalid[i_pe]           ),
        .i_reg_rvalid_desp  (i_reg_rvalid_desp[i_pe]      ),
        .o_reg_wr           (o_reg_wr[i_pe]               ),
        .o_reg_wr_desp      (o_reg_wr_desp[i_pe]          ),
        .o_reg_waddr        (o_reg_waddr[i_pe*32+:32]     ),
        .o_reg_wdata        (o_reg_wdata[i_pe*512+:512]   ),
        .i_status           (i_status[i_pe*32+:32]        ),
        .o_status           (o_status[i_pe*32+:32]        ),
        //* debug;
        .d_i_reg_id_6b      (d_i_reg_id_18b[i_pe*6+:6]    ),
        .d_reg_value_32b    (d_reg_value_96b[i_pe*32+:32] )
      );
    end
  endgenerate
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
 

  //====================================================================//
  //*   MEM Part
  //====================================================================//
  //* this handles read to RAM and memory mapped pseudo peripherals
  Memory_Top Memory_Top(
    //* clk & rst_n;
    .i_clk                  (i_clk                        ),
    .i_rst_n                (i_rst_n                      ),
    //* config interface;
    .i_conf_rden            (i_conf_rden                  ),
    .i_conf_wren            (i_conf_wren                  ),
    .i_conf_addr            (i_conf_addr                  ),
    .i_conf_wdata           (i_conf_wdata                 ),
    .o_conf_rdata           (o_conf_rdata                 ),
    .i_conf_en              (i_conf_en                    ),
    //* instr access interface;
    .i_instr_req            (w_instr_req                  ),
    .i_instr_addr           (w_instr_addr                 ),
    .o_instr_rdata          (w_instr_rdata                ),
    .o_instr_rvalid         (w_instr_rvalid               ),
    .o_instr_gnt            (w_instr_gnt                  ),
    //* data access interface;
    .i_data_req             (w_data_req                   ),
    .i_data_addr            (w_data_addr                  ),
    .i_data_we              (w_data_we                    ),
    .i_data_be              (w_data_be                    ),
    .i_data_wdata           (w_data_wdata                 ),
    .o_data_rdata           (w_data_rdata                 ),
    .o_data_rvalid          (w_data_rvalid                ),
    .o_data_gnt             (w_data_gnt                   ),
    //* dDMA;

    //* DMA interface;
    .i_dma_rden             (i_dma_rden                   ),
    .i_dma_wren             (i_dma_wren                   ),
    .i_dma_addr             (i_dma_addr                   ),
    .i_dma_wdata            (i_dma_wdata                  ),
    .o_dma_rdata            (o_dma_rdata                  ),
    .o_dma_rvalid           (o_dma_rvalid                 ),
    .o_dma_gnt              (o_dma_gnt                    )
  );
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  //====================================================================//
  //*   Debug Part
  //====================================================================//
  //* debug {instr_req, instr_addr}
  assign d_pc_0   = {w_instr_req[0], w_instr_addr[0*32+:31]};
  `ifdef PE1_EN
    assign d_pc_1 = {w_instr_req[1], w_instr_addr[1*32+:31]};
  `else 
    assign d_pc_1 = 33'b0;
  `endif
  `ifdef PE2_EN
    assign d_pc_2 = {w_instr_req[2], w_instr_addr[2*32+:31]};
  `else 
    assign d_pc_2 = 33'b0;
  `endif
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//


  reg [31:0]  cnt_clk;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
      cnt_clk   <= 32'b0;
    end
    else begin
      cnt_clk   <= 32'd1 + cnt_clk;
    end
  end

  integer out_file;
  initial begin
    out_file = $fopen("F:/share_with_ubuntu/inst_log_cmp.txt","w");
  end

  always @(posedge i_clk) begin
    if(w_instr_req[0] == 1'b1) begin
      $fwrite(out_file, "addr: %08x\n", w_instr_addr[31:0]);
    end
    if(cnt_clk == 32'hbd5d) begin
      $fclose(out_file);
    end
  end


endmodule

