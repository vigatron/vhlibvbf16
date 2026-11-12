#!/usr/bin/env python3
# =============================================================================
# checkvectors_mul_bf16_bf16_fp32.py
# Проверка тестовых векторов умножения BF16 (A * B = F32)
# Сравнивает вычисленные результаты (BF16 RNE + точный F32) с данными из
# testvalues/test_values_mul_bf16_bf16_fp32/test_values_mul_bf16_bf16_fp32.json
# =============================================================================

import sys
import json
import os
import math
import struct
import argparse

# ---------------------------------------------------------------------------
# BF16 константы (формат: [15] sign, [14:7] exp bias=127, [6:0] frac)
# ---------------------------------------------------------------------------
BF16_EXP_MAX    = 255
BF16_SIGN_MASK  = 0x8000
BF16_EXP_MASK   = 0x7F80   # биты [14:7]
BF16_FRAC_MASK  = 0x007F   # биты [6:0]

BF16_QUIET_BIT  = 1 << 6   # 0x40, quiet bit for NaN

# ---------------------------------------------------------------------------
# F32 константы (формат: [31] sign, [30:23] exp bias=127, [22:0] frac)
# ---------------------------------------------------------------------------
F32_EXP_MAX     = 255
F32_SIGN_MASK   = 0x80000000
F32_EXP_MASK    = 0x7F800000   # биты [30:23]
F32_FRAC_MASK   = 0x007FFFFF   # биты [22:0]

F32_QUIET_BIT   = 1 << 22      # quiet bit for NaN

QNAN_BF16 = 0x7FC0
QNAN_F32  = 0x7FC00000
INF_BF16  = 0x7F80
INF_F32   = 0x7F800000

# ---------------------------------------------------------------------------
# Вспомогательные функции BF16
# ---------------------------------------------------------------------------

def bf16_unpack(u16):
    """@brief Распаковывает BF16 на sign, exp, frac."""
    sign = (u16 & BF16_SIGN_MASK) >> 15
    exp  = (u16 & BF16_EXP_MASK) >> 7
    frac =  u16 & BF16_FRAC_MASK
    return sign, exp, frac


def bf16_pack(sign, exp, frac):
    """@brief Собирает BF16 из sign, exp, frac."""
    return (sign << 15) | (exp << 7) | frac


def bf16_is_nan(u16):
    """@brief Признак NaN для BF16."""
    s, e, f = bf16_unpack(u16)
    return e == BF16_EXP_MAX and f != 0


def bf16_is_inf(u16):
    """@brief Признак бесконечности для BF16."""
    s, e, f = bf16_unpack(u16)
    return e == BF16_EXP_MAX and f == 0


def bf16_is_zero(u16):
    """@brief Признак нуля (+0.0 или -0.0) для BF16."""
    s, e, f = bf16_unpack(u16)
    return e == 0 and f == 0


# ---------------------------------------------------------------------------
# Конвертация BF16 <-> float
# ---------------------------------------------------------------------------

def bf16_to_float(u16):
    """@brief Конвертирует BF16 в float (используется только для проверочного скрипта)."""
    s, e, f = bf16_unpack(u16)
    if e == 0 and f == 0:
        return -0.0 if s else 0.0
    if e == 0:
        # Subnormal: 0.frac * 2^(1 - 127) = frac * 2^(-7) * 2^(-126) = frac * 2^(-133)
        return (-1.0 if s else 1.0) * f * 2.0**(-133)
    if e == BF16_EXP_MAX:
        if f == 0:
            return float('-inf') if s else float('inf')
        return float('nan')
    # Normal: (1 + frac/128) * 2^(exp - 127)
    return (-1.0 if s else 1.0) * (1.0 + f / 128.0) * 2.0**(e - 127)


