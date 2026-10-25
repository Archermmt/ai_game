"""Install project-local tools. Never upgrades the user's system Godot or Blender."""

import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import urllib.error
import zipfile

from common import ROOT, toolchain


def download_metadata(version, name):
    """Use official checksums if the release metadata API is rate limited."""
    try:
        with urllib.request.urlopen(f"https://api.github.com/repos/godotengine/godot/releases/tags/{version}-stable", timeout=30) as response:
            release = json.load(response)
        asset = next(a for a in release["assets"] if a["name"] == name)
        digest = asset.get("digest", "")
        if not digest.startswith("sha256:") or len(digest[7:]) != 64:
            raise RuntimeError("Official asset has no valid SHA256 digest")
        return asset["browser_download_url"], "sha256", digest[7:]
    except urllib.error.HTTPError as error:
        if error.code not in (403, 429):
            raise
    base = f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable"
    with urllib.request.urlopen(base + "/SHA512-SUMS.txt", timeout=30) as response:
        checksums = response.read().decode("utf-8")
    for line in checksums.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1].lstrip("*") == name:
            digest = fields[0]
            if len(digest) != 128 or any(c not in "0123456789abcdef" for c in digest):
                raise RuntimeError("Invalid official SHA512 digest")
            print("Release API limited; using official SHA512 manifest", flush=True)
            return base + "/" + name, "sha512", digest
    raise RuntimeError("Asset missing from official SHA512 manifest")


def matches_digest(path, algorithm, digest):
    return path.is_file() and hashlib.new(algorithm, path.read_bytes()).hexdigest() == digest


def main():
    lock = toolchain()
    cache = ROOT / ".tools/downloads"
    cache.mkdir(parents=True, exist_ok=True)
    version = lock["godot"]["version"]
    system = platform.system()
    suffix = {"Darwin": "macos.universal.zip", "Linux": "linux.x86_64.zip", "Windows": "win64.exe.zip"}[system]
    name = f"Godot_v{version}-stable_{suffix}"
    url, algorithm, digest = download_metadata(version, name)
    archive = cache / name
    if not matches_digest(archive, algorithm, digest):
        print("Downloading", name, flush=True)
        temporary = archive.with_suffix(".partial")
        with urllib.request.urlopen(url, timeout=60) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        if not matches_digest(temporary, algorithm, digest):
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
    subprocess.run([str(python), "-m", "pip", "install", "-r", str(ROOT / "tools/requirements-dev.lock.txt")], check=True)
    print("Bootstrap complete. Export templates are installed separately with matching official version.")


if __name__ == "__main__":
    main()
