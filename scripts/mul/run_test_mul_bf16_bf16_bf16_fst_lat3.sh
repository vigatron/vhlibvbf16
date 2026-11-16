#!/usr/bin/env bash
# Тестбенч vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb
# Основной проверяющий тестбенч (16 базовых векторов, потоковая проверка,
# проверка en=0 HOLD и reset priority).
# См. scripts/tb_lib.sh
SRC=(
    src/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.v
    src/aux/vhfastmulb16_mul4x4_comb.v
)
TB=tests/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb.v

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tb_lib.sh"
tb_main "$@"