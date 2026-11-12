#!/usr/bin/env bash
# Случайный/directed regression для vhfastmulb16_add_fp16_rtz_lat4.
# Векторы генерируются Python-моделью в build/vhfastmulb16_add_fp16_rtz_lat4_rand.hex.
# Seed можно переопределить через окружение:
#   VEC_SEED=1 ./scripts/run_test_add_fp16_rtz_lat4_rand.sh sim
# См. scripts/tb_lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"   # tb_lib.sh вычислит такой же ROOT заново

SRC_FILE=scripts/fp16_rtz_lat4.src
TB=tests/vhfastmulb16_add_fp16_rtz_lat4_rand_tb.v

# Число векторов должно совпадать с localparam N в тестбенче
# ($readmemh читает ровно N строк) - значение проверяется ниже.
VEC_COUNT=4096
VEC_SEED="${VEC_SEED:-12345}"
VEC_FILE="$ROOT/build/vhfastmulb16_add_fp16_rtz_lat4_rand.hex"

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
        python3 "$SCRIPT_DIR/gen_fp16_vectors.py" \
            --mode rtz --count "$VEC_COUNT" --seed "$VEC_SEED" \
            --out "$VEC_FILE" >/dev/null
        ;;
    clean)
        rm -f "$VEC_FILE" "$VEC_FILE.labels"
        ;;
esac

source "$SCRIPT_DIR/tb_lib.sh"
tb_main "$@"
