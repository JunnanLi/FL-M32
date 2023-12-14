/*
 *  Project:            timelyRV_v1.x -- a RISCV-32IMC SoC.
 *  Module name:        CSR_TOP.
 *  Description:        top module of CSR.
 *  Last updated date:  2022.06.17.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Noted:
 *    1) support pipelined reading/writing;
 */

module CSR_TOP (
  //* clk & reset;
  input   wire                      i_clk,
  input   wire                      i_rst_n,
  //* peri interface;
  input   wire  [`NUM_PE*32-1:0]    i_addr_32b,
  input   wire  [   `NUM_PE-1:0]    i_wren,
  input   wire  [   `NUM_PE-1:0]    i_rden,
  input   wire  [`NUM_PE*32-1:0]    i_din_32b,
  output  reg   [`NUM_PE*32-1:0]    o_dout_32b,
  output  reg   [   `NUM_PE-1:0]    o_dout_32b_valid,
  //* interrupt;
  output  wire  [   `NUM_PE-1:0]    o_interrupt,          
  output  reg   [   `NUM_PE-1:0]    o_time_int,   //* for 3 PE;
  //* system time;
  input   wire                      i_update_valid,
  input   wire  [          64:0]    i_update_system_time,
  output  wire  [          63:0]    o_system_time,
  output  reg                       o_second_pulse,
  //* debug;
  output  reg   [           3:0]    d_cnt_pe0_wr_4b,
  output  reg   [           3:0]    d_cnt_pe1_wr_4b,
  output  reg   [           3:0]    d_cnt_pe2_wr_4b,
  output  reg   [           3:0]    d_cnt_pe0_rd_4b,
  output  reg   [           3:0]    d_cnt_pe1_rd_4b,
  output  reg   [           3:0]    d_cnt_pe2_rd_4b,
  output  wire  [          31:0]    d_pe0_instr_offsetAddr_32b,
  output  wire  [          31:0]    d_pe1_instr_offsetAddr_32b,
  output  wire  [          31:0]    d_pe2_instr_offsetAddr_32b,
  output  wire  [          31:0]    d_pe0_data_offsetAddr_32b,
  output  wire  [          31:0]    d_pe1_data_offsetAddr_32b,
  output  wire  [          31:0]    d_pe2_data_offsetAddr_32b,
  output  wire  [           2:0]    d_guard_3b,
  output  reg   [           3:0]    d_cnt_pe0_int_4b,
  output  reg   [           3:0]    d_cnt_pe1_int_4b,
  output  reg   [           3:0]    d_cnt_pe2_int_4b,
  output  wire  [           3:0]    d_start_en_4b
);


  //==============================================================//
  //   internal reg/wire/param declarations
  //==============================================================//
  //* r_cntTime_cmp, r_cntTime_int are timers for irq;
  //*   r_cntTime_cmp is configured by program;
  //*   r_cntTime_int is used to decrease from r_cntTime_cmp;
  reg           [31:0]      r_cntTime_cmp[`NUM_PE-1:0], r_cntTime_int[`NUM_PE-1:0];
  //* r_sysTime_s is system time in second;
  //* r_sysTime_ns is system time in nano-second;
  //* r_toRead_sysTime_s is current system time in second when reading;
  //* r_toUpdate_sysTime_ns is system time in nano-second to update;
  //* r_toUpdate_sysTime_s is system time in second to update;
  //* r_ns_per_clk is related with PE's clock frequency, i.e., 20ns for 50MHz;
  reg           [31:0]      r_sysTime_ns, r_sysTime_s, r_toRead_sysTime_s[`NUM_PE-1:0];
  reg           [31:0]      r_toUpdate_sysTime_ns, r_toUpdate_sysTime_s;
  reg           [31:0]      r_toUpdate_sysTime_ns_cmcu, r_toUpdate_sysTime_s_cmcu;
  reg                       r_toUpdate_time, r_toUpdate_time_cmcu; 
  reg           [7:0]       r_ns_per_clk;

  //* r_guard should be '0x1234' when writing CSR;
  reg           [15:0]      r_guard[`NUM_PE-1:0];
  reg           [`NUM_PE-1:0] r_wr_req, r_wr_finish;  //* used to maintain wr req;
  wire          [`NUM_PE-1:0] w_guard_en;
  reg           [31:0]      sw_version;           //* e.g., 0x20220721
  reg           [31:0]      r_shared_reg[7:0];
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  genvar j_pe;
  assign o_interrupt        = {`NUM_PE{1'b0}};
  assign o_system_time      = {r_sysTime_s, r_sysTime_ns};

  //* guard;
    assign w_guard_en[0]    = (r_guard[0] == 16'h1234);
  `ifdef PE1_EN
    assign w_guard_en[1]    = (r_guard[1] == 16'h1234);
  `endif
  `ifdef PE2_EN
    assign w_guard_en[2]    = (r_guard[2] == 16'h1234);
  `endif
  `ifdef PE3_EN
    assign w_guard_en[3]    = (r_guard[2] == 16'h1234);
  `endif

  //==============================================================//
  //  time interrupt    
  //==============================================================//
  integer i_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_time_int                    <= {`NUM_PE{1'b0}};
      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        //* r_cntTime_int for time_irq (in 20ns);
        r_cntTime_int[i_pe]         <= 32'b0;
      end
    end 
    else begin
      o_time_int                    <= {`NUM_PE{1'b0}};
      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        r_cntTime_int[i_pe]         <= r_cntTime_int[i_pe] - 32'd1;
        if(|r_cntTime_int[i_pe] == 1'b0) begin
          r_cntTime_int[i_pe]       <= r_cntTime_cmp[i_pe];
          o_time_int[i_pe]          <= |(r_cntTime_cmp[i_pe]);
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  maintain wr/rd req   
  //==============================================================//
  reg   [31:0]  r_addr_req[`NUM_PE-1:0];
  reg   [31:0]  r_wdata_req[`NUM_PE-1:0];
  reg   [`NUM_PE-1:0]   r_turn_pe;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      for(i_pe = 0; i_pe <`NUM_PE; i_pe=i_pe+1) begin
        r_wr_req[i_pe]                <= 1'b0;
        r_addr_req[i_pe]              <= 32'b0;
        r_wdata_req[i_pe]             <= 32'b0;
      end
      r_turn_pe[0]                    <= 1'b1;
      `ifdef PE1_EN
        r_turn_pe[`NUM_PE-1:1]        <= {(`NUM_PE-1){1'b0}};
      `endif
    end else begin
      `ifndef PE1_EN
        r_turn_pe                     <= 1'b1;
      `else
        r_turn_pe                     <= {r_turn_pe[`NUM_PE-2:0], r_turn_pe[`NUM_PE-1]};
      `endif
      
      for(i_pe = 0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        if(r_turn_pe[i_pe] == 1'b1) begin
          if(i_wren[i_pe] == 1'b1) begin
            r_wr_req[i_pe]            <= 1'b1;
            r_addr_req[i_pe]          <= i_addr_32b[i_pe*32+:32];
            r_wdata_req[i_pe]         <= i_din_32b[i_pe*32+:32];
          end
          else begin
            r_wr_req[i_pe]            <= 1'b0;
            r_addr_req[i_pe]          <= 32'b0;
            r_wdata_req[i_pe]         <= 32'b0;
          end
        end
        else begin
          r_wr_req[i_pe]              <= (i_wren[i_pe] == 1'b1)? 1'b1: r_wr_req[i_pe];
          r_addr_req[i_pe]            <= (i_wren[i_pe] == 1'b1)? i_addr_32b[i_pe*32+:32]: r_addr_req[i_pe];
          r_wdata_req[i_pe]           <= (i_wren[i_pe] == 1'b1)? i_din_32b[i_pe*32+:32] : r_wdata_req[i_pe];
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

  //==============================================================//
  //  Config CSR
  //==============================================================//
  integer i;
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      //* peri interface;
      o_dout_32b_valid              <= {`NUM_PE{1'b0}};
      o_dout_32b                    <= {`NUM_PE{32'b0}};
      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1) begin
        //* r_guart should be 0x1234;
        r_guard[i_pe]               <= 16'b0;
        //* record sysTime_s;
        r_toRead_sysTime_s[i_pe]    <= 32'b0;
        //* cmp timer;
        r_cntTime_cmp[i_pe]         <= 32'b0;
      end
      //* shared registers;
      for(i_pe=0; i_pe<8; i_pe=i_pe+1) begin
        r_shared_reg[i_pe]          <= 32'b0;
      end
      //* system_time
      r_sysTime_ns                  <= 32'b0;
      r_sysTime_s                   <= 32'b0;
      r_toUpdate_sysTime_ns         <= 32'b0;
      r_toUpdate_sysTime_s          <= 32'b0;
      r_toUpdate_time               <= 1'b0;
      r_toUpdate_sysTime_ns_cmcu    <= 32'b0;
      r_toUpdate_sysTime_s_cmcu     <= 32'b0;
      r_toUpdate_time_cmcu          <= 1'b0;
      sw_version                    <= 32'h20220000; //* e.g., 0x20220721
      r_ns_per_clk                  <= 8'd20;

      //* wr-related;
      r_wr_finish                   <= {`NUM_PE{1'b0}};

      //* debug;
      d_cnt_pe0_wr_4b               <= 4'b0;
      d_cnt_pe1_wr_4b               <= 4'b0;
      d_cnt_pe2_wr_4b               <= 4'b0;
      d_cnt_pe0_rd_4b               <= 4'b0;
      d_cnt_pe1_rd_4b               <= 4'b0;
      d_cnt_pe2_rd_4b               <= 4'b0;
    end 
    else begin
      o_dout_32b_valid              <= r_wr_finish | i_rden;
      r_toUpdate_time               <= 1'b0;
      //* to update system_time by cmcu;
      r_toUpdate_time_cmcu          <= i_update_valid;
      r_toUpdate_sysTime_ns_cmcu    <= (i_update_system_time[64] == 1'b0)? 
                                      (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - 
                                        i_update_system_time[31:0]):
                                      (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + 
                                        i_update_system_time[31:0]);
      r_toUpdate_sysTime_s_cmcu     <= (i_update_system_time[64] == 1'b0)? 
                                      (r_sysTime_s - i_update_system_time[63:32]):
                                      (r_sysTime_s + i_update_system_time[63:32]);

      //* write instr/r_data_offsetAddr;
        
        //* writing;
          if(r_wr_req[0] & r_turn_pe[0]) begin
            r_guard[0]                    <= 16'b0;
            d_cnt_pe0_wr_4b               <= d_cnt_pe0_wr_4b + 4'd1;
            r_wr_finish                   <= {`NUM_PE{1'b0}};
            r_wr_finish[0]                <= 1'b1;
            case(r_addr_req[0][6:2])
              5'd0: begin   end
              5'd1: r_guard[0]            <= r_wdata_req[0][15:0];
              5'd2: sw_version            <= (w_guard_en[0] == 1'b1)? r_wdata_req[0]: sw_version;
              5'd9: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s - r_wdata_req[0];
                    r_toUpdate_time       <= (w_guard_en[0] == 1'b1)? 1'b1: 1'b0;
              end
              5'd10: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s + r_wdata_req[0];
                    r_toUpdate_time       <= (w_guard_en[0] == 1'b1)? 1'b1: 1'b0;
              end
              5'd11: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - r_wdata_req[0]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[0] == 1'b1)? 1'b1: 1'b0;
              end
              5'd12: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + r_wdata_req[0]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[0] == 1'b1)? 1'b1: 1'b0;
              end
              5'd14:r_cntTime_cmp[0]      <= r_wdata_req[0];
              5'd16:r_shared_reg[0]       <= r_wdata_req[0];
              5'd17:r_shared_reg[1]       <= r_wdata_req[0];
              5'd18:r_shared_reg[2]       <= r_wdata_req[0];
              5'd19:r_shared_reg[3]       <= r_wdata_req[0];
              5'd20:r_shared_reg[4]       <= r_wdata_req[0];
              5'd21:r_shared_reg[5]       <= r_wdata_req[0];
              5'd22:r_shared_reg[6]       <= r_wdata_req[0];
              5'd23:r_shared_reg[7]       <= r_wdata_req[0];
              5'd31:r_ns_per_clk          <= (w_guard_en[0] == 1'b1)? r_wdata_req[0][7:0]: r_ns_per_clk;
              default: begin
              end
            endcase
          end
        `ifdef PE1_EN
          else if(r_wr_req[1] & r_turn_pe[1]) begin
            r_guard[1]                    <= 16'b0;
            r_wr_finish                   <= {`NUM_PE{1'b0}};
            r_wr_finish[1]                <= 1'b1;
            d_cnt_pe1_wr_4b               <= d_cnt_pe1_wr_4b + 4'd1;
            case(r_addr_req[1][6:2])
              5'd0: begin
              end
              5'd1: r_guard[1]            <= r_wdata_req[1][15:0];
              5'd2: sw_version            <= (w_guard_en[1] == 1'b1)? r_wdata_req[1]: sw_version;
              5'd9: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s - r_wdata_req[1];
                    r_toUpdate_time       <= (w_guard_en[1] == 1'b1)? 1'b1: 1'b0;
              end
              5'd10: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s + r_wdata_req[1];
                    r_toUpdate_time       <= (w_guard_en[1] == 1'b1)? 1'b1: 1'b0;
              end
              5'd11: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - r_wdata_req[1]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[1] == 1'b1)? 1'b1: 1'b0;
              end
              5'd12: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + r_wdata_req[1]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[1] == 1'b1)? 1'b1: 1'b0;
              end
              5'd14:r_cntTime_cmp[1]      <= r_wdata_req[1];
              5'd16:r_shared_reg[0]       <= r_wdata_req[1];
              5'd17:r_shared_reg[1]       <= r_wdata_req[1];
              5'd18:r_shared_reg[2]       <= r_wdata_req[1];
              5'd19:r_shared_reg[3]       <= r_wdata_req[1];
              5'd20:r_shared_reg[4]       <= r_wdata_req[1];
              5'd21:r_shared_reg[5]       <= r_wdata_req[1];
              5'd22:r_shared_reg[6]       <= r_wdata_req[1];
              5'd23:r_shared_reg[7]       <= r_wdata_req[1];
              5'd31:r_ns_per_clk          <= (w_guard_en[1] == 1'b1)? r_wdata_req[1][7:0]: r_ns_per_clk;
              default: begin
              end
            endcase
          end
        `endif
        `ifdef PE2_EN
          else if(r_wr_req[2] & r_turn_pe[2]) begin
            r_guard[2]                    <= 16'b0;
            r_wr_finish                   <= {`NUM_PE{1'b0}};
            r_wr_finish[2]                <= 1'b1;
            d_cnt_pe2_wr_4b               <= d_cnt_pe2_wr_4b + 4'd1;
            case(r_addr_req[2][6:2])
              5'd0: begin
              end
              5'd1: r_guard[2]            <= r_wdata_req[2][15:0];
              5'd2: sw_version            <= (w_guard_en[2] == 1'b1)? r_wdata_req[2]: sw_version;
              5'd9: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s - r_wdata_req[2];
                    r_toUpdate_time       <= (w_guard_en[2] == 1'b1)? 1'b1: 1'b0;
              end
              5'd10: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s + r_wdata_req[2];
                    r_toUpdate_time       <= (w_guard_en[2] == 1'b1)? 1'b1: 1'b0;
              end
              5'd11: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - r_wdata_req[2]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[2] == 1'b1)? 1'b1: 1'b0;
              end
              5'd12: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + r_wdata_req[2]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[2] == 1'b1)? 1'b1: 1'b0;
              end
              5'd14:r_cntTime_cmp[2]      <= r_wdata_req[2];
              5'd16:r_shared_reg[0]       <= r_wdata_req[2];
              5'd17:r_shared_reg[1]       <= r_wdata_req[2];
              5'd18:r_shared_reg[2]       <= r_wdata_req[2];
              5'd19:r_shared_reg[3]       <= r_wdata_req[2];
              5'd20:r_shared_reg[4]       <= r_wdata_req[2];
              5'd21:r_shared_reg[5]       <= r_wdata_req[2];
              5'd22:r_shared_reg[6]       <= r_wdata_req[2];
              5'd23:r_shared_reg[7]       <= r_wdata_req[2];
              5'd31:r_ns_per_clk          <= (w_guard_en[2] == 1'b1)? r_wdata_req[2][7:0]: r_ns_per_clk;
              default: begin
              end
            endcase
          end
        `endif
        `ifdef PE3_EN
          else if(r_wr_req[3] & r_turn_pe[3]) begin
            r_guard[3]                    <= 16'b0;
            r_wr_finish                   <= {`NUM_PE{1'b0}};
            r_wr_finish[3]                <= 1'b1;
            d_cnt_pe2_wr_4b               <= d_cnt_pe2_wr_4b + 4'd1;
            case(r_addr_req[3][6:2])
              5'd0: begin
              end
              5'd1: r_guard[3]            <= r_wdata_req[3][15:0];
              5'd2: sw_version            <= (w_guard_en[3] == 1'b1)? r_wdata_req[3]: sw_version;
              5'd9: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s - r_wdata_req[3];
                    r_toUpdate_time       <= (w_guard_en[3] == 1'b1)? 1'b1: 1'b0;
              end
              5'd10: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0});
                    r_toUpdate_sysTime_s  <= r_sysTime_s + r_wdata_req[3];
                    r_toUpdate_time       <= (w_guard_en[3] == 1'b1)? 1'b1: 1'b0;
              end
              5'd11: begin 
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} - r_wdata_req[2]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[3] == 1'b1)? 1'b1: 1'b0;
              end
              5'd12: begin
                    r_toUpdate_sysTime_ns <= (r_sysTime_ns + {23'b0,r_ns_per_clk[7:0],1'b0} + r_wdata_req[2]);
                    r_toUpdate_sysTime_s  <= r_sysTime_s;
                    r_toUpdate_time       <= (w_guard_en[3] == 1'b1)? 1'b1: 1'b0;
              end
              5'd14:r_cntTime_cmp[3]      <= r_wdata_req[3];
              5'd16:r_shared_reg[0]       <= r_wdata_req[3];
              5'd17:r_shared_reg[1]       <= r_wdata_req[3];
              5'd18:r_shared_reg[2]       <= r_wdata_req[3];
              5'd19:r_shared_reg[3]       <= r_wdata_req[3];
              5'd20:r_shared_reg[4]       <= r_wdata_req[3];
              5'd21:r_shared_reg[5]       <= r_wdata_req[3];
              5'd22:r_shared_reg[6]       <= r_wdata_req[3];
              5'd23:r_shared_reg[7]       <= r_wdata_req[3];
              5'd31:r_ns_per_clk          <= (w_guard_en[3] == 1'b1)? r_wdata_req[3][7:0]: r_ns_per_clk;
              default: begin
              end
            endcase
          end
        `endif
          else begin
            r_wr_finish                   <= {`NUM_PE{1'b0}};
            sw_version                    <= sw_version;
            r_toUpdate_sysTime_ns         <= r_toUpdate_sysTime_ns;
            r_toUpdate_sysTime_s          <= r_toUpdate_sysTime_s;
            r_toUpdate_time               <= 1'b0;
            for(i=0; i<8; i=i+1) begin
              r_shared_reg[i]             <= r_shared_reg[i];
            end
          end

      for(i_pe=0; i_pe<`NUM_PE; i_pe=i_pe+1) begin

        //* to read;
        if(i_rden[i_pe] == 1'b1) begin
          (*full_case, parallel_case*)
          case(i_addr_32b[(i_pe*32+2)+:5])
            5'd0: o_dout_32b[i_pe*32+:32]   <= 32'b0;
            5'd1: o_dout_32b[i_pe*32+:32]   <= r_guard[i_pe];
            5'd2: o_dout_32b[i_pe*32+:32]   <= sw_version;
            5'd3: o_dout_32b[i_pe*32+:32]   <= `HW_VERSION;
            5'd4: o_dout_32b[i_pe*32+:32]   <= (i_pe == 0)? 32'd0 :
                                                (i_pe == 1)? 32'd1 : 
                                                (i_pe == 2)? 32'd2 : 32'd3;
            5'd12:begin 
                  o_dout_32b[i_pe*32+:32]   <= r_sysTime_ns;
                  r_toRead_sysTime_s[i_pe]  <= r_sysTime_s;
            end
            5'd13:o_dout_32b[i_pe*32+:32]   <= r_toRead_sysTime_s[i_pe];
            5'd14:o_dout_32b[i_pe*32+:32]   <= r_cntTime_cmp[i_pe];
            5'd15:o_dout_32b[i_pe*32+:32]   <= 32'b0;
            5'd16:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[0];
            5'd17:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[1];
            5'd18:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[2];
            5'd19:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[3];
            5'd20:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[4];
            5'd21:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[5];
            5'd22:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[6];
            5'd23:o_dout_32b[i_pe*32+:32]   <= r_shared_reg[7];
            default: begin
              o_dout_32b[i_pe*32+:32]       <= 32'b0;
            end
          endcase
        end
      end
      d_cnt_pe0_rd_4b               <= (i_rden[0] == 1'b1)? d_cnt_pe0_rd_4b + 4'd1: d_cnt_pe0_rd_4b;
      `ifdef PE1_EN
        d_cnt_pe1_rd_4b             <= (i_rden[1] == 1'b1)? d_cnt_pe1_rd_4b + 4'd1: d_cnt_pe1_rd_4b;
      `else 
        d_cnt_pe1_rd_4b             <= 4'b0;
      `endif
      `ifdef PE2_EN
        d_cnt_pe2_rd_4b             <= (i_rden[2] == 1'b1)? d_cnt_pe2_rd_4b + 4'd1: d_cnt_pe2_rd_4b;
      `else 
        d_cnt_pe2_rd_4b             <= 4'b0;
      `endif

      //* update system_time;
      if(r_toUpdate_time == 1'b1) begin
        if(r_toUpdate_sysTime_ns[31] == 1'b1) begin //* minus offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns + 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s - 32'd1;
        end
        else if(r_toUpdate_sysTime_ns >= 32'd1_000_000_000) begin
          //* add offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns - 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s + 32'd1;
        end
        else begin
          r_sysTime_ns              <= r_toUpdate_sysTime_ns;
          r_sysTime_s               <= r_toUpdate_sysTime_s;
        end
      end
      else if(r_toUpdate_time_cmcu == 1'b1) begin
        if(r_toUpdate_sysTime_ns_cmcu[31] == 1'b1) begin //* minus offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns_cmcu + 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s_cmcu - 32'd1;
        end
        else if(r_toUpdate_sysTime_ns_cmcu >= 32'd1_000_000_000) begin
          //* add offset & overflow;
          r_sysTime_ns              <= r_toUpdate_sysTime_ns_cmcu - 32'd1_000_000_000;
          r_sysTime_s               <= r_toUpdate_sysTime_s_cmcu + 32'd1;
        end
        else begin
          r_sysTime_ns              <= r_toUpdate_sysTime_ns_cmcu;
          r_sysTime_s               <= r_toUpdate_sysTime_s_cmcu;
        end
      end
      else begin
        if(r_sysTime_ns >= 32'd1_000_000_000) begin
          r_sysTime_ns              <= {24'b0,r_ns_per_clk[7:0]};
          r_sysTime_s               <= r_sysTime_s + 32'd1;
        end
        else begin
          r_sysTime_ns              <= r_sysTime_ns + {24'b0,r_ns_per_clk[7:0]};
        end
      end
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  //==============================================================//
  //  second pulse
  //==============================================================//
  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      o_second_pulse <= 1'b0;
    end else begin
      o_second_pulse <= (r_sysTime_ns >= 32'd1_000_000_000);
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//
  
  //==============================================================//
  //  debugs
  //==============================================================//
  assign  d_guard_3b      = w_guard_en;
  assign  d_start_en_4b   = 'b0;
  assign  d_pe0_instr_offsetAddr_32b  = 'b0;
  assign  d_pe1_instr_offsetAddr_32b  = 'b0;
  assign  d_pe2_instr_offsetAddr_32b  = 'b0;
  assign  d_pe0_data_offsetAddr_32b   = 'b0;
  assign  d_pe1_data_offsetAddr_32b   = 'b0;
  assign  d_pe2_data_offsetAddr_32b   = 'b0;

  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      d_cnt_pe0_int_4b            <= 4'b0;
      d_cnt_pe1_int_4b            <= 4'b0;
      d_cnt_pe2_int_4b            <= 4'b0;
    end else begin
      d_cnt_pe0_int_4b            <= (o_time_int[0] == 1'b1)? 4'b1 + d_cnt_pe0_int_4b:d_cnt_pe0_int_4b;
      d_cnt_pe1_int_4b            <= (o_time_int[1] == 1'b1)? 4'b1 + d_cnt_pe1_int_4b:d_cnt_pe1_int_4b;
      d_cnt_pe2_int_4b            <= (o_time_int[2] == 1'b1)? 4'b1 + d_cnt_pe2_int_4b:d_cnt_pe2_int_4b;
    end
  end
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//

endmodule
