#!/usr/bin/env bash
# Тестбенч vhfastmulb16_sign_tb
# См. scripts/tb_lib.sh
SRC=(
    src/aux/vhfastmulb16_sign.v
)
TB=tests/aux/vhfastmulb16_sign_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"
