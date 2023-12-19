// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Francesco Conti - f.conti@unibo.it                         //
//                                                                            //
// Additional contributions by:                                               //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Junnan Li        - lijunnan@nudt.edu.cn                    //
//                                                                            //
// Design Name:    RISC-V register file                                       //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Register file with 31x 32 bit wide registers. Register 0   //
//                 is fixed to 0. This register file is based on flip-flops.  //
//                 Also supports the fp-register file now if FPU=1            //
//                 If PULP_ZFINX is 1, floating point operations take values  //
//                 from the X register file                                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_register_file #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32,
    parameter FPU        = 0,
    parameter PULP_ZFINX = 0
) (
    // Clock and Reset
     input    logic                   clk
    ,input    logic                   rst_n

    ,input    logic                   scan_cg_en_i

    //Read port R1
    ,input    logic [ADDR_WIDTH-1:0]  raddr_a_i
    ,output   logic [DATA_WIDTH-1:0]  rdata_a_o

    //Read port R2
    ,input    logic [ADDR_WIDTH-1:0]  raddr_b_i
    ,output   logic [DATA_WIDTH-1:0]  rdata_b_o

    //Read port R3
    ,input    logic [ADDR_WIDTH-1:0]  raddr_c_i
    ,output   logic [DATA_WIDTH-1:0]  rdata_c_o

    // Write port W1
    ,input    logic [ADDR_WIDTH-1:0]  waddr_a_i
    ,input    logic [DATA_WIDTH-1:0]  wdata_a_i
    ,input    logic                   we_a_i

    // Write port W2
    ,input    logic [ADDR_WIDTH-1:0]  waddr_b_i
    ,input    logic [DATA_WIDTH-1:0]  wdata_b_i
    ,input    logic                   we_b_i

    //* for DRA
    ,output   logic                   reg_rd_o
    ,output   logic  [         31:0]  reg_raddr_o
    ,input    logic  [        511:0]  reg_rdata_i
    ,input    logic                   reg_rvalid_i
    ,input    logic                   reg_rvalid_desp_i
    ,output   logic                   reg_wr_o
    ,output   logic                   reg_wr_desp_o
    ,output   logic  [         31:0]  reg_waddr_o
    ,output   logic  [        511:0]  reg_wdata_o
    ,input    logic  [         31:0]  status_i   //* mem_rf2[31];
    ,output   logic  [         31:0]  status_o   //* {}
    ,input    logic  [          5:0]  d_i_reg_id_6b
    ,output   logic  [         31:0]  d_reg_value_32b
);

  //====================================================================//
  //*   localparam
  //====================================================================//
    //* defination of Regs, status, ctrl, addr, temp, desp, data;
    localparam STATUS_REG             = 31;
    localparam CTRL_REG               = 30;
    localparam RADDR_REG              = 29;
    localparam WADDR_REG              = 28;
    //* TEMP_REG [27,20]
    localparam DESP_REG_3             = 19;
    localparam DESP_REG_2             = 18;
    localparam DESP_REG_1             = 17;
    localparam DESP_REG_0             = 16;  
    //* description 
    //*   [127:112]: pkt_buffer_id, in 512b;
    //*   [111:96] : 8b outport + 8b inport;
    //*   [ 95:80] : flowid;
    //*   [ 79:64] : length;
    //*   [ 63:0]  : timestamp;
    //* DATA_REG [15,0]

    //* defination of CTRL_REG
    localparam TO_READ_DATA           = 31;
    localparam TO_WRITE_DATA          = 30;
    localparam TO_RECV_PKT            = 29;
    localparam TO_SEND_PKT            = 28;
    localparam TO_REPLACE_DATA        = 27;
    localparam PKT_VALID              = 0;

    //* defination of STATUS_REG
    localparam STATUS_READ_DATA       = 31;
    localparam STATUS_WRITE_DATA      = 30;
    localparam STATUS_RECV_PKT        = 29;
    localparam STATUS_SEND_PKT        = 28;
    localparam STATUS_REPLACE_DATA    = 27;

    //* number of integer registers
    localparam NUM_WORDS = 2 ** (ADDR_WIDTH - 1);
    //* number of floating point registers
    localparam NUM_FP_WORDS = 2 ** (ADDR_WIDTH - 1);
    // localparam NUM_TOT_WORDS = FPU ? 
    //   (PULP_ZFINX ? NUM_WORDS : NUM_WORDS + NUM_FP_WORDS) : NUM_WORDS;
    localparam NUM_TOT_WORDS = 64;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  //====================================================================//
  //*   internal reg/wire/param declarations
  //====================================================================//
  // integer register file
  logic [    NUM_WORDS-1:0][DATA_WIDTH-1:0] mem;
  // integer register file 2 & 3 (ping-pong registers)
  logic [    NUM_WORDS-1:0][DATA_WIDTH-1:0] mem_rf2;
  logic [             15:0][DATA_WIDTH-1:0] mem_rf3;
  logic [              3:0][DATA_WIDTH-1:0] mem_send;
  logic [             30:0][DATA_WIDTH-1:0] mem_recv;

  // fp register file
  // logic [ NUM_FP_WORDS-1:0][DATA_WIDTH-1:0] mem_fp;

  // masked write addresses
  logic [   ADDR_WIDTH-1:0]                 waddr_a;
  logic [   ADDR_WIDTH-1:0]                 waddr_b;

  // write enable signals for all registers
  logic [NUM_TOT_WORDS-1:0]                 we_a_dec;
  logic [NUM_TOT_WORDS-1:0]                 we_b_dec;
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //-----------------------------------------------------------------------------
  //-- READ : Read address decoder RAD
  //-----------------------------------------------------------------------------
  // generate
  //   if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_read
  //     assign rdata_a_o = raddr_a_i[5] ? mem_fp[raddr_a_i[4:0]] : mem[raddr_a_i[4:0]];
  //     assign rdata_b_o = raddr_b_i[5] ? mem_fp[raddr_b_i[4:0]] : mem[raddr_b_i[4:0]];
  //     assign rdata_c_o = raddr_c_i[5] ? mem_fp[raddr_c_i[4:0]] : mem[raddr_c_i[4:0]];
  //   end else begin : gen_mem_read
  //     assign rdata_a_o = mem[raddr_a_i[4:0]];
  //     assign rdata_b_o = mem[raddr_b_i[4:0]];
  //     assign rdata_c_o = mem[raddr_c_i[4:0]];
  //   end
  // endgenerate

  //* replace FPU register by pkt register (@Junnan Li)
  assign rdata_a_o = raddr_a_i[5] ? mem_rf2[raddr_a_i[4:0]] : mem[raddr_a_i[4:0]];
  assign rdata_b_o = raddr_b_i[5] ? mem_rf2[raddr_b_i[4:0]] : mem[raddr_b_i[4:0]];
  assign rdata_c_o = raddr_c_i[5] ? mem_rf2[raddr_c_i[4:0]] : mem[raddr_c_i[4:0]];

  //-----------------------------------------------------------------------------
  //-- WRITE : Write Address Decoder (WAD), combinatorial process
  //-----------------------------------------------------------------------------

  // Mask top bit of write address to disable fp regfile
  assign waddr_a = waddr_a_i;
  assign waddr_b = waddr_b_i;

  genvar gidx;
  generate
    for (gidx = 0; gidx < 64; gidx=gidx+1) begin : gen_we_decoder
      assign we_a_dec[gidx] = (waddr_a == gidx) ? we_a_i : 1'b0;
      assign we_b_dec[gidx] = (waddr_b == gidx) ? we_b_i : 1'b0;
    end
  endgenerate

  integer i, l;
  //-----------------------------------------------------------------------------
  //-- WRITE : Write operation
  //-----------------------------------------------------------------------------
  // R0 is nil
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      // R0 is nil
      mem[0] <= 32'b0;
    end else begin
      // R0 is nil
      mem[0] <= 32'b0;
    end
  end

  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk or negedge rst_n) begin : register_write_behavioral
    if (rst_n == 1'b0) begin
      for (i = 1; i < NUM_WORDS; i=i+1) begin
        mem[i] <= 32'b0;
      end
    end else begin
      for (i = 1; i < NUM_WORDS; i=i+1) begin
             if (we_b_dec[i] == 1'b1) mem[i] <= wdata_b_i;
        else if (we_a_dec[i] == 1'b1) mem[i] <= wdata_a_i;
        else                          mem[i] <= mem[i];
      end
    end
  end

  // if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_write
  //   // Floating point registers
  //   for (l = 0; l < NUM_FP_WORDS; l++) begin
  //     always_ff @(posedge clk, negedge rst_n) begin : fp_regs
  //       if (rst_n == 1'b0) mem_fp[l] <= '0;
  //       else if (we_b_dec[l+NUM_WORDS] == 1'b1) mem_fp[l] <= wdata_b_i;
  //       else if (we_a_dec[l+NUM_WORDS] == 1'b1) mem_fp[l] <= wdata_a_i;
  //     end
  //   end
  // end else begin : gen_no_mem_fp_write
  //   assign mem_fp = 'b0;
  // end

  //====================================================================//
  //*   update pkt registers
  //====================================================================//
  //* 1) update mem_rf2[30:0];
  always_ff @(posedge clk or negedge rst_n) begin : gen_rf2
    if (rst_n == 1'b0) begin
      for (l = 0; l < (NUM_WORDS-1); l=l+1) begin
        mem_rf2[l]        <= 32'b0;
      end
    end
    else if (mem_rf2[CTRL_REG][TO_REPLACE_DATA] == 1'b1) begin
      //* replace mem_rf2;
      for (l = 0; l < 16; l=l+1) begin
        mem_rf2[l]        <= mem_rf3[l];
      end
      mem_rf2[RADDR_REG]  <= mem_rf2[RADDR_REG] + 32'd1;
      mem_rf2[WADDR_REG]  <= mem_rf2[WADDR_REG] + 32'd1;
      mem_rf2[CTRL_REG]   <= 32'b0;
    end
    else if (mem_rf2[CTRL_REG][TO_RECV_PKT] == 1'b1) begin
      //* replace description;
      for (l = 0; l < 20; l=l+1) begin
        mem_rf2[l]        <= mem_recv[l];
      end
      mem_rf2[RADDR_REG]  <= mem_recv[RADDR_REG];
      mem_rf2[WADDR_REG]  <= mem_recv[WADDR_REG];
      mem_rf2[CTRL_REG]   <= mem_recv[CTRL_REG];
    end
    else if (mem_rf2[CTRL_REG][TO_SEND_PKT] == 1'b1) begin
      //* replace description;
      mem_rf2[CTRL_REG]   <= 32'b0;
    end
    else begin
      for (l = 0; l < 31; l=l+1) begin
             if (we_b_dec[l+NUM_WORDS] == 1'b1) mem_rf2[l] <= wdata_b_i;
        else if (we_a_dec[l+NUM_WORDS] == 1'b1) mem_rf2[l] <= wdata_a_i;
        else                                    mem_rf2[l] <= mem_rf2[l];
      end
    end
  end

  //* 2) assign mem_rf2[STATUS_REG];
  always_ff @(posedge clk) begin
    mem_rf2[STATUS_REG]   <= status_i;
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //====================================================================//
  //*   DRA: Direct Register Access
  //====================================================================//
  integer       i_pktReg;
  reg           cnt_wr, cnt_resp_rvalid;
  reg           pre_to_read, pre_to_write, pre_to_recv, pre_to_send;
  reg   [31:0]  base_raddr, base_waddr; //* TODO, used to read after 
  always_ff @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
      for(i_pktReg = 0; i_pktReg<31; i_pktReg=i_pktReg+1) begin
        mem_recv[i_pktReg]    <= 32'b0;
      end
      for(i_pktReg = 0; i_pktReg<16; i_pktReg=i_pktReg+1) begin
        mem_rf3[i_pktReg]     <= 32'b0;
      end
      for(i_pktReg = 0; i_pktReg<4; i_pktReg=i_pktReg+1) begin
        mem_send[i_pktReg]    <= 32'b0;
      end
      cnt_wr                  <= 1'b0;
      cnt_resp_rvalid         <= 1'b0;
      //* connect to nic;
      reg_rd_o                <= 1'b0;
      reg_raddr_o             <= 32'b0;
      reg_wr_o                <= 1'b0;
      reg_wr_desp_o           <= 1'b0;
      reg_waddr_o             <= 32'b0;
      reg_wdata_o             <= 512'b0;
      //* temp status;
      pre_to_read             <= 1'b0;
      pre_to_write            <= 1'b0;
      pre_to_recv             <= 1'b0;
      pre_to_send             <= 1'b0;
    end 
    else begin
      //* 1) update temp status;
      {pre_to_read, pre_to_write, pre_to_recv, pre_to_send}   <= mem_rf2[CTRL_REG][TO_READ_DATA:TO_SEND_PKT];
      
      //* 2-1) to read data, send reading request;
      reg_rd_o                <= 1'b0;
      if(mem_rf2[CTRL_REG][TO_READ_DATA] == 1'b1 && pre_to_read == 1'b0) begin
        reg_rd_o              <= 1'b1;
        reg_raddr_o           <= mem_rf2[RADDR_REG];
      end
      //* 2-2) to raad dat, get readed data (update mem_rf3);
      if(reg_rvalid_i == 1'b1) begin
        { mem_rf3[0], mem_rf3[1], mem_rf3[2], mem_rf3[3],
          mem_rf3[4], mem_rf3[5], mem_rf3[6], mem_rf3[7],
          mem_rf3[8], mem_rf3[9], mem_rf3[10],mem_rf3[11],
          mem_rf3[12],mem_rf3[13],mem_rf3[14],mem_rf3[15]} <= reg_rdata_i;
      end
      else begin
        for(i_pktReg = 0; i_pktReg<16; i_pktReg=i_pktReg+1) begin
          mem_rf3[i_pktReg]   <= mem_rf3[i_pktReg];
        end
      end

      //* 3) to write data & send pkt;
      reg_wr_o                <= 1'b0;
      reg_wr_desp_o           <= 1'b0;
      if((mem_rf2[CTRL_REG][TO_WRITE_DATA] == 1'b1 && pre_to_write == 1'b0) || 
          (mem_rf2[CTRL_REG][TO_SEND_PKT] == 1'b1 && pre_to_send == 1'b0) || 
          cnt_wr != 1'b0) 
      begin
        cnt_wr                <= (mem_rf2[CTRL_REG][TO_WRITE_DATA] == 1'b1)? 1'b0: ~cnt_wr;
        reg_wr_o              <= ~cnt_wr;
        reg_wr_desp_o         <= cnt_wr;
        reg_waddr_o           <= mem_rf2[WADDR_REG];
        //* restore description;
        for(i_pktReg = 0; i_pktReg<4; i_pktReg=i_pktReg+1) begin
          mem_send[i_pktReg]  <= (cnt_wr == 1'b0)? mem_rf2[16+i_pktReg]: mem_send[i_pktReg];
        end

        reg_wdata_o           <= (cnt_wr == 1'b0)? {mem_rf2[0],mem_rf2[1],mem_rf2[2],mem_rf2[3],
                                                    mem_rf2[4],mem_rf2[5],mem_rf2[6],mem_rf2[7],
                                                    mem_rf2[8],mem_rf2[9],mem_rf2[10],mem_rf2[11],
                                                    mem_rf2[12],mem_rf2[13],mem_rf2[14],mem_rf2[15]}:
                                            {384'b0,mem_send[0],mem_send[1],mem_send[2],mem_send[3]};
      end

      //* 4-1) to recv next pkt, get recved pkt (update mem_recv);
      //* currently, we recv automatically after processing current pkt;
      //* and replace mem_rf2 by recv pkt according to CPU's cmd;
      cnt_resp_rvalid         <= (reg_rvalid_desp_i == 1'd1)? ~cnt_resp_rvalid: 1'd0;
      if(reg_rvalid_desp_i == 1'b1) begin
        (*full_case, parallel_case*)
        case(cnt_resp_rvalid)
          1'd0: {mem_recv[0],mem_recv[1],mem_recv[2],mem_recv[3],
                  mem_recv[4],mem_recv[5],mem_recv[6],mem_recv[7],
                  mem_recv[8],mem_recv[9],mem_recv[10],mem_recv[11],
                  mem_recv[12],mem_recv[13],mem_recv[14],mem_recv[15]}  <= reg_rdata_i;
          1'd1: {mem_recv[16],mem_recv[17],mem_recv[18],mem_recv[19]}   <= reg_rdata_i[127:0];
        endcase
      end
      else begin
        for(i_pktReg = 0; i_pktReg<20; i_pktReg=i_pktReg+1) begin
          mem_recv[i_pktReg]  <= mem_recv[i_pktReg];
        end
      end

      for(i_pktReg = 20; i_pktReg<28; i_pktReg=i_pktReg+1) begin
        mem_recv[i_pktReg]    <= mem_recv[i_pktReg];
      end

      //* 4-2) set PKT_VALID, '1' means received pkt;
      mem_recv[CTRL_REG]      <= 32'b0;
      if(reg_rvalid_desp_i == 1'b1 && cnt_resp_rvalid == 1'd1) begin
        mem_recv[CTRL_REG][PKT_VALID] <= 1'b1;
      end
      else if(mem_rf2[CTRL_REG][TO_RECV_PKT] == 1'b1) begin
        mem_recv[CTRL_REG][PKT_VALID] <= 1'b0;
      end
      else begin
        mem_recv[CTRL_REG][PKT_VALID] <= mem_recv[CTRL_REG][PKT_VALID];
      end

      //* 4-3) set rd_addr & wr_addr;
      if(reg_rvalid_desp_i == 1'b1 && cnt_resp_rvalid == 1'd1) begin
        mem_recv[RADDR_REG]           <= {16'b0, 7'b0, reg_rdata_i[123-:4], 5'd1};
        mem_recv[WADDR_REG]           <= {16'b0, 7'b0, reg_rdata_i[123-:4], 5'd0};
      end
      else begin
        mem_recv[RADDR_REG]           <= mem_recv[RADDR_REG];
        mem_recv[WADDR_REG]           <= mem_recv[WADDR_REG];
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //* set status_o;
  assign status_o = {31'b0,mem_recv[CTRL_REG][PKT_VALID]};

  //====================================================================//
  //*   debug
  //====================================================================//
  always_ff @(posedge clk or negedge rst_n) begin : debug_reg
    if(~rst_n) begin
      d_reg_value_32b             <= 32'b0;
    end else begin
      (*full_case, parallel_case *)
      case(d_i_reg_id_6b)
        //* common register;
        6'd0: d_reg_value_32b     <= mem[0];
        6'd1: d_reg_value_32b     <= mem[1];
        6'd2: d_reg_value_32b     <= mem[2];
        6'd3: d_reg_value_32b     <= mem[3];
        6'd4: d_reg_value_32b     <= mem[4];
        6'd5: d_reg_value_32b     <= mem[5];
        6'd6: d_reg_value_32b     <= mem[6];
        6'd7: d_reg_value_32b     <= mem[7];
        6'd8: d_reg_value_32b     <= mem[8];
        6'd9: d_reg_value_32b     <= mem[9];
        6'd10: d_reg_value_32b    <= mem[10];
        6'd11: d_reg_value_32b    <= mem[11];
        6'd12: d_reg_value_32b    <= mem[12];
        6'd13: d_reg_value_32b    <= mem[13];
        6'd14: d_reg_value_32b    <= mem[14];
        6'd15: d_reg_value_32b    <= mem[15];
        6'd16: d_reg_value_32b    <= mem[16];
        6'd17: d_reg_value_32b    <= mem[17];
        6'd18: d_reg_value_32b    <= mem[18];
        6'd19: d_reg_value_32b    <= mem[19];
        6'd20: d_reg_value_32b    <= mem[20];
        6'd21: d_reg_value_32b    <= mem[21];
        6'd22: d_reg_value_32b    <= mem[22];
        6'd23: d_reg_value_32b    <= mem[23];
        6'd24: d_reg_value_32b    <= mem[24];
        6'd25: d_reg_value_32b    <= mem[25];
        6'd26: d_reg_value_32b    <= mem[26];
        6'd27: d_reg_value_32b    <= mem[27];
        6'd28: d_reg_value_32b    <= mem[28];
        6'd29: d_reg_value_32b    <= mem[29];
        6'd30: d_reg_value_32b    <= mem[30];
        6'd31: d_reg_value_32b    <= mem[31];
        //* pkt register;
        6'd32: d_reg_value_32b    <= mem_rf2[0];
        6'd33: d_reg_value_32b    <= mem_rf2[1];
        6'd34: d_reg_value_32b    <= mem_rf2[2];
        6'd35: d_reg_value_32b    <= mem_rf2[3];
        6'd36: d_reg_value_32b    <= mem_rf2[4];
        6'd37: d_reg_value_32b    <= mem_rf2[5];
        6'd38: d_reg_value_32b    <= mem_rf2[6];
        6'd39: d_reg_value_32b    <= mem_rf2[7];
        6'd40: d_reg_value_32b    <= mem_rf2[8];
        6'd41: d_reg_value_32b    <= mem_rf2[9];
        6'd42: d_reg_value_32b    <= mem_rf2[10];
        6'd43: d_reg_value_32b    <= mem_rf2[11];
        6'd44: d_reg_value_32b    <= mem_rf2[12];
        6'd45: d_reg_value_32b    <= mem_rf2[13];
        6'd46: d_reg_value_32b    <= mem_rf2[14];
        6'd47: d_reg_value_32b    <= mem_rf2[15];
        6'd48: d_reg_value_32b    <= mem_rf2[16];
        6'd49: d_reg_value_32b    <= mem_rf2[17];
        6'd50: d_reg_value_32b    <= mem_rf2[18];
        6'd51: d_reg_value_32b    <= mem_rf2[19];
        6'd52: d_reg_value_32b    <= mem_rf2[20];
        6'd53: d_reg_value_32b    <= mem_rf2[21];
        6'd54: d_reg_value_32b    <= mem_rf2[22];
        6'd55: d_reg_value_32b    <= mem_rf2[23];
        6'd56: d_reg_value_32b    <= mem_rf2[24];
        6'd57: d_reg_value_32b    <= mem_rf2[25];
        6'd58: d_reg_value_32b    <= mem_rf2[26];
        6'd59: d_reg_value_32b    <= mem_rf2[27];
        6'd60: d_reg_value_32b    <= mem_rf2[28];
        6'd61: d_reg_value_32b    <= mem_rf2[29];
        6'd62: d_reg_value_32b    <= mem_rf2[30];
        6'd63: d_reg_value_32b    <= mem_rf2[31];
      endcase
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
