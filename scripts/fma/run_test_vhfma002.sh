#!/usr/bin/env bash
# Тестбенч vhfma002_tb
# См. scripts/tb_lib.sh
SRC_FILE=scripts/fma/vhfma002.src
TB=tests/fma/vhfma002_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"