/*
* Copyright 2019 ETH Zürich and University of Bologna
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
.global uart_irq_handler
# .global can_irq_handler
.global dma_irq_handler
.global time_irq_handler
.global irq_puts
.section .vectors, "ax"
.option norvc
vector_table:
	j sw_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j fast2_irq_handler //* 7;  __no_irq_handler, fast2_irq_handler
	j __no_irq_handler  //* 8;  __no_irq_handler, fast2_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j fast0_irq_handler	//* 16;
	j __no_irq_handler	//* 17;
	j __no_irq_handler	//* 18;	__no_irq_handler, fast1_irq_handler
	j __no_irq_handler	//* 19;
	j __no_irq_handler	//* 20;
	j __no_irq_handler	//* 21;
	j fast1_irq_handler	//* 22; fast1_irq_handler, __no_irq_handler
	j __no_irq_handler	//* 23;
	j __no_irq_handler	//* 24; fast2_irq_handler, __no_irq_handler
	j __no_irq_handler	//* 25;
	j __no_irq_handler	//* 26;
	j __no_irq_handler	//* 27;
	j __no_irq_handler	//* 28;
	j __no_irq_handler	//* 29;
	j __no_irq_handler	//* 30;
	j verification_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler

/* this is fixed to 0x8000, used for PULP_SECURE=0. We redirect this entry to the
new vector table (which is at mtvec) */
/* .section .legacy_irq, "ax" */
/*	j vector_table */
/*	j __no_irq_handler */
/*	j __no_irq_handler */
/*	j __no_irq_handler */

.section .text.vecs
/* exception handling */
__no_irq_handler:
	la a0, no_exception_handler_msg
	jal ra, irq_puts
	j end_handler


sw_irq_handler:
	csrr t0, mcause
	slli t0, t0, 1  /* shift off the high bit */
	srli t0, t0, 1
	li t1, 2
	beq t0, t1, handle_illegal_insn
	li t1, 11
	beq t0, t1, handle_ecall
	li t1, 3
	beq t0, t1, handle_ebreak
	j handle_unknown

fast0_irq_handler:
	/*la a0, uart_handler_msg
	jal ra, irq_puts*/
	/*j uart_irq_handler*/
	sw x1,   -1*4(sp)	//* save ra;
    jal ra,  save_current_environment
    addi sp, sp, -32*4
	jal ra,  uart_irq_handler
	addi sp, sp, 32*4
    jal ra,  load_previous_environment
    lw x1,   -1*4(sp)    //* load ra;
	// j end_handler
	mret

fast1_irq_handler:
	/* j dma_irq_handler */
	sw x1,   -1*4(sp)	//* save ra;
    jal ra,  save_current_environment
    addi sp, sp, -32*4
	jal ra,  dma_irq_handler
	addi sp, sp, 32*4
    jal ra,  load_previous_environment
    lw x1,   -1*4(sp)    //* load ra;
	mret

fast2_irq_handler:
	/* j time_irq_handler */
	sw x1,   -1*4(sp)	//* save ra;
    jal ra,  save_current_environment
    addi sp, sp, -32*4
	jal ra,  time_irq_handler
	addi sp, sp, 32*4
    jal ra,  load_previous_environment
    lw x1,   -1*4(sp)    //* load ra;
	mret

handle_ecall:
	la a0, ecall_msg
	jal ra, irq_puts
	j end_handler

handle_ebreak:
	la a0, ebreak_msg
	jal ra, irq_puts
	j end_handler

handle_illegal_insn:
	la a0, illegal_insn_msg
	jal ra, irq_puts
	j end_handler

handle_unknown:
	la a0, unknown_msg
	jal ra, irq_puts
	j end_handler

end_handler:
	csrr a0, mepc
	addi a0, a0, 4
	csrw mepc, a0
	mret
/* this interrupt can be generated for verification purposes, random or when the PC is equal to a given value*/
verification_irq_handler:
	mret

save_current_environment:
    sw x2,   -2*4(sp)            //* save previous x2-x31;
    sw x3,   -3*4(sp)            
    sw x4,   -4*4(sp)
    sw x5,   -5*4(sp)
    sw x6,   -6*4(sp)
    sw x7,   -7*4(sp)
    sw x8,   -8*4(sp)
    sw x9,   -9*4(sp)
    sw x10, -10*4(sp)
    sw x11, -11*4(sp)
    sw x12, -12*4(sp)
    sw x13, -13*4(sp)
    sw x14, -14*4(sp)
    sw x15, -15*4(sp)
    sw x16, -16*4(sp)
    sw x17, -17*4(sp)
    sw x18, -18*4(sp)
    sw x19, -19*4(sp)
    sw x20, -20*4(sp)
    sw x21, -21*4(sp)
    sw x22, -22*4(sp)
    sw x23, -23*4(sp)
    sw x24, -24*4(sp)
    sw x25, -25*4(sp)
    sw x26, -26*4(sp)
    sw x27, -27*4(sp)
    sw x28, -28*4(sp)
    sw x29, -29*4(sp)
    sw x30, -30*4(sp)
    sw x31, -31*4(sp)
    ret

load_previous_environment:
    // lw x2,   -2*4(sp)            //* save previous x2-x31;
    lw x3,   -3*4(sp)            
    lw x4,   -4*4(sp)
    lw x5,   -5*4(sp)
    lw x6,   -6*4(sp)
    lw x7,   -7*4(sp)
    lw x8,   -8*4(sp)
    lw x9,   -9*4(sp)
    lw x10, -10*4(sp)
    lw x11, -11*4(sp)
    lw x12, -12*4(sp)
    lw x13, -13*4(sp)
    lw x14, -14*4(sp)
    lw x15, -15*4(sp)
    lw x16, -16*4(sp)
    lw x17, -17*4(sp)
    lw x18, -18*4(sp)
    lw x19, -19*4(sp)
    lw x20, -20*4(sp)
    lw x21, -21*4(sp)
    lw x22, -22*4(sp)
    lw x23, -23*4(sp)
    lw x24, -24*4(sp)
    lw x25, -25*4(sp)
    lw x26, -26*4(sp)
    lw x27, -27*4(sp)
    lw x28, -28*4(sp)
    lw x29, -29*4(sp)
    lw x30, -30*4(sp)
    lw x31, -31*4(sp)
    ret

.section .rodata
illegal_insn_msg:
	.string "illegal instruction exception handler entered\n"
ecall_msg:
	.string "ecall exception handler entered\n"
ebreak_msg:
	.string "ebreak exception handler entered\n"
unknown_msg:
	.string "unknown exception handler entered\n"
no_exception_handler_msg:
	.string "no exception handler installed\n"
uart_handler_msg:
	.string "uart test\n"
