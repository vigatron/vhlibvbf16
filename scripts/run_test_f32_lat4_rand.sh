#!/usr/bin/env bash
# Случайный/directed regression для vhfastmulb16_f32_lat4.
# Векторы генерируются Python-моделью в build/vhfastmulb16_f32_lat4_rand.hex.
# См. scripts/tb_lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAME=vhfastmulb16_f32_lat4_rand
GTKW_NAME=vhfastmulb16_f32_lat4_rand_tb
SRC=(
    src/vhfastmulb16_f32_lat4.v
    src/vhfastmulb16_add8x8_lat2.v
    src/vhfastmulb16_mul8x8_lat3.v
    src/vhfastmulb16_mul4x4_lat2.v
    src/vhfastmulb16_sign.v
)
TB=tests/vhfastmulb16_f32_lat4_rand_tb.v
RESULT_MODE=passed

case "${1:-sim}" in
    clean)
        ;;
    *)
        mkdir -p "$PROJECT_ROOT/build"
        python3 "$PROJECT_ROOT/scripts/gen_f32_vectors.py" \
            --count 2048 --seed 12345 \
            --out "$PROJECT_ROOT/build/vhfastmulb16_f32_lat4_rand.hex" >/dev/null
        ;;
esac

source "$SCRIPT_DIR/tb_lib.sh"
tb_main "$@"
