    .text
    .globl gcd_u32_asm
    .type gcd_u32_asm, @function

gcd_u32_asm:
    beqz a0, .Lreturn_b
    beqz a1, .Lreturn
    li t0, 0

    # Remove and count the shared factors of two.
.Lcommon_twos:
    or t1, a0, a1
    andi t1, t1, 1
    bnez t1, .Lstrip_a
    srli a0, a0, 1
    srli a1, a1, 1
    addi t0, t0, 1
    j .Lcommon_twos

.Lstrip_a:
    andi t1, a0, 1
    bnez t1, .Lstrip_b
    srli a0, a0, 1
    j .Lstrip_a

.Lshift_b:
    srli a1, a1, 1
.Lstrip_b:
    andi t1, a1, 1
    beqz t1, .Lshift_b

    # Keep the smaller odd operand in a0 and the difference in a1.
    bltu a1, a0, .Lsmaller_b
    sub a1, a1, a0
    bnez a1, .Lshift_b
    sll a0, a0, t0
    ret

.Lsmaller_b:
    sub t2, a0, a1
    mv a0, a1
    mv a1, t2
    j .Lshift_b

.Lreturn_b:
    mv a0, a1
.Lreturn:
    ret

    .size gcd_u32_asm, .-gcd_u32_asm
