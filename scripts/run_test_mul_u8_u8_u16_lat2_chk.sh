#!/usr/bin/env bash
# Визуализационный тестбенч vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb
# См. scripts/tb_lib.sh
SRC=(
    src/vhfastmulb16_mul_u8_u8_u16_lat2.v
    src/vhfastmulb16_mul4x4.v
)
TB=tests/vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
