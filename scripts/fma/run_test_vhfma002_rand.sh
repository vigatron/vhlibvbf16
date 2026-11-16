#!/usr/bin/env bash
# Случайный тестбенч vhfma002_rand_tb
# См. scripts/tb_lib.sh
SRC_FILE=scripts/fma/vhfma002.src
TB=tests/fma/vhfma002_rand_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"