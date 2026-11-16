#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_fst_bf16_vectors.py
@brief Generate BF16 x BF16 -> BF16 (FAST variant, RTZ/FTZ) test vectors.

Bit-exact reference model of the planned DUT
`vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3`:

  * operands: BF16 [15] sign | [14:7] exp (bias 127) | [6:0] frac;
  * FTZ on inputs: exp==0 (zero or subnormal) -> operand treated as zero;
    effective mantissa M = (exp==0) ? 0 : (0x80 | frac);
  * exact 16-bit product P = M_a * M_b;
    biased exponent sum S = (exp_a + exp_b - 127) mod 512 (like add8x8_lat2);
  * normalization: prod_n = P[14:0] if P[15] else P[13:0], k = P[15];
    biased result exponent E = (S + k) mod 512 (bias 127);
  * rounding: RTZ (truncation): mant = prod_n[14:8] (top 7 bits);
  * overflow:  exp_overflow = (S <= 381) && (E > 254) -> signed Inf;
  * underflow: exp_underflow = (S > 381) || (E == 0) -> signed zero;
  * NaN: canonical quiet NaN 0x7FC0 (payload not propagated, sign not applied);
  * sign: sign_a XOR sign_b applied to Inf/zero/normal results (not to NaN);
  * exception priority: NaN > Inf > Zero > Underflow > Overflow > Normal.

Output format (one 48-bit hexadecimal word per line):
    bits[47:32] = BF16 operand A
    bits[31:16] = BF16 operand B
    bits[15:0]  = expected BF16 result

Usage:
    ./scripts/gen_fst_bf16_vectors.py --out build/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_rand.hex
    ./scripts/gen_fst_bf16_vectors.py --count 2048 --seed 12345 --out build/vectors.hex
    ./scripts/gen_fst_bf16_vectors.py --self-check
