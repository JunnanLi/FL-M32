/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        CSRAM_TOP.
 *  Description:        top module of CSRAM.
 *  Last updated date:  2022.06.17.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) Do not support pipelined reading/writing;
 */

//* NUM_PE is 3, NUM_PE_T is 4, AIPE_ID is 3; (defined in global_head.v) 

module CSRAM_TOP (
  //* clk & rst_n;
  input   wire                        i_clk,
  input   wire                        i_rst_n,
  //* sram access interface;
  input   wire  [`NUM_PE_T*32-1:0]    i_addr_32b,
  input   wire  [   `NUM_PE_T-1:0]    i_wren,
  input   wire  [   `NUM_PE_T-1:0]    i_rden,
  input   wire  [`NUM_PE_T*32-1:0]    i_din_32b,
  output  wire  [`NUM_PE_T*32-1:0]    o_dout_32b,
  output  wire  [   `NUM_PE_T-1:0]    o_dout_32b_valid,
  output  wire  [   `NUM_PE_T-1:0]    o_interrupt,
  //* debug;
  output  reg   [             3:0]    d_cnt_pe0_wr_4b,
  output  reg   [             3:0]    d_cnt_pe1_wr_4b,
  output  reg   [             3:0]    d_cnt_pe2_wr_4b,
  output  reg   [             3:0]    d_cnt_pe0_rd_4b,
  output  reg   [             3:0]    d_cnt_pe1_rd_4b,
  output  reg   [             3:0]    d_cnt_pe2_rd_4b
);
  assign                              o_interrupt = {`NUM_PE_T{1'b0}};

  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* sram signals;
  reg                                 r_wren_csram_PE;
  reg           [            31:0]    r_addr_csram_PE;
  reg           [            31:0]    r_din_csram_PE;
  wire          [            31:0]    w_dout_csram_PE;
  reg           [     `NUM_PE-1:0]    r_peID[2:0];    //* used to output o_dout_32b_valid of PEs;
  reg           [             1:0]    r_ready_aiPE;   //* used to output o_dout_32b_valid of aiPE;
  reg           [     `NUM_PE-1:0]    r_wr_req, r_rd_req;  //* used to maintain wr req;
  //* output;
  assign        o_dout_32b_valid          = {r_ready_aiPE[1],r_peID[2]};
  assign        o_dout_32b[0+:`NUM_PE*32] = {`NUM_PE{w_dout_csram_PE}};
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  maintain wr/rd req 
  //==============================================================//
  reg   [31:0]  r_addr_req[`NUM_PE-1:0];
  reg   [31:0]  r_wdata_req[`NUM_PE-1:0];
  reg   [2:0]   r_turn_pe;
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      for(i_pe = 0; i_pe <`NUM_PE; i_pe=i_pe+1) begin
        r_wr_req[i_pe]                <= 1'b0;
        r_rd_req[i_pe]                <= 1'b0;
        r_addr_req[i_pe]              <= 32'b0;
        r_wdata_req[i_pe]             <= 32'b0;
      end
      r_turn_pe                       <= 3'b001;
    end else begin
      r_turn_pe                       <= {r_turn_pe[1:0], r_turn_pe[2]};
      for(i_pe = 0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        if(r_turn_pe[i_pe] == 1'b1) begin
          if(i_wren[i_pe] == 1'b1 || i_rden[i_pe] == 1'b1) begin
            r_wr_req[i_pe]            <= i_wren[i_pe];
            r_rd_req[i_pe]            <= i_rden[i_pe];
            r_addr_req[i_pe]          <= i_addr_32b[i_pe*32+:32];
            r_wdata_req[i_pe]         <= i_din_32b[i_pe*32+:32];
          end
          else begin
            r_wr_req[i_pe]            <= 1'b0;
            r_rd_req[i_pe]            <= 1'b0;
            r_addr_req[i_pe]          <= 32'b0;
            r_wdata_req[i_pe]         <= 32'b0;
          end
        end
        else begin
          r_wr_req[i_pe]              <= (i_wren[i_pe] == 1'b1)? 1'b1: r_wr_req[i_pe];
          r_rd_req[i_pe]              <= (i_rden[i_pe] == 1'b1)? 1'b1: r_rd_req[i_pe];
          r_addr_req[i_pe]            <= (i_wren[i_pe] == 1'b1 || i_rden[i_pe] == 1'b1)? i_addr_32b[i_pe*32+:32]: r_addr_req[i_pe];
          r_wdata_req[i_pe]           <= (i_wren[i_pe] == 1'b1)? i_din_32b[i_pe*32+:32]: r_wdata_req[i_pe];
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  MUX to select PE    
  //==============================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_wren_csram_PE                 <= 1'b0;
      r_addr_csram_PE                 <= 32'b0;
      r_din_csram_PE                  <= 32'b0;
      for(i_pe=0; i_pe<3; i_pe=i_pe+1) begin
        r_peID[i_pe]                  <= {`NUM_PE{1'b0}};
      end
      //* debug;
      d_cnt_pe0_rd_4b                 <= 4'b0;
      d_cnt_pe1_rd_4b                 <= 4'b0;
      d_cnt_pe2_rd_4b                 <= 4'b0;
      d_cnt_pe0_wr_4b                 <= 4'b0;
      d_cnt_pe1_wr_4b                 <= 4'b0;
      d_cnt_pe2_wr_4b                 <= 4'b0;
    end 
    else begin
      r_wren_csram_PE                 <= 1'b0;
      //* TODO, current version is implemented for NUM_PE = 3;
      case((r_wr_req|r_rd_req)&r_turn_pe)
        3'b001: begin
          r_wren_csram_PE             <= r_wr_req[0];
          r_addr_csram_PE             <= r_addr_req[0];
          r_din_csram_PE              <= r_wdata_req[0];
          r_peID[0]                   <= 3'b001;
          d_cnt_pe0_wr_4b             <= (r_wr_req[0] == 1'b1)? d_cnt_pe0_wr_4b + 4'd1: d_cnt_pe0_wr_4b;
          d_cnt_pe0_rd_4b             <= (r_rd_req[0] == 1'b1)? d_cnt_pe0_rd_4b + 4'd1: d_cnt_pe0_rd_4b;
        end
        3'b010: begin
          r_wren_csram_PE             <= r_wr_req[1];
          r_addr_csram_PE             <= r_addr_req[1];
          r_din_csram_PE              <= r_wdata_req[1];
          r_peID[0]                   <= 3'b010;
          d_cnt_pe1_wr_4b             <= (r_wr_req[1] == 1'b1)? d_cnt_pe1_wr_4b + 4'd1: d_cnt_pe1_wr_4b;
          d_cnt_pe1_rd_4b             <= (r_rd_req[1] == 1'b1)? d_cnt_pe1_rd_4b + 4'd1: d_cnt_pe1_rd_4b;
        end
        3'b100: begin
          r_wren_csram_PE             <= r_wr_req[2];
          r_addr_csram_PE             <= r_addr_req[2];
          r_din_csram_PE              <= r_wdata_req[2];
          r_peID[0]                   <= 3'b100;
          d_cnt_pe2_wr_4b             <= (r_wr_req[2] == 1'b1)? d_cnt_pe2_wr_4b + 4'd1: d_cnt_pe2_wr_4b;
          d_cnt_pe2_rd_4b             <= (r_rd_req[2] == 1'b1)? d_cnt_pe2_rd_4b + 4'd1: d_cnt_pe2_rd_4b;
        end
        default: begin
          r_peID[0]                   <= 3'b0;
        end
      endcase

      //* delay two clocks;
      {r_peID[2],r_peID[1]}           <= {r_peID[1],r_peID[0]};
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  output  o_dout_32b_valid of aiPE    
  //==============================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      r_ready_aiPE                    <= 2'b0;
    end 
    else begin
      `ifdef AIPE_EN
        r_ready_aiPE                  <= {r_ready_aiPE[0], i_wren[`AIPE_ID]|i_rden[`AIPE_ID]};
      `else
        r_ready_aiPE                  <= 2'b0;
      `endif
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* dual port sram;
  `ifdef XILINX_FIFO_RAM
    ram_32b_64 ram_csram (
      .clka       (i_clk                        ),
      .wea        (r_wren_csram_PE              ),
      .addra      (r_addr_csram_PE[7:2]         ),
      .dina       (r_din_csram_PE               ),
      .douta      (w_dout_csram_PE              ),
      `ifdef AIPE_EN
        .clkb     (i_clk                        ),
        .web      (i_wren[`AIPE_ID]             ),
        .addrb    (i_addr_32b[`AIPE_ID*32+:6]   ),
        .dinb     (i_din_32b[`AIPE_ID*32+:32]   ),
        .doutb    (o_dout_32b[`AIPE_ID*32+:32]  )
      `else
        .clkb     (i_clk                        ),
        .web      (1'b0                         ),
        .addrb    (32'b0                        ),
        .dinb     (32'b0                        ),
        .doutb    (                             )
      `endif
    );
  `else
    dualportsram64x32 ram_csram(
      .aclr       (~i_rst_n                     ), //* asynchronous reset
      .address_a  (r_addr_csram_PE[7:2]         ), //* port A: address
      .address_b  (i_addr_32b[`AIPE_ID*32+:6]   ), //* port B: address
      .clock      (i_clk                        ), //* port A & B: clock
      .data_a     (r_din_csram_PE               ), //* port A: data input
      .data_b     (i_din_32b[`AIPE_ID*32+:32]   ), //* port B: data input
      .rden_a     (!r_wren_csram_PE             ), //* port A: read enable
      .rden_b     (!i_wren[`AIPE_ID]            ), //* port B: read enable
      .wren_a     (r_wren_csram_PE              ), //* port A: write enable
      .wren_b     (i_wren[`AIPE_ID]             ), //* port B: write enable
      .q_a        (w_dout_csram_PE              ), //* port A: data output
      .q_b        (o_dout_32b[`AIPE_ID*32+:32]  )  //* port B: data output
      );
  `endif

endmodule
