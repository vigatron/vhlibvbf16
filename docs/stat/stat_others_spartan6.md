# Статистика реализации на Spartan-6 LX9 (-2 speed grade)

## Спецификация целевой FPGA

| Параметр | Значение |
|----------|----------|
| **Device** | XC6SLX9-2 |
| **LUTs (6-input / LUT6)** | **5,720** |
| **Flip-Flops** | 11,440 |
| **DSP** | 16 × DSP48A1 (исключительно LUT/FF; исключение — `vhfma002`, см. раздел «DSP Block Exception (`vhfma002`)» в README.md) |
| **Block RAM** | 32 × 18Kb (не используется) |

> **Важно:** Все цифры ниже — **оценки на основе синтеза в Yosys (YoWASP)**.
> Синтез останавливается до ABC9 (`-run begin:map_ffs`): YoWASP WASM не может запустить внешний `yosys-abc`.
> **LUTs — оценка по числу вентилей** (gates / 2.5), структура иерархии развёрнута (`flatten`).
> Счёт FF/CARRY4/IO — точный (по дампу RTLIL). **Fmax — ручная калибровка типовых значений** (`scripts/modules_config.py`), не измерение post-PAR.
> **Реальные post-PAR измерения (Xilinx ISE 14.7, плата CMB32F407HDMIR3, XC6SLX9-2TQG144) — папка `docs/benchmarks/`:**
> **`log_fma_fst_lat8`** — тест `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` (FAST, RTZ, FTZ, lat=8), минимальная обвязка с шиной загрузки данных:
> - [`test_xc6slx9_fma8.cmd_log`](../benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8.cmd_log) — лог запуска ISE.
> - [`test_xc6slx9_fma8.twr`](../benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8.twr) — отчёт тайминга.
> - [`test_xc6slx9_fma8_summary.html`](../benchmarks/log_fma_fst_lat8/test_xc6slx9_fma8_summary.html) — сводный отчёт по ресурсам и таймингу.
> - Констрейнт: **6 ns (≈166.7 MHz)**; **0 ошибок тайминга**; **min period 5.243 ns (≈190.7 MHz)**; slack 0.757 ns; Data Path Delay 5.227 ns (1 уровень логики).
> **`log_fma_rne_lat8`** — тест `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` (RNE, subnormals preserved, lat=8), минимальная обвязка с шиной загрузки данных:
> - [`test_xc6slx9_fma8.cmd_log`](../benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8.cmd_log) — лог запуска ISE.
> - [`test_xc6slx9_fma8.twr`](../benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8.twr) — отчёт тайминга.
> - [`test_xc6slx9_fma8_summary.html`](../benchmarks/log_fma_rne_lat8/test_xc6slx9_fma8_summary.html) — сводный отчёт по ресурсам и таймингу.
> - Констрейнт: **8 ns (125 MHz)**; **0 ошибок тайминга** (237 196 paths / 4 753 endpoints); **min period 7.414 ns (≈134.9 MHz)**; slack 0.586 ns; Data Path Delay 6.784 ns (3 уровня логики: 2.664 ns логика + 4.120 ns route); **887 slice FF (7%)**, **1 117 slice LUT (19%)**, **514 занятых слайсов (35%)**, **0 DSP48A1 / 0 BRAM**, 37 LOCed IOB.
> **`log_fma_fst_lat4`** — тест `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` (FAST, RTZ, FTZ, lat=4), минимальная обвязка с шиной загрузки данных (сборка использует то же имя проекта `test_xc6slx9_fma8`, что и lat=8 — отличается только DUT внутри `u_mul`):
> - [`test_xc6slx9_fma8.cmd_log`](../benchmarks/log_fma_fst_lat4/test_xc6slx9_fma8.cmd_log) — лог запуска ISE.
> - [`test_xc6slx9_fma8.twr`](../benchmarks/log_fma_fst_lat4/test_xc6slx9_fma8.twr) — отчёт тайминга.
> - [`test_xc6slx9_fma8_summary.html`](../benchmarks/log_fma_fst_lat4/test_xc6slx9_fma8_summary.html) — сводный отчёт по ресурсам и таймингу.
> - Констрейнт: **10 ns (100 MHz)**; **0 ошибок тайминга**; **min period 7.987 ns (≈125.2 MHz)**; худший внутренний путь DUT `grp_mul` (`u_mul/Mmux_b_man11_FRB → u_mul/Madd_exp_p_calc_lut<0>1_FRB`): **9.357 ns (≈106.9 MHz)**, Data Path Delay 9.283 ns (8 уровней логики), slack 0.643 ns; **493 slice FF (4%)**, **759 slice LUT (13%)**, **359 занятых слайсов (25%)**, **0 DSP48A1 / 0 BRAM**, 37 LOCed IOB. Сравнение с `..._fst_lat8` (890 slice FF / 802 slice LUT / 467 слайсов): 4-стадийная перебалансировка подтверждает ~2× сокращение FF при более низком Fmax; внутренний предел DUT ≈107 MHz ниже Yosys-оценки 170 MHz (нижняя граница допуска ±20–25%).
> Папка `log9_fma_lat8` удалена (переименована — это сборка `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`, см. `log_fma_rne_lat8`).
> Измерялся полный top: DUT (`u_mul`) **+ минимальный параллельный интерфейс загрузки данных** (`u_regs` + тонкая MCU-шина `u_iface`, IOB-регистры), не «голый» DUT — напрямую с Yosys-оценками (~1 013 LUT) не сопоставимо. Пробные тесты (lat=8 — 2026-11-15, lat=4 — 2026-11-21), не sign-off.
> Ожидаемая погрешность оценки LUT без реального синтеза — **±20–25%**.
> Для точного Fmax необходимо запустить Xilinx ISE/Vivado с `report_timing`.

