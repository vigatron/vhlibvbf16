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
from datetime import datetime
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
from typing import Dict, List, Optional, Any

# Import module configuration
sys.path.insert(0, str(Path(__file__).parent))
from modules_config import MODULES, FAMILIES, TOOL_VERSIONS

ROOT = Path(__file__).parent.parent
BUILD_STAT_DIR = ROOT / "build" / "stat"
BUILD_STAT_DIR.mkdir(parents=True, exist_ok=True)

# Single module synthesis script (run as subprocess)
SYNTH_SCRIPT = '''
import sys
sys.path.insert(0, "{pylibs}")
from yowasp_yosys import run_yosys

module_name = "{module_name}"
family = "{family}"
sources = {sources}

read_verilog_cmds = "\\n".join(f"read_verilog {{src}}" for src in sources)

yosys_script = f"""
{{read_verilog_cmds}}
hierarchy -top {{module_name}}
synth_xilinx -family {{family}} -top {{module_name}} -run begin:map_ffs
stat -top {{module_name}}
"""

result = run_yosys(["-p", yosys_script])
sys.exit(result)
'''


def parse_stat_output(stdout: str, module_name: str) -> Dict[str, int]:
    """Parse Yosys stat text output to extract cell counts."""
    cell_counts = {}

    lines = stdout.split('\n')
    in_module = False

    for line in lines:
        # Check for module header
        if f"=== {module_name} ===" in line:
            in_module = True
            continue

        # Check for next module header (end of our module section)
        if in_module and line.startswith("==="):
            break

        if in_module:
            # Parse cell type lines: "       COUNT   CELL_TYPE"
            match = re.match(r'^\s+(\d+)\s+(\S+)$', line)
            if match:
                count = int(match.group(1))
                cell_type = match.group(2)
                cell_counts[cell_type] = count

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
        family=family,
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

    

    # Parse stat text output
    cell_counts = parse_stat_output(stdout, module_name)

    if not cell_counts:
        return {
            "module": module_name,
            "family": family,
            "error": "Failed to parse stat output",
            "raw_output": stdout[-3000:],
            "stderr": stderr[-1000:],
            "returncode": returncode,
            "elapsed_sec": elapsed,
        }

    # Calculate logic cells
    logic_cell_types = [
        "LUT1", "LUT2", "LUT3", "LUT4", "LUT5", "LUT6", "LUT6_2",
        "MUXCY", "XORCY", "MUXF7", "MUXF8", "MUXF78",
        "CARRY4", "CARRY8",
        "$_AND_", "$_OR_", "$_XOR_", "$_NOT_", "$_NAND_", "$_NOR_", "$_XNOR_",
        "$_MUX_", "$_NMUX_", "$_AOI_", "$_OAI_",
        "FDRE", "FDSE", "FDCE", "FDPE", "LDCE", "LDPE",
        "$_DFF_", "$_DFFE_", "$_SDFF_", "$_SDFFE_", "$_DFF_P_", "$_DFF_N_",
        "RAM32M", "RAM64M", "RAM128X1D", "RAM256X1D",
        "FIFO18E1", "FIFO36E1", "BRAM",
        "$lut", "$mux", "$fa", "$alu", "$macc",
        "$alu", "$macc_v2",
        "$and", "$or", "$xor", "$not", "$eq", "$ne", "$logic_and", "$logic_or", "$logic_not",
        "$reduce_and", "$reduce_or",
        "$shl", "$shr", "$shiftx",
        "$sdff", "$sdffe",
    ]
    logic_cells = sum(cell_counts.get(t, 0) for t in logic_cell_types)

    # LUT6 estimation
    lut6_est = logic_cells / 2.5

    # Check for DSP usage
    dsp_count = cell_counts.get("DSP48A1", 0) + cell_counts.get("DSP48E1", 0) + \
                cell_counts.get("DSP48E2", 0) + cell_counts.get("DSP58", 0) + \
                cell_counts.get("$__MUL18X18", 0) + cell_counts.get("MUL18X18", 0)

    # FF count
    ff_count = cell_counts.get("FDRE", 0) + cell_counts.get("FDSE", 0) + \
               cell_counts.get("FDCE", 0) + cell_counts.get("FDPE", 0) + \
               cell_counts.get("$_DFFE_PP0P_", 0) + cell_counts.get("$_DFFE_NP0P_", 0) + \
               cell_counts.get("$_DFFE_PP1P_", 0) + cell_counts.get("$_DFFE_NP1P_", 0) + \
               cell_counts.get("$_SDFFE_PP0P_", 0) + cell_counts.get("$_SDFFE_NP0P_", 0) + \
               cell_counts.get("$_SDFFE_PP1P_", 0) + cell_counts.get("$_SDFFE_NP1P_", 0) + \
               cell_counts.get("$sdff", 0) + cell_counts.get("$sdffe", 0)

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

    # Estimate logic levels for Fmax
    logic_levels_est = estimate_logic_levels(module, cell_counts)

    # Fmax estimation based on logic levels
    fmax_est = estimate_fmax(logic_levels_est, family)

    return {
        "module": module_name,
        "family": family,
        "device": family_info["device"],
        "tool": TOOL_VERSIONS,
        "synth_options": f"synth_xilinx -family {family} -run begin:fine (pre-ABC9)",
        "metrics": {
            "logic_cells": logic_cells,
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
            "source": "logic_depth",
            "logic_levels_max": logic_levels_est,
            "critical_path": get_critical_path_hint(module),
        },
        "latency": module["latency"],
        "pipeline_stages": module["latency"],
        "rounding": module["rounding"],
        "subnormal_handling": module["subnormal_handling"],
        "category": module["category"],
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "git_commit": get_git_commit(),
        "elapsed_sec": round(elapsed, 2),
    }


