# vhlibvbf16

![Verilog](https://img.shields.io/badge/Verilog-2008-1364FF)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Date](https://img.shields.io/badge/date-2026--11--06-informational)
![Status](https://img.shields.io/badge/status-initial_version-orange)
![Build](https://img.shields.io/badge/build-verified-brightgreen)


Compact pipelined BFloat16 multiplier (Verilog) — RTZ/RNE, no DSP required.  

Author: V01G04A81  
Rev: 0.0.1  


`vhfastmulb16` is a hardware implementation of a BFloat16 (Brain Floating Point) multiplier.
It multiplies two BF16 numbers and produces a BF16 result on the output.
The design supports two rounding modes:

- **RTZ** (Round Toward Zero) — truncation, simple discard of the lower bits;
- **RNE** (Round to Nearest Even) — IEEE 754 rounding.

The implementation does not require any DSP blocks: the multiplication is built
from a carry-save adder (CSA) tree and a final 16-bit carry-propagate adder (CPA).

## Development Status

- This is an **Initial version** of the project.
- The simplified implementation optimized for speed (without rounding and extra logic) — `vhfastmulb16_fst_lat3.v` — is currently **in development**. The design bypasses the rounding stage and omits auxiliary control/exception logic, shortening the critical path at the cost of numerical precision.
- The pipelined BF16 multiplication modules with Latency 2 and 4 are also **in development** as intermediate stages of the design flow.
- The Latency 3 implementation (`vhfastmulb16_rtz_lat3.v` / `vhfastmulb16_rne_lat3.v`) is available now! It is the current top-level synthesizable RTL with the full multiply datapath and the RTZ / RNE rounding stages.
- The modules are implemented in pure logic without the multiplication operator `*`; replacing the carry-propagate adder with a DSP (for example, a DSP48A1) would save up to 50% of LUTs and significantly increase the operating speed.

## Source Files

The `src/` directory contains **11** Verilog source files:

| # | File | Module | Description | Latency |
|---|------|--------|-------------|---------|
| 1 | `vhfastmulb16_mul4x4.v` | `vhfastmulb16_mul4x4` | 4x4-bit multiplication without the `*` operator (CSA tree) | 1 clk |
| 2 | `vhfastmulb16_mul8x8.v` | `vhfastmulb16_mul8x8` | 8x8-bit multiplication via 4 instances of `mul4x4` | 2 clk |
| 3 | `vhfastmulb16_add8x8_lat2.v` | `vhfastmulb16_add8x8_lat2` | Addition of two 8-bit numbers and subtraction of 127 (bias) | 2 clk |
| 4 | `vhfastmulb16_add8x8_branch.v` | `vhfastmulb16_add8x8` | Addition of two 8-bit numbers and subtraction of 127 | 2 clk |
| 5 | `vhfastmulb16_sign.v` | `vhfastmulb16_sign` | Sign cascade (XOR) with 3 outputs | 1/2/3 clk |
| 6 | `vhfastmulb16_flags_lat1.v` | `vhfastmulb16_flags_lat1` | Exponent/mantissa flags (zero/subnormal/normal/inf/nan) | 1 clk |
| 7 | `vhfastmulb16_flags_lat2.v` | `vhfastmulb16_flags_lat2` | Exponent/mantissa flags (2-stage pipeline) | 2 clk |
| 8 | `vhfastmulb16_except_lat2.v` | `vhfastmulb16_except_lat2` | Exception handling (NaN/Inf/Zero) for latency-2 pipeline | 2 clk |
| 9 | `vhfastmulb16_except_lat3.v` | `vhfastmulb16_except_lat3` | Exception handling (NaN/Inf/Zero) for latency-3 pipeline | 3 clk |
| 10 | `vhfastmulb16_rtz_lat3.v` | `vhfastmulb16_rtz_lat3` | Top-level BF16 multiplier with **RTZ** rounding (truncation) | 3 clk |
| 11 | `vhfastmulb16_rne_lat3.v` | `vhfastmulb16_rne_lat3` | Top-level BF16 multiplier with **RNE** rounding (IEEE 754) | 3 clk |

### Module Dependencies

```
vhfastmulb16_rtz_lat3 / vhfastmulb16_rne_lat3
├── vhfastmulb16_add8x8_lat2
├── vhfastmulb16_mul8x8
│   └── vhfastmulb16_mul4x4 (x4)
├── vhfastmulb16_sign
├── vhfastmulb16_flags_lat1 (in except_lat2)
├── vhfastmulb16_flags_lat2 (in except_lat3)
├── vhfastmulb16_except_lat2 (in rtz/rne latency-3)
└── vhfastmulb16_except_lat3 (alternative for latency-3)
```

### Versions with Different Latency

| Component | Latency 1 | Latency 2 | Latency 3 |
|-----------|-----------|-----------|-----------|
| Flags | `vhfastmulb16_flags_lat1` | `vhfastmulb16_flags_lat2` | - |
| Exceptions | - | `vhfastmulb16_except_lat2` | `vhfastmulb16_except_lat3` |
| Top-level | - | - | `vhfastmulb16_rtz_lat3`, `vhfastmulb16_rne_lat3` |

## Testbenches

The testbenches are located in the [tests/](tests/) directory, and the run scripts are located in the [scripts/](scripts/) directory.

| Testbench | Module under test |
|-----------|-------------------|
| `tests/vhfastmulb16_mul4x4_tb.v` | `vhfastmulb16_mul4x4` |
| `tests/vhfastmulb16_mul8x8_tb.v` | `vhfastmulb16_mul8x8` |
| `tests/vhfastmulb16_add8x8_tb.v` | `vhfastmulb16_add8x8_lat2` |
| `tests/vhfastmulb16_sign_tb.v` | `vhfastmulb16_sign` |
| `tests/vhfastmulb16_flags_lat1_tb.v` | `vhfastmulb16_flags_lat1` |
| `tests/vhfastmulb16_flags_lat2_tb.v` | `vhfastmulb16_flags_lat2` |
| `tests/vhfastmulb16_except_lat2_tb.v` | `vhfastmulb16_except_lat2` |
| `tests/vhfastmulb16_except_lat3_tb.v` | `vhfastmulb16_except_lat3` |
| `tests/vhfastmulb16_rtz_lat3_tb.v` | `vhfastmulb16_rtz_lat3` |
| `tests/vhfastmulb16_rne_lat3_tb.v` | `vhfastmulb16_rne_lat3` |

Run the simulation with:

```bash
# All tests
./scripts/run_all.sh sim

# Individual tests
./scripts/run_test_mul4x4.sh sim
./scripts/run_test_mul8x8.sh sim
./scripts/run_test_add8x8_lat2.sh sim
./scripts/run_test_sign.sh sim
./scripts/run_test_flags_lat1.sh sim
./scripts/run_test_flags_lat2.sh sim
./scripts/run_test_except_lat2.sh sim
./scripts/run_test_except_lat3.sh sim
./scripts/run_test_mul_fb16_rtz_lat3.sh sim
./scripts/run_test_mul_fb16_rne_lat3.sh sim

# Visualization (gtkwave)
./scripts/run_test_mul4x4.sh wave
./scripts/run_test_mul8x8.sh wave

# Clean up build artifacts
./scripts/run_all.sh clean
```

See the [docs/testbenches_list.md](docs/testbenches_list.md) file for more details.

## Test Vectors

The reference test vector table is kept in [docs/test_values_details.md](docs/test_values_details.md).

| No. | Operation | Input A (`inarr_a`) | Bit structure A | Input B (`inarr_b`) | Bit structure B | Output C (`outarr_c`) | Bit structure C (Expected) | Test description |
| :---: | :--- | :---: | :--- | :---: | :--- | :--- | :--- | :--- |
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

## FPGA Resource Statistics

The implementation was evaluated for the Xilinx XC6SLX9 (Spartan-6 LX9) target:

| Parameter | Value |
|----------|-------|
| **Device** | XC6SLX9 (Spartan-6 LX9) |
| **Package** | CSG144 / CPG144 |
| **Logic Cells** | 9,152 |
| **Slices** | 1,448 |
| **LUTs (4-input)** | **5,792** (1,448 × 4) |
| **Flip-Flops** | 11,584 |
| **Block RAM (18Kb)** | 32 (576 Kb total) |
| **DSP48A1** | 16 |
| **Max Clock (typical)** | ~200-300 MHz for simple paths |

### Top-Level Modules

#### `vhfastmulb16_rtz_lat3` (RTZ — Round Toward Zero)

| Resource | Estimate | % of available |
|----------|----------|----------------|
| **LUTs** | ~1,850 | **32%** |
| FF (registers) | ~1,200 | 10% |
| DSP48A1 | 0 | 0% |
| Block RAM | 0 | 0% |
| **Max frequency** | ~180 MHz | — |

#### `vhfastmulb16_rne_lat3` (RNE — Round to Nearest Even)

| Resource | Estimate | % of available |
|----------|----------|----------------|
| **LUTs** | ~2,150 | **37%** |
| FF (registers) | ~1,300 | 11% |
| DSP48A1 | 0 | 0% |
| Block RAM | 0 | 0% |
| **Max frequency** | ~160 MHz | — |

### RTZ vs RNE Comparison

| Metric | RTZ | RNE | Overhead |
|---------|-----|-----|----------|
| LUTs | 1,850 | 2,150 | **+16%** |
| FF | 1,200 | 1,300 | **+8%** |
| Max Freq | ~180 MHz | ~160 MHz | -11% |
| Latency | 3 cycles | 3 cycles | 0 |
| Accuracy | Truncation | IEEE 754 RNE | — |

Both modules comfortably fit into the **XC6SLX9** with a reserve of ~60-65% of LUTs
for the rest of the system logic.

## Author

Author: Viktor Glebov / V01G04A81 2026

## License

MIT

<https://github.com/vigatron/vhlibvbf16>
