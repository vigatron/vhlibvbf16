#!/usr/bin/env bash
# Визуализационный тестбенч vhfastmulb16_mul8x8_chk_tb
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_mul8x8_chk
GTKW_NAME=vhfastmulb16_mul8x8_chk_tb
SRC=(
    src/vhfastmulb16_mul8x8.v
    src/vhfastmulb16_mul4x4.v
)
TB=tests/vhfastmulb16_mul8x8_chk_tb.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"