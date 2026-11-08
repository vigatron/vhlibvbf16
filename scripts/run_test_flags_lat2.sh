#!/usr/bin/env bash
# Тестбенч vhfastmulb16_flags_lat2_chk_tb
# См. scripts/tb_lib.sh
SRC=(
    src/vhfastmulb16_flags_lat2.v
)
TB=tests/vhfastmulb16_flags_lat2_chk_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
