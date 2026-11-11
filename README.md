# vhlibvbf16

![Verilog-2005](https://img.shields.io/badge/DUT_Verilog--2005_(IEEE_1364--2005)-1364FF)
![SystemVerilog-2012](https://img.shields.io/badge/TB_SystemVerilog--2012_(IEEE_1800--2012)-CC3300)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Date](https://img.shields.io/badge/date-2026--11--06-informational)
![Status](https://img.shields.io/badge/status-initial_version-orange)
![Build](https://img.shields.io/badge/build-verified-brightgreen)


Compact pipelined BFloat16 multiplier (Verilog) — RTZ/RNE, no DSP required.  

Author: V01G04A81  
Rev: 0.0.3  


`vhfastmulb16` is a hardware implementation of a BFloat16 (Brain Floating Point) multiplier.
It multiplies two BF16 numbers and produces a BF16 result on the output.

The DUT is written in plain **Verilog-2005** (IEEE 1364-2005, no SystemVerilog
constructs in `src/`); the testbenches in `tests/` are **SystemVerilog**
(compiled with `iverilog -g2012`, IEEE 1800-2012).
The design supports two rounding modes:

- **RTZ** (Round Toward Zero) — truncation, simple discard of the lower bits;
- **RNE** (Round to Nearest Even) — IEEE 754 rounding.

The implementation does not require any DSP blocks: the multiplication is built
from a carry-save adder (CSA) tree and a final 16-bit carry-propagate adder (CPA).

## Arithmetic Specification

| Feature | Behavior |
|---------|----------|
| **Format** | BF16: `s[15] \| exp[14:7] \| frac[6:0]` (8-bit exponent, bias 127; 7-bit mantissa) |
| **Rounding** | RTZ (truncation) in `vhfastmulb16_rtz_lat3`; RNE (IEEE 754 round-to-nearest-even) in `vhfastmulb16_rne_lat3` |
| **Subnormal inputs** | **Flush To Zero (FTZ)**: subnormal operands (`exp=0`, `frac≠0`) are flushed to zero before the pipeline; ±0 is already zero |
| **Subnormal results** | Not generated: exp underflow (≤0 after normalization) flushes the result to ±0 |
| **Zero** | Zero operand (`exp=0`), unless the other operand is Inf or NaN → result ±0 (canonical `s\|8'h00\|7'h00`) |
| **Infinity** | Inf operand (`exp=255, frac=0`) and no NaN → result ±Inf (`s\|8'hFF\|7'h00`); Inf × 0 = NaN |
| **NaN** | Any operand with `exp=255, frac≠0` → quiet NaN, payload preserved (priority A > B): `s\|8'hFF\|1'b1\|payload[5:0]` |
| **Exception priority** | NaN > Inf > Zero > normal multiply; overflow saturates to ±Inf, underflow flushes to ±0 |
| **Sign** | `sign_a XOR sign_b` for all results, including NaN |
| **Pipeline** | 3 clock cycles latency, full-drain behavior: after `en=0` the pipeline finishes accepted data for 2 more cycles, then holds the last result (HOLD, no zero-fill) |

### F32-output module (`vhfastmulb16_f32_lat4`)

| Feature | Behavior |
|---------|----------|
| **Format** | Input BF16; output F32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Rounding** | None: normal products are exact; F32 subnormal results are truncated (RTZ) |
| **Subnormal inputs** | **Not flushed**: BF16 subnormals are normalized into the F32 result |
| **Subnormal results** | F32 subnormal, truncated (RTZ); underflow below `2^-149` → signed zero |
| **NaN** | Canonical quiet NaN `0x7FC00000` |
| **Overflow** | Result outside F32 range → `±Inf` with sign = XOR of signs |
| **Pipeline** | 4 clock cycles latency, fully pipelined; after `en=0` drains for 3 cycles, then holds |

### FP32-adder modules (`vhfastmulb16_addf32_rtz_lat4`, `vhfastmulb16_addf32_rne_lat4`)

| Feature | `addf32_rtz_lat4` | `addf32_rne_lat4` |
|---------|-------------------|-------------------|
| **Format** | FP32 + FP32 -> FP32: `s[31] \| exp[30:23] \| frac[22:0]` | FP32 + FP32 -> FP32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Rounding** | RTZ (round toward zero — truncation) | RNE (round-to-nearest-even, IEEE 754 default) |
| **Subnormal inputs** | **Not flushed**: treated as finite values (no FTZ) | **Not flushed**: treated as finite values (no FTZ) |
| **Subnormal results** | Truncated (RTZ); exp ≤ 0 → signed zero | Rounded (RNE); exp ≤ 0 → signed zero or subnormal |
| **NaN** | Quiet NaN; sign and payload preserved from NaN operand | Quiet NaN; sign and payload preserved from NaN operand |
| **Zero sign** | IEEE-754 default: (+0)+(-0) = +0, (-0)+(-0) = -0 | IEEE-754 default: (+0)+(-0) = +0, (-0)+(-0) = -0 |
| **Infinity** | ±Inf propagated; (+Inf)+(-Inf) → qNaN | ±Inf propagated; (+Inf)+(-Inf) → qNaN |
| **Overflow** | Result > F32 max → ±Inf with sign of result | Result > F32 max → ±Inf with sign of result |
| **Pipeline** | 4 clock cycles latency, fully pipelined; HOLD on `en=0` | 4 clock cycles latency, fully pipelined; HOLD on `en=0` |

## Development Status

- The BF16-output top-level modules `vhfastmulb16_rtz_lat3` and `vhfastmulb16_rne_lat3` are available (latency 3).
- The F32-output top-level module `vhfastmulb16_f32_lat4` is available (latency 4): exact BF16 x BF16 product represented as IEEE-754 binary32, no rounding, BF16 subnormals are not flushed, F32 subnormal results are truncated (RTZ).
- The FP32-adder top-level modules `vhfastmulb16_addf32_rtz_lat4` and `vhfastmulb16_addf32_rne_lat4` are available (latency 4): FP32 + FP32 -> FP32 with RTZ and RNE rounding respectively.
- The building blocks are available: `vhfastmulb16_mul4x4_comb`, `vhfastmulb16_mul4x4_lat2`, `vhfastmulb16_mul8x8`, `vhfastmulb16_mul8x8_lat3`, `vhfastmulb16_add8x8_lat2`, `vhfastmulb16_flags_lat2`, `vhfastmulb16_except_lat2`, `vhfastmulb16_except_lat3`.
- `vhfastmulb16_fst_lat3` is a planned simplified variant; it is **not present in `src/` yet**.
- The modules are implemented in pure logic without the multiplication operator `*`; replacing the whole `mul8x8` multiplier (4× `mul4x4` + CSA tree + CPA) with a DSP (for example, a DSP48A1) would save up to 50% of LUTs and significantly increase the operating speed.

## Source Files

The `src/` directory contains **17** Verilog source files:

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

## Top Modules

The following top-level modules are the primary entry points of the library:

| Module | File | Function | Output Format | Latency | Rounding |
|--------|------|----------|---------------|---------|----------|
| `vhfastmulb16_rtz_lat3` | `src/vhfastmulb16_rtz_lat3.v` | BF16 × BF16 multiplier | BF16 | 3 clk | RTZ (truncation) |
| `vhfastmulb16_rne_lat3` | `src/vhfastmulb16_rne_lat3.v` | BF16 × BF16 multiplier | BF16 | 3 clk | RNE (IEEE-754) |
| `vhfastmulb16_f32_lat4` | `src/vhfastmulb16_f32_lat4.v` | BF16 × BF16 multiplier | F32 | 4 clk | None (exact) |
| `vhfastmulb16_addf32_rtz_lat4` | `src/vhfastmulb16_addf32_rtz_lat4.v` | FP32 + FP32 adder | F32 | 4 clk | RTZ (truncation) |
| `vhfastmulb16_addf32_rne_lat4` | `src/vhfastmulb16_addf32_rne_lat4.v` | FP32 + FP32 adder | F32 | 4 clk | RNE (IEEE-754) |

### Module Dependencies

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

### Versions with Different Latency

| Component | Latency 1 | Latency 2 | Latency 3 | Latency 4 |
|-----------|-----------|-----------|-----------|-----------|
| Mul4x4 | `vhfastmulb16_mul4x4` | `vhfastmulb16_mul4x4_lat2` | - | - |
| Mul8x8 | - | `vhfastmulb16_mul8x8` | `vhfastmulb16_mul8x8_lat3` | - |
| Flags | `vhfastmulb16_flags_lat1` | `vhfastmulb16_flags_lat2` | - | - |
| Exceptions | - | `vhfastmulb16_except_lat2` | `vhfastmulb16_except_lat3` | - |
| Top-level (BF16 mul) | - | - | `vhfastmulb16_rtz_lat3`, `vhfastmulb16_rne_lat3` | `vhfastmulb16_f32_lat4` |
| Top-level (FP32 add) | - | - | - | `vhfastmulb16_addf32_rtz_lat4`, `vhfastmulb16_addf32_rne_lat4` |

## Testbenches

The testbenches are located in the [tests/](tests/) directory, and the run scripts are located in the [scripts/](scripts/) directory.

| Testbench | Module under test |
|-----------|-------------------|
| `tests/vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` |
| `tests/vhfastmulb16_mul4x4_chk_tb.v` | `vhfastmulb16_mul4x4` (check/debug) |
| `tests/vhfastmulb16_mul4x4_lat2_tb.v` | `vhfastmulb16_mul4x4_lat2` |
| `tests/vhfastmulb16_mul4x4_lat2_chk_tb.v` | `vhfastmulb16_mul4x4_lat2` (check/debug) |
| `tests/vhfastmulb16_mul8x8_tb.v` | `vhfastmulb16_mul8x8` |
| `tests/vhfastmulb16_mul8x8_chk_tb.v` | `vhfastmulb16_mul8x8` (check/debug) |
| `tests/vhfastmulb16_mul8x8_lat3_tb.v` | `vhfastmulb16_mul8x8_lat3` |
| `tests/vhfastmulb16_mul8x8_lat3_chk_tb.v` | `vhfastmulb16_mul8x8_lat3` (check/debug) |
| `tests/vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8_lat2` |
| `tests/vhfastmulb16_add8x8_reva_tb.v` | `vhfastmulb16_add8x8_lat2` (exhaustive, 256×256) |
| `tests/vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` |
| `tests/vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` |
| `tests/vhfastmulb16_flags_lat2_tb.v` | `vhfastmulb16_flags_lat2` |
| `tests/vhfastmulb16_flags_lat2_chk_tb.v` | `vhfastmulb16_flags_lat2` (check/debug) |
| `tests/vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` |
| `tests/vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` |
| `tests/vhfastmulb16_rtz_lat3_tb.v` | `vhfastmulb16_rtz_lat3` |
| `tests/vhfastmulb16_rne_lat3_tb.v` | `vhfastmulb16_rne_lat3` |
| `tests/vhfastmulb16_f32_lat4_tb.v` | `vhfastmulb16_f32_lat4` (directed, LAT=4) |
| `tests/vhfastmulb16_f32_lat4_rand_tb.v` | `vhfastmulb16_f32_lat4` (random regression, LAT=4) |
| `tests/vhfastmulb16_addf32_rtz_lat4_tb.v` | `vhfastmulb16_addf32_rtz_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/vhfastmulb16_addf32_rne_lat4_tb.v` | `vhfastmulb16_addf32_rne_lat4` (directed + en=0 gaps, LAT=4) |

Most testbenches have a dedicated run script. In particular, several
`*_chk_tb.v` benches are also runnable directly:

| Script | Testbench |
|--------|-----------|
| `scripts/run_test_add8x8_lat2.sh` | `tests/vhfastmulb16_add8x8_tb.v` |
| `scripts/run_test_flags_lat2.sh` | `tests/vhfastmulb16_flags_lat2_chk_tb.v` |
| `scripts/run_test_mul4x4_lat2.sh` | `tests/vhfastmulb16_mul4x4_lat2_chk_tb.v` |
| `scripts/run_test_mul8x8_lat3.sh` | `tests/vhfastmulb16_mul8x8_lat3_chk_tb.v` |
| `scripts/run_test_mul8x8_chk.sh` | `tests/vhfastmulb16_mul8x8_chk_tb.v` |

See `scripts/run_test_*.sh` for the complete mapping.

Run the simulation with:

```bash
# All testbench scripts
./scripts/run_all.sh sim

# Individual tests
./scripts/run_test_mul4x4.sh sim
./scripts/run_test_mul4x4_lat2.sh sim
./scripts/run_test_mul8x8.sh sim
./scripts/run_test_mul8x8_lat3.sh sim
./scripts/run_test_add8x8_lat2.sh sim
./scripts/run_test_sign.sh sim
./scripts/run_test_flags_lat1.sh sim
./scripts/run_test_flags_lat2.sh sim
./scripts/run_test_except_lat2.sh sim
./scripts/run_test_except_lat3.sh sim
./scripts/run_test_mul_fb16_rtz_lat3.sh sim
./scripts/run_test_mul_fb16_rne_lat3.sh sim
./scripts/run_test_f32_lat4.sh sim
./scripts/run_test_f32_lat4_rand.sh sim
./scripts/run_test_addf32_rtz_lat4.sh sim
./scripts/run_test_addf32_rne_lat4.sh sim

# Visualization (gtkwave)
./scripts/run_test_mul4x4.sh wave
./scripts/run_test_mul8x8.sh wave
./scripts/run_test_f32_lat4.sh wave
./scripts/run_test_f32_lat4_rand.sh wave

# Clean up build artifacts
./scripts/run_all.sh clean
```

`run_all.sh` runs every `scripts/run_test_*.sh`; the benches without a dedicated
script (`vhfastmulb16_mul4x4_chk_tb.v`, `vhfastmulb16_add8x8_reva_tb.v`) are not included.
See the [docs/testbenches_list.md](docs/testbenches_list.md) file for more details.


## FPGA Resource Estimates

The implementation is estimated for Xilinx Spartan-6 (XC6SLX9, XC6SLX16),
Spartan-7 (XC7S15) and Artix-7 (XC7A15T).
Detailed manual RTL estimates are maintained in:

- [`docs/stat/stat_top_all.md`](docs/stat/stat_top_all.md) — comparison of the top-level modules (RTZ, RNE, F32) across FPGA families;
- [`docs/stat/stat_others_all.md`](docs/stat/stat_others_all.md) — submodules and bottom-up breakdown;
- [`docs/stat/stat_top_spartan6.md`](docs/stat/stat_top_spartan6.md), [`docs/stat/stat_top_spartan7.md`](docs/stat/stat_top_spartan7.md), [`docs/stat/stat_top_artix7.md`](docs/stat/stat_top_artix7.md) — per-device details.

All values are manual estimates (±20–25%), not synthesis reports.

## Author

Author: Viktor Glebov / V01G04A81 2026

## License

MIT

<https://github.com/vigatron/vhlibvbf16>
