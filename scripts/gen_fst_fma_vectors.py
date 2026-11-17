#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_fst_fma_vectors.py
@brief Generate BF16 x BF16 + FP32 -> FP32 FAST (RTZ/FTZ) test vectors.

Bit-exact reference model of the planned DUT
`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`:

  * BF16 operands: [15] sign | [14:7] exp (bias 127) | [6:0] frac;
  * FP32 addend:   [31] sign | [30:23] exp (bias 127) | [22:0] frac;
  * FTZ on inputs: exp == 0 (zero or subnormal) -> operand treated as zero;
    effective mantissa M = (exp == 0) ? 0 : (0x80 | frac) for BF16 and
    (0x800000 | frac) for FP32;
  * exact product P = M_a * M_b (16 bits);
  * normalization: leading one is at P[15] or P[14] for normal BF16 inputs,
    so k = 15 if P[15] else 14, p24 = (P << (15-k)) << 8;
  * internal exponents:
        exp_p = a_exp + b_exp - 130 + (P[15] ? 1 : 0)
        exp_s = s_exp - 3
    product zero -> exp_p_eff = -1024 (sentinel);
    FP32 zero    -> exp_s_eff = -1024 (sentinel);
  * alignment: shift = |exp_p_eff - exp_s_eff|, large/small selected by
    exponent and (on equality) by the 24-bit significands;
  * RTZ without sticky: small_al = (shift >= 32) ? 0 : (small_ext >> shift);
  * 28-bit add/sub, carry fix-up (carry -> man_raw >> 1, exp + 1),
    full 5-bit LZD over the 28-bit raw result, normalization;
  * RTZ final: 24-bit significand = man_norm[26:3], low 3 bits discarded;
  * result exponent E = exp_pre + 3:
        E <= 0   -> +0 (FTZ underflow)
        E >= 255 -> +/-Inf (overflow)
        otherwise -> sign | E[7:0] | man_norm[25:3];
  * NaN: canonical quiet NaN 0x7FC00000 (no sign, no payload);
  * zero sign: always +0 (both-zero, exact cancellation, underflow);
  * exception priority: NaN > Inf > Zero > normal.

Output format (one 96-bit hexadecimal word per line):
    bits[95:80] = BF16 operand A (VALA)
    bits[79:64] = BF16 operand B (VALB)
    bits[63:32] = FP32 operand S (SUMM)
    bits[31:0]  = expected FP32 result

Usage:
    ./scripts/gen_fst_fma_vectors.py --self-check
    ./scripts/gen_fst_fma_vectors.py --emit-testvalues
    ./scripts/gen_fst_fma_vectors.py --count 2048 --seed 12345 \
        --out build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_rand.hex
