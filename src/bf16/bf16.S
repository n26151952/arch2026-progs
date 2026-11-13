# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    srli t0, a0, 16
    srli t1, a0, 23
    andi t1, t1, 255
    li t2, 255
    beq t1, t2, .Lbf16_f32_special

    andi t1, t0, 1
    li t2, 0x7fff
    add a0, a0, t2
    add a0, a0, t1
    srli a0, a0, 16
    ret

.Lbf16_f32_special:
    mv a0, t0
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm
    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    # Compute the result sign and classify operands in order.
    xor     t0, a0, a1
    li      t3, 0x8000
    and     t0, t0, t3
    addi    t3, t3, -1
    and     t1, a0, t3
    and     t2, a1, t3
    li      t3, 0x7f80
    bltu    t3, t1, .Lmul_return
    beq     t1, t3, .Lmul_a_inf
    bltu    t3, t2, .Lmul_return_b
    beq     t2, t3, .Lmul_b_inf
    beqz    t1, .Lmul_signed_zero
    beqz    t2, .Lmul_signed_zero

    # Unpack both significands and normalize subnormal operands.
    srli    t3, t1, 7
    srli    t4, t2, 7
    andi    a0, t1, 127
    andi    a1, t2, 127
    li      t5, 128

    beqz    t3, .Lmul_subnormal_a
    ori     a0, a0, 128
    j       .Lmul_unpack_b
.Lmul_subnormal_a:
    li      t3, 1
.Lmul_normalize_a:
    slli    a0, a0, 1
    addi    t3, t3, -1
    bltu    a0, t5, .Lmul_normalize_a

.Lmul_unpack_b:
    beqz    t4, .Lmul_subnormal_b
    ori     a1, a1, 128
    j       .Lmul_product
.Lmul_subnormal_b:
    li      t4, 1
.Lmul_normalize_b:
    slli    a1, a1, 1
    addi    t4, t4, -1
    bltu    a1, t5, .Lmul_normalize_b

.Lmul_product:
    # Multiply by adding a shifted copy for each set bit of a1.
    li      t6, 0
.Lmul_bit:
    andi    t5, a1, 1
    beqz    t5, .Lmul_next_bit
    add     t6, t6, a0
.Lmul_next_bit:
    slli    a0, a0, 1
    srli    a1, a1, 1
    bnez    a1, .Lmul_bit

    add     t3, t3, t4
    addi    t3, t3, -127
    li      t5, 0x8000
    bltu    t6, t5, .Lmul_truncate
    srli    t6, t6, 1
    addi    t3, t3, 1

.Lmul_truncate:
    srli    t6, t6, 7
    andi    t6, t6, 127
    li      t5, 255
    bge     t3, t5, .Lmul_inf
    li      t5, -6
    blt     t3, t5, .Lmul_signed_zero
    blez    t3, .Lmul_subnormal_result
    slli    t3, t3, 7
    or      t6, t6, t3
    or      a0, t6, t0
    ret

.Lmul_subnormal_result:
    li      t5, 1
    sub     t5, t5, t3
    srl     t6, t6, t5
    or      a0, t6, t0
    ret

.Lmul_a_inf:
    beqz    t2, .Lmul_nan
    j       .Lmul_inf
.Lmul_b_inf:
    beqz    t1, .Lmul_nan
.Lmul_inf:
    li      a0, 0x7f80
    or      a0, a0, t0
    ret
.Lmul_nan:
    li      a0, 0x7fc0
    ret
.Lmul_signed_zero:
    mv      a0, t0
    ret
.Lmul_return_b:
    mv      a0, a1
.Lmul_return:
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    # Handle NaNs, signed zeros, negative inputs, and positive infinity.
    li      t0, 0x7fff
    and     t0, a0, t0
    li      t1, 0x7f80
    bltu    t1, t0, .Lsqrt_return
    beqz    t0, .Lsqrt_zero
    bne     a0, t0, .Lsqrt_nan
    beq     t0, t1, .Lsqrt_return
    li      t1, 128
    bltu    t0, t1, .Lsqrt_zero

    # Halve the unbiased exponent and double the significand if it was odd.
    srli    t1, t0, 7
    addi    t1, t1, -127
    andi    t2, t1, 1
    srai    t1, t1, 1
    addi    t1, t1, 127
    andi    t0, t0, 127
    ori     t0, t0, 128
    sll     t0, t0, t2

    # Find the integer square root of ((significand + 1) << 7) - 1.
    addi    t0, t0, 1
    slli    t0, t0, 7
    addi    t0, t0, -1
    li      t2, 0
    li      t3, 0x4000
.Lsqrt_bit:
    add     t4, t2, t3
    srli    t2, t2, 1
    bltu    t0, t4, .Lsqrt_next_bit
    sub     t0, t0, t4
    add     t2, t2, t3
.Lsqrt_next_bit:
    srli    t3, t3, 2
    bnez    t3, .Lsqrt_bit

    slli    t1, t1, 7
    andi    t2, t2, 127
    or      a0, t1, t2
.Lsqrt_return:
    ret

.Lsqrt_zero:
    li      a0, 0
    ret
.Lsqrt_nan:
    li      a0, 0x7fc0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
