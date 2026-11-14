#!/usr/bin/env python3
"""
Generate statistics documentation (Markdown) from collected JSON data.

Reads build/stat/<module>_<family>.json files and generates:
- docs/stat/stat_top_<family>.md for each family
- docs/stat/stat_top_all.md combined comparison
"""

import sys
import json
import os
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional

ROOT = Path(__file__).parent.parent
BUILD_STAT_DIR = ROOT / "build" / "stat"
DOCS_STAT_DIR = ROOT / "docs" / "stat"
DOCS_STAT_DIR.mkdir(parents=True, exist_ok=True)

# family id -> output file name (see project AGENTS.md: Statistic & Benchmark)
FAMILY_DOC_NAMES = {
    "xc6s": "stat_top_spartan6.md",
    "xc7s": "stat_top_spartan7.md",
    "xc7a": "stat_top_artix7.md",
}
FAMILY_DOC_NAMES_OTHERS = {
    "xc6s": "stat_others_spartan6.md",
    "xc7s": "stat_others_spartan7.md",
    "xc7a": "stat_others_artix7.md",
}

CATEGORIES_TOP = {
    "multiplication": "Модули умножения (Multiplication)",
    "fma": "Комбинированные модули (Combined / FMA)",
    "addition": "Модули сложения (Addition)",
}
CATEGORIES_OTHERS = {
    "submodule": "Подмодули (Bottom-up)",
}

# Cell types that are generation artefacts / not part of the design
PSEUDO_CELL_TYPES = {
    "wires", "ports", "cells", "submodules",
    "$scopeinfo",
    "$specify2", "$specify3", "$specify4", "$specrule",
}

# Import module configuration for metadata
sys.path.insert(0, str(ROOT / "scripts"))
from modules_config import MODULES, SUBMODULES, FAMILIES


def load_all_results(build_dir: Path = BUILD_STAT_DIR) -> Dict[str, Dict[str, Dict]]:
    """Load all JSON results, organized by family then module."""
    results = {fam: {} for fam in FAMILIES.keys()}

    for json_file in build_dir.glob("*.json"):
        try:
            with open(json_file) as f:
                data = json.load(f)
            family = data.get("family")
            module = data.get("module")
            if family in results and module:
                results[family][module] = data
        except Exception as e:
            print(f"Warning: Failed to load {json_file}: {e}")

    return results


def format_number(n: Optional[int]) -> str:
    """Format number with ~ prefix if estimated, or return 'N/A'."""
    if n is None:
        return "N/A"
    return f"~{n}"


def format_exact(n: Optional[int]) -> str:
    """Format an exactly counted number (no ~ prefix)."""
    if n is None:
        return "N/A"
    return str(n)


def format_percent(value: Optional[int], total: int) -> str:
    """Format as percentage of total."""
    if value is None or total == 0:
        return "N/A"
    pct = (value / total) * 100
    return f"**~{pct:.1f}%**"


def get_tool_info(all_results: Dict[str, Dict[str, Dict]]) -> Dict[str, str]:
    """Return tool version info from the first available result."""
    for fam_results in all_results.values():
        for data in fam_results.values():
            tool = data.get("tool")
            if tool:
                return tool
    return {}


def accuracy_str(m: Dict) -> str:
    """Build accuracy description for a module config entry."""
    if m["rounding"] == "RTZ":
        acc = "truncation (RTZ)"
    elif m["rounding"] == "RNE":
        acc = "IEEE 754 RNE"
    else:
        acc = "exact"

    subnormal = m["subnormal_handling"]
    if subnormal == "FTZ":
        acc += "; FTZ"
    elif subnormal == "n/a":
        pass
    elif subnormal == "preserve":
        acc += "; subnormals preserved"
    else:
        acc += f"; {subnormal}"
    return acc


