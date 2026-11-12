#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_fp32_vectors.py
@brief Generate and validate FP32 + FP32 -> FP32 test vectors (RTZ / RNE).

The generator uses a bit-exact integer reference model of the planned
`vhfastmulb16_add_fp32_rtz_lat4` / `vhfastmulb16_add_fp32_rne_lat4` DUTs:
  * finite operands are added exactly, then rounded to binary32:
      - RTZ: truncation toward zero (no guard/round/sticky);
      - RNE: round-to-nearest, ties to even (IEEE-754 default);
  * subnormal inputs are not flushed to zero;
  * subnormal results are produced and rounded (RNE) or truncated (RTZ);
  * NaN: sign and mantissa (payload) preserved from the NaN operand,
    quiet bit (frac[22]) forced to 1;
  * Inf + (-Inf): qNaN with sign/payload taken from operand b
    (convention of the current DUT, see tests/*_tb.v vector #8);
  * both operands zero: sign = sign_a & sign_b (IEEE-754 default);
  * exact cancellation of non-zero operands: +0.

Output format (one 96-bit hexadecimal word per line):
  bits[95:64] = FP32 operand A
  bits[63:32] = FP32 operand B
  bits[31:0]  = expected FP32 result

A sidecar file `<out>.labels` contains one category label per line
(useful to locate a failing vector).

Usage:
    ./scripts/gen_fp32_vectors.py --mode rne --out build/vectors.hex
    ./scripts/gen_fp32_vectors.py --mode rtz --count 4096 --seed 1234 \
        --out build/vhfastmulb16_add_fp32_rtz_lat4_rand.hex
    ./scripts/gen_fp32_vectors.py --mode rne --self-check
"""

import argparse
import os
import random
import sys
from fractions import Fraction

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INF_F32 = 0x7F800000
QNAN_QUIET = 0x400000  # frac[22]

MODES = ("rtz", "rne")


# ---------------------------------------------------------------------------
# Reference model (integer, bit-exact)
# ---------------------------------------------------------------------------

def _unpack(u):
    """@brief Decode a finite FP32 word into (sign, unbiased_exp, mantissa).

    Subnormals are decoded with unbiased exponent -126 and the raw 23-bit
    mantissa; normals get the implicit hidden bit.

    @param u FP32 bit pattern (must be finite).
    @return Tuple (sign, exp, man).
    """
    s = (u >> 31) & 1
    ef = (u >> 23) & 0xFF
    fr = u & 0x7FFFFF
    if ef == 0:
        return s, -126, fr
    return s, ef - 127, fr | 0x800000


def _classify(u):
    """@brief Classify an FP32 word: 'nan', 'inf', 'zero' or 'num'.

    @param u FP32 bit pattern.
    @return Class name.
    """
    ef = (u >> 23) & 0xFF
    fr = u & 0x7FFFFF
    if ef == 0xFF:
        return "nan" if fr else "inf"
    if ef == 0 and fr == 0:
        return "zero"
    return "num"


def _nan_result(u):
    """@brief Build the qNaN result for a NaN operand.

    Sign and payload are preserved from the operand, quiet bit forced to 1.

    @param u FP32 NaN bit pattern.
    @return FP32 qNaN bit pattern.
    """
    s = (u >> 31) & 1
    return (s << 31) | INF_F32 | ((u & 0x7FFFFF) | QNAN_QUIET)


def add_f32(a, b, mode):
    """@brief Bit-exact FP32 addition reference (RTZ or RNE).

    @param a First operand (FP32 bit pattern).
    @param b Second operand (FP32 bit pattern).
    @param mode 'rtz' or 'rne'.
    @return Expected FP32 result bit pattern.
    """
    ca = _classify(a)
    cb = _classify(b)
    sa = (a >> 31) & 1
    sb = (b >> 31) & 1

    # --- NaN priority (payload preserved, quiet bit forced) ---
    if ca == "nan":
        return _nan_result(a)
    if cb == "nan":
        return _nan_result(b)

    # --- Inf ---
    if ca == "inf" or cb == "inf":
        if ca == "inf" and cb == "inf" and sa != sb:
            # Inf + (-Inf) -> qNaN; sign/payload from operand b (DUT convention).
            return _nan_result(b)
        return ((sa if ca == "inf" else sb) << 31) | INF_F32

    # --- zero ---
    if ca == "zero" and cb == "zero":
        return (sa & sb) << 31
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
    e_field = k + emin - 23 + 127       # biased exponent

    if e_field >= 255:
        # Value >= 2^128: overflow to Inf (rounding cannot pull it back).
        return (sign << 31) | INF_F32

    if e_field >= 1:
        # Normal result.
        sh = k - 23
        if sh > 0:
            q = mag >> sh
            rem = mag & ((1 << sh) - 1)
            if mode == "rne":
                half = 1 << (sh - 1)
                if rem > half or (rem == half and (q & 1)):
                    q += 1
        else:
            q = mag << (-sh)
        if q >= (1 << 24):
            q >>= 1
            e_field += 1
        if e_field >= 255:
            return (sign << 31) | INF_F32
        return (sign << 31) | (e_field << 23) | (q & 0x7FFFFF)

    # Subnormal result: value = mag * 2^(emin-23) = m * 2^-149.
    sh = -(emin + 126)
    if sh <= 0:
        return (sign << 31) | (mag << (-sh))
    q = mag >> sh
    rem = mag & ((1 << sh) - 1)
    if mode == "rne":
        half = 1 << (sh - 1)
        if rem > half or (rem == half and (q & 1)):
            q += 1
    if q >= (1 << 23):
        # Rounded up to the smallest normal.
        return (sign << 31) | (1 << 23)
    return (sign << 31) | q


# ---------------------------------------------------------------------------
# Directed corner cases
# ---------------------------------------------------------------------------

DIRECTED = [
    (0x00000000, 0x00000000, "zero+zero"),
    (0x80000000, 0x80000000, "-zero+-zero"),
    (0x00000000, 0x80000000, "+zero+-zero"),
    (0x80000000, 0x00000000, "-zero+zero"),
    (0x3F800000, 0x3F800000, "1+1"),
    (0x3F800000, 0xBF800000, "1-1"),
    (0x3F800000, 0x00000000, "1++0"),
    (0x3F800000, 0x80000000, "1+-0"),
    (0x7F800000, 0x7F800000, "inf+inf"),
    (0x7F800000, 0xFF800000, "inf-inf"),
    (0xFF800000, 0xFF800000, "-inf-inf"),
    (0x7F800000, 0x3F800000, "inf+1"),
    (0x7FC00000, 0x3F800000, "qnan+1"),
    (0x7FA00000, 0x3F800000, "snan+1"),
    (0x3F800000, 0x7FC01234, "1+qnan"),
    (0x7F7FFFFF, 0x3F800000, "max+1"),
    (0x7F7FFFFF, 0x7F7FFFFF, "max+max"),
    (0xFF7FFFFF, 0xFF7FFFFF, "-max-max"),
    (0x00000001, 0x00000001, "minsub+minsub"),
    (0x00000001, 0x3F800000, "minsub+1"),
    (0x80000001, 0x3F800000, "-minsub+1"),
    (0x00800000, 0x00000001, "minnorm+minsub"),
    (0x007FFFFF, 0x00800000, "maxsub+minnorm"),
    (0x3F800000, 0x007FFFFF, "1+maxsub"),
    (0xBF800000, 0x3F7FFFFF, "-1+maxsub_scale"),
    (0x3F800001, 0xBF800000, "1ulp-1"),
    (0x3F800000, 0x33800000, "1+2^-24 (rne tie)"),
    (0x3F800000, 0x33C00000, "1+3*2^-25 (rne up)"),
    (0x3F800000, 0x34000000, "1+2^-23 (exact)"),
    (0x3F800001, 0x33800000, "1ulp+2^-24 (tie odd)"),
    (0x3F800000, 0x3F800001, "1+1ulp (equal exp)"),
    (0x40000000, 0xC0000000, "2-2"),
    (0x7F000000, 0x7F000000, "2^127+2^127"),
    (0x7EFFFFFF, 0x7EFFFFFF, "below2^127+itself"),
    (0x0C000000, 0x0C000000, "tiny+small"),
    (0x00800001, 0x80800000, "minnorm+1ulp-minnorm"),
    (0x00000003, 0x00000003, "3minsub+3minsub"),
    (0x00000005, 0x80000003, "5minsub-3minsub"),
    (0x7F7FFFFE, 0x7F7FFFFE, "max-1ulp+max-1ulp"),
]


# ---------------------------------------------------------------------------
# Random vector generation
# ---------------------------------------------------------------------------

def _rand_normal(rng, exp=None):
    """@brief Random finite normal FP32 word.

    @param rng Random generator.
    @param exp Optional biased exponent (1..254).
    @return FP32 bit pattern.
    """
    if exp is None:
        exp = rng.randint(1, 254)
    return (rng.getrandbits(1) << 31) | (exp << 23) | rng.getrandbits(23)


def _rand_subnormal(rng):
    """@brief Random non-zero subnormal FP32 word.

    @param rng Random generator.
    @return FP32 bit pattern.
    """
    frac = rng.getrandbits(23) or 1
    return (rng.getrandbits(1) << 31) | frac


def _clamp_exp(e):
    """@brief Clamp a biased exponent to the finite normal range."""
    return max(1, min(254, e))


def random_cases(count, seed):
    """@brief Generate `count` deterministic random (a, b, label) triples.

    The distribution is intentionally biased towards cases that exercise
    the mantissa datapath: equal exponents, small exponent differences,
    near-cancellation, subnormals, underflow and overflow boundaries.

    @param count Number of vectors.
    @param seed Random seed.
    @return List of (a, b, label) tuples.
    """
    rng = random.Random(seed)
    out = []

    # Fixed weights (sum = 100).
    buckets = [
        (20, "equal_exp"),
        (20, "dexp_1_3"),
        (15, "dexp_4_25"),
        (10, "dexp_26_100"),
        (5, "dexp_gt_100"),
        (15, "cancel"),
        (8, "subnormal"),
        (3, "underflow"),
        (2, "overflow"),
        (2, "chaos"),
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
        elif name == "dexp_1_3":
            e1 = rng.randint(4, 251)
            d = rng.randint(1, 3)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_4_25":
            e1 = rng.randint(26, 230)
            d = rng.randint(4, 25)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_26_100":
            e1 = rng.randint(101, 155)
            d = rng.randint(26, 100)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_gt_100":
            e1 = rng.randint(150, 254)
            d = rng.randint(101, 250)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 - d))
        elif name == "cancel":
            a = _rand_normal(rng)
            n = rng.randint(1, 8)
            low = rng.getrandbits(n)
            b = (a ^ 0x80000000) & ~((1 << n) - 1)
            b |= low
            if ((b >> 23) & 0xFF) == 0xFF:
                b = a ^ 0x80000000
        elif name == "subnormal":
            a = _rand_subnormal(rng)
            b = _rand_subnormal(rng) if rng.random() < 0.5 else _rand_normal(rng)
        elif name == "underflow":
            e1 = rng.randint(1, 6)
            a = _rand_normal(rng, e1)
            b = (_rand_normal(rng, e1) ^ 0x80000000) if rng.random() < 0.7 else _rand_subnormal(rng)
        elif name == "overflow":
            e1 = rng.randint(250, 254)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, rng.randint(250, 254))
        else:  # chaos: fully random words (may be NaN/Inf)
            a = rng.getrandbits(32)
            b = rng.getrandbits(32)
        out.append((a & 0xFFFFFFFF, b & 0xFFFFFFFF, name))
    return out


# ---------------------------------------------------------------------------
# Independent self-check (exact rational arithmetic)
# ---------------------------------------------------------------------------

def _f32_frac(u):
    """@brief Convert a finite FP32 word to an exact Fraction.

    @param u FP32 bit pattern.
    @return Exact value as Fraction.
    """
    s = (u >> 31) & 1
    ef = (u >> 23) & 0xFF
    fr = u & 0x7FFFFF
    if ef == 0:
        v = Fraction(fr, 1 << 149)
    else:
        v = Fraction(fr | 0x800000) * (Fraction(2) ** (ef - 150))
    return -v if s else v


def _ref_via_fraction(x, mode):
    """@brief Independent reference: round an exact Fraction to FP32.

    Uses a binary search over the monotonic positive-FP32 bit patterns.

    @param x Exact value (Fraction), non-zero.
    @param mode 'rtz' or 'rne'.
    @return FP32 bit pattern.
    """
    sign = 1 if x < 0 else 0
    mag = -x if sign else x
    if mag >= Fraction(1 << 128):
        return (sign << 31) | INF_F32

    lo, hi = 0, 0x7F7FFFFF
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if _f32_frac(mid) <= mag:
            lo = mid
        else:
            hi = mid - 1
    f_lo = _f32_frac(lo)

    if f_lo == mag or mode == "rtz":
        w = lo
    elif lo == 0x7F7FFFFF:
        # Midpoint between max_normal and 2^128.
        half_ulp = Fraction(1 << 103)
        w = 0x7F800000 if (mag - f_lo) >= half_ulp else 0x7F7FFFFF
    else:
        up = lo + 1
        d_lo = mag - f_lo
        d_up = _f32_frac(up) - mag
        if d_lo < d_up:
            w = lo
        elif d_up < d_lo:
            w = up
        else:
            w = lo if (lo & 1) == 0 else up
    return (sign << 31) | w


def self_check(count, seed, mode):
    """@brief Validate the integer reference against exact rational arithmetic.

    @param count Number of vectors to check.
    @param seed Random seed.
    @param mode 'rtz' or 'rne'.
    @return 0 on success, 1 on mismatch.
    """
    errors = 0
    total = 0
    cases = [(a, b, label) for a, b, label in DIRECTED]
    cases += random_cases(count, seed)
    for a, b, label in cases:
        ca = _classify(a)
        cb = _classify(b)
        if ca in ("nan", "inf") or cb in ("nan", "inf"):
            continue
        total += 1
        expected = add_f32(a, b, mode)
        if ca == "zero" and cb == "zero":
            exact_bits = ((a >> 31) & 1 & ((b >> 31) & 1)) << 31
        elif ca == "zero":
            exact_bits = b
        elif cb == "zero":
            exact_bits = a
        else:
            exact = _f32_frac(a) + _f32_frac(b)
            exact_bits = 0 if exact == 0 else _ref_via_fraction(exact, mode)
        if expected != exact_bits:
            errors += 1
            if errors <= 20:
                print("MISMATCH [{}] a={:08X} b={:08X} label={} "
                      "model={:08X} exact={:08X}".format(
                          mode, a, b, label, expected, exact_bits))
    print("self-check[{}]: checked {} vectors, errors {}".format(mode, total, errors))
    return 0 if errors == 0 else 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    """@brief Entry point: generate vectors or run the self-check."""
    parser = argparse.ArgumentParser(
        description="Generate FP32 + FP32 -> FP32 test vectors (RTZ / RNE)")
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
            # Check both modes regardless of --mode: the reference shares code.
            rc = self_check(args.count, args.seed + 1,
                            "rne" if args.mode == "rtz" else "rtz")
        return rc

    if args.count < len(DIRECTED):
        print("ERROR: --count={} is less than {} directed cases".format(
            args.count, len(DIRECTED)), file=sys.stderr)
        return 2

    out_path = args.out
    if out_path is None:
        out_path = "build/vhfastmulb16_add_fp32_{}_lat4_rand.hex".format(args.mode)
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    cases = [(a, b, label) for a, b, label in DIRECTED]
    cases += random_cases(args.count - len(DIRECTED), args.seed)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, _label in cases:
            f.write("{:08X}{:08X}{:08X}\n".format(a, b, add_f32(a, b, args.mode)))

    if not args.no_labels:
        with open(out_path + ".labels", "w", encoding="ascii") as f:
            for _a, _b, label in cases:
                f.write(label + "\n")

    print("generated {} vectors [{}] -> {}".format(len(cases), args.mode, out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
