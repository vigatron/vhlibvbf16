# Сравнительная статистика всех top модулей на всех FPGA

Источник данных: `docs/stat/stat_top_spartan6.md`, `docs/stat/stat_top_spartan7.md`, `docs/stat/stat_top_artix7.md` (генерируются `scripts/generate_stat_docs.py` из `build/stat/*.json`).
LUT — оценка по числу вентилей до ABC9 (YoWASP WASM не выполняет yosys-abc), погрешность ±20–25%. Fmax — ручная калибровка типовых значений, не измерение post-PAR.
Есть пробные post-PAR измерения трёх FMA (lat8 rne/fst и lat4 fst) на Spartan-6 (плата CMB32F407HDMIR3, XC6SLX9-2TQG144, ISE 14.7) — см. `stat_top_spartan6.md` и папку `docs/benchmarks/`. Измеренные значения приведены в колонке «Fmax post-PAR, MHz»; Fmax typ — ручная калибровка, не измерение.
- `log_fma_fst_lat8` (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8`, FAST/RTZ/FTZ): min period **5.243 ns (≈190.7 MHz)**, 0 ошибок тайминга, констрейнт 6 ns (typ manual 200 MHz).
- `log_fma_rne_lat8` (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8`, RNE): min period **7.414 ns (≈134.9 MHz)**, 0 ошибок тайминга (237 196 paths / 4 753 endpoints), констрейнт 8 ns (typ manual 170 MHz).
- `log_fma_fst_lat4` (`vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4`, FAST/RTZ/FTZ, lat=4): min period **7.987 ns (≈125.2 MHz)**, 0 ошибок тайминга, констрейнт 10 ns; внутренний путь DUT `grp_mul` 9.357 ns (≈106.9 MHz) (typ manual 170 MHz).

---

## Ресурсы целевых FPGA

| Device | Семейство | LUT6 | FF | DSP | BRAM |
|--------|-----------|------|-----|-----|------|
| XC6SLX9-2 | Spartan-6 | 5,720 | 11,440 | 16 × DSP48A1 (исключение: `vhfma002`) | 32 × 18Kb (не исп.) |
| XC7S15-1 | Spartan-7 | 8,000 | 16,000 | 20 × DSP48E1 (исключение: `vhfma002`) | 10 × 36Kb (не исп.) |
| XC7A15T-1 | Artix-7 | 10,400 | 20,800 | 45 × DSP48E1 (исключение: `vhfma002`) | 25 × 36Kb (не исп.) |

---

## Сравнение top-level модулей (LUTs)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | ~252 | ~252 | ~252 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | ~259 | ~259 | ~259 |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | ~230 | ~230 | ~230 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | ~485 | ~485 | ~485 |

## Сравнение top-level модулей (FF)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | 106 | 106 | 106 |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | 117 | 117 | 117 |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | 61 | 61 | 61 |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | 170 | 170 | 170 |

## Сравнение top-level модулей (% от доступных LUT6)

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | **~4.4%** | **~3.1%** | **~2.4%** |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | **~4.5%** | **~3.2%** | **~2.5%** |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | **~4.0%** | **~2.9%** | **~2.2%** |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | **~8.5%** | **~6.1%** | **~4.7%** |

## Сравнение Latency и Fmax (оценка)

### Модули умножения (Multiplication)

| Модуль | Latency | Fmax XC6SLX9-2 (typ) | Fmax XC7S15-1 (typ) | Fmax XC7A15T-1 (typ) | Точность |
|--------|---------|---------------------|---------------------|---------------------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | 3 | 175 MHz | 205 MHz | 230 MHz | truncation (RTZ); FTZ |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | 3 | 155 MHz | 180 MHz | 210 MHz | IEEE 754 RNE; FTZ |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | 3 | 200 MHz | 230 MHz | 255 MHz | truncation (RTZ); FTZ |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | 4 | 145 MHz | 165 MHz | 190 MHz | exact; subnormals preserved |

