#!/usr/bin/env python3
"""
Collect synthesis statistics for all top-level modules using Yosys.

Runs synth_xilinx for each module and each FPGA family, collects stat output,
and saves results to build/stat/<module>_<family>.json

Usage:
    python3 scripts/collect_stats.py [--module MODULE] [--family FAMILY] [--jobs N]

Requires:
    - YoWASP Yosys in tmp/pylibs/yowasp_yosys/
"""

import sys
import os
import json
import subprocess
import argparse
import time
import re
from datetime import datetime, timezone
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
from typing import Dict, List, Optional, Any

# Import module configuration
sys.path.insert(0, str(Path(__file__).parent))
from modules_config import MODULES, SUBMODULES, FAMILIES, TOOL_VERSIONS

ROOT = Path(__file__).parent.parent
BUILD_STAT_DIR = ROOT / "build" / "stat"
BUILD_STAT_DIR.mkdir(parents=True, exist_ok=True)
BUILD_STAT_OTHERS_DIR = ROOT / "build" / "stat_others"

# Set in main(); workers (forked) inherit it
OUTPUT_DIR = BUILD_STAT_DIR

# Single module synthesis script (run as subprocess)
# NOTE: synthesis stops before ABC9 (map_ffs) because YoWASP WASM cannot run the
# external yosys-abc binary. ABC9 is what would map gates onto LUT1-6 cells, so
# all LUT figures are estimates derived from the gate count (see lut6_est).
# "flatten" is used so that counts cover the whole hierarchy (top + submodules).
# "write_rtlil" on stdout is used instead of `stat` because `stat` crashes the
# WASM runtime for some modules (e.g. vhfastmulb16_mul_bf16_bf16_fp32_lat4).
SYNTH_SCRIPT = '''
import sys
sys.path.insert(0, "{pylibs}")
from yowasp_yosys import run_yosys

module_name = "{module_name}"
family = "{synth_family}"
sources = {sources}

read_verilog_cmds = "\\n".join(f"read_verilog {{src}}" for src in sources)

yosys_script = f"""
{{read_verilog_cmds}}
hierarchy -top {{module_name}}
flatten
synth_xilinx -family {{family}} -top {{module_name}} -run begin:map_ffs
write_rtlil
"""

result = run_yosys(["-p", yosys_script])
sys.exit(result)
'''


GATE_CELL_TYPES = [
    "$_AND_", "$_ANDNOT_", "$_NAND_",
    "$_OR_", "$_NOR_", "$_ORNOT_",
    "$_XOR_", "$_XNOR_",
    "$_NOT_",
    "$_MUX_", "$_NMUX_",
    "$_AOI_", "$_OAI_",
]

FF_CELL_RE = re.compile(
    r'^(\$_DFF|\$_SDFF|\$_DFFE|\$_SDFFE|\$sdff|\$sdffe'
    r'|FDCE|FDRE|FDPE|FDSE|LDCE|LDPE)'
)


def parse_rtlil_top_cells(stdout: str, top_name: str) -> Dict[str, int]:
    """Parse Yosys RTLIL dump (stdout) and count cells in the top module.

    After `flatten` the top module contains the whole design logic; library
    primitive bodies (e.g. \\IBUF, \\CARRY4 with their $specify cells) live in
    separate modules and are skipped.
    """
    cell_counts: Dict[str, int] = {}
    in_top = False

    for line in stdout.split('\n'):
        module_match = re.match(r'^module\s+(\\?\S+)', line)
        if module_match:
            in_top = module_match.group(1).lstrip('\\') == top_name
            continue

        if in_top and line.rstrip() == 'end':
            break

        if in_top:
            cell_match = re.match(r'^\s+cell\s+(\\?\S+)', line)
            if cell_match:
                cell_type = cell_match.group(1).lstrip('\\')
                if cell_type == '$scopeinfo':
                    # yosys annotation node, not a hardware cell
                    continue
                cell_counts[cell_type] = cell_counts.get(cell_type, 0) + 1

    return cell_counts


