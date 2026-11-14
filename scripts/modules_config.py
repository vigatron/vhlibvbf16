#!/usr/bin/env python3
"""
Configuration of top-level modules for statistics collection.

Each module entry defines:
- name: module name (top-level)
- sources: list of Verilog source files relative to project root
- latency: pipeline latency in cycles
- rounding: rounding mode (RTZ, RNE, exact)
- subnormal_handling: how subnormals are handled (FTZ, preserve, etc.)
- category: multiplication, addition, fma
- fmax: hand-calibrated typical Fmax (MHz) per FPGA family
  (manual estimation, see docs/stat/stat_top_spartan6.md etc.)
"""

MODULES = [
    {
        "name": "vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3",
        "sources": [
            "src/vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3.v",
            "src/vhfastmulb16_add8x8_lat2.v",
            "src/vhfastmulb16_mul_u8_u8_u16_lat2.v",
            "src/vhfastmulb16_mul4x4.v",
            "src/vhfastmulb16_flags_lat1.v",
            "src/vhfastmulb16_sign.v",
            "src/vhfastmulb16_except_lat2.v",
        ],
        "latency": 3,
        "rounding": "RTZ",
        "subnormal_handling": "FTZ",
        "category": "multiplication",
        "fmax": {"xc6s": 175, "xc7s": 205, "xc7a": 230},
    },
    {
        "name": "vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3",
        "sources": [
            "src/vhfastmulb16_mul_bf16_bf16_bf16_rne_lat3.v",
            "src/vhfastmulb16_add8x8_lat2.v",
            "src/vhfastmulb16_mul_u8_u8_u16_lat2.v",
            "src/vhfastmulb16_mul4x4.v",
            "src/vhfastmulb16_flags_lat1.v",
            "src/vhfastmulb16_sign.v",
            "src/vhfastmulb16_except_lat2.v",
        ],
        "latency": 3,
        "rounding": "RNE",
        "subnormal_handling": "FTZ",
        "category": "multiplication",
        "fmax": {"xc6s": 155, "xc7s": 180, "xc7a": 210},
    },
    {
        "name": "vhfastmulb16_mul_bf16_bf16_fp32_lat4",
        "sources": [
            "src/vhfastmulb16_mul_bf16_bf16_fp32_lat4.v",
            "src/vhfastmulb16_mul4x4_comb.v",
            "src/vhfastmulb16_sign.v",
        ],
        "latency": 4,
        "rounding": "exact",
        "subnormal_handling": "preserve",
        "category": "multiplication",
        "fmax": {"xc6s": 145, "xc7s": 165, "xc7a": 190},
    },
    {
        "name": "vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4",
        "sources": [
            "src/vhfastmulb16_add_fp32_fp32_fp32_rtz_lat4.v",
        ],
        "latency": 4,
        "rounding": "RTZ",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 120, "xc7s": 140, "xc7a": 160},
    },
    {
        "name": "vhfastmulb16_add_fp32_fp32_fp32_rne_lat4",
        "sources": [
            "src/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4.v",
        ],
        "latency": 4,
        "rounding": "RNE",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 110, "xc7s": 130, "xc7a": 150},
    },
    {
        "name": "vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4",
        "sources": [
            "src/vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4.v",
        ],
        "latency": 4,
        "rounding": "RTZ",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 140, "xc7s": 170, "xc7a": 200},
    },
    {
        "name": "vhfastmulb16_add_fp16_fp16_fp16_rne_lat4",
        "sources": [
            "src/vhfastmulb16_add_fp16_fp16_fp16_rne_lat4.v",
        ],
        "latency": 4,
        "rounding": "RNE",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 130, "xc7s": 155, "xc7a": 185},
    },
    {
        "name": "vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4",
        "sources": [
            "src/vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4.v",
        ],
        "latency": 4,
        "rounding": "RTZ",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 135, "xc7s": 165, "xc7a": 195},
    },
    {
        "name": "vhfastmulb16_add_bf16_bf16_bf16_rne_lat4",
        "sources": [
            "src/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.v",
        ],
        "latency": 4,
        "rounding": "RNE",
        "subnormal_handling": "preserve",
        "category": "addition",
        "fmax": {"xc6s": 125, "xc7s": 150, "xc7a": 180},
    },
    {
        "name": "vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4",
        "sources": [
            "src/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4.v",
            "src/vhfastmulb16_mul4x4_comb.v",
        ],
        "latency": 4,
        "rounding": "RNE",
        "subnormal_handling": "preserve",
        "category": "fma",
        "fmax": {"xc6s": 100, "xc7s": 125, "xc7a": 145},
    },
    {
        "name": "vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8",
        "sources": [
            "src/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8.v",
            "src/vhfastmulb16_mul4x4_comb.v",
        ],
        "latency": 8,
        "rounding": "RNE",
        "subnormal_handling": "preserve",
        "category": "fma",
        "fmax": {"xc6s": 170, "xc7s": 200, "xc7a": 220},
    },
]

