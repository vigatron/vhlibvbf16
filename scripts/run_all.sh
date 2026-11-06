#!/usr/bin/env bash
# =============================================================
# run_all.sh - Запуск всех тестбенчей проекта vhlibvbf16
# =============================================================
# Использование:
#   ./scripts/run_all.sh [sim|wave|clean|help]
#   sim   (по умолчанию) - собрать и прогнать все тестбенчи
#   wave  - прогнать и открыть gtkwave для каждого
#   clean - удалить все артефакты сборки и логов
#   help  - показать эту справку
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Список скриптов тестбенчей (без tb_lib.sh)
TEST_SCRIPTS=(
    "run_test_add8x8_lat2.sh"
    "run_test_except_lat2.sh"
    "run_test_except_lat3.sh"
    "run_test_flags_lat1.sh"
    "run_test_flags_lat2.sh"
    "run_test_mul4x4.sh"
    "run_test_mul8x8.sh"
    "run_test_sign.sh"
    "run_test_mul_fb16_rne_lat3.sh"
    "run_test_mul_fb16_rtz_lat3.sh"
)

CMD="${1:-sim}"

case "$CMD" in
    sim|all)
        echo "============================================================"
        echo "Запуск всех тестбенчей (sim)..."
        echo "============================================================"
        ;;
    wave)
        echo "============================================================"
        echo "Запуск всех тестбенчей с визуализацией (wave)..."
        echo "============================================================"
        ;;
    clean)
        echo "============================================================"
        echo "Очистка всех артефактов..."
        echo "============================================================"
        ;;
    -h|--help|help)
        cat <<EOF
Использование: $0 [команда]

Команды:
  sim   (по умолчанию, он же all) - собрать и прогнать все тестбенчи
  wave  - прогнать тестбенчи и открыть gtkwave для каждого
  clean - удалить все артефакты сборки и логов
  help  - показать эту справку

Список тестбенчей:
EOF
        for s in "${TEST_SCRIPTS[@]}"; do
            echo "  $s"
        done
        exit 0
        ;;
    *)
        echo "ERROR: неизвестная команда: $CMD" >&2
        echo "Использование: $0 [sim|wave|clean|help]" >&2
        exit 2
        ;;
esac

# Запуск каждого тестбенча
PASSED=0
FAILED=0
FAILED_LIST=()

for script in "${TEST_SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"
    
    if [ ! -f "$script_path" ]; then
        echo "WARNING: $script не найден, пропуск" >&2
        continue
    fi
    
    echo ""
    echo ">>> Запуск: $script $CMD"
    echo "------------------------------------------------------------"
    
    if "$script_path" "$CMD"; then
        echo "------------------------------------------------------------"
        echo "<<< $script: PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "------------------------------------------------------------"
        echo "<<< $script: FAILED"
        FAILED=$((FAILED + 1))
        FAILED_LIST+=("$script")
    fi
done

echo ""
echo "============================================================"
echo "ИТОГО: PASSED=$PASSED, FAILED=$FAILED"
if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    echo "Проваленные:"
    for f in "${FAILED_LIST[@]}"; do
        echo "  $f"
    done
    echo "============================================================"
    exit 1
fi
echo "============================================================"
exit 0