// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#define regnum_x0   0
#define regnum_x1   1
#define regnum_x2   2
#define regnum_x3   3
#define regnum_x4   4
#define regnum_x5   5
#define regnum_x6   6
#define regnum_x7   7
#define regnum_x8   8
#define regnum_x9   9
#define regnum_x10 10
#define regnum_x11 11
#define regnum_x12 12
#define regnum_x13 13
#define regnum_x14 14
#define regnum_x15 15
#define regnum_x16 16
#define regnum_x17 17
#define regnum_x18 18
#define regnum_x19 19
#define regnum_x20 20
#define regnum_x21 21
#define regnum_x22 22
#define regnum_x23 23
#define regnum_x24 24
#define regnum_x25 25
#define regnum_x26 26
#define regnum_x27 27
#define regnum_x28 28
#define regnum_x29 29
#define regnum_x30 30
#define regnum_x31 31


#define i_type_insn(_imm, _rs1, _f3, _rd, _opc) \
.word (((_imm) << 20) | ((_rs1) << 15) | ((_f3) << 12) | ((_rd) << 7) | ((_opc) << 0))

#define u_type_insn(_imm, _rd, _opc) \
.word (((_imm & 0xfffff000) << 0) | ((_rd) << 7) | ((_opc) << 0))

#define s_type_insn(_imm, _rs2, _rs1, _f3, _opc) \
.word (((_imm & 0b111111100000) << 20) | ((_rs2) << 20) | ((_rs1) << 15) | ((_f3) << 12) | \
((_imm & 0b000000011111) << 7) | ((_opc) << 0))

#define r_type_insn(_f7, _rs2, _rs1, _f3, _rd, _opc) \
.word (((_f7) << 25) | ((_rs2) << 20) | ((_rs1) << 15) | ((_f3) << 12) | ((_rd) << 7) | ((_opc) << 0))


//-------------------------------------------------------------------//
//* lui
#define rf2_lui_instr(_imm, _rd) \
u_type_insn(_imm, regnum_ ## _rd, 0b0111111)
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
//* lb
#define rf2_lb_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b000, regnum_ ## _rd, 0b1011111)
//* lh
#define rf2_lh_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b001, regnum_ ## _rd, 0b1011111)
//* lw
#define rf2_lw_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b010, regnum_ ## _rd, 0b1011111)
//* lbu
#define rf2_lbu_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b100, regnum_ ## _rd, 0b1011111)
//* lhu
#define rf2_lhu_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b101, regnum_ ## _rd, 0b1011111)
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
//* sb
#define rf2_sb_instr(_imm, _rs1, _rs2) \
s_type_insn(_imm, regnum_ ## _rs2, regnum_ ## _rs1, 0b000, 0b1101011)
//* sh
#define rf2_sh_instr(_imm, _rs1, _rs2) \
s_type_insn(_imm, regnum_ ## _rs2, regnum_ ## _rs1, 0b001, 0b1101011)
//* sw
#define rf2_sw_instr(_imm, _rs1, _rs2) \
s_type_insn(_imm, regnum_ ## _rs2, regnum_ ## _rs1, 0b010, 0b1101011)
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
//* addi
#define rf2_addi_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b000, regnum_ ## _rd, 0b0011011)
//* slti
#define rf2_slti_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b010, regnum_ ## _rd, 0b0011011)
//* sltiu
#define rf2_sltiu_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b011, regnum_ ## _rd, 0b0011011)
//* xori
#define rf2_xori_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b100, regnum_ ## _rd, 0b0011011)
//* ori
#define rf2_ori_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b110, regnum_ ## _rd, 0b0011011)
//* andi
#define rf2_andi_instr(_imm, _rs1, _rd) \
i_type_insn(_imm, regnum_ ## _rs1, 0b111, regnum_ ## _rd, 0b0011011)
//* slli
#define rf2_slli_instr(_imm, _rs1, _rd) \
i_type_insn(0x0|_imm, regnum_ ## _rs1, 0b001, regnum_ ## _rd, 0b0011011)
//* srli
#define rf2_srli_instr(_imm, _rs1, _rd) \
i_type_insn(0x0|_imm, regnum_ ## _rs1, 0b101, regnum_ ## _rd, 0b0011011)
//* srai
#define rf2_srai_instr(_imm, _rs1, _rd) \
i_type_insn(0x400|_imm, regnum_ ## _rs1, 0b101, regnum_ ## _rd, 0b0011011)
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
//* add
#define rf2_add_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b000, regnum_ ## _rd, 0b0111011)
//* sub
#define rf2_sub_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0100000, regnum_ ## _rs2, regnum_ ## _rs1, 0b000, regnum_ ## _rd, 0b0111011)
//* sll: x[rd] = x[rs1] << x[rs2];
#define rf2_sll_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b001, regnum_ ## _rd, 0b0111011)
//* slt
#define rf2_slt_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b010, regnum_ ## _rd, 0b0111011)
//* sltu
#define rf2_sltu_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b011, regnum_ ## _rd, 0b0111011)
//* xor
#define rf2_xor_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b100, regnum_ ## _rd, 0b0111011)
//* srl
#define rf2_srl_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b101, regnum_ ## _rd, 0b0111011)
//* sra
#define rf2_sra_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0100000, regnum_ ## _rs2, regnum_ ## _rs1, 0b101, regnum_ ## _rd, 0b0111011)
//* or
#define rf2_or_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b110, regnum_ ## _rd, 0b0111011)
//* and
#define rf2_and_instr(_rs2, _rs1, _rd) \
r_type_insn(0b0000000, regnum_ ## _rs2, regnum_ ## _rs1, 0b111, regnum_ ## _rd, 0b0111011)
//-------------------------------------------------------------------//

//-------------------------------------------------------------------//
//* exch: 1, comm_reg -> pkt_reg; 0, pkt_reg -> comm_reg;
#define rf2_exch_instr(_dir, _rs1, _rd) \
i_type_insn(0x0, regnum_ ## _rs1, _dir, regnum_ ## _rd, 0b0011111)
//-------------------------------------------------------------------//


