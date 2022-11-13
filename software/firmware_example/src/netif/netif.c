#include "netif.h"

unsigned int meta_buffer[8] = {0, 0, 0, 0, 0, 0, 0, 0};


int rv_recv(unsigned int * ptr)
{
  unsigned int pkt_len = 0x0;
  
  //* check whether NIC recv pkt;
  uint32_t tag_w_length = *((volatile uint32_t *) DMA_TAG_ADDR);
  
  if(tag_w_length == 0x80000000){
    return 0;
  }
  
  //printf("get1\r\n");
  //printf("tag%d\n\r", tag_w_length);
  
  *((volatile uint32_t *) DMA_CNT_RECV_PKT) = 0;
  
  pkt_len = (tag_w_length & 0xffff) - 0x20;
  
  *((volatile uint32_t *) DMA_RECV_LEN_ADDR)  = (uint32_t)(32);
  *((volatile uint32_t *) DMA_RECV_ADDR_ADDR) = (uint32_t)(meta_buffer);
  
  // printf("r: %08x, %d\n\r", (uint32_t )(q->payload), (uint32_t )(q->len));
  *((volatile uint32_t *) DMA_RECV_LEN_ADDR)  = (uint32_t)(pkt_len);
  *((volatile uint32_t *) DMA_RECV_ADDR_ADDR) = (uint32_t)(ptr);

  //printf("len%d\n\r", pkt_len);

  while(*((volatile uint32_t *) DMA_CNT_RECV_PKT) == 0) ;
  
  //printf("return\r\n");
  
  //rv_send(ptr, 60);
  
  return pkt_len;
}

int rv_send(unsigned int * ptr, unsigned int len)
{
  unsigned int pkt_len = (unsigned int)len;
  
  pkt_len = pkt_len << 16;
  
  *((volatile uint32_t *) DMA_SEND_LEN_ADDR)  = (uint32_t)(pkt_len + 0x20);
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t)(meta_buffer);
  
  *((volatile uint32_t *) DMA_SEND_LEN_ADDR)  = (uint32_t)(len);
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = (uint32_t)(ptr);
  
  *((volatile uint32_t *) DMA_SEND_ADDR_ADDR) = 0x80000000;
  
  //printf("send\r\n");
  
  return 1;
}