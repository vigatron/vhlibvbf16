# Run the Simulation

← [README](../README.md)

All scripts are started from the project root.

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
See [testbenches_list.md](testbenches_list.md) and
[srcfiles_list.md](srcfiles_list.md) for more details.