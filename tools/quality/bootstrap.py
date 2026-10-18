"""Install project-local tools. Never upgrades the user's system Godot or Blender."""

import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile

from common import ROOT, toolchain


def main():
    lock = toolchain()
    cache = ROOT / ".tools/downloads"
    cache.mkdir(parents=True, exist_ok=True)
    version = lock["godot"]["version"]
    system = platform.system()
    suffix = {"Darwin": "macos.universal.zip", "Linux": "linux.x86_64.zip", "Windows": "win64.exe.zip"}[system]
    name = f"Godot_v{version}-stable_{suffix}"
    with urllib.request.urlopen(f"https://api.github.com/repos/godotengine/godot/releases/tags/{version}-stable", timeout=30) as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"] == name)
    archive = cache / name
    digest = asset.get("digest", "")
    if not archive.exists() or not digest.endswith(hashlib.sha256(archive.read_bytes()).hexdigest()):
        print("Downloading", name, flush=True)
        temporary = archive.with_suffix(".partial")
        with urllib.request.urlopen(asset["browser_download_url"], timeout=60) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        if not digest.startswith("sha256:") or digest[7:] != hashlib.sha256(temporary.read_bytes()).hexdigest():
            raise RuntimeError("Official release digest did not match; refusing to execute download")
        temporary.replace(archive)
    destination = ROOT / ".tools/godot"
    destination.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as zipped:
        zipped.extractall(destination)
    if system == "Darwin":
        executable = destination / "Godot.app/Contents/MacOS/Godot"
    else:
        executable = destination / f"Godot_v{version}-stable_{suffix.removesuffix('.zip')}"
        if system == "Linux":
            executable.rename(destination / "godot")
            executable = destination / "godot"
        else:
            executable.rename(destination / "godot.exe")
            executable = destination / "godot.exe"
    executable.chmod(executable.stat().st_mode | 0o111)
    venv = ROOT / ".venv"
    subprocess.run([sys.executable, "-m", "venv", str(venv)], check=True)
    python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    subprocess.run([str(python), "-m", "pip", "install", "-r", str(ROOT / "requirements-dev.txt")], check=True)
    print("Bootstrap complete. Export templates are installed separately with matching official version.")


if __name__ == "__main__":
    main()
