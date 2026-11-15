#!/usr/bin/env bash
# Тестбенч vhfma001_tb
# См. scripts/tb_lib.sh
SRC_FILE=scripts/fma/vhfma001.src
TB=tests/fma/vhfma001_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"