---

## Сводная таблица

### Подмодули (Bottom-up)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 5,720) | Fmax typ, MHz | Fmax post-PAR, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|--------------------|
| `vhfastmulb16_mul4x4` | ~24 | 8 | 1 | exact | **~0.4%** | 280 | — |
| `vhfastmulb16_mul4x4_lat2` | ~24 | 24 | 2 | exact | **~0.4%** | 340 | — |
| `vhfastmulb16_mul4x4_comb` | ~24 | 0 | 0 | exact | **~0.4%** | 320 | — |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | ~129 | 48 | 2 | exact | **~2.3%** | 230 | — |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | ~130 | 101 | 3 | exact | **~2.3%** | 290 | — |
| `vhfastmulb16_add8x8_lat2` | ~4 | 19 | 2 | exact | **~0.1%** | 400 | — |
| `vhfastmulb16_sign` | ~0 | 3 | 3 | exact | **~0.0%** | 500 | — |
| `vhfastmulb16_flags_lat1` | ~16 | 5 | 1 | exact | **~0.3%** | 400 | — |
| `vhfastmulb16_flags_lat2` | ~16 | 11 | 2 | exact | **~0.3%** | 450 | — |
| `vhfastmulb16_except_lat2` | ~40 | 32 | 2 | exact | **~0.7%** | 320 | — |
| `vhfastmulb16_except_lat3` | ~40 | 57 | 3 | exact | **~0.7%** | 360 | — |

---

## Детальная статистика по модулям

### `vhfastmulb16_mul4x4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~24 | **~0.4%** |
| **FF** | 8 | **~0.1%** |
| **CARRY4** | 2 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~61 | — |
| **Logic Cells (total)** | 90 | — |
| **IO (IBUF+OBUF)** | 19 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 280 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 1 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
16 частичных произведений (AND) → CSA tree (2 уровня) → 8-битный CPA (CARRY4) → выходной регистр
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 34 |
| $_OR_ | 10 |
| $_SDFFE_PP0P_ | 8 |
| $_XOR_ | 17 |
| CARRY4 | 2 |
| IBUF | 11 |
| OBUF | 8 |

---

### `vhfastmulb16_mul4x4_lat2`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~24 | **~0.4%** |
| **FF** | 24 | **~0.2%** |
| **CARRY4** | 2 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~61 | — |
| **Logic Cells (total)** | 106 | — |
| **IO (IBUF+OBUF)** | 19 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 340 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 2 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
CSA tree → 8-битный CPA (CARRY4) → выходной регистр (стадия 2)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 34 |
| $_OR_ | 10 |
| $_SDFFE_PP0P_ | 23 |
| $_SDFF_PP0_ | 1 |
| $_XOR_ | 17 |
| CARRY4 | 2 |
| IBUF | 11 |
| OBUF | 8 |

---

### `vhfastmulb16_mul4x4_comb`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~24 | **~0.4%** |
| **FF** | 0 | **~0.0%** |
| **CARRY4** | 2 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~61 | — |
| **Logic Cells (total)** | 79 | — |
| **IO (IBUF+OBUF)** | 16 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 320 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 0 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
16 частичных произведений (AND) → CSA tree (2 уровня) → 8-битный CPA (CARRY4) → комбинационный выход
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 34 |
| $_OR_ | 10 |
| $_XOR_ | 17 |
| CARRY4 | 2 |
| IBUF | 8 |
| OBUF | 8 |

---

### `vhfastmulb16_mul_u8_u8_u16_lat2`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~129 | **~2.3%** |
| **FF** | 48 | **~0.4%** |
| **CARRY4** | 11 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~322 | — |
| **Logic Cells (total)** | 416 | — |
| **IO (IBUF+OBUF)** | 35 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 230 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 2 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
4× mul4x4 (CSA) → 2 уровня CSA → 16-битный CPA (CARRY4) → выходной регистр
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 167 |
| $_OR_ | 54 |
| $_SDFFE_PP0P_ | 48 |
| $_XOR_ | 101 |
| CARRY4 | 11 |
| IBUF | 19 |
| OBUF | 16 |

