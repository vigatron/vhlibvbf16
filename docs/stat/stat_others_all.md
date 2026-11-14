# Сравнительная статистика всех подмодулей на всех FPGA

Источник данных: `docs/stat/stat_others_spartan6.md`, `docs/stat/stat_others_spartan7.md`, `docs/stat/stat_others_artix7.md` (генерируются `scripts/generate_stat_others_docs.py` из `build/stat_others/*.json`).
LUT — оценка по числу вентилей до ABC9 (YoWASP WASM не выполняет yosys-abc), погрешность ±20–25%. Fmax — ручная калибровка типовых значений, не измерение post-PAR.

---

## Ресурсы целевых FPGA

| Device | Семейство | LUT6 | FF | DSP | BRAM |
|--------|-----------|------|-----|-----|------|
| XC6SLX9-2 | Spartan-6 | 5,720 | 11,440 | 16 × DSP48A1 (не исп.) | 32 × 18Kb (не исп.) |
| XC7S15-1 | Spartan-7 | 8,000 | 16,000 | 20 × DSP48E1 (не исп.) | 10 × 36Kb (не исп.) |
| XC7A15T-1 | Artix-7 | 10,400 | 20,800 | 45 × DSP48E1 (не исп.) | 25 × 36Kb (не исп.) |

---

## Сравнение подмодулей (LUTs)

### Подмодули (Bottom-up)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul4x4` | ~24 | ~24 | ~24 |
| `vhfastmulb16_mul4x4_lat2` | ~24 | ~24 | ~24 |
| `vhfastmulb16_mul4x4_comb` | ~24 | ~24 | ~24 |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | ~129 | ~129 | ~129 |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | ~130 | ~130 | ~130 |
| `vhfastmulb16_add8x8_lat2` | ~4 | ~4 | ~4 |
| `vhfastmulb16_sign` | ~0 | ~0 | ~0 |
| `vhfastmulb16_flags_lat1` | ~16 | ~16 | ~16 |
| `vhfastmulb16_flags_lat2` | ~16 | ~16 | ~16 |
| `vhfastmulb16_except_lat2` | ~40 | ~40 | ~40 |
| `vhfastmulb16_except_lat3` | ~40 | ~40 | ~40 |

## Сравнение подмодулей (FF)

### Подмодули (Bottom-up)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul4x4` | 8 | 8 | 8 |
| `vhfastmulb16_mul4x4_lat2` | 24 | 24 | 24 |
| `vhfastmulb16_mul4x4_comb` | 0 | 0 | 0 |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | 48 | 48 | 48 |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | 101 | 101 | 101 |
| `vhfastmulb16_add8x8_lat2` | 19 | 19 | 19 |
| `vhfastmulb16_sign` | 3 | 3 | 3 |
| `vhfastmulb16_flags_lat1` | 5 | 5 | 5 |
| `vhfastmulb16_flags_lat2` | 11 | 11 | 11 |
| `vhfastmulb16_except_lat2` | 32 | 32 | 32 |
| `vhfastmulb16_except_lat3` | 57 | 57 | 57 |

## Сравнение подмодулей (% от доступных LUT6)

### Подмодули (Bottom-up)

| Модуль | XC6SLX9-2 (5,720) | XC7S15-1 (8,000) | XC7A15T-1 (10,400) |
|--------|----------|----------|----------|
| `vhfastmulb16_mul4x4` | **~0.4%** | **~0.3%** | **~0.2%** |
| `vhfastmulb16_mul4x4_lat2` | **~0.4%** | **~0.3%** | **~0.2%** |
| `vhfastmulb16_mul4x4_comb` | **~0.4%** | **~0.3%** | **~0.2%** |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | **~2.3%** | **~1.6%** | **~1.2%** |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | **~2.3%** | **~1.6%** | **~1.2%** |
| `vhfastmulb16_add8x8_lat2` | **~0.1%** | **~0.1%** | **~0.0%** |
| `vhfastmulb16_sign` | **~0.0%** | **~0.0%** | **~0.0%** |
| `vhfastmulb16_flags_lat1` | **~0.3%** | **~0.2%** | **~0.2%** |
| `vhfastmulb16_flags_lat2` | **~0.3%** | **~0.2%** | **~0.2%** |
| `vhfastmulb16_except_lat2` | **~0.7%** | **~0.5%** | **~0.4%** |
| `vhfastmulb16_except_lat3` | **~0.7%** | **~0.5%** | **~0.4%** |

## Сравнение Latency и Fmax (оценка)

### Подмодули (Bottom-up)