# Bottom-up submodules for docs/stat/stat_others_*.md (generated).
# Sources include the submodule's own dependencies (flatten handles the rest).
SUBMODULES = [
    {
        "name": "vhfastmulb16_mul4x4",
        "sources": ["src/vhfastmulb16_mul4x4.v"],
        "latency": 1,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 280, "xc7s": 320, "xc7a": 380},
    },
    {
        "name": "vhfastmulb16_mul4x4_lat2",
        "sources": ["src/vhfastmulb16_mul4x4_lat2.v"],
        "latency": 2,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 340, "xc7s": 400, "xc7a": 420},
    },
    {
        "name": "vhfastmulb16_mul4x4_comb",
        "sources": ["src/vhfastmulb16_mul4x4_comb.v"],
        "latency": 0,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 320, "xc7s": 360, "xc7a": 380},
    },
    {
        "name": "vhfastmulb16_mul_u8_u8_u16_lat2",
        "sources": ["src/vhfastmulb16_mul_u8_u8_u16_lat2.v", "src/vhfastmulb16_mul4x4.v"],
        "latency": 2,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 230, "xc7s": 270, "xc7a": 290},
    },
    {
        "name": "vhfastmulb16_mul_u8_u8_u16_lat3",
        "sources": ["src/vhfastmulb16_mul_u8_u8_u16_lat3.v", "src/vhfastmulb16_mul4x4_lat2.v"],
        "latency": 3,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 290, "xc7s": 330, "xc7a": 350},
    },
    {
        "name": "vhfastmulb16_add8x8_lat2",
        "sources": ["src/vhfastmulb16_add8x8_lat2.v"],
        "latency": 2,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 400, "xc7s": 450, "xc7a": 480},
    },
    {
        "name": "vhfastmulb16_sign",
        "sources": ["src/vhfastmulb16_sign.v"],
        "latency": 3,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 500, "xc7s": 600, "xc7a": 620},
    },
    {
        "name": "vhfastmulb16_flags_lat1",
        "sources": ["src/vhfastmulb16_flags_lat1.v"],
        "latency": 1,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 400, "xc7s": 450, "xc7a": 480},
    },
    {
        "name": "vhfastmulb16_flags_lat2",
        "sources": ["src/vhfastmulb16_flags_lat2.v"],
        "latency": 2,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 450, "xc7s": 500, "xc7a": 540},
    },
    {
        "name": "vhfastmulb16_except_lat2",
        "sources": ["src/vhfastmulb16_except_lat2.v", "src/vhfastmulb16_flags_lat1.v"],
        "latency": 2,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 320, "xc7s": 360, "xc7a": 380},
    },
    {
        "name": "vhfastmulb16_except_lat3",
        "sources": ["src/vhfastmulb16_except_lat3.v", "src/vhfastmulb16_flags_lat2.v"],
        "latency": 3,
        "rounding": "exact",
        "subnormal_handling": "n/a",
        "category": "submodule",
        "fmax": {"xc6s": 360, "xc7s": 400, "xc7a": 420},
    },
]

# FPGA families to synthesize for
# NOTE: yosys synth_xilinx has no separate -family for Spartan-7 / Artix-7;
# both map to "xc7" (Series 7), so their post-map_ffs netlists are identical.
# The FAMILIES keys stay distinct (device, LUT/FF totals, Fmax differ).
FAMILIES = {
    "xc6s": {
        "device": "XC6SLX9-2",
        "synth_family": "xc6s",
        "lut6_total": 5720,
        "ff_total": 11440,
        "dsp_total": 16,
        "dsp_type": "DSP48A1",
        "bram_total": "32 × 18Kb",
        "description": "Spartan-6 LX9 (-2 speed grade)",
    },
    "xc7s": {
        "device": "XC7S15-1",
        "synth_family": "xc7",
        "lut6_total": 8000,
        "ff_total": 16000,
        "dsp_total": 20,
        "dsp_type": "DSP48E1",
        "bram_total": "10 × 36Kb",
        "description": "Spartan-7 S15 (-1 speed grade)",
    },
    "xc7a": {
        "device": "XC7A15T-1",
        "synth_family": "xc7",
        "lut6_total": 10400,
        "ff_total": 20800,
        "dsp_total": 45,
        "dsp_type": "DSP48E1",
        "bram_total": "25 × 36Kb",
        "description": "Artix-7 A15T (-1 speed grade)",
    },
}

# Yosys tool versions (for metadata)
TOOL_VERSIONS = {
    "yosys": "0.70 (git sha1 28ba3cb92)",
    "yowasp": "0.70.0.0.post1259",
    "wasmtime": "47.0.1",
}