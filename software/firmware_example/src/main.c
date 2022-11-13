/*
 *  LwIP for a modified Cv32e40p (RV32IMC) Processor Core.
 *
 *  Copyright (C) 2021-2022 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Date: 2022.10.13
 *  Description: port LwIP to RISC-V MCU. 
 */

#include "firmware.h"

volatile unsigned int timer_irq_count;

int main(){
    unsigned char test_pkt[1600] = {0};
    unsigned int  get_pkt_len = 0;
    int i;
    unsigned char mac_tmp[6] = {0};
    //unsigned char *p = test_pkt;
    //* system inilization, open all interrupt (32_bitmap);
    irq_init();

    //* test TCP checksum calculation;
    //    uint32_t meta[8] ={0,0,0x00000800,0,0,0,0,0};
    //    uint32_t payload[20] ={0x76cd2300, 0x21001a63, 0x8f2bc585, 0x00450008,
    //                        0x270a3400, 0x06400040, 0xa8c0cad2, 0x6b716401,
    //                        0x05055b2a, 0x777a5000, 0x00004bff, 0x02800000,
    //                        0x0000ffff, 0x04020000, 0x0301ca17, 0x01010103,
    //                        0x00000204, 0x00000000, 0x00000000, 0x00000000};
    //
    //    printf("payload: %08x",payload);
    //    //* write metadata;
    //    *((volatile uint32_t *) DMA_SEND_LEN_ADDR) = (uint32_t)(0x20020);
    //    *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t )(meta);
    //    //* write payload;
    //    *((volatile uint32_t *) DMA_SEND_LEN_ADDR) = (uint32_t)(0x20042);
    //    *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t )(payload);
    //    *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = 0x80000000;
    //
    //    while(1);
    //

    //* for timer_irq;
    timer_irq_count = 0;
    
    printf("\rsystem boot finished\r\n");
    
    //* set timer_irq_value, i.e., TIMERCMP_ADDR
    *((volatile uint32_t *) TIMERCMP_ADDR) = 50000000;

    ////* to recv pkt and retransmit tcp pkt;
    //while (1) {
    //    if (timer_irq_count != 0){
    //        timer_irq_count = 0;
    //        tcp_tmr();
    //        printf("tcp_tmr\r\n");
    //    }
    //    else timer_irq_count = 0;
    //    
    //    ethernetif_input(p_server_netif);
    //}
    
    while(1)
    {
        if (timer_irq_count != 0){
            timer_irq_count = 0;
            //printf("tcp_tmr\r\n");
        }
        else timer_irq_count = 0;
        
        get_pkt_len = (unsigned int)(rv_recv(test_pkt));
        //printf("tcp_tmr\r\n");
        
        //get_pkt_len = 0x0;
        
        if(get_pkt_len > 0)
        {
          printf("recv, len: %d\n\r",get_pkt_len);
            for(i = 0; i < 6; i++) mac_tmp[i] = test_pkt[i];
            for(i = 0; i < 6; i++) test_pkt[i] = test_pkt[i+6];
            for(i = 0; i < 6; i++) test_pkt[i+6] = mac_tmp[i];
            
            // if(test_pkt[12] == 0x12)
                rv_send(test_pkt, get_pkt_len);
            // else 
                // printf("no\r\n");
          printf("send\n\r");
        }
    }
    return 0;
}

