# Статистика реализации на 7-Series (Spartan-7 S15 / Artix-7 A15T)

## Спецификация целевой FPGA

| Параметр | Значение |
|----------|----------|
| **Device** | XC7S15-1 / XC7A15T-1 |
| **LUTs (6-input / LUT6)** | **8,000** |
| **Flip-Flops** | 16,000 |
| **DSP** | 0 (запрещено правилами) |
| **Block RAM** | 0 |

> **Важно:** Все цифры ниже — **оценки на основе синтеза в Yosys (YoWASP)**.
> Реальный синтез в Xilinx ISE/Vivado не выполнялся.
> Ожидаемая погрешность без реального синтеза — **±20–25%**.
> Для точного Fmax необходимо запустить Xilinx ISE/Vivado с `report_timing`.

---

## Top-level модули (LUTs)

### Модули умножения (Multiplication)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~82 | ~16 | 3 | truncation (RTZ); FTZ | **~1.0%** | 167 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~88 | ~16 | 3 | IEEE 754 RNE; FTZ | **~1.1%** | 150 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | N/A | N/A | 4 | exact; subnormals preserved | N/A | N/A |

### Комбинированные модули (Combined / FMA)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~942 | ~243 | 4 | IEEE 754 RNE; subnormals preserved | **~11.8%** | 45 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~944 | ~555 | 8 | IEEE 754 RNE; subnormals preserved | **~11.8%** | 45 |

### Модули сложения (Addition)

| Модуль | LUTs | FF | Latency | Точность | % LUTs (от 8,000) | Fmax typ, MHz |
|--------|------|-----|---------|----------|---------------------------|---------------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~753 | ~257 | 4 | truncation (RTZ); subnormals preserved | **~9.4%** | 95 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~788 | ~257 | 4 | IEEE 754 RNE; subnormals preserved | **~9.8%** | 72 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~335 | ~141 | 4 | truncation (RTZ); subnormals preserved | **~4.2%** | 101 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~357 | ~141 | 4 | IEEE 754 RNE; subnormals preserved | **~4.5%** | 89 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~361 | ~114 | 4 | truncation (RTZ); subnormals preserved | **~4.5%** | 101 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~404 | ~114 | 4 | IEEE 754 RNE; subnormals preserved | **~5.1%** | 89 |

---

## Детальная статистика по модулям

### `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~82 | **~1.0%** |
| **FF** | ~16 | **~0.1%** |
| **CARRY4** | ~3 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~204 | — |
| **Fmax (est.)** | 167 MHz | — |
| **Logic Levels (est.)** | 8 | — |
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
| $_AND_ | 27 |
| $_MUX_ | 112 |
| $_NOT_ | 15 |
| $_OR_ | 46 |
| $_SDFFE_PP0P_ | 16 |
| $_SDFF_PP0_ | 2 |
| $_XOR_ | 1 |
| CARRY4 | 3 |
| IBUF | 35 |
| OBUF | 16 |
| cells | 270 |
| ports | 6 |
| submodules | 7 |
| vhfastmulb16_add8x8_lat2 | 1 |
| vhfastmulb16_except_lat2 | 1 |
| vhfastmulb16_mul_u8_u8_u16_lat2 | 1 |
| vhfastmulb16_sign | 1 |
| wires | 112 |

---

### `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~88 | **~1.1%** |
| **FF** | ~16 | **~0.1%** |
| **CARRY4** | ~6 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~221 | — |
| **Fmax (est.)** | 150 MHz | — |
| **Logic Levels (est.)** | 9 | — |
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
| $_AND_ | 28 |
| $_MUX_ | 116 |
| $_NOT_ | 15 |
| $_OR_ | 54 |
| $_SDFFE_PP0P_ | 16 |
| $_SDFF_PP0_ | 2 |
| $_XOR_ | 2 |
| CARRY4 | 6 |
| IBUF | 35 |
| OBUF | 16 |
| cells | 284 |
| ports | 6 |
| submodules | 10 |
| vhfastmulb16_add8x8_lat2 | 1 |
| vhfastmulb16_except_lat2 | 1 |
| vhfastmulb16_mul_u8_u8_u16_lat2 | 1 |
| vhfastmulb16_sign | 1 |
| wires | 132 |

---

### `vhfastmulb16_mul_bf16_bf16_fp32_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | N/A | N/A |
| **FF** | N/A | N/A |
| **CARRY4** | N/A | — |
| **CARRY8** | N/A | — |
| **LUT6_2** | N/A | — |
| **MUXF7** | N/A | — |
| **MUXF8** | N/A | — |
| **IO (IBUF+OBUF)** | N/A | — |
| **DSP48** | N/A | 0% (запрещено) |
| **Logic Cells** | N/A | — |
| **Fmax (est.)** | N/A MHz | — |
| **Logic Levels (est.)** | N/A | — |
| **Latency** | 4 cycles | — |
| **Rounding** | exact | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
unknown
```

---

### `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~753 | **~9.4%** |
| **FF** | ~257 | **~1.6%** |
| **CARRY4** | ~19 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~99 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~1883 | — |
| **Fmax (est.)** | 95 MHz | — |
| **Logic Levels (est.)** | 15 | — |
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
| cells | 2224 |
| ports | 6 |
| submodules | 19 |
| wires | 335 |

