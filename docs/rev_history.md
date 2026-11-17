# Revision History

← [README](../README.md)

| Rev | Date | Changes |
|-----|------|---------|
| 0.0.12 | 2026-11-16 | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` (FAST / max-Fmax BF16 × BF16 → BF16 multiplier) added: single balanced 3-stage pipeline (no nested latency modules), RTZ, FTZ inputs, canonical qNaN `0x7FC0` (no sign), sign XOR on Inf/zero/normal; autonomous (only 4× `vhfastmulb16_mul4x4_comb`, 0 DSP). Verification: directed testbench (16 vectors) + random regression (2048 vectors, Python FTZ/RTZ golden model `scripts/gen_fst_bf16_vectors.py`) — **0 errors**; test vectors `testvalues/mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_bf16_fst_rtz.{json,md}`. Stats regenerated (YoWASP, LUT estimate): ~230 LUT, ~61 FF, 230 MHz on XC7S15-1 (vs ~252 / 106 / 205 MHz for `rtz_lat3`); full regression **PASSED=38, FAILED=0** |
| 0.0.11 | 2026-11-16 | `vhfma001` (max-Fmax clone of the lat8 FMA, pure LUT/FF, 8 clk) and `vhfma002` (8-stage FMA with the 8x8 BF16 mantissa multiply mapped to one DSP48 — the sole allowed DSP exception) released; stats regenerated 2026-11-16 (`vhfma001`: LUT ~1148 est., FF 570, DSP48 = 0; `vhfma002`: LUT ~1016 est., FF 510, DSP48 = 1); README synchronized (module lists, testbenches); full regression **PASSED=36, FAILED=0** |
| 0.0.10 | 2026-11-15 | First post-PAR trial on a real board (XC6SLX9-2TQG144, ISE 14.7, CMB32F407HDMIR3): lat8 FMA at 125 MHz, 0 timing errors; logs in [`test_xc6slx9_fma8.cmd_log`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8.cmd_log), [`test_xc6slx9_fma8.twr`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8.twr) and [`test_xc6slx9_fma8_summary.html`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8_summary.html); `vhfma001` added; stat reports updated |
| 0.0.9 | 2026-11-14 | Source/testbench folder reorganization (`mul/`, `add/`, `fma/`, `aux/`) |
| 0.0.8 | 2026-11-14 | `tmpfix` (lat8 FMA hotfix) |
| 0.0.7opt | 2026-11-14 | lat8 FMA rebalanced (S2 prefix-CLZ, S4 nonzero-gate, S7 shift-of-shift removal + exponent retiming, S8 pure pack stage) |
| 0.0.7 | 2026-11-14 | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` added; stats updated |
| 0.0.6 | 2026-11-14 | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` draft; README fixes |
| 0.0.5 | 2026-11-12 | Refactoring |
| 0.0.4 | 2026-11-11 | FP16 adder modules added; README updated |
| 0.0.3 / 0.0.2 | 2026-11-11 / 2026-11-10 | FP32 adder test vectors; FP32 adder draft |
| 0.0.1 | 2026-11-06 | First public revision (stats fix) |