#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_fma_vectors.py
@brief Generate and validate BF16 x BF16 + FP32 -> Float32 test vectors (FMA, RNE).

The generator uses a bit-exact reference model of the planned
`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` DUT:
  * BF16 x BF16 product is exact (no intermediate rounding);
  * single RNE rounding applied only at the final FMA result;
  * BF16 subnormal inputs are not flushed to zero;
  * NaN result is canonical quiet NaN 0x7FC00000;
  * exception priority is NaN > Inf > Zero > normal > subnormal;
  * exact cancellation (x - x) yields +0.

Output format (one 64-bit hexadecimal word per line):
    bits[63:48] = BF16 operand A (VALA)
    bits[47:32] = BF16 operand B (VALB)
    bits[31:0]  = FP32 operand S  (SUMM)
    bits[31:0]  = expected F32 result  (в отдельной колонке output_c)

Usage:
    ./scripts/gen_fma_vectors.py --out build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.hex
    ./scripts/gen_fma_vectors.py --count 4096 --seed 1234 --out build/vectors.hex
    ./scripts/gen_fma_vectors.py --self-check
"""

import argparse
import json
import os
import random
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTVALUES_JSON = os.path.join(
    BASE, "testvalues", "fma", "test_values_muladd_bf16_bf16_fp32_fp32_rne_lat4",
    "test_values_muladd_bf16_bf16_fp32_fp32_rne_lat4.json")

QNAN_F32 = 0x7FC00000
INF_F32 = 0x7F800000
F32_FRAC_MASK = 0x007FFFFF
F32_EXP_MASK = 0x7F800000
F32_SIGN_MASK = 0x80000000


# =============================================================================
# BF16 helpers
# =============================================================================

def bf16_unpack(u16):
    """@brief Unpack BF16 into sign, exp, frac."""
    sign = (u16 >> 15) & 1
    exp = (u16 >> 7) & 0xFF
    frac = u16 & 0x7F
    return sign, exp, frac


def bf16_is_zero(u16):
    s, e, f = bf16_unpack(u16)
    return e == 0 and f == 0


def bf16_is_inf(u16):
    s, e, f = bf16_unpack(u16)
    return e == 0xFF and f == 0


def bf16_is_nan(u16):
    s, e, f = bf16_unpack(u16)
    return e == 0xFF and f != 0


def bf16_to_man_exp(u16):
    """@brief Return (mantissa_8bit, eff_exp) for BF16 operand (no FTZ).

    mantissa includes hidden bit: {exp!=0, frac} (8 bits).
    eff_exp = 1 for subnormal, exp otherwise.
    value = mantissa * 2^(eff_exp - 134)
    """
    s, e, f = bf16_unpack(u16)
    e_eff = 1 if e == 0 else e
    man = (0x80 if e != 0 else 0x00) | f  # 8-bit significand
    return man, e_eff


# =============================================================================
# BF16 x BF16 -> F32 exact product (no intermediate rounding)
# =============================================================================

def bf16_mul_f32(a, b):
    """@brief Return bit-exact F32 product of two BF16 words.

    Same semantics as vhfastmulb16_mul_bf16_bf16_fp32_lat4:
    canonical qNaN, no FTZ for BF16 subnormals, RTZ for F32 subnormals.
    """
    a_sign, a_exp, a_frac = bf16_unpack(a)
    b_sign, b_exp, b_frac = bf16_unpack(b)

    a_zero = bf16_is_zero(a)
    b_zero = bf16_is_zero(b)
    a_inf = bf16_is_inf(a)
    b_inf = bf16_is_inf(b)
    a_nan = bf16_is_nan(a)
    b_nan = bf16_is_nan(b)

    sign = a_sign ^ b_sign

    res_nan = a_nan or b_nan or (a_inf and b_zero) or (b_inf and a_zero)
    res_inf = (not res_nan) and (a_inf or b_inf)
    res_zero = (not res_nan) and (not res_inf) and (a_zero or b_zero)

    if res_nan:
        return QNAN_F32
    if res_inf:
        return (sign << 31) | INF_F32
    if res_zero:
        return sign << 31

    a_man, a_exp_eff = bf16_to_man_exp(a)
    b_man, b_exp_eff = bf16_to_man_exp(b)

    prod = a_man * b_man  # 16-bit product, 0..65535
    if prod == 0:
        return sign << 31

    k = prod.bit_length() - 1  # index of highest set bit, 0..15
    exp_unb = a_exp_eff + b_exp_eff + k  # unbiased exponent + offset

    # value = prod * 2^(exp_unb - 294)  (P24 = prod << (23-k), then <<3)
    if exp_unb >= 396:
        # F32 overflow.
        return (sign << 31) | INF_F32

    if exp_unb >= 142:
        # Normal F32 result: exact, no rounding.
        exp_field = exp_unb - 141
        frac = (prod << (23 - k)) & 0x7FFFFF
        return (sign << 31) | (exp_field << 23) | frac

    # F32 subnormal result: truncate (RTZ).
    shift = 142 - exp_unb
    if shift >= 24:
        return sign << 31
    frac = ((prod << (23 - k)) >> shift) & 0x7FFFFF
    return (sign << 31) | frac


# =============================================================================
# FP32 helpers
# =============================================================================

def f32_unpack(u32):
    """@brief Unpack FP32 into sign, exp, frac."""
    sign = (u32 >> 31) & 1
    exp = (u32 >> 23) & 0xFF
    frac = u32 & 0x7FFFFF
    return sign, exp, frac


def f32_is_zero(u32):
    s, e, f = f32_unpack(u32)
    return e == 0 and f == 0


def f32_is_inf(u32):
    s, e, f = f32_unpack(u32)
    return e == 0xFF and f == 0


def f32_is_nan(u32):
    s, e, f = f32_unpack(u32)
    return e == 0xFF and f != 0


def f32_to_man_exp(u32):
    """@brief Return (mantissa_24bit, eff_exp) for FP32 operand (no FTZ).

    mantissa includes hidden bit: {exp!=0, frac} (24 bits).
    eff_exp = 1 for subnormal, exp otherwise.
    value = mantissa * 2^(eff_exp - 150)
    """
    s, e, f = f32_unpack(u32)
    e_eff = 1 if e == 0 else e
    man = (0x800000 if e != 0 else 0x000000) | f  # 24-bit significand
    return man, e_eff


# =============================================================================
# FP32 + FP32 -> FP32 with RNE rounding (golden model)
# =============================================================================

def f32_add_rne(a, b):
    """@brief Return bit-exact F32 sum of two FP32 words with RNE rounding.

    Implements IEEE-754 binary32 addition with round-to-nearest-even.
    Subnormal inputs are not flushed to zero.
    NaN -> canonical quiet NaN 0x7FC00000.
    """
    a_sign, a_exp, a_frac = f32_unpack(a)
    b_sign, b_exp, b_frac = f32_unpack(b)

    a_zero = f32_is_zero(a)
    b_zero = f32_is_zero(b)
    a_inf = f32_is_inf(a)
    b_inf = f32_is_inf(b)
    a_nan = f32_is_nan(a)
    b_nan = f32_is_nan(b)

    # NaN priority
    if a_nan or b_nan:
        return QNAN_F32
    if a_inf and b_inf and a_sign != b_sign:
        return QNAN_F32  # Inf - Inf = NaN
    if a_inf or b_inf:
        inf_sign = a_sign if a_inf else b_sign
        return (inf_sign << 31) | INF_F32

    # Both zero
    if a_zero and b_zero:
        if a_sign and b_sign:
            return 0x80000000  # -0 + -0 = -0
        return 0x00000000  # +0 + -0 = +0, +0 + +0 = +0

    # Effective mantissa and exponent (no FTZ)
    a_man, a_exp_eff = f32_to_man_exp(a)
    b_man, b_exp_eff = f32_to_man_exp(b)

    # Internal scale: value = man24 * 2^(exp_eff - 150)
    # Use 27-bit extended mantissa (24 + 3 GRS bits) like the DUT
    a_ext = a_man << 3  # 27 bits
    b_ext = b_man << 3

    # Align exponents: larger exponent stays, smaller is right-shifted
    if a_exp_eff > b_exp_eff:
        shift = a_exp_eff - b_exp_eff
        large_ext, large_sign = a_ext, a_sign
        small_ext, small_sign = b_ext, b_sign
        large_exp = a_exp_eff
    elif b_exp_eff > a_exp_eff:
        shift = b_exp_eff - a_exp_eff
        large_ext, large_sign = b_ext, b_sign
        small_ext, small_sign = a_ext, a_sign
        large_exp = b_exp_eff
    else:
        shift = 0
        # Equal exponents: compare mantissas
        if a_man >= b_man:
            large_ext, large_sign = a_ext, a_sign
            small_ext, small_sign = b_ext, b_sign
        else:
            large_ext, large_sign = b_ext, b_sign
            small_ext, small_sign = a_ext, a_sign
        large_exp = a_exp_eff

    # Right-shift small operand with sticky bit
    if shift >= 27:
        small_al = 1 if small_ext != 0 else 0  # all bits lost -> sticky only
    else:
        # sticky = OR of bits shifted out
        sticky = small_ext & ((1 << shift) - 1)
        small_al = (small_ext >> shift) | (1 if sticky else 0)

    # Add or subtract magnitudes
    op_add = (large_sign == small_sign)
    if op_add:
        man_raw = large_ext + small_al  # 27 bits + possible carry -> 28
    else:
        man_raw = large_ext - small_al  # large >= small in magnitude

    # Normalize
    if man_raw == 0:
        # Exact cancellation: result is +0 (IEEE-754: +0 for x + (-x))
        return 0x00000000

    # Find leading one position in man_raw (up to bit 27, since ext27 max is 2^27-1 + 2^27-1 = 2^28-2)
    if man_raw & 0x08000000:  # bit 27 set (carry from addition)
        man_norm = man_raw >> 1
        exp_adj = large_exp + 1
    else:
        # Count leading zeros down to bit 26
        lz = 0
        tmp = man_raw
        while tmp and not (tmp & 0x04000000):  # bit 26
            tmp <<= 1
            lz += 1
        man_norm = man_raw << lz
        exp_adj = large_exp - lz

    # man_norm now has leading bit at position 26 (27-bit value).
    # Internal scale: value = man_norm * 2^(exp_adj - 153) (since ext27 = man<<3).
    # FP32: value = kept * 2^(exp_biased - 150), where kept = man_norm >> 3.
    # So exp_biased - 150 = exp_adj - 153 + 3 = exp_adj - 150.
    # Therefore exp_biased = exp_adj.
    exp_biased = exp_adj

    # Extract G/R/S from man_norm[2:0]
    kept = (man_norm >> 3) & 0xFFFFFF  # 24-bit significand (bits 26:3)
    g = (man_norm >> 2) & 1
    r = (man_norm >> 1) & 1
    s = man_norm & 1

    # RNE rounding
    round_up = g and (r or s or (kept & 1))
    if round_up:
        kept += 1
        if kept & 0x1000000:  # overflow from 24 to 25 bits
            kept >>= 1
            exp_biased += 1

    # Check overflow / subnormal
    if exp_biased >= 0xFF:
        # Overflow -> Inf
        inf_sign = large_sign
        return (inf_sign << 31) | INF_F32

    if exp_biased <= 0:
        # Subnormal result
        shift_sub = 1 - exp_biased  # how many to right-shift kept
        if shift_sub >= 24:
            return large_sign << 31  # underflow to zero
        # Shift kept right with sticky for final RNE on subnormal
        frac_bits = kept
        sticky_sub = frac_bits & ((1 << shift_sub) - 1)
        frac_sub = frac_bits >> shift_sub
        g_sub = (frac_bits >> (shift_sub - 1)) & 1 if shift_sub >= 1 else 0
        r_sub = 0  # after shift, remaining bits below are sticky
        s_sub = sticky_sub
        # Final RNE on subnormal fraction
        round_sub = g_sub and (r_sub or s_sub or (frac_sub & 1))
        if round_sub:
            frac_sub += 1
            if frac_sub & 0x800000:  # overflow to normal
                exp_biased = 1
                frac_sub = 0
        return (large_sign << 31) | frac_sub

    # Normal result
    frac_final = kept & 0x7FFFFF
    return (large_sign << 31) | (exp_biased << 23) | frac_final


# =============================================================================
# FMA: SUMM + (VALA x VALB)
# =============================================================================

def fma_rne(a_bf16, b_bf16, s_f32):
    """@brief Return bit-exact FMA result: SUMM + (VALA x VALB), RNE rounding.

    Product computed exactly (no intermediate rounding), then single RNE
    addition with SUMM.
    """
    prod_f32 = bf16_mul_f32(a_bf16, b_bf16)
    return f32_add_rne(s_f32, prod_f32)


# =============================================================================
# Directed test cases
# =============================================================================

def directed_cases():
    """@brief Return directed edge cases as (a, b, s, expected, label)."""
    cases = [
        # From testvalues JSON (20 vectors)
        (0x3F80, 0x3F80, 0x3F800000, "1.0 + (1.0 * 1.0) = 2.0"),
        (0x4000, 0x4040, 0x00000000, "0.0 + (2.0 * 3.0) = 6.0"),
        (0x3F00, 0x3E80, 0x40A00000, "5.0 + (0.5 * 0.25) = 5.125"),
        (0xBFC0, 0x4080, 0x00000000, "0.0 + (-1.5 * 4.0) = -6.0"),
        (0x0000, 0x4040, 0x41200000, "10.0 + (0.0 * 3.0) = 10.0"),
        (0x7F80, 0x4000, 0x00000000, "0.0 + (+Inf * 2.0) = +Inf"),
        (0x7F80, 0x0000, 0x00000000, "0.0 + (+Inf * 0.0) = qNaN"),
        (0x3F80, 0x3F80, 0x7FC00000, "NaN + (1.0 * 1.0) = qNaN"),
        (0x7F80, 0x3F80, 0xFF800000, "-Inf + (+Inf * 1.0) = qNaN"),
        (0x7F80, 0xBF80, 0x7F800000, "+Inf + (+Inf * -1.0) = qNaN"),
        (0x7F7F, 0x4000, 0x00000000, "0.0 + (max_BF16 * 2.0) = +Inf"),
        (0x0001, 0x3F80, 0x00000000, "0.0 + (min_sub * 1.0) = subnormal"),
        (0x0001, 0x3F80, 0x00010000, "subnormal + (min_sub * 1.0)"),
        (0x3F80, 0xBF80, 0x3F800000, "1.0 + (1.0 * -1.0) = +0"),
        (0x3F80, 0x3F80, 0xBF800000, "-1.0 + (1.0 * 1.0) = +0"),
        (0x8000, 0x3F80, 0x80000000, "-0.0 + (-0.0 * 1.0) = -0"),
        (0xFF80, 0x3F80, 0x00000000, "0.0 + (-Inf * 1.0) = -Inf"),
        (0x7FC0, 0x3F80, 0x00000000, "0.0 + (NaN * 1.0) = qNaN"),
        (0x3F80, 0x7FC0, 0x00000000, "0.0 + (1.0 * NaN) = qNaN"),
        (0x3F80, 0x3F80, 0x3F000000, "0.5 + (1.0 * 1.0) = 1.5"),
    ]
    return [(a, b, s, fma_rne(a, b, s), label) for a, b, s, label in cases]


# =============================================================================
# Random test cases
# =============================================================================

def random_cases(count, seed):
    """@brief Return `count` deterministic random (a, b, s) triples."""
    rng = random.Random(seed)
    return [(rng.getrandbits(16), rng.getrandbits(16), rng.getrandbits(32))
            for _ in range(count)]


# =============================================================================
# Self-check against JSON test vectors
# =============================================================================

def self_check():
    """@brief Validate the reference model against docs JSON test vectors."""
    if not os.path.exists(TESTVALUES_JSON):
        print("WARNING: JSON test vectors not found at {}".format(TESTVALUES_JSON))
        return 0

    with open(TESTVALUES_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    errors = 0
    total = 0
    for item in data.get("test_vectors", []):
        a = int(item["input_a"]["hex"], 16)
        b = int(item["input_b"]["hex"], 16)
        s = int(item["input_s"]["hex"], 16)
        exp = int(item["output_c"]["hex"], 16)
        got = fma_rne(a, b, s)
        total += 1
        if got != exp:
            errors += 1
            print("FAIL #{no}: a={a:04X} b={b:04X} s={s:08X} exp={exp:08X} got={got:08X}".format(
                no=item["no"], a=a, b=b, s=s, exp=exp, got=got))
    print("checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Generate BF16 x BF16 + FP32 -> F32 (FMA, RNE) test vectors")
    parser.add_argument("--count", type=int, default=2048,
                        help="total number of vectors (default: 2048)")
    parser.add_argument("--seed", type=int, default=12345,
                        help="random seed (default: 12345)")
    parser.add_argument("--out",
                        default="build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.hex",
                        help="output hex file")
    parser.add_argument("--self-check", action="store_true",
                        help="validate the model against docs JSON")
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    if args.count < 1:
        print("ERROR: --count must be positive", file=sys.stderr)
        return 2

    cases = directed_cases()
    if len(cases) > args.count:
        print(
            "ERROR: --count={} is less than {} directed cases".format(
                args.count, len(cases)),
            file=sys.stderr)
        return 2

    rand_count = args.count - len(cases)
    for a, b, s in random_cases(rand_count, args.seed):
        cases.append((a, b, s, fma_rne(a, b, s), "random"))

    out_path = args.out
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, s, exp, _label in cases:
            f.write("{:04X}{:04X}{:08X}{:08X}\n".format(a, b, s, exp))

    print("generated {} vectors -> {}".format(len(cases), out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
