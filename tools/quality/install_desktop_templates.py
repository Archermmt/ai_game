"""Register only the locked template version; never replace other versions."""

import hashlib
import os
import platform
import shutil
from pathlib import Path

from common import ROOT, toolchain


def main():
    version = toolchain()["godot"]["export_template_version"]
    if platform.system() == "Darwin":
        base = Path.home() / "Library/Application Support/Godot/export_templates"
    elif platform.system() == "Windows":
        base = Path(os.environ["APPDATA"]) / "Godot/export_templates"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates"
    destination = base / version
    destination.mkdir(parents=True, exist_ok=True)
    for source in (ROOT / ".tools/export_templates").iterdir():
        target = destination / source.name
        if target.exists():
            if hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
                raise RuntimeError(f"Refusing to overwrite differing template: {target}")
            continue
        if os.name == "nt":
            shutil.copyfile(source, target)
        else:
            target.symlink_to(source)
    print("Registered locked desktop template version:", version)


if __name__ == "__main__":
    main()
