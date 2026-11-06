# Список исходных файлов DUT (src/*.v)

Всего модулей: **12**

| # | Файл | Модуль | Описание | Латентность |
|---|------|--------|----------|-------------|
| 1 | `vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | Умножение 4×4 бит без оператора `*` (CSA дерево) | 1 такт |
| 2 | `vhfastmulb16_mul8x8.v` | `vhfastmulb16_mul8x8` | Умножение 8×8 бит через 4× `mul4x4` | 2 такта |
| 3 | `vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Сложение экспонент + вычитание 127 (bias) | 2 такта |
| 4 | `vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Каскадный конвейер знака (XOR) с 3 выходами | 1/2/3 такта |
| 5 | `vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Флаги экспоненты/мантиссы (zero/subnormal/normal/inf/nan) | 1 такт |
| 6 | `vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Флаги экспоненты/мантиссы (2-стадийный конвейер) | 2 такта |
| 7 | `vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Обработка исключений (NaN/Inf/Zero) для latency-2 пайплайна | 2 такта |
| 8 | `vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Обработка исключений (NaN/Inf/Zero) для latency-3 пайплайна | 3 такта |
| 9 | `vhfastmulb16_rtz_lat3.v` | `vhfastmulb16_rtz_lat3` | Top-level BF16 мультипликатор с **RTZ** округлением (усечение) | 3 такта |
| 10 | `vhfastmulb16_rne_lat3.v` | `vhfastmulb16_rne_lat3` | Top-level BF16 мультипликатор с **RNE** округлением (IEEE 754) | 3 такта |
| 11 | `vhfastmulb16_lat3.v` | `vhfastmulb16_lat3` | **Устаревший** (алиас для `rtz_lat3`), оставлен для совместимости | 3 такта |
| 12 | `vhfastmulb16_add8x8.v` | `vhfastmulb16_add8x8` | **Устаревший** (алиас для `add8x8_lat2`), оставлен для совместимости | 2 такта |

---

## Зависимости между модулями

```
vhfastmulb16_rtz_lat3 / vhfastmulb16_rne_lat3
├── vhfastmulb16_add8x8_lat2
├── vhfastmulb16_mul8x8
│   └── vhfastmulb16_mul4x4 (×4)
├── vhfastmulb16_sign
├── vhfastmulb16_flags_lat1 (в except_lat2)
├── vhfastmulb16_flags_lat2 (в except_lat3)
├── vhfastmulb16_except_lat2 (в rtz/rne latency-3)
└── vhfastmulb16_except_lat3 (альтернатива для latency-3)
```

---

## Версии с разной латентностью

| Компонент | Latency 1 | Latency 2 | Latency 3 |
|-----------|-----------|-----------|-----------|
| Флаги | `flags_lat1` | `flags_lat2` | — |
| Исключения | — | `except_lat2` | `except_lat3` |
| Top-level | — | — | `rtz_lat3`, `rne_lat3` |

---

## Устаревшие файлы (для совместимости)

- `vhfastmulb16_lat3.v` → используйте `vhfastmulb16_rtz_lat3.v`
- `vhfastmulb16_add8x8.v` → используйте `vhfastmulb16_add8x8_lat2.v`

В новых проектах используйте версию с суффиксом `_latN`.