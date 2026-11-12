#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_f32_vectors.py
@brief Generate and validate BF16 x BF16 -> Float32 test vectors.

The generator uses a bit-exact reference model of the planned
`vhfastmulb16_f32_lat4` DUT:
  * normal products are represented exactly in F32;
  * F32 subnormal results are truncated (RTZ), no rounding;
  * BF16 subnormal inputs are not flushed to zero;
  * NaN result is canonical quiet NaN 0x7FC00000;
  * exception priority is NaN > Inf > Zero;
  * Inf * 0 -> canonical qNaN;
  * Inf * finite (including BF16 subnormal) -> Inf with XOR sign;
  * zero * finite -> signed zero with XOR sign.

Output format (one 64-bit hexadecimal word per line):
    bits[63:48] = BF16 operand A
    bits[47:32] = BF16 operand B
    bits[31:0]  = expected F32 result

Usage:
    ./scripts/gen_f32_vectors.py --out build/vhfastmulb16_f32_lat4_rand.hex
    ./scripts/gen_f32_vectors.py --count 4096 --seed 1234 --out build/vectors.hex
    ./scripts/gen_f32_vectors.py --self-check
"""

import argparse
import json
import os
import random
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTVALUES_JSON = os.path.join(
    BASE, "testvalues", "test_values_mul_bf16_bf16_fp32",
    "test_values_mul_bf16_bf16_fp32.json")

QNAN_F32 = 0x7FC00000
INF_F32 = 0x7F800000


def bf16_product_f32(a, b):
    """@brief Return the bit-exact F32 product of two BF16 words.

    Implements the same semantics as vhfastmulb16_f32_lat4:
    canonical qNaN, no FTZ for BF16 subnormals, RTZ for F32 subnormals.
    """
    a_sign = (a >> 15) & 1
    b_sign = (b >> 15) & 1
    a_exp = (a >> 7) & 0xFF
    b_exp = (b >> 7) & 0xFF
    a_frac = a & 0x7F
    b_frac = b & 0x7F

    a_zero = (a_exp == 0) and (a_frac == 0)
    b_zero = (b_exp == 0) and (b_frac == 0)
    a_inf = (a_exp == 0xFF) and (a_frac == 0)
    b_inf = (b_exp == 0xFF) and (b_frac == 0)
    a_nan = (a_exp == 0xFF) and (a_frac != 0)
    b_nan = (b_exp == 0xFF) and (b_frac != 0)

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

    # BF16 subnormal and normal operands share the same decode:
    #   e_eff = 1 for exp=0, otherwise exp
    #   M     = {exp!=0, frac}
    a_exp_eff = 1 if a_exp == 0 else a_exp
    b_exp_eff = 1 if b_exp == 0 else b_exp
    a_man = (0x80 if a_exp != 0 else 0x00) | a_frac
    b_man = (0x80 if b_exp != 0 else 0x00) | b_frac

    prod = a_man * b_man
    if prod == 0:
        return sign << 31

    k = prod.bit_length() - 1
    exp_unb = a_exp_eff + b_exp_eff + k

    if exp_unb >= 396:
        # F32 overflow.
        return (sign << 31) | INF_F32

    if exp_unb >= 142:
        # Normal F32 result: exact.
        exp_field = exp_unb - 141
        frac = (prod << (23 - k)) & 0x7FFFFF
        return (sign << 31) | (exp_field << 23) | frac

    # F32 subnormal result: truncate (RTZ).
    shift = 142 - exp_unb
    if shift >= 24:
        return sign << 31
    frac = ((prod << (23 - k)) >> shift) & 0x7FFFFF
    return (sign << 31) | frac


def directed_cases():
    """@brief Return directed edge cases as (a, b, expected, label) tuples."""
    cases = [
        # Main and extended vectors from testvalues/test_values_mul_bf16_bf16_fp32/test_values_mul_bf16_bf16_fp32.json
        (0x3F80, 0x3F80, "1.0 * 1.0"),
        (0x4000, 0x4060, "2.0 * 3.5"),
        (0xBFC0, 0x4080, "-1.5 * 4.0"),
        (0x3F00, 0x3E80, "0.5 * 0.25"),
        (0x4300, 0x3C00, "128.0 * 0.0078125"),
        (0x4049, 0x4000, "3.140625 * 2.0"),
        (0xC2C8, 0xBDCD, "-100.0 * -0.10009765625"),
        (0x4120, 0x3E9A, "10.0 * 0.30078125"),
        (0x3F80, 0x0000, "1.0 * 0.0"),
        (0x7F80, 0x4000, "+Inf * 2.0"),
        (0xFF80, 0x7F80, "-Inf * +Inf"),
        (0x7F80, 0x0000, "+Inf * 0.0"),
        (0x7FC0, 0x40A0, "NaN * 5.0"),
        (0x7FC0, 0x7F80, "NaN * +Inf"),
        (0x0000, 0x0000, "0.0 * 0.0"),
        (0xFF80, 0x8000, "-Inf * -0.0"),
        (0x7F7F, 0x7F7F, "max_BF16 * max_BF16"),
        (0x0001, 0x0001, "min_subnormal^2"),
        (0x0001, 0x3F80, "min_subnormal * 1.0"),
        (0x8000, 0x3F80, "-0.0 * 1.0"),
        # Additional F32 edge cases and RTZ checks
        (0x0003, 0x3700, "subnormal RTZ: 3*2^-150 -> 1*2^-149"),
        (0x0001, 0x3700, "subnormal underflow: 2^-150 -> 0"),
        (0x0001, 0x3780, "subnormal exact: 2^-149"),
        (0x0003, 0x3780, "subnormal exact: 3*2^-149"),
        (0x0001, 0x7F80, "subnormal * +Inf -> +Inf"),
        (0x8001, 0x0000, "negative subnormal * +0 -> -0"),
        (0x0001, 0x7FC0, "subnormal * NaN -> qNaN"),
        (0x7F7F, 0x3F80, "max_BF16 * 1.0 -> 0x7F7F0000"),
        (0x7F7F, 0x4000, "max_BF16 * 2.0 -> +Inf"),
        (0x0080, 0x0080, "min_normal^2 -> 0"),
        (0x8003, 0x3700, "negative subnormal RTZ"),
        (0x7FC1, 0x3F80, "NaN with payload -> canonical qNaN"),
    ]
    return [(a, b, bf16_product_f32(a, b), label) for a, b, label in cases]


def random_cases(count, seed):
    """@brief Return `count` deterministic random BF16 pairs."""
    rng = random.Random(seed)
    return [(rng.getrandbits(16), rng.getrandbits(16)) for _ in range(count)]


def self_check():
    """@brief Validate the reference model against docs JSON test vectors."""
    with open(TESTVALUES_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    errors = 0
    total = 0
    for group in ("test_vectors", "extended_vectors"):
        for item in data.get(group, []):
            a = int(item["input_a"]["hex"], 16)
            b = int(item["input_b"]["hex"], 16)
            exp = int(item["output_c"]["float32"]["hex"], 16)
            got = bf16_product_f32(a, b)
            total += 1
            if got != exp:
                errors += 1
                print(
                    "FAIL #{no}: a={a:04X} b={b:04X} exp={exp:08X} got={got:08X}".format(
                        no=item["no"], a=a, b=b, exp=exp, got=got
                    )
                )
    print("checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


def main():
    parser = argparse.ArgumentParser(description="Generate BF16 x BF16 -> F32 test vectors")
    parser.add_argument("--count", type=int, default=2048, help="total number of vectors (default: 2048)")
    parser.add_argument("--seed", type=int, default=12345, help="random seed (default: 12345)")
    parser.add_argument("--out", default="build/vhfastmulb16_f32_lat4_rand.hex", help="output hex file")
    parser.add_argument("--self-check", action="store_true", help="validate the model against docs JSON")
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    if args.count < 1:
        print("ERROR: --count must be positive", file=sys.stderr)
        return 2

    cases = directed_cases()
    if len(cases) > args.count:
        print(
            "ERROR: --count={} is less than {} directed cases".format(args.count, len(cases)),
            file=sys.stderr,
        )
        return 2

    rand_count = args.count - len(cases)
    for a, b in random_cases(rand_count, args.seed):
        cases.append((a, b, bf16_product_f32(a, b), "random"))

    out_path = args.out
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, exp, _label in cases:
            f.write("{:04X}{:04X}{:08X}\n".format(a, b, exp))

    print("generated {} vectors -> {}".format(len(cases), out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