"""

import argparse
import json
import os
import random
import struct
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTVALUES_DIR = os.path.join(
    BASE, "testvalues", "fma",
    "test_values_muladd_bf16_bf16_fp32_fp32_fst_lat8")
TESTVALUES_JSON = os.path.join(
    TESTVALUES_DIR,
    "test_values_muladd_bf16_bf16_fp32_fp32_fst_lat8.json")

QNAN_F32 = 0x7FC00000
INF_F32 = 0x7F800000
F32_FRAC_MASK = 0x007FFFFF
SENTINEL_EXP = -1024


# =============================================================================
# Decode helpers
# =============================================================================

def bf16_decode(u16):
    """@brief Unpack BF16 into sign, exp, frac."""
    sign = (u16 >> 15) & 1
    exp = (u16 >> 7) & 0xFF
    frac = u16 & 0x7F
    return sign, exp, frac


def f32_decode(u32):
    """@brief Unpack FP32 into sign, exp, frac."""
    sign = (u32 >> 31) & 1
    exp = (u32 >> 23) & 0xFF
    frac = u32 & 0x7FFFFF
    return sign, exp, frac


# =============================================================================
# FAST FMA reference model
# =============================================================================

def fma_fst(a, b, s):
    """@brief Return the bit-exact FAST (RTZ/FTZ) FMA result.

    Implements the frozen contract from
    rules/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8.md.
    """
    a_sign, a_exp, a_frac = bf16_decode(a)
    b_sign, b_exp, b_frac = bf16_decode(b)
    s_sign, s_exp, s_frac = f32_decode(s)

    a_zero = (a_exp == 0)               # FTZ: zero and subnormal
    b_zero = (b_exp == 0)
    s_zero = (s_exp == 0)
    a_inf = (a_exp == 0xFF) and (a_frac == 0)
    b_inf = (b_exp == 0xFF) and (b_frac == 0)
    s_inf = (s_exp == 0xFF) and (s_frac == 0)
    a_nan = (a_exp == 0xFF) and (a_frac != 0)
    b_nan = (b_exp == 0xFF) and (b_frac != 0)
    s_nan = (s_exp == 0xFF) and (s_frac != 0)

    prod_sign = a_sign ^ b_sign
    prod_nan = a_nan or b_nan or (a_inf and b_zero) or (b_inf and a_zero)
    prod_inf = (not prod_nan) and (a_inf or b_inf)
    prod_zero = (not prod_nan) and (not prod_inf) and (a_zero or b_zero)

    res_nan = s_nan or prod_nan or (
        prod_inf and s_inf and (prod_sign != s_sign))
    res_inf = (not res_nan) and (prod_inf or s_inf)
    res_zero = (not res_nan) and (not res_inf) and prod_zero and s_zero

    if res_nan:
        return QNAN_F32
    if res_inf:
        sign = s_sign if s_inf else prod_sign
        return (sign << 31) | INF_F32
    if res_zero:
        return 0

    # Both operands are finite normal (FTZ removed subnormals/zeros above),
    # except the special cases handled above.
    a_man = 0 if a_zero else (0x80 | a_frac)
    b_man = 0 if b_zero else (0x80 | b_frac)
    s_man = 0 if s_zero else (0x800000 | s_frac)

    prod = a_man * b_man              # 16 bits, 0..65025
    if prod & 0x8000:
        p_norm = prod
    else:
        p_norm = (prod << 1) & 0xFFFF
    p24 = (p_norm << 8) & 0xFFFFFF
    exp_p = a_exp + b_exp - 130 + (1 if (prod & 0x8000) else 0)
    exp_s = s_exp - 3

    exp_p_eff = SENTINEL_EXP if prod_zero else exp_p
    exp_s_eff = SENTINEL_EXP if s_zero else exp_s

    if exp_p_eff > exp_s_eff:
        large_is_prod = True
        shift = exp_p_eff - exp_s_eff
    elif exp_p_eff < exp_s_eff:
        large_is_prod = False
        shift = exp_s_eff - exp_p_eff
    else:
        large_is_prod = (p24 >= s_man)
        shift = 0

    if large_is_prod:
        large_man = p24
        small_man = s_man
        large_exp = exp_p_eff
        large_sign = prod_sign
        small_sign = s_sign
    else:
        large_man = s_man
        small_man = p24
        large_exp = exp_s_eff
        large_sign = s_sign
        small_sign = prod_sign

    large_ext = large_man << 3        # 27 bits
    small_ext = small_man << 3        # 27 bits
    op_add = (large_sign == small_sign)

    # RTZ without sticky: all shifted-out bits are discarded.
    if shift >= 32:
        small_al = 0
    else:
        small_al = small_ext >> shift

    if op_add:
        man_raw = large_ext + small_al
    else:
        man_raw = large_ext - small_al

    # The datapath is only reached when the larger operand is really larger;
    # the subtraction cannot underflow.
    if man_raw < 0:
        raise ValueError(
            "man_raw underflow: a={:04X} b={:04X} s={:08X}".format(a, b, s))
    if man_raw >= (1 << 28):
        raise ValueError(
            "man_raw overflow: a={:04X} b={:04X} s={:08X}".format(a, b, s))

    carry = (man_raw >> 27) & 1
    if carry:
        man_norm0 = (man_raw >> 1) & 0x7FFFFFF
        exp_adj = large_exp + 1
    else:
        man_norm0 = man_raw & 0x7FFFFFF
        exp_adj = large_exp

    if man_raw == 0:
        lzd = 0
        is_zero = True
    else:
        p = man_raw.bit_length() - 1   # 0..27
        lzd = 0 if p == 27 else 26 - p
        is_zero = False

    man_norm = (man_norm0 << lzd) & 0x7FFFFFF
    exp_pre = exp_adj - lzd
    exp_f32 = exp_pre + 3
    sign = large_sign

    if is_zero:
        return 0
    if exp_f32 <= 0:
        return 0
    if exp_f32 >= 255:
        return (sign << 31) | INF_F32

    frac = (man_norm >> 3) & F32_FRAC_MASK
    return (sign << 31) | ((exp_f32 & 0xFF) << 23) | frac


# =============================================================================
# Directed test cases
# =============================================================================

def directed_cases():
    """@brief Return directed edge cases as (a, b, s, label) tuples."""
    cases = [
        # Basic arithmetic
        (0x3F80, 0x3F80, 0x3F800000, "1.0 + (1.0 × 1.0) = 2.0"),
        (0x4000, 0x4040, 0x00000000, "0.0 + (2.0 × 3.0) = 6.0"),
        (0x3F00, 0x3E80, 0x40A00000, "5.0 + (0.5 × 0.25) = 5.125"),
        (0xBFC0, 0x4080, 0x00000000, "0.0 + (-1.5 × 4.0) = -6.0"),
        (0x0000, 0x4040, 0x41200000, "10.0 + (0.0 × 3.0) = 10.0"),

        # Infinity / NaN
        (0x7F80, 0x4000, 0x00000000, "0.0 + (+Inf × 2.0) = +Inf"),
        (0x7F80, 0x0000, 0x00000000, "0.0 + (+Inf × 0.0) = qNaN"),
        (0x3F80, 0x3F80, 0x7FC00000, "NaN + (1.0 × 1.0) = qNaN"),
        (0x7F80, 0x3F80, 0xFF800000,
         "-Inf + (+Inf × 1.0) = qNaN (Inf − Inf)"),
        (0x7F80, 0xBF80, 0x7F800000,
         "+Inf + (+Inf × -1.0) = qNaN (Inf − Inf)"),
        (0x7F80, 0x3F80, 0x7F800000,
         "+Inf + (+Inf × 1.0) = +Inf (same-sign Inf)"),
        (0xFF80, 0x3F80, 0xFF800000,
         "-Inf + (-Inf × 1.0) = -Inf (same-sign Inf)"),
        (0xFF80, 0x3F80, 0x00000000, "0.0 + (-Inf × 1.0) = -Inf"),
        (0x7FC0, 0x3F80, 0x00000000, "0.0 + (NaN × 1.0) = qNaN"),
        (0x3F80, 0x7FC0, 0x00000000, "0.0 + (1.0 × NaN) = qNaN"),
        (0x7F81, 0x3F80, 0x00000000, "sNaN(BF16) -> canonical qNaN"),
        (0x7FC1, 0x3F80, 0x7FA00000,
         "two NaN with payload -> canonical qNaN"),
        (0x7F80, 0x4000, 0x7FC00000,
         "NaN-addend priority over Inf-product -> qNaN"),
        (0xFF80, 0x0000, 0x00000000, "-Inf × 0 -> qNaN"),
        (0x0000, 0x0000, 0xFF800000, "0 × 0 + (-Inf) = -Inf"),
        (0x7FC0, 0x3F80, 0xFF800000, "NaN × 1.0 + (-Inf) = qNaN (NaN priority)"),

        # FTZ and underflow
        (0x0080, 0x0080, 0x00000000,
         "0.0 + (min_normal_BF16 × min_normal_BF16) = +0 (underflow)"),
        (0x0001, 0x3F80, 0x00000000,
         "0.0 + (min_subnormal_BF16 × 1.0) = +0 (FTZ input)"),
        (0x0001, 0x3F80, 0x3F800000,
         "1.0 + (min_subnormal_BF16 × 1.0) = 1.0 (FTZ input)"),
        (0x3F80, 0x3F80, 0x00000001,
         "1.0 × 1.0 + min_subnormal_FP32 = 1.0 (FTZ SUMM)"),
        (0x0001, 0x3700, 0x00000000,
         "0.0 + (2^-133 × 2^-17) = +0 (FTZ underflow)"),
        (0x0001, 0x3700, 0x00000001,
         "2^-149 + 2^-150 -> +0 (FTZ SUMM and product)"),
        (0x0003, 0x3700, 0x00000000, "3·2^-150 -> +0 (FTZ underflow)"),
        (0x0001, 0x3700, 0x80000001,
         "-2^-149 + 2^-150 -> +0 (FAST zero rule)"),
        (0x0080, 0x0080, 0x00000001,
         "2^-252 + 2^-149 -> +0 (FTZ SUMM and product)"),
        (0x0001, 0x7F7F, 0x00000000,
         "min_subnormal × max_BF16 -> +0 (FTZ)"),
        (0x7F7F, 0x3F80, 0x00000001,
         "max_BF16 × 1.0 + min_subnormal_FP32 = max_BF16 (SUMM FTZ)"),

        # Signed zero and exact cancellation
        (0x3F80, 0xBF80, 0x3F800000,
         "1.0 + (1.0 × -1.0) = +0 (exact cancellation)"),
        (0x3F80, 0x3F80, 0xBF800000,
         "-1.0 + (1.0 × 1.0) = +0 (exact cancellation)"),
        (0x8000, 0x3F80, 0x80000000,
         "-0.0 + (-0.0 × 1.0) = +0 (FAST zero rule)"),
        (0x8000, 0xBF80, 0x80000000,
         "-0.0 + (-0.0 × -1.0) = +0 (FAST zero rule)"),
        (0x0000, 0x3F80, 0x80000000,
         "+0.0 + (+0.0 × 1.0) = +0 (FAST zero rule)"),

        # RTZ truncation and rounding boundaries
        (0x3F80, 0x3380, 0x3F800000,
         "1.0 + (1.0 × 2^-24) — RTZ half-ulp -> 1.0"),
        (0x3F80, 0x3381, 0x3F800000,
         "1.0 + (1.0 × (2^-24 + 2^-31)) — RTZ above half-ulp -> 1.0"),
        (0x3F80, 0x3301, 0x3F800000,
         "1.0 + (1.0 × (2^-25 + 2^-32)) — RTZ below half-ulp -> 1.0"),
        (0x3F80, 0xB3C0, 0x3F800000,
         "1.0 - (1.0 × 3·2^-25) — RTZ subtraction"),
        (0x3300, 0x3F80, 0x3F7FFFFF,
         "tie across binade boundary — RTZ -> 1−2^-24"),

        # Overflow / underflow boundaries
        (0x7F7F, 0x4000, 0x00000000,
         "0.0 + (max_BF16 × 2.0) = +Inf (product overflow)"),
        (0x7300, 0x3F80, 0x7F7FFFFF,
         "FP32_max + 2^103 — RTZ overflow boundary -> FP32_max"),
        (0x7280, 0x3F80, 0x7F7FFFFF,
         "FP32_max + 2^102 — RTZ below boundary -> FP32_max"),
        (0xF300, 0x3F80, 0xFF7FFFFF,
         "-FP32_max - 2^103 — RTZ overflow boundary -> -FP32_max"),
        (0x7F7F, 0x3F80, 0x7F7FFFFF,
         "FP32_max + max_BF16 -> +Inf (overflow)"),
        (0x3F80, 0x3F80, 0xFF7FFFFF,
         "-FP32_max + (1.0 × 1.0) = -FP32_max (absorbed)"),
        (0x7F7F, 0x7F7F, 0x00000000,
         "max_BF16 × max_BF16 -> +Inf (product overflow)"),
        (0xFF7F, 0x7F7F, 0x00000000,
         "-max_BF16 × max_BF16 -> -Inf (product overflow)"),

        # Normalization / alignment
        (0x3FC0, 0x3FC0, 0x3F400000,
         "1.5 × 1.5 + 0.75 = 3.0 (carry)"),
        (0x3F80, 0x3F80, 0x3FC00000,
         "1.5 + (1.0 × 1.0) = 2.5 (p24 < s_man)"),
        (0x3F80, 0xBF80, 0x3F400000,
         "0.75 + (1.0 × -1.0) = -0.25 (large = SUMM)"),
        (0x3F80, 0x3F80, 0x0D800000,
         "2^-100 + (1.0 × 1.0) = 1.0 (shift saturation)"),
        (0x0D80, 0x0D80, 0x3F800000,
         "2^-200 + 1.0 = 1.0 (tiny product)"),
        (0xBFFF, 0x4B00, 0x4B7FFFFF,
         "(2^24−1) − (2^24−2^16) — 24-bit normalization"),
        (0xBF7F, 0x0080, 0x00800000,
         "2^-126 − (1−2^-8)·2^-126 = 2^-134 -> +0 (FTZ)"),
    ]

    result = []
    for a, b, s, label in cases:
        result.append((a, b, s, fma_fst(a, b, s), label))
    return result


# =============================================================================
# Random test cases
# =============================================================================

def random_cases(count, seed):
    """@brief Return `count` deterministic random (a, b, s) triples."""
    rng = random.Random(seed)
    return [(rng.getrandbits(16), rng.getrandbits(16), rng.getrandbits(32))
            for _ in range(count)]


# =============================================================================
# Formatting helpers
# =============================================================================

def f32_value(u):
    """@brief Human-readable value for an FP32 word (FAST zero is always +0)."""
    exp = (u >> 23) & 0xFF
    frac = u & 0x7FFFFF
    sign = (u >> 31) & 1
    if exp == 0xFF:
        if frac == 0:
            return "-Inf" if sign else "+Inf"
        return "qNaN"
    if exp == 0:
        return "+0"
    v = struct.unpack("<f", struct.pack("<I", u))[0]
    return repr(v)


def bf16_bitstruct(u16):
    """@brief Human-readable BF16 bit structure."""
    s, e, f = bf16_decode(u16)
    return "s:{}, exp:{} (0x{:02X}), mant:{} (0x{:02X})".format(s, e, e, f, f)


def f32_bitstruct(u32):
    """@brief Human-readable FP32 bit structure."""
    s, e, f = f32_decode(u32)
    return "s:{}, exp:{} (0x{:02X}), mant:{} (0x{:06X})".format(s, e, e, f, f)


# =============================================================================
# Self-check
# =============================================================================

def self_check():
    """@brief Validate the reference model against the JSON test vectors."""
    if not os.path.exists(TESTVALUES_JSON):
        print("FAIL: testvalues JSON not found: {}".format(TESTVALUES_JSON))
        return 1

    with open(TESTVALUES_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    errors = 0
    total = 0
    for group in ("test_vectors", "extended_vectors"):
        for item in data.get(group, []):
            a = int(item["input_a"]["hex"], 16)
            b = int(item["input_b"]["hex"], 16)
            s = int(item["input_s"]["hex"], 16)
            exp = int(item["output_c"]["hex"], 16)
            got = fma_fst(a, b, s)
            total += 1
            if got != exp:
                errors += 1
                print(
                    "FAIL #{no}: a={a:04X} b={b:04X} s={s:08X} "
                    "exp={exp:08X} got={got:08X}".format(
                        no=item["no"], a=a, b=b, s=s, exp=exp, got=got))
    print("checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


# =============================================================================
# Testvalues emission
# =============================================================================

def emit_testvalues(outdir):
    """@brief Emit testvalues JSON + Markdown from the verified model."""
    cases = directed_cases()

    test_vectors = []
    for idx, (a, b, s, exp, label) in enumerate(cases, start=1):
        test_vectors.append({
            "no": idx,
            "operation": label,
            "input_a": {
                "hex": "0x{:04X}".format(a),
                "bf16": "16'h{:04X}".format(a),
                "bit_structure": bf16_bitstruct(a),
            },
            "input_b": {
                "hex": "0x{:04X}".format(b),
                "bf16": "16'h{:04X}".format(b),
                "bit_structure": bf16_bitstruct(b),
            },
            "input_s": {
                "hex": "0x{:08X}".format(s),
                "f32": "32'h{:08X}".format(s),
                "bit_structure": f32_bitstruct(s),
            },
            "output_c": {
                "hex": "0x{:08X}".format(exp),
                "f32": "32'h{:08X}".format(exp),
                "value": f32_value(exp),
            },
            "test_description": label,
        })

    data = {
        "$schema": (
            "bf16xbf16+f32 -> f32 fused multiply-add FAST (RTZ/FTZ) "
            "test vectors"),
        "format": {
            "input_a": "BF16 VALA (1s/8e/7m)",
            "input_b": "BF16 VALB (1s/8e/7m)",
            "input_s": "FP32 SUMM (1s/8e/23m)",
            "output_c": (
                "FP32 RESULT = SUMM + (VALA × VALB), RTZ rounding, "
                "FTZ on inputs and output"),
            "special_cases": (
                "NaN in -> qNaN 0x7FC00000; Inf*finite + same-sign Inf -> Inf; "
                "Inf*finite + opposite-sign Inf -> qNaN; zero*finite + finite "
                "-> finite; exact cancellation x + (-x) -> +0; all zero "
                "results -> +0; underflow -> +0; overflow -> +/-Inf"),
            "note": (
                "BF16 and FP32 subnormal operands are flushed to zero (FTZ). "
                "No F32 subnormal results are produced. The product is exact; "
                "the single final rounding is RTZ (truncation)."),
            "zero_sign_rules": (
                "FAST: -0 + -0 = +0; -0 + +0 = +0; exact cancellation "
                "x + (-x) = +0; underflow to zero -> +0"),
        },
        "test_vectors": test_vectors,
        "metadata": {
            "title": (
                "BF16 x BF16 + FP32 -> FP32 (fst_lat8, RTZ/FTZ) test vectors"),
            "source": (
                "rules/fma/"
                "vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8.md "
                "(frozen contract)"),
            "generator": "scripts/gen_fst_fma_vectors.py",
            "vector_count": len(test_vectors),
            "special_values": {
                "infinity": "0x7F800000 / 0xFF800000",
                "quiet_nan": "0x7FC00000",
                "positive_zero": "0x00000000",
                "negative_zero": "0x80000000 (input only; output is +0)",
            },
        },
    }

    os.makedirs(outdir, exist_ok=True)
    json_path = os.path.join(
        outdir, "test_values_muladd_bf16_bf16_fp32_fp32_fst_lat8.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    md_lines = [
        "# Тестовые векторы для "
        "`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`",
        "",
        "Операция: `RESULT = SUMM + (VALA_BF16 × VALB_BF16)`, "
        "FP32 output, **RTZ** rounding, **FTZ** on inputs and output.",
        "",
        "## Формат",
        "",
        "Каждая строка: `VALA_BF16 VALB_BF16 SUMM_FP32 RESULT_FP32 "
        "# комментарий`",
        "",
        "Все значения в шестнадцатеричном формате, без хвостовых пробелов.",
        "",
        "## Правила FAST",
        "",
        "| Случай | Результат |",
        "|---|---|",
        "| Любой NaN | canonical qNaN `0x7FC00000` |",
        "| `Inf × finite` + `±Inf` | `±Inf` / qNaN при разных знаках |",
        "| `Inf × 0` | qNaN |",
        "| Subnormal вход BF16/FP32 | трактуется как 0 (FTZ) |",
        "| Subnormal результат | `+0` (FTZ) |",
        "| Переполнение FP32 | `±Inf` |",
        "| Точная отмена `x + (-x)` | `+0` |",
        "| Любой нулевой результат | `+0` (знак не сохраняется) |",
        "",
        "## Тестовые векторы ({} всего)".format(len(test_vectors)),
        "",
        "| # | VALA | VALB | SUMM | EXPECTED | Описание |",
        "|---|------|------|------|----------|----------|",
    ]
    for idx, (a, b, s, exp, label) in enumerate(cases, start=1):
        md_lines.append(
            "| {} | `{:04X}` | `{:04X}` | `{:08X}` | `{:08X}` | {} |".format(
                idx, a, b, s, exp, label))

    md_path = os.path.join(
        outdir, "test_values_muladd_bf16_bf16_fp32_fp32_fst_lat8.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines) + "\n")

    print("wrote {}\n      {}".format(json_path, md_path))
    return 0


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate BF16 x BF16 + FP32 -> FP32 FAST (RTZ/FTZ) "
            "test vectors"))
    parser.add_argument("--count", type=int, default=2048,
                        help="total number of vectors (default: 2048)")
    parser.add_argument("--seed", type=int, default=12345,
                        help="random seed (default: 12345)")
    parser.add_argument(
        "--out",
        default=(
            "build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_rand.hex"),
        help="output hex file")
    parser.add_argument("--self-check", action="store_true",
                        help="validate the model against docs JSON")
    parser.add_argument("--emit-testvalues", action="store_true",
                        help="write testvalues JSON/MD from the verified model")
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    if args.emit_testvalues:
        return emit_testvalues(TESTVALUES_DIR)

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
        cases.append((a, b, s, fma_fst(a, b, s), "random"))

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
