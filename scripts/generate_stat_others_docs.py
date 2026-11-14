#!/usr/bin/env python3
"""
Generate submodule statistics documentation (Markdown) from collected JSON data.

Reads build/stat_others/<module>_<family>.json files (produced by
`scripts/collect_stats.py --submodules`) and generates:
- docs/stat/stat_others_spartan6.md
- docs/stat/stat_others_spartan7.md
- docs/stat/stat_others_artix7.md
- docs/stat/stat_others_all.md (cross-family comparison)
"""

import sys
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
BUILD_STAT_OTHERS_DIR = ROOT / "build" / "stat_others"
DOCS_STAT_DIR = ROOT / "docs" / "stat"

sys.path.insert(0, str(ROOT / "scripts"))

from modules_config import SUBMODULES, FAMILIES
from generate_stat_docs import (
    CATEGORIES_OTHERS,
    FAMILY_DOC_NAMES_OTHERS,
    load_all_results,
    generate_family_doc,
    generate_all_doc,
)


def main():
    print("Loading collected submodule statistics...")
    all_results = load_all_results(BUILD_STAT_OTHERS_DIR)

    total_files = sum(len(v) for v in all_results.values())
    if total_files == 0:
        print("ERROR: No submodule statistics data found in build/stat_others/")
        print("Run scripts/collect_stats.py --submodules first")
        sys.exit(1)

    print(f"Found data for {total_files} module/family combinations")

    # Generate per-family docs
    for family in FAMILIES.keys():
        family_results = all_results.get(family, {})
        if not family_results:
            print(f"Warning: No data for family {family}, skipping")
            continue

        doc = generate_family_doc(
            family, family_results, all_results,
            modules=SUBMODULES,
            categories=CATEGORIES_OTHERS,
            section_title="Сводная таблица",
        )
        output_file = DOCS_STAT_DIR / FAMILY_DOC_NAMES_OTHERS[family]
        with open(output_file, "w") as f:
            f.write(doc)
        print(f"Generated: {output_file}")

    # Generate combined doc
    doc_all = generate_all_doc(
        all_results,
        modules=SUBMODULES,
        categories=CATEGORIES_OTHERS,
        doc_title="# Сравнительная статистика всех подмодулей на всех FPGA",
        source_docs="`docs/stat/stat_others_spartan6.md`, `docs/stat/stat_others_spartan7.md`, `docs/stat/stat_others_artix7.md`",
        generator_note="генерируются `scripts/generate_stat_others_docs.py` из `build/stat_others/*.json`",
        comparison_label="подмодулей",
        conclusion_kind="others",
    )
    output_all = DOCS_STAT_DIR / "stat_others_all.md"
    with open(output_all, "w") as f:
        f.write(doc_all)
    print(f"Generated: {output_all}")

    print("\nDone!")


if __name__ == "__main__":
    main()
