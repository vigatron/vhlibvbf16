# Список тестбенчей (tests/*.v)

Всего файлов: **20**

## Основные проверяющие тестбенчи (с `TEST PASSED` / `TEST FAILED`)

| # | Файл | Тестируемый модуль | Тип | Векторов |
|---|------|-------------------|-----|----------|
| 1 | `vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` | Exhaustive (все 16×16) | 256 |
| 2 | `vhfastmulb16_mul4x4_lat2_tb.v` | `vhfastmulb16_mul4x4_lat2` | Exhaustive (все 16×16), LAT=2 | 256 |
| 3 | `vhfastmulb16_mul8x8_tb.v` | `vhfastmulb16_mul8x8` | Exhaustive (все 256×256) | 65 536 |
| 4 | `vhfastmulb16_mul8x8_lat3_tb.v` | `vhfastmulb16_mul8x8_lat3` | Exhaustive (все 256×256), LAT=3 | 65 536 |
| 5 | `vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8` | Directed | — |
| 6 | `vhfastmulb16_add8x8_reva_tb.v` | `vhfastmulb16_add8x8` | Directed (branch variant) | — |
| 7 | `vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` | Directed + pipeline | 16 |
| 8 | `vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` | Directed (256 значений exp) | 256 |
| 9 | `vhfastmulb16_flags_lat2_tb.v` | `vhfastmulb16_flags_lat2` | Directed + pipeline (LAT=2) | — |
| 10 | `vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` | Directed + pipeline (LAT=2) | 24 |
| 11 | `vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` | Directed + pipeline (LAT=3) | 24 |
| 12 | `vhfastmulb16_rtz_lat3_tb.v` | `vhfastmulb16_rtz_lat3` | Visual (16 векторов из таблицы) | 16 |
| 13 | `vhfastmulb16_rne_lat3_tb.v` | `vhfastmulb16_rne_lat3` | Visual (16 векторов из таблицы) | 16 |
| 14 | `vhfastmulb16_f32_lat4_tb.v` | `vhfastmulb16_f32_lat4` | Directed + streaming, `LAT=4` | 32 |
| 15 | `vhfastmulb16_f32_lat4_rand_tb.v` | `vhfastmulb16_f32_lat4` | Random regression (Python golden model), `LAT=4` | 2048 |

## Визуализационные / вспомогательные тестбенчи

| # | Файл | Модуль | Описание |
|---|------|--------|----------|
| 16 | `vhfastmulb16_mul4x4_chk_tb.v` | `mul4x4` | 4 пары: 3×5, 7×9, 10×11, 15×15 |
| 17 | `vhfastmulb16_mul4x4_lat2_chk_tb.v` | `mul4x4_lat2` | 12 векторов, LAT=2 |
| 18 | `vhfastmulb16_mul8x8_chk_tb.v` | `mul8x8` | 4 пары: 1×9, 3×11, 5×13, 7×15 |
| 19 | `vhfastmulb16_mul8x8_lat3_chk_tb.v` | `mul8x8_lat3` | 4 пары, LAT=3 |
| 20 | `vhfastmulb16_flags_lat2_chk_tb.v` | `flags_lat2` | 12 векторов, LAT=2 |

---

## Запуск тестов

```bash
# Все тесты через скрипты в scripts/
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

# С визуализацией (gtkwave)
./scripts/run_test_f32_lat4.sh wave
./scripts/run_test_f32_lat4_rand.sh wave

# Очистка артефактов
./scripts/run_test_f32_lat4.sh clean
```

---

## Тестовые векторы (docs/test_values/)

| Файл | Описание |
|------|----------|
| `test_values_details.md` | 16 основных тестов BF16 (1.0×1.0, 2.0×3.5, -1.5×4.0, Inf×0=NaN, etc.) |
| `test_values_rne.md` | Вектора для RNE округления |
| `test_values_rnz.md` | Вектора для RTZ (усечение) |
| `test_values_bf16_bf16_f32.md` | BF16 x BF16 -> F32 exact product (16 + 4 extended) |
| `test_values_bf16_bf16_f32.json` | Машиночитаемая версия F32-векторов |

---

## Наименование

- `<module>_tb.v` — основной проверяющий тестбенч
- `<module>_tb.chk.v` / `<module>_chk_tb.v` — визуализационный/упрощённый
- `<module>_latN_tb.v` — если модуль имеет версию с латентностью N
- `vhfastmulb16_f32_lat4_rand_tb.v` — случайный regression с Python golden-моделью