def float_to_bf16_rne(val):
    """
    @brief Конвертирует float в BF16 с округлением RNE (Round-to-Nearest-Even).
    """
    if val == 0.0:
        return 0x0000
    if val != val:  # NaN
        return QNAN_BF16
    if val == float('inf'):
        return INF_BF16
    if val == float('-inf'):
        return 0xFF80

    sign = 1 if val < 0 else 0
    val = abs(val)

    # frexp: val = m * 2^e, 0.5 <= m < 1.0
    m, e = math.frexp(val)
    # Переводим в m2 = 2*m (1.0 <= m2 < 2.0), e2 = e - 1
    m2 = m * 2.0
    e2 = e - 1
    exp_biased = e2 + 127

    # Переполнение
    if exp_biased >= BF16_EXP_MAX:
        return bf16_pack(sign, BF16_EXP_MAX, 0)  # Inf

    # Поднормальный результат
    if exp_biased <= 0:
        # val = frac * 2^(-133)  =>  frac = val * 2^133
        raw_frac = val * 2.0**133
        frac_int = int(raw_frac)
        frac_rem = raw_frac - frac_int
        # RNE rounding
        if frac_rem > 0.5 or (frac_rem == 0.5 and (frac_int & 1)):
            frac_int += 1
        if frac_int > 0x7F:
            # Переполнение поднормального -> минимальный нормальный
            return bf16_pack(sign, 1, 0)
        return bf16_pack(sign, 0, frac_int)

    # Нормальный результат
    # m2 = 1 + frac/128  =>  frac = (m2 - 1) * 128
    # Расширяем на 3 бита для G/R/S: raw_ext = frac * 8
    raw_ext = (m2 - 1.0) * 128.0 * 8.0
    frac_ext = int(raw_ext)
    G = (frac_ext >> 2) & 1
    R = (frac_ext >> 1) & 1
    S = frac_ext & 1

    frac_kept = frac_ext >> 3  # 7 бит

    inc = 0
    if G:
        if R or S:
            inc = 1
        else:
            # Tie-to-even
            inc = frac_kept & 1

    frac_rounded = frac_kept + inc
    if frac_rounded > 0x7F:
        # Перенос мантиссы
        frac_rounded = 0
        exp_biased += 1
        if exp_biased >= BF16_EXP_MAX:
            return bf16_pack(sign, BF16_EXP_MAX, 0)  # Inf

    return bf16_pack(sign, exp_biased, frac_rounded)


# ---------------------------------------------------------------------------
# Конвертация F32 helpers (для вывода и отладки)
# ---------------------------------------------------------------------------

def f32_pack(sign, exp, frac):
    """@brief Собирает F32 из sign, exp, frac."""
    return (sign << 31) | (exp << 23) | frac


def f32_to_float(u32):
    """@brief Декодирует binary32 слово в Python float."""
    return struct.unpack("<f", struct.pack("<I", u32))[0]


def f32_label(u32):
    """@brief Читаемое представление binary32 слова (число, +Inf, -Inf, quiet NaN)."""
    v = f32_to_float(u32)
    if math.isnan(v):
        return "quiet NaN"
    if math.isinf(v):
        return "+Inf" if v > 0 else "-Inf"
    if v == 0.0:
        return "-0.0" if (u32 >> 31) else "+0.0"
    return repr(v)


# ---------------------------------------------------------------------------
# Умножение BF16 x BF16 -> (BF16 RNE, F32 exact)
# ---------------------------------------------------------------------------

def bf16_mul(a16, b16):
    """
    @brief Умножает два BF16 числа A * B.

    Special cases по IEEE-754:
      * NaN на входе -> quiet NaN (0x7FC0 / 0x7FC00000);
      * Inf * 0 (или 0 * Inf) -> quiet NaN;
      * Inf * finite -> Inf со знаком = XOR знаков;
      * 0 * finite -> 0 со знаком = XOR знаков.

    @return Словарь {'bf16': <результат BF16 округлённый RNE>,
                    'f32':  <точный продукт, закодированный как IEEE-754 binary32>}.
    """
    a_nan = bf16_is_nan(a16)
    b_nan = bf16_is_nan(b16)
    a_inf = bf16_is_inf(a16)
    b_inf = bf16_is_inf(b16)
    a_zero = bf16_is_zero(a16)
    b_zero = bf16_is_zero(b16)

    if a_nan or b_nan:
        return {'bf16': QNAN_BF16, 'f32': QNAN_F32}

    if (a_inf and b_zero) or (b_inf and a_zero):
        return {'bf16': QNAN_BF16, 'f32': QNAN_F32}

    sa, _, _ = bf16_unpack(a16)
    sb, _, _ = bf16_unpack(b16)
    sign = sa ^ sb

    if a_inf or b_inf:
        res_bf16 = bf16_pack(sign, BF16_EXP_MAX, 0)
        res_f32  = (sign << 31) | INF_F32
        return {'bf16': res_bf16, 'f32': res_f32}

    if a_zero or b_zero:
        res_bf16 = bf16_pack(sign, 0, 0)
        res_f32  = sign << 31
        return {'bf16': res_bf16, 'f32': res_f32}

    # Оба конечных: конвертируем в float, умножаем, конвертируем обратно
    fa = bf16_to_float(a16)
    fb = bf16_to_float(b16)
    result = fa * fb

    # Точный продукт в F32 (одиночное округление до binary32)
    try:
        f32_bits = struct.unpack("<I", struct.pack("<f", result))[0]
    except OverflowError:
        # Результат не влезает в F32 -> Inf с вычисленным знаком
        f32_bits = (sign << 31) | INF_F32

    bf16_rne = float_to_bf16_rne(result)
    return {'bf16': bf16_rne, 'f32': f32_bits}


