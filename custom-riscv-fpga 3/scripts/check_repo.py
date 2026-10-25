#!/usr/bin/env python3
"""Validate local Markdown links, SVGs, and core project files.

Only local file references are checked; remote HTTP sources are not fetched.
The script deliberately avoids claiming anything about a CPU's correctness.
"""
from pathlib import Path
import re
import sys
from urllib.parse import unquote
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NEEDED = [
    "README.md", "ROADMAP.md", "Makefile",
    ".github/workflows/ci.yml", "docs/architecture.md",
    "AI_ASSISTANCE.md", "MY_WORK.md", "rtl/cpu/rv32i_core.v",
    "rtl/soc/rv32_soc.v", "rtl/top/tangnano20k.cst",
    "docs/verification.md",
    "examples/01_blink/blink.v", "examples/01_blink/tangnano20k.cst",
]
RE_MD = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
RE_IMG = re.compile(r'<img[^>]+src=["\']([^"\']+)["\']', re.I)


def local_target(source: Path, raw: str):
    raw = raw.strip().split(' "')[0].strip("<>")
    if not raw or raw.startswith(("http:", "https:", "mailto:", "#", "data:")):
        return None
    raw = unquote(raw).split("#", 1)[0]
    return source.parent / raw


def main() -> int:
    problems = []
    for name in NEEDED:
        if not (ROOT / name).exists():
            problems.append(f"Missing required file: {name}")

    for source in ROOT.rglob("*.md"):
        text = source.read_text(encoding="utf-8")
        for raw in RE_MD.findall(text) + RE_IMG.findall(text):
            target = local_target(source, raw)
            if target is not None and not target.exists():
                problems.append(f"Broken link: {source.relative_to(ROOT)} -> {raw}")

    for svg in (ROOT / "docs/assets").glob("*.svg"):
        try:
            ET.parse(svg)
        except ET.ParseError as err:
            problems.append(f"Invalid SVG: {svg.name}: {err}")

    if problems:
        print("FAIL: repository validation\n" + "\n".join("- " + x for x in problems))
        return 1
    print("PASS: required files, relative Markdown links, and SVG syntax")
    return 0


if __name__ == "__main__":
    sys.exit(main())
