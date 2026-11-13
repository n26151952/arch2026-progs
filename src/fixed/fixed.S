# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    # Count passes while propagating the carry word.
    li      t0, 0
    beqz    a1, .Lop1_done
.Lop1_loop:
    and     t1, a0, a1
    xor     a0, a0, a1
    slli    a1, t1, 1
    addi    t0, t0, 1
    bnez    a1, .Lop1_loop
.Lop1_done:
    sw      t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    # Compute the unsigned average without overflowing the sum.
    and     t0, a0, a1
    xor     a0, a0, a1
    srli    a0, a0, 1
    add     a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    # Save the product sign and form unsigned magnitudes.
    xor     t0, a0, a1
    srai    t0, t0, 31
    srai    t4, a0, 31
    xor     a0, a0, t4
    sub     a0, a0, t4
    srai    t4, a1, 31
    xor     a1, a1, t4
    sub     a1, a1, t4

    # Use the smaller magnitude as the multiplier to shorten the loop.
    bgeu    a0, a1, .Lqmul_init
    mv      t4, a0
    mv      a0, a1
    mv      a1, t4

.Lqmul_init:
    li      t1, 0
    li      t2, 0
    li      t3, 0
    beqz    a1, .Lqmul_signed

    # Accumulate into t2:t1 and shift the multiplicand in t3:a0.
.Lqmul_bit:
    andi    t4, a1, 1
    beqz    t4, .Lqmul_next
    add     t5, t1, a0
    sltu    t4, t5, t1
    mv      t1, t5
    add     t2, t2, t3
    add     t2, t2, t4
.Lqmul_next:
    srli    a1, a1, 1
    beqz    a1, .Lqmul_signed
    srli    t4, a0, 31
    slli    a0, a0, 1
    slli    t3, t3, 1
    or      t3, t3, t4
    j       .Lqmul_bit

.Lqmul_signed:
    beqz    t0, .Lqmul_round
    sltu    t4, zero, t1
    neg     t1, t1
    neg     t2, t2
    sub     t2, t2, t4

.Lqmul_round:
    li      t4, 0x80000
    add     t5, t1, t4
    sltu    t4, t5, t1
    add     t2, t2, t4
    srli    t5, t5, 20
    slli    t2, t2, 12
    or      a0, t2, t5
    ret
    .size   q_mul_asm, .-q_mul_asm