# ---------------------------------------------------------------------------
# Загрузка тестовых векторов
# ---------------------------------------------------------------------------

def load_vectors(json_path):
    """@brief Загружает векторы из JSON файла."""
    with open(json_path, 'r') as f:
        data = json.load(f)
    return data['test_vectors'] + data.get('extended_vectors', [])


def hex_to_int(hstr):
    """
    @brief Преобразует строку вида '16'h3F80' или '0x3F800000' в int.
    """
    hstr = hstr.replace('16\'h', '').replace('"', '').strip()
    if hstr.lower().startswith('0x'):
        hstr = hstr[2:]
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

    result = bf16_mul(a_val, b_val)
    calc_bf16 = result['bf16']
    calc_f32  = result['f32']

    for vec in vectors:
        va = hex_to_int(vec['input_a']['bf16'])
        vb = hex_to_int(vec['input_b']['bf16'])
        if va == a_val and vb == b_val:
            exp_bf16 = hex_to_int(vec['output_c']['bf16'])
            exp_f32  = hex_to_int(vec['output_c']['float32']['hex'])

            ok_bf16 = (calc_bf16 == exp_bf16)
            ok_f32  = (calc_f32 == exp_f32)

            if verbose:
                print(f"A={a_hex} B={b_hex}")
                print(f"  BF16: calc=0x{calc_bf16:04X} expected=0x{exp_bf16:04X} {'OK' if ok_bf16 else 'FAIL'}")
                print(f"  F32:  calc=0x{calc_f32:08X} expected=0x{exp_f32:08X} ({f32_label(calc_f32)}) {'OK' if ok_f32 else 'FAIL'}")

            if ok_bf16 and ok_f32:
                return True, (f"PASS: {a_hex} * {b_hex} "
                              f"-> BF16=0x{calc_bf16:04X} F32=0x{calc_f32:08X}")
            else:
                return False, (f"FAIL: {a_hex} * {b_hex} "
                               f"BF16: calc=0x{calc_bf16:04X} exp=0x{exp_bf16:04X}, "
                               f"F32: calc=0x{calc_f32:08X} exp=0x{exp_f32:08X}")

    return False, f"Pair {a_hex} * {b_hex} not found in test vectors"


def check_all(vectors, verbose=False):
    """@brief Проверяет все векторы из JSON файла."""
    passed = 0
    failed = 0

    for vec in vectors:
        a_hex = vec['input_a']['bf16']
        b_hex = vec['input_b']['bf16']
        ok, msg = check_pair(a_hex, b_hex, vectors, verbose=verbose)
        if ok:
            passed += 1
            if verbose:
                print(f"[{vec.get('no', '')}] {msg}")
        else:
            failed += 1
            print(f"[{vec.get('no', '')}] {msg}")

    return passed, failed


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Проверка тестовых векторов BF16 умножения (A * B = F32)'
    )
    parser.add_argument('a', nargs='?', help='Первое BF16 число (например, 16\'h3F80)')
    parser.add_argument('b', nargs='?', help='Второе BF16 число (например, 16\'h3F80)')
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
        'test_values_mul_bf16_bf16_fp32',
        'test_values_mul_bf16_bf16_fp32.json'
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
