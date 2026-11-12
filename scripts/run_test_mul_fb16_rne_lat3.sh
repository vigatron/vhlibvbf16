#!/usr/bin/env bash
# Тестбенч vhfastmulb16_rne_lat3_tb
# См. scripts/tb_lib.sh
SRC=(
    src/vhfastmulb16_rne_lat3.v
    src/vhfastmulb16_add8x8_lat2.v
    src/vhfastmulb16_mul_u8_u8_u16_lat2.v
    src/vhfastmulb16_mul4x4.v
    src/vhfastmulb16_flags_lat1.v
    src/vhfastmulb16_sign.v
    src/vhfastmulb16_except_lat2.v
)
TB=tests/vhfastmulb16_rne_lat3_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_lib.sh"
tb_main "$@"
