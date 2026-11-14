BF16 Multiplication Test Vector Table


| No. | Operation | Input A (`inarr_a`) | Bit structure A | Input B (`inarr_b`) | Bit structure B | Output C (`outarr_c`) | Bit structure C (Expected) | Test description |
| :---: | :---: | :---: | :--- | :---: | :--- | :---: | :--- | :--- |
| 1 | 1.0 * 1.0 = 1.0 | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) 1.0 | Multiplication by one |
| 2 | 2.0 * 3.5 = 7.0 | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4060` | s:0, exp:128 (0x80), mant:96 (0x60) | `16'h40E0` | s:0, exp:129 (0x81), mant:96 (0x60) 7.0 | Basic integers & fractions |
| 3 | -1.5 * 4.0 = -6.0 | `16'hBFC0` | s:1, exp:127 (0x7F), mant:64 (0x40) | `16'h4080` | s:0, exp:129 (0x81), mant:0 (0x00) | `16'hC0C0` | s:1, exp:129 (0x81), mant:64 (0x40) -6.0 | Negative by positive |
| 4 | 0.5 * 0.25 = 0.125 | `16'h3F00` | s:0, exp:126 (0x7E), mant:0 (0x00) | `16'h3E80` | s:0, exp:125 (0x7D), mant:0 (0x00) | `16'h3E00` | s:0, exp:124 (0x7C), mant:0 (0x00) 0.125 | Values less than one |
| 5 | 128.0 * 0.0078125 = 1.0 | `16'h4300` | s:0, exp:134 (0x86), mant:0 (0x00) | `16'h3C00` | s:0, exp:120 (0x78), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) 1.0 | Reciprocal powers of two |
| 6 | 3.140625 * 2.0 = 6.28125 | `16'h4049` | s:0, exp:128 (0x80), mant:73 (0x49) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h40C9` | s:0, exp:129 (0x81), mant:73 (0x49) 6.28125 | Fractional precision |
| 7 | -100.0 * -0.10009... = 10.0 | `16'hC2C8` | s:1, exp:133 (0x85), mant:72 (0x48) | `16'hBDCD` | s:1, exp:123 (0x7B), mant:77 (0x4D) | `16'h4120` | s:0, exp:130 (0x82), mant:32 (0x20) 10.0 (rounded) | Two negative values |
| 8 | 10.0 * 0.30078... = 3.0 | `16'h4120` | s:0, exp:130 (0x82), mant:32 (0x20) | `16'h3E9A` | s:0, exp:125 (0x7D), mant:26 (0x1A) | `16'h4040` | s:0, exp:128 (0x80), mant:64 (0x40) 3.0 (rounded) | Mantissa precision check |
| 9 | 1.0 * 0.0 = 0.0 | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) +0.0 | Multiplied by zero |
| 10 | +∞ * 2.0 = +∞ | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) +Inf | Inf by positive value |
| 11 | -∞ * +∞ = -∞ | `16'hFF80` | s:1, exp:255 (0xFF), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'hFF80` | s:1, exp:255 (0xFF), mant:0 (0x00) -Inf | Different infinities |
| 12 | +∞ * 0.0 = NaN | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) quiet NaN | Indeterminacy |
| 13 | NaN * 5.0 = NaN | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) | `16'h40A0` | s:0, exp:129 (0x81), mant:32 (0x20) | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) NaN | NaN propagated |
| 14 | NaN * +∞ = NaN | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) NaN | NaN * Infinity |
| 15 | 0.0 * 0.0 = 0.0 | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) +0.0 | Zero multiplied by zero |
| 16 | -∞ * -0.0 = NaN | `16'hFF80` | s:1, exp:255 (0xFF), mant:0 (0x00) | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) quiet NaN | -Inf * negative zero |
