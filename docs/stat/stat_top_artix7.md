# Статистика реализации на Artix-7 A15T (-1 speed grade)

## Спецификация целевой FPGA

| Параметр | Значение |
|----------|----------|
| **Device** | XC7A15T-1 |
| **LUTs (6-input / LUT6)** | **10,400** |
| **Flip-Flops** | 20,800 |
| **DSP** | 45 × DSP48E1 (исключительно LUT/FF; исключение — `vhfma002`, см. раздел «DSP Block Exception (`vhfma002`)» в README.md) |
| **Block RAM** | 25 × 36Kb (не используется) |

> **Важно:** Все цифры ниже — **оценки на основе синтеза в Yosys (YoWASP)**.
> Синтез останавливается до ABC9 (`-run begin:map_ffs`): YoWASP WASM не может запустить внешний `yosys-abc`.
> **LUTs — оценка по числу вентилей** (gates / 2.5), структура иерархии развёрнута (`flatten`).
> Счёт FF/CARRY4/IO — точный (по дампу RTLIL). **Fmax — ручная калибровка типовых значений** (`scripts/modules_config.py`), не измерение post-PAR.
> Реальный синтез в Xilinx ISE/Vivado не выполнялся.
> Ожидаемая погрешность оценки LUT без реального синтеза — **±20–25%**.
> Для точного Fmax необходимо запустить Xilinx ISE/Vivado с `report_timing`.

---

## Top-level модули (LUTs)

### Модули умножения (Multiplication)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 10,400) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~252 | 106 | 3 | truncation (RTZ); FTZ | **~2.4%** | 230 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~259 | 117 | 3 | IEEE 754 RNE; FTZ | **~2.5%** | 210 |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | ~230 | 61 | 3 | truncation (RTZ); FTZ | **~2.2%** | 255 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | ~485 | 170 | 4 | exact; subnormals preserved | **~4.7%** | 190 |

### Комбинированные модули (Combined / FMA)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 10,400) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~1011 | 246 | 4 | IEEE 754 RNE; subnormals preserved | **~9.7%** | 145 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~1013 | 562 | 8 | IEEE 754 RNE; subnormals preserved | **~9.7%** | 220 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | ~662 | 528 | 8 | truncation (RTZ); FTZ | **~6.4%** | 250 |
| `vhfma001` | ~1148 | 570 | 8 | IEEE 754 RNE; subnormals preserved | **~11.0%** | 230 |
| `vhfma002` | ~1016 | 510 | 8 | IEEE 754 RNE; subnormals preserved | **~9.8%** | 230 |

### Модули сложения (Addition)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 10,400) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~746 | 261 | 4 | truncation (RTZ); subnormals preserved | **~7.2%** | 160 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~774 | 261 | 4 | IEEE 754 RNE; subnormals preserved | **~7.4%** | 150 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~329 | 145 | 4 | truncation (RTZ); subnormals preserved | **~3.2%** | 200 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~348 | 145 | 4 | IEEE 754 RNE; subnormals preserved | **~3.3%** | 185 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~355 | 118 | 4 | truncation (RTZ); subnormals preserved | **~3.4%** | 195 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~395 | 118 | 4 | IEEE 754 RNE; subnormals preserved | **~3.8%** | 180 |

---

## Детальная статистика по модулям

### `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~252 | **~2.4%** |
| **FF** | 106 | **~0.5%** |
| **CARRY4** | 20 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~629 | — |
| **Logic Cells (total)** | 806 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 230 MHz | источник: manual |
| **Latency** | 3 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | FTZ | — |

**Критический путь (оценка):**
```
mul4x4 (CSA) → mul_u8_u8_u16_lat2 CPA → exp_sum + man_msb → c_next mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 208 |
| $_MUX_ | 125 |
| $_NOT_ | 49 |
| $_OR_ | 139 |
| $_SDFFE_PP0P_ | 91 |
| $_SDFF_PP0_ | 15 |
| $_XOR_ | 108 |
| CARRY4 | 20 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~259 | **~2.5%** |
| **FF** | 117 | **~0.6%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~647 | — |
| **Logic Cells (total)** | 838 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 210 MHz | источник: manual |
| **Latency** | 3 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | FTZ | — |

**Критический путь (оценка):**
```
mul4x4 (CSA) → CPA → man_shifted/G/R/S → RNE increment → exp_inc → exp_norm (9-bit add) → c_next mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 210 |
| $_MUX_ | 129 |
| $_NOT_ | 49 |
| $_OR_ | 147 |
| $_SDFFE_PP0P_ | 102 |
| $_SDFF_PP0_ | 15 |
| $_XOR_ | 112 |
| CARRY4 | 23 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~230 | **~2.2%** |
| **FF** | 61 | **~0.3%** |
| **CARRY4** | 17 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~575 | — |
| **Logic Cells (total)** | 704 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 255 MHz | источник: manual |
| **Latency** | 3 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | FTZ | — |

