# BF16 x BF16 -> F32 Test Vector Matrix (simplified)

BF16 Multiplication: A * B = C

Columns:
  * A, B   - input operands (BF16, 1s/8e/7m)
  * C      - output BF16 rounded to nearest even (RNE reference)
  * F32    - exact product as IEEE-754 binary32 (F32)

Special cases: NaN in -> quiet NaN; Inf * 0 -> quiet NaN; Inf * finite -> Inf
(sign = XOR of signs); zero * finite -> zero (sign = XOR of signs).

| № | A | B | C (BF16 RNE) | F32 (exact) | Description |
|:-:|:---:|:---:|:---:|:---:|:---|
| 1 | `16'h3F80` | `16'h3F80` | `16'h3F80` | `0x3F800000` | Multiplication by one (1.0 * 1.0 = 1.0) |
| 2 | `16'h4000` | `16'h4060` | `16'h40E0` | `0x40E00000` | Basic integers & fractions (2.0 * 3.5 = 7.0) |
| 3 | `16'hBFC0` | `16'h4080` | `16'hC0C0` | `0xC0C00000` | Negative by positive (-1.5 * 4.0 = -6.0) |
| 4 | `16'h3F00` | `16'h3E80` | `16'h3E00` | `0x3E000000` | Values less than one (0.5 * 0.25 = 0.125) |
| 5 | `16'h4300` | `16'h3C00` | `16'h3F80` | `0x3F800000` | Reciprocal powers of two (128.0 * 0.0078125 = 1.0) |
| 6 | `16'h4049` | `16'h4000` | `16'h40C9` | `0x40C90000` | Fractional precision (3.140625 * 2.0 = 6.28125) |
| 7 | `16'hC2C8` | `16'hBDCD` | `16'h4120` | `0x41202800` | Two negative values (-100.0 * -0.10009765625 = 10.009765625) |
| 8 | `16'h4120` | `16'h3E9A` | `16'h4040` | `0x40408000` | Mantissa precision check (10.0 * 0.30078125 = 3.0078125) |
| 9 | `16'h3F80` | `16'h0000` | `16'h0000` | `0x00000000` | Multiplied by zero (1.0 * 0.0 = 0.0) |
| 10 | `16'h7F80` | `16'h4000` | `16'h7F80` | `0x7F800000` | Inf by positive value (+Inf * 2.0 = +Inf) |
| 11 | `16'hFF80` | `16'h7F80` | `16'hFF80` | `0xFF800000` | Different infinities (-Inf * +Inf = -Inf) |
| 12 | `16'h7F80` | `16'h0000` | `16'h7FC0` | `0x7FC00000` | Indeterminacy (+Inf * 0.0 = NaN) |
| 13 | `16'h7FC0` | `16'h40A0` | `16'h7FC0` | `0x7FC00000` | NaN propagated (NaN * 5.0 = NaN) |
| 14 | `16'h7FC0` | `16'h7F80` | `16'h7FC0` | `0x7FC00000` | NaN * Infinity |
| 15 | `16'h0000` | `16'h0000` | `16'h0000` | `0x00000000` | Zero multiplied by zero (0.0 * 0.0 = 0.0) |
| 16 | `16'hFF80` | `16'h8000` | `16'h7FC0` | `0x7FC00000` | -Inf * negative zero |

## Extended vectors (F32 range limits)

| № | A | B | C (BF16 RNE) | F32 (exact) | Description |
|:-:|:---:|:---:|:---:|:---:|:---|
| 17 | `16'h7F7F` | `16'h7F7F` | `16'h7F80` | `0x7F800000` | F32 overflow (max_BF16 * max_BF16 = +Inf) |
| 18 | `16'h0001` | `16'h0001` | `16'h0000` | `0x00000000` | F32 underflow to zero (min subnormal * min subnormal) |
| 19 | `16'h0001` | `16'h3F80` | `16'h0001` | `0x00010000` | BF16 subnormal -> F32 subnormal (min subnormal * 1.0) |
| 20 | `16'h8000` | `16'h3F80` | `16'h8000` | `0x80000000` | Signed zero (-0.0 * 1.0 = -0.0) |
