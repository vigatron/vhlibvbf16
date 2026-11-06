# Статистика реализации на Xilinx XC6SLX9-144 (Spartan-6 LX9)

## Спецификация целевого FPGA

| Параметр | Значение |
|----------|----------|
| **Device** | XC6SLX9 (Spartan-6 LX9) |
| **Package** | CSG144 / CPG144 |
| **Logic Cells** | 9,152 |
| **Slices** | 1,448 |
| **LUTs (4-input)** | **5,792** (1,448 × 4) |
| **Flip-Flops** | 11,584 |
| **Block RAM (18Kb)** | 32 (576 Kb total) |
| **DSP48A1** | 16 |
| **Max Clock (typical)** | ~200-300 MHz для простых путей |

---

## Top-level модули

### 1. `vhfastmulb16_rtz_lat3` (RTZ — Round Toward Zero)

| Ресурс | Оценка | % от доступных |
|--------|--------|----------------|
| **LUTs** | ~1,850 | **32%** |
| FF (регистры) | ~1,200 | 10% |
| DSP48A1 | 0 | 0% |
| Block RAM | 0 | 0% |
| **Макс. частота** | ~180 MHz | — |

#### Распределение по подмодулям:

| Подмодуль | LUTs | FF | Примечание |
|-----------|------|-----|------------|
| `mul8x8` (4× `mul4x4` + сумматор) | 680 | 320 | 4× CSA + 16-bit CPA |
| `add8x8_lat2` | 95 | 40 | 2-stage pipeline |
| `sign` | 15 | 6 | 3-stage XOR pipeline |
| `except_lat2` | 420 | 180 | 2× `flags_lat1` + классификация |
| `flags_lat1` (×2) | 180 | 80 | nibble comparisons |
| **Top-level glue** (mux, norm, round) | 460 | 574 | exp_norm, man_norm, c_next mux |
| **Pipeline registers** (drain, en_pipe) | — | ~100 | en_d1, en_d2, a_eff/b_eff delay |
| **ИТОГО** | **~1,850** | **~1,200** | |

---

### 2. `vhfastmulb16_rne_lat3` (RNE — Round to Nearest Even)

| Ресурс | Оценка | % от доступных |
|--------|--------|----------------|
| **LUTs** | ~2,150 | **37%** |
| FF (регистры) | ~1,300 | 11% |
| DSP48A1 | 0 | 0% |
| Block RAM | 0 | 0% |
| **Макс. частота** | ~160 MHz | — |

#### Разница с RTZ (+300 LUTs):

| Компонент | Доп. LUTs | Причина |
|-----------|-----------|---------|
| RNE rounding logic (G/R/S/LSB) | +120 | `always_comb` с ripple-carry инкрементом |
| Guard/Round/Sticky extract | +40 | битовые операции |
| Rounding carry into exponent | +50 | exp_norm_pre + carry adder |
| Man_final mux | +40 | carry-dependent selection |
| Pipeline regs для rounding | +50 | синхронизация с except_lat2 |
| **ИТОГО** | **+300** | |

#### Распределение:

| Подмодуль | LUTs | FF |
|-----------|------|-----|
| `mul8x8` | 680 | 320 |
| `add8x8_lat2` | 95 | 40 |
| `sign` | 15 | 6 |
| `except_lat2` | 420 | 180 |
| `flags_lat1` (×2) | 180 | 80 |
| **RNE rounding** (always_comb) | 250 | — |
| **Top-level glue** | 510 | 674 |
| **Pipeline registers** | — | ~100 |
| **ИТОГО** | **~2,150** | **~1,300** |

---

## Сравнение RTZ vs RNE

| Метрика | RTZ | RNE | Overhead |
|---------|-----|-----|----------|
| LUTs | 1,850 | 2,150 | **+16%** |
| FF | 1,200 | 1,300 | **+8%** |
| Max Freq | ~180 MHz | ~160 MHz | -11% |
| Latency | 3 cycles | 3 cycles | 0 |
| Точность | Truncation | IEEE 754 RNE | — |

---

## Критический путь (Timing)

### RTZ:
```
mul4x4 (CSA) → mul8x8 CPA → exp_sum + man_msb → c_next mux → output reg
```
~5.5 ns (180 MHz)

### RNE:
```
mul4x4 (CSA) → mul8x8 CPA → exp_sum + man_msb → RNE rounding (G/R/S/LSB) → c_next mux → output reg
```
~6.2 ns (160 MHz)

---

## Рекомендации по оптимизации

| Оптимизация | Экономия LUTs | Сложность |
|-------------|---------------|-----------|
| Использовать DSP48A1 для mul8x8 | -400 LUTs | Требует переработки mul4x4 |
| Заменить `flags_lat1` на комбинационную | -180 LUTs | Потеря latency 1 |
| Объединить `except_lat2` + `flags_lat1` | -100 LUTs | Рефакторинг |
| **Потенциальный итог RTZ** | **~1,100 LUTs (19%)** | |

---

## Вывод

| Модуль | LUTs | % от XC6SLX9 | Рекомендация |
|--------|------|--------------|--------------|
| **RTZ** | 1,850 (32%) | ✅ Помещается с запасом | Для production |
| **RNE** | 2,150 (37%) | ✅ Помещается | Если нужна IEEE 754 точность |

Оба модуля комфортно помещаются в **XC6SLX9** с запасом ~60-65% LUTs для остальной логики системы.