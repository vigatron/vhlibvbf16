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

# Список скриптов тестбенчей (без tb_lib.sh) - через GLOB, включая подпапки
# компонентов (например, scripts/fma/).
shopt -s nullglob globstar
TEST_SCRIPTS=( "$SCRIPT_DIR"/**/run_test_*.sh )

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
        for script in "${TEST_SCRIPTS[@]}"; do
            "$script" clean || true
        done
        # Заметаем осиротевшие артефакты от прежних имён тестов.
        # build/ и logs/ в .gitignore; visual/ (gtkw) не трогаем - см. AGENTS.md.
        rm -f "$ROOT"/build/* "$ROOT"/logs/*
        echo "============================================================"
        exit 0
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
            echo "  $(basename "$s")"
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
    script_name="$(basename "$script")"

    if [ ! -f "$script" ]; then
        echo "WARNING: $script_name не найден, пропуск" >&2
        continue
    fi

    echo ""
    echo ">>> Запуск: $script_name $CMD"
    echo "------------------------------------------------------------"

    if "$script" "$CMD"; then
        echo "------------------------------------------------------------"
        echo "<<< $script_name: PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "------------------------------------------------------------"
        echo "<<< $script_name: FAILED"
        FAILED=$((FAILED + 1))
        FAILED_LIST+=("$script_name")
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