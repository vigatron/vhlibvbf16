#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file check_test_values.py
@brief Validator for the BF16 x BF16 -> F32 test vector tables.

Checks that the expected results stored in
`docs/test_values_mul_bf16_bf16_f32.json` and `docs/test_values_mul_bf16_bf16_f32.md`
match the value recomputed from the BF16 operands.

Semantics being checked:
  * F32 output = exact product of the two BF16 values (no intermediate BF16 rounding);
  * BF16 reference column = product rounded to nearest even (RNE);
  * special cases: NaN in -> quiet NaN, Inf*0 -> quiet NaN, Inf*finite -> Inf
    with sign = XOR of signs, zero*finite -> zero with sign = XOR of signs.

Usage:
    ./scripts/check_test_values.py [--quiet]

Exit code: 0 - all vectors match, 1 - mismatches found.
"""

import json
import math
import os
import re
import struct
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(BASE, "docs")
JSON_PATH = os.path.join(DOCS, "test_values_mul_bf16_bf16_f32.json")
MD_PATH = os.path.join(DOCS, "test_values_mul_bf16_bf16_f32.md")

QNAN_BF16 = 0x7FC0
QNAN_F32 = 0x7FC00000
INF_BF16 = 0x7F80
INF_F32 = 0x7F800000


def bf16_is_nan(a):
    """@brief Check that a BF16 word is NaN."""
    return ((a >> 7) & 0xFF) == 0xFF and (a & 0x7F) != 0


def bf16_is_inf(a):
    """@brief Check that a BF16 word is infinity."""
    return ((a >> 7) & 0xFF) == 0xFF and (a & 0x7F) == 0


def bf16_is_zero(a):
    """@brief Check that a BF16 word is +0.0 or -0.0."""
    return (a & 0x7FFF) == 0


def bf16_to_float(a):
    """@brief Decode a finite BF16 word into a Python float (exact)."""
    s = (a >> 15) & 1
    e = (a >> 7) & 0xFF
    m = a & 0x7F
    if e == 0:
        return (-1.0) ** s * (m / 128.0) * 2.0 ** -126
    return (-1.0) ** s * (1.0 + m / 128.0) * 2.0 ** (e - 127)


def float_to_bf16_rne(x):
    """@brief Round a positive-or-negative float to BF16 using RNE."""
    sign = 0
    if math.copysign(1.0, x) < 0:
        sign = 1
        x = -x
    if x == 0.0:
        return sign << 15
    e = math.floor(math.log2(x))
    if e < -126:
        return (sign << 15) | int(round(x / 2.0 ** -126 * 128.0))
    m = (x / 2.0 ** e - 1.0) * 128.0
    mi = int(round(m))
    ee = e + 127
    if mi == 128:
        mi = 0
        ee += 1
    if ee >= 0xFF:
        return (sign << 15) | INF_BF16
    return (sign << 15) | (ee << 7) | mi


def mul_bf16(a, b):
    """@brief Multiply two BF16 words.

    @return Tuple (bf16_rne, f32_exact): BF16 result rounded RNE and exact
            product encoded as IEEE-754 binary32.
    """
    if bf16_is_nan(a) or bf16_is_nan(b):
        return QNAN_BF16, QNAN_F32
    if (bf16_is_inf(a) and bf16_is_zero(b)) or (bf16_is_inf(b) and bf16_is_zero(a)):
        return QNAN_BF16, QNAN_F32
    sign = ((a >> 15) ^ (b >> 15)) & 1
    if bf16_is_inf(a) or bf16_is_inf(b):
        return (sign << 15) | INF_BF16, (sign << 31) | INF_F32
    if bf16_is_zero(a) or bf16_is_zero(b):
        return sign << 15, sign << 31
    p = bf16_to_float(a) * bf16_to_float(b)
    try:
        u = struct.unpack("<I", struct.pack("<f", p))[0]
    except OverflowError:
        u = (sign << 31) | INF_F32
    return float_to_bf16_rne(p), u


def f32_to_float(u):
    """@brief Decode a binary32 word into a Python float."""
    return struct.unpack("<f", struct.pack("<I", u))[0]


def f32_bits(u):
    """@brief Format a binary32 word as a 32 character binary string."""
    return format(u, "032b")


def bf16_struct_str(a):
    """@brief Format a BF16 word as 's:.., exp:.. (..), mant:.. (..)'."""
    return "s:%d, exp:%d (0x%02X), mant:%d (0x%02X)" % (
        (a >> 15) & 1, (a >> 7) & 0xFF, (a >> 7) & 0xFF, a & 0x7F, a & 0x7F)


def f32_struct_str(u):
    """@brief Format a binary32 word as 's:.., exp:.. (..), mant:.. (..)'."""
    return "s:%d, exp:%d (0x%02X), mant:%d (0x%06X)" % (
        (u >> 31) & 1, (u >> 23) & 0xFF, (u >> 23) & 0xFF, u & 0x7FFFFF, u & 0x7FFFFF)


def f32_label(u):
    """@brief Human readable text for a binary32 word (number, +Inf, -Inf, quiet NaN)."""
    v = f32_to_float(u)
    if math.isnan(v):
        return "quiet NaN"
    if math.isinf(v):
        return "+Inf" if v > 0 else "-Inf"
    if v == 0.0:
        return "-0.0" if (u >> 31) else "+0.0"
    return repr(v)


def parse_int(text):
    """@brief Parse a value written as 0x...., 16'h.... or plain decimal/hex string."""
    t = text.strip().strip("*`").strip()
    m = re.search(r"(0[xX][0-9A-Fa-f]{1,8}|16'h([0-9A-Fa-f]{1,4}))", t)
    if m:
        s = m.group(1)
        return int(s.split("'h")[-1].replace("0x", ""), 16)
    return int(t, 0)


