#!/usr/bin/env python3
"""
Configuration of top-level modules for statistics collection.

Each module entry defines:
- name: module name (top-level)
- sources: list of Verilog source files relative to project root
- family_sources: additional sources per FPGA family (optional)
- latency: pipeline latency in cycles
- rounding: rounding mode (RTZ, RNE, exact)
- subnormal_handling: how subnormals are handled (FTZ, preserve, etc.)
- category: multiplication, addition, fma
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
    },
]

# FPGA families to synthesize for
FAMILIES = {
    "xc6s": {
        "device": "XC6SLX9-2",
        "lut6_total": 5720,
        "ff_total": 11440,
        "description": "Spartan-6 LX9 (-2 speed grade)",
    },
    "xc7s": {
        "device": "XC7S15-1",
        "lut6_total": 8000,
        "ff_total": 16000,
        "description": "Spartan-7 S15 (-1 speed grade)",
    },
    "xc7a": {
        "device": "XC7A15T-1",
        "lut6_total": 10400,
        "ff_total": 20800,
        "description": "Artix-7 A15T (-1 speed grade)",
    },
}

# Yosys tool versions (for metadata)
TOOL_VERSIONS = {
    "yosys": "0.70 (git sha1 28ba3cb92)",
    "yowasp": "0.70.0.0.post1259",
    "wasmtime": "47.0.1",
}