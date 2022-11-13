/* Copyright (c) 2017  SiFive Inc. All rights reserved.
 * Copyright (c) 2022  National University of Defense and Technology.
 * This copyrighted material is made available to anyone wishing to use,
 * modify, copy, or redistribute it subject to the terms and conditions
 * of the FreeBSD License.   
 */

#include "custom_ops.S" //* for DRA;

/* Entry point for bare metal programs */
.section .text.start
.global _start
.global main
//.global irq
.global memset

.type _start, @function

_start:
/* initialize global pointer */
.option push
.option norelax
1:  auipc gp, %pcrel_hi(__global_pointer$)
    addi  gp, gp, %pcrel_lo(1b)
.option pop

/* initialize stack pointer */
    la sp, _sp

/* set vector table address and vectored mode */
    la a0, __vector_start
    ori a0, a0, 0x1
    csrw mtvec, a0

/* clear the bss segment */
    // la a0, __bss_start
    // la a2, __bss_end
    // sub a2, a2, a0
    // li a1, 0
    // call memset

/* new-style constructors and destructors */
    // la a0, __libc_fini_array
    // call atexit
    // call __libc_init_array

/* call main */
    lw a0, 0(sp)                    /* a0 = argc */
    addi a1, sp, __SIZEOF_POINTER__ /* a1 = argv */
    li a2, 0                        /* a2 = envp = NULL */
    call main
    // tail exit

// .size  _start, .-_start

// .global _init
// .type   _init, @function
// .global _fini
// .type   _fini, @function
// _init:
// _fini:
//  /* These don't have to do anything since we use init_array/fini_array. Prevent
//     missing symbol error */
//     ret
// .size  _init, .-_init
// .size _fini, .-_fini

    .global __test_custom_instr
    .type   __test_custom_instr, @function
__test_custom_instr:
    rf2_addi_instr(10, x1, x1);
    rf2_slti_instr(10, x1, x2);
    rf2_sltiu_instr(11, x1, x3);
    rf2_xori_instr(11, x1, x4);
    rf2_ori_instr(11, x4, x5);
    rf2_andi_instr(10, x5, x6);
    rf2_slli_instr(8, x1, x7);
    rf2_srli_instr(4, x1, x8);
    rf2_srai_instr(1, x1, x9);

    rf2_exch_instr(1, x1, x31);
    rf2_exch_instr(0, x1, x10);

    rf2_lui_instr(0x10000, x11);

    rf2_lb_instr(0, x11, x12);
    rf2_lh_instr(0, x11, x13);
    rf2_lw_instr(0, x11, x14);
    rf2_lbu_instr(0, x11, x15);
    rf2_lhu_instr(0, x11, x16);

    rf2_sb_instr(0, x11, x12);
    rf2_sh_instr(0, x11, x13);
    rf2_sw_instr(0, x11, x14);

    rf2_lb_instr(0, x11, x14);
    rf2_lh_instr(0, x11, x13);
    rf2_lw_instr(0, x11, x12);

    rf2_add_instr(x1, x7, x17);
    rf2_sub_instr(x1, x8, x18);
    rf2_sll_instr(x1, x9, x19);
    rf2_slt_instr(x1, x0, x20);
    rf2_sltu_instr(x1, x1, x21);
    rf2_xor_instr(x1, x2, x22);
    rf2_srl_instr(x1, x3, x23);
    rf2_sra_instr(x1, x4, x24);
    rf2_or_instr(x1, x5, x25);
    rf2_and_instr(x1, x6, x26);
    ret
    .size   __test_custom_instr, . - __test_custom_instr
    

    .global __to_recv_pkt
    .type   __to_recv_pkt, @function
__to_recv_pkt:
    rf2_lui_instr(0x20000000, x30); //* to recv pkt;
    addi x0, x1, 0
    addi x0, x2, 0
    rf2_exch_instr(1, x30, x10);    //* exchange to common reg (a0);
    ret
    .size   __to_recv_pkt, . - __to_recv_pkt

    .global __test_proc_pkt
    .type   __test_proc_pkt, @function
__test_proc_pkt:
    // rf2_lui_instr(0x10000, x21);
    // rf2_add_instr(x21, x3, x3);
    rf2_lui_instr(0x10000000, x21);
    rf2_lui_instr(0x30000000, x22);
    rf2_add_instr(x21, x16, x16);
    rf2_xor_instr(x22, x16, x16);   //* get outPort;
    ret
    .size   __test_proc_pkt, . - __test_proc_pkt

    .global __to_send_pkt
    .type   __to_send_pkt, @function
__to_send_pkt:
    rf2_slli_instr(4, x16, x21);
    rf2_srli_instr(20, x21, x28);   //* get write back address;
    rf2_lui_instr(0x10000000, x30); //* to send pkt;
    ret
    .size   __to_send_pkt, . - __to_send_pkt

    .global __dma_recv_pkt
    .type   __dma_recv_pkt, @function
__dma_recv_pkt:
    rf2_addi_instr(2, x19, x19);    //* set dma_wr tag;
    rf2_slli_instr(4, x16, x21);
    rf2_srli_instr(20, x21, x28);   //* get write back address;
    rf2_lui_instr(0x10000000, x30); //* to dma_recv pkt;
    ret
    .size   __dma_recv_pkt, . - __dma_recv_pkt
