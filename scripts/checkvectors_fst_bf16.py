#!/usr/bin/env python3
# =============================================================================
# checkvectors_fst_bf16.py
# Проверка тестовых векторов умножения BF16 (FAST / fst_lat3, RTZ + FTZ).
#
# Проверяет:
#   1) сгенерированный hex-файл (build/..._fst_lat3_rand.hex, 48-битные строки
#      A|B|C) на соответствие bit-exact модели из gen_fst_bf16_vectors.py;
#   2) JSON-векторы test_values_mul_bf16_bf16_fst_rtz.json на соответствие модели.
#
# Модель (frozen contract):
#   rules/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.md
#   FTZ входов, RTZ, канонический qNaN 0x7FC0 (без знака), знак XOR на Inf/zero/normal.
# =============================================================================

import argparse
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import gen_fst_bf16_vectors as G  # noqa: E402

DEFAULT_HEX = os.path.join(
    PROJECT_ROOT, "build",
    "vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_rand.hex")
DEFAULT_JSON = os.path.join(
    PROJECT_ROOT, "testvalues", "mul", "test_values_mul_bf16_bf16_bf16",
    "test_values_mul_bf16_bf16_fst_rtz.json")


def check_hex(hex_path, verbose=False):
    """@brief Validate a 48-bit hex vector file against the reference model.

    Each line: 12 hex chars = A(4) B(4) C(4).
    """
    if not os.path.exists(hex_path):
        print("ERROR: hex file not found: {}".format(hex_path))
        return 1

    total = 0
    errors = 0
    with open(hex_path, "r", encoding="ascii") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            if len(line) != 12:
                errors += 1
                print("FAIL line {}: bad length '{}'".format(lineno, line))
                continue
            a = int(line[0:4], 16)
            b = int(line[4:8], 16)
            c = int(line[8:12], 16)
            got = G.mul_bf16_fst_rtz(a, b)
            total += 1
            if got != c:
                errors += 1
                if errors <= 20:
                    print("FAIL line {}: a={:04X} b={:04X} exp={:04X} got={:04X}".format(
                        lineno, a, b, c, got))
    print("hex  : checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


def check_json(json_path, verbose=False):
    """@brief Validate JSON testvalues against the reference model."""
    if not os.path.exists(json_path):
        print("ERROR: JSON not found: {}".format(json_path))
        return 1

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    def in_hex(item, key):
        ia = item["input_" + key]
        if isinstance(ia, dict):
            return ia["hex"] if "hex" in ia else ia["bf16"]
        return ia

    def out_hex(item):
        oc = item["output_c"]
        if isinstance(oc, dict):
            return oc["hex"] if "hex" in oc else oc["bf16"]["hex"]
        return oc

    total = 0
    errors = 0
    for group in ("test_vectors", "extended_vectors"):
        for item in data.get(group, []):
            a = int(in_hex(item, "a"), 16)
            b = int(in_hex(item, "b"), 16)
            c = int(out_hex(item), 16)
            got = G.mul_bf16_fst_rtz(a, b)
            total += 1
            if got != c:
                errors += 1
                print("FAIL #{}: a={:04X} b={:04X} exp={:04X} got={:04X}".format(
                    item.get("no"), a, b, c, got))
    print("json : checked {} vectors, errors {}".format(total, errors))
    return 0 if errors == 0 else 1


def main():
    parser = argparse.ArgumentParser(
        description="Validate BF16 x BF16 -> BF16 (fst_lat3, RTZ/FTZ) vectors")
    parser.add_argument("--hex", default=DEFAULT_HEX,
                        help="hex vector file to check")
    parser.add_argument("--json", default=DEFAULT_JSON,
                        help="JSON testvalues to check")
    parser.add_argument("--skip-hex", action="store_true",
                        help="do not check the hex file")
    parser.add_argument("--skip-json", action="store_true",
                        help="do not check the JSON file")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="verbose output")
    args = parser.parse_args()

    rc = 0
    if not args.skip_hex:
        rc |= check_hex(args.hex, args.verbose)
    if not args.skip_json:
        rc |= check_json(args.json, args.verbose)

    print("=" * 50)
    print("RESULT: {}".format("PASS" if rc == 0 else "FAIL"))
    return 0 if rc == 0 else 1


if __name__ == "__main__":
    sys.exit(main())