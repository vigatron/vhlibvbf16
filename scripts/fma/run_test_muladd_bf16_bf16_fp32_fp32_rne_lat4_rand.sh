#!/usr/bin/env bash
# Случайный/directed regression для vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4.
# Векторы генерируются Python-моделью в build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.hex.
# Seed можно переопределить через окружение:
#   VEC_SEED=1 ./scripts/fma/run_test_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.sh sim
# См. scripts/tb_lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # корень проекта (на два уровня выше от scripts/fma/)

SRC_FILE=scripts/fma/muladd_bf16_bf16_fp32_fp32_rne_lat4.src
TB=tests/fma/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb.v

# Число векторов должно совпадать с localparam N в тестбенче
# ($readmemh читает ровно N строк) - значение проверяется ниже.
VEC_COUNT=2048
VEC_SEED="${VEC_SEED:-12345}"
VEC_FILE="$ROOT/build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.hex"

case "${1:-sim}" in
    sim|all|wave)
        # Защита от расхождения генератора и тестбенча.
        tb_count="$(sed -n 's/.*localparam integer N *= *\([0-9]\{1,\}\).*/\1/p' \
                    "$ROOT/$TB" | head -1)"
        if [ -n "$tb_count" ] && [ "$tb_count" != "$VEC_COUNT" ]; then
            echo "ERROR: VEC_COUNT=$VEC_COUNT не совпадает с N=$tb_count в $TB" >&2
            exit 1
        fi

        mkdir -p "$ROOT/build"
        python3 "$ROOT/scripts/gen_fma_vectors.py" \
            --count "$VEC_COUNT" --seed "$VEC_SEED" \
            --out "$VEC_FILE" >/dev/null
        ;;
    clean)
        rm -f "$VEC_FILE"
        ;;
esac

source "$ROOT/scripts/tb_lib.sh"
tb_main "$@"