def run_yosys_synth(module: Dict, family: str) -> Dict[str, Any]:
    """Run Yosys synthesis for a single module/family combination via subprocess."""
    module_name = module["name"]
    sources = module["sources"]
    family_info = FAMILIES[family]

    # Prepare the synthesis script
    pylibs_path = str(ROOT / "tmp/pylibs")
    script = SYNTH_SCRIPT.format(
        pylibs=pylibs_path,
        module_name=module_name,
        synth_family=family_info.get("synth_family", family),
        sources=sources
    )

    # Run Yosys via subprocess to capture stdout
    start_time = time.time()
    try:
        cmd = [sys.executable, "-c", script]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=300)
        elapsed = time.time() - start_time
        stdout = result.stdout
        stderr = result.stderr
        returncode = result.returncode
    except subprocess.TimeoutExpired:
        return {
            "module": module_name,
            "family": family,
            "error": "Yosys synthesis timeout (300s)",
            "elapsed_sec": time.time() - start_time,
        }
    except Exception as e:
        return {
            "module": module_name,
            "family": family,
            "error": f"Yosys execution failed: {e}",
            "elapsed_sec": time.time() - start_time,
        }

    if returncode != 0:
        # Still try to parse output even if return code is non-zero
        pass

    

    # Parse RTLIL dump (whole design, top module after flatten)
    cell_counts = parse_rtlil_top_cells(stdout, module_name)

    if not cell_counts:
        return {
            "module": module_name,
            "family": family,
            "error": "Failed to parse RTLIL output",
            "raw_output": stdout[-3000:],
            "stderr": stderr[-1000:],
            "returncode": returncode,
            "elapsed_sec": elapsed,
        }

    logic_cells = sum(cell_counts.values())

    # Gates (logic cells that would be packed into LUTs); excludes CARRY4,
    # flip-flops and IO buffers on purpose.
    gates = sum(cell_counts.get(t, 0) for t in GATE_CELL_TYPES)

    # LUT6 estimation (rough, pre-ABC9 gate count / 2.5)
    lut6_est = gates / 2.5

    # Check for DSP usage
    dsp_count = cell_counts.get("DSP48A1", 0) + cell_counts.get("DSP48E1", 0) + \
                cell_counts.get("DSP48E2", 0) + cell_counts.get("DSP58", 0) + \
                cell_counts.get("$__MUL18X18", 0) + cell_counts.get("MUL18X18", 0)

    # FF count (all flip-flop cell variants, e.g. FDCE/FDRE, $_SDFFE_PP0P_, $_SDFF_PP0_)
    ff_count = sum(count for cell_type, count in cell_counts.items()
                   if FF_CELL_RE.match(cell_type))

    # CARRY4 count
    carry4 = cell_counts.get("CARRY4", 0)
    carry8 = cell_counts.get("CARRY8", 0)

    # LUT6_2, MUXF7, MUXF8
    lut6_2 = cell_counts.get("LUT6_2", 0)
    muxf7 = cell_counts.get("MUXF7", 0)
    muxf8 = cell_counts.get("MUXF8", 0)

    # IO buffers
    iob = cell_counts.get("IBUF", 0) + cell_counts.get("OBUF", 0) + \
          cell_counts.get("IOBUF", 0) + cell_counts.get("OBUFT", 0)

    # Fmax: hand-calibrated typical value (see modules_config.py)
    fmax_est = module["fmax"][family]

    return {
        "module": module_name,
        "family": family,
        "device": family_info["device"],
        "tool": TOOL_VERSIONS,
        "synth_options": f"synth_xilinx -family {family_info.get("synth_family", family)} -run begin:map_ffs; flatten; pre-ABC9 (YoWASP WASM cannot run yosys-abc)",
        "metrics": {
            "logic_cells": logic_cells,
            "gates": gates,
            "lut6_est": round(lut6_est),
            "lut6_abc9": None,
            "ff": ff_count,
            "carry4": carry4,
            "carry8": carry8,
            "lut6_2": lut6_2,
            "muxf7": muxf7,
            "muxf8": muxf8,
            "iob": iob,
            "dsp48": dsp_count,
            "cell_counts": cell_counts,
        },
        "fmax": {
            "estimated_mhz": fmax_est,
            "source": "manual",
            "logic_levels_max": None,
            "critical_path": get_critical_path_hint(module),
        },
        "latency": module["latency"],
        "pipeline_stages": module["latency"],
        "rounding": module["rounding"],
        "subnormal_handling": module["subnormal_handling"],
        "category": module["category"],
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "git_commit": get_git_commit(),
        "elapsed_sec": round(elapsed, 2),
    }



