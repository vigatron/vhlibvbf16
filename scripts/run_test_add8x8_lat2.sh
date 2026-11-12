#!/usr/bin/env bash
# Тестбенч vhfastmulb16_add8x8_tb (артефакты/gtkw - с суффиксом _chk)
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_add8x8
GTKW_NAME=vhfastmulb16_add8x8_lat2_tb
SRC=(
    src/vhfastmulb16_add8x8_lat2.v
)
TB=tests/vhfastmulb16_add8x8_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