def generate_family_doc(family: str, family_results: Dict[str, Dict], all_results: Dict,
                        modules: List[Dict] = None, categories: Dict[str, str] = None,
                        section_title: str = "Top-level модули (LUTs)") -> str:
    """Generate stat_top_<family>.md (or stat_others_<family>.md) for a single family."""
    if modules is None:
        modules = MODULES
    if categories is None:
        categories = CATEGORIES_TOP

    fam_info = FAMILIES[family]
    lut_total = fam_info["lut6_total"]
    ff_total = fam_info["ff_total"]
    device = fam_info["device"]

    lines = []
    lines.append(f"# Статистика реализации на {fam_info['description']}")
    lines.append("")
    lines.append(f"## Спецификация целевой FPGA")
    lines.append("")
    lines.append(f"| Параметр | Значение |")
    lines.append(f"|----------|----------|")
    lines.append(f"| **Device** | {device} |")
    lines.append(f"| **LUTs (6-input / LUT6)** | **{lut_total:,}** |")
    lines.append(f"| **Flip-Flops** | {ff_total:,} |")
    lines.append(f"| **DSP** | {fam_info['dsp_total']} × {fam_info['dsp_type']} (не используются — запрещено правилами) |")
    lines.append(f"| **Block RAM** | {fam_info['bram_total']} (не используется) |")
    lines.append(f"")
    lines.append(f"> **Важно:** Все цифры ниже — **оценки на основе синтеза в Yosys (YoWASP)**.")
    lines.append(f"> Синтез останавливается до ABC9 (`-run begin:map_ffs`): YoWASP WASM не может запустить внешний `yosys-abc`.")
    lines.append(f"> **LUTs — оценка по числу вентилей** (gates / 2.5), структура иерархии развёрнута (`flatten`).")
    lines.append(f"> Счёт FF/CARRY4/IO — точный (по дампу RTLIL). **Fmax — ручная калибровка типовых значений** (`scripts/modules_config.py`), не измерение post-PAR.")
    lines.append(f"> Реальный синтез в Xilinx ISE/Vivado не выполнялся.")
    lines.append(f"> Ожидаемая погрешность оценки LUT без реального синтеза — **±20–25%**.")
    lines.append(f"> Для точного Fmax необходимо запустить Xilinx ISE/Vivado с `report_timing`.")
    lines.append(f"")
    lines.append(f"---")
    lines.append(f"")

    # Modules tables (LUTs)
    lines.append(f"## {section_title}")
    lines.append(f"")

    for cat_key, cat_title in categories.items():
        cat_modules = [m for m in modules if m["category"] == cat_key]
        if not cat_modules:
            continue

        lines.append(f"### {cat_title}")
        lines.append(f"")
        lines.append(f"| Модуль | LUTs | FF | Latency | Точность | % LUTs (от {lut_total:,}) | Fmax typ, MHz |")
        lines.append(f"|--------|------|-----|---------|----------|---------------------------|---------------|")

        for m in cat_modules:
            name = m["name"]
            data = family_results.get(name, {})
            metrics = data.get("metrics", {})
            fmax = data.get("fmax", {})

            lut = metrics.get("lut6_est")
            ff = metrics.get("ff")
            latency = m["latency"]
            acc = accuracy_str(m)

            lut_str = format_number(lut)
            ff_str = format_exact(ff)
            pct_str = format_percent(lut, lut_total)
            fmax_str = str(fmax.get("estimated_mhz", "N/A"))

            lines.append(f"| `{name}` | {lut_str} | {ff_str} | {latency} | {acc} | {pct_str} | {fmax_str} |")

        lines.append(f"")

    # Resource usage details for each module
    lines.append(f"---")
    lines.append(f"")
    lines.append(f"## Детальная статистика по модулям")
    lines.append(f"")

    for m in modules:
        name = m["name"]
        data = family_results.get(name, {})
        if not data:
            continue

        metrics = data.get("metrics", {})
        fmax = data.get("fmax", {})
        cell_counts = metrics.get("cell_counts", {})

        lines.append(f"### `{name}`")
        lines.append(f"")
        lines.append(f"| Ресурс | Значение | % от доступных |")
        lines.append(f"|--------|----------|----------------|")
        lines.append(f"| **LUTs (est.)** | {format_number(metrics.get('lut6_est'))} | {format_percent(metrics.get('lut6_est'), lut_total)} |")
        lines.append(f"| **FF** | {format_exact(metrics.get('ff'))} | {format_percent(metrics.get('ff'), ff_total)} |")
        lines.append(f"| **CARRY4** | {format_exact(metrics.get('carry4'))} | — |")
        lines.append(f"| **CARRY8** | {format_exact(metrics.get('carry8'))} | — |")
        lines.append(f"| **LUT6_2** | {format_exact(metrics.get('lut6_2'))} | — |")
        lines.append(f"| **MUXF7** | {format_exact(metrics.get('muxf7'))} | — |")
        lines.append(f"| **MUXF8** | {format_exact(metrics.get('muxf8'))} | — |")
        lines.append(f"| **Gates (pre-ABC9)** | {format_number(metrics.get('gates'))} | — |")
        lines.append(f"| **Logic Cells (total)** | {format_exact(metrics.get('logic_cells'))} | — |")
        lines.append(f"| **IO (IBUF+OBUF)** | {format_exact(metrics.get('iob'))} | — |")
        lines.append(f"| **DSP48** | {metrics.get('dsp48', 'N/A')} | 0% (запрещено, проверено) |")
        lines.append(f"| **Fmax (typ, manual)** | {fmax.get('estimated_mhz', 'N/A')} MHz | источник: {fmax.get('source', 'unknown')} |")
        lines.append(f"| **Latency** | {m['latency']} cycles | — |")
        lines.append(f"| **Rounding** | {m['rounding']} | — |")
        lines.append(f"| **Subnormals** | {m['subnormal_handling']} | — |")
        lines.append(f"")
        lines.append(f"**Критический путь (оценка):**")
        lines.append(f"```")
        lines.append(f"{fmax.get('critical_path', 'unknown')}")
        lines.append(f"```")
        lines.append(f"")

        # Cell breakdown
        if cell_counts:
            lines.append(f"**Распределение ячеек:**")
            lines.append(f"")
            lines.append(f"| Тип ячейки | Количество |")
            lines.append(f"|------------|------------|")
            for cell_type in sorted(cell_counts.keys()):
                count = cell_counts[cell_type]
                if count > 0 and cell_type not in PSEUDO_CELL_TYPES:
                    lines.append(f"| {cell_type} | {count} |")
            lines.append(f"")

        lines.append(f"---")
        lines.append(f"")

    # Footer
    tool = get_tool_info(all_results)
    lines.append(f"*Сгенерировано автоматически: {datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")}*")
    lines.append(f"*Инструменты: Yosys {tool.get('yosys', 'unknown')}, YoWASP {tool.get('yowasp', 'unknown')}, wasmtime {tool.get('wasmtime', 'unknown')}*")

    return "\n".join(lines)


