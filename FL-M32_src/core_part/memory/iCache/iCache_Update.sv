/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        Icache_Top.
 *  Description:        instr cache of timelyRV core.
 *  Last updated date:  2023.12.06.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2023 NUDT.
 *
 *  Noted:
 */


module iCache_Update
#(
    parameter ADDR_WIDTH        = 6,
    parameter TAG_WIDTH         = 8,
    parameter DATA_WIDTH        = 128,
    parameter N_WAY             = 4
)
(
  //* clk & reset;
  input   wire                            i_clk,
  input   wire                            i_rst_n,

  input   wire  [`NUM_PE-1:0]             i_cache_miss,
  input   wire  [`NUM_PE-1:0][31:0]       i_addr_miss,
  input   wire  [`NUM_PE-1:0][N_WAY-1:0]  i_vic_miss,
  output  wire  [`NUM_PE-1:0]             o_resp_miss,


  //* interface for reading SRAM by Icache;
  output  reg                             o_mm_rden,
  output  reg   [31:0]                    o_mm_addr,
  input   wire                            i_mm_gnt,
  input   wire  [DATA_WIDTH-1:0]          i_mm_rdata,
  input   wire                            i_mm_rvalid,

  output  wire  [N_WAY-1:0]               o_inst_tag_upd,
  output  wire  [ADDR_WIDTH-1:0]          o_inst_tag_addr_upd,
  output  wire  [TAG_WIDTH-1:0]           o_inst_tag_wdata_upd,
  output  wire  [DATA_WIDTH-1:0]          o_inst_data_wdata_upd
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  reg   [`NUM_PE-1:0]                 r_lock_gnt;
  wire  [`NUM_PE-1:0]                 wait_to_read_ns;
  reg   [`NUM_PE-1:0]                 r_wait_to_read;
  reg   [3:0][`NUM_PE-1:0]            r_tag_read;
  wire  [`NUM_PE-1:0]                 w_resp_miss_ns;
  wire  [N_WAY-1:0]                   w_hit;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  assign o_resp_miss            = r_tag_read[3];
  assign w_resp_miss_ns         = r_tag_read[2];
  assign wait_to_read_ns        = r_wait_to_read & ~r_tag_read[0] | i_cache_miss;

  integer i;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      o_mm_rden                 <= 'b0;
      o_mm_addr                 <= 'b0;
      r_lock_gnt                <= 4'hf;
      r_wait_to_read            <= 'b0;
      for(i=0; i<4; i=i+1)
        r_tag_read[i]           <= 'b0;
    end else begin
      o_mm_rden                 <= 1'b0;
      r_tag_read[0]             <= 'b0;
      for(i=1; i<4; i=i+1)
        r_tag_read[i]           <= r_tag_read[i-1];
      r_wait_to_read            <= wait_to_read_ns;
      if(i_mm_gnt == 1'b1)
        //* for 4 PEs;
        casez(wait_to_read_ns)
          4'b???1: begin
            o_mm_rden           <= 1'b1;
            o_mm_addr           <= i_addr_miss[0];
            r_tag_read[0][0]    <= 1'b1;
          end
          4'b??10: begin
            o_mm_rden           <= 1'b1;
            o_mm_addr           <= i_addr_miss[1];
            r_tag_read[0][1]    <= 1'b1;
          end
          4'b?100: begin
            o_mm_rden           <= 1'b1;
            o_mm_addr           <= i_addr_miss[2];
            r_tag_read[0][2]    <= 1'b1;
          end
          4'b1000: begin
            o_mm_rden           <= 1'b1;
            o_mm_addr           <= i_addr_miss[3];
            r_tag_read[0][3]    <= 1'b1;
          end
        default: begin
        end
      endcase
    end
  end

  //* for 4 PEs
  assign o_inst_tag_upd      =  (w_resp_miss_ns[0])? i_vic_miss[0]:
                                (w_resp_miss_ns[1])? i_vic_miss[1]:
                                (w_resp_miss_ns[2])? i_vic_miss[2]:
                                (w_resp_miss_ns[3])? i_vic_miss[3]: 'b0;
  assign o_inst_tag_addr_upd =  (w_resp_miss_ns[0])? i_addr_miss[0][2+:ADDR_WIDTH]:
                                (w_resp_miss_ns[1])? i_addr_miss[1][2+:ADDR_WIDTH]:
                                (w_resp_miss_ns[2])? i_addr_miss[2][2+:ADDR_WIDTH]:
                                (w_resp_miss_ns[3])? i_addr_miss[3][2+:ADDR_WIDTH]: 'b0;
  assign o_inst_tag_wdata_upd = (w_resp_miss_ns[0])? {1'b1,i_addr_miss[0][2+ADDR_WIDTH+:(TAG_WIDTH-1)]}:
                                (w_resp_miss_ns[1])? {1'b1,i_addr_miss[1][2+ADDR_WIDTH+:(TAG_WIDTH-1)]}:
                                (w_resp_miss_ns[2])? {1'b1,i_addr_miss[2][2+ADDR_WIDTH+:(TAG_WIDTH-1)]}:
                                (w_resp_miss_ns[3])? {1'b1,i_addr_miss[3][2+ADDR_WIDTH+:(TAG_WIDTH-1)]}: 'b0;
  assign o_inst_data_wdata_upd  = i_mm_rdata;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  // assert (w_hit == 4'b0000 || w_hit == 4'b0001 || w_hit == 4'b0010 || w_hit == 4'b0100 || w_hit == 4'b1000 )
  //   else
  //     $error("w_hit in iCache: %x", w_hit);

endmodule
