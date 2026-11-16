# vhlibvbf16

![Verilog-2005](https://img.shields.io/badge/DUT_Verilog--2005_(IEEE_1364--2005)-1364FF)
![SystemVerilog-2012](https://img.shields.io/badge/TB_SystemVerilog--2012_(IEEE_1800--2012)-CC3300)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Rev](https://img.shields.io/badge/Rev-0.0.12-informational)
![Date](https://img.shields.io/badge/date-2026--11--16-informational)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Tests](https://img.shields.io/badge/tests-run__all.sh%20PASSED%2038%2F38-brightgreen)


Author: V01G04A81  
Rev: 0.0.12  


## Description

Compact pipelined BF16/FP32 arithmetic library (Verilog)<br>
BF16 multiplier (RTZ / RNE / **FAST max-Fmax**), BF16×BF16→F32 multiplier, BF16×BF16+FP32 fused multiply-add (including the `vhfma001` max-Fmax clone and the `vhfma002` DSP-mapped variant), BF16 adders, FP32 adders and FP16 adders; RTZ/RNE; the reference implementation does not require DSP blocks (a single allowed exception exists — see [DSP Block Exception](#dsp-block-exception-vhfma002)).

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
| `vhfma001` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax, pure LUT/FF; speed-optimized clone of lat8) | F32 | 8 clk | RNE (IEEE-754) |
| `vhfma002` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax; 8x8 BF16 mantissa multiply mapped to one DSP48 — allowed exception) | F32 | 8 clk | RNE (IEEE-754) |
| `vhfma001` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax, pure LUT/FF; speed-optimized clone of lat8) | F32 | 8 clk | RNE (IEEE-754) |
| `vhfma002` | BF16 × BF16 + FP32 fused multiply-add (8-stage, max Fmax; 8x8 BF16 mantissa multiply mapped to one DSP48 — allowed exception) | F32 | 8 clk | RNE (IEEE-754) |

### Auxiliary Modules

Helper modules used internally by the top-level DUTs.


The corresponding files are located in the `src` folder (the multiplication top DUTs are in `src/mul/`, the addition top DUTs are in `src/add/`, the FMA modules are in `src/fma/`, the auxiliary submodules are in `src/aux/`).
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

- The BF16-output top-level modules `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` and `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` are available (latency 3).
- The FAST BF16-output top-level module `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` is available (latency 3): speed-optimized variant with a single 3-stage pipeline (no nested latency modules), RTZ rounding, FTZ inputs, canonical qNaN `0x7FC0` (no sign), sign XOR on Inf/zero/normal; autonomous (only 4× `vhfastmulb16_mul4x4_comb`, 0 DSP). Synthesis (YoWASP, LUT estimate): ~230 LUT, ~61 FF, ~230 MHz on XC7S15-1 (vs ~252 LUT / ~106 FF / 205 MHz for `rtz_lat3`).
- The F32-output top-level module `vhfastmulb16_mul_bf16_bf16_fp32_lat4` is available (latency 4): exact BF16 x BF16 product represented as IEEE-754 binary32, no rounding, BF16 subnormals are not flushed, F32 subnormal results are truncated (RTZ).
- The FMA top-level module `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` is available (latency 4): fused `SUMM + VALA × VALB` with a single RNE rounding, exact BF16 product, BF16 and FP32 subnormals are not flushed, and an exact intermediate product is not rounded to Inf before the final addition.
- The FMA top-level module `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` is available (latency 8): same fused FMA functionality with an 8-stage balanced pipeline optimized for maximum Fmax. Key optimizations: rebalanced 8 stages (S1: decode + 4×mul4x4 + exp_p0/exp_s0 + clz24; S2: 2-level CSA + SUMM normalization; S3: CPA → man_prod + LOD k; S4: p24, exp_p + k, direct exp_p - exp_s; S5: sticky + alignment; S6: add/sub + carry fix-up + LZD; S7: normalization + parallel CARRY4 subtractors for exp_pre/grs_shift; S8: RNE + pack), direct shift_diff without mux on shift-amount path, parallel CARRY4 subtractors replacing prefix network, per-stage clock enable (en_d1..en_d7) with true CE on FDRE (no bubble insertion on en=0).
- **Verification status (FMA lat4):** the directed testbench (44 vectors) and random regression (2048 vectors per seed, seeds 1–5 and 12345) pass with **0 errors**; an additional exact-Fraction regression of 6 × 4096 vectors (uniform random, FP32-subnormal `SUMM`, tiny BF16 products, specials and exact-cancellation cases) also reports **0 errors**. The reference model `scripts/gen_fma_vectors.py` uses exact `Fraction` arithmetic and is self-checked against all 44 directed JSON vectors.
- The FMA top-level module `vhfma001` is available (latency 8): speed-optimized clone of the lat8 FMA (S2 prefix-CLZ, S4 nonzero-gate for the mantissa compare, S7 shift-of-shift removal — subnormal GRS computed directly from S6 registers, S7/S8 exponent retiming), identical latency, interface and control model to lat8; pure LUT/FF implementation.
- The FMA top-level module `vhfma002` is available (latency 8): experimental variant of `vhfma001` with the 8x8 BF16 mantissa multiply mapped to a single DSP48 block (`*` with `use_dsp="yes"`) — the only module of the library allowed to use DSP blocks. Reworked on 2026-11-16: single DSP-mapped multiply replacing four LUT 4x4 multipliers, product CLZ16 one-hot decoder replacing the `casez` priority leading-one detect, dead logic removed; see [DSP Block Exception](#dsp-block-exception-vhfma002).
- **Verification status (vhfma001):** directed testbench (45 vectors, `tests/fma/vhfma001_tb.v`) — **0 errors**; random regression (2048 vectors, `tests/fma/vhfma001_rand_tb.v`, seed 12345) — **0 errors**.
- **Verification status (vhfma002):** directed testbench (45 vectors, `tests/fma/vhfma002_tb.v`, hold/reset checks included) — **0 errors**; random regression (2048 vectors, `tests/fma/vhfma002_rand_tb.v`, seed 12345) — **0 errors**; additional seeds 777 and 20260601 — **0 errors** (local, not committed; rerun with `python3 scripts/gen_fma_vectors.py --count 2048 --seed <seed> --out build/vhfma002_rand.hex`).
- **Verification status (FMA lat8):** directed testbench (45 vectors) — **0 errors**; random regression (2048 vectors) — **0 errors**; extended 100k continuous stream — **0 errors**; extended 20k random `en` (~50% gaps) — **0 errors** (specifically validates mid-stream `en=0` handling without spurious bubbles).
- **Full regression:** `./scripts/run_all.sh sim` runs all **38** test scripts (including `scripts/mul/`, `scripts/add/`, `scripts/fma/` and `scripts/aux/`) with **PASSED=38, FAILED=0** (run on 2026-11-16, Icarus Verilog 12.0).
- The FP32-adder top-level modules `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` and `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` are available (latency 4): FP32 + FP32 -> FP32 with RTZ and RNE rounding respectively.
- The FP16-adder top-level modules `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` and `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` are available (latency 4): FP16 + FP16 -> FP16 with RTZ and RNE rounding respectively; subnormal operands are not flushed to zero.
- The BF16-adder top-level modules `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` and `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` are available (latency 4): BF16 + BF16 -> BF16 with RTZ and RNE rounding respectively; subnormal operands are not flushed to zero, NaN results are canonical `0x7FC0`, and RTZ overflow saturates to max finite `0x7F7F`.
- **Verification status (FP32 adders):** the directed smoke tests pass and both random regressions (`tests/add/vhfastmulb16_add_fp32_fp32_fp32_*_lat4_rand_tb.v`, 4096 vectors against a bit-exact IEEE-754 model) report **0 mismatches**. Additional wide runs: 120 000 vectors (seed 777) and 300 000 vectors (seed 999) per mode — **0 errors**. Rounding/subnormal/overflow corner cases are covered by directed vectors. The RNE datapath no longer uses non-constant loop bounds (Yosys blocker removed). Stage-2 rebalancing reduced the Yosys logic depth from 56 to **20** (RTZ) / **22** (RNE) levels at +2–7 % cell area, latency remains 4.
- **Verification status (FP16 adders):** the directed smoke tests pass and both random regressions (`tests/add/vhfastmulb16_add_fp16_fp16_fp16_*_lat4_rand_tb.v`, 4096 vectors against a bit-exact IEEE-754 model) report **0 mismatches**; rounding/subnormal/overflow corner cases are covered by directed vectors.
- **Verification status (BF16 adders):** the directed tests (`tests/add/vhfastmulb16_add_bf16_bf16_bf16_*_lat4_tb.v`, 32 vectors) and random regressions (`..._rand_tb.v`, 4096 vectors against `scripts/gen_bf16_vectors.py`) pass with **0 mismatches**; extended 20 000-vector runs with seeds 777/999 and exhaustive 256×256 subnormal/min-normal pairs also report 0 errors for both RTZ and RNE.
- The building blocks are available: `vhfastmulb16_mul4x4`, `vhfastmulb16_mul4x4_lat2`, `vhfastmulb16_mul4x4_comb`, `vhfastmulb16_mul_u8_u8_u16_lat2`, `vhfastmulb16_mul_u8_u8_u16_lat3`, `vhfastmulb16_add8x8_lat2`, `vhfastmulb16_sign`, `vhfastmulb16_flags_lat1`, `vhfastmulb16_flags_lat2`, `vhfastmulb16_except_lat2`, `vhfastmulb16_except_lat3`.
- The FAST BF16 multiplier `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` is a speed-optimized variant of the BF16-output multiplier (see above); it is autonomous (only `vhfastmulb16_mul4x4_comb`) and implemented in pure LUT/FF (0 DSP).
- The modules are implemented in pure logic; the multiplication operator `*` appears **only** in `vhfma002` (DSP48-mapped, explicitly allowed exception). **Use of DSP blocks (DSP48A1, DSP48E1, etc.) is prohibited for all other modules** to ensure portability across FPGA families; see [DSP Block Exception](#dsp-block-exception-vhfma002).

## Source Files

The `src/` directory contains **25** Verilog source files:

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
| `fma/vhfma001.v` | `vhfma001` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding (8-stage, max Fmax; speed-optimized clone of lat8, pure LUT/FF) | 8 clk |
| `fma/vhfma002.v` | `vhfma002` | Fused multiply-add BF16 × BF16 + FP32 -> **FP32** with **RNE** rounding (8-stage, max Fmax; single DSP48-mapped 8x8 mantissa multiply — allowed exception) | 8 clk |
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

| Component | Latency 1 | Latency 2 | Latency 3 | Latency 4 | Latency 8 |
|-----------|-----------|-----------|-----------|-----------|-----------|
| Mul4x4 | `vhfastmulb16_mul4x4` | `vhfastmulb16_mul4x4_lat2` | - | - | - |
| Mul8x8 | - | `vhfastmulb16_mul_u8_u8_u16_lat2` | `vhfastmulb16_mul_u8_u8_u16_lat3` | - | - |
| Flags | `vhfastmulb16_flags_lat1` | `vhfastmulb16_flags_lat2` | - | - | - |
| Exceptions | - | `vhfastmulb16_except_lat2` | `vhfastmulb16_except_lat3` | - | - |
| Top-level (BF16 × BF16) | - | - | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3`, `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | - |
| Top-level (FP32 add) | - | - | - | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4`, `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | - |
| Top-level (FP16 add) | - | - | - | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4`, `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | - |
| Top-level (BF16 add) | - | - | - | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4`, `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | - |
| Top-level (BF16 × BF16 + FP32 FMA) | - | - | - | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`, `vhfma001`, `vhfma002` |

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

Run the simulation with:

```bash
# All testbench scripts
./scripts/run_all.sh sim

# Individual tests
./scripts/aux/run_test_mul4x4.sh sim
./scripts/aux/run_test_mul4x4_lat2.sh sim
./scripts/aux/run_test_mul_u8_u8_u16_lat2.sh sim
./scripts/aux/run_test_mul_u8_u8_u16_lat2_chk.sh sim
./scripts/aux/run_test_mul_u8_u8_u16_lat3.sh sim
./scripts/aux/run_test_add8x8_lat2.sh sim
./scripts/aux/run_test_add8x8_reva.sh sim
./scripts/aux/run_test_sign.sh sim
./scripts/aux/run_test_flags_lat1.sh sim
./scripts/aux/run_test_flags_lat2.sh sim
./scripts/aux/run_test_except_lat2.sh sim
./scripts/aux/run_test_except_lat3.sh sim
./scripts/mul/run_test_mul_bf16_bf16_bf16_rtz_lat3.sh sim
./scripts/mul/run_test_mul_bf16_bf16_bf16_rne_lat3.sh sim
./scripts/mul/run_test_mul_bf16_bf16_bf16_fst_lat3.sh sim
./scripts/mul/run_test_mul_bf16_bf16_bf16_fst_lat3_rand.sh sim
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4.sh sim
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4_rand.sh sim
./scripts/add/run_test_add_fp32_fp32_fp32_rtz_lat4.sh sim
./scripts/add/run_test_add_fp32_fp32_fp32_rne_lat4.sh sim
./scripts/add/run_test_add_fp32_fp32_fp32_rtz_lat4_rand.sh sim
./scripts/add/run_test_add_fp32_fp32_fp32_rne_lat4_rand.sh sim
./scripts/add/run_test_add_fp16_fp16_fp16_rtz_lat4.sh sim
./scripts/add/run_test_add_fp16_fp16_fp16_rne_lat4.sh sim
./scripts/add/run_test_add_fp16_fp16_fp16_rtz_lat4_rand.sh sim
./scripts/add/run_test_add_fp16_fp16_fp16_rne_lat4_rand.sh sim
./scripts/add/run_test_add_bf16_bf16_bf16_rtz_lat4.sh sim
./scripts/add/run_test_add_bf16_bf16_bf16_rne_lat4.sh sim
./scripts/add/run_test_add_bf16_bf16_bf16_rtz_lat4_rand.sh sim
./scripts/add/run_test_add_bf16_bf16_bf16_rne_lat4_rand.sh sim
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat4.sh sim
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.sh sim
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat8.sh sim
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand.sh sim
./scripts/fma/run_test_vhfma001.sh sim
./scripts/fma/run_test_vhfma001_rand.sh sim
./scripts/fma/run_test_vhfma002.sh sim
./scripts/fma/run_test_vhfma002_rand.sh sim

# Visualization (gtkwave)
./scripts/aux/run_test_mul4x4.sh wave
./scripts/aux/run_test_mul_u8_u8_u16_lat2.sh wave
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4.sh wave
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4_rand.sh wave
./scripts/add/run_test_add_fp32_fp32_fp32_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_fp32_fp32_fp32_rne_lat4_rand.sh wave
./scripts/add/run_test_add_fp16_fp16_fp16_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_fp16_fp16_fp16_rne_lat4_rand.sh wave
./scripts/add/run_test_add_bf16_bf16_bf16_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_bf16_bf16_bf16_rne_lat4_rand.sh wave
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.sh wave
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat8.sh wave
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand.sh wave
./scripts/fma/run_test_vhfma001.sh wave
./scripts/fma/run_test_vhfma002.sh wave

# Clean up build artifacts
./scripts/run_all.sh clean
```

`run_all.sh` runs every `run_test_*.sh` script, including component
subdirectories such as `scripts/mul/`, `scripts/add/`, `scripts/fma/` and `scripts/aux/`; the benches without a dedicated script
(`vhfastmulb16_flags_lat2_tb.v`, `vhfastmulb16_mul4x4_chk_tb.v`,
`vhfastmulb16_mul4x4_lat2_tb.v`, `vhfastmulb16_mul_u8_u8_u16_lat3_tb.v`) are not included.
Last full run: **2026-11-16, PASSED=38, FAILED=0**.
See [docs/testbenches_list.md](docs/testbenches_list.md) and
[docs/srcfiles_list.md](docs/srcfiles_list.md) for more details.

## Test Values

Test vectors live in the top-level [testvalues/](testvalues/) directory (one
subdirectory per operation):

| Directory | Contents |
|-----------|----------|
| `testvalues/mul/test_values_mul_bf16_bf16_bf16/` | BF16 × BF16 → BF16 vectors (main 16 + RNE/RTZ tables + fst FAST/RTZ vectors) |
| `testvalues/mul/test_values_mul_bf16_bf16_fp32/` | BF16 × BF16 → F32 exact-product vectors (`.md` + `.json`) |
| `testvalues/fma/test_values_muladd_bf16_bf16_fp32_fp32_rne_lat4/` | BF16 × BF16 + FP32 → F32 fused-multiply-add vectors, 44 directed cases (`.md` + `.json`); reused by the lat8, `vhfma001` and `vhfma002` variants |
| `testvalues/fma/test_values_muladd_bf16_bf16_fp32_fp32_rne_lat4/` | BF16 × BF16 + FP32 → F32 fused-multiply-add vectors, 44 directed cases (`.md` + `.json`); reused by the lat8, `vhfma001` and `vhfma002` variants |
| `testvalues/add/test_values_add_bf16_bf16_bf16/` | BF16 + BF16 → BF16 vectors, 32 directed cases (`.json` + RNE/RTZ tables) |
| `testvalues/add/test_values_add_fp16_fp16_fp16/` | FP16 + FP16 → FP16 vectors, 32 directed cases (`.json` + RNE/RTZ tables) |
| `testvalues/add/test_values_add_fp16_fp16_fp32/` | FP32 + FP32 → FP32 vectors, 32 directed cases (`.json` + RNE/RTZ tables) — directory name is historical |

The main machine-readable `.json` files are validated by `scripts/check_test_values.py`
(BF16 x BF16 -> F32), `scripts/checkvectors_add_bf16_bf16_bf16.py` (BF16 add),
`scripts/checkvectors_add_fp16_fp16_fp16.py` (FP16 add, RNE/RTZ) and
`scripts/checkvectors_mul_bf16_bf16_fp32.py` (BF16 x BF16 -> F32); the FP16
tables are generated from the directed testbench vectors by
`scripts/gen_fp16_vectors.py`. The BF16 adders use the exact integer model in
`scripts/gen_bf16_vectors.py` for random/directed regression; the 32 JSON
vectors remain unchanged. The FMA vectors are validated by the exact
`Fraction` model in `scripts/gen_fma_vectors.py` (`--self-check`).


## FPGA Resource Estimates

The implementation targets Xilinx Spartan-6 (XC6SLX9-2), Spartan-7 (XC7S15-1) and Artix-7 (XC7A15T-1). Device reports are **generated automatically** from Yosys (YoWASP) synthesis results, not hand-written:

- `scripts/collect_stats.py` — synthesizes every design with Yosys: `hierarchy -top` → `flatten` → `synth_xilinx -family <xc6s|xc7> -run begin:map_ffs` (YoWASP WASM cannot run yosys-abc, so synthesis stops before ABC9), then parses the RTLIL dump on stdout. LUT6 is estimated as `gates / 2.5` (±20–25%); FF, CARRY4 and IO buffer counts are exact.
- `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py` — generate the top-level and bottom-up submodule reports (pass `--write` to overwrite the `docs/stat/*.md` files; without it they run in dry-run mode).
- Stat reports were regenerated on **2026-11-16** and now include `vhfma001` (LUT ~1148 est., FF 570, **DSP48 = 0**) and `vhfma002` (LUT ~1016 est., FF 510, **DSP48 = 1** — explicitly allowed exception); see the `vhfma001` / `vhfma002` sections of the per-device reports.
- `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py` — generate the top-level and bottom-up submodule reports (pass `--write` to overwrite the `docs/stat/*.md` files; without it they run in dry-run mode).
- Stat reports were regenerated on **2026-11-16** and now include `vhfma001` (LUT ~1148 est., FF 570, **DSP48 = 0**) and `vhfma002` (LUT ~1016 est., FF 510, **DSP48 = 1** — explicitly allowed exception); see the `vhfma001` / `vhfma002` sections of the per-device reports.

Fmax (typ) is a hand-calibrated typical value stored in `scripts/modules_config.py` (`fmax` per module and family, `source: manual`), not a post-PAR measurement (a first trial post-PAR measurement exists — see below); expect ±20–25%. The `vhfma002` Fmax values (180/210/230 MHz) and `vhfma001` (180/210/230 MHz) are manual calibrations and are **not confirmed** by PAR yet (the `vhfma002` one was made before the DSP-mapped rework). For a sign-off Fmax, run Xilinx ISE/Vivado with `report_timing`.
Fmax (typ) is a hand-calibrated typical value stored in `scripts/modules_config.py` (`fmax` per module and family, `source: manual`), not a post-PAR measurement (a first trial post-PAR measurement exists — see below); expect ±20–25%. The `vhfma002` Fmax values (180/210/230 MHz) and `vhfma001` (180/210/230 MHz) are manual calibrations and are **not confirmed** by PAR yet (the `vhfma002` one was made before the DSP-mapped rework). For a sign-off Fmax, run Xilinx ISE/Vivado with `report_timing`.

**Real-board measurement (preliminary, trial).** The `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` module has been placed & routed in Xilinx ISE 14.7 on a **CMB32F407HDMIR3** board (hybrid STM32F407 + Spartan-6 XC6SLX9-2TQG144). The measured top includes the DUT (`u_mul`) **plus a minimal parallel data-loading interface** (helper logic: input/output registers `u_regs` and a thin MCU parallel-bus wrapper `u_iface`, packed into IOBs), not the bare DUT — figures are not directly comparable to the Yosys estimates above. With an 8 ns (125 MHz) clock constraint: **0 timing errors** (237,196 analyzed paths / 4,753 endpoints), minimum period **7.414 ns (~134.9 MHz)**, **887 slice registers (7%)**, **1,117 slice LUTs (19%)**, **514 occupied slices (35%)**, **0 DSP48A1 / 0 BRAM**, 37 LOCed IOBs ("Performance with IOB Packing"). Trial run (2026-11-15, not a sign-off; more devices/trials pending). Logs: [`docs/benchmarks/log9_fma_lat8/`](docs/benchmarks/log9_fma_lat8/) —
[`test_xc6slx9_fma8.cmd_log`](docs/benchmarks/log9_fma_lat8/test_xc6slx9_fma8.cmd_log),
[`test_xc6slx9_fma8.twr`](docs/benchmarks/log9_fma_lat8/test_xc6slx9_fma8.twr),
[`test_xc6slx9_fma8_summary.html`](docs/benchmarks/log9_fma_lat8/test_xc6slx9_fma8_summary.html).
No post-PAR trial exists yet for `vhfma001` / `vhfma002`.

Reports (regenerated 2026-11-16; `vhfma001` and `vhfma002` rows included):

- [`docs/stat/stat_top_all.md`](docs/stat/stat_top_all.md) — comparison of the top-level modules (RTZ, RNE, F32, FMA, add_fp32, add_fp16, add_bf16) and their typical (typ) Fmax across FPGA families;
- [`docs/stat/stat_top_spartan6.md`](docs/stat/stat_top_spartan6.md), [`docs/stat/stat_top_spartan7.md`](docs/stat/stat_top_spartan7.md), [`docs/stat/stat_top_artix7.md`](docs/stat/stat_top_artix7.md) — per-device details;
- [`docs/stat/stat_others_all.md`](docs/stat/stat_others_all.md) — bottom-up submodule comparison and typical (typ) Fmax; [`docs/stat/stat_others_spartan6.md`](docs/stat/stat_others_spartan6.md), [`docs/stat/stat_others_spartan7.md`](docs/stat/stat_others_spartan7.md), [`docs/stat/stat_others_artix7.md`](docs/stat/stat_others_artix7.md) — per-device submodule details.

To regenerate the statistics:

```bash
./scripts/collect_stats.py --all   # top-level modules + submodules
./scripts/generate_stat_docs.py --write
./scripts/generate_stat_others_docs.py --write
./scripts/generate_stat_docs.py --write
./scripts/generate_stat_others_docs.py --write
```

## Revision History

| Rev | Date | Changes |
|-----|------|---------|
| 0.0.12 | 2026-11-16 | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` (FAST / max-Fmax BF16 × BF16 → BF16 multiplier) added: single balanced 3-stage pipeline (no nested latency modules), RTZ, FTZ inputs, canonical qNaN `0x7FC0` (no sign), sign XOR on Inf/zero/normal; autonomous (only 4× `vhfastmulb16_mul4x4_comb`, 0 DSP). Verification: directed testbench (16 vectors) + random regression (2048 vectors, Python FTZ/RTZ golden model `scripts/gen_fst_bf16_vectors.py`) — **0 errors**; test vectors `testvalues/mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_bf16_fst_rtz.{json,md}`. Stats regenerated (YoWASP, LUT estimate): ~230 LUT, ~61 FF, 230 MHz on XC7S15-1 (vs ~252 / 106 / 205 MHz for `rtz_lat3`); full regression **PASSED=38, FAILED=0** |
| 0.0.11 | 2026-11-16 | `vhfma001` (max-Fmax clone of the lat8 FMA, pure LUT/FF, 8 clk) and `vhfma002` (8-stage FMA with the 8x8 BF16 mantissa multiply mapped to one DSP48 — the sole allowed DSP exception) released; stats regenerated 2026-11-16 (`vhfma001`: LUT ~1148 est., FF 570, DSP48 = 0; `vhfma002`: LUT ~1016 est., FF 510, DSP48 = 1); README synchronized (module lists, testbenches); full regression **PASSED=36, FAILED=0** |
| 0.0.10 | 2026-11-15 | First post-PAR trial on a real board (XC6SLX9-2TQG144, ISE 14.7, CMB32F407HDMIR3): lat8 FMA at 125 MHz, 0 timing errors; logs in [`docs/benchmarks/log9_fma_lat8/`](docs/benchmarks/log9_fma_lat8/); `vhfma001` added; stat reports updated |
| 0.0.9 | 2026-11-14 | Source/testbench folder reorganization (`mul/`, `add/`, `fma/`, `aux/`) |
| 0.0.8 | 2026-11-14 | `tmpfix` (lat8 FMA hotfix) |
| 0.0.7opt | 2026-11-14 | lat8 FMA rebalanced (S2 prefix-CLZ, S4 nonzero-gate, S7 shift-of-shift removal + exponent retiming, S8 pure pack stage) |
| 0.0.7 | 2026-11-14 | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` added; stats updated |
| 0.0.6 | 2026-11-14 | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` draft; README fixes |
| 0.0.5 | 2026-11-12 | Refactoring |
| 0.0.4 | 2026-11-11 | FP16 adder modules added; README updated |
| 0.0.3 / 0.0.2 | 2026-11-11 / 2026-11-10 | FP32 adder test vectors; FP32 adder draft |
| 0.0.1 | 2026-11-06 | First public revision (stats fix) |

## Author

Author: Viktor Glebov / V01G04A81 2026

## License

MIT — see [LICENSE](LICENSE).
MIT — see [LICENSE](LICENSE).

<https://github.com/vigatron/vhlibvbf16>