---

### `vhfastmulb16_mul_u8_u8_u16_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~130 | **~2.3%** |
| **FF** | 101 | **~0.9%** |
| **CARRY4** | 11 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~324 | — |
| **Logic Cells (total)** | 471 | — |
| **IO (IBUF+OBUF)** | 35 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 290 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 3 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
4× mul4x4_lat2 (2 стадии) → CSA tree → 16-битный CPA → выходной регистр (стадия 3)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 167 |
| $_OR_ | 56 |
| $_SDFFE_PP0P_ | 98 |
| $_SDFF_PP0_ | 3 |
| $_XOR_ | 101 |
| CARRY4 | 11 |
| IBUF | 19 |
| OBUF | 16 |

---

### `vhfastmulb16_add8x8_lat2`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~4 | **~0.1%** |
| **FF** | 19 | **~0.2%** |
| **CARRY4** | 6 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~10 | — |
| **Logic Cells (total)** | 63 | — |
| **IO (IBUF+OBUF)** | 28 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 400 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 2 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
9-битный сумматор + 9-битный вычитатель (константа 127) → CARRY4 → выходной регистр
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_NOT_ | 2 |
| $_SDFFE_PP0P_ | 18 |
| $_SDFF_PP0_ | 1 |
| $_XOR_ | 8 |
| CARRY4 | 6 |
| IBUF | 19 |
| OBUF | 9 |

---

### `vhfastmulb16_sign`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~0 | **~0.0%** |
| **FF** | 3 | **~0.0%** |
| **CARRY4** | 0 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1 | — |
| **Logic Cells (total)** | 12 | — |
| **IO (IBUF+OBUF)** | 8 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 500 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 3 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
XOR (sign) → signc_lat1 → signc_lat2 → signc_lat3 (en, синхронный reset)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_SDFFE_PP0P_ | 3 |
| $_XOR_ | 1 |
| IBUF | 5 |
| OBUF | 3 |

---

### `vhfastmulb16_flags_lat1`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~16 | **~0.3%** |
| **FF** | 5 | **~0.0%** |
| **CARRY4** | 0 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~39 | — |
| **Logic Cells (total)** | 68 | — |
| **IO (IBUF+OBUF)** | 24 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 400 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 1 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
NaN/Inf/Zero классификация → регистр (латентность 1)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 4 |
| $_NOT_ | 17 |
| $_OR_ | 18 |
| $_SDFFE_PP0P_ | 5 |
| IBUF | 19 |
| OBUF | 5 |

---

### `vhfastmulb16_flags_lat2`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~16 | **~0.3%** |
| **FF** | 11 | **~0.1%** |
| **CARRY4** | 0 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~39 | — |
| **Logic Cells (total)** | 74 | — |
| **IO (IBUF+OBUF)** | 24 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 450 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 2 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
flags_lat1 → регистр (латентность 2)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 4 |
| $_NOT_ | 17 |
| $_OR_ | 18 |
| $_SDFFE_PP0P_ | 11 |
| IBUF | 19 |
| OBUF | 5 |

---

### `vhfastmulb16_except_lat2`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~40 | **~0.7%** |
| **FF** | 32 | **~0.3%** |
| **CARRY4** | 0 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~101 | — |
| **Logic Cells (total)** | 188 | — |
| **IO (IBUF+OBUF)** | 55 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 320 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 2 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
flags_lat1 ×2 → классификация NaN/Inf/Zero → выбор NaN payload / флагов → выходной регистр (латентность 2)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 15 |
| $_MUX_ | 13 |
| $_NOT_ | 32 |
| $_OR_ | 41 |
| $_SDFFE_PP0P_ | 19 |
| $_SDFF_PP0_ | 13 |
| IBUF | 35 |
| OBUF | 20 |

---

### `vhfastmulb16_except_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~40 | **~0.7%** |
| **FF** | 57 | **~0.5%** |
| **CARRY4** | 0 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~101 | — |
| **Logic Cells (total)** | 213 | — |
| **IO (IBUF+OBUF)** | 55 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 360 MHz | источник: manual |
| **Fmax (post-PAR, measured)** | — | измерений нет |
| **Latency** | 3 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | n/a | — |

**Критический путь (оценка):**
```
flags_lat2 ×2 → классификация NaN/Inf/Zero → выбор NaN payload / флагов → выходной регистр (латентность 3)
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 15 |
| $_MUX_ | 13 |
| $_NOT_ | 32 |
| $_OR_ | 41 |
| $_SDFFE_PP0P_ | 31 |
| $_SDFF_PP0_ | 26 |
| IBUF | 35 |
| OBUF | 20 |

---

*Сгенерировано автоматически: 2026-11-21T14:41:08.772255Z*
*Инструменты: Yosys 0.70 (git sha1 28ba3cb92), YoWASP 0.70.0.0.post1259, wasmtime 47.0.1*