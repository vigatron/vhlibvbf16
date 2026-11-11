# DUT Source Files List (src/*.v)

Total modules: **17**

| # | File | Module | Description | Latency |
|---|------|--------|-------------|---------|
| 1 | `vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | 4x4-bit multiplication without the `*` operator (CSA tree) | 1 clk |
| 2 | `vhfastmulb16_mul4x4_lat2.v` | `vhfastmulb16_mul4x4_lat2` | 4x4-bit multiplication (CSA tree), 2-stage pipeline | 2 clk |
| 3 | `vhfastmulb16_mul4x4_comb.v` | `vhfastmulb16_mul4x4_comb` | 4x4-bit combinational multiplication (CSA tree, no output register) | 0 clk |
| 4 | `vhfastmulb16_mul8x8.v` | `vhfastmulb16_mul8x8` | 8x8-bit multiplication via 4 instances of `mul4x4` | 2 clk |
| 5 | `vhfastmulb16_mul8x8_lat3.v` | `vhfastmulb16_mul8x8_lat3` | 8x8-bit multiplication via 4 instances of `mul4x4_lat2` | 3 clk |
| 6 | `vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Addition of two 8-bit numbers and subtraction of 127 (bias) | 2 clk |
| 7 | `vhfastmulb16_add8x8_branch.v` | `vhfastmulb16_add8x8` | Addition of two 8-bit numbers and subtraction of 127 | 2 clk |
| 8 | `vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Sign cascade (XOR) with 3 outputs | 1/2/3 clk |
| 9 | `vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Exponent/mantissa flags (zero/subnormal/normal/inf/nan) | 1 clk |
| 10 | `vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Exponent/mantissa flags (2-stage pipeline) | 2 clk |
| 11 | `vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Exception handling (NaN/Inf/Zero) for latency-2 pipeline | 2 clk |
| 12 | `vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Exception handling (NaN/Inf/Zero) for latency-3 pipeline | 3 clk |
| 13 | `vhfastmulb16_rtz_lat3.v` | `vhfastmulb16_rtz_lat3` | Top-level BF16 multiplier with **RTZ** rounding (truncation) | 3 clk |
| 14 | `vhfastmulb16_rne_lat3.v` | `vhfastmulb16_rne_lat3` | Top-level BF16 multiplier with **RNE** rounding (IEEE 754) | 3 clk |
| 15 | `vhfastmulb16_f32_lat4.v` | `vhfastmulb16_f32_lat4` | Top-level BF16 x BF16 -> **F32** exact multiplier, no rounding | 4 clk |
| 16 | `vhfastmulb16_addf32_rtz_lat4.v` | `vhfastmulb16_addf32_rtz_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RTZ** rounding | 4 clk |
| 17 | `vhfastmulb16_addf32_rne_lat4.v` | `vhfastmulb16_addf32_rne_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RNE** rounding | 4 clk |

---

## Module Dependencies

```
vhfastmulb16_rtz_lat3 / vhfastmulb16_rne_lat3
├── vhfastmulb16_add8x8_lat2
├── vhfastmulb16_mul8x8
│   └── vhfastmulb16_mul4x4 (x4)
├── vhfastmulb16_sign
├── vhfastmulb16_flags_lat1 (in except_lat2)
├── vhfastmulb16_flags_lat2 (in except_lat3)
├── vhfastmulb16_except_lat2 (in rtz/rne latency-3)
└── vhfastmulb16_except_lat3 (alternative for latency-3)

vhfastmulb16_f32_lat4
├── vhfastmulb16_mul4x4_comb (x4)
└── vhfastmulb16_sign

vhfastmulb16_addf32_rtz_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_addf32_rne_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)
```

---

## Versions with Different Latency

| Component | Latency 1 | Latency 2 | Latency 3 | Latency 4 |
|-----------|-----------|-----------|-----------|-----------|
| Mul4x4 | `mul4x4` | `mul4x4_lat2` | - | - |
| Mul8x8 | - | `mul8x8` | `mul8x8_lat3` | - |
| Flags | `flags_lat1` | `flags_lat2` | - | - |
| Exceptions | - | `except_lat2` | `except_lat3` | - |
| Top-level | - | - | `rtz_lat3`, `rne_lat3` | `f32_lat4`, `addf32_rtz_lat4`, `addf32_rne_lat4` |

Note: `vhfastmulb16_mul4x4_comb` is the purely combinational variant (latency 0).

---

## Current Source Directory Contents

The `src/` directory contains the following 17 Verilog source files:

- `vhfastmulb16_add8x8_branch.v`
- `vhfastmulb16_add8x8_lat2.v`
- `vhfastmulb16_addf32_rne_lat4.v`
- `vhfastmulb16_addf32_rtz_lat4.v`
- `vhfastmulb16_except_lat2.v`
- `vhfastmulb16_except_lat3.v`
- `vhfastmulb16_f32_lat4.v`
- `vhfastmulb16_f32_lat4.v`
- `vhfastmulb16_flags_lat1.v`
- `vhfastmulb16_flags_lat2.v`
- `vhfastmulb16_mul4x4.v`
- `vhfastmulb16_mul4x4_comb.v`
- `vhfastmulb16_mul4x4_lat2.v`
- `vhfastmulb16_mul4x4_comb.v`
- `vhfastmulb16_mul4x4_lat2.v`
- `vhfastmulb16_mul8x8.v`
- `vhfastmulb16_mul8x8_lat3.v`
- `vhfastmulb16_mul8x8_lat3.v`
- `vhfastmulb16_rne_lat3.v`
- `vhfastmulb16_rtz_lat3.v`
- `vhfastmulb16_sign.v`

No deprecated files are kept in the current version of `src/`.