def get_critical_path_hint(module: Dict) -> str:
    """Return a hint about the critical path for the module."""
    name = module["name"]

    exact_hints = {
        "vhfastmulb16_mul4x4": "16 частичных произведений (AND) → CSA tree (2 уровня) → 8-битный CPA (CARRY4) → выходной регистр",
        "vhfastmulb16_mul4x4_lat2": "CSA tree → 8-битный CPA (CARRY4) → выходной регистр (стадия 2)",
        "vhfastmulb16_mul4x4_comb": "16 частичных произведений (AND) → CSA tree (2 уровня) → 8-битный CPA (CARRY4) → комбинационный выход",
        "vhfastmulb16_mul_u8_u8_u16_lat2": "4× mul4x4 (CSA) → 2 уровня CSA → 16-битный CPA (CARRY4) → выходной регистр",
        "vhfastmulb16_mul_u8_u8_u16_lat3": "4× mul4x4_lat2 (2 стадии) → CSA tree → 16-битный CPA → выходной регистр (стадия 3)",
        "vhfastmulb16_add8x8_lat2": "9-битный сумматор + 9-битный вычитатель (константа 127) → CARRY4 → выходной регистр",
        "vhfastmulb16_sign": "XOR (sign) → signc_lat1 → signc_lat2 → signc_lat3 (en, синхронный reset)",
        "vhfastmulb16_flags_lat1": "NaN/Inf/Zero классификация → регистр (латентность 1)",
        "vhfastmulb16_flags_lat2": "flags_lat1 → регистр (латентность 2)",
        "vhfastmulb16_except_lat2": "flags_lat1 ×2 → классификация NaN/Inf/Zero → выбор NaN payload / флагов → выходной регистр (латентность 2)",
        "vhfastmulb16_except_lat3": "flags_lat2 ×2 → классификация NaN/Inf/Zero → выбор NaN payload / флагов → выходной регистр (латентность 3)",
    }
    if name in exact_hints:
        return exact_hints[name]

    if "muladd" in name and "lat4" in name:
        return "p_*_d1 → CSA tree → 16-bit CPA → k_calc → exp_p_calc → exp compare → shift_diff → large/small mux → 27-bit alignment shifter → reg S3"
    elif "muladd" in name and "lat8" in name:
        return "P1-P4 balanced pipeline: all stages 7-11 LUT levels (S4 worst: 10-11). CARRY4 subtractors, per-stage CE, deferred mantissa compare, LZD split S6/S7"
    elif "mul_bf16_bf16_bf16" in name and "rtz" in name:
        return "mul4x4 (CSA) → mul_u8_u8_u16_lat2 CPA → exp_sum + man_msb → c_next mux → output reg"
    elif "mul_bf16_bf16_bf16" in name and "rne" in name:
        return "mul4x4 (CSA) → CPA → man_shifted/G/R/S → RNE increment → exp_inc → exp_norm (9-bit add) → c_next mux → output reg"
    elif "mul_bf16_bf16_fp32" in name:
        return "mul4x4_comb (CSA) → CPA → leading-one → mant_norm shifter → exp_unb → F32 pack mux → output reg"
    elif "add_fp32" in name and "rtz" in name:
        return "barrel shifter alignment (S1) → 28-bit add/sub (S2) → LZD 27-bit (S3) → carry fix-up → F32 pack mux → output reg"
    elif "add_fp32" in name and "rne" in name:
        return "barrel shifter (S1) → 28-bit add/sub (S2) → LZD 27-bit (S3) → normalization → RNE rounding (G/R/S + increment) → F32 pack mux → output reg"
    elif "add_fp16" in name and "rtz" in name:
        return "barrel shifter alignment (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → carry fix-up → F16 pack mux → output reg"
    elif "add_fp16" in name and "rne" in name:
        return "barrel shifter (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → normalization → RNE rounding → F16 pack mux → output reg"
    elif "add_bf16" in name and "rtz" in name:
        return "barrel shifter alignment (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → carry fix-up → BF16 pack mux → output reg"
    elif "add_bf16" in name and "rne" in name:
        return "barrel shifter (S1) → 15-bit add/sub (S2) → LZD 15-bit (S3) → normalization → RNE rounding → BF16 pack mux → output reg"
    else:
        return "unknown"


