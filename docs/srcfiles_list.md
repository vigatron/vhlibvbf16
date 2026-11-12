# DUT Source Files List (src/*.v)

Total modules: **20**

| # | File | Module | Description | Latency |
|---|------|--------|-------------|---------|
| 1 | `vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | 4x4-bit multiplication without the `*` operator (CSA tree) | 1 clk |
| 2 | `vhfastmulb16_mul4x4_lat2.v` | `vhfastmulb16_mul4x4_lat2` | 4x4-bit multiplication (CSA tree), 2-stage pipeline | 2 clk |
| 3 | `vhfastmulb16_mul4x4_comb.v` | `vhfastmulb16_mul4x4_comb` | 4x4-bit combinational multiplication (CSA tree, no output register) | 0 clk |
| 4 | `vhfastmulb16_mul_u8_u8_u16_lat2.v` | `vhfastmulb16_mul_u8_u8_u16_lat2` | 8x8-bit multiplication via 4 instances of `mul4x4` | 2 clk |
| 5 | `vhfastmulb16_mul_u8_u8_u16_lat3.v` | `vhfastmulb16_mul_u8_u8_u16_lat3` | 8x8-bit multiplication via 4 instances of `mul4x4_lat2` | 3 clk |
| 6 | `vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Addition of two 8-bit numbers and subtraction of 127 (bias) | 2 clk |
| 7 | `vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Sign cascade (XOR) with 3 outputs | 1/2/3 clk |
| 8 | `vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Exponent/mantissa flags (zero/subnormal/normal/inf/nan) | 1 clk |
| 9 | `vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Exponent/mantissa flags (2-stage pipeline) | 2 clk |
| 10 | `vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Exception handling (NaN/Inf/Zero) for latency-2 pipeline | 2 clk |
| 11 | `vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Exception handling (NaN/Inf/Zero) for latency-3 pipeline | 3 clk |
| 12 | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | Top-level BF16 multiplier with **RTZ** rounding (truncation) | 3 clk |
| 13 | `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | Top-level BF16 multiplier with **RNE** rounding (IEEE 754) | 3 clk |
| 14 | `vhfastmulb16_mul_bf16_bf16_fp32_lat4.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | Top-level BF16 x BF16 -> **F32** exact multiplier, no rounding | 4 clk |
| 15 | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RTZ** rounding | 4 clk |
| 16 | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RNE** rounding | 4 clk |
| 17 | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | Top-level FP16 + FP16 -> **F16** adder with **RTZ** rounding | 4 clk |
| 18 | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | Top-level FP16 + FP16 -> **F16** adder with **RNE** rounding | 4 clk |
| 19 | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | Top-level BF16 + BF16 -> **BF16** adder with **RTZ** rounding | 4 clk |
| 20 | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | Top-level BF16 + BF16 -> **BF16** adder with **RNE** rounding | 4 clk |

---

## Module Dependencies

```
vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3 / vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3
├── vhfastmulb16_add8x8_lat2
├── vhfastmulb16_mul_u8_u8_u16_lat2
│   └── vhfastmulb16_mul4x4 (x4)
├── vhfastmulb16_sign
├── vhfastmulb16_flags_lat1 (in except_lat2)
├── vhfastmulb16_flags_lat2 (in except_lat3)
├── vhfastmulb16_except_lat2 (in rtz/rne latency-3)
└── vhfastmulb16_except_lat3 (alternative for latency-3)

vhfastmulb16_mul_bf16_bf16_fp32_lat4
├── vhfastmulb16_mul4x4_comb (x4)
└── vhfastmulb16_sign

vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_add_fp32_fp32_fp32_rne_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_add_fp16_fp16_fp16_rne_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)

vhfastmulb16_add_bf16_bf16_bf16_rne_lat4
  (autonomous, no dependencies on other vhfastmulb16_* modules)
```

---

## Versions with Different Latency

| Component | Latency 1 | Latency 2 | Latency 3 | Latency 4 |
|-----------|-----------|-----------|-----------|-----------|
| Mul4x4 | `mul4x4` | `mul4x4_lat2` | - | - |
| Mul8x8 | - | `mul_u8_u8_u16_lat2` | `mul_u8_u8_u16_lat3` | - |
| Flags | `flags_lat1` | `flags_lat2` | - | - |
| Exceptions | - | `except_lat2` | `except_lat3` | - |
| Top-level (BF16 × BF16) | - | - | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` |
| Top-level (FP32 add) | - | - | - | `add_fp32_fp32_fp32_rtz_lat4`, `add_fp32_fp32_fp32_rne_lat4` |
| Top-level (FP16 add) | - | - | - | `add_fp16_fp16_fp16_rtz_lat4`, `add_fp16_fp16_fp16_rne_lat4` |
| Top-level (BF16 add) | - | - | - | `add_bf16_bf16_bf16_rtz_lat4`, `add_bf16_bf16_bf16_rne_lat4` |

Note: `vhfastmulb16_mul4x4_comb` is the purely combinational variant (latency 0).

---

## Current Source Directory Contents

The `src/` directory contains the following 20 Verilog source files:

- `vhfastmulb16_add8x8_lat2.v`
- `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.v`
- `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4.v`
- `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4.v`
- `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4.v`
- `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4.v`
- `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4.v`
- `vhfastmulb16_except_lat2.v`
- `vhfastmulb16_except_lat3.v`
- `vhfastmulb16_mul_bf16_bf16_fp32_lat4.v`
- `vhfastmulb16_flags_lat1.v`
- `vhfastmulb16_flags_lat2.v`
- `vhfastmulb16_mul4x4.v`
- `vhfastmulb16_mul4x4_comb.v`
- `vhfastmulb16_mul4x4_lat2.v`
- `vhfastmulb16_mul_u8_u8_u16_lat2.v`
- `vhfastmulb16_mul_u8_u8_u16_lat3.v`
- `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3.v`
- `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3.v`
- `vhfastmulb16_sign.v`

No deprecated files are kept in the current version of `src/`.
