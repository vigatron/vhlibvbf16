#!/usr/bin/env bash
# Тестбенч vhfastmulb16_flags_lat1_tb
# См. scripts/tb_lib.sh
SRC=(
    src/aux/vhfastmulb16_flags_lat1.v
)
TB=tests/aux/vhfastmulb16_flags_lat1_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"