---

### `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~788 | **~9.8%** |
| **FF** | ~257 | **~1.6%** |
| **CARRY4** | ~34 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~99 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~1969 | — |
| **Fmax (est.)** | 72 MHz | — |
| **Logic Levels (est.)** | 20 | — |
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
| cells | 2295 |
| ports | 6 |
| submodules | 34 |
| wires | 382 |

---

### `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~335 | **~4.2%** |
| **FF** | ~141 | **~0.9%** |
| **CARRY4** | ~15 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~838 | — |
| **Fmax (est.)** | 101 MHz | — |
| **Logic Levels (est.)** | 14 | — |
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
| cells | 1019 |
| ports | 6 |
| submodules | 15 |
| wires | 271 |

---

### `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~357 | **~4.5%** |
| **FF** | ~141 | **~0.9%** |
| **CARRY4** | ~23 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~892 | — |
| **Fmax (est.)** | 89 MHz | — |
| **Logic Levels (est.)** | 16 | — |
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
| cells | 1065 |
| ports | 6 |
| submodules | 23 |
| wires | 321 |

---

### `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~361 | **~4.5%** |
| **FF** | ~114 | **~0.7%** |
| **CARRY4** | ~16 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~903 | — |
| **Fmax (est.)** | 101 MHz | — |
| **Logic Levels (est.)** | 14 | — |
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
| cells | 1056 |
| ports | 6 |
| submodules | 16 |
| wires | 278 |

---

### `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~404 | **~5.1%** |
| **FF** | ~114 | **~0.7%** |
| **CARRY4** | ~23 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~51 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~1011 | — |
| **Fmax (est.)** | 89 MHz | — |
| **Logic Levels (est.)** | 16 | — |
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
| cells | 1157 |
| ports | 6 |
| submodules | 23 |
| wires | 332 |

---

### `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~942 | **~11.8%** |
| **FF** | ~243 | **~1.5%** |
| **CARRY4** | ~70 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~99 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~2354 | — |
| **Fmax (est.)** | 45 MHz | — |
| **Logic Levels (est.)** | 33 | — |
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
| $_AND_ | 186 |
| $_MUX_ | 1128 |
| $_NOT_ | 244 |
| $_OR_ | 578 |
| $_SDFFE_PP0P_ | 243 |
| $_SDFF_PP0_ | 3 |
| $_XNOR_ | 16 |
| $_XOR_ | 132 |
| CARRY4 | 70 |
| IBUF | 67 |
| OBUF | 32 |
| cells | 2629 |
| ports | 7 |
| submodules | 74 |
| vhfastmulb16_mul4x4_comb | 4 |
| wires | 667 |

---

### `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`

| Ресурс | Значение | % от доступных |
|--------|----------|----------------|
| **LUTs (est.)** | ~944 | **~11.8%** |
| **FF** | ~555 | **~3.5%** |
| **CARRY4** | ~70 | — |
| **CARRY8** | ~0 | — |
| **LUT6_2** | ~0 | — |
| **MUXF7** | ~0 | — |
| **MUXF8** | ~0 | — |
| **IO (IBUF+OBUF)** | ~99 | — |
| **DSP48** | ~0 | 0% (запрещено) |
| **Logic Cells** | ~2359 | — |
| **Fmax (est.)** | 45 MHz | — |
| **Logic Levels (est.)** | 33 | — |
| **Latency** | 8 cycles | — |
| **Rounding** | RNE | — |
| **Subnormals** | preserve | — |

**Критический путь (оценка):**
```
barrel shifter (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → normalization → RNE rounding → BF16 pack mux → output reg
```

**Распределение ячеек:**

| Тип ячейки | Количество |
|------------|------------|
| $_AND_ | 187 |
| $_MUX_ | 1128 |
| $_NOT_ | 245 |
| $_OR_ | 581 |
| $_SDFFE_PP0P_ | 555 |
| $_SDFF_PP0_ | 7 |
| $_XNOR_ | 16 |
| $_XOR_ | 132 |
| CARRY4 | 70 |
| IBUF | 67 |
| OBUF | 32 |
| cells | 2950 |
| ports | 7 |
| submodules | 74 |
| vhfastmulb16_mul4x4_comb | 4 |
| wires | 718 |

---

*Сгенерировано автоматически: 2026-11-14T07:09:19.673664Z*
*Инструменты: Yosys unknown, YoWASP unknown*)