def get_git_commit() -> str:
    """Get current git commit hash."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return "unknown"


def save_result(result: Dict, module_name: str, family: str):
    """Save result to JSON file."""
    filename = OUTPUT_DIR / f"{module_name}_{family}.json"
    with open(filename, "w") as f:
        json.dump(result, f, indent=2)
    return filename


def collect_one(args: tuple) -> Dict:
    """Wrapper for parallel execution."""
    module, family = args
    print(f"  [{module['name']} / {family}] ", end="", flush=True)
    result = run_yosys_synth(module, family)
    if "error" in result:
        print(f"FAILED: {result['error']}")
    else:
        print(f"OK (LUT~{result['metrics']['lut6_est']}, FF~{result['metrics']['ff']}, Fmax~{result['fmax']['estimated_mhz']}MHz)")
    save_result(result, module["name"], family)
    return result


def collect_group(modules: List[Dict], families: List[str], jobs: int, out_dir: Path, label: str):
    """Collect statistics for one group of modules into out_dir."""
    global OUTPUT_DIR
    OUTPUT_DIR = out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    work_items = [(m, f) for m in modules for f in families]
    print(f"[{label}] Collecting statistics for {len(modules)} module(s) x {len(families)} family(ies) = {len(work_items)} runs")
    print(f"Output directory: {out_dir}")
    print(f"Parallel jobs: {jobs}")
    print()

    results = []
    if jobs > 1:
        with ProcessPoolExecutor(max_workers=jobs) as executor:
            futures = {executor.submit(collect_one, item): item for item in work_items}
            for future in as_completed(futures):
                results.append(future.result())
    else:
        for item in work_items:
            results.append(collect_one(item))

    print("\n=== SUMMARY ===")
    ok = sum(1 for r in results if "error" not in r)
    failed = len(results) - ok
    print(f"Successful: {ok}, Failed: {failed}")

    if failed > 0:
        print("\nFailures:")
        for r in results:
            if "error" in r:
                print(f"  {r['module']} / {r['family']}: {r['error']}")

    print(f"\nResults saved to: {out_dir}")
    return results


def main():
    parser = argparse.ArgumentParser(description="Collect synthesis statistics for all modules")
    parser.add_argument("--module", help="Collect only for specific module")
    parser.add_argument("--family", help="Collect only for specific family (xc6s, xc7s, xc7a)")
    parser.add_argument("--jobs", "-j", type=int, default=1, help="Parallel jobs (default: 1)")
    parser.add_argument("--list", action="store_true", help="List modules and families")
    parser.add_argument("--submodules", action="store_true", help="Collect bottom-up submodules (docs/stat/stat_others_*.md)")
    parser.add_argument("--all", action="store_true", help="Collect both top-level modules and submodules")
    args = parser.parse_args()

    if args.list:
        print("Top-level modules:")
        for m in MODULES:
            print(f"  {m['name']} (category: {m['category']}, latency: {m['latency']}, rounding: {m['rounding']})")
        print("\nSubmodules:")
        for m in SUBMODULES:
            print(f"  {m['name']} (category: {m['category']}, latency: {m['latency']}, rounding: {m['rounding']})")
        print("\nFamilies:")
        for fid, finfo in FAMILIES.items():
            print(f"  {fid}: {finfo['device']} ({finfo['description']})")
        return

    # Filter families
    families = list(FAMILIES.keys())
    if args.family:
        if args.family not in FAMILIES:
            print(f"ERROR: Family '{args.family}' not found")
            sys.exit(1)
        families = [args.family]

    # Select groups to collect
    if args.all:
        groups = [("top", MODULES, BUILD_STAT_DIR),
                  ("submodules", SUBMODULES, BUILD_STAT_OTHERS_DIR)]
    elif args.submodules:
        groups = [("submodules", SUBMODULES, BUILD_STAT_OTHERS_DIR)]
    else:
        groups = [("top", MODULES, BUILD_STAT_DIR)]

    collected_any = False
    for label, module_list, out_dir in groups:
        modules = module_list
        if args.module:
            modules = [m for m in modules if m["name"] == args.module]
        if not modules:
            continue
        collected_any = True
        collect_group(modules, families, args.jobs, out_dir, label)

    if not collected_any:
        print(f"ERROR: Module '{args.module}' not found")
        sys.exit(1)


if __name__ == "__main__":
    main()