#!/usr/bin/env python3
# =============================================================================
# checkvectors_add_fp16_fp16_fp16.py
# Проверка тестовых векторов сложения FP16 (A + B = C)
# Сравнивает вычисленные результаты RNE/RTZ с данными из
# testvalues/test_values_add_fp16_fp16_fp16/test_values_add_fp16_fp16_fp16.json
# =============================================================================

import sys
import json
import os
import math
import argparse

# ---------------------------------------------------------------------------
# FP16 константы (формат: [15] sign, [14:10] exp bias=15, [9:0] frac)
# ---------------------------------------------------------------------------
FP16_EXP_MAX    = 31
FP16_SIGN_MASK  = 0x8000
FP16_EXP_MASK   = 0x7C00   # биты [14:10]
FP16_FRAC_MASK  = 0x03FF   # биты [9:0]

FP16_QUIET_BIT  = 1 << 9   # 0x200, quiet bit for NaN

# ---------------------------------------------------------------------------
# Вспомогательные функции FP16
# ---------------------------------------------------------------------------

def fp16_unpack(u16):
    """@brief Распаковывает FP16 на sign, exp, frac."""
    sign = (u16 & FP16_SIGN_MASK) >> 15
    exp  = (u16 & FP16_EXP_MASK) >> 10
    frac =  u16 & FP16_FRAC_MASK
    return sign, exp, frac


def fp16_pack(sign, exp, frac):
    """@brief Собирает FP16 из sign, exp, frac."""
    return (sign << 15) | (exp << 10) | frac


def fp16_is_nan(u16):
    s, e, f = fp16_unpack(u16)
    return e == FP16_EXP_MAX and f != 0


def fp16_is_inf(u16):
    s, e, f = fp16_unpack(u16)
    return e == FP16_EXP_MAX and f == 0


def fp16_is_zero(u16):
    s, e, f = fp16_unpack(u16)
    return e == 0 and f == 0


# ---------------------------------------------------------------------------
# Конвертация FP16 <-> float
# ---------------------------------------------------------------------------

def fp16_to_float(u16):
    """@brief Конвертирует FP16 в float (используется только для проверочного скрипта)."""
    s, e, f = fp16_unpack(u16)
    if e == 0 and f == 0:
        return -0.0 if s else 0.0
    if e == 0:
        # Subnormal: 0.frac * 2^(1 - 15) = frac * 2^(-10) * 2^(-14) = frac * 2^(-24)
        return (-1.0 if s else 1.0) * f * 2.0**(-24)
    if e == FP16_EXP_MAX:
        if f == 0:
            return float('-inf') if s else float('inf')
        return float('nan')
    # Normal: (1 + frac/1024) * 2^(exp - 15)
    return (-1.0 if s else 1.0) * (1.0 + f / 1024.0) * 2.0**(e - 15)


def float_to_fp16_rne(val):
    """
    @brief Конвертирует float в FP16 с округлением RNE (Round-to-Nearest-Even).
    """
    if val == 0.0:
        return 0x0000
    if val != val:  # NaN
        return 0x7E00
    if val == float('inf'):
        return 0x7C00
    if val == float('-inf'):
        return 0xFC00

    sign = 1 if val < 0 else 0
    val = abs(val)

    # frexp: val = m * 2^e, 0.5 <= m < 1.0
    m, e = math.frexp(val)
    # Переводим в m2 = 2*m (1.0 <= m2 < 2.0), e2 = e - 1
    m2 = m * 2.0
    e2 = e - 1
    exp_biased = e2 + 15

    # Переполнение
    if exp_biased >= FP16_EXP_MAX:
        return fp16_pack(sign, FP16_EXP_MAX, 0)  # Inf

    # Поднормальный результат
    if exp_biased <= 0:
        # val = frac * 2^(-24)  =>  frac = val * 2^24
        raw_frac = val * 2.0**24
        frac_int = int(raw_frac)
        frac_rem = raw_frac - frac_int
        # RNE rounding
        if frac_rem > 0.5 or (frac_rem == 0.5 and (frac_int & 1)):
            frac_int += 1
        if frac_int > 0x3FF:
            # Переполнение поднормального -> минимальный нормальный
            return fp16_pack(sign, 1, 0)
        return fp16_pack(sign, 0, frac_int)

    # Нормальный результат
    # m2 = 1 + frac/1024  =>  frac = (m2 - 1) * 1024
    # Расширяем на 3 бита для G/R/S: raw_ext = frac * 8
    raw_ext = (m2 - 1.0) * 1024.0 * 8.0
    frac_ext = int(raw_ext)
    G = (frac_ext >> 2) & 1
    R = (frac_ext >> 1) & 1
    S = frac_ext & 1

    frac_kept = frac_ext >> 3  # 10 бит

    inc = 0
    if G:
        if R or S:
            inc = 1
        else:
            # Tie-to-even
            inc = frac_kept & 1

    frac_rounded = frac_kept + inc
    if frac_rounded > 0x3FF:
        # Перенос мантиссы
        frac_rounded = 0
        exp_biased += 1
        if exp_biased >= FP16_EXP_MAX:
            return fp16_pack(sign, FP16_EXP_MAX, 0)  # Inf

    return fp16_pack(sign, exp_biased, frac_rounded)


