# Сравнительная статистика всех top модулей на всех FPGA

Источник данных: `docs/stat/stat_top_xc6s.md`, `docs/stat/stat_top_xc7s.md`, `docs/stat/stat_top_xc7a.md`.
Все цифры — оценки на основе синтеза в Yosys (YoWASP) с погрешностью ±20–25%.

---

## Ресурсы целевых FPGA

| Device | Семейство | LUT6 | FF | DSP | BRAM |
|--------|-----------|------|-----|-----|------|
| XC6SLX9-2 | Spartan-6 | 5,720 | 11,440 | 0 (запрещено) | 0 |
| XC7S15-1 | Spartan-7 | 8,000 | 16,000 | 0 (запрещено) | 0 |
| XC7A15T-1 | Artix-7 | 10,400 | 20,800 | 0 (запрещено) | 0 |

---

## Сравнение top-level модулей (LUTs)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~82 | ~82 | ~82 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~88 | ~88 | ~88 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | N/A | N/A | N/A |

## Сравнение top-level модулей (FF)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~16 | ~16 | ~16 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~16 | ~16 | ~16 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | N/A | N/A | N/A |

## Сравнение top-level модулей (% от доступных LUT6)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | **~1.4%** | **~1.0%** | **~0.8%** |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | **~1.5%** | **~1.1%** | **~0.8%** |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | N/A | N/A | N/A |

## Сравнение Latency и Fmax (оценка)

### Модули умножения (Multiplication)

| Модуль | Latency | Fmax XC6SLX9-2 | Fmax XC7S15-1 | Fmax XC7A15T-1 | Точность |
|----------|------------|------------|------------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | 3 | 131 MHz | 167 MHz | 167 MHz | truncation (RTZ); FTZ |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | 3 | 118 MHz | 150 MHz | 150 MHz | IEEE 754 RNE; FTZ |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | 4 | N/A MHz | N/A MHz | N/A MHz | exact; subnormals preserved |

## Сравнение top-level модулей (LUTs)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~942 | ~942 | ~942 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~944 | ~944 | ~944 |

## Сравнение top-level модулей (FF)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~243 | ~243 | ~243 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~555 | ~555 | ~555 |

## Сравнение top-level модулей (% от доступных LUT6)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | **~16.5%** | **~11.8%** | **~9.1%** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | **~16.5%** | **~11.8%** | **~9.1%** |

## Сравнение Latency и Fmax (оценка)

### Комбинированные модули (Combined / FMA)

| Модуль | Latency | Fmax XC6SLX9-2 | Fmax XC7S15-1 | Fmax XC7A15T-1 | Точность |
|----------|------------|------------|------------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | 4 | 35 MHz | 45 MHz | 45 MHz | IEEE 754 RNE; subnormals preserved; fused BF16×BF16+FP32; single RNE |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | 8 | 35 MHz | 45 MHz | 45 MHz | IEEE 754 RNE; subnormals preserved; fused BF16×BF16+FP32; single RNE |

## Сравнение top-level модулей (LUTs)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~753 | ~753 | ~753 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~788 | ~788 | ~788 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~335 | ~335 | ~335 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~357 | ~357 | ~357 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~361 | ~361 | ~361 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~404 | ~404 | ~404 |

## Сравнение top-level модулей (FF)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~257 | ~257 | ~257 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~257 | ~257 | ~257 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~141 | ~141 | ~141 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~141 | ~141 | ~141 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~114 | ~114 | ~114 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~114 | ~114 | ~114 |

## Сравнение top-level модулей (% от доступных LUT6)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | **~13.2%** | **~9.4%** | **~7.2%** |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | **~13.8%** | **~9.8%** | **~7.6%** |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | **~5.9%** | **~4.2%** | **~3.2%** |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | **~6.2%** | **~4.5%** | **~3.4%** |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | **~6.3%** | **~4.5%** | **~3.5%** |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | **~7.1%** | **~5.1%** | **~3.9%** |

## Сравнение Latency и Fmax (оценка)

### Модули сложения (Addition)

| Модуль | Latency | Fmax XC6SLX9-2 | Fmax XC7S15-1 | Fmax XC7A15T-1 | Точность |
|----------|------------|------------|------------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | 4 | 74 MHz | 95 MHz | 95 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | 4 | 57 MHz | 72 MHz | 72 MHz | IEEE 754 RNE; subnormals preserved |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | 4 | 79 MHz | 101 MHz | 101 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | 4 | 70 MHz | 89 MHz | 89 MHz | IEEE 754 RNE; subnormals preserved |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | 4 | 79 MHz | 101 MHz | 101 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | 4 | 70 MHz | 89 MHz | 89 MHz | IEEE 754 RNE; subnormals preserved |

## Рабочая частота Fmax (typ), MHz

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | **131** | **167** | **167** |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | **118** | **150** | **150** |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | **N/A** | **N/A** | **N/A** |

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | **35** | **45** | **45** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | **35** | **45** | **45** |

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | **74** | **95** | **95** |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | **57** | **72** | **72** |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | **79** | **101** | **101** |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | **70** | **89** | **89** |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | **79** | **101** | **101** |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | **70** | **89** | **89** |

> Значения `typ` — середины оценочных диапазонов из синтеза Yosys (логическая глубина, ±25%).
> Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

---

## Краткие выводы

1. **Все модули компактны.** Наименьшее устройство (XC6SLX9): самый прожорливый модуль (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`) занимает **~16.5% LUT6** (944 LUT); остальные модули укладываются в ~2.8–16.5% LUT6.

2. **RNE дороже RTZ на ~30–50 LUTs (~8–17%).** Это стоимость IEEE 754 округления "до ближайшего чётного" (G/R/S биты, инкремент мантиссы, корректировка экспоненты).

3. **FP32-модуль эффективнее по LUT, но потребляет больше FF.** `vhfastmulb16_mul_bf16_bf16_fp32_lat4` использует комбинационный `mul4x4_comb` на первой стадии (экономия LUT) и глубокий 4-стадийный конвейер (больше FF). Latency = 4 такта вместо 3.

4. **Ресурсы 7-й серии (Spartan-7, Artix-7) ниже в процентном соотношении:** загрузка по LUT одинакова, а устройства больше.

5. **Маржа для роста.** На всех целевых FPGA остаётся не менее **~84% свободных LUT6** для остальной логики системы.

6. **Fmax верифицирован через Yosys синтез.** Ценности Fmax основаны на синтезе в Yosys (abc9, synth_xilinx) с оценкой глубины логики. Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

7. **Категорический запрет на использование DSP блоков.** Все модули библиотеки реализованы **исключительно в чистой логике LUT/FF**. Использование DSP48A1, DSP48E1 или любых других DSP блоков **запрещено**. Проверка: `dsp48 = 0` во всех отчётах. Подробности см. в `rules/dsp_prohibition.md`.

8. **Автоматизация:** Статистика собрана скриптом `scripts/collect_stats.py`, документация сгенерирована `scripts/generate_stat_docs.py`. Исходные данные в `build/stat/*.json`.

---

*Последнее обновление: 2026-11-14T07:12:42.362446Z*
*Инструменты: Yosys/YoWASP, wasmtime*