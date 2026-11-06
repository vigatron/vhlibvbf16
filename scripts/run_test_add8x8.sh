#!/usr/bin/env bash
# Тестбенч vhfastmulb16_add8x8_tb.chk
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_add8x8_lat2_chk
GTKW_NAME=vhfastmulb16_add8x8_tb.chk
SRC=(
    src/vhfastmulb16_add8x8_lat2.v
)
TB=tests/vhfastmulb16_add8x8_tb.chk.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
