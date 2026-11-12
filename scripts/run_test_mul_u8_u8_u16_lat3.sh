#!/usr/bin/env bash
# Тестбенч vhfastmulb16_mul_u8_u8_u16_lat3_chk_tb
# См. scripts/tb_lib.sh
SRC=(
    src/vhfastmulb16_mul_u8_u8_u16_lat3.v
    src/vhfastmulb16_mul4x4_lat2.v
)
TB=tests/vhfastmulb16_mul_u8_u8_u16_lat3_chk_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
