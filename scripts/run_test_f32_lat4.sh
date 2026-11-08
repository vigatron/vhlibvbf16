#!/usr/bin/env bash
# Тестбенч vhfastmulb16_f32_lat4_tb
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_f32_lat4
GTKW_NAME=vhfastmulb16_f32_lat4_tb
SRC=(
    src/vhfastmulb16_f32_lat4.v
)
TB=tests/vhfastmulb16_f32_lat4_tb.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
