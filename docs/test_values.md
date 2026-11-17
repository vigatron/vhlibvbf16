# Test Values

← [README](../README.md)

Test vectors live in the top-level [testvalues/](../testvalues/) directory (one
subdirectory per operation):

| Directory | Contents |
|-----------|----------|
| `testvalues/mul/test_values_mul_bf16_bf16_bf16/` | BF16 × BF16 → BF16 vectors (main 16 + RNE/RTZ tables + fst FAST/RTZ vectors) |
| `testvalues/mul/test_values_mul_bf16_bf16_fp32/` | BF16 × BF16 → F32 exact-product vectors (`.md` + `.json`) |
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