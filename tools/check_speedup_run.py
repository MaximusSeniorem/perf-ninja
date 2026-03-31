#!/usr/bin/env python3

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path

import gbench
from gbench import report, util


class Colors:
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"


def shell_join(parts: list[str]) -> str:
    return " ".join(shlex.quote(p) for p in parts)


def call_wrapper(cmd: list[str], cwd: Path, verbose: bool) -> None:
    if verbose:
        print(f"{Colors.OKCYAN}Running: {shell_join(cmd)}{Colors.ENDC}")
        subprocess.check_call(cmd, cwd=str(cwd))
    else:
        subprocess.check_call(
            cmd,
            cwd=str(cwd),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def get_build_dir(repo_root: Path, variant: str, build_type: str) -> Path:
    return repo_root / "build" / variant / build_type


def get_preset_name(variant: str, build_type: str) -> str:
    return f"conan-{variant}-{build_type.lower()}"


def run_variant(
    repo_root: Path,
    variant: str,
    build_type: str,
    target_prefix: str,
    kwargs: list[str],
    verbose: bool,
) -> bool:
    build_dir = get_build_dir(repo_root, variant, build_type)
    if not build_dir.exists():
        print(f"{Colors.FAIL}{variant}: build directory not found: {build_dir}{Colors.ENDC}")
        return False

    preset = get_preset_name(variant, build_type)
    validate_target = f"{target_prefix}.validateLab"
    benchmark_target = f"{target_prefix}.benchmarkLab"

    try:
        call_wrapper(
            ["cmake", "--build", "--preset", preset, "--target", validate_target, *kwargs],
            cwd=repo_root,
            verbose=verbose,
        )
        call_wrapper(
            ["cmake", "--build", "--preset", preset, "--target", benchmark_target, *kwargs],
            cwd=repo_root,
            verbose=verbose,
        )
    except subprocess.CalledProcessError:
        print(f"{Colors.FAIL}{variant}: run failed{Colors.ENDC}")
        return False

    print(f"{Colors.OKGREEN}{variant}: run done{Colors.ENDC}")
    return True


def compare_results(
    repo_root: Path,
    build_type: str,
    target_prefix: str,
) -> bool:
    relative_lab_path = Path("labs") / Path(*target_prefix.split("."))

    baseline_result = (
        get_build_dir(repo_root, "baseline", build_type)
        / relative_lab_path
        / "result.json"
    )
    solution_result = (
        get_build_dir(repo_root, "solution", build_type)
        / relative_lab_path
        / "result.json"
    )

    if not baseline_result.exists():
        print(f"{Colors.FAIL}Missing baseline result: {baseline_result}{Colors.ENDC}")
        return False
    if not solution_result.exists():
        print(f"{Colors.FAIL}Missing solution result: {solution_result}{Colors.ENDC}")
        return False

    out_json_solution = util.load_benchmark_results(str(solution_result))
    out_json_baseline = util.load_benchmark_results(str(baseline_result))

    diff_report = report.get_difference_report(
        out_json_baseline,
        out_json_solution,
        True,
    )
    output_lines = report.print_difference_report(
        diff_report,
        False,
        True,
        0.05,
        True,
    )

    for line in output_lines:
        print(line)

    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Run prepared speedup builds and compare benchmark results.")
    parser.add_argument(
        "--repo_root",
        type=Path,
        default=Path("."),
        help="Path to the repository root.",
    )
    parser.add_argument(
        "--build_type",
        type=str,
        default="Release",
        help="Build type, e.g. Release or Debug.",
    )
    parser.add_argument(
        "--target_prefix",
        type=str,
        required=True,
        help="Target prefix, e.g. misc.warmup",
    )
    parser.add_argument(
        "--kwargs",
        nargs=argparse.REMAINDER,
        default=[],
        help="Extra arguments forwarded verbatim to Conan commands.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        help="Verbose output.",
    )

    args = parser.parse_args()
    repo_root = args.repo_root.resolve()

    baseline_ok = run_variant(
        repo_root=repo_root,
        variant="baseline",
        build_type=args.build_type,
        target_prefix=args.target_prefix,
        kwargs=args.kwargs,
        verbose=args.verbose,
    )
    solution_ok = run_variant(
        repo_root=repo_root,
        variant="solution",
        build_type=args.build_type,
        target_prefix=args.target_prefix,
        kwargs=args.kwargs,
        verbose=args.verbose,
    )

    if not (baseline_ok and solution_ok):
        return 1

    return 0 if compare_results(repo_root, args.build_type, args.target_prefix) else 1


if __name__ == "__main__":
    sys.exit(main())