**Критический путь (оценка):**
```
unknown
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 208 |
| $_MUX_ | 97 |
| $_NOT_ | 36 |
| $_OR_ | 119 |
| $_SDFFE_PP0P_ | 59 |
| $_SDFF_PP0_ | 2 |
| $_XOR_ | 115 |
| CARRY4 | 17 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_mul_bf16_bf16_fp32_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~485 | **~4.7%** |
| **FF** | 170 | **~0.8%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1212 | — |
| **Logic Cells (total)** | 1472 | — |
| **IO (IBUF+OBUF)** | 67 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 190 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
mul4x4_comb (CSA) → CPA → leading-one → mant_norm shifter → exp_unb → F32 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 229 |
| $_MUX_ | 567 |
| $_NOT_ | 71 |
| $_OR_ | 231 |
| $_SDFFE_PP0P_ | 166 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 114 |
| CARRY4 | 23 |
| IBUF | 35 |
| OBUF | 32 |

---

### `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~746 | **~7.2%** |
| **FF** | 261 | **~1.3%** |
| **CARRY4** | 19 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1864 | — |
| **Logic Cells (total)** | 2243 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 160 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter alignment (S1) → 28-bit add/sub (S2) → LZD 27-bit (S3) → carry fix-up → F32 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 300 |
| $_MUX_ | 814 |
| $_NOT_ | 168 |
| $_OR_ | 490 |
| $_SDFFE_PP0P_ | 257 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 92 |
| CARRY4 | 19 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~774 | **~7.4%** |
| **FF** | 261 | **~1.3%** |
| **CARRY4** | 34 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1935 | — |
| **Logic Cells (total)** | 2329 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 150 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter (S1) → 28-bit add/sub (S2) → LZD 27-bit (S3) → normalization → RNE rounding (G/R/S + increment) → F32 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 306 |
| $_MUX_ | 861 |
| $_NOT_ | 172 |
| $_OR_ | 501 |
| $_SDFFE_PP0P_ | 257 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 95 |
| CARRY4 | 34 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~329 | **~3.2%** |
| **FF** | 145 | **~0.7%** |
| **CARRY4** | 15 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~823 | — |
| **Logic Cells (total)** | 1034 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 200 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter alignment (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → carry fix-up → F16 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 126 |
| $_MUX_ | 358 |
| $_NOT_ | 96 |
| $_OR_ | 189 |
| $_SDFFE_PP0P_ | 141 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 54 |
| CARRY4 | 15 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~348 | **~3.3%** |
| **FF** | 145 | **~0.7%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~869 | — |
| **Logic Cells (total)** | 1088 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 185 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → normalization → RNE rounding → F16 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 132 |
| $_MUX_ | 380 |
| $_NOT_ | 100 |
| $_OR_ | 200 |
| $_SDFFE_PP0P_ | 141 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 57 |
| CARRY4 | 23 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~355 | **~3.4%** |
| **FF** | 118 | **~0.6%** |
| **CARRY4** | 16 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~887 | — |
| **Logic Cells (total)** | 1072 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 195 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter alignment (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → carry fix-up → BF16 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 144 |
| $_MUX_ | 393 |
| $_NOT_ | 104 |
| $_OR_ | 185 |
| $_SDFFE_PP0P_ | 114 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 61 |
| CARRY4 | 16 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~395 | **~3.8%** |
| **FF** | 118 | **~0.6%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~988 | — |
| **Logic Cells (total)** | 1180 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 180 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → normalization → RNE rounding → BF16 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 149 |
| $_MUX_ | 423 |
| $_NOT_ | 114 |
| $_OR_ | 241 |
| $_SDFFE_PP0P_ | 114 |
| $_SDFF_PP0_ | 4 |
| $_XOR_ | 61 |
| CARRY4 | 23 |
| IBUF | 35 |
| OBUF | 16 |

---

### `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~1011 | **~9.7%** |
| **FF** | 246 | **~1.2%** |
| **CARRY4** | 78 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2528 | — |
| **Logic Cells (total)** | 2951 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 145 MHz | источник: manual |
| **Latency** | 4 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
p_*_d1 → CSA tree → 16-bit CPA → k_calc → exp_p_calc → exp compare → shift_diff → large/small mux → 27-bit alignment shifter → reg S3
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 322 |
| $_MUX_ | 1128 |
| $_NOT_ | 244 |
| $_OR_ | 618 |
| $_SDFFE_PP0P_ | 243 |
| $_SDFF_PP0_ | 3 |
| $_XNOR_ | 16 |
| $_XOR_ | 200 |
| CARRY4 | 78 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~1013 | **~9.7%** |
| **FF** | 562 | **~2.7%** |
| **CARRY4** | 78 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2533 | — |
| **Logic Cells (total)** | 3272 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 220 MHz | источник: manual |
| **Latency** | 8 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
P1-P4 balanced pipeline: all stages 7-11 LUT levels (S4 worst: 10-11). CARRY4 subtractors, per-stage CE, deferred mantissa compare, LZD split S6/S7
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 323 |
| $_MUX_ | 1128 |
| $_NOT_ | 245 |
| $_OR_ | 621 |
| $_SDFFE_PP0P_ | 555 |
| $_SDFF_PP0_ | 7 |
| $_XNOR_ | 16 |
| $_XOR_ | 200 |
| CARRY4 | 78 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~662 | **~6.4%** |
| **FF** | 528 | **~2.5%** |
| **CARRY4** | 50 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1654 | — |
| **Logic Cells (total)** | 2331 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 250 MHz | источник: manual |
| **Latency** | 8 cycles | — |
| **Rounding** | RTZ | — |
| **Subnormals** | FTZ | — |

**Критический путь (оценка):**
```
8-stage balanced pipeline: S1 decode+FTZ+4×mul4x4, S2 CSA, S3 CPA+1-bit norm, S4 exp diff+large/small, S5 alignment, S6 28-bit add+LZD, S7 LZD normalize+exp_pre, S8 RTZ pack; no sticky, no RNE, no subnormal path
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 284 |
| $_MUX_ | 625 |
| $_NOT_ | 161 |
| $_OR_ | 383 |
| $_SDFFE_PP0P_ | 521 |
| $_SDFF_PP0_ | 7 |
| $_XNOR_ | 16 |
| $_XOR_ | 185 |
| CARRY4 | 50 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfma001`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~1148 | **~11.0%** |
| **FF** | 570 | **~2.7%** |
| **CARRY4** | 78 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2871 | — |
| **Logic Cells (total)** | 3618 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 230 MHz | источник: manual |
| **Latency** | 8 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
unknown
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 354 |
| $_MUX_ | 1260 |
| $_NOT_ | 267 |
| $_OR_ | 763 |
| $_SDFFE_PP0P_ | 563 |
| $_SDFF_PP0_ | 7 |
| $_XNOR_ | 16 |
| $_XOR_ | 211 |
| CARRY4 | 78 |
| IBUF | 67 |
| OBUF | 32 |

---

### `vhfma002`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~1016 | **~9.8%** |
| **FF** | 510 | **~2.5%** |
| **CARRY4** | 70 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2540 | — |
| **Logic Cells (total)** | 3220 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 1 | **~2.2%** (разрешено исключением — см. README.md, «DSP Block Exception (`vhfma002`)») |
| **Fmax (typ, manual)** | 230 MHz | источник: manual |
| **Latency** | 8 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
unknown
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 196 |
| $_MUX_ | 1276 |
| $_NOT_ | 264 |
| $_OR_ | 682 |
| $_SDFFE_PP0P_ | 503 |
| $_SDFF_PP0_ | 7 |
| $_XNOR_ | 16 |
| $_XOR_ | 106 |
| CARRY4 | 70 |
| DSP48E1 | 1 |
| IBUF | 67 |
| OBUF | 32 |

---

*Сгенерировано автоматически: 2026-11-17T10:50:51.912525Z*
*Инструменты: Yosys 0.70 (git sha1 28ba3cb92), YoWASP 0.70.0.0.post1259, wasmtime 47.0.1*