def float_to_fp16_rtz(val):
    """
    @brief Конвертирует float в FP16 с округлением RTZ (Round Toward Zero / отсечение).
    """
    if val == 0.0:
        return 0x0000
    if val != val:
        return 0x7E00
    if val == float('inf'):
        return 0x7C00
    if val == float('-inf'):
        return 0xFC00

    sign = 1 if val < 0 else 0
    val = abs(val)

    m, e = math.frexp(val)
    m2 = m * 2.0
    e2 = e - 1
    exp_biased = e2 + 15

    # Переполнение: результат не влазит в FP16 -> Inf (соглашение DUT для сложения)
    if exp_biased >= FP16_EXP_MAX:
        return fp16_pack(sign, FP16_EXP_MAX, 0)

    # Поднормальный результат: отсечение
    if exp_biased <= 0:
        raw_frac = val * 2.0**24
        frac_int = int(raw_frac)  # просто отсекаем
        if frac_int > 0x3FF:
            frac_int = 0x3FF
        return fp16_pack(sign, 0, frac_int)

    # Нормальный результат: отсечение защитных битов
    raw_ext = (m2 - 1.0) * 1024.0 * 8.0
    frac_ext = int(raw_ext)  # отсечение
    frac_kept = frac_ext >> 3

    if frac_kept > 0x3FF:
        frac_kept = 0x3FF

    return fp16_pack(sign, exp_biased, frac_kept)


def fp16_qnan_from(u16):
    """
    @brief Построить qNaN из операнда: знак и полея сохраняются,
           quiet bit (frac[9]) принудительно выставляется в 1.
    """
    s = (u16 >> 15) & 1
    return (s << 15) | FP16_EXP_MASK | ((u16 & FP16_FRAC_MASK) | FP16_QUIET_BIT)


def fp16_add(a16, b16):
    """
    @brief Выполняет сложение двух FP16 чисел A + B.

    Соглашения DUT (см. testvalues/.../test_values_add_fp16_fp16_fp16.json):
      * NaN на входе -> qNaN с знаком и полезной нагрузкой из операнда-НаN,
        quiet bit принудительно = 1;
      * Inf + (-Inf) -> qNaN со знаком и полезной нагрузкой из операнда B;
      * Inf * конечное -> Inf со знаком = XOR знаков;
      * оба операнда нули -> знак = sign_a & sign_b (IEEE-754 default);
      * точное категорирование ненулевых операндов -> +0;
      * переполнение -> Inf (для обоих режимов округления).

    @return Словарь {'rne': <result_rne>, 'rtz': <result_rtz>}.
    """
    # Спецслучаи (NaN, Inf, нули) обрабатываются по IEEE-754
    a_nan = fp16_is_nan(a16)
    b_nan = fp16_is_nan(b16)
    a_inf = fp16_is_inf(a16)
    b_inf = fp16_is_inf(b16)
    a_zero = fp16_is_zero(a16)
    b_zero = fp16_is_zero(b16)

    # --- NaN приоритет: знак и полезная нагрузка сохраняются, quiet bit = 1 ---
    if a_nan:
        res = fp16_qnan_from(a16)
        return {'rne': res, 'rtz': res}
    if b_nan:
        res = fp16_qnan_from(b16)
        return {'rne': res, 'rtz': res}

    # --- Inf ---
    if a_inf and b_inf:
        sa, _, _ = fp16_unpack(a16)
        sb, _, _ = fp16_unpack(b16)
        if sa == sb:
            res = fp16_pack(sa, FP16_EXP_MAX, 0)
            return {'rne': res, 'rtz': res}
        else:
            # Inf + (-Inf) -> qNaN со знаком и полезной нагрузкой из операнда B
            res = fp16_qnan_from(b16)
            return {'rne': res, 'rtz': res}

    if a_inf:
        sa, _, _ = fp16_unpack(a16)
        res = fp16_pack(sa, FP16_EXP_MAX, 0)
        return {'rne': res, 'rtz': res}

    if b_inf:
        sb, _, _ = fp16_unpack(b16)
        res = fp16_pack(sb, FP16_EXP_MAX, 0)
        return {'rne': res, 'rtz': res}

    # --- zero ---
    if a_zero and b_zero:
        sa, _, _ = fp16_unpack(a16)
        sb, _, _ = fp16_unpack(b16)
        if sa == sb:
            res = fp16_pack(sa, 0, 0)
        else:
            res = fp16_pack(0, 0, 0)  # +0 + (-0) = +0
        return {'rne': res, 'rtz': res}

    if a_zero:
        return {'rne': b16, 'rtz': b16}

    if b_zero:
        return {'rne': a16, 'rtz': a16}

    # Оба конечных: конвертируем в float, складываем, конвертируем обратно
    fa = fp16_to_float(a16)
    fb = fp16_to_float(b16)
    result = fa + fb

    rne = float_to_fp16_rne(result)
    rtz = float_to_fp16_rtz(result)
    return {'rne': rne, 'rtz': rtz}


