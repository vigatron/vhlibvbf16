# FP16 Addition Test Vector Matrix (RNE / RTZ)

FP16 Addition: A + B = C

RNE - Round to Nearest Even, RTZ - Round Toward Zero.

Source: directed vectors from `tests/vhfastmulb16_add_fp16_rne_lat4_tb.v` and `tests/vhfastmulb16_add_fp16_rtz_lat4_tb.v`.

| № | A | B | C (RNE) | C (RTZ) | Description |
| :-: | :-: | :-: | :-: | :-: | :--- |
|  1 | `16'h3C00` | `16'h3C00` | `16'h4000` | `16'h4000` | 1.0 + 1.0 = 2.0 |
|  2 | `16'hBC00` | `16'h3C00` | `16'h0000` | `16'h0000` | -1.0 + 1.0 = +0 |
|  3 | `16'h7C00` | `16'h3C00` | `16'h7C00` | `16'h7C00` | +Inf + 1.0 = +Inf |
|  4 | `16'h7E00` | `16'h3C00` | `16'h7E00` | `16'h7E00` | qNaN + 1.0 = qNaN |
|  5 | `16'h0001` | `16'h0001` | `16'h0002` | `16'h0002` | min_subnormal + min_subnormal = 2^-23 |
|  6 | `16'h7BFF` | `16'h3C00` | `16'h7BFF` | `16'h7BFF` | max_normal + 1.0 -> max_normal (1.0 below ulp) |
|  7 | `16'hFC00` | `16'hFC00` | `16'hFC00` | `16'hFC00` | -Inf + (-Inf) = -Inf |
|  8 | `16'h7C00` | `16'hFC00` | `16'hFE00` | `16'hFE00` | +Inf + (-Inf) = qNaN (sign/payload from op B) |
|  9 | `16'h8000` | `16'h8000` | `16'h8000` | `16'h8000` | -0 + (-0) = -0 |
| 10 | `16'h0000` | `16'h8000` | `16'h0000` | `16'h0000` | +0 + (-0) = +0 (IEEE-754 default) |
| 11 | `16'h4300` | `16'h4100` | `16'h4600` | `16'h4600` | 3.5 + 2.5 = 6.0 |
| 12 | `16'hD640` | `16'h5640` | `16'h0000` | `16'h0000` | -100.0 + 100.0 = +0 |
| 13 | `16'h7E00` | `16'h7E00` | `16'h7E00` | `16'h7E00` | NaN + NaN = qNaN |
| 14 | `16'h0400` | `16'h3C00` | `16'h3C00` | `16'h3C00` | subnormal + 1.0 -> 1.0 |
| 15 | `16'hC400` | `16'hC800` | `16'hCA00` | `16'hCA00` | -3.0 + (-4.0) = -7.0 |
| 16 | `16'h0001` | `16'h0001` | `16'h0002` | `16'h0002` | 2^-24 + 2^-24 = 2^-23 |
| 17 | `16'h8000` | `16'h3C00` | `16'h3C00` | `16'h3C00` | -0 + 1.0 = 1.0 |
| 18 | `16'h5640` | `16'h0001` | `16'h5640` | `16'h5640` | large + small (small below ulp) |
| 19 | `16'h7E12` | `16'h3C00` | `16'h7E12` | `16'h7E12` | NaN with payload, payload preserved |
| 20 | `16'h7C01` | `16'h3C00` | `16'h7E01` | `16'h7E01` | sNaN -> qNaN, payload preserved |
| 21 | `16'h7C00` | `16'h0400` | `16'h7C00` | `16'h7C00` | +Inf + subnormal = +Inf |
| 22 | `16'h0400` | `16'h8400` | `16'h0000` | `16'h0000` | subnormal + (-subnormal) = +0 |
| 23 | `16'h0000` | `16'h0000` | `16'h0000` | `16'h0000` | +0 + +0 = +0 |
| 24 | `16'h8000` | `16'h0000` | `16'h0000` | `16'h0000` | -0 + +0 = +0 |
| 25 | `16'h3C00` | `16'hBC00` | `16'h0000` | `16'h0000` | 1.0 + (-1.0) = +0 |
| 26 | `16'h4000` | `16'hBC00` | `16'h3C00` | `16'h3C00` | 2.0 + (-1.0) = 1.0 |
| 27 | `16'h7BFF` | `16'h7BFF` | `16'h7C00` | `16'h7C00` | max_normal + max_normal = +Inf |
| 28 | `16'hFC00` | `16'h3C00` | `16'hFC00` | `16'hFC00` | -Inf + 1.0 = -Inf |
| 29 | `16'h7E00` | `16'h7C00` | `16'h7E00` | `16'h7E00` | NaN + Inf = qNaN |
| 30 | `16'h3C00` | `16'h0800` | `16'h3C00` | `16'h3C00` | 1.0 + 2^-11 (half ULP, tie to even -> 1.0) |
| 31 | `16'h3C00` | `16'h1400` | `16'h3C01` | `16'h3C01` | 1.0 + 2^-10 (1 ULP) = 1.0 + 2^-10 |
| 32 | `16'hC000` | `16'h4000` | `16'h0000` | `16'h0000` | -2.0 + 2.0 = +0 |

All 32 vectors produce identical results for RNE and RTZ.
