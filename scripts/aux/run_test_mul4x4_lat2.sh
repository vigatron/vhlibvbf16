#!/usr/bin/env bash
# Тестбенч vhfastmulb16_mul4x4_lat2_chk_tb
# См. scripts/tb_lib.sh
SRC=(
    src/aux/vhfastmulb16_mul4x4_lat2.v
)
TB=tests/aux/vhfastmulb16_mul4x4_lat2_chk_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"
