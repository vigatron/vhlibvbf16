# Статистика реализации подмодулей на Xilinx XC6SLX9-144

## Спецификация FPGA (напоминание)

| Параметр | Значение |
|----------|----------|
| **LUTs** | 5,792 |
| **FF** | 11,584 |
| **DSP48A1** | 16 |
| **Block RAM** | 32 × 18Kb |

---

## Подмодули (Bottom-up)

### 1. `vhfastmulb16_mul4x4` — 4×4 multiplier (CSA tree)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **170** | 2.9% |
| FF | 8 | 0.1% |
| DSP48A1 | 0 | — |
| Latency | 1 cycle | — |
| Max Freq | ~350 MHz | — |

#### Архитектура:
- 4 partial products (10-bit each) → 40 LUTs
- CSA Level 1 (3:2) → 50 LUTs
- CSA Level 2 (3:2) → 50 LUTs
- Final CPA (10-bit) → 30 LUTs

---

### 2. `vhfastmulb16_mul8x8` — 8×8 multiplier (4× mul4x4)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **680** | 11.7% |
| FF | 320 | 2.8% |
| DSP48A1 | 0 | — |
| Latency | 2 cycles | — |
| Max Freq | ~250 MHz | — |

#### Архитектура:
- 4× `mul4x4` = 4 × 170 = **680 LUTs**
- 16-bit CPA (final sum) = ~120 LUTs (включено выше)
- Pipeline reg между mul4x4 и CPA = 320 FF

> **Примечание:** Можно заменить на 1× DSP48A1 (18×18) → экономия ~680 LUTs, но текущая реализация — pure LUT.

---

### 3. `vhfastmulb16_add8x8_lat2` — Exponent adder (a + b - 127)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **95** | 1.6% |
| FF | 40 | 0.3% |
| Latency | 2 cycles | — |
| Max Freq | ~400 MHz | — |

#### Архитектура:
- Stage 1: 9-bit adder (a + b) = 45 LUTs
- Stage 2: 9-bit subtractor (-127) = 40 LUTs
- Pipeline regs = 18 FF

---

### 4. `vhfastmulb16_sign` — Sign pipeline (XOR × 3 stages)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **15** | 0.3% |
| FF | 6 | 0.05% |
| Latency | 1/2/3 cycles | — |
| Max Freq | >500 MHz | — |

---

### 5. `vhfastmulb16_flags_lat1` — Flags (latency 1)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **90** | 1.6% |
| FF | 40 | 0.3% |
| Latency | 1 cycle | — |

#### Детали:
- nibble comparisons (exp_h0, exp_l0, exp_h1, exp_l1, frc_h0, frc_l0) = 40 LUTs
- flag logic (AND/OR/NOT) = 30 LUTs
- Output regs = 5 FF

---

### 6. `vhfastmulb16_flags_lat2` — Flags (latency 2)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **95** | 1.6% |
| FF | 40 | 0.3% |
| Latency | 2 cycles | — |

#### Разница с lat1:
- Stage 1 regs (exp_h0/h1/l0/l1, frc_h0/l0) = 20 FF
- Stage 2 flag logic = 35 LUTs

---

### 7. `vhfastmulb16_except_lat2` — Exception handling (latency 2)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **420** | 7.3% |
| FF | 180 | 1.6% |
| Latency | 2 cycles | — |

#### Архитектура:
- 2× `flags_lat1` = 2 × 90 = 180 LUTs
- Classification logic (NaN/Inf/Zero priority) = 80 LUTs
- NaN payload mux (A > B) = 40 LUTs
- Pipeline regs (a_d1, b_d1, en_d1) = 48 FF
- Output regs = 5 FF

---

### 8. `vhfastmulb16_except_lat3` — Exception handling (latency 3)

| Ресурс | Оценка | % LUTs |
|--------|--------|--------|
| **LUTs** | **430** | 7.4% |
| FF | 200 | 1.7% |
| Latency | 3 cycles | — |

#### Разница с lat2:
- 2× `flags_lat2` = 2 × 95 = 190 LUTs (+10)
- Deeper pipeline regs (a_d1/d2, b_d1/d2) = 96 FF (+16)

---

## Сводная таблица всех модулей

| Модуль | LUTs | FF | Latency | % LUTs (от 5,792) |
|--------|------|-----|---------|-------------------|
| **mul4x4** | 170 | 8 | 1 | 2.9% |
| **mul8x8** | 680 | 320 | 2 | 11.7% |
| **add8x8_lat2** | 95 | 40 | 2 | 1.6% |
| **sign** | 15 | 6 | 1/2/3 | 0.3% |
| **flags_lat1** | 90 | 40 | 1 | 1.6% |
| **flags_lat2** | 95 | 40 | 2 | 1.6% |
| **except_lat2** | 420 | 180 | 2 | 7.3% |
| **except_lat3** | 430 | 200 | 3 | 7.4% |
| **ИТОГО (все уникальные)** | **~2,095** | **~834** | — | **36%** |

> Примечание: `mul8x8` включает 4× `mul4x4`, поэтому общая сумма < суммы частей.

---

## Топ-уровневые модули (включают всё выше)

| Top модуль | LUTs | FF | % LUTs | Состав |
|------------|------|-----|--------|--------|
| `vhfastmulb16_rtz_lat3` | 1,850 | 1,200 | 32% | mul8x8 + add8x8_lat2 + sign + except_lat2 + flags_lat1×2 + glue |
| `vhfastmulb16_rne_lat3` | 2,150 | 1,300 | 37% | RTZ + RNE rounding logic |

---

## Потенциал оптимизации

### 1. Использование DSP48A1 для mul8x8
| Подход | LUTs | DSP48A1 | Экономия |
|--------|------|---------|----------|
| Текущий (LUT-only) | 680 | 0 | — |
| 1× DSP48A1 (18×18) | ~120 | 1 | **560 LUTs (82%)** |
| 1× DSP48A1 + pre-add | ~80 | 1 | **600 LUTs (88%)** |

> Spartan-6 имеет **16 DSP48A1**. Использование 1 для mul8x8 разумно.

### 2. Объединение flags_lat1 + except_lat2
- Сейчас: 90 + 90 + 80 + 40 = 300 LUTs для flags+classification
- Объединённое: ~200 LUTs
- **Экономия: ~100 LUTs**

### 3. Замена flags_lat1 на комбинационную (latency 0)
- Если latency 1 не требуется: -90 LUTs, -40 FF на экземпляр
- Риск: увеличение критического пути top-level

---

## Рекомендации по внедрению в XC6SLX9

| Приоритет | Действие | Эффект |
|-----------|----------|--------|
| 1 | Перенести `mul8x8` на DSP48A1 | -560 LUTs, +1 DSP |
| 2 | Объединить `flags_lat1` + `except_lat2` классификацию | -100 LUTs |
| 3 | Рассмотреть `flags_lat1` → комбинационную (если timing позволяет) | -180 LUTs |

**После оптимизаций RTZ: ~1,100 LUTs (19%) — очень комфортно для XC6SLX9.**