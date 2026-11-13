#!/usr/bin/env python3
"""Install and verify the repository's bundled editor fonts without silent skips."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import sys
import tempfile

ICONS = ("all-the-icons.ttf", "file-icons.ttf", "fontawesome.ttf",
         "material-design-icons.ttf", "octicons.ttf", "weathericons.ttf")


def digest(path: Path) -> bytes:
    return hashlib.sha256(path.read_bytes()).digest()


def inventory(source: Path) -> list[Path]:
    if not source.is_dir():
        raise ValueError(f"font source directory is missing: {source}")
    fonts = sorted(path for path in source.rglob("*") if path.is_file() and path.suffix.lower() in {".ttf", ".otf"})
    if not fonts:
        raise ValueError(f"font source has no TTF/OTF files: {source}")
    names = {}
    for font in fonts:
        if not font.stat().st_size:
            raise ValueError(f"source font is empty: {font.name}")
        if font.name in names and digest(font) != digest(names[font.name]):
            raise ValueError(f"different source fonts share a destination name: {font.name}")
        names[font.name] = font
    return list(names.values())


def install(fonts: list[Path], destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for source in fonts:
        target = destination / source.name
        if target.is_file() and digest(target) == digest(source):
            continue
        fd, staging = tempfile.mkstemp(prefix=".font-install-", dir=destination)
        os.close(fd)
        try:
            shutil.copy2(source, staging)
            if digest(Path(staging)) != digest(source):
                raise ValueError(f"copied font differs from source: {source.name}")
            os.replace(staging, target)
        finally:
            Path(staging).unlink(missing_ok=True)


def verify(fonts: list[Path], destination: Path, *, icons: bool) -> None:
    failures = []
    for source in fonts:
        target = destination / source.name
        if not target.is_file() or digest(target) != digest(source):
            failures.append(f"missing or mismatched bundled font: {source.name}")
    if icons:
        for name in ICONS:
            path = destination / name
            if not path.is_file() or not path.stat().st_size:
                failures.append(f"missing or empty all-the-icons font: {name}")
    if failures:
        raise ValueError("\n".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("install", "verify"))
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent / "good_fonts")
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--skip-icons", action="store_true", help="explicit CI policy; bundled fonts remain mandatory")
    args = parser.parse_args()
    destination = args.destination or Path.home() / ("Library/Fonts" if platform.system() == "Darwin" else ".fonts")
    try:
        fonts = inventory(args.source)
        if args.mode == "install":
            if os.environ.get("DRY_RUN") == "1":
                print(f"DRY-RUN: install and verify {len(fonts)} bundled fonts at {destination}")
                return 0
            install(fonts, destination)
        icons = args.mode == "verify" and not args.skip_icons
        verify(fonts, destination, icons=icons)
    except (OSError, ValueError) as error:
        print(f"FAIL: fonts: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {len(fonts)} bundled fonts exactly match the repository at {destination}")
    if icons:
        print("PASS: all six all-the-icons fonts are installed and nonempty")
    elif args.mode == "verify":
        print("SKIPPED BY POLICY: all-the-icons font verification (explicit CI skip)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
