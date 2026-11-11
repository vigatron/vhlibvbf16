#!/usr/bin/env bash
# Тестбенч vhfastmulb16_addf16_rne_lat4_tb
# См. scripts/tb_lib.sh
SRC_FILE=scripts/f16_rne_lat4.src
TB=tests/vhfastmulb16_addf16_rne_lat4_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