def estimate_logic_levels(module: Dict, cell_counts: Dict) -> int:
    """Rough estimation of max logic levels based on module category and cell counts."""
    category = module["category"]
    carry4 = cell_counts.get("CARRY4", 0)
    lut6 = cell_counts.get("LUT6", 0) + cell_counts.get("LUT6_2", 0) * 2
    muxf7 = cell_counts.get("MUXF7", 0)
    muxf8 = cell_counts.get("MUXF8", 0)

    if category == "multiplication":
        base = 8 + (carry4 * 0.3) + (muxf7 * 0.45) + (muxf8 * 0.9)
    elif category == "addition":
        base = 10 + (carry4 * 0.3) + (lut6 * 0.02) + (muxf7 * 0.45)
    elif category == "fma":
        base = 12 + (carry4 * 0.3) + (lut6 * 0.015) + (muxf7 * 0.45) + (muxf8 * 0.9)
    else:
        base = 10

    return max(5, int(base))


def estimate_fmax(logic_levels: int, family: str) -> int:
    """Estimate Fmax based on logic levels and FPGA family."""
    timing = {
        "xc6s": {"tcko": 0.57, "tlut": 0.35, "trouting_factor": 1.35, "tsetup": 0.46},
        "xc7s": {"tcko": 0.45, "tlut": 0.28, "trouting_factor": 1.30, "tsetup": 0.38},
        "xc7a": {"tcko": 0.42, "tlut": 0.25, "trouting_factor": 1.25, "tsetup": 0.35},
    }
    t = timing.get(family, timing["xc6s"])

    t_logic = logic_levels * t["tlut"]
    t_routing = t_logic * t["trouting_factor"]
    t_clk = t["tcko"] + t_logic + t_routing + t["tsetup"]
    fmax_mhz = 1000 / t_clk

    return int(fmax_mhz)


def get_critical_path_hint(module: Dict) -> str:
    """Return a hint about the critical path for the module."""
    name = module["name"]

    if "mul_bf16_bf16_bf16" in name and "rtz" in name:
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
    elif "muladd" in name and "lat4" in name:
        return "p_*_d1 → CSA tree → 16-bit CPA → k_calc → exp_p_calc → exp compare → shift_diff → large/small mux → 27-bit alignment shifter → reg S3"
    elif "muladd" in name and "lat8" in name:
        return "P1-P4 balanced pipeline: all stages 7-11 LUT levels (S4 worst: 10-11). CARRY4 subtractors, per-stage CE, deferred mantissa compare, LZD split S6/S7"
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
    filename = BUILD_STAT_DIR / f"{module_name}_{family}.json"
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


def main():
    parser = argparse.ArgumentParser(description="Collect synthesis statistics for all modules")
    parser.add_argument("--module", help="Collect only for specific module")
    parser.add_argument("--family", help="Collect only for specific family (xc6s, xc7s, xc7a)")
    parser.add_argument("--jobs", "-j", type=int, default=1, help="Parallel jobs (default: 1)")
    parser.add_argument("--list", action="store_true", help="List modules and families")
    args = parser.parse_args()

    if args.list:
        print("Modules:")
        for m in MODULES:
            print(f"  {m['name']} (category: {m['category']}, latency: {m['latency']}, rounding: {m['rounding']})")
        print("\nFamilies:")
        for fid, finfo in FAMILIES.items():
            print(f"  {fid}: {finfo['device']} ({finfo['description']})")
        return

    # Filter modules/families
    modules = MODULES
    if args.module:
        modules = [m for m in MODULES if m["name"] == args.module]
        if not modules:
            print(f"ERROR: Module '{args.module}' not found")
            sys.exit(1)

    families = list(FAMILIES.keys())
    if args.family:
        if args.family not in FAMILIES:
            print(f"ERROR: Family '{args.family}' not found")
            sys.exit(1)
        families = [args.family]

    # Prepare work items
    work_items = [(m, f) for m in modules for f in families]
    print(f"Collecting statistics for {len(modules)} module(s) x {len(families)} family(ies) = {len(work_items)} runs")
    print(f"Output directory: {BUILD_STAT_DIR}")
    print(f"Parallel jobs: {args.jobs}")
    print()

    # Run collection
    results = []
    if args.jobs > 1:
        with ProcessPoolExecutor(max_workers=args.jobs) as executor:
            futures = {executor.submit(collect_one, item): item for item in work_items}
            for future in as_completed(futures):
                results.append(future.result())
    else:
        for item in work_items:
            results.append(collect_one(item))

    # Summary
    print("\n=== SUMMARY ===")
    ok = sum(1 for r in results if "error" not in r)
    failed = len(results) - ok
    print(f"Successful: {ok}, Failed: {failed}")

    if failed > 0:
        print("\nFailures:")
        for r in results:
            if "error" in r:
                print(f"  {r['module']} / {r['family']}: {r['error']}")

    print(f"\nResults saved to: {BUILD_STAT_DIR}")


if __name__ == "__main__":
    main()