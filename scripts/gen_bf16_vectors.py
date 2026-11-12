#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_bf16_vectors.py
@brief Generate and validate BF16 + BF16 -> BF16 test vectors (RTZ / RNE).

The generator uses a bit-exact integer reference model of the DUTs
`vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` and
`vhfastmulb16_add_bf16_bf16_bf16_rne_lat4`:

  * finite operands are added exactly, then rounded to bfloat16:
      - RTZ: truncation toward zero;
      - RNE: round-to-nearest, ties to even (IEEE-754 default);
  * subnormal inputs are not flushed to zero;
  * subnormal results are exact for BF16 (all finite values are multiples
    of 2^-133), but the model still implements the nominal rounding path;
  * NaN: any NaN operand or Inf + (-Inf) -> canonical quiet NaN 0x7FC0;
  * both operands zero: sign = sign_a & sign_b (IEEE-754 default);
  * exact cancellation of non-zero operands: +0;
  * RTZ overflow: max finite 0x7F7F;
  * RNE overflow: Inf 0x7F80.

Output format (one 48-bit hexadecimal word per line):
  bits[47:32] = BF16 operand A
  bits[31:16] = BF16 operand B
  bits[15:0]  = expected BF16 result

A sidecar file `<out>.labels` contains one category label per line.

Usage:
    ./scripts/gen_bf16_vectors.py --mode rne --out build/vectors.hex
    ./scripts/gen_bf16_vectors.py --mode rtz --count 4096 --seed 1234 \
        --out build/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4_rand.hex
    ./scripts/gen_bf16_vectors.py --mode rne --self-check
