BF16 Multiplication Test Vector Table (FAST / fst_lat3, RTZ)

| No. | Operation | Input A (`inarr_a`) | Bit structure A | Input B (`inarr_b`) | Bit structure B | Output C (`outarr_c`) | Bit structure C (Expected) | Test description |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | 1.0 * 1.0 | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | 1.0 * 1.0 |
| 2 | 2.0 * 3.5 | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4060` | s:0, exp:128 (0x80), mant:96 (0x60) | `16'h40E0` | s:0, exp:129 (0x81), mant:96 (0x60) | 2.0 * 3.5 |
| 3 | -1.5 * 4.0 | `16'hBFC0` | s:1, exp:127 (0x7f), mant:64 (0x40) | `16'h4080` | s:0, exp:129 (0x81), mant:0 (0x00) | `16'hC0C0` | s:1, exp:129 (0x81), mant:64 (0x40) | -1.5 * 4.0 |
| 4 | 0.5 * 0.25 | `16'h3F00` | s:0, exp:126 (0x7e), mant:0 (0x00) | `16'h3E80` | s:0, exp:125 (0x7d), mant:0 (0x00) | `16'h3E00` | s:0, exp:124 (0x7c), mant:0 (0x00) | 0.5 * 0.25 |
| 5 | 128.0 * 0.0078125 | `16'h4300` | s:0, exp:134 (0x86), mant:0 (0x00) | `16'h3C00` | s:0, exp:120 (0x78), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | 128.0 * 0.0078125 |
| 6 | 3.140625 * 2.0 | `16'h4049` | s:0, exp:128 (0x80), mant:73 (0x49) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h40C9` | s:0, exp:129 (0x81), mant:73 (0x49) | 3.140625 * 2.0 |
| 7 | -100.0 * -0.10009765625 | `16'hC2C8` | s:1, exp:133 (0x85), mant:72 (0x48) | `16'hBDCD` | s:1, exp:123 (0x7b), mant:77 (0x4d) | `16'h4120` | s:0, exp:130 (0x82), mant:32 (0x20) | -100.0 * -0.10009765625 |
| 8 | 10.0 * 0.30078125 | `16'h4120` | s:0, exp:130 (0x82), mant:32 (0x20) | `16'h3E9A` | s:0, exp:125 (0x7d), mant:26 (0x1a) | `16'h4040` | s:0, exp:128 (0x80), mant:64 (0x40) | 10.0 * 0.30078125 |
| 9 | 1.0 * 0.0 | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | 1.0 * 0.0 |
| 10 | +Inf * 2.0 | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | +Inf * 2.0 |
| 11 | -Inf * +Inf | `16'hFF80` | s:1, exp:255 (0xff), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | `16'hFF80` | s:1, exp:255 (0xff), mant:0 (0x00) | -Inf * +Inf |
| 12 | +Inf * 0.0 | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | +Inf * 0.0 |
| 13 | NaN * 5.0 | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | `16'h40A0` | s:0, exp:129 (0x81), mant:32 (0x20) | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | NaN * 5.0 |
| 14 | NaN * +Inf | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | NaN * +Inf |
| 15 | 0.0 * 0.0 | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | 0.0 * 0.0 |
| 16 | -Inf * -0.0 | `16'hFF80` | s:1, exp:255 (0xff), mant:0 (0x00) | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xff), mant:64 (0x40) | -Inf * -0.0 |
| 17 | min_subnormal * 1.0 (FTZ -> 0) | `16'h0001` | s:0, exp:0 (0x00), mant:1 (0x01) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | min_subnormal * 1.0 (FTZ -> 0) |
| 18 | -0.0 * 1.0 (sign) | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | -0.0 * 1.0 (sign) |
| 19 | min_normal * min_normal (underflow -> 0) | `16'h0080` | s:0, exp:1 (0x01), mant:0 (0x00) | `16'h0080` | s:0, exp:1 (0x01), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | min_normal * min_normal (underflow -> 0) |
| 20 | max_BF16 * max_BF16 (overflow -> Inf) | `16'h7F7F` | s:0, exp:254 (0xfe), mant:127 (0x7f) | `16'h7F7F` | s:0, exp:254 (0xfe), mant:127 (0x7f) | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | max_BF16 * max_BF16 (overflow -> Inf) |
| 21 | max_BF16 * 1.0 (normal) | `16'h7F7F` | s:0, exp:254 (0xfe), mant:127 (0x7f) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'h7F7F` | s:0, exp:254 (0xfe), mant:127 (0x7f) | max_BF16 * 1.0 (normal) |
| 22 | 2.0 * 2.0 = 4.0 | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4080` | s:0, exp:129 (0x81), mant:0 (0x00) | 2.0 * 2.0 = 4.0 |
| 23 | 4.0 * 2.0 = 8.0 | `16'h4080` | s:0, exp:129 (0x81), mant:0 (0x00) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4100` | s:0, exp:130 (0x82), mant:0 (0x00) | 4.0 * 2.0 = 8.0 |
| 24 | -2.0 * 1.0 = -2.0 | `16'hC000` | s:1, exp:128 (0x80), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'hC000` | s:1, exp:128 (0x80), mant:0 (0x00) | -2.0 * 1.0 = -2.0 |
| 25 | 2.0 * -1.0 = -2.0 | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'hBF80` | s:1, exp:127 (0x7f), mant:0 (0x00) | `16'hC000` | s:1, exp:128 (0x80), mant:0 (0x00) | 2.0 * -1.0 = -2.0 |
| 26 | -1.0 * -1.0 = 1.0 | `16'hBF80` | s:1, exp:127 (0x7f), mant:0 (0x00) | `16'hBF80` | s:1, exp:127 (0x7f), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | -1.0 * -1.0 = 1.0 |
| 27 | large * large (near overflow) | `16'h7F00` | s:0, exp:254 (0xfe), mant:0 (0x00) | `16'h7F00` | s:0, exp:254 (0xfe), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xff), mant:0 (0x00) | large * large (near overflow) |
| 28 | small normal * small normal | `16'h0100` | s:0, exp:2 (0x02), mant:0 (0x00) | `16'h0100` | s:0, exp:2 (0x02), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | small normal * small normal |
| 29 | 1.0 * -1.0 = -1.0 | `16'h3F80` | s:0, exp:127 (0x7f), mant:0 (0x00) | `16'hBF80` | s:1, exp:127 (0x7f), mant:0 (0x00) | `16'hBF80` | s:1, exp:127 (0x7f), mant:0 (0x00) | 1.0 * -1.0 = -1.0 |
