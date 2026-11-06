#!/usr/bin/env bash
# Тестбенч vhfastmulb16_except_lat2_tb
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_except_lat2
GTKW_NAME=vhfastmulb16_except_lat2_tb
SRC=(
    src/vhfastmulb16_except_lat2.v
    src/vhfastmulb16_flags_lat1.v
)
TB=tests/vhfastmulb16_except_lat2_tb.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
