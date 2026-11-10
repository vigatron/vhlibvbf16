# Статистика подмодулей на Xilinx Spartan-7 (XC7S15-1, XC7S15-2)

## Спецификация целевых FPGA

| Параметр | XC7S15-1 | XC7S15-2 |
|----------|----------|----------|
| **Device** | XC7S15 (Spartan-7) | XC7S15 (Spartan-7) |
| **LUTs (6-input / LUT6)** | **8,000** | **8,000** |
| **Flip-Flops** | 16,000 | 16,000 |
| **DSP48E1** | 20 | 20 |
| **Block RAM (36Kb)** | 10 (360 Kb) | 10 (360 Kb) |

---

> **Важно:** Все цифры — оценки на основе ручного подсчёта по RTL-коду (погрешность ±20–25%).

#### Правила подсчёта LUT6:
- любая булева функция от ≤6 входов = 1 LUT6;
- n-битный сумматор/вычитатель с carry chain (CARRY4) = n LUTs;
- 2:1 мультиплексор шириной n бит = n LUTs;
- сравнение ниббла с константой = 1 LUT.

---

## Подмодули (Bottom-up)

### 1. `vhfastmulb16_mul4x4` — 4×4 multiplier (CSA tree, latency 1)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~45** | **0.6%** |
| FF | 8 | 0.05% |
| Latency | 1 cycle | — |

---

### 2. `vhfastmulb16_mul4x4_lat2` — 4×4 multiplier, 2-stage pipeline (latency 2) [НОВЫЙ]

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~50** | **0.6%** |
| FF | 37 | 0.2% |
| Latency | 2 cycles | — |

---

### 3. `vhfastmulb16_mul4x4_comb` — 4×4 multiplier, purely combinational (latency 0) [НОВЫЙ]

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~45** | **0.6%** |
| FF | 0 | 0% |
| Latency | 0 (comb) | — |

---

### 4. `vhfastmulb16_mul8x8` — 8×8 multiplier (4× mul4x4 + CSA tree, latency 2) [ОБНОВЛЁННЫЙ]

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~208** | **2.6%** |
| FF | 48 | 0.3% |
| Latency | 2 cycles | — |

---

### 5. `vhfastmulb16_mul8x8_lat3` — 8×8 multiplier (4× mul4x4_lat2, latency 3) [НОВЫЙ]

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~230** | **2.9%** |
| FF | 160 | 1.0% |
| Latency | 3 cycles | — |

---

### 6. `vhfastmulb16_add8x8_lat2` — Exponent adder (a + b - 127, latency 2)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~18** | **0.2%** |
| FF | 19 | 0.1% |
| Latency | 2 cycles | — |

---

### 7. `vhfastmulb16_add8x8_branch` (`vhfastmulb16_add8x8`) (latency 2)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~18** | **0.2%** |
| FF | 19 | 0.1% |
| Latency | 2 cycles | — |

---

### 8. `vhfastmulb16_sign` — Sign pipeline (XOR × 3 stages)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~1** | **0.01%** |
| FF | 3 | 0.02% |
| Latency | 1/2/3 cycles | — |

---

### 9. `vhfastmulb16_flags_lat1` — Flags (latency 1)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~11** | **0.1%** |
| FF | 5 | 0.03% |
| Latency | 1 cycle | — |

---

### 10. `vhfastmulb16_flags_lat2` — Flags (latency 2)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~11** | **0.1%** |
| FF | 11 | 0.07% |
| Latency | 2 cycles | — |

---

### 11. `vhfastmulb16_except_lat2` — Exception handling (latency 2)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~54** | **0.7%** |
| FF | 63 | 0.4% |
| Latency | 2 cycles | — |

---

### 12. `vhfastmulb16_except_lat3` — Exception handling (latency 3)

| Ресурс | XC7S15 | % LUTs |
|--------|--------|--------|
| **LUTs** | **~52** | **0.7%** |
| FF | 108 | 0.7% |
| Latency | 3 cycles | — |

---

## Сводная таблица (XC7S15)

| Модуль | LUTs | FF | Latency | % LUTs (от 8,000) |
|--------|------|-----|---------|-------------------|
| mul4x4 | ~45 | 8 | 1 | 0.6% |
| mul4x4_lat2 | ~50 | 37 | 2 | 0.6% |
| mul4x4_comb | ~45 | 0 | 0 | 0.6% |
| mul8x8 | ~208 | 48 | 2 | 2.6% |
| mul8x8_lat3 | ~230 | 160 | 3 | 2.9% |
| add8x8_lat2 | ~18 | 19 | 2 | 0.2% |
| add8x8 (branch) | ~18 | 19 | 2 | 0.2% |
| sign | ~1 | 3 | 1/2/3 | 0.01% |
| flags_lat1 | ~11 | 5 | 1 | 0.1% |
| flags_lat2 | ~11 | 11 | 2 | 0.1% |
| except_lat2 | ~54 | 63 | 2 | 0.7% |
| except_lat3 | ~52 | 108 | 3 | 0.7% |
| **ИТОГО (уникальные)** | **~626** | **~420** | — | **7.8%** |