#!/usr/bin/env python3

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path


class Colors:
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"


def shell_join(parts: list[str]) -> str:
    return " ".join(shlex.quote(p) for p in parts)


def call_wrapper(cmd: list[str], verbose: bool) -> None:
    if verbose:
        print(f"{Colors.OKCYAN}Running: {shell_join(cmd)}{Colors.ENDC}")
        subprocess.check_call(cmd)
    else:
        subprocess.check_call(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def build_variant(
    repo_root: Path,
    variant: str,
    defines: list[str],
    kwargs: list[str],
    verbose: bool,
) -> bool:
    cmd = [
        "conan",
        "build",
        str(repo_root),
        "-b",
        f"missing",
        "-c",
        f'tools.cmake.cmake_layout:build_folder_vars=["const.{variant}"]',
    ]

    for define in defines:
        cmd.extend(["-c", f"tools.build:defines=['{define}']"])

    cmd.extend(kwargs)

    try:
        call_wrapper(cmd, verbose)
    except subprocess.CalledProcessError:
        print(f"{Colors.FAIL}{variant}: build failed{Colors.ENDC}")
        return False

    print(f"{Colors.OKGREEN}{variant}: build done{Colors.ENDC}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Configure/build baseline and solution variants with Conan.")
    parser.add_argument(
        "--repo_root",
        type=Path,
        default=Path("."),
        help="Path to the repository root.",
    )
    parser.add_argument(
        "-D",
        "--define",
        dest="defines",
        action="append",
        default=["SOLUTION"],
        help="Preprocessor define added to the solution build. Can be passed multiple times.",
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
    if not repo_root.exists():
        print(f"{Colors.FAIL}Repository root does not exist: {repo_root}{Colors.ENDC}")
        return 1

    baseline_ok = build_variant(
        repo_root=repo_root,
        variant="baseline",
        defines=[],
        kwargs=args.kwargs,
        verbose=args.verbose,
    )

    solution_ok = build_variant(
        repo_root=repo_root,
        variant="solution",
        defines=args.defines,
        kwargs=args.kwargs,
        verbose=args.verbose,
    )

    return 0 if (baseline_ok and solution_ok) else 1


if __name__ == "__main__":
    sys.exit(main())