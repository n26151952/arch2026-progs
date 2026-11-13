#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if ((f32bits & 0x7f800000u) == 0x7f800000u)
        return (uint16_t) (f32bits >> 16);
    uint32_t kept_lsb = (f32bits >> 16) & 1u;
    return (uint16_t) ((f32bits + 0x7fffu + kept_lsb) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & 0x8000u;
    uint32_t magnitude_a = a & 0x7fffu;
    uint32_t magnitude_b = b & 0x7fffu;

    if (magnitude_a > 0x7f80u)
        return a;
    if (magnitude_a == 0x7f80u)
        return magnitude_b == 0 ? 0x7fc0u : (uint16_t) (sign | 0x7f80u);
    if (magnitude_b > 0x7f80u)
        return b;
    if (magnitude_b == 0x7f80u)
        return magnitude_a == 0 ? 0x7fc0u : (uint16_t) (sign | 0x7f80u);
    if (magnitude_a == 0 || magnitude_b == 0)
        return (uint16_t) sign;

    int exponent_a = (int) (magnitude_a >> 7);
    int exponent_b = (int) (magnitude_b >> 7);
    uint32_t mantissa_a = magnitude_a & 0x7fu;
    uint32_t mantissa_b = magnitude_b & 0x7fu;

    if (exponent_a != 0) {
        mantissa_a |= 0x80u;
    } else {
        exponent_a = 1;
        while (mantissa_a < 0x80u) {
            mantissa_a <<= 1;
            --exponent_a;
        }
    }

    if (exponent_b != 0) {
        mantissa_b |= 0x80u;
    } else {
        exponent_b = 1;
        while (mantissa_b < 0x80u) {
            mantissa_b <<= 1;
            --exponent_b;
        }
    }

    uint32_t product = mantissa_a * mantissa_b;
    int exponent = exponent_a + exponent_b - 127;
    unsigned int shift = 7;
    if (product >= 0x8000u) {
        ++shift;
        ++exponent;
    }

    if (exponent >= 255)
        return (uint16_t) (sign | 0x7f80u);
    if (exponent < -6)
        return (uint16_t) sign;

    uint32_t fraction = (product >> shift) & 0x7fu;
    if (exponent <= 0)
        return (uint16_t) (sign | (fraction >> (1 - exponent)));

    return (uint16_t) (sign | ((uint32_t) exponent << 7) | fraction);
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t magnitude = a & 0x7fffu;

    if (magnitude > 0x7f80u)
        return a;
    if (magnitude == 0)
        return 0;
    if ((a & 0x8000u) != 0)
        return 0x7fc0u;
    if (magnitude == 0x7f80u)
        return a;
    if (magnitude < 0x80u)
        return 0;

    int exponent = (int) (magnitude >> 7) - 127;
    uint32_t mantissa = (magnitude & 0x7fu) | 0x80u;
    if (exponent % 2 != 0) {
        mantissa <<= 1;
        --exponent;
    }

    uint32_t limit = (mantissa + 1u) << 7;
    uint32_t low = 90;
    uint32_t high = 257;
    while (high - low > 1u) {
        uint32_t mid = low + ((high - low) >> 1);
        if (mid * mid < limit)
            low = mid;
        else
            high = mid;
    }

    uint32_t biased_exponent = (uint32_t) (exponent / 2 + 127);
    return (uint16_t) ((biased_exponent << 7) | (low & 0x7fu));
}