"""

import argparse
import json
import os
import random
import sys
from fractions import Fraction

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BF16_EXP_MAX = 0xFF
BF16_INF = 0x7F80
BF16_MAX_FINITE = 0x7F7F
BF16_QNAN = 0x7FC0
BF16_QUIET_BIT = 0x40

MODES = ("rtz", "rne")


# ---------------------------------------------------------------------------
# Reference model (integer, bit-exact)
# ---------------------------------------------------------------------------

def _unpack(u):
    """@brief Decode a finite BF16 word into (sign, unbiased_exp, mantissa).

    Subnormals are decoded with unbiased exponent -126 and the raw 7-bit
    mantissa; normals get the implicit hidden bit.

    @param u BF16 bit pattern (must be finite).
    @return Tuple (sign, exp, man).
    """
    s = (u >> 15) & 1
    ef = (u >> 7) & 0xFF
    fr = u & 0x7F
    if ef == 0:
        return s, -126, fr
    return s, ef - 127, fr | 0x80


def _classify(u):
    """@brief Classify a BF16 word: 'nan', 'inf', 'zero' or 'num'.

    @param u BF16 bit pattern.
    @return Class name.
    """
    ef = (u >> 7) & 0xFF
    fr = u & 0x7F
    if ef == 0xFF:
        return "nan" if fr else "inf"
    if ef == 0 and fr == 0:
        return "zero"
    return "num"


def add_bf16(a, b, mode):
    """@brief Bit-exact BF16 addition reference (RTZ or RNE).

    @param a First operand (BF16 bit pattern).
    @param b Second operand (BF16 bit pattern).
    @param mode 'rtz' or 'rne'.
    @return Expected BF16 result bit pattern.
    """
    ca = _classify(a)
    cb = _classify(b)
    sa = (a >> 15) & 1
    sb = (b >> 15) & 1

    # --- NaN: canonical quiet NaN ---
    if ca == "nan" or cb == "nan":
        return BF16_QNAN

    # --- Inf ---
    if ca == "inf" or cb == "inf":
        if ca == "inf" and cb == "inf" and sa != sb:
            return BF16_QNAN
        return ((sa if ca == "inf" else sb) << 15) | BF16_INF

    # --- zero ---
    if ca == "zero" and cb == "zero":
        return (sa & sb) << 15
    if ca == "zero":
        return b
    if cb == "zero":
        return a

    # --- finite operands ---
    s1, e1, m1 = _unpack(a)
    s2, e2, m2 = _unpack(b)
    emin = min(e1, e2)
    va = m1 << (e1 - emin)
    vb = m2 << (e2 - emin)
    if s1:
        va = -va
    if s2:
        vb = -vb
    total = va + vb
    if total == 0:
        return 0  # exact cancellation -> +0

    sign = 1 if total < 0 else 0
    mag = abs(total)
    k = mag.bit_length() - 1            # index of the MSB
    e_field = k + emin - 7 + 127        # biased exponent (7 frac bits)

    if e_field >= 255:
        # Overflow: RTZ -> max finite, RNE -> Inf.
        return (sign << 15) | (BF16_INF if mode == "rne" else BF16_MAX_FINITE)

    if e_field >= 1:
        # Normal result.
        sh = k - 7
        if sh > 0:
            q = mag >> sh
            rem = mag & ((1 << sh) - 1)
            if mode == "rne":
                half = 1 << (sh - 1)
                if rem > half or (rem == half and (q & 1)):
                    q += 1
        else:
            q = mag << (-sh)
        if q >= 256:
            q >>= 1
            e_field += 1
        if e_field >= 255:
            return (sign << 15) | (BF16_INF if mode == "rne" else BF16_MAX_FINITE)
        return (sign << 15) | (e_field << 7) | (q & 0x7F)

    # Subnormal result: value = mag * 2^(emin - 7) = frac * 2^-133.
    sh = -(emin + 126)
    if sh <= 0:
        return (sign << 15) | (mag << (-sh))
    q = mag >> sh
    rem = mag & ((1 << sh) - 1)
    if mode == "rne":
        half = 1 << (sh - 1)
        if rem > half or (rem == half and (q & 1)):
            q += 1
    if q >= 128:
        # Rounded up to the smallest normal.
        return (sign << 15) | (1 << 7)
    return (sign << 15) | q


# ---------------------------------------------------------------------------
# Directed corner cases
# ---------------------------------------------------------------------------

DIRECTED = [
    (0x0000, 0x0000, "zero+zero"),
    (0x8000, 0x8000, "-zero+-zero"),
    (0x0000, 0x8000, "+zero+-zero"),
    (0x8000, 0x0000, "-zero+zero"),
    (0x3F80, 0x3F80, "1+1"),
    (0x3F80, 0xBF80, "1-1"),
    (0x3F80, 0x0000, "1++0"),
    (0x3F80, 0x8000, "1+-0"),
    (0x7F80, 0x7F80, "inf+inf"),
    (0x7F80, 0xFF80, "inf-inf"),
    (0xFF80, 0xFF80, "-inf-inf"),
    (0x7F80, 0x3F80, "inf+1"),
    (0x7FC0, 0x3F80, "qnan+1"),
    (0x7F81, 0x3F80, "snan+1"),
    (0xFF81, 0x3F80, "-snan+1"),
    (0x3F80, 0x7FC1, "1+qnan_payload"),
    (0x7F7F, 0x3F80, "max+1 -> rne inf / rtz max"),
    (0x7F7F, 0x7F7F, "max+max"),
    (0xFF7F, 0xFF7F, "-max-max"),
    (0x7F00, 0x7F00, "2^127+2^127"),
    (0x7F7F, 0x7A80, "max+0.25ulp"),
    (0x7F7F, 0x7B00, "max+0.5ulp (overflow tie)"),
    (0x7F7F, 0x7B01, "max+>0.5ulp"),
    (0x0001, 0x0001, "minsub+minsub"),
    (0x0001, 0x3F80, "minsub+1"),
    (0x8001, 0x3F80, "-minsub+1"),
    (0x0080, 0x0001, "minnorm+minsub"),
    (0x007F, 0x0001, "maxsub+minsub -> minnorm"),
    (0x007F, 0x007F, "maxsub+maxsub"),
    (0x0080, 0x807F, "minnorm-maxsub -> minsub"),
    (0x0081, 0x807F, "minnorm+1-maxsub"),
    (0x0100, 0x007F, "2^-125+maxsub (round)"),
    (0x3F80, 0x3B80, "1+0.5ulp (rne tie even)"),
    (0x3F81, 0x3B80, "1+1ulp+0.5ulp (rne tie odd)"),
    (0x3F80, 0x3B00, "1+0.25ulp"),
    (0x3F80, 0x3B01, "1+0.25ulp+eps"),
    (0x3FFF, 0x3B80, "near2+0.5ulp (rne carry)"),
    (0xBF80, 0xBB80, "-1-0.5ulp (negative tie even)"),
    (0xBF81, 0xBB80, "-1-1ulp-0.5ulp (negative tie odd)"),
    (0x3F80, 0x0002, "1+minsub2 (alignment saturation)"),
    (0x3F80, 0x8002, "1-minsub2 (rtz predecessor)"),
    (0xBF80, 0x0002, "-1+minsub2 (rtz predecessor)"),
    (0x3F80, 0x3F00, "1+0.5"),
    (0x3F80, 0x3E80, "1+0.25"),
    (0x4000, 0xC000, "2-2"),
    (0x42C8, 0x3F80, "100+1"),
    (0x3FC0, 0xBF40, "1.5-0.75"),
]


# ---------------------------------------------------------------------------
# Random vector generation
# ---------------------------------------------------------------------------

def _rand_normal(rng, exp=None):
    """@brief Random finite normal BF16 word.

    @param rng Random generator.
    @param exp Optional biased exponent (1..254).
    @return BF16 bit pattern.
    """
    if exp is None:
        exp = rng.randint(1, 254)
    return (rng.getrandbits(1) << 15) | (exp << 7) | rng.getrandbits(7)


def _rand_subnormal(rng):
    """@brief Random non-zero subnormal BF16 word.

    @param rng Random generator.
    @return BF16 bit pattern.
    """
    frac = rng.getrandbits(7) or 1
    return (rng.getrandbits(1) << 15) | frac


def _clamp_exp(e):
    """@brief Clamp a biased exponent to the finite normal range."""
    return max(1, min(254, e))


def random_cases(count, seed):
    """@brief Generate `count` deterministic random (a, b, label) triples.

    The distribution is biased towards cases that exercise alignment,
    cancellation, subnormal and overflow boundaries.

    @param count Number of vectors.
    @param seed Random seed.
    @return List of (a, b, label) tuples.
    """
    rng = random.Random(seed)
    out = []

    buckets = [
        (20, "equal_exp"),
        (20, "dexp_1_6"),
        (15, "dexp_7_13"),
        (10, "dexp_14_25"),
        (5, "dexp_gt_25"),
        (15, "cancel"),
        (8, "subnormal"),
        (2, "overflow"),
        (5, "chaos"),
    ]
    total_w = sum(w for w, _ in buckets)

    for _ in range(count):
        r = rng.uniform(0, total_w)
        acc = 0
        name = buckets[-1][1]
        for w, n in buckets:
            acc += w
            if r <= acc:
                name = n
                break

        if name == "equal_exp":
            e = rng.randint(1, 254)
            a = _rand_normal(rng, e)
            b = _rand_normal(rng, e)
        elif name == "dexp_1_6":
            e1 = rng.randint(7, 248)
            d = rng.randint(1, 6)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_7_13":
            e1 = rng.randint(14, 241)
            d = rng.randint(7, 13)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_14_25":
            e1 = rng.randint(26, 229)
            d = rng.randint(14, 25)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_gt_25":
            e1 = rng.randint(30, 254)
            d = rng.randint(26, 100)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 - d))
        elif name == "cancel":
            a = _rand_normal(rng)
            n = rng.randint(1, 7)
            low = rng.getrandbits(n)
            b = (a ^ 0x8000) & ~((1 << n) - 1)
            b |= low
            if ((b >> 7) & 0xFF) == 0xFF:
                b = a ^ 0x8000
        elif name == "subnormal":
            a = _rand_subnormal(rng)
            b = _rand_subnormal(rng) if rng.random() < 0.5 else _rand_normal(rng)
        elif name == "overflow":
            e1 = rng.randint(250, 254)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, rng.randint(250, 254))
        else:  # chaos: fully random words (may be NaN/Inf)
            a = rng.getrandbits(16)
            b = rng.getrandbits(16)
        out.append((a & 0xFFFF, b & 0xFFFF, name))
    return out


# ---------------------------------------------------------------------------
# Independent self-check (exact rational arithmetic)
# ---------------------------------------------------------------------------

def _bf16_frac(u):
    """@brief Convert a finite BF16 word to an exact Fraction.

    @param u BF16 bit pattern.
    @return Exact value as Fraction.
    """
    s = (u >> 15) & 1
    ef = (u >> 7) & 0xFF
    fr = u & 0x7F
    if ef == 0:
        v = Fraction(fr, 1 << 133)
    else:
        v = Fraction(fr | 0x80) * (Fraction(2) ** (ef - 134))
    return -v if s else v


def _ref_via_fraction(x, mode):
    """@brief Independent reference: round an exact Fraction to BF16.

    Uses a binary search over the monotonic positive-BF16 bit patterns.

    @param x Exact value (Fraction), non-zero.
    @param mode 'rtz' or 'rne'.
    @return BF16 bit pattern.
    """
    sign = 1 if x < 0 else 0
    mag = -x if sign else x
    max_finite_val = _bf16_frac(BF16_MAX_FINITE)
    ulp_max = Fraction(1 << 120)

    if mag > max_finite_val:
        if mode == "rtz":
            return (sign << 15) | BF16_MAX_FINITE
        # RNE: overflow threshold = max_finite + 0.5 ULP.
        threshold = max_finite_val + ulp_max / 2
        # At the exact tie, max_finite has all-ones significand (odd),
        # while 2^128 has an even significand, so the tie goes to Inf.
        if mag >= threshold:
            return (sign << 15) | BF16_INF
        return (sign << 15) | BF16_MAX_FINITE

    lo, hi = 0, BF16_MAX_FINITE
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if _bf16_frac(mid) <= mag:
            lo = mid
        else:
            hi = mid - 1
    f_lo = _bf16_frac(lo)

    if f_lo == mag or mode == "rtz":
        w = lo
    else:
        up = lo + 1
        d_lo = mag - f_lo
        d_up = _bf16_frac(up) - mag
        if d_lo < d_up:
            w = lo
        elif d_up < d_lo:
            w = up
        else:
            w = lo if (lo & 1) == 0 else up
    return (sign << 15) | w


def _load_json_vectors():
    """@brief Load the project's 32 directed BF16 addition vectors.

    @return List of vector dictionaries.
    """
    path = os.path.join(
        BASE, "testvalues", "test_values_add_bf16_bf16_bf16",
        "test_values_add_bf16_bf16_bf16.json"
    )
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)["vectors"]


def _hex_to_int(hstr):
    """@brief Convert a JSON '16 hXXXX' string to an integer."""
    return int(hstr.replace("16'h", ""), 16)


def self_check(count, seed, mode):
    """@brief Validate the integer reference against JSON and exact rationals.

    @param count Number of random vectors to check.
    @param seed Random seed.
    @param mode 'rtz' or 'rne'.
    @return 0 on success, 1 on mismatch.
    """
    errors = 0
    total = 0

    # Validate the 32 directed JSON vectors (both rounding modes).
    for vec in _load_json_vectors():
        a = _hex_to_int(vec["a"])
        b = _hex_to_int(vec["b"])
        for m, key in (("rne", "crne"), ("rtz", "crtz")):
            exp = _hex_to_int(vec[key])
            got = add_bf16(a, b, m)
            total += 1
            if got != exp:
                errors += 1
                if errors <= 20:
                    print("JSON MISMATCH [{}] a={:04X} b={:04X} desc={} "
                          "model={:04X} expected={:04X}".format(
                              m, a, b, vec.get("desc", ""), got, exp))

    cases = [(a, b, label) for a, b, label in DIRECTED]
    cases += random_cases(count, seed)
    for a, b, label in cases:
        ca = _classify(a)
        cb = _classify(b)
        if ca in ("nan", "inf") or cb in ("nan", "inf"):
            continue
        total += 1
        expected = add_bf16(a, b, mode)
        if ca == "zero" and cb == "zero":
            exact_bits = ((a >> 15) & 1 & ((b >> 15) & 1)) << 15
        elif ca == "zero":
            exact_bits = b
        elif cb == "zero":
            exact_bits = a
        else:
            exact = _bf16_frac(a) + _bf16_frac(b)
            exact_bits = 0 if exact == 0 else _ref_via_fraction(exact, mode)
        if expected != exact_bits:
            errors += 1
            if errors <= 20:
                print("MISMATCH [{}] a={:04X} b={:04X} label={} "
                      "model={:04X} exact={:04X}".format(
                          mode, a, b, label, expected, exact_bits))
    print("self-check[{}]: checked {} vectors, errors {}".format(mode, total, errors))
    return 0 if errors == 0 else 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    """@brief Entry point: generate vectors or run the self-check."""
    parser = argparse.ArgumentParser(
        description="Generate BF16 + BF16 -> BF16 test vectors (RTZ / RNE)")
    parser.add_argument("--mode", choices=MODES, default="rtz",
                        help="rounding mode (default: rtz)")
    parser.add_argument("--count", type=int, default=4096,
                        help="total number of vectors (default: 4096)")
    parser.add_argument("--seed", type=int, default=12345,
                        help="random seed (default: 12345)")
    parser.add_argument("--out", default=None,
                        help="output hex file (default: build/<dut>_rand.hex)")
    parser.add_argument("--self-check", action="store_true",
                        help="validate the integer model with exact rationals")
    parser.add_argument("--no-labels", action="store_true",
                        help="do not write the sidecar .labels file")
    args = parser.parse_args()

    if args.self_check:
        rc = self_check(args.count, args.seed, args.mode)
        if rc == 0:
            rc = self_check(args.count, args.seed + 1,
                            "rne" if args.mode == "rtz" else "rtz")
        return rc

    if args.count < len(DIRECTED):
        print("ERROR: --count={} is less than {} directed cases".format(
            args.count, len(DIRECTED)), file=sys.stderr)
        return 2

    out_path = args.out
    if out_path is None:
        out_path = "build/vhfastmulb16_add_bf16_bf16_bf16_{}_lat4_rand.hex".format(
            args.mode)
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    cases = [(a, b, label) for a, b, label in DIRECTED]
    cases += random_cases(args.count - len(DIRECTED), args.seed)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, _label in cases:
            f.write("{:04X}{:04X}{:04X}\n".format(a, b, add_bf16(a, b, args.mode)))

    if not args.no_labels:
        with open(out_path + ".labels", "w", encoding="ascii") as f:
            for _a, _b, label in cases:
                f.write(label + "\n")

    print("generated {} vectors [{}] -> {}".format(len(cases), args.mode, out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
