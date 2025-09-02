#!/usr/bin/env python3
"""
Simple YAML formatter using PyYAML safe_load/safe_dump.
Rewrites files with 2-space indentation and stable key order preserved (sort_keys=False).
"""
import sys
from pathlib import Path

import yaml


def format_file(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8")
        # Parse YAML
        data = yaml.safe_load(text)
    except Exception as e:
        print(f"YAML parse error in {path}: {e}", file=sys.stderr)
        return 1

    try:
        # Dump back with consistent formatting
        out = yaml.safe_dump(
            data,
            sort_keys=False,
            allow_unicode=True,
            default_flow_style=False,
            indent=2,
        )
        # Ensure trailing newline
        if not out.endswith("\n"):
            out += "\n"
        path.write_text(out, encoding="utf-8")
    except Exception as e:
        print(f"YAML write error for {path}: {e}", file=sys.stderr)
        return 1

    return 0


def main(argv):
    if not argv:
        print("Usage: format-yaml.py file1.yaml [file2.yml ...]")
        return 2

    exit_code = 0
    for p in argv:
        path = Path(p)
        if not path.exists():
            print(f"Skipping missing file: {p}")
            continue
        rc = format_file(path)
        exit_code = exit_code or rc

    return exit_code


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