def check_json(errors):
    """@brief Validate the JSON table field by field.

    @return List of parsed vectors (no, a, b, c_bf16, f32).
    """
    with open(JSON_PATH) as f:
        data = json.load(f)
    vectors = []
    groups = [("test_vectors", data.get("test_vectors", [])),
              ("extended_vectors", data.get("extended_vectors", []))]
    for group, items in groups:
        for tv in items:
            no = tv["no"]
            a = parse_int(tv["input_a"]["bf16"])
            b = parse_int(tv["input_b"]["bf16"])
            c = parse_int(tv["output_c"]["bf16"])
            fhex = parse_int(tv["output_c"]["float32"]["hex"])
            c_exp, f_exp = mul_bf16(a, b)
            tag = "%s#%d" % (group, no)
            if c != c_exp:
                errors.append("%s: BF16 result 0x%04X != expected 0x%04X" % (tag, c, c_exp))
            if fhex != f_exp:
                errors.append("%s: F32 result 0x%08X != expected 0x%08X (%s)"
                              % (tag, fhex, f_exp, f32_label(f_exp)))
            if int(tv["output_c"]["float32"]["binary"], 2) != fhex:
                errors.append("%s: binary string does not match hex 0x%08X" % (tag, fhex))
            if tv["output_c"]["float32"]["value"] != f32_label(fhex):
                errors.append("%s: value '%s' != expected '%s'"
                              % (tag, tv["output_c"]["float32"]["value"], f32_label(fhex)))
            if tv["output_c"]["float32"]["bit_structure"] != f32_struct_str(fhex):
                errors.append("%s: F32 bit_structure does not match hex" % tag)
            if tv["output_c"]["bit_structure"] != bf16_struct_str(c):
                errors.append("%s: BF16 bit_structure does not match value" % tag)
            for key in ("input_a", "input_b"):
                word = parse_int(tv[key]["bf16"])
                if parse_int(tv[key]["float32_bits"]) != word << 16:
                    errors.append("%s: %s.float32_bits != bf16 << 16" % (tag, key))
                if tv[key]["bit_structure"] != bf16_struct_str(word):
                    errors.append("%s: %s.bit_structure does not match value" % (tag, key))
            vectors.append((no, a, b, c, fhex))
    return vectors


def check_md(json_vectors, errors):
    """@brief Validate the Markdown table against the JSON table."""
    with open(MD_PATH) as f:
        lines = f.readlines()
    by_no = {v[0]: v for v in json_vectors}
    rows = [ln for ln in lines if ln.strip().startswith("|") and "16'h" in ln]
    seen = set()
    for ln in rows:
        cols = [c.strip() for c in ln.strip().strip("|").split("|")]
        try:
            no = int(cols[0])
        except ValueError:
            errors.append("MD: invalid test number '%s'" % cols[0])
            continue
        if no not in by_no:
            errors.append("MD: unknown test number %d" % no)
            continue
        seen.add(no)
        _, a, b, c, fhex = by_no[no]
        md_a = parse_int(cols[2])
        md_b = parse_int(cols[4])
        md_c = parse_int(cols[6])
        md_f = parse_int(cols[7])
        if (md_a, md_b, md_c) != (a, b, c):
            errors.append("MD #%d: A/B/C mismatch with JSON" % no)
        if md_f != fhex:
            errors.append("MD #%d: F32 0x%08X != expected 0x%08X (%s)"
                          % (no, md_f, fhex, f32_label(fhex)))
    missing = sorted(set(by_no) - seen)
    if missing:
        errors.append("MD: missing vectors %s" % missing)


def main():
    """@brief Entry point: run all checks and report the result."""
    errors = []
    vectors = check_json(errors)
    check_md(vectors, errors)
    if errors:
        print("FAILED: %d problem(s)" % len(errors))
        for e in errors:
            print("  - " + e)
        return 1
    if "--quiet" not in sys.argv:
        print("OK: %d vectors checked (%s, %s)" % (len(vectors), JSON_PATH, MD_PATH))
    return 0


if __name__ == "__main__":
    sys.exit(main())
