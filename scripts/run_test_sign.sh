#!/usr/bin/env bash
# Тестбенч vhfastmulb16_sign_tb
# См. scripts/tb_lib.sh
NAME=vhfastmulb16_sign
GTKW_NAME=vhfastmulb16_sign_tb
SRC=(
    src/vhfastmulb16_sign.v
)
TB=tests/vhfastmulb16_sign_tb.v
RESULT_MODE=passed

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
