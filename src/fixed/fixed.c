#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    while (b != 0) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        ++passes;
    }

    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a;
    uint32_t ub = (uint32_t) b;
    uint32_t a_lo = ua & 0xffffu;
    uint32_t a_hi = ua >> 16;
    uint32_t b_lo = ub & 0xffffu;
    uint32_t b_hi = ub >> 16;

    uint32_t p0 = a_lo * b_lo;
    uint32_t p1 = a_hi * b_lo;
    uint32_t p2 = a_lo * b_hi;
    uint32_t p3 = a_hi * b_hi;

    uint32_t middle = (p0 >> 16) + (p1 & 0xffffu) + (p2 & 0xffffu);
    uint32_t lo = (p0 & 0xffffu) | (middle << 16);
    uint32_t hi = p3 + (p1 >> 16) + (p2 >> 16) + (middle >> 16);

    /* Correct the high word for signed operands. */
    if (a < 0)
        hi -= ub;
    if (b < 0)
        hi -= ua;

    uint32_t rounded = lo + (1u << (Q - 1));
    hi += lo > UINT32_MAX - (1u << (Q - 1));

    uint32_t result = (hi << (32 - Q)) | (rounded >> Q);
    if (result <= INT32_MAX)
        return (int32_t) result;
    return -1 - (int32_t) (UINT32_MAX - result);
}
