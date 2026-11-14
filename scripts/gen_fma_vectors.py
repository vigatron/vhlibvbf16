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
from fractions import Fraction

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

    Uses exact rational arithmetic and a single RNE rounding, so subnormal
    inputs and exact halfway cases are handled without intermediate loss.
    NaN -> canonical quiet NaN 0x7FC00000.
    """
    ka, sa, va = _f32_fraction(a)
    kb, sb, vb = _f32_fraction(b)

    if ka == "nan" or kb == "nan":
        return QNAN_F32
    if ka == "inf" and kb == "inf":
        return QNAN_F32 if sa != sb else (sa << 31) | INF_F32
    if ka == "inf":
        return (sa << 31) | INF_F32
    if kb == "inf":
        return (sb << 31) | INF_F32
    if va == 0 and vb == 0:
        return 0x80000000 if (sa and sb) else 0

    total = (-va if sa else va) + (-vb if sb else vb)
    if total == 0:
        return 0
    return _round_f32_fraction(total, 1 if total < 0 else 0)


# =============================================================================
# FMA: SUMM + (VALA x VALB)
# =============================================================================

def _floor_log2(x):
    """@brief Return floor(log2(x)) for a positive Fraction."""
    e = x.numerator.bit_length() - x.denominator.bit_length()
    if Fraction(2) ** e > x:
        e -= 1
    while Fraction(2) ** (e + 1) <= x:
        e += 1
    return e


def _round_f32_fraction(x, sign_hint):
    """@brief Round an exact Fraction to binary32 using RNE."""
    if x == 0:
        return sign_hint << 31
    sign = 1 if x < 0 else 0
    a = -x if x < 0 else x
    e = _floor_log2(a)

    if e < -126:
        q = Fraction(1, 1 << 149)
        n = a // q
        rem = a - n * q
        if rem * 2 > q or (rem * 2 == q and (n & 1)):
            n += 1
        if n == 0:
            return sign << 31
        if n >= (1 << 23):
            return (sign << 31) | (1 << 23)
        return (sign << 31) | int(n)

    q = Fraction(2) ** (e - 23)
    n = a // q
    rem = a - n * q
    if rem * 2 > q or (rem * 2 == q and (n & 1)):
        n += 1
    if n >= (1 << 24):
        n >>= 1
        e += 1
    if e > 127:
        return (sign << 31) | INF_F32
    return (sign << 31) | ((e + 127) << 23) | int(n - (1 << 23))


def _bf16_fraction(u16):
    """@brief Return (kind, sign, exact value) for a BF16 word."""
    s, e, f = bf16_unpack(u16)
    if e == 0xFF:
        return ("nan" if f else "inf"), s, None
    if e == 0:
        if f == 0:
            return "zero", s, Fraction(0)
        return "num", s, Fraction(f) * Fraction(2) ** -133
    return "num", s, Fraction(0x80 | f) * Fraction(2) ** (e - 134)


def _f32_fraction(u32):
    """@brief Return (kind, sign, exact value) for an FP32 word."""
    s, e, f = f32_unpack(u32)
    if e == 0xFF:
        return ("nan" if f else "inf"), s, None
    if e == 0:
        if f == 0:
            return "zero", s, Fraction(0)
        return "num", s, Fraction(f) * Fraction(2) ** -149
    return "num", s, Fraction(0x800000 | f) * Fraction(2) ** (e - 150)


def fma_rne(a_bf16, b_bf16, s_f32):
    """@brief Return bit-exact FMA result: SUMM + (VALA x VALB), RNE rounding.

    The product is represented as an exact Fraction (no intermediate FP32
    rounding), then added to SUMM exactly and rounded once with RNE.
    """
    ka, sa, va = _bf16_fraction(a_bf16)
    kb, sb, vb = _bf16_fraction(b_bf16)
    ks, ss, vs = _f32_fraction(s_f32)

    if ka == "nan" or kb == "nan" or ks == "nan":
        return QNAN_F32
    if (ka == "inf" and kb == "zero") or (kb == "inf" and ka == "zero"):
        return QNAN_F32

    prod_sign = sa ^ sb
    if ka == "inf" or kb == "inf":
        if ks == "inf" and ss != prod_sign:
            return QNAN_F32
        return (prod_sign << 31) | INF_F32
    if ks == "inf":
        return (ss << 31) | INF_F32

    prod = Fraction(0) if (ka == "zero" or kb == "zero") else va * vb
    if prod == 0:
        if vs == 0:
            return 0x80000000 if (prod_sign and ss) else 0
        return _round_f32_fraction(-vs if ss else vs, ss)
    if vs == 0:
        return _round_f32_fraction(-prod if prod_sign else prod, prod_sign)

    total = (-prod if prod_sign else prod) + (-vs if ss else vs)
    if total == 0:
        return 0
    return _round_f32_fraction(total, 1 if total < 0 else 0)


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
