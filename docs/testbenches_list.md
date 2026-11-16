# Список тестбенчей (tests/**/*.v)

Всего файлов: **42**

## Основные проверяющие тестбенчи (с `TEST PASSED` / `TEST FAILED`)

| # | Файл | Тестируемый модуль | Тип | Векторов |
|---|------|-------------------|-----|----------|
| 1 | `aux/vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` | Exhaustive (все 16×16) | 256 |
| 2 | `aux/vhfastmulb16_mul4x4_lat2_tb.v` | `vhfastmulb16_mul4x4_lat2` | Exhaustive (все 16×16), LAT=2 | 256 |
| 3 | `aux/vhfastmulb16_mul_u8_u8_u16_lat2_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat2` | Exhaustive (все 256×256) | 65 536 |
| 4 | `aux/vhfastmulb16_mul_u8_u8_u16_lat3_tb.v` | `vhfastmulb16_mul_u8_u8_u16_lat3` | Exhaustive (все 256×256), LAT=3 | 65 536 |
| 5 | `aux/vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8_lat2` | Directed / visual (16 пар) | 16 |
| 6 | `aux/vhfastmulb16_add8x8_reva_tb.v` | `vhfastmulb16_add8x8_lat2` | Exhaustive (все 256×256) | 65 536 |
| 7 | `aux/vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` | Directed + pipeline | 16 |
| 8 | `aux/vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` | Directed + pipeline | 12 |
| 9 | `aux/vhfastmulb16_flags_lat2_tb.v` | `vhfastmulb16_flags_lat2` | Directed + pipeline (LAT=2) | 256 |
| 10 | `aux/vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` | Directed + pipeline (LAT=2) | 24 |
| 11 | `aux/vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` | Directed + pipeline (LAT=3) | 24 |
| 12 | `mul/vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | Visual (16 векторов из таблицы) | 16 |
| 13 | `mul/vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | Visual (16 векторов из таблицы) | 16 |
| 14 | `mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | Visual (16 векторов FAST/RTZ) | 16 |
| 15 | `mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_rand_tb.v` | `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | Random/directed regression (Python FTZ/RTZ model), `LAT=3` | 2048 |
| 16 | `mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4_tb.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | Directed + streaming, `LAT=4` | 32 |
| 17 | `mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4_rand_tb.v` | `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | Random regression (Python golden model), `LAT=4` | 2048 |
| 18 | `add/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | Directed + streaming, `LAT=4` | 32 |
| 19 | `add/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | Directed + streaming, `LAT=4` | 32 |
| 20 | `add/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | Random/directed regression (Python IEEE-754 model), `LAT=4` | 4096 |
| 21 | `add/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_rand_tb.v` | `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | Random/directed regression (Python IEEE-754 model), `LAT=4` | 4096 |
| 22 | `add/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | Directed + streaming, `LAT=4` | 32 |
| 23 | `add/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | Directed + streaming, `LAT=4` | 32 |
| 24 | `add/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | Random/directed regression (Python IEEE-754 model), `LAT=4` | 4096 |
| 25 | `add/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4_rand_tb.v` | `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | Random/directed regression (Python IEEE-754 model), `LAT=4` | 4096 |
| 26 | `add/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | Directed + streaming, `LAT=4` | 32 |
| 27 | `add/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | Directed + streaming, `LAT=4` | 32 |
| 28 | `add/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4_rand_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | Random/directed regression (Python BF16 model), `LAT=4` | 4096 |
| 29 | `add/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_rand_tb.v` | `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | Random/directed regression (Python BF16 model), `LAT=4` | 4096 |
| 30 | `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | Directed + streaming + hold/reset, `LAT=4` | 44 |
| 31 | `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | Random/directed regression (exact Python FMA model), `LAT=4` | 2048 |
| 32 | `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | Directed + streaming + hold/reset, `LAT=8` | 45 |
| 33 | `fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand_tb.v` | `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | Random/directed regression (exact Python FMA model), `LAT=8` | 2048 |
| 34 | `fma/vhfma001_tb.v` | `vhfma001` | Directed + streaming + hold/reset, `LAT=8` | 45 |
| 35 | `fma/vhfma001_rand_tb.v` | `vhfma001` | Random regression, `LAT=8` | 2048 |
| 36 | `fma/vhfma002_tb.v` | `vhfma002` | Directed + streaming + hold/reset, `LAT=8` | 45 |
| 37 | `fma/vhfma002_rand_tb.v` | `vhfma002` | Random regression, `LAT=8` | 2048 |

## Визуализационные / вспомогательные тестбенчи

