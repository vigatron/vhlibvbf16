#!/usr/bin/env bash
# Общий движок сборки и запуска тестбенчей (включая визуализацию в gtkwave).
# Напрямую не запускается: подключается из tests/run_test_*.sh
#
# Обёртка обязана задать до подключения:
#   NAME        - базовое имя артефактов:
#                 build/<NAME>.vvp, build/<NAME>.vcd, logs/<NAME>.log
#   GTKW_NAME     - базовое имя файла visual/<GTKW_NAME>.gtkw
#   SRC         - массив исходников DUT относительно корня проекта
#   TB          - путь тестбенча относительно корня проекта
#   RESULT_MODE - критерий успеха:
#                   passed  - в логе должна быть строка "TEST PASSED"
#                   no_fail - в логе должен быть "PASSED" и не быть "x FAILED"
#
# Использование: run_test_*.sh [sim|wave|clean|help]
#   sim   (по умолчанию, он же all) - собрать и прогнать тестбенч
#   wave  - прогнать тестбенч и открыть gtkwave
#   clean - удалить артефакты сборки и лог
set -euo pipefail

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_LIB_DIR/.." && pwd)"
BUILD="$ROOT/build"
LOG_DIR="$ROOT/logs"

SIM="$BUILD/$NAME.vvp"
VCD="$BUILD/$NAME.vcd"
LOG="$LOG_DIR/$NAME.log"
GTKW="$ROOT/visual/$GTKW_NAME.gtkw"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: не найден $1" >&2
        exit 1
    }
}

check_config() {
    local var
    for var in NAME GTKW_NAME TB RESULT_MODE; do
        if [ -z "${!var:-}" ]; then
            echo "ERROR: обёртка не задала $var" >&2
            exit 1
        fi
    done
    if [ "${#SRC[@]}" -eq 0 ]; then
        echo "ERROR: обёртка не задала список исходников SRC" >&2
        exit 1
    fi
    case "$RESULT_MODE" in
        passed|no_fail) ;;
        *)
            echo "ERROR: неизвестный RESULT_MODE=$RESULT_MODE" >&2
            exit 1
            ;;
    esac
}

build() {
    need iverilog
    mkdir -p "$BUILD" "$LOG_DIR"

    local -a files=()
    local f
    for f in "${SRC[@]}"; do
        files+=("$ROOT/$f")
    done
    files+=("$ROOT/$TB")

    iverilog -g2012 -o "$SIM" "${files[@]}"
}

# Критерий успеха прогона.
check_result() {
    case "$RESULT_MODE" in
        passed)
            grep -q "TEST PASSED" "$LOG"
            ;;
        no_fail)
            grep -q "PASSED" "$LOG" && ! grep -q "x FAILED" "$LOG"
            ;;
    esac
}

# vvp запускается из корня проекта: $dumpfile в TB задан
# относительно корня ("build/<NAME>.vcd").
sim() {
    check_config
    build
    ( cd "$ROOT" && vvp "$SIM" ) | tee "$LOG"

    if ! check_result; then
        echo "RESULT: FAILED (лог: $LOG)"
        return 1
    fi

    echo "RESULT: PASSED"
}

# gtkwave запускается из корня проекта, чтобы нашлись
# build/<NAME>.vcd и visual/<GTKW_NAME>.gtkw.
wave() {
    if ! sim; then
        echo "WARNING: тестбенч не прошёл проверку, gtkwave открывается для анализа" >&2
    fi
    need gtkwave
    ( cd "$ROOT" && gtkwave "$VCD" "$GTKW" >/dev/null 2>&1 & )
    echo "gtkwave: осциллограмма $VCD"
}

clean() {
    rm -f "$SIM" "$VCD" "$LOG"
}

usage() {
    cat <<EOF
Использование: $(basename "$0") [команда]

Список сигналов gtkwave: visual/$GTKW_NAME.gtkw
Тестбенч: $TB
Артефакты: build/$NAME.vvp, build/$NAME.vcd
Лог:       logs/$NAME.log

Команды:
  sim   (по умолчанию, он же all) - собрать и прогнать тестбенч
  wave  - прогнать тестбенч и открыть gtkwave
  clean - удалить артефакты сборки и лог
  help  - показать эту справку
EOF
}

tb_main() {
    case "${1:-sim}" in
        all|sim)
            sim
            ;;
        wave)
            wave
            ;;
        clean)
            clean
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "ERROR: неизвестная команда: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
}
