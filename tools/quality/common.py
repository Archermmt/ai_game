"""Shared paths and locked-runtime lookup for local and CI checks."""

import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def engine_binary():
    candidates = [
        os.environ.get("GODOT_BIN"),
        ROOT / ".tools/godot/Godot.app/Contents/MacOS/Godot",
        ROOT / ".tools/godot/godot",
        ROOT / ".tools/godot/godot.exe",
        shutil.which("godot"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise RuntimeError("Godot not found; run python3 tools/quality/bootstrap.py")


def toolchain():
    return json.loads((ROOT / "toolchain.lock.json").read_text())
