# FPGA Resource Estimates

← [README](../README.md)

The implementation targets Xilinx Spartan-6 (XC6SLX9-2), Spartan-7 (XC7S15-1) and Artix-7 (XC7A15T-1). Device reports are **generated automatically** from Yosys (YoWASP) synthesis results, not hand-written:

- `scripts/collect_stats.py` — synthesizes every design with Yosys: `hierarchy -top` → `flatten` → `synth_xilinx -family <xc6s|xc7> -run begin:map_ffs` (YoWASP WASM cannot run yosys-abc, so synthesis stops before ABC9), then parses the RTLIL dump on stdout. LUT6 is estimated as `gates / 2.5` (±20–25%); FF, CARRY4 and IO buffer counts are exact.
- `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py` — generate the top-level and bottom-up submodule reports (pass `--write` to overwrite the `stat/*.md` files; without it they run in dry-run mode).
- Stat reports were regenerated on **2026-11-17** and now include `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` (LUT ~662 est., FF 528, CARRY4 50, **DSP48 = 0**; Fmax typ 200/230/250 MHz on XC6SLX9-2/XC7S15-1/XC7A15T-1), `vhfma001` (LUT ~1148 est., FF 570, **DSP48 = 0**) and `vhfma002` (LUT ~1016 est., FF 510, **DSP48 = 1** — explicitly allowed exception); see the corresponding sections of the per-device reports.

Fmax (typ) is a hand-calibrated typical value stored in `scripts/modules_config.py` (`fmax` per module and family, `source: manual`), not a post-PAR measurement (a first trial post-PAR measurement exists — see below); expect ±20–25%. The `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` Fmax values (200/230/250 MHz), the `vhfma002` Fmax values (180/210/230 MHz) and `vhfma001` (180/210/230 MHz) are manual calibrations and are **not confirmed** by PAR yet (the `vhfma002` one was made before the DSP-mapped rework). For a sign-off Fmax, run Xilinx ISE/Vivado with `report_timing`.

**Real-board measurements (preliminary, trial).** Both modules have been placed & routed in Xilinx ISE 14.7 on a **CMB32F407HDMIR3** board (hybrid STM32F407 + Spartan-6 XC6SLX9-2TQG144). The measured top includes the DUT (`u_mul`) **plus a minimal parallel data-loading interface** (helper logic: input/output registers `u_regs` and a thin MCU parallel-bus wrapper `u_iface`, packed into IOBs), not the bare DUT — figures are not directly comparable to the Yosys estimates above.

**`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`** (FAST, RTZ, FTZ, lat=8) — [`log_fma_fst_lat8`](benchmarks/log_fma_fst_lat8/):
- [`test_xc6slx9_fma8.cmd_log`](benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8.cmd_log) — ISE run log (XST → NGDBuild → MAP → PAR → TRCE → Bitgen).
- [`test_xc6slx9_fma8.twr`](benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8.twr) — timing report.
- [`test_xc6slx9_fma8_summary.html`](benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8_summary.html) — resource & timing summary.
- Constraint: **6 ns (≈166.7 MHz)**; **0 timing errors**; **min period 5.243 ns (≈190.7 MHz)**; slack 0.757 ns; Data Path Delay 5.227 ns (1 logic level).

**`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`** (RNE, subnormals preserved, lat=8) — [`log_fma_rne_lat8`](benchmarks/log_fma_rne_lat8/):
- [`test_xc6slx9_fma8.cmd_log`](benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8.cmd_log) — ISE run log.
- [`test_xc6slx9_fma8.twr`](benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8.twr) — timing report.
- [`test_xc6slx9_fma8_summary.html`](benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8_summary.html) — resource & timing summary.
- Constraint: **8 ns (125 MHz)**; **0 timing errors** (237,196 analyzed paths / 4,753 endpoints); minimum period **7.414 ns (~134.9 MHz)**; slack 0.586 ns; Data Path Delay 6.784 ns (3 logic levels: 2.664 ns logic + 4.120 ns route); **887 slice registers (7%)**, **1,117 slice LUTs (19%)**, **514 occupied slices (35%)**, **0 DSP48A1 / 0 BRAM**, 37 LOCed IOBs ("Performance with IOB Packing").

Trial run (2026-11-15, not a sign-off; more devices/trials pending).
Folder `log9_fma_lat8` removed (renamed — this is the `..._rne_lat8` build, see `log_fma_rne_lat8`).

No post-PAR trial exists yet for `vhfma001` / `vhfma002`.

Reports (regenerated 2026-11-17; `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`, `vhfma001` and `vhfma002` rows included):

- [`stat/stat_top_all.md`](stat/stat_top_all.md) — comparison of the top-level modules (RTZ, RNE, F32, FMA, add_fp32, add_fp16, add_bf16) and their typical (typ) Fmax across FPGA families;
- [`stat/stat_top_spartan6.md`](stat/stat_top_spartan6.md), [`stat/stat_top_spartan7.md`](stat/stat_top_spartan7.md), [`stat/stat_top_artix7.md`](stat/stat_top_artix7.md) — per-device details;
- [`stat/stat_others_all.md`](stat/stat_others_all.md) — bottom-up submodule comparison and typical (typ) Fmax; [`stat/stat_others_spartan6.md`](stat/stat_others_spartan6.md), [`stat/stat_others_spartan7.md`](stat/stat_others_spartan7.md), [`stat/stat_others_artix7.md`](stat/stat_others_artix7.md) — per-device submodule details.

To regenerate the statistics:

```bash
./scripts/collect_stats.py --all   # top-level modules + submodules
./scripts/generate_stat_docs.py --write
./scripts/generate_stat_others_docs.py --write
```