| # | Файл | Модуль | Описание |
|---|------|--------|----------|
| 38 | `aux/vhfastmulb16_mul4x4_chk_tb.v` | `mul4x4` | 4 пары: 3×5, 7×9, 10×11, 15×15 |
| 39 | `aux/vhfastmulb16_mul4x4_lat2_chk_tb.v` | `mul4x4_lat2` | 12 векторов, LAT=2 |
| 40 | `aux/vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb.v` | `mul_u8_u8_u16_lat2` | 4 пары: 1×9, 3×11, 5×13, 7×15 |
| 41 | `aux/vhfastmulb16_mul_u8_u8_u16_lat3_chk_tb.v` | `mul_u8_u8_u16_lat3` | 4 пары, LAT=3 |
| 42 | `aux/vhfastmulb16_flags_lat2_chk_tb.v` | `flags_lat2` | 12 векторов, LAT=2 |

---

## Запуск тестов

```bash
# Все тесты через скрипты в scripts/
./scripts/aux/run_test_mul4x4.sh sim
./scripts/aux/run_test_mul4x4_lat2.sh sim
./scripts/aux/run_test_mul_u8_u8_u16_lat2.sh sim
./scripts/aux/run_test_mul_u8_u8_u16_lat3.sh sim
./scripts/aux/run_test_add8x8_lat2.sh sim
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

# С визуализацией (gtkwave)
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4.sh wave
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4_rand.sh wave
./scripts/add/run_test_add_fp32_fp32_fp32_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_fp32_fp32_fp32_rne_lat4_rand.sh wave
./scripts/add/run_test_add_fp16_fp16_fp16_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_fp16_fp16_fp16_rne_lat4_rand.sh wave
./scripts/add/run_test_add_bf16_bf16_bf16_rtz_lat4_rand.sh wave
./scripts/add/run_test_add_bf16_bf16_bf16_rne_lat4_rand.sh wave
./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.sh wave

# Очистка артефактов
./scripts/mul/run_test_mul_bf16_bf16_fp32_lat4.sh clean
```

---

## Тестовые векторы (testvalues/)

| Файл | Описание |
|------|----------|
| `mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_bf16_details.md` | 16 основных тестов BF16 (1.0×1.0, 2.0×3.5, -1.5×4.0, Inf×0=NaN, etc.) |
| `mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_rne.md` | Вектора для RNE округления |
| `mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_rtz.md` | Вектора для RTZ (усечение) |
| `mul/test_values_mul_bf16_bf16_fp32/test_values_mul_bf16_bf16_fp32.md` | BF16 x BF16 -> F32 exact product (16 + 4 extended) |
| `mul/test_values_mul_bf16_bf16_fp32/test_values_mul_bf16_bf16_fp32.json` | Машиночитаемая версия F32-векторов |
| `add/test_values_add_bf16_bf16_bf16/test_values_add_bf16_bf16_bf16.json` | BF16 + BF16 -> BF16, 32 вектора (RNE/RTZ) |
| `add/test_values_add_bf16_bf16_bf16/test_values_add_bf16_rne.md` | BF16 addition, только C (RNE) |
| `add/test_values_add_bf16_bf16_bf16/test_values_add_bf16_rtz.md` | BF16 addition, только C (RTZ) |
| `add/test_values_add_fp16_fp16_fp16/test_values_add_fp16_fp16_fp16.json` | FP16 + FP16 -> FP16, 32 вектора (RNE/RTZ) |
| `add/test_values_add_fp16_fp16_fp16/test_values_add_fp16_rne.md` | FP16 addition, только C (RNE) |
| `add/test_values_add_fp16_fp16_fp16/test_values_add_fp16_rtz.md` | FP16 addition, только C (RTZ) |

---

## Наименование

- `<module>_tb.v` — основной проверяющий тестбенч
- `<module>_tb.chk.v` / `<module>_chk_tb.v` — визуализационный/упрощённый
- `<module>_latN_tb.v` — если модуль имеет версию с латентностью N
- `mul/vhfastmulb16_mul_bf16_bf16_fp32_lat4_rand_tb.v` — случайный regression с Python golden-моделью
- `vhfastmulb16_add_fp32_fp32_fp32_*_rand_tb.v` — случайный/directed regression FP32-сумматоров
  с бит-точным эталоном (`scripts/gen_fp32_vectors.py`)
- `vhfastmulb16_add_fp16_fp16_fp16_*_rand_tb.v` — случайный/directed regression FP16-сумматоров
  с бит-точным эталоном (`scripts/gen_fp16_vectors.py`)
- `vhfastmulb16_add_bf16_bf16_bf16_*_rand_tb.v` — случайный/directed regression BF16-сумматоров
  с бит-точным эталоном (`scripts/gen_bf16_vectors.py`)
- `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_tb.v` — directed + hold/reset FMA
- `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb.v` — random/directed FMA
  с точной Fraction-моделью (`scripts/gen_fma_vectors.py`)
- `vhfma001_tb.v` / `vhfma001_rand_tb.v` — directed + random FMA (latency 8, клон lat8 для максимального Fmax, чистый LUT/FF)
- `vhfma002_tb.v` / `vhfma002_rand_tb.v` — directed + random FMA (latency 8; единственное исключение с DSP48 — умножение 8×8 мантисс)
