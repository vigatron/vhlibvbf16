#!/usr/bin/env bash
# Тестбенч vhfastmulb16_except_lat2_tb
# См. scripts/tb_lib.sh
SRC=(
    src/vhfastmulb16_except_lat2.v
    src/vhfastmulb16_flags_lat1.v
)
TB=tests/vhfastmulb16_except_lat2_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
