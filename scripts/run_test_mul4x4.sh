#!/usr/bin/env bash
# Тестбенч vhfastmulb16_mul4x4_tb
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_mul4x4
GTKW_NAME=vhfastmulb16_mul4x4_tb
SRC=(
    src/vhfastmulb16_mul4x4.v
)
TB=tests/vhfastmulb16_mul4x4_tb.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