## Сравнение top-level модулей (LUTs)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | ~1011 | ~1011 | ~1011 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | ~1013 | ~1013 | ~1013 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` | ~667 | ~667 | ~667 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | ~667 | ~667 | ~667 |
| `vhfma001` | ~1148 | ~1148 | ~1148 |
| `vhfma002` | ~1016 | ~1016 | ~1016 |

## Сравнение top-level модулей (FF)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | 246 | 246 | 246 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | 562 | 562 | 562 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` | 234 | 234 | 234 |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | 528 | 528 | 528 |
| `vhfma001` | 570 | 570 | 570 |
| `vhfma002` | 510 | 510 | 510 |

## Сравнение top-level модулей (% от доступных LUT6)

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | **~17.7%** | **~12.6%** | **~9.7%** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | **~17.7%** | **~12.7%** | **~9.7%** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` | **~11.7%** | **~8.3%** | **~6.4%** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | **~11.7%** | **~8.3%** | **~6.4%** |
| `vhfma001` | **~20.1%** | **~14.3%** | **~11.0%** |
| `vhfma002` | **~17.8%** | **~12.7%** | **~9.8%** |

## Сравнение Latency и Fmax (оценка)

### Комбинированные модули (Combined / FMA)

| Модуль | Latency | Fmax XC6SLX9-2 (typ) | Fmax XC7S15-1 (typ) | Fmax XC7A15T-1 (typ) | Точность |
|--------|---------|---------------------|---------------------|---------------------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | 4 | 100 MHz | 125 MHz | 145 MHz | IEEE 754 RNE; subnormals preserved; fused BF16×BF16+FP32; single RNE |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | 8 | 170 MHz | 200 MHz | 220 MHz | IEEE 754 RNE; subnormals preserved; fused BF16×BF16+FP32; single RNE |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` | 4 | 170 MHz | 200 MHz | 220 MHz | truncation (RTZ); FTZ; fused BF16×BF16+FP32; single RTZ |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | 8 | 200 MHz | 230 MHz | 250 MHz | truncation (RTZ); FTZ; fused BF16×BF16+FP32; single RTZ |
| `vhfma001` | 8 | 180 MHz | 210 MHz | 230 MHz | IEEE 754 RNE; subnormals preserved |
| `vhfma002` | 8 | 180 MHz | 210 MHz | 230 MHz | IEEE 754 RNE; subnormals preserved |

## Сравнение top-level модулей (LUTs)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | ~746 | ~746 | ~746 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | ~774 | ~774 | ~774 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | ~329 | ~329 | ~329 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | ~348 | ~348 | ~348 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | ~355 | ~355 | ~355 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | ~395 | ~395 | ~395 |

## Сравнение top-level модулей (FF)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | 261 | 261 | 261 |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | 261 | 261 | 261 |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | 145 | 145 | 145 |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | 145 | 145 | 145 |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | 118 | 118 | 118 |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | 118 | 118 | 118 |

## Сравнение top-level модулей (% от доступных LUT6)

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | **~13.0%** | **~9.3%** | **~7.2%** |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | **~13.5%** | **~9.7%** | **~7.4%** |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | **~5.8%** | **~4.1%** | **~3.2%** |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | **~6.1%** | **~4.3%** | **~3.3%** |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | **~6.2%** | **~4.4%** | **~3.4%** |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | **~6.9%** | **~4.9%** | **~3.8%** |

## Сравнение Latency и Fmax (оценка)

### Модули сложения (Addition)

