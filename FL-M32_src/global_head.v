/*
 *  Project:            FL-M32_4c_v0.1.x -- a RISCV-32IMC SoC.
 *  Module name:        global_head.
 *  Description:        head file of timelyRV_SoC_hardware.
 *  Last updated date:  2023.11.25.
 *
 *  Communicate with Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright (C) 2021-2023 NUDT.
 *
 *  Noted:
 *    1) Do not support AIPE for 4 cores
 */


  //==============================================================//
  //  user defination
  //==============================================================//
  //* hardware version configuration
    `define HW_VERSION      32'h2_01_00
  //=========================//
  //* pe core configuration;
    `define PE0_EN              //* common PEs;
    `define PE1_EN              //* common PEs;
    `define PE2_EN              //* common PEs;
    `define PE3_EN              //* common PEs;
  //=========================//
  //* peri configuration;
    `define UART_EN             //* Address 1002xxxx is always for UART;
    // `define GPIO_EN             //* Address 1002xxxx is always for GPIO;
    // `define SPI_EN              //* Address 1003xxxx is always for SPI;
    `define CSR_EN              //* Address 1004xxxx is always for CSR;
    // `define CSRAM_EN            //* Address 1005xxxx is always for CSRAM;
    `define DMA_EN              //* Address 1007xxxx is always for DMA;
    // `define DRA_EN              //* Address 1008xxxx is always for DRA;
    // `define CAN_EN              //* Address 1009xxxx is always for CAN;
  //=========================//
  //* cmcu configuration;
    // `define CMCU
  //=========================//
  //* instr/data memory size (each);
    `define MEM_128KB             //* default is 128KB;
    // `define MEM_64KB             
    // `define MEM_32KB    
  //=========================// 
  //* Using Xilinx's FIFO/SRAM IP cores
    // `define XILINX_FIFO_RAM
    `define SIM_FIFO_RAM
  //=========================//
  //* Using CUSTOMIZED_MUL logic
    // `define CUSTOMIZED_MUL
  //=========================//
  //* time-relate info (ns).
    `define NS_PER_CLK      32'd20
  //=========================//
  //* open display function for UART
    `define OPEN_DISPLAY        
  //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>//



  //==============================================================//
  // conguration according user defination, DO NOT NEED TO MODIFY!!!
  //==============================================================//
  //* pe core configuration
    `ifdef PE3_EN
      `define NUM_PE        4
    `elsif PE2_EN
      `define NUM_PE        3
    `elsif PE1_EN
      `define NUM_PE        2
    `else
      `define NUM_PE        1
    `endif

    `ifdef AIPE_EN
      //* total PEs;
      `define NUM_PE_T      (`NUM_PE+1)
      //* open aiPE and set its id;
      `define AIPE_ID       3 
    `else
      //* total PEs;
      `define NUM_PE_T      (`NUM_PE)
    `endif
  //=========================//
  //* peri configuration;
    //* periID
    `ifdef UART_EN
      `define UART_PERI     1
    `else
      `define UART_PERI     0
    `endif
    `ifdef GPIO_EN
      `define GPIO_PERI     1
    `else
      `define GPIO_PERI     0
    `endif
    `ifdef SPI_EN 
      `define SPI_PERI      1
    `else
      `define SPI_PERI      0
    `endif
    `ifdef CSR_EN
      `define CSR_PERI      1
    `else
      `define CSR_PERI      0
    `endif
    `ifdef CSRAM_EN
      `define CSRAM_PERI    1
    `else
      `define CSRAM_PERI    0
    `endif
    `ifdef CAN_EN
      `define CAN_PERI      1
    `else
      `define CAN_PERI      0
    `endif
    `ifdef DMA_EN
      `define DMA_PERI      1
    `else
      `define DMA_PERI      0
    `endif
    `ifdef DRA_EN
      `define DRA_PERI      1
    `else
      `define DRA_PERI      0
    `endif
    `ifdef dDMA_EN
      `define dDMA_PERI     1
    `else
      `define dDMA_PERI     0
    `endif

    //* UART, GPIO, SPI, CSR, CSRAM, CAN are in Peri_Top;
    `define NUM_PERI_IN     (`UART_PERI+`GPIO_PERI+`SPI_PERI+`CSR_PERI+`CSRAM_PERI+`CAN_PERI)
    //* DMA, DRA, are in Pkt_Proc, dDMA is in MultiCore;
    `define NUM_PERI_OUT    (`DMA_PERI+`DRA_PERI+`dDMA_PERI)
    //* Number of Peripherals
    `define NUM_PERI        (`NUM_PERI_IN+`NUM_PERI_OUT) 

    `define UART            0   
    `define GPIO            (`UART_PERI)
    `define SPI             (`UART_PERI+`GPIO_PERI)
    `define CSR             (`UART_PERI+`GPIO_PERI+`SPI_PERI)
    `define CSRAM           (`UART_PERI+`GPIO_PERI+`SPI_PERI+`CSR_PERI)
    `define CAN             (`UART_PERI+`GPIO_PERI+`SPI_PERI+`CSR_PERI+`CSRAM_PERI)
    `define dDMA            (`NUM_PERI_IN)
    `define DMA             (`NUM_PERI_IN+`dDMA_PERI)
    `define DRA             (`NUM_PERI_IN+`dDMA_PERI+`DMA_PERI)
    `define DMA_OUT         0
    `define DRA_OUT         (`DMA_PERI)
    `define dDMA_OUT        (`DMA_PERI+`DRA_PERI)
    //* irq_defination;
    `define TIME_IRQ        7   //* time irq id, TODO: should before peri
                                //*   to have a higher priority;
    `define UART_IRQ        16  
    `define GPIO_IRQ        17  
    `define SPI_IRQ         18  
    `define CSR_IRQ         19  
    `define CSRAM_IRQ       20  
    `define dDMA_IRQ        21  
    `define DMA_IRQ         22  
    `define DRA_IRQ         23  
    `define CAN_IRQ         24 
  //=========================//
  //* number of ports in MUX
    `define NUM_SRAM        4   
    `define NUM_SRAM_REQ    4   //* port_a is {dma_0,      pe_1,  pe_0,  pe_3/conf};
                                //* port_b is {dma_3/dDMA, dma_2, dma_1, pe_2};
  //=========================//
  //* instr/data memory size
    `ifdef MEM_128KB
      `define BIT_CONF      15
    `elsif MEM_64KB
      `define BIT_CONF      14
    `elsif MEM_32KB
      `define BIT_CONF      13
    `endif
  //=========================//
  //* for configure pkt valid tag, '1' is valid, '0' is invalid;  //
    // `define CRC_PAD         0           
  //==============================================================//
 