| Модуль | Latency | Fmax XC6SLX9-2 (typ) | Fmax XC7S15-1 (typ) | Fmax XC7A15T-1 (typ) | Точность |
|--------|---------|---------------------|---------------------|---------------------|----------|
| `vhfastmulb16_mul4x4` | 1 | 280 MHz | 320 MHz | 380 MHz | exact |
| `vhfastmulb16_mul4x4_lat2` | 2 | 340 MHz | 400 MHz | 420 MHz | exact |
| `vhfastmulb16_mul4x4_comb` | 0 | 320 MHz | 360 MHz | 380 MHz | exact |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | 2 | 230 MHz | 270 MHz | 290 MHz | exact |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | 3 | 290 MHz | 330 MHz | 350 MHz | exact |
| `vhfastmulb16_add8x8_lat2` | 2 | 400 MHz | 450 MHz | 480 MHz | exact |
| `vhfastmulb16_sign` | 3 | 500 MHz | 600 MHz | 620 MHz | exact |
| `vhfastmulb16_flags_lat1` | 1 | 400 MHz | 450 MHz | 480 MHz | exact |
| `vhfastmulb16_flags_lat2` | 2 | 450 MHz | 500 MHz | 540 MHz | exact |
| `vhfastmulb16_except_lat2` | 2 | 320 MHz | 360 MHz | 380 MHz | exact |
| `vhfastmulb16_except_lat3` | 3 | 360 MHz | 400 MHz | 420 MHz | exact |

## Рабочая частота Fmax (typ), MHz

### Подмодули (Bottom-up)

| Модуль | XC6SLX9-2 | XC7S15-1 | XC7A15T-1 |
|--------|----------|----------|----------|
| `vhfastmulb16_mul4x4` | **280** | **320** | **380** |
| `vhfastmulb16_mul4x4_lat2` | **340** | **400** | **420** |
| `vhfastmulb16_mul4x4_comb` | **320** | **360** | **380** |
| `vhfastmulb16_mul_u8_u8_u16_lat2` | **230** | **270** | **290** |
| `vhfastmulb16_mul_u8_u8_u16_lat3` | **290** | **330** | **350** |
| `vhfastmulb16_add8x8_lat2` | **400** | **450** | **480** |
| `vhfastmulb16_sign` | **500** | **600** | **620** |
| `vhfastmulb16_flags_lat1` | **400** | **450** | **480** |
| `vhfastmulb16_flags_lat2` | **450** | **500** | **540** |
| `vhfastmulb16_except_lat2` | **320** | **360** | **380** |
| `vhfastmulb16_except_lat3` | **360** | **400** | **420** |

> Значения `typ` — ручная калибровка (см. `scripts/modules_config.py`), не измерение post-PAR.
> Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

---

## Краткие выводы

1. **Все модули компактны.** Наименьшее устройство (XC6SLX9): самый прожорливый модуль (`vhfastmulb16_mul_u8_u8_u16_lat3`) занимает **~2.3% LUT6** (~130 LUT); самый компактный (`vhfastmulb16_sign`) — ~0.0% LUT6.

2. **`mul_u8_u8_u16_lat2` (latency 2) ~129 LUT, `mul_u8_u8_u16_lat3` (latency 3) ~130 LUT.** Альтернативные 8×8 реализации; `lat3` построен на `mul4x4_lat2`.

3. **Суммарно все подмодули ~447 LUT (~7.8% LUT6 XC6SLX9)** — каждый подмодуль мал; основной вклад дают множители 8×8 и `except_lat*`.

4. **Ресурсы 7-й серии (Spartan-7, Artix-7) ниже в процентном соотношении:** загрузка по LUT одинакова, а устройства больше.

5. **Маржа.** Все подмодули суммарно занимают **~7.8% LUT6** XC6SLX9 — даже с учётом дублирования инстансов место остаётся.

6. **LUT — оценка, Fmax — калибровка.** LUT6 получено делением числа вентилей на 2.5 до ABC9 (YoWASP WASM не выполняет yosys-abc; погрешность ±20–25%). Fmax — ручные типовые значения (`scripts/modules_config.py`), не измерение post-PAR. Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.

7. **Категорический запрет на использование DSP блоков.** Все модули библиотеки реализованы **исключительно в чистой логике LUT/FF**. Использование DSP48A1, DSP48E1 или любых других DSP блоков **запрещено**. Проверка: `dsp48 = 0` во всех отчётах. Подробности см. в `rules/dsp_prohibition.md`.

8. **Автоматизация:** Статистика собрана скриптом `scripts/collect_stats.py`, документация сгенерирована `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py`. Исходные данные в `build/stat*.json`.

---

*Последнее обновление: 2026-11-14T07:55:40.264795Z*
*Инструменты: Yosys/YoWASP, wasmtime*