"""

import argparse
import json
import os
import random
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTVALUES_JSON = os.path.join(
    BASE, "testvalues", "mul", "test_values_mul_bf16_bf16_bf16",
    "test_values_mul_bf16_bf16_fst_rtz.json")

QNAN_BF16 = 0x7FC0
INF_BF16 = 0x7F80


def mul_bf16_fst_rtz(a, b):
    """@brief Return the bit-exact BF16 (FAST, RTZ/FTZ) product of two BF16 words.

    Implements the frozen contract from
    rules/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.md.
    """
    a_sign = (a >> 15) & 1
    b_sign = (b >> 15) & 1
    a_exp = (a >> 7) & 0xFF
    b_exp = (b >> 7) & 0xFF
    a_frac = a & 0x7F
    b_frac = b & 0x7F

    sign = a_sign ^ b_sign

    a_zero = (a_exp == 0)               # FTZ: zero and subnormal
    b_zero = (b_exp == 0)
    a_inf = (a_exp == 0xFF) and (a_frac == 0)
    b_inf = (b_exp == 0xFF) and (b_frac == 0)
    a_nan = (a_exp == 0xFF) and (a_frac != 0)
    b_nan = (b_exp == 0xFF) and (b_frac != 0)

    res_nan = a_nan or b_nan or (a_inf and b_zero) or (b_inf and a_zero)
    res_inf = (not res_nan) and (a_inf or b_inf)
    res_zero = (not res_nan) and (not res_inf) and (a_zero or b_zero)

    if res_nan:
        return QNAN_BF16
    if res_inf:
        return (sign << 15) | INF_BF16
    if res_zero:
        return (sign << 15)

    # Both operands are finite normal (FTZ removed subnormals/zeros above).
    a_man = 0x80 | a_frac
    b_man = 0x80 | b_frac

    prod = a_man * b_man                # 16 bits, 0..65025

    if prod == 0:
        return (sign << 15)

    if prod >= 0x8000:
        # MSB set: hidden bit at P[15]
        man_norm = (prod >> 8) & 0x7F
        k = 1
    else:
        man_norm = (prod >> 7) & 0x7F
        k = 0

    # exp_sum = a_exp + b_exp - 127 (mod 512), identical to vhfastmulb16_add8x8_lat2
    exp_sum = (a_exp + b_exp - 127) & 0x1FF
    exp_n = (exp_sum + k) & 0x1FF

    # Same bounds as vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3.v / rne_lat3.v
    exp_underflow = (exp_sum > 381) or (exp_n == 0)
    exp_overflow = (exp_sum <= 381) and (exp_n > 254)

    if exp_underflow:
        return (sign << 15)
    if exp_overflow:
        return (sign << 15) | INF_BF16

    return (sign << 15) | ((exp_n & 0xFF) << 7) | man_norm


def directed_cases():
    """@brief Return directed edge cases as (a, b, expected, label) tuples."""
    cases = [
        # Base vectors (match test_values_mul_bf16_rtz.md rows 1-16)
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

        # Additional directed cases: FTZ / underflow / overflow / signs
        (0x0001, 0x3F80, "min_subnormal * 1.0 (FTZ -> 0)"),
        (0x8000, 0x3F80, "-0.0 * 1.0 (sign)"),
        (0x0080, 0x0080, "min_normal * min_normal (underflow -> 0)"),
        (0x7F7F, 0x7F7F, "max_BF16 * max_BF16 (overflow -> Inf)"),
        (0x7F7F, 0x3F80, "max_BF16 * 1.0 (normal)"),
        (0x4000, 0x4000, "2.0 * 2.0 = 4.0"),
        (0x4080, 0x4000, "4.0 * 2.0 = 8.0"),
        (0xC000, 0x3F80, "-2.0 * 1.0 = -2.0"),
        (0x4000, 0xBF80, "2.0 * -1.0 = -2.0"),
        (0xBF80, 0xBF80, "-1.0 * -1.0 = 1.0"),
        (0x7F00, 0x7F00, "large * large (near overflow)"),
        (0x0100, 0x0100, "small normal * small normal"),
        (0x3F80, 0xBF80, "1.0 * -1.0 = -1.0"),
    ]

    result = []
    for a, b, label in cases:
        exp = mul_bf16_fst_rtz(a, b)
        result.append((a, b, exp, label))
    return result


def random_cases(count, seed):
    """@brief Return `count` deterministic random BF16 pairs."""
    rng = random.Random(seed)
    return [(rng.getrandbits(16), rng.getrandbits(16)) for _ in range(count)]


def self_check():
    """@brief Validate the reference model against docs JSON test vectors.

    Supports two JSON layouts:
      * "output_c": {"hex": ...}                      (fst/fp32 family)
      * "output_c": {"bf16": {"hex": ...}}            (rtz/rne bf16 family)
    """
    if not os.path.exists(TESTVALUES_JSON):
        print("FAIL: testvalues JSON not found: {}".format(TESTVALUES_JSON))
        return 1

    with open(TESTVALUES_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    def out_hex(item):
        """@brief Extract expected output hex from either JSON layout."""
        oc = item["output_c"]
        if isinstance(oc, dict):
            if "hex" in oc:
                return oc["hex"]
            if "bf16" in oc:
                return oc["bf16"]["hex"]
        raise KeyError("unsupported output_c layout in item {}".format(item.get("no")))

    def in_hex(item, key):
        """@brief Extract input hex from either JSON layout."""
        ia = item["input_" + key]
        if isinstance(ia, dict):
            return ia["hex"] if "hex" in ia else ia["bf16"]
        return ia

    errors = 0
    total = 0
    for group in ("test_vectors", "extended_vectors"):
        for item in data.get(group, []):
            a = int(in_hex(item, "a"), 16)
            b = int(in_hex(item, "b"), 16)
            exp = int(out_hex(item), 16)
            got = mul_bf16_fst_rtz(a, b)
            total += 1
            if got != exp:
                errors += 1
                print(
                    "FAIL #{no}: a={a:04X} b={b:04X} exp={exp:04X} got={got:04X}".format(
                        no=item["no"], a=a, b=b, exp=exp, got=got
                    )
                )
    print("checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


def bf16_bitstruct(u16):
    """@brief Human-readable BF16 bit structure: s:0, exp:127 (0x7F), mant:0 (0x00)."""
    s = (u16 >> 15) & 1
    e = (u16 >> 7) & 0xFF
    f = u16 & 0x7F
    return "s:{s}, exp:{e} ({e:#04x}), mant:{f} ({f:#04x})".format(s=s, e=e, f=f)


def emit_testvalues(outdir):
    """@brief Emit testvalues JSON + Markdown from the verified reference model.

    Writes:
      * <outdir>/test_values_mul_bf16_bf16_fst_rtz.json
      * <outdir>/test_values_mul_bf16_bf16_fst_rtz.md
      * <outdir>/test_values_mul_bf16_bf16_fst_details.md
    """
    cases = directed_cases()
    base_count = 16  # rows 1..16 mirror the classic mul table

    test_vectors = []
    extended_vectors = []
    for idx, (a, b, exp, label) in enumerate(cases, start=1):
        item = {
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
            "output_c": {
                "hex": "0x{:04X}".format(exp),
                "bf16": "16'h{:04X}".format(exp),
                "bit_structure": bf16_bitstruct(exp),
            },
            "test_description": label,
        }
        if idx <= base_count:
            test_vectors.append(item)
        else:
            extended_vectors.append(item)

    data = {
        "$schema": "vhfastmulb16 testvectors v1",
        "format": {
            "input": "BF16 (1s/8e/7m)",
            "output": "BF16 (1s/8e/7m) = product rounded RTZ, FTZ on inputs",
            "output_c": "BF16 column = result of vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3 (canonical qNaN 0x7FC0, no sign on NaN)",
            "special_cases": "NaN in -> qNaN 0x7FC0; Inf*0 -> qNaN 0x7FC0; Inf*finite -> Inf with XOR sign; zero*finite -> signed zero with XOR sign; exp==0 (FTZ) treated as zero",
        },
        "test_vectors": test_vectors,
        "extended_vectors": extended_vectors,
        "metadata": {
            "title": "BF16 x BF16 -> BF16 (fst_lat3, RTZ/FTZ) test vectors",
            "source": "rules/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.md (frozen contract)",
            "generator": "scripts/gen_fst_bf16_vectors.py",
            "vector_count": len(test_vectors),
            "extended_vector_count": len(extended_vectors),
            "special_values": {
                "infinity": "0x7F80 / 0xFF80",
                "quiet_nan": "0x7FC0",
                "positive_zero": "0x0000",
                "negative_zero": "0x8000",
            },
        },
    }

    json_path = os.path.join(outdir, "test_values_mul_bf16_bf16_fst_rtz.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # Compact matrix MD (like test_values_mul_bf16_rtz.md)
    md_lines = [
        "# BF16 Multiplication Test Vector Matrix (FAST / fst_lat3, RTZ)",
        "",
        "BF16 Multiplication: A * B = C",
        "",
        "FAST variant (`vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3`): RTZ, FTZ on inputs,",
        "canonical quiet NaN `0x7FC0` (no sign), sign = XOR on Inf/zero/normal.",
        "",
        "| № | A | B | C |",
        "| :-: | :-: | :-: | :-: |",
    ]
    for idx, (a, b, exp, _label) in enumerate(cases, start=1):
        md_lines.append("| {:2} | `16'h{:04X}` | `16'h{:04X}` | `16'h{:04X}` |".format(idx, a, b, exp))
    md_path = os.path.join(outdir, "test_values_mul_bf16_bf16_fst_rtz.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines) + "\n")

    # Detailed table MD (like test_values_mul_bf16_bf16_details.md)
    det = [
        "BF16 Multiplication Test Vector Table (FAST / fst_lat3, RTZ)",
        "",
        "| No. | Operation | Input A (`inarr_a`) | Bit structure A | Input B (`inarr_b`) | Bit structure B | Output C (`outarr_c`) | Bit structure C (Expected) | Test description |",
        "| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |",
    ]
    for idx, (a, b, exp, label) in enumerate(cases, start=1):
        det.append(
            "| {no} | {op} | `16'h{a:04X}` | {abs_} | `16'h{b:04X}` | {bbs} | `16'h{e:04X}` | {ebs} | {desc} |".format(
                no=idx, op=label, a=a, b=b, e=exp,
                abs_=bf16_bitstruct(a), bbs=bf16_bitstruct(b), ebs=bf16_bitstruct(exp),
                desc=label)
        )
    det_path = os.path.join(outdir, "test_values_mul_bf16_bf16_fst_details.md")
    with open(det_path, "w", encoding="utf-8") as f:
        f.write("\n".join(det) + "\n")

    print("wrote {}\n      {}\n      {}".format(json_path, md_path, det_path))
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Generate BF16 x BF16 -> BF16 (fst_lat3, RTZ/FTZ) test vectors")
    parser.add_argument("--count", type=int, default=2048,
                        help="total number of vectors (default: 2048)")
    parser.add_argument("--seed", type=int, default=12345,
                        help="random seed (default: 12345)")
    parser.add_argument("--out", default="build/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_rand.hex",
                        help="output hex file")
    parser.add_argument("--self-check", action="store_true",
                        help="validate the model against docs JSON")
    parser.add_argument("--emit-testvalues", action="store_true",
                        help="write testvalues JSON/MD from the verified model")
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    if args.emit_testvalues:
        outdir = os.path.join(
            BASE, "testvalues", "mul", "test_values_mul_bf16_bf16_bf16")
        return emit_testvalues(outdir)

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
        exp = mul_bf16_fst_rtz(a, b)
        cases.append((a, b, exp, "random"))

    out_path = args.out
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, exp, _label in cases:
            f.write("{:04X}{:04X}{:04X}\n".format(a, b, exp))

    print("generated {} vectors -> {}".format(len(cases), out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())