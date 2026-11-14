#!/usr/bin/env bash
# Тестбенч vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_tb
# См. scripts/tb_lib.sh
SRC_FILE=scripts/fma/muladd_bf16_bf16_fp32_fp32_rne_lat8.src
TB=tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"
