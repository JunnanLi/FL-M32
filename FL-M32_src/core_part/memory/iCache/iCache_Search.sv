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


module iCache_Search
#(
    parameter ADDR_WIDTH        = 6,
    parameter TAG_WIDTH         = 8,
    parameter DATA_WIDTH        = 128,
    parameter N_WAY             = 4,
    parameter ID_WAY            = 1
)
(
  //* clk & reset;
  input   wire                                i_clk,
  input   wire                                i_rst_n,

  //* interface for PEs (instr.);
  input   wire                                i_icache_req,
  input   wire  [31:0]                        i_icache_addr,
  output  reg   [31:0]                        o_icache_rdata,
  output  reg                                 o_icache_rvalid,
  output  wire                                o_icache_gnt,


  //* interface for reading SRAM by Icache;
  output  wire                                o_tag_rden,
  output  wire  [ADDR_WIDTH-1:0]              o_tag_addr,
  input   wire  [N_WAY-1:0][TAG_WIDTH-1:0]    i_tag_rdata,
  input   wire  [N_WAY-1:0][DATA_WIDTH-1:0]   i_data_rdata,

  //* interface for reading SRAM by Icache;
  output  reg                                 o_cache_miss,
  output  reg   [31:0]                        o_addr_miss,
  output  reg   [N_WAY-1:0]                   o_vic_miss,
  input   wire                                i_resp_miss
);
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  wire  [N_WAY-1:0]                   w_hit;
  wire  [15:0]                        w_temp_addr;
  wire                                w_cache_miss_ns;
  reg                                 r_lock_gnt;
  reg                                 r_icache_gnt_delay;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   Combine input signals
  //====================================================================//
  genvar idx;
  generate
    for (idx = 0; idx < N_WAY; idx=idx+1) begin : hit_cache
      assign w_hit[idx] = (i_tag_rdata[idx][TAG_WIDTH-1]==1'b1) &
                          (i_tag_rdata[idx][0+:(TAG_WIDTH-1)] == w_temp_addr[2+ADDR_WIDTH+:(TAG_WIDTH-1)]);
    end
  endgenerate

  integer i;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      o_icache_rdata          <= 'b0;
      o_icache_rvalid         <= 'b0;
      o_cache_miss            <= 'b0;
      o_addr_miss             <= 'b0;
      o_vic_miss              <= ID_WAY;
      r_lock_gnt              <= 1'b1;
      r_icache_gnt_delay      <= 1'b1;
    end else begin
      r_lock_gnt              <=  (i_resp_miss)? 1'b1: 
                                  (w_cache_miss_ns)? 1'b0: r_lock_gnt;
      r_icache_gnt_delay      <= o_icache_gnt;

      o_icache_rvalid         <= 1'b0;
      o_cache_miss            <= 1'b0;
      o_vic_miss              <= ID_WAY;
      if(o_tag_rden == 1'b1) begin
        case(w_hit)
          4'b0001: begin
            o_icache_rvalid           <= 1'b1;
            case(w_temp_addr[1:0])
              2'd0: o_icache_rdata    <= i_data_rdata[0][31:0];
              2'd1: o_icache_rdata    <= i_data_rdata[0][32*1+:32];
              2'd2: o_icache_rdata    <= i_data_rdata[0][32*2+:32];
              2'd3: o_icache_rdata    <= i_data_rdata[0][32*3+:32];
              default: o_icache_rdata <= i_data_rdata[0][31:0];
            endcase
          end
          4'b0010: begin
            o_icache_rvalid           <= 1'b1;
            case(w_temp_addr[1:0])
              2'd0: o_icache_rdata    <= i_data_rdata[1][31:0];
              2'd1: o_icache_rdata    <= i_data_rdata[1][32*1+:32];
              2'd2: o_icache_rdata    <= i_data_rdata[1][32*2+:32];
              2'd3: o_icache_rdata    <= i_data_rdata[1][32*3+:32];
              default: o_icache_rdata <= i_data_rdata[1][31:0];
            endcase
          end
          4'b0100: begin
            o_icache_rvalid           <= 1'b1;
            case(w_temp_addr[1:0])
              2'd0: o_icache_rdata    <= i_data_rdata[2][31:0];
              2'd1: o_icache_rdata    <= i_data_rdata[2][32*1+:32];
              2'd2: o_icache_rdata    <= i_data_rdata[2][32*2+:32];
              2'd3: o_icache_rdata    <= i_data_rdata[2][32*3+:32];
              default: o_icache_rdata <= i_data_rdata[2][31:0];
            endcase
          end
          4'b1000: begin
            o_icache_rvalid           <= 1'b1;
            case(w_temp_addr[1:0])
              2'd0: o_icache_rdata    <= i_data_rdata[3][31:0];
              2'd1: o_icache_rdata    <= i_data_rdata[3][32*1+:32];
              2'd2: o_icache_rdata    <= i_data_rdata[3][32*2+:32];
              2'd3: o_icache_rdata    <= i_data_rdata[3][32*3+:32];
              default: o_icache_rdata <= i_data_rdata[3][31:0];
            endcase
          end
          default: begin
            o_cache_miss              <= 1'b1;
            o_icache_rvalid           <= 1'b0;
            o_addr_miss               <= i_icache_addr;
          end
        endcase
      end
    end
  end

  assign w_cache_miss_ns  = o_tag_rden & (w_hit==4'b0);
  assign o_tag_rden       = i_icache_req & r_icache_gnt_delay | i_resp_miss;
  assign o_tag_addr       = i_icache_addr[2+:ADDR_WIDTH];
  assign w_temp_addr      = (i_resp_miss)? o_addr_miss[15:0]: i_icache_addr[15:0];
  assign o_icache_gnt     = ~w_cache_miss_ns & r_lock_gnt;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* assert
  initial begin
    assert (w_hit == 4'b0000 || w_hit == 4'b0001 || w_hit == 4'b0010 || w_hit == 4'b0100 || w_hit == 4'b1000 )
      else
        $error("w_hit in iCache: %x", w_hit);
  end

endmodule
