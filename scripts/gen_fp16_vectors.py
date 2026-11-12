#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@file gen_fp16_vectors.py
@brief Generate and validate FP16 + FP16 -> FP16 test vectors (RTZ / RNE).

The generator uses a bit-exact integer reference model of the planned
`vhfastmulb16_add_fp16_rtz_lat4` / `vhfastmulb16_add_fp16_rne_lat4` DUTs:
  * finite operands are added exactly, then rounded to binary16:
      - RTZ: truncation toward zero (no guard/round/sticky);
      - RNE: round-to-nearest, ties to even (IEEE-754 default);
  * subnormal inputs are not flushed to zero;
  * subnormal results are produced and rounded (RNE) or truncated (RTZ);
  * NaN: sign and mantissa (payload) preserved from the NaN operand,
    quiet bit (frac[9]) forced to 1;
  * Inf + (-Inf): qNaN with sign/payload taken from operand b
    (convention of the current DUT, see tests/*_tb.v vector #8);
  * both operands zero: sign = sign_a & sign_b (IEEE-754 default);
  * exact cancellation of non-zero operands: +0.

Output format (one 48-bit hexadecimal word per line):
  bits[47:32] = FP16 operand A
  bits[31:16] = FP16 operand B
  bits[15:0]  = expected FP16 result

A sidecar file `<out>.labels` contains one category label per line
(useful to locate a failing vector).

Usage:
    ./scripts/gen_fp16_vectors.py --mode rne --out build/vectors.hex
    ./scripts/gen_fp16_vectors.py --mode rtz --count 4096 --seed 1234 \
        --out build/vhfastmulb16_add_fp16_rtz_lat4_rand.hex
    ./scripts/gen_fp16_vectors.py --mode rne --self-check
"""

import argparse
import os
import random
import sys
from fractions import Fraction

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INF_F16 = 0x7C00
QNAN_QUIET = 0x0200  # frac[9]

MODES = ("rtz", "rne")


# ---------------------------------------------------------------------------
# Reference model (integer, bit-exact)
# ---------------------------------------------------------------------------

def _unpack(u):
    """@brief Decode a finite FP16 word into (sign, unbiased_exp, mantissa).

    Subnormals are decoded with unbiased exponent -14 and the raw 10-bit
    mantissa; normals get the implicit hidden bit.

    @param u FP16 bit pattern (must be finite).
    @return Tuple (sign, exp, man).
    """
    s = (u >> 15) & 1
    ef = (u >> 10) & 0x1F
    fr = u & 0x3FF
    if ef == 0:
        return s, -14, fr
    return s, ef - 15, fr | 0x400


def _classify(u):
    """@brief Classify an FP16 word: 'nan', 'inf', 'zero' or 'num'.

    @param u FP16 bit pattern.
    @return Class name.
    """
    ef = (u >> 10) & 0x1F
    fr = u & 0x3FF
    if ef == 0x1F:
        return "nan" if fr else "inf"
    if ef == 0 and fr == 0:
        return "zero"
    return "num"


def _nan_result(u):
    """@brief Build the qNaN result for a NaN operand.

    Sign and payload are preserved from the operand, quiet bit forced to 1.

    @param u FP16 NaN bit pattern.
    @return FP16 qNaN bit pattern.
    """
    s = (u >> 15) & 1
    return (s << 15) | INF_F16 | ((u & 0x3FF) | QNAN_QUIET)


def add_f16(a, b, mode):
    """@brief Bit-exact FP16 addition reference (RTZ or RNE).

    @param a First operand (FP16 bit pattern).
    @param b Second operand (FP16 bit pattern).
    @param mode 'rtz' or 'rne'.
    @return Expected FP16 result bit pattern.
    """
    ca = _classify(a)
    cb = _classify(b)
    sa = (a >> 15) & 1
    sb = (b >> 15) & 1

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
        return ((sa if ca == "inf" else sb) << 15) | INF_F16

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
    e_field = k + emin - 10 + 15        # biased exponent (10 frac bits)

    if e_field >= 31:
        # Value >= 2^16: overflow to Inf (rounding cannot pull it back).
        return (sign << 15) | INF_F16

    if e_field >= 1:
        # Normal result.
        sh = k - 10
        if sh > 0:
            q = mag >> sh
            rem = mag & ((1 << sh) - 1)
            if mode == "rne":
                half = 1 << (sh - 1)
                if rem > half or (rem == half and (q & 1)):
                    q += 1
        else:
            q = mag << (-sh)
        if q >= (1 << 11):
            q >>= 1
            e_field += 1
        if e_field >= 31:
            return (sign << 15) | INF_F16
        return (sign << 15) | (e_field << 10) | (q & 0x3FF)

    # Subnormal result: value = mag * 2^(emin-10) = m * 2^-24.
    sh = -(emin + 14)
    if sh <= 0:
        return (sign << 15) | (mag << (-sh))
    q = mag >> sh
    rem = mag & ((1 << sh) - 1)
    if mode == "rne":
        half = 1 << (sh - 1)
        if rem > half or (rem == half and (q & 1)):
            q += 1
    if q >= (1 << 10):
        # Rounded up to the smallest normal.
        return (sign << 15) | (1 << 10)
    return (sign << 15) | q


# ---------------------------------------------------------------------------
# Directed corner cases
# ---------------------------------------------------------------------------

DIRECTED = [
    (0x0000, 0x0000, "zero+zero"),
    (0x8000, 0x8000, "-zero+-zero"),
    (0x0000, 0x8000, "+zero+-zero"),
    (0x8000, 0x0000, "-zero+zero"),
    (0x3C00, 0x3C00, "1+1"),
    (0x3C00, 0xBC00, "1-1"),
    (0x3C00, 0x0000, "1++0"),
    (0x3C00, 0x8000, "1+-0"),
    (0x7C00, 0x7C00, "inf+inf"),
    (0x7C00, 0xFC00, "inf-inf"),
    (0xFC00, 0xFC00, "-inf-inf"),
    (0x7C00, 0x3C00, "inf+1"),
    (0x7E00, 0x3C00, "qnan+1"),
    (0x7A00, 0x3C00, "snan+1"),
    (0x3C00, 0x7E01, "1+qnan"),
    (0x7BFF, 0x3C00, "max+1"),
    (0x7BFF, 0x7BFF, "max+max"),
    (0xFBFF, 0xFBFF, "-max-max"),
    (0x0001, 0x0001, "minsub+minsub"),
    (0x0001, 0x3C00, "minsub+1"),
    (0x8001, 0x3C00, "-minsub+1"),
    (0x0400, 0x0001, "minnorm+minsub"),
    (0x03FF, 0x0400, "maxsub+minnorm"),
    (0x3C00, 0x03FF, "1+maxsub"),
    (0xBC00, 0x3BFF, "-1+maxsub_scale"),
    (0x3C01, 0xBC00, "1ulp-1"),
    (0x3C00, 0x3200, "1+2^-10 (rne tie)"),
    (0x3C00, 0x3300, "1+3*2^-11 (rne up)"),
    (0x3C00, 0x3400, "1+2^-9 (exact)"),
    (0x3C01, 0x3200, "1ulp+2^-10 (tie odd)"),
    (0x3C00, 0x3C01, "1+1ulp (equal exp)"),
    (0x4000, 0xC000, "2-2"),
    (0x7800, 0x7800, "2^15+2^15"),
    (0x77FF, 0x77FF, "below2^15+itself"),
    (0x0C00, 0x0C00, "tiny+small"),
    (0x0401, 0x8400, "minnorm+1ulp-minnorm"),
    (0x0003, 0x0003, "3minsub+3minsub"),
    (0x0005, 0x8003, "5minsub-3minsub"),
    (0x7BFE, 0x7BFE, "max-1ulp+max-1ulp"),
]


# ---------------------------------------------------------------------------
# Random vector generation
# ---------------------------------------------------------------------------

def _rand_normal(rng, exp=None):
    """@brief Random finite normal FP16 word.

    @param rng Random generator.
    @param exp Optional biased exponent (1..30).
    @return FP16 bit pattern.
    """
    if exp is None:
        exp = rng.randint(1, 30)
    return (rng.getrandbits(1) << 15) | (exp << 10) | rng.getrandbits(10)


def _rand_subnormal(rng):
    """@brief Random non-zero subnormal FP16 word.

    @param rng Random generator.
    @return FP16 bit pattern.
    """
    frac = rng.getrandbits(10) or 1
    return (rng.getrandbits(1) << 15) | frac


def _clamp_exp(e):
    """@brief Clamp a biased exponent to the finite normal range."""
    return max(1, min(30, e))


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
            e = rng.randint(1, 30)
            a = _rand_normal(rng, e)
            b = _rand_normal(rng, e)
        elif name == "dexp_1_3":
            e1 = rng.randint(4, 27)
            d = rng.randint(1, 3)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_4_25":
            e1 = rng.randint(5, 26)
            d = rng.randint(4, 10)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_26_100":
            e1 = rng.randint(11, 20)
            d = rng.randint(5, 15)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 + rng.choice((-d, d))))
        elif name == "dexp_gt_100":
            e1 = rng.randint(28, 30)
            d = rng.randint(1, 25)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, _clamp_exp(e1 - d))
        elif name == "cancel":
            a = _rand_normal(rng)
            n = rng.randint(1, 8)
            low = rng.getrandbits(n)
            b = (a ^ 0x8000) & ~((1 << n) - 1)
            b |= low
            if ((b >> 10) & 0x1F) == 0x1F:
                b = a ^ 0x8000
        elif name == "subnormal":
            a = _rand_subnormal(rng)
            b = _rand_subnormal(rng) if rng.random() < 0.5 else _rand_normal(rng)
        elif name == "underflow":
            e1 = rng.randint(1, 6)
            a = _rand_normal(rng, e1)
            b = (_rand_normal(rng, e1) ^ 0x8000) if rng.random() < 0.7 else _rand_subnormal(rng)
        elif name == "overflow":
            e1 = rng.randint(28, 30)
            a = _rand_normal(rng, e1)
            b = _rand_normal(rng, rng.randint(28, 30))
        else:  # chaos: fully random words (may be NaN/Inf)
            a = rng.getrandbits(16)
            b = rng.getrandbits(16)
        out.append((a & 0xFFFF, b & 0xFFFF, name))
    return out


# ---------------------------------------------------------------------------
# Independent self-check (exact rational arithmetic)
# ---------------------------------------------------------------------------

def _f16_frac(u):
    """@brief Convert a finite FP16 word to an exact Fraction.

    @param u FP16 bit pattern.
    @return Exact value as Fraction.
    """
    s = (u >> 15) & 1
    ef = (u >> 10) & 0x1F
    fr = u & 0x3FF
    if ef == 0:
        v = Fraction(fr, 1 << 24)
    else:
        v = Fraction(fr | 0x400) * (Fraction(2) ** (ef - 25))
    return -v if s else v


def _ref_via_fraction(x, mode):
    """@brief Independent reference: round an exact Fraction to FP16.

    Uses a binary search over the monotonic positive-FP16 bit patterns.

    @param x Exact value (Fraction), non-zero.
    @param mode 'rtz' or 'rne'.
    @return FP16 bit pattern.
    """
    sign = 1 if x < 0 else 0
    mag = -x if sign else x
    if mag >= Fraction(1 << 16):
        return (sign << 15) | INF_F16

    lo, hi = 0, 0x7BFF
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if _f16_frac(mid) <= mag:
            lo = mid
        else:
            hi = mid - 1
    f_lo = _f16_frac(lo)

    if f_lo == mag or mode == "rtz":
        w = lo
    elif lo == 0x7BFF:
        # Midpoint between max_normal and 2^16.
        half_ulp = Fraction(1 << 14)
        w = 0x7C00 if (mag - f_lo) >= half_ulp else 0x7BFF
    else:
        up = lo + 1
        d_lo = mag - f_lo
        d_up = _f16_frac(up) - mag
        if d_lo < d_up:
            w = lo
        elif d_up < d_lo:
            w = up
        else:
            w = lo if (lo & 1) == 0 else up
    return (sign << 15) | w


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
        expected = add_f16(a, b, mode)
        if ca == "zero" and cb == "zero":
            exact_bits = ((a >> 15) & 1 & ((b >> 15) & 1)) << 15
        elif ca == "zero":
            exact_bits = b
        elif cb == "zero":
            exact_bits = a
        else:
            exact = _f16_frac(a) + _f16_frac(b)
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
        description="Generate FP16 + FP16 -> FP16 test vectors (RTZ / RNE)")
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
        out_path = "build/vhfastmulb16_add_fp16_{}_lat4_rand.hex".format(args.mode)
    if not os.path.isabs(out_path):
        out_path = os.path.join(BASE, out_path)

    cases = [(a, b, label) for a, b, label in DIRECTED]
    cases += random_cases(args.count - len(DIRECTED), args.seed)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(out_path, "w", encoding="ascii") as f:
        for a, b, _label in cases:
            f.write("{:04X}{:04X}{:04X}\n".format(a, b, add_f16(a, b, args.mode)))

    if not args.no_labels:
        with open(out_path + ".labels", "w", encoding="ascii") as f:
            for _a, _b, label in cases:
                f.write(label + "\n")

    print("generated {} vectors [{}] -> {}".format(len(cases), args.mode, out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