| Модуль | Latency | Fmax XC6SLX9-2 (typ) | Fmax XC7S15-1 (typ) | Fmax XC7A15T-1 (typ) | Точность |
|--------|---------|---------------------|---------------------|---------------------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | 4 | 120 MHz | 140 MHz | 160 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | 4 | 110 MHz | 130 MHz | 150 MHz | IEEE 754 RNE; subnormals preserved |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | 4 | 140 MHz | 170 MHz | 200 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | 4 | 130 MHz | 155 MHz | 185 MHz | IEEE 754 RNE; subnormals preserved |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | 4 | 135 MHz | 165 MHz | 195 MHz | truncation (RTZ); subnormals preserved |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | 4 | 125 MHz | 150 MHz | 180 MHz | IEEE 754 RNE; subnormals preserved |

## Рабочая частота Fmax (typ), MHz

### Модули умножения (Multiplication)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3` | **175** | **205** | **230** |
| `vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3` | **155** | **180** | **210** |
| `vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3` | **200** | **230** | **255** |
| `vhfastmulb16_mul_bf16_bf16_fp32_lat4` | **145** | **165** | **190** |

### Комбинированные модули (Combined / FMA)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4` | **100** | **125** | **145** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8` | **170** | **200** | **220** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4` | **170** | **200** | **220** |
| `vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8` | **200** | **230** | **250** |
| `vhfma001` | **180** | **210** | **230** |
| `vhfma002` | **180** | **210** | **230** |

### Модули сложения (Addition)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4` | **120** | **140** | **160** |
| `vhfastmulb16_add_fp32_fp32_fp32_rne_lat4` | **110** | **130** | **150** |
| `vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4` | **140** | **170** | **200** |
| `vhfastmulb16_add_fp16_fp16_fp16_rne_lat4` | **130** | **155** | **185** |
| `vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4` | **135** | **165** | **195** |
| `vhfastmulb16_add_bf16_bf16_bf16_rne_lat4` | **125** | **150** | **180** |

> Значения `typ` — ручная калибровка (см. `scripts/modules_config.py`), не измерение post-PAR.
> Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

---

## Краткие выводы

1. **Все модули компактны.** Наименьшее устройство (XC6SLX9): самый прожорливый модуль (`vhfma001`) занимает **~20.1% LUT6** (~1148 LUT); самый компактный (`vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3`) — ~4.0% LUT6.

2. **RNE дороже RTZ в среднем на ~24 LUT.** Это стоимость IEEE 754 округления "до ближайшего чётного" (G/R/S биты, инкремент мантиссы, корректировка экспоненты).

3. **FP32-модуль эффективнее по LUT, но потребляет больше FF.** `vhfastmulb16_mul_bf16_bf16_fp32_lat4` использует комбинационный `mul4x4_comb` на первой стадии (экономия LUT) и глубокий 4-стадийный конвейер (больше FF). Latency = 4 такта вместо 3.

4. **Ресурсы 7-й серии (Spartan-7, Artix-7) ниже в процентном соотношении:** загрузка по LUT одинакова, а устройства больше.

5. **Маржа для роста.** На всех целевых FPGA остаётся не менее **~80% свободных LUT6** для остальной логики системы.

6. **LUT — оценка, Fmax — калибровка.** LUT6 получено делением числа вентилей на 2.5 до ABC9 (YoWASP WASM не выполняет yosys-abc; погрешность ±20–25%). Fmax — ручные типовые значения (`scripts/modules_config.py`), не измерение post-PAR. Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

7. **Категорический запрет на использование DSP блоков — с одним исключением.** Все модули библиотеки реализованы **исключительно в чистой логике LUT/FF**. Исключение: `vhfma002` (экспериментальный DSP-вариант `vhfma001`) — ему разрешено использовать DSP48 для умножения 8×8 мантисс BF16. Проверка: `dsp48 = 0` во всех отчётах, кроме `vhfma002`. Подробности см. в разделе «DSP Block Exception (`vhfma002`)» в README.md.

8. **Автоматизация:** Статистика собрана скриптом `scripts/collect_stats.py`, документация сгенерирована `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py`. Исходные данные в `build/stat*.json`.

---

*Последнее обновление: 2026-11-21T14:24:36.033260Z*
*Инструменты: Yosys/YoWASP, wasmtime*