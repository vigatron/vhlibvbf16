# FPGA Resource Estimates

← [README](../README.md)

The implementation targets Xilinx Spartan-6 (XC6SLX9-2), Spartan-7 (XC7S15-1) and Artix-7 (XC7A15T-1). Device reports are **generated automatically** from Yosys (YoWASP) synthesis results, not hand-written:

- `scripts/collect_stats.py` — synthesizes every design with Yosys: `hierarchy -top` → `flatten` → `synth_xilinx -family <xc6s|xc7> -run begin:map_ffs` (YoWASP WASM cannot run yosys-abc, so synthesis stops before ABC9), then parses the RTLIL dump on stdout. LUT6 is estimated as `gates / 2.5` (±20–25%); FF, CARRY4 and IO buffer counts are exact.
- `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py` — generate the top-level and bottom-up submodule reports (pass `--write` to overwrite the `stat/*.md` files; without it they run in dry-run mode).
- Stat reports were regenerated on **2026-11-16** and now include `vhfma001` (LUT ~1148 est., FF 570, **DSP48 = 0**) and `vhfma002` (LUT ~1016 est., FF 510, **DSP48 = 1** — explicitly allowed exception); see the `vhfma001` / `vhfma002` sections of the per-device reports.

Fmax (typ) is a hand-calibrated typical value stored in `scripts/modules_config.py` (`fmax` per module and family, `source: manual`), not a post-PAR measurement (a first trial post-PAR measurement exists — see below); expect ±20–25%. The `vhfma002` Fmax values (180/210/230 MHz) and `vhfma001` (180/210/230 MHz) are manual calibrations and are **not confirmed** by PAR yet (the `vhfma002` one was made before the DSP-mapped rework). For a sign-off Fmax, run Xilinx ISE/Vivado with `report_timing`.

**Real-board measurement (preliminary, trial).** The `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` module has been placed & routed in Xilinx ISE 14.7 on a **CMB32F407HDMIR3** board (hybrid STM32F407 + Spartan-6 XC6SLX9-2TQG144). The measured top includes the DUT (`u_mul`) **plus a minimal parallel data-loading interface** (helper logic: input/output registers `u_regs` and a thin MCU parallel-bus wrapper `u_iface`, packed into IOBs), not the bare DUT — figures are not directly comparable to the Yosys estimates above. With an 8 ns (125 MHz) clock constraint: **0 timing errors** (237,196 analyzed paths / 4,753 endpoints), minimum period **7.414 ns (~134.9 MHz)**, **887 slice registers (7%)**, **1,117 slice LUTs (19%)**, **514 occupied slices (35%)**, **0 DSP48A1 / 0 BRAM**, 37 LOCed IOBs ("Performance with IOB Packing"). Trial run (2026-11-15, not a sign-off; more devices/trials pending). Logs: [`test_xc6slx9_fma8.cmd_log`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8.cmd_log), [`test_xc6slx9_fma8.twr`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8.twr), [`test_xc6slx9_fma8_summary.html`](benchmarks/log9_fma_lat8/test_xc6slx9_fma8_summary.html).
No post-PAR trial exists yet for `vhfma001` / `vhfma002`.

Reports (regenerated 2026-11-16; `vhfma001` and `vhfma002` rows included):

- [`stat/stat_top_all.md`](stat/stat_top_all.md) — comparison of the top-level modules (RTZ, RNE, F32, FMA, add_fp32, add_fp16, add_bf16) and their typical (typ) Fmax across FPGA families;
- [`stat/stat_top_spartan6.md`](stat/stat_top_spartan6.md), [`stat/stat_top_spartan7.md`](stat/stat_top_spartan7.md), [`stat/stat_top_artix7.md`](stat/stat_top_artix7.md) — per-device details;
- [`stat/stat_others_all.md`](stat/stat_others_all.md) — bottom-up submodule comparison and typical (typ) Fmax; [`stat/stat_others_spartan6.md`](stat/stat_others_spartan6.md), [`stat/stat_others_spartan7.md`](stat/stat_others_spartan7.md), [`stat/stat_others_artix7.md`](stat/stat_others_artix7.md) — per-device submodule details.

To regenerate the statistics:

```bash
./scripts/collect_stats.py --all   # top-level modules + submodules
./scripts/generate_stat_docs.py --write
./scripts/generate_stat_others_docs.py --write
```