# BF16 x BF16 -> Float32 test vector table

Output `C` is the **exact product** of `A` and `B` represented as IEEE-754 binary32 (F32).
No intermediate rounding to BF16 is applied: the product of two 8-bit mantissas fits exactly
into the 24-bit F32 mantissa, so the only operations are normalization, sign XOR and
special-case handling.

Column `Output C (BF16, RNE reference)` is the BF16 result rounded to nearest even.
It is a reference for the BF16 output of `vhfastmulb16`; for #7 and #8 it differs from the F32 output.

Special cases: `NaN` in -> quiet NaN `0x7FC00000`; `Inf * 0` -> quiet NaN; `Inf * finite` -> `Inf`
with sign = XOR of signs; `zero * finite` -> zero with sign = XOR of signs.

| No. | Operation | Input A (BF16) | Bit structure A | Input B (BF16) | Bit structure B | Output C (BF16, RNE reference) | **Output C (Float32, exact)** | Bit structure C (F32) | Test description |
|-----|-----------|----------------|-----------------|----------------|-----------------|------------------|--------------------------|----------------------------|------------------|
| 1 | 1.0 * 1.0 = 1.0 | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h3F80` | **`0x3F800000` = 1.0** | s:0, exp:127 (0x7F), mant:0 (0x000000) | Multiplication by one |
| 2 | 2.0 * 3.5 = 7.0 | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h4060` | s:0, exp:128 (0x80), mant:96 (0x60) | `16'h40E0` | **`0x40E00000` = 7.0** | s:0, exp:129 (0x81), mant:6291456 (0x600000) | Basic integers & fractions |
| 3 | -1.5 * 4.0 = -6.0 | `16'hBFC0` | s:1, exp:127 (0x7F), mant:64 (0x40) | `16'h4080` | s:0, exp:129 (0x81), mant:0 (0x00) | `16'hC0C0` | **`0xC0C00000` = -6.0** | s:1, exp:129 (0x81), mant:4194304 (0x400000) | Negative by positive |
| 4 | 0.5 * 0.25 = 0.125 | `16'h3F00` | s:0, exp:126 (0x7E), mant:0 (0x00) | `16'h3E80` | s:0, exp:125 (0x7D), mant:0 (0x00) | `16'h3E00` | **`0x3E000000` = 0.125** | s:0, exp:124 (0x7C), mant:0 (0x000000) | Values less than one |
| 5 | 128.0 * 0.0078125 = 1.0 | `16'h4300` | s:0, exp:134 (0x86), mant:0 (0x00) | `16'h3C00` | s:0, exp:120 (0x78), mant:0 (0x00) | `16'h3F80` | **`0x3F800000` = 1.0** | s:0, exp:127 (0x7F), mant:0 (0x000000) | Reciprocal powers of two |
| 6 | 3.140625 * 2.0 = 6.28125 | `16'h4049` | s:0, exp:128 (0x80), mant:73 (0x49) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h40C9` | **`0x40C90000` = 6.28125** | s:0, exp:129 (0x81), mant:4784128 (0x490000) | Fractional precision |
| 7 | -100.0 * -0.10009765625 = 10.009765625 | `16'hC2C8` | s:1, exp:133 (0x85), mant:72 (0x48) | `16'hBDCD` | s:1, exp:123 (0x7B), mant:77 (0x4D) | `16'h4120` | **`0x41202800` = 10.009765625** | s:0, exp:130 (0x82), mant:2107392 (0x202800) | Two negative values (exact F32) |
| 8 | 10.0 * 0.30078125 = 3.0078125 | `16'h4120` | s:0, exp:130 (0x82), mant:32 (0x20) | `16'h3E9A` | s:0, exp:125 (0x7D), mant:26 (0x1A) | `16'h4040` | **`0x40408000` = 3.0078125** | s:0, exp:128 (0x80), mant:4227072 (0x408000) | Mantissa precision check (exact F32) |
| 9 | 1.0 * 0.0 = 0.0 | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | **`0x00000000` = +0.0** | s:0, exp:0 (0x00), mant:0 (0x000000) | Multiplied by zero |
| 10 | +Inf * 2.0 = +Inf | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h4000` | s:0, exp:128 (0x80), mant:0 (0x00) | `16'h7F80` | **`0x7F800000` = +Inf** | s:0, exp:255 (0xFF), mant:0 (0x000000) | Inf by positive value |
| 11 | -Inf * +Inf = -Inf | `16'hFF80` | s:1, exp:255 (0xFF), mant:0 (0x00) | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'hFF80` | **`0xFF800000` = -Inf** | s:1, exp:255 (0xFF), mant:0 (0x000000) | Different infinities |
| 12 | +Inf * 0.0 = NaN | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | **`0x7FC00000` = quiet NaN** | s:0, exp:255 (0xFF), mant:4194304 (0x400000) | Indeterminacy |
| 13 | NaN * 5.0 = NaN | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) | `16'h40A0` | s:0, exp:129 (0x81), mant:32 (0x20) | `16'h7FC0` | **`0x7FC00000` = quiet NaN** | s:0, exp:255 (0xFF), mant:4194304 (0x400000) | NaN propagated |
| 14 | NaN * +Inf = NaN | `16'h7FC0` | s:0, exp:255 (0xFF), mant:64 (0x40) | `16'h7F80` | s:0, exp:255 (0xFF), mant:0 (0x00) | `16'h7FC0` | **`0x7FC00000` = quiet NaN** | s:0, exp:255 (0xFF), mant:4194304 (0x400000) | NaN * Infinity |
| 15 | 0.0 * 0.0 = 0.0 | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | s:0, exp:0 (0x00), mant:0 (0x00) | `16'h0000` | **`0x00000000` = +0.0** | s:0, exp:0 (0x00), mant:0 (0x000000) | Zero multiplied by zero |
| 16 | -Inf * -0.0 = NaN | `16'hFF80` | s:1, exp:255 (0xFF), mant:0 (0x00) | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | `16'h7FC0` | **`0x7FC00000` = quiet NaN** | s:0, exp:255 (0xFF), mant:4194304 (0x400000) | -Inf * negative zero |

## Extended vectors (F32 range limits)

| No. | Operation | Input A (BF16) | Bit structure A | Input B (BF16) | Bit structure B | Output C (BF16, RNE reference) | **Output C (Float32, exact)** | Bit structure C (F32) | Test description |
|-----|-----------|----------------|-----------------|----------------|-----------------|------------------|--------------------------|----------------------------|------------------|
| 17 | max_BF16 * max_BF16 = +Inf | `16'h7F7F` | s:0, exp:254 (0xFE), mant:127 (0x7F) | `16'h7F7F` | s:0, exp:254 (0xFE), mant:127 (0x7F) | `16'h7F80` | **`0x7F800000` = +Inf** | s:0, exp:255 (0xFF), mant:0 (0x000000) | F32 overflow (product exceeds F32 range) |
| 18 | min_subnormal_BF16 * min_subnormal_BF16 = +0.0 | `16'h0001` | s:0, exp:0 (0x00), mant:1 (0x01) | `16'h0001` | s:0, exp:0 (0x00), mant:1 (0x01) | `16'h0000` | **`0x00000000` = +0.0** | s:0, exp:0 (0x00), mant:0 (0x000000) | F32 underflow to zero |
| 19 | min_subnormal_BF16 * 1.0 | `16'h0001` | s:0, exp:0 (0x00), mant:1 (0x01) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h0001` | **`0x00010000` = 9.183549615799121e-41** | s:0, exp:0 (0x00), mant:65536 (0x010000) | BF16 subnormal -> F32 subnormal |
| 20 | -0.0 * 1.0 = -0.0 | `16'h8000` | s:1, exp:0 (0x00), mant:0 (0x00) | `16'h3F80` | s:0, exp:127 (0x7F), mant:0 (0x00) | `16'h8000` | **`0x80000000` = -0.0** | s:1, exp:0 (0x00), mant:0 (0x000000) | Signed zero |
