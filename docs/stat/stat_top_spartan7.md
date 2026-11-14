# Статистика реализации на Spartan-7 S15 (-1 speed grade)

## Спецификация целевой FPGA

| Параметр | Значение |
|----------|----------|
| **Device** | XC7S15-1 |
| **LUTs (6-input / LUT6)** | **8,000** |
| **Flip-Flops** | 16,000 |
| **DSP** | 20 × DSP48E1 (не используются — запрещено правилами) |
| **Block RAM** | 10 × 36Kb (не используется) |

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

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~252 | 106 | 3 | truncation (RTZ); FTZ | **~3.1%** | 205 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~259 | 117 | 3 | IEEE 754 RNE; FTZ | **~3.2%** | 180 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | ~485 | 170 | 4 | exact; subnormals preserved | **~6.1%** | 165 |

### Комбинированные модули (Combined / FMA)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~1011 | 246 | 4 | IEEE 754 RNE; subnormals preserved | **~12.6%** | 125 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~1013 | 562 | 8 | IEEE 754 RNE; subnormals preserved | **~12.7%** | 200 |

### Модули сложения (Addition)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~746 | 261 | 4 | truncation (RTZ); subnormals preserved | **~9.3%** | 140 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~774 | 261 | 4 | IEEE 754 RNE; subnormals preserved | **~9.7%** | 130 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~329 | 145 | 4 | truncation (RTZ); subnormals preserved | **~4.1%** | 170 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~348 | 145 | 4 | IEEE 754 RNE; subnormals preserved | **~4.3%** | 155 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~355 | 118 | 4 | truncation (RTZ); subnormals preserved | **~4.4%** | 165 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~395 | 118 | 4 | IEEE 754 RNE; subnormals preserved | **~4.9%** | 150 |

---

## Детальная статистика по модулям

### `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~252 | **~3.1%** |
| **FF** | 106 | **~0.7%** |
| **CARRY4** | 20 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~629 | — |
| **Logic Cells (total)** | 806 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 205 MHz | источник: manual |
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
| **LUTs (est.)** | ~259 | **~3.2%** |
| **FF** | 117 | **~0.7%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~647 | — |
| **Logic Cells (total)** | 838 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 180 MHz | источник: manual |
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

### `vhfastmulb16_mul_bf16_bf16_fp32_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~485 | **~6.1%** |
| **FF** | 170 | **~1.1%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1212 | — |
| **Logic Cells (total)** | 1472 | — |
| **IO (IBUF+OBUF)** | 67 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 165 MHz | источник: manual |
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
| **LUTs (est.)** | ~746 | **~9.3%** |
| **FF** | 261 | **~1.6%** |
| **CARRY4** | 19 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1864 | — |
| **Logic Cells (total)** | 2243 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 140 MHz | источник: manual |
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
| **LUTs (est.)** | ~774 | **~9.7%** |
| **FF** | 261 | **~1.6%** |
| **CARRY4** | 34 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~1935 | — |
| **Logic Cells (total)** | 2329 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 130 MHz | источник: manual |
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
| **LUTs (est.)** | ~329 | **~4.1%** |
| **FF** | 145 | **~0.9%** |
| **CARRY4** | 15 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~823 | — |
| **Logic Cells (total)** | 1034 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 170 MHz | источник: manual |
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
| **LUTs (est.)** | ~348 | **~4.3%** |
| **FF** | 145 | **~0.9%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~869 | — |
| **Logic Cells (total)** | 1088 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 155 MHz | источник: manual |
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
| **LUTs (est.)** | ~355 | **~4.4%** |
| **FF** | 118 | **~0.7%** |
| **CARRY4** | 16 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~887 | — |
| **Logic Cells (total)** | 1072 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 165 MHz | источник: manual |
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
| **LUTs (est.)** | ~395 | **~4.9%** |
| **FF** | 118 | **~0.7%** |
| **CARRY4** | 23 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~988 | — |
| **Logic Cells (total)** | 1180 | — |
| **IO (IBUF+OBUF)** | 51 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 150 MHz | источник: manual |
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
| **LUTs (est.)** | ~1011 | **~12.6%** |
| **FF** | 246 | **~1.5%** |
| **CARRY4** | 78 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2528 | — |
| **Logic Cells (total)** | 2951 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 125 MHz | источник: manual |
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
| **LUTs (est.)** | ~1013 | **~12.7%** |
| **FF** | 562 | **~3.5%** |
| **CARRY4** | 78 | — |
| **CARRY8** | 0 | — |
| **LUT6_2** | 0 | — |
| **MUXF7** | 0 | — |
| **MUXF8** | 0 | — |
| **Gates (pre-ABC9)** | ~2533 | — |
| **Logic Cells (total)** | 3272 | — |
| **IO (IBUF+OBUF)** | 99 | — |
| **DSP48** | 0 | 0% (запрещено, проверено) |
| **Fmax (typ, manual)** | 200 MHz | источник: manual |
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

*Сгенерировано автоматически: 2026-11-14T07:41:44.719414Z*
*Инструменты: Yosys 0.70 (git sha1 28ba3cb92), YoWASP 0.70.0.0.post1259, wasmtime 47.0.1*