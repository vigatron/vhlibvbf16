# DUT Source Files List (src/*.v)

Total modules: **11**

| # | File | Module | Description | Latency |
|---|------|--------|-------------|---------|
| 1 | `vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | 4x4-bit multiplication without the `*` operator (CSA tree) | 1 clk |
| 2 | `vhfastmulb16_mul8x8.v` | `vhfastmulb16_mul8x8` | 8x8-bit multiplication via 4 instances of `mul4x4` | 2 clk |
| 3 | `vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Addition of two 8-bit numbers and subtraction of 127 (bias) | 2 clk |
| 4 | `vhfastmulb16_add8x8_branch.v` | `vhfastmulb16_add8x8` | Addition of two 8-bit numbers and subtraction of 127 | 2 clk |
| 5 | `vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Sign cascade (XOR) with 3 outputs | 1/2/3 clk |
| 6 | `vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Exponent/mantissa flags (zero/subnormal/normal/inf/nan) | 1 clk |
| 7 | `vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Exponent/mantissa flags (2-stage pipeline) | 2 clk |
| 8 | `vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Exception handling (NaN/Inf/Zero) for latency-2 pipeline | 2 clk |
| 9 | `vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Exception handling (NaN/Inf/Zero) for latency-3 pipeline | 3 clk |
| 10 | `vhfastmulb16_rtz_lat3.v` | `vhfastmulb16_rtz_lat3` | Top-level BF16 multiplier with **RTZ** rounding (truncation) | 3 clk |
| 11 | `vhfastmulb16_rne_lat3.v` | `vhfastmulb16_rne_lat3` | Top-level BF16 multiplier with **RNE** rounding (IEEE 754) | 3 clk |

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
```

---

## Versions with Different Latency

| Component | Latency 1 | Latency 2 | Latency 3 |
|-----------|-----------|-----------|-----------|
| Flags | `flags_lat1` | `flags_lat2` | - |
| Exceptions | - | `except_lat2` | `except_lat3` |
| Top-level | - | - | `rtz_lat3`, `rne_lat3` |

---

## Current Source Directory Contents

The `src/` directory contains the following 11 Verilog source files:

- `vhfastmulb16_add8x8_branch.v`
- `vhfastmulb16_add8x8_lat2.v`
- `vhfastmulb16_except_lat2.v`
- `vhfastmulb16_except_lat3.v`
- `vhfastmulb16_flags_lat1.v`
- `vhfastmulb16_flags_lat2.v`
- `vhfastmulb16_mul4x4.v`
- `vhfastmulb16_mul8x8.v`
- `vhfastmulb16_rne_lat3.v`
- `vhfastmulb16_rtz_lat3.v`
- `vhfastmulb16_sign.v`

No deprecated files are kept in the current version of `src/`.
