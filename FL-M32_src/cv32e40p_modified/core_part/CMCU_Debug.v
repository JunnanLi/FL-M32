 /*
 *  picoSoC_hardware -- SoC Hardware for RISCV-32I core.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2022 NUDT.
 *
 *  Data: 2021.12.03
 *  Description: This module is used to debug PE_ARRAY.
 */

`timescale 1 ns / 1 ps

module CMCU_Debug(
  //* clk & rst_n
   input                    i_clk
  ,input                    i_rst_n
  //* localbus interface;
  ,input  wire              i_cs            //* active low
  ,input  wire              i_wr_rd         //* 0:read 1:write
  ,input  wire  [19:0]      i_address
  ,input  wire  [31:0]      i_data_in
  ,output reg               o_ack_n
  ,output reg   [31:0]      o_data_out
  
  //* debug signals;
  //* dDMA;
  ,input  wire              d_dDMA_tag_start_dDMA_1b
  ,input  wire              d_dDMA_tag_resp_dDMA_1b 
  ,input  wire  [31:0]      d_dDMA_addr_RAM_32b         
  ,input  wire  [15:0]      d_dDMA_len_RAM_16b           
  ,input  wire  [31:0]      d_dDMA_addr_RAM_AIPE_32b
  ,input  wire  [15:0]      d_dDMA_len_RAM_AIPE_16b 
  ,input  wire              d_dDMA_dir_1b           
  ,input  wire  [3:0]       d_dDMA_cnt_pe0_rd_4b    
  ,input  wire  [3:0]       d_dDMA_cnt_pe0_wr_4b
  ,input  wire  [3:0]       d_dDMA_cnt_pe1_rd_4b
  ,input  wire  [3:0]       d_dDMA_cnt_pe1_wr_4b
  ,input  wire  [3:0]       d_dDMA_cnt_pe2_rd_4b
  ,input  wire  [3:0]       d_dDMA_cnt_pe2_wr_4b
  ,input  wire  [3:0]       d_dDMA_state_dDMA_4b
  ,input  wire  [3:0]       d_dDMA_cnt_int_4b   
  //* csr;
  ,input  wire  [3:0]       d_csr_cnt_pe0_wr_4b
  ,input  wire  [3:0]       d_csr_cnt_pe1_wr_4b
  ,input  wire  [3:0]       d_csr_cnt_pe2_wr_4b
  ,input  wire  [3:0]       d_csr_cnt_pe0_rd_4b
  ,input  wire  [3:0]       d_csr_cnt_pe1_rd_4b
  ,input  wire  [3:0]       d_csr_cnt_pe2_rd_4b
  ,input  wire  [31:0]      d_csr_pe0_instr_offsetAddr_32b
  ,input  wire  [31:0]      d_csr_pe1_instr_offsetAddr_32b
  ,input  wire  [31:0]      d_csr_pe2_instr_offsetAddr_32b
  ,input  wire  [31:0]      d_csr_pe0_data_offsetAddr_32b 
  ,input  wire  [31:0]      d_csr_pe1_data_offsetAddr_32b 
  ,input  wire  [31:0]      d_csr_pe2_data_offsetAddr_32b 
  ,input  wire  [2:0]       d_csr_guard_3b      
  ,input  wire  [3:0]       d_csr_cnt_pe0_int_4b
  ,input  wire  [3:0]       d_csr_cnt_pe1_int_4b
  ,input  wire  [3:0]       d_csr_cnt_pe2_int_4b
  ,input  wire  [3:0]       d_csr_start_en_4b   
  //* gpio;
  ,input  wire              d_gpio_en_1b        
  ,input  wire  [15:0]      d_gpio_data_ctrl_16b
  ,input  wire  [15:0]      d_gpio_bm_int_16b   
  ,input  wire  [15:0]      d_gpio_bm_clear_16b 
  ,input  wire  [15:0]      d_gpio_pos_neg_16b  
  ,input  wire  [15:0]      d_gpio_dir_16b      
  ,input  wire  [15:0]      d_gpio_recvData_16b 
  ,input  wire  [15:0]      d_gpio_sendData_16b 
  ,input  wire  [3:0]       d_gpio_cnt_pe0_wr_4b
  ,input  wire  [3:0]       d_gpio_cnt_pe1_wr_4b
  ,input  wire  [3:0]       d_gpio_cnt_pe2_wr_4b
  ,input  wire  [3:0]       d_gpio_cnt_pe0_rd_4b
  ,input  wire  [3:0]       d_gpio_cnt_pe1_rd_4b
  ,input  wire  [3:0]       d_gpio_cnt_pe2_rd_4b
  ,input  wire  [3:0]       d_gpio_cnt_int_4b   
  //* csram;
  ,input  wire  [3:0]       d_csram_cnt_pe0_wr_4b
  ,input  wire  [3:0]       d_csram_cnt_pe1_wr_4b
  ,input  wire  [3:0]       d_csram_cnt_pe2_wr_4b
  ,input  wire  [3:0]       d_csram_cnt_pe0_rd_4b
  ,input  wire  [3:0]       d_csram_cnt_pe1_rd_4b
  ,input  wire  [3:0]       d_csram_cnt_pe2_rd_4b
  //* spi;
  ,input  wire  [3:0]       d_spi_state_read_4b
  ,input  wire  [3:0]       d_spi_state_spi_4b 
  ,input  wire  [3:0]       d_spi_state_resp_4b
  ,input  wire  [3:0]       d_spi_cnt_pe0_rd_4b
  ,input  wire  [3:0]       d_spi_cnt_pe1_rd_4b
  ,input  wire  [3:0]       d_spi_cnt_pe2_rd_4b
  ,input  wire  [3:0]       d_spi_cnt_pe0_wr_4b
  ,input  wire  [3:0]       d_spi_cnt_pe1_wr_4b
  ,input  wire  [3:0]       d_spi_cnt_pe2_wr_4b
  ,input  wire  [0:0]       d_spi_empty_spi_1b 
  ,input  wire  [6:0]       d_spi_usedw_spi_7b 
  //* uart;
  ,input  wire  [26:0]      d_uart_usedw_rx_27b
  ,input  wire  [35:0]      d_uart_usedw_tx_36b
  ,input  wire  [11:0]      d_uart_cnt_rd_12b  
  ,input  wire  [11:0]      d_uart_cnt_wr_12b  
  //* ready * irq;
  ,input  wire  [3:0]       d_periTop_peri_ready_4b
  ,input  wire  [8:0]       d_periTop_pe0_int_9b   
  ,input  wire  [8:0]       d_periTop_pe1_int_9b   
  ,input  wire  [8:0]       d_periTop_pe2_int_9b   

  //=============== Pkt_Proc ===================//
  //* Pkt_Distribute;
  ,input  wire  [3:0]       d_AsynRev_inc_pkt_4b 
  ,input  wire  [3:0]       d_PktMUX_state_mux_4b   
  ,input  wire              d_PktMUX_inc_dra_pkt_1b 
  ,input  wire              d_PktMUX_inc_dma_pkt_1b
  ,input  wire              d_PktMUX_inc_conf_pkt_1b 
  ,input  wire  [6:0]       d_PktMUX_usedw_pktDMA_7b
  ,input  wire  [6:0]       d_PktMUX_usedw_pktDRA_7b
  ,input  wire  [6:0]       d_PktMUX_usedw_conf_7b
  //* dma;
  ,input  wire  [2:0]       d_dmaDist_inc_pkt_3b   
  ,input  wire              d_dmaDist_state_dist_1b
  ,input  wire  [3:0]       d_dmaOut_state_out_4b
  ,input  wire  [2:0]       d_dma_alf_dma_3b      
  ,input  wire  [2:0]       d_dma_empty_dmaWR_3b  
  ,input  wire  [29:0]      d_dma_usedw_dmaWR_30b 
  ,input  wire  [2:0]       d_dma_empty_pBufWR_3b 
  ,input  wire  [2:0]       d_dma_empty_pBufRD_3b 
  ,input  wire  [29:0]      d_dma_usedw_pBufRD_30b
  ,input  wire  [2:0]       d_dma_empty_int_3b    
  ,input  wire  [2:0]       d_dma_empty_length_3b 
  ,input  wire  [2:0]       d_dma_empty_low16b_3b 
  ,input  wire  [2:0]       d_dma_empty_high16b_3b
  //* DRA;
  ,input  wire             d_dra_empty_pktRecv_1b 
  ,input  wire  [    2:0]  d_dra_empty_despRecv_3b
  ,input  wire  [    2:0]  d_dra_empty_despSend_3b
  ,input  wire  [    2:0]  d_dra_empty_writeReq_3b
  ,input  wire  [    9:0]  d_dra_usedw_pktRecv_10b

  //=============== Multi_core ===================//
  ,input  wire  [   31:0]   d_pc_0
  ,input  wire  [   31:0]   d_pc_1
  ,input  wire  [   31:0]   d_pc_2
  ,input  wire  [   31:0]   d_pe0_reg_value_32b
  ,input  wire  [   31:0]   d_pe1_reg_value_32b
  ,input  wire  [   31:0]   d_pe2_reg_value_32b
  ,output reg   [    5:0]   d_o_pe0_reg_id_6b
  ,output reg   [    5:0]   d_o_pe1_reg_id_6b
  ,output reg   [    5:0]   d_o_pe2_reg_id_6b
);

//======================= internal reg/wire/param declarations =//
/** state_conf is used to configure (read or write) itcm and dtcm
* stat_out is used to output "print" in the program running on CPU
*/
reg [3:0] state_conf, state_out;
parameter IDLE_S          = 4'd0,
          WAIT_DATA_0_S   = 4'd1,
          WAIT_DATA_1_S   = 4'd2,
          RESP_ACK_S      = 4'd3,
          WAIT_END_S      = 4'd4;
//* pre_finish_loading_prog record i_finish_loading_prog;
reg                       r_finish_loading_prog;
//==============================================================//


  //======================= counters    ========================//
  //* cnt;
  integer i;
  reg   [31:0]    cnt_AsynRev_pkt[3:0]; //* 0 is total, 1 is dma, 2 is dra, 3 is conf;
  reg   [31:0]    cnt_PktMUX_dra_pkt, cnt_PktMUX_dma_pkt, cnt_PktMUX_conf_pkt;
  reg   [31:0]    cnt_dmaDist_pkt[2:0]; //* each PE;

  always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
      for(i=0; i<4; i=i+1) begin
        cnt_AsynRev_pkt[i]      <= 32'b0;
      end
      cnt_PktMUX_dra_pkt        <= 32'b0;
      cnt_PktMUX_dma_pkt        <= 32'b0;
      for(i=0; i<3; i=i+1) begin
        cnt_dmaDist_pkt[i]      <= 32'b0;
      end
    end 
    else begin
      for(i=0; i<4; i=i+1) begin
        cnt_AsynRev_pkt[i]      <= (d_AsynRev_inc_pkt_4b[i] == 1'b1)? (32'd1 + cnt_AsynRev_pkt[i]) : cnt_AsynRev_pkt[i];
      end
      cnt_PktMUX_dra_pkt        <= (d_PktMUX_inc_dra_pkt_1b == 1'b1)? (32'd1 + cnt_PktMUX_dra_pkt) : cnt_PktMUX_dra_pkt;
      cnt_PktMUX_dma_pkt        <= (d_PktMUX_inc_dma_pkt_1b == 1'b1)? (32'd1 + cnt_PktMUX_dma_pkt) : cnt_PktMUX_dma_pkt;
      cnt_PktMUX_conf_pkt       <= (d_PktMUX_inc_conf_pkt_1b== 1'b1)? (32'd1 + cnt_PktMUX_conf_pkt): cnt_PktMUX_conf_pkt;
      for(i=0; i<3; i=i+1) begin
        cnt_dmaDist_pkt[i]      <= (d_dmaDist_inc_pkt_3b[i] == 1'b1)? (32'd1 + cnt_dmaDist_pkt[i]) : cnt_dmaDist_pkt[i];
      end
    end
  end
  //============================================================//


//======================= parser pkt and return debug signals ==//
always @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    // reset
    o_ack_n                 <= 1'b1;
    o_data_out              <= 32'b0;
    //* debug addr;
    d_o_pe0_reg_id_6b       <= 6'b0;
    d_o_pe1_reg_id_6b       <= 6'b0;
    d_o_pe2_reg_id_6b       <= 6'b0;
    //* state;
    state_conf              <= IDLE_S;
  end
  else begin
    case(state_conf)
      IDLE_S: begin
        if(i_cs == 1'b0) begin
          state_conf  <= RESP_ACK_S;
          case(i_address[19:16])
            4'd0: begin
              //* dDMA;
              case(i_address[2:0])
                3'd0:     o_data_out        <= {20'b0,3'b0,d_dDMA_tag_start_dDMA_1b,
                                                3'b0,d_dDMA_tag_resp_dDMA_1b,
                                                3'b0,d_dDMA_dir_1b};
                3'd1:     o_data_out        <= d_dDMA_addr_RAM_32b;
                3'd2:     o_data_out        <= d_dDMA_addr_RAM_AIPE_32b;
                3'd3:     o_data_out        <= {d_dDMA_len_RAM_16b,d_dDMA_len_RAM_AIPE_16b};
                3'd4:     o_data_out        <= {d_dDMA_cnt_pe0_rd_4b,d_dDMA_cnt_pe0_wr_4b,
                                                d_dDMA_cnt_pe1_rd_4b,d_dDMA_cnt_pe1_wr_4b,
                                                d_dDMA_cnt_pe2_rd_4b,d_dDMA_cnt_pe2_wr_4b,
                                                d_dDMA_state_dDMA_4b,d_dDMA_cnt_int_4b};
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd1: begin
              //* CSR;
              case(i_address[2:0])
                3'd0:     o_data_out        <= d_csr_pe0_instr_offsetAddr_32b;
                3'd1:     o_data_out        <= d_csr_pe1_instr_offsetAddr_32b;
                3'd2:     o_data_out        <= d_csr_pe2_instr_offsetAddr_32b;
                3'd3:     o_data_out        <= d_csr_pe0_data_offsetAddr_32b;
                3'd4:     o_data_out        <= d_csr_pe1_data_offsetAddr_32b;
                3'd5:     o_data_out        <= d_csr_pe2_data_offsetAddr_32b;
                3'd6:     o_data_out        <= {8'b0, d_csr_cnt_pe0_rd_4b,d_csr_cnt_pe0_wr_4b,
                                                d_csr_cnt_pe1_rd_4b,d_csr_cnt_pe1_wr_4b,
                                                d_csr_cnt_pe2_rd_4b,d_csr_cnt_pe2_wr_4b};
                3'd7:     o_data_out        <= {8'b0,1'b0, d_csr_guard_3b,d_csr_start_en_4b,
                                                d_csr_cnt_pe0_int_4b,d_csr_cnt_pe1_int_4b,
                                                d_csr_cnt_pe2_int_4b,4'b0};
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd2: begin
              //* GPIO;
              case(i_address[2:0])
                3'd0:     o_data_out        <= {3'b0,d_gpio_en_1b, d_gpio_cnt_int_4b, 
                                                d_gpio_cnt_pe0_rd_4b, d_gpio_cnt_pe0_wr_4b,
                                                d_gpio_cnt_pe1_rd_4b, d_gpio_cnt_pe1_wr_4b,
                                                d_gpio_cnt_pe2_rd_4b, d_gpio_cnt_pe2_wr_4b};
                3'd1:     o_data_out        <= {d_gpio_data_ctrl_16b,d_gpio_pos_neg_16b};
                3'd2:     o_data_out        <= {d_gpio_bm_int_16b,d_gpio_bm_clear_16b};
                3'd3:     o_data_out        <= {16'b0,d_gpio_dir_16b};
                3'd4:     o_data_out        <= {d_gpio_recvData_16b,d_gpio_sendData_16b};
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd3: begin
              //* CSRAM;
              o_data_out        <= {8'b0,d_csram_cnt_pe0_rd_4b,d_csram_cnt_pe0_wr_4b,
                                         d_csram_cnt_pe1_rd_4b,d_csram_cnt_pe1_wr_4b,
                                         d_csram_cnt_pe2_rd_4b,d_csram_cnt_pe2_wr_4b};
            end
            4'd4: begin
              //* SPI;
              case(i_address[2:0])
                3'd0:     o_data_out        <= {4'b0,d_spi_state_read_4b,
                                                d_spi_state_spi_4b, d_spi_state_resp_4b,
                                                d_spi_cnt_pe0_rd_4b, d_spi_cnt_pe0_wr_4b,
                                                d_spi_cnt_pe1_rd_4b, d_spi_cnt_pe1_wr_4b};
                3'd1:     o_data_out        <= {16'b0,
                                                d_spi_cnt_pe2_rd_4b, d_spi_cnt_pe2_wr_4b,
                                                d_spi_empty_spi_1b, d_spi_usedw_spi_7b};
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd5: begin
              //* UART;
              case(i_address[2:0])
                3'd1:     o_data_out        <= {7'b0,d_uart_usedw_rx_27b[8:0],
                                                7'b0,d_uart_usedw_rx_27b[17:9]};
                3'd2:     o_data_out        <= {4'b0,d_uart_usedw_tx_36b[11:0],
                                                7'b0,d_uart_usedw_rx_27b[26:18]};
                3'd3:     o_data_out        <= {4'b0,d_uart_usedw_tx_36b[35:24],
                                                4'b0,d_uart_usedw_tx_36b[23:12]};
                3'd4:     o_data_out        <= {8'b0,d_uart_cnt_rd_12b,d_uart_cnt_wr_12b};
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd6: begin
              //* ready * irq;
              o_data_out        <= {1'b0,d_periTop_peri_ready_4b,
                                                d_periTop_pe0_int_9b,
                                                d_periTop_pe1_int_9b,
                                                d_periTop_pe2_int_9b};
            end
            //* pkt Proc
            4'd7: begin
              //* pkt distribute;
              case(i_address[2:0])
                3'd0:     o_data_out        <= cnt_AsynRev_pkt[0]; //* dma & dra & discard (discard tag);
                3'd1:     o_data_out        <= cnt_AsynRev_pkt[1]; //* dma;
                3'd2:     o_data_out        <= cnt_AsynRev_pkt[2]; //* dra;
                3'd3:     o_data_out        <= cnt_AsynRev_pkt[3]; //* conf;
                3'd4:     o_data_out        <= cnt_PktMUX_dra_pkt;  
                3'd5:     o_data_out        <= cnt_PktMUX_dma_pkt;
                3'd6:     o_data_out        <= {4'b0, d_PktMUX_state_mux_4b,
                                                1'b0, d_PktMUX_usedw_pktDMA_7b,
                                                1'b0, d_PktMUX_usedw_pktDRA_7b,
                                                1'b0, d_PktMUX_usedw_conf_7b    };
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd8: begin
              //* pkt DMA;
              case(i_address[2:0])
                3'd0:     o_data_out        <= cnt_dmaDist_pkt[0];
                3'd1:     o_data_out        <= cnt_dmaDist_pkt[1];
                3'd2:     o_data_out        <= cnt_dmaDist_pkt[2];
                3'd3:     o_data_out        <= {8'b0, 7'b0, d_dmaDist_state_dist_1b,
                                                4'b0, d_dmaOut_state_out_4b,
                                                5'b0, d_dma_alf_dma_3b};
                3'd4:     o_data_out        <= {8'b0, 5'b0, d_dma_empty_dmaWR_3b,
                                                5'b0, d_dma_empty_pBufWR_3b,
                                                5'b0, d_dma_empty_pBufRD_3b};
                3'd5:     o_data_out        <= {5'b0, d_dma_empty_int_3b,
                                                5'b0, d_dma_empty_length_3b,
                                                5'b0, d_dma_empty_low16b_3b,
                                                5'b0, d_dma_empty_high16b_3b};
                3'd6:     o_data_out        <= d_dma_usedw_dmaWR_30b;
                3'd7:     o_data_out        <= d_dma_usedw_pBufRD_30b;
                default:  o_data_out        <= 32'b0;
              endcase
            end
            4'd9: begin
                o_data_out      <= {3'b0, d_dra_empty_pktRecv_1b, 
                                    1'b0, d_dra_empty_despRecv_3b,
                                    1'b0, d_dra_empty_despSend_3b,
                                    1'b0, d_dra_empty_writeReq_3b,
                                    6'b0, d_dra_usedw_pktRecv_10b};
            end
            4'd10: begin
              state_conf                    <= WAIT_DATA_0_S;
              //* multi_core
              d_o_pe0_reg_id_6b             <= i_address[8+:6];
              d_o_pe1_reg_id_6b             <= i_address[8+:6];
              d_o_pe2_reg_id_6b             <= i_address[8+:6];
            end 
            default:      o_data_out        <= 32'b0;
          endcase
        end
        else begin
          state_conf                        <= IDLE_S;
        end
      end
      WAIT_DATA_0_S: begin
        state_conf                          <= WAIT_DATA_1_S;
      end
      WAIT_DATA_1_S: begin
        state_conf                          <= RESP_ACK_S;
        case(i_address[2:0])
          3'd0:     o_data_out              <= d_pe0_reg_value_32b;
          3'd1:     o_data_out              <= d_pe1_reg_value_32b;
          3'd2:     o_data_out              <= d_pe2_reg_value_32b;
          3'd4:     o_data_out              <= d_pc_0;
          3'd5:     o_data_out              <= d_pc_1;
          3'd6:     o_data_out              <= d_pc_2;
          default:  o_data_out              <= 32'b0;
        endcase
      end
      RESP_ACK_S: begin
        o_ack_n                 <= 1'b0;
        state_conf              <= WAIT_END_S;
      end
      WAIT_END_S: begin
        if(i_cs == 1'b1) begin
          o_ack_n               <= 1'b1;
          state_conf            <= IDLE_S;
        end
        else begin
          o_ack_n               <= o_ack_n;
          state_conf            <= WAIT_END_S;
        end
      end
      default: begin
        state_conf              <= IDLE_S;
      end
    endcase
  end
end
//==============================================================//


endmodule