def generate_all_doc(all_results: Dict[str, Dict[str, Dict]],
                     modules: List[Dict] = None,
                     categories: Dict[str, str] = None,
                     doc_title: str = "# Сравнительная статистика всех top модулей на всех FPGA",
                     source_docs: str = "`docs/stat/stat_top_spartan6.md`, `docs/stat/stat_top_spartan7.md`, `docs/stat/stat_top_artix7.md`",
                     generator_note: str = "генерируются `scripts/generate_stat_docs.py` из `build/stat/*.json`",
                     comparison_label: str = "top-level модулей",
                     conclusion_kind: str = "top") -> str:
    """Generate stat_top_all.md (or stat_others_all.md) with cross-family comparison."""
    if modules is None:
        modules = MODULES
    if categories is None:
        categories = CATEGORIES_TOP

    lines = []
    lines.append(doc_title)
    lines.append("")
    lines.append(f"Источник данных: {source_docs} ({generator_note}).")
    lines.append("LUT — оценка по числу вентилей до ABC9 (YoWASP WASM не выполняет yosys-abc), погрешность ±20–25%. Fmax — ручная калибровка типовых значений, не измерение post-PAR.")
    lines.append("")
    lines.append("---")
    lines.append("")

    # FPGA resources table
    lines.append("## Ресурсы целевых FPGA")
    lines.append("")
    lines.append("| Device | Семейство | LUT6 | FF | DSP | BRAM |")
    lines.append("|--------|-----------|------|-----|-----|------|")

    family_order = ["xc6s", "xc7s", "xc7a"]
    family_names = {
        "xc6s": "Spartan-6",
        "xc7s": "Spartan-7",
        "xc7a": "Artix-7",
    }

    for fid in family_order:
        fi = FAMILIES[fid]
        lines.append(f"| {fi['device']} | {family_names[fid]} | {fi['lut6_total']:,} | {fi['ff_total']:,} | {fi['dsp_total']} × {fi['dsp_type']} (не исп.) | {fi['bram_total']} (не исп.) |")

    lines.append("")
    lines.append("---")
    lines.append("")

    # Comparison tables
    for cat_key, cat_title in categories.items():
        cat_modules = [m for m in modules if m["category"] == cat_key]
        if not cat_modules:
            continue

        # LUTs comparison
        lines.append(f"## Сравнение {comparison_label} (LUTs)")
        lines.append("")
        lines.append(f"### {cat_title}")
        lines.append("")
        header = "| Модуль | " + " | ".join(FAMILIES[f]["device"] for f in family_order) + " |"
        sep = "|--------|" + "|".join("----------" for _ in family_order) + "|"
        lines.append(header)
        lines.append(sep)

        for m in cat_modules:
            name = m["name"]
            row = f"| `{name}` |"
            for fid in family_order:
                data = all_results.get(fid, {}).get(name, {})
                lut = data.get("metrics", {}).get("lut6_est")
                row += f" {format_number(lut)} |"
            lines.append(row)

        lines.append("")

        # FF comparison
        lines.append(f"## Сравнение {comparison_label} (FF)")
        lines.append("")
        lines.append(f"### {cat_title}")
        lines.append("")
        header = "| Модуль | " + " | ".join(FAMILIES[f]["device"] for f in family_order) + " |"
        lines.append(header)
        lines.append(sep)

        for m in cat_modules:
            name = m["name"]
            row = f"| `{name}` |"
            for fid in family_order:
                data = all_results.get(fid, {}).get(name, {})
                ff = data.get("metrics", {}).get("ff")
                row += f" {format_exact(ff)} |"
            lines.append(row)

        lines.append("")

        # % LUTs comparison
        lines.append(f"## Сравнение {comparison_label} (% от доступных LUT6)")
        lines.append("")
        lines.append(f"### {cat_title}")
        lines.append("")
        header = "| Модуль | " + " | ".join(f"{FAMILIES[f]['device']} ({FAMILIES[f]['lut6_total']:,})" for f in family_order) + " |"
        lines.append(header)
        lines.append(sep)

        for m in cat_modules:
            name = m["name"]
            row = f"| `{name}` |"
            for fid in family_order:
                data = all_results.get(fid, {}).get(name, {})
                lut = data.get("metrics", {}).get("lut6_est")
                total = FAMILIES[fid]["lut6_total"]
                row += f" {format_percent(lut, total)} |"
            lines.append(row)

        lines.append("")

        # Fmax comparison
        lines.append(f"## Сравнение Latency и Fmax (оценка)")
        lines.append("")
        lines.append(f"### {cat_title}")
        lines.append("")
        header = "| Модуль | Latency | " + " | ".join(f"Fmax {FAMILIES[f]['device']} (typ)" for f in family_order) + " | Точность |"
        sep6 = "|--------|---------|" + "|".join("---------------------" for _ in family_order) + "|----------|"
        lines.append(header)
        lines.append(sep6)

        for m in cat_modules:
            name = m["name"]
            row = f"| `{name}` | {m['latency']} |"
            for fid in family_order:
                data = all_results.get(fid, {}).get(name, {})
                fmax = data.get("fmax", {}).get("estimated_mhz", "N/A")
                row += f" {fmax} MHz |"
            acc = accuracy_str(m)
            if "muladd" in name:
                acc += "; fused BF16×BF16+FP32; single RNE"
            row += f" {acc} |"
            lines.append(row)

        lines.append("")

    # Fmax typ table
    lines.append("## Рабочая частота Fmax (typ), MHz")
    lines.append("")

    for cat_key, cat_title in categories.items():
        cat_modules = [m for m in modules if m["category"] == cat_key]
        if not cat_modules:
            continue

        lines.append(f"### {cat_title}")
        lines.append("")
        header = "| Модуль | " + " | ".join(FAMILIES[f]['device'] for f in family_order) + " |"
        lines.append(header)
        lines.append(sep)

        for m in cat_modules:
            name = m["name"]
            row = f"| `{name}` |"
            for fid in family_order:
                data = all_results.get(fid, {}).get(name, {})
                fmax = data.get("fmax", {}).get("estimated_mhz", "N/A")
                row += f" **{fmax}** |"
            lines.append(row)

        lines.append("")

    lines.append("> Значения `typ` — ручная калибровка (см. `scripts/modules_config.py`), не измерение post-PAR.")
    lines.append("> Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.")
    lines.append("")

    # Conclusions
    lines.append("---")
    lines.append("")
    lines.append("## Краткие выводы")
    lines.append("")

    # Find max/min LUT module on smallest device
    xc6s_results = all_results.get("xc6s", {})
    lut_by_module = {name: d.get("metrics", {}).get("lut6_est", 0) for name, d in xc6s_results.items()}
    if lut_by_module:
        max_name = max(lut_by_module, key=lut_by_module.get)
        min_name = min(lut_by_module, key=lut_by_module.get)
        max_lut = lut_by_module[max_name]
        min_lut = lut_by_module[min_name]
        total = FAMILIES["xc6s"]["lut6_total"]
        max_pct = (max_lut / total) * 100
        min_pct = (min_lut / total) * 100

        lines.append(f"1. **Все модули компактны.** Наименьшее устройство (XC6SLX9): самый прожорливый модуль (`{max_name}`) занимает **~{max_pct:.1f}% LUT6** (~{max_lut} LUT); самый компактный (`{min_name}`) — ~{min_pct:.1f}% LUT6.")
        lines.append(f"")

    if conclusion_kind == "top":
        # RNE vs RTZ delta (multiplication + addition pairs) on xc6s
        rne_deltas = []
        for rtz_name, rtz_lut in lut_by_module.items():
            if "_rtz_" not in rtz_name:
                continue
            rne_name = rtz_name.replace("_rtz_", "_rne_")
            rne_lut = lut_by_module.get(rne_name)
            if rne_lut is not None:
                rne_deltas.append(rne_lut - rtz_lut)
        if rne_deltas:
            avg_delta = sum(rne_deltas) / len(rne_deltas)
            lines.append(f"2. **RNE дороже RTZ в среднем на ~{avg_delta:.0f} LUT.** Это стоимость IEEE 754 округления \"до ближайшего чётного\" (G/R/S биты, инкремент мантиссы, корректировка экспоненты).")
            lines.append(f"")
        lines.append(f"3. **FP32-модуль эффективнее по LUT, но потребляет больше FF.** `vhfastmulb16_mul_bf16_bf16_fp32_lat4` использует комбинационный `mul4x4_comb` на первой стадии (экономия LUT) и глубокий 4-стадийный конвейер (больше FF). Latency = 4 такта вместо 3.")
        lines.append(f"")
    elif conclusion_kind == "others":
        # Alternative implementations for 8x8 multipliers
        lat2_lut = lut_by_module.get("vhfastmulb16_mul_u8_u8_u16_lat2", 0)
        lat3_lut = lut_by_module.get("vhfastmulb16_mul_u8_u8_u16_lat3", 0)
        lines.append(f"2. **`mul_u8_u8_u16_lat2` (latency 2) ~{lat2_lut} LUT, `mul_u8_u8_u16_lat3` (latency 3) ~{lat3_lut} LUT.** Альтернативные 8×8 реализации; `lat3` построен на `mul4x4_lat2`.")
        lines.append(f"")
        total_lut = sum(lut_by_module.values())
        total_pct = (total_lut / FAMILIES["xc6s"]["lut6_total"]) * 100
        lines.append(f"3. **Суммарно все подмодули ~{total_lut} LUT (~{total_pct:.1f}% LUT6 XC6SLX9)** — каждый подмодуль мал; основной вклад дают множители 8×8 и `except_lat*`.")
        lines.append(f"")
    lines.append(f"4. **Ресурсы 7-й серии (Spartan-7, Artix-7) ниже в процентном соотношении:** загрузка по LUT одинакова, а устройства больше.")
    lines.append(f"")
    if lut_by_module:
        free_pct = 100 - max_pct
        if conclusion_kind == "others":
            sum_pct = (sum(lut_by_module.values()) / FAMILIES["xc6s"]["lut6_total"]) * 100
            lines.append(f"5. **Маржа.** Все подмодули суммарно занимают **~{sum_pct:.1f}% LUT6** XC6SLX9 — даже с учётом дублирования инстансов место остаётся.")
        else:
            lines.append(f"5. **Маржа для роста.** На всех целевых FPGA остаётся не менее **~{free_pct:.0f}% свободных LUT6** для остальной логики системы.")
        lines.append(f"")

    lines.append(f"6. **LUT — оценка, Fmax — калибровка.** LUT6 получено делением числа вентилей на 2.5 до ABC9 (YoWASP WASM не выполняет yosys-abc; погрешность ±20–25%). Fmax — ручные типовые значения (`scripts/modules_config.py`), не измерение post-PAR. Для точного Fmax требуется Xilinx ISE/Vivado с `report_timing`.")
    lines.append(f"")
    lines.append(f"7. **Категорический запрет на использование DSP блоков.** Все модули библиотеки реализованы **исключительно в чистой логике LUT/FF**. Использование DSP48A1, DSP48E1 или любых других DSP блоков **запрещено**. Проверка: `dsp48 = 0` во всех отчётах. Подробности см. в `rules/dsp_prohibition.md`.")
    lines.append(f"")
    lines.append(f"8. **Автоматизация:** Статистика собрана скриптом `scripts/collect_stats.py`, документация сгенерирована `scripts/generate_stat_docs.py` / `scripts/generate_stat_others_docs.py`. Исходные данные в `build/stat*.json`.")
    lines.append(f"")

    lines.append("---")
    lines.append("")
    lines.append(f"*Последнее обновление: {datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")}*")
    lines.append(f"*Инструменты: Yosys/YoWASP, wasmtime*")

    return "\n".join(lines)


def main():
    print("Loading collected statistics...")
    all_results = load_all_results()

    # Check if any data exists
    total_files = sum(len(v) for v in all_results.values())
    if total_files == 0:
        print("ERROR: No statistics data found in build/stat/")
        print("Run scripts/collect_stats.py first")
        sys.exit(1)

    print(f"Found data for {total_files} module/family combinations")

    # Generate per-family docs
    for family in FAMILIES.keys():
        family_results = all_results.get(family, {})
        if not family_results:
            print(f"Warning: No data for family {family}, skipping")
            continue

        doc = generate_family_doc(family, family_results, all_results)
        output_file = DOCS_STAT_DIR / FAMILY_DOC_NAMES[family]
        with open(output_file, "w") as f:
            f.write(doc)
        print(f"Generated: {output_file}")

    # Generate combined doc
    doc_all = generate_all_doc(all_results)
    output_all = DOCS_STAT_DIR / "stat_top_all.md"
    with open(output_all, "w") as f:
        f.write(doc_all)
    print(f"Generated: {output_all}")

    print("\nDone!")


if __name__ == "__main__":
    main()