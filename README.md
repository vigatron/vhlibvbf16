# vhlibvbf16

![Verilog-2005](https://img.shields.io/badge/DUT_Verilog--2005_(IEEE_1364--2005)-1364FF)
![SystemVerilog-2012](https://img.shields.io/badge/TB_SystemVerilog--2012_(IEEE_1800--2012)-CC3300)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Rev](https://img.shields.io/badge/Rev-0.0.12-informational)
![Date](https://img.shields.io/badge/date-2026--11--16-informational)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Tests](https://img.shields.io/badge/tests-run__all.sh%20PASSED%2038%2F38-brightgreen)


Author: V01G04A81  
Rev: 0.0.13  


## Description

Compact pipelined BF16/FP32 arithmetic library (Verilog)<br>
BF16 multiplier (RTZ / RNE / **FAST max-Fmax**), BF16×BF16→F32 multiplier, BF16×BF16+FP32 fused multiply-add (RNE and **FAST max-Fmax** variants, including the `vhfma001` max-Fmax clone and the `vhfma002` DSP-mapped variant), BF16 adders, FP32 adders and FP16 adders; RTZ/RNE; the reference implementation does not require DSP blocks (a single allowed exception exists — see [DSP Block Exception](#dsp-block-exception-vhfma002)).

`vhfastmulb16_mul_bf16_bf16_bf16` is a hardware implementation of a BFloat16 (Brain Floating Point) multiplier.
It multiplies two BF16 numbers and produces a BF16 result on the output.


## Top Modules

The following top-level modules are the primary entry points of the library:

### Multiplication Modules

| Module | Function | Output Format | Latency | Rounding |
|---------|----------|---------------|---------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | BF16 × BF16 multiplier | BF16 | 3 clk | RTZ (truncation) |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | BF16 × BF16 multiplier | BF16 | 3 clk | RNE (IEEE-754) |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | BF16 × BF16 multiplier (**FAST / max-Fmax**) | BF16 | 3 clk | RTZ (truncation), FTZ |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | BF16 × BF16 multiplier | F32 | 4 clk | None (exact) |

### Addition Modules

| Module | Function | Output Format | Latency | Rounding |
|---------|----------|---------------|---------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | FP32 + FP32 adder | F32 | 4 clk | RTZ (truncation) |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | FP32 + FP32 adder | F32 | 4 clk | RNE (IEEE-754) |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | FP16 + FP16 adder | F16 | 4 clk | RTZ (truncation) |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | FP16 + FP16 adder | F16 | 4 clk | RNE (IEEE-754) |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | BF16 + BF16 adder | BF16 | 4 clk | RTZ (truncation) |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | BF16 + BF16 adder | BF16 | 4 clk | RNE (IEEE-754) |

### Combined Modules

| Module | Function | Output Format | Latency | Rounding |
|---------|----------|---------------|---------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | BF16 × BF16 + FP32 fused multiply-add | F32 | 4 clk | RNE (IEEE-754) |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax) | F32 | 8 clk | RNE (IEEE-754) |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | BF16 × BF16 + FP32 fused multiply-add (**FAST / max-Fmax**) | F32 | 8 clk | RTZ (truncation), FTZ |
| `vhfma001` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax, pure LUT/FF; speed-optimized clone of lat8) | F32 | 8 clk | RNE (IEEE-754) |
| `vhfma002` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax; 8x8 BF16 mantissa multiply mapped to one DSP48 — allowed exception) | F32 | 8 clk | RNE (IEEE-754) |

### Auxiliary Modules

Helper modules used internally by the top-level DUTs.


The corresponding files are located in the `src` folder (the multiplication top DUTs are in `src/mul/`, the addition top DUTs are in `src/add/`, the FMA modules are in `src/fma/`, the auxiliary submodules are in `src/aux/`).

The DUT is written in plain **Verilog-2005** (IEEE 1364-2005, no SystemVerilog
constructs in `src/`); the testbenches in `tests/` are **SystemVerilog**
(compiled with `iverilog -g2012`, IEEE 1800-2012).
The design supports two rounding modes:

- **RTZ** (Round Toward Zero) — truncation, simple discard of the lower bits;
- **RNE** (Round to Nearest Even) — IEEE 754 rounding.

The implementation does not require any DSP blocks for the reference flow: the
multiplication is built from a carry-save adder (CSA) tree and a final 16-bit
carry-propagate adder (CPA). A single module is explicitly exempted from this
rule — `vhfma002` (see [DSP Block Exception](#dsp-block-exception-vhfma002)).
All other modules stay in pure LUT/FF logic.

## DSP Block Exception (`vhfma002`)

**`vhfma002` is the only module of the library allowed to use DSP blocks.**

- The 8x8-bit BF16 mantissa multiply is a single `*` operator with
  `(* use_dsp = "yes" *)` and maps onto one DSP48A1 (Spartan-6) or DSP48E1
  (Spartan-7 / Artix-7) cell. Everything else in the module is regular LUT/FF logic.
- Rationale: maximum Fmax at a fixed latency of 8 cycles. The DSP multiply path is
  much shorter than a LUT-based 8x8 multiplier built from four 4x4 `mul4x4_comb`
  instances (that is what `vhfma001` does).
- Interface, latency (8 clk), RNE rounding, subnormal handling, special-case
  semantics and the per-stage clock-enable model are identical to `vhfma001`
  and `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`.
- Synthesis evidence: Yosys (YoWASP) 0.70 reports exactly one DSP48 cell per
  family for `vhfma002` (`DSP48A1` on XC6S, `DSP48E1` on XC7S/XC7A); see
  [`docs/stat/stat_top_spartan6.md`](docs/stat/stat_top_spartan6.md) and
  [`docs/stat/stat_top_spartan7.md`](docs/stat/stat_top_spartan7.md), section `vhfma002`.
- Post-PAR Fmax is not confirmed yet: the `fmax` values in
  `scripts/modules_config.py` (180/210/230 MHz) are a hand-calibrated typical
  estimate, not a measurement. For a sign-off, run Xilinx ISE/Vivado `report_timing`.
- All other modules of the library remain strictly DSP-free and keep the `*`-free
  convention of the reference implementation.

## Arithmetic Specification

### BF16-output multiplier (`vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3`)

| Feature | Behavior |
|---------|----------|
| **Format** | BF16: `s[15] \| exp[14:7] \| frac[6:0]` (8-bit exponent, bias 127; 7-bit mantissa) |
| **Rounding** | RTZ (truncation) in `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`; RNE (IEEE 754 round-to-nearest-even) in `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` |
| **Subnormal inputs** | **Flush To Zero (FTZ)**: subnormal operands (`exp=0`, `frac≠0`) are flushed to zero before the pipeline; ±0 is already zero |
| **Subnormal results** | Not generated: exp underflow (≤0 after normalization) flushes the result to ±0 |
| **Zero** | Zero operand (`exp=0`) → result ±0 (canonical `s\|8'h00\|7'h00`); Inf × 0 → NaN, NaN × 0 → NaN |
| **Infinity** | Inf operand (`exp=255, frac=0`) and no NaN → result ±Inf (`s\|8'hFF\|7'h00`); Inf × 0 = NaN |
| **NaN** | Any operand with `exp=255, frac≠0` → quiet NaN, payload preserved (priority A > B): `s\|8'hFF\|1'b1\|payload[5:0]` |
| **Exception priority** | NaN > Inf > Zero > normal multiply; overflow saturates to ±Inf, underflow flushes to ±0 |
| **Sign** | `sign_a XOR sign_b` for all results, including NaN |
| **Pipeline** | 3 clock cycles latency, full-drain behavior: after `en=0` the pipeline finishes accepted data for 2 more cycles, then holds the last result (HOLD, no zero-fill) |

### FAST BF16-output multiplier (`vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3`)

Speed-optimized (max-Fmax) variant of the BF16-output multiplier with a single
balanced 3-stage pipeline and no nested latency modules. Same interface and
control model as the RTZ/RNE variants; distinguished by the canonical (sign-less)
NaN and a smaller register footprint.

| Feature | Behavior |
|---------|----------|
| **Format** | BF16: `s[15] \| exp[14:7] \| frac[6:0]` (8-bit exponent, bias 127; 7-bit mantissa) |
| **Rounding** | RTZ (truncation): the 7 high bits of the normalized product are kept, low bits dropped |
| **Subnormal inputs** | **Flush To Zero (FTZ)**: any operand with `exp=0` (zero or subnormal) is treated as zero — no separate subnormal arithmetic |
| **Subnormal results** | Not generated: exp underflow flushes the result to ±0 |
| **Zero** | Zero operand (`exp=0`, FTZ) → result ±0 (sign = XOR); Inf × 0 → NaN |
| **Infinity** | Inf operand and no NaN → ±Inf (sign = XOR); Inf × 0 = NaN |
| **NaN** | Canonical quiet NaN `0x7FC0` — **no sign, no payload** (differs from `rtz_lat3`/`rne_lat3`, which XOR the sign into NaN) |
| **Exception priority** | NaN > Inf > Zero > Underflow > Overflow > normal multiply |
| **Sign** | `sign_a XOR sign_b` for Inf/zero/normal results (not applied to NaN) |
| **Pipeline** | 3 clock cycles latency, single 3-stage pipeline (S1: decode+FTZ+8×8 multiply+exp_sum; S2: normalize+exponent adjust+bounds; S3: select+output reg); after `en=0` drains 3 cycles, then HOLD |
| **Implementation** | Autonomous (only 4× `vhfastmulb16_mul4x4_comb`); no `*` operator; pure LUT/FF, 0 DSP |

### F32-output module (`vhfastmulb16_mul_bf16_bf16_fp32_lat4`)

| Feature | Behavior |
|---------|----------|
| **Format** | Input BF16; output F32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Rounding** | None: normal products are exact; F32 subnormal results are truncated (RTZ) |
| **Subnormal inputs** | **Not flushed**: BF16 subnormals are normalized into the F32 result |
| **Subnormal results** | F32 subnormal, truncated (RTZ); underflow below `2^-149` → signed zero |
| **NaN** | Canonical quiet NaN `0x7FC00000` |
| **Overflow** | Result outside F32 range → `±Inf` with sign = XOR of signs |
| **Pipeline** | 4 clock cycles latency, fully pipelined; after `en=0` drains for 3 cycles, then holds |

### FMA module (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4`)

| Feature | Behavior |
|---------|----------|
| **Format** | Inputs: BF16 `VALA`, BF16 `VALB`, FP32 `SUMM`; output FP32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Operation** | `RESULT = SUMM + (VALA × VALB)` with one final rounding (fused, no intermediate F32 product rounding) |
| **Rounding** | RNE (round-to-nearest-even, IEEE 754 default), including F32 subnormal results |
| **Subnormal inputs** | **Not flushed**: BF16 subnormals and FP32 subnormal `SUMM` are normalized and used exactly (no FTZ) |
| **Subnormal results** | F32 subnormal with RNE; the exact half-ulp `2^-150` tie rounds to even (zero), values below it round to signed zero |
| **NaN** | Any NaN input → canonical quiet NaN `0x7FC00000`; `Inf × 0` → qNaN; `Inf` + opposite-sign `Inf` → qNaN |
| **Infinity** | An infinite operand propagates to a result with the infinite operand's sign; a finite exact product is never converted to Inf before the final addition |
| **Zero sign** | `-0 + -0 = -0`; `-0 + +0 = +0`; exact cancellation `x + (-x) = +0`; underflow to zero preserves the exact-result sign |
| **Pipeline** | 4 clock cycles latency, fully pipelined, HOLD on `en=0` |

### FAST FMA module (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`)

Speed-optimized (max-Fmax) variant of the BF16 × BF16 + FP32 FMA with RTZ
rounding and FTZ on BF16/FP32 subnormals. The BF16 × BF16 product is exact;
the single final rounding is RTZ (truncation). No F32 subnormal results are
produced; every zero result is `+0`. The alignment path has no sticky and the
carry fix-up drops the shifted-out bit, so rare 1-ulp deviations from exact
RTZ are possible — a deliberate FAST trade-off (bit-exact IEEE RNE is not a
requirement for this module).

| Feature | Behavior |
|---------|----------|
| **Format** | Inputs: BF16 `VALA`, BF16 `VALB`, FP32 `SUMM`; output FP32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Operation** | `RESULT = SUMM + (VALA × VALB)` (fused, exact product) |
| **Rounding** | RTZ (truncation): the 24-bit significand `man_norm[26:3]` is kept, low 3 bits dropped; no G/R/S, no tie-to-even |
| **Subnormal inputs** | **Flush To Zero (FTZ)**: BF16 `exp=0` and FP32 `exp=0` are treated as zero |
| **Subnormal results** | Not generated: `exp_f32 <= 0` → `+0` |
| **Zero sign** | Every zero result → `+0` (both-zero, exact cancellation, underflow) |
| **NaN** | Canonical quiet NaN `0x7FC00000` — no sign, no payload |
| **Infinity** | `Inf × finite` and `±Inf` with the same sign → `±Inf`; `Inf × 0` and `Inf + (-Inf)` → qNaN |
| **Overflow** | `exp_f32 >= 255` → `±Inf` |
| **Exception priority** | NaN > Inf > Zero > Underflow > Overflow > normal |
| **Pipeline** | 8 clock cycles, fully pipelined; after `en=0` drains 8 cycles, then HOLD |
| **Implementation** | Autonomous (only 4× `vhfastmulb16_mul4x4_comb`); no `*` operator; pure LUT/FF, 0 DSP |

### FP32-adder modules (`vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4`, `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4`)

| Feature | `add_fp32_fp32_fp32_rtz_lat4` | `add_fp32_fp32_fp32_rne_lat4` |
|---------|-------------------|-------------------|
| **Format** | FP32 + FP32 -> FP32: `s[31] \| exp[30:23] \| frac[22:0]` | FP32 + FP32 -> FP32: `s[31] \| exp[30:23] \| frac[22:0]` |
| **Rounding** | RTZ (round toward zero — truncation) | RNE (round-to-nearest-even, IEEE 754 default) |
| **Subnormal inputs** | **Not flushed**: treated as finite values (no FTZ) | **Not flushed**: treated as finite values (no FTZ) |
| **Subnormal results** | Truncated (RTZ); exp ≤ 0 → F32 subnormal (right shift, low bits dropped); zero only below `2^-149` | Rounded (RNE); exp ≤ 0 → F32 subnormal (exact for FP32 operands) |
| **NaN** | Quiet NaN; sign and payload preserved from the NaN operand (priority A > B, quiet bit forced) | Quiet NaN; sign and payload preserved from the NaN operand (priority A > B, quiet bit forced) |
| **Zero sign** | IEEE-754 default: (+0)+(-0) = +0, (-0)+(-0) = -0; exact cancellation → +0 | IEEE-754 default: (+0)+(-0) = +0, (-0)+(-0) = -0; exact cancellation → +0 |
| **Infinity** | ±Inf propagated; (+Inf)+(-Inf) → qNaN (sign/payload from operand B) | ±Inf propagated; (+Inf)+(-Inf) → qNaN (sign/payload from operand B) |
| **Overflow** | Result > F32 max → ±Inf with sign of result (project convention: `exp ≥ 255` → Inf) | Result > F32 max → ±Inf with sign of result (project convention: `exp ≥ 255` → Inf) |
| **Pipeline** | 4 clock cycles latency, fully pipelined; HOLD on `en=0` | 4 clock cycles latency, fully pipelined; HOLD on `en=0` |

## Development Status

The per-module availability notes and the verification status of the DUTs (directed
testbenches, random regressions, full `run_all.sh` regression) are listed in
[docs/dev_status.md](docs/dev_status.md).

## Source Files

The `src/` directory contains **26** Verilog source files:

### Multiplication Modules

| File | Module | Description | Latency |
|------|--------|-------------|---------|
| `aux/vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | 4x4-bit multiplication without the `*` operator (CSA tree) | 1 clk |
| `aux/vhfastmulb16_mul4x4_lat2.v` | `vhfastmulb16_mul4x4_lat2` | 4x4-bit multiplication (CSA tree), 2-stage pipeline | 2 clk |
| `aux/vhfastmulb16_mul4x4_comb.v` | `vhfastmulb16_mul4x4_comb` | 4x4-bit combinational multiplication (CSA tree, no output register) | 0 clk |
| `aux/vhfastmulb16_mul_u8_u8_u16_lat2.v` | `vhfastmulb16_mul_u8_u8_u16_lat2` | 8x8-bit multiplication via 4 instances of `mul4x4` | 2 clk |
| `aux/vhfastmulb16_mul_u8_u8_u16_lat3.v` | `vhfastmulb16_mul_u8_u8_u16_lat3` | 8x8-bit multiplication via 4 instances of `mul4x4_lat2` | 3 clk |
| `mul/vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | Top-level BF16 multiplier with **RTZ** rounding (truncation) | 3 clk |
| `mul/vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | Top-level BF16 multiplier with **RNE** rounding (IEEE 754) | 3 clk |
| `mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.v` | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | Top-level BF16 multiplier, **FAST** (max-Fmax): RTZ, FTZ, single 3-stage pipeline, canonical qNaN | 3 clk |
| `mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | Top-level BF16 x BF16 -> **F32** exact multiplier, no rounding | 4 clk |

### Addition Modules

| File | Module | Description | Latency |
|------|--------|-------------|---------|
| `aux/vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Addition of two 8-bit numbers and subtraction of 127 (bias) | 2 clk |
| `add/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RTZ** rounding | 4 clk |
| `add/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | Top-level FP32 + FP32 -> **F32** adder with **RNE** rounding | 4 clk |
| `add/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | Top-level FP16 + FP16 -> **F16** adder with **RTZ** rounding | 4 clk |
| `add/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | Top-level FP16 + FP16 -> **F16** adder with **RNE** rounding | 4 clk |
| `add/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | Top-level BF16 + BF16 -> **BF16** adder with **RTZ** rounding | 4 clk |
| `add/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | Top-level BF16 + BF16 -> **BF16** adder with **RNE** rounding | 4 clk |

### Combined Modules

| File | Module | Description | Latency |
|------|--------|-------------|---------|
| `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding | 4 clk |
| `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding (8-stage, max Fmax) | 8 clk |
| `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RTZ** rounding (8-stage, max Fmax; FTZ) | 8 clk |
| `fma/vhfma001.v` | `vhfma001` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding (8-stage, max Fmax; speed-optimized clone of lat8, pure LUT/FF) | 8 clk |
| `fma/vhfma002.v` | `vhfma002` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding (8-stage, max Fmax; single DSP48-mapped 8x8 mantissa multiply — allowed exception) | 8 clk |

### Auxiliary Modules

| File | Module | Description | Latency |
|------|--------|-------------|---------|
| `aux/vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Sign cascade (XOR) with 3 outputs | 1/2/3 clk |
| `aux/vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Exponent/mantissa flags (zero/subnormal/normal/inf/nan) | 1 clk |
| `aux/vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Exponent/mantissa flags (2-stage pipeline) | 2 clk |
| `aux/vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Exception handling (NaN/Inf/Zero) for latency-2 pipeline | 2 clk |
| `aux/vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Exception handling (NaN/Inf/Zero) for latency-3 pipeline | 3 clk |

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

vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3
└── vhfastmulb16_mul4x4_comb (x4)

vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4
└── vhfastmulb16_mul4x4_comb (x4)

vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8
└── vhfastmulb16_mul4x4_comb (x4)

vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8
└── vhfastmulb16_mul4x4_comb (x4)

vhfma001
└── vhfastmulb16_mul4x4_comb (x4)

vhfma002
  (autonomous, no dependencies on other vhfastmulb16_* modules;
   one DSP48 block for the 8x8 BF16 mantissa multiply — allowed exception)

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

### Versions with Different Latency

#### Latency 1

| Component | Modules |
|-----------|---------|
| Mul4x4 | `vhfastmulb16_mul4x4` |
| Flags | `vhfastmulb16_flags_lat1` |

#### Latency 2

| Component | Modules |
|-----------|---------|
| Mul4x4 | `vhfastmulb16_mul4x4_lat2` |
| Mul8x8 | `vhfastmulb16_mul_u8_u8_u16_lat2` |
| Flags | `vhfastmulb16_flags_lat2` |
| Exceptions | `vhfastmulb16_except_lat2` |

#### Latency 3

| Component | Modules |
|-----------|---------|
| Mul8x8 | `vhfastmulb16_mul_u8_u8_u16_lat3` |
| Exceptions | `vhfastmulb16_except_lat3` |
| Top-level (BF16 × BF16) | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` |

#### Latency 4

| Component | Modules |
|-----------|---------|
| Top-level (BF16 × BF16) | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` |
| Top-level (FP32 add) | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4`, `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` |
| Top-level (FP16 add) | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4`, `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` |
| Top-level (BF16 add) | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4`, `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` |
| Top-level (BF16 × BF16 + FP32 FMA) | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` |

#### Latency 8

| Component | Modules |
|-----------|---------|
| Top-level (BF16 × BF16 + FP32 FMA) | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`, `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`, `vhfma001`, `vhfma002` |

## Testbenches

The testbenches are located in the [tests/](tests/) directory, and the run scripts are located in the [scripts/](scripts/) directory.

### Multiplication Modules

| Testbench | Module under test |
|-----------|-------------------|
| `tests/aux/vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` |
| `tests/aux/vhfastmulb16_mul4x4_chk_tb.v` | `vhfastmulb16_mul4x4` (check/debug) |
| `tests/aux/vhfastmulb16_mul4x4_lat2_tb.v` | `vhfastmulb16_mul4x4_lat2` |
| `tests/aux/vhfastmulb16_mul4x4_lat2_chk_tb.v` | `vhfastmulb16_mul4x4_lat2` (check/debug) |
| `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat2_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat2` |
| `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat2` (check/debug) |
| `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat3_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat3` |
| `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat3_chk_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat3` (check/debug) |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` (visual, LAT=3) |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_rand_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` (random regression, LAT=3) |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4_tb.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` (directed, LAT=4) |
| `tests/mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4_rand_tb.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` (random regression, LAT=4) |

### Addition Modules

| Testbench | Module under test |
|-----------|-------------------|
| `tests/aux/vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8_lat2` |
| `tests/aux/vhfastmulb16_add8x8_reva_tb.v` | `vhfastmulb16_add8x8_lat2` (exhaustive, 256×256) |
| `tests/add/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` (random/directed regression, LAT=4) |
| `tests/add/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_rand_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` (random/directed regression, LAT=4) |
| `tests/add/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` (random/directed regression, LAT=4) |
| `tests/add/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4_rand_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` (random/directed regression, LAT=4) |
| `tests/add/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` (directed + en=0 gaps, LAT=4) |
| `tests/add/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` (random/directed regression, LAT=4) |
| `tests/add/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_rand_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` (random/directed regression, LAT=4) |

### Combined Modules

| Testbench | Module under test |
|-----------|-------------------|
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` (directed + hold/reset, LAT=4) |
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` (random regression, LAT=4) |
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` (directed + hold/reset, LAT=8) |
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` (random regression, LAT=8) |
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` (directed + hold/reset, LAT=8) |
| `tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_rand_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` (random regression, LAT=8) |
| `tests/fma/vhfma001_tb.v` | `vhfma001` (directed + hold/reset, LAT=8) |
| `tests/fma/vhfma001_rand_tb.v` | `vhfma001` (random regression, LAT=8) |
| `tests/fma/vhfma002_tb.v` | `vhfma002` (directed + hold/reset, LAT=8) |
| `tests/fma/vhfma002_rand_tb.v` | `vhfma002` (random regression, LAT=8) |

### Auxiliary Modules

| Testbench | Module under test |
|-----------|-------------------|
| `tests/aux/vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` |
| `tests/aux/vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` |
| `tests/aux/vhfastmulb16_flags_lat2_tb.v` | `vhfastmulb16_flags_lat2` |
| `tests/aux/vhfastmulb16_flags_lat2_chk_tb.v` | `vhfastmulb16_flags_lat2` (check/debug) |
| `tests/aux/vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` |
| `tests/aux/vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` |

Most testbenches have a dedicated run script. In particular, several
`*_chk_tb.v` benches are also runnable directly:

| Script | Testbench |
|--------|-----------|
| `scripts/aux/run_test_add8x8_lat2.sh` | `tests/aux/vhfastmulb16_add8x8_tb.v` |
| `scripts/aux/run_test_flags_lat2.sh` | `tests/aux/vhfastmulb16_flags_lat2_chk_tb.v` |
| `scripts/aux/run_test_mul4x4_lat2.sh` | `tests/aux/vhfastmulb16_mul4x4_lat2_chk_tb.v` |
| `scripts/aux/run_test_mul_u8_u8_u16_lat3.sh` | `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat3_chk_tb.v` |
| `scripts/aux/run_test_mul_u8_u8_u16_lat2_chk.sh` | `tests/aux/vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb.v` |

See `scripts/run_test_*.sh` and the component subdirectories `scripts/mul/`, `scripts/add/`, `scripts/fma/` and `scripts/aux/` for the complete mapping.

The run commands (`run_all.sh sim` / `wave` / `clean`, individual test scripts, the list
of benches without a dedicated script and the last full regression result) are listed in
[docs/run_simulation.md](docs/run_simulation.md).

## Test Values

The test-vector layout (per-operation subdirectories, file formats, validation and
generation scripts) is described in [docs/test_values.md](docs/test_values.md).


## FPGA Resource Estimates

The device resource reports (Yosys/YoWASP estimates, Fmax calibration notes and the
preliminary real-board measurement) are maintained in
[docs/resource_estimates.md](docs/resource_estimates.md).

## Real-board benchmarks (CMB32F407HDMIR3)

Post-PAR timing measurements were performed on the **CMB32F407HDMIR3** board
(hybrid STM32F407 MCU + Xilinx Spartan-6 XC6SLX9-2TQG144 FPGA, SDRAM
128-MBit / 256-MBit (x16), 7.5 ns / 6 ns ≈ 133 / 166 MHz), using Xilinx ISE
14.7. The measured top includes the DUT plus a minimal parallel data-loading
interface (`u_regs` + `u_iface`, IOB-packed), not the bare DUT — figures are
not directly comparable to the Yosys estimates.

Detailed logs: [`docs/benchmarks/log_fma_fst_lat8/`](docs/benchmarks/log_fma_fst_lat8/)
and [`docs/benchmarks/log_fma_rne_lat8/`](docs/benchmarks/log_fma_rne_lat8/).

| Module | Constraint | Min period | Equivalent Fmax | Timing errors |
|--------|------------|------------|-----------------|---------------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` (FAST, RTZ, FTZ, lat=8) | 6 ns | 5.243 ns | ≈190.7 MHz | 0 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` (RNE, lat=8) | 8 ns | 7.414 ns | ≈134.9 MHz | 0 |

Trial run (2026-11-15, not a sign-off; more devices/trials pending).

## Revision History

The full revision history (Rev 0.0.1 … 0.0.12) is maintained in [docs/rev_history.md](docs/rev_history.md).

## Author

Author: Viktor Glebov / V01G04A81 2026

## License

MIT — see [LICENSE](LICENSE).

<https://github.com/vigatron/vhlibvbf16>
