# Список тестбенчей (tests/*.v)

Всего файлов: **14**

## Основные проверяющие тестбенчи (с `TEST PASSED` / `TEST FAILED`)

| # | Файл | Тестируемый модуль | Тип | Векторов |
|---|------|-------------------|-----|----------|
| 1 | `vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` | Exhaustive (все 16×16) | 256 |
| 2 | `vhfastmulb16_mul8x8_tb.v` | `vhfastmulb16_mul8x8` | Exhaustive (все 256×256) | 65 536 |
| 3 | `vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8` | Directed | — |
| 4 | `vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` | Directed + pipeline | 16 |
| 5 | `vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` | Directed (256 значений exp) | 256 |
| 6 | `vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` | Directed + pipeline (LAT=2) | 24 |
| 7 | `vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` | Directed + pipeline (LAT=3) | 24 |
| 8 | `vhfastmulb16_lat3_tb.v` | `vhfastmulb16_rtz_lat3` | Visual (16 векторов из таблицы) | 16 |
| 9 | `vhfastmulb16_rne_lat3_tb.v` | `vhfastmulb16_rne_lat3` | Visual (16 векторов из таблицы) | 16 |

## Визуализационные тестбенчи (`.chk.v` — для gtkwave)

| # | Файл | Модуль | Описание |
|---|------|--------|----------|
| 10 | `vhfastmulb16_mul4x4_tb.chk.v` | `mul4x4` | 4 пары: 3×5, 7×9, 10×11, 15×15 |
| 11 | `vhfastmulb16_mul8x8_chk_tb.v` | `mul8x8` | 4 пары: 1×9, 3×11, 5×13, 7×15 |
| 12 | `vhfastmulb16_add8x8_tb.chk.v` | `add8x8_lat2` | 16 пар экспонент из test_values_rnz.md |
| 13 | `vhfastmulb16_flags_lat2_tb.chk.v` | `flags_lat2` | 12 векторов, LAT=2 |
| 14 | `vhfastmulb16_rne_lat3_tb.v` | `rne_lat3` | Уже в основном списке |

---

## Запуск тестов

```bash
# Все тесты через скрипты в scripts/
./scripts/run_test_mul4x4.sh sim
./scripts/run_test_mul8x8.sh sim
./scripts/run_test_add8x8.sh sim
./scripts/run_test_sign.sh sim
./scripts/run_test_flags_lat1.sh sim
./scripts/run_test_flags_lat2.sh sim
./scripts/run_test_except_lat2.sh sim
./scripts/run_test_except_lat3.sh sim
./scripts/run_test_mul_fb16_lat3.sh sim      # RTZ top-level
./scripts/run_test_mul_fb16_rne_lat3.sh sim  # RNE top-level

# С визуализацией (gtkwave)
./scripts/run_test_mul4x4.sh wave
./scripts/run_test_mul8x8.sh wave
# ... и т.д.

# Очистка артефактов
./scripts/run_test_mul4x4.sh clean
# ... и т.д.
```

---

## Тестовые векторы (docs/test_values/)

| Файл | Описание |
|------|----------|
| `test_values_details.md` | 16 основных тестов (1.0×1.0, 2.0×3.5, -1.5×4.0, Inf×0=NaN, etc.) |
| `test_values_rne.md` | Вектора для RNE округления |
| `test_values_rnz.md` | Вектора для RTZ (усечение) |

---

## Наименование

- `<module>_tb.v` — основной проверяющий тестбенч
- `<module>_tb.chk.v` — визуализационный (упрощённый, для gtkwave)
- `<module>_latN_tb.v` — если модуль имеет версию с латентностью N