# ---------------------------------------------------------------------------
# Загрузка тестовых векторов
# ---------------------------------------------------------------------------

def load_vectors(json_path):
    """@brief Загружает векторы из JSON файла."""
    with open(json_path, 'r') as f:
        data = json.load(f)
    return data['vectors']


def hex_to_int(hstr):
    """@brief Преобразует строку вида '16'h3C00' в int."""
    hstr = hstr.replace('16\'h', '').replace('"', '').strip()
    return int(hstr, 16)


# ---------------------------------------------------------------------------
# Основная логика проверки
# ---------------------------------------------------------------------------

def check_pair(a_hex, b_hex, vectors, verbose=False):
    """
    @brief Проверяет пару (A, B) против тестовых векторов.

    @return (ok, message).
    """
    a_val = hex_to_int(a_hex)
    b_val = hex_to_int(b_hex)

    result = fp16_add(a_val, b_val)
    calc_rne = result['rne']
    calc_rtz = result['rtz']

    for vec in vectors:
        if hex_to_int(vec['a']) == a_val and hex_to_int(vec['b']) == b_val:
            exp_rne = hex_to_int(vec['crne'])
            exp_rtz = hex_to_int(vec['crtz'])

            ok_rne = (calc_rne == exp_rne)
            ok_rtz = (calc_rtz == exp_rtz)

            if verbose:
                print(f"A={a_hex} B={b_hex}")
                print(f"  RNE: calc=0x{calc_rne:04X} expected=0x{exp_rne:04X} {'OK' if ok_rne else 'FAIL'}")
                print(f"  RTZ: calc=0x{calc_rtz:04X} expected=0x{exp_rtz:04X} {'OK' if ok_rtz else 'FAIL'}")

            if ok_rne and ok_rtz:
                return True, f"PASS: {a_hex} + {b_hex} -> RNE=0x{calc_rne:04X} RTZ=0x{calc_rtz:04X}"
            else:
                return False, (f"FAIL: {a_hex} + {b_hex} "
                               f"RNE: calc=0x{calc_rne:04X} exp=0x{exp_rne:04X}, "
                               f"RTZ: calc=0x{calc_rtz:04X} exp=0x{exp_rtz:04X}")

    return False, f"Pair {a_hex} + {b_hex} not found in test vectors"


def check_all(vectors, verbose=False):
    """@brief Проверяет все векторы из файла."""
    passed = 0
    failed = 0

    for vec in vectors:
        a_hex = vec['a']
        b_hex = vec['b']
        ok, msg = check_pair(a_hex, b_hex, vectors, verbose=verbose)
        if ok:
            passed += 1
            if verbose:
                print(f"[{vec.get('desc', '')}] {msg}")
        else:
            failed += 1
            print(f"[{vec.get('desc', '')}] {msg}")

    return passed, failed


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Проверка тестовых векторов FP16 сложения (A + B = C)'
    )
    parser.add_argument('a', nargs='?', help='Первое FP16 число (например, 16\'h3C00)')
    parser.add_argument('b', nargs='?', help='Второе FP16 число (например, 16\'h3C00)')
    parser.add_argument('--all', action='store_true',
                        help='Проверить все векторы из JSON файла')
    parser.add_argument('--json', default=None,
                        help='Путь к JSON файлу с векторами')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Подробный вывод')

    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    default_json = os.path.join(
        project_root,
        'testvalues',
        'test_values_add_fp16_fp16_fp16',
        'test_values_add_fp16_fp16_fp16.json'
    )
    json_path = args.json if args.json else default_json

    if not os.path.exists(json_path):
        print(f"ERROR: JSON файл не найден: {json_path}")
        sys.exit(1)

    vectors = load_vectors(json_path)

    if args.all:
        passed, failed = check_all(vectors, verbose=args.verbose)
        print(f"\n{'='*50}")
        print(f"ИТОГО: PASSED={passed}, FAILED={failed}, TOTAL={passed + failed}")
        if failed > 0:
            sys.exit(1)
    elif args.a and args.b:
        ok, msg = check_pair(args.a, args.b, vectors, verbose=True)
        print(msg)
        if not ok:
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
