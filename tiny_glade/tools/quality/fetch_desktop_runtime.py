"""Fetch selected files from official ZIPs using bounded explicit HTTP ranges.

Avoid downloading Android/Web templates for a desktop-only prototype. ZipFile
verifies each extracted entry's CRC; selected files get SHA-256 recorded locally.
"""

import argparse
import concurrent.futures
import hashlib
import io
import json
import time
import urllib.request
import zipfile
from pathlib import Path

from common import ROOT, toolchain

BLOCK = 4 * 1024 * 1024


class RemoteZip(io.RawIOBase):
    def __init__(self, asset):
        self.url = asset["browser_download_url"]
        self.size = asset["size"]
        self.position = 0
        self.blocks = {}

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset + (self.position if whence == 1 else self.size if whence == 2 else 0)
        return self.position

    def tell(self):
        return self.position

    def _block(self, number):
        start = number * BLOCK
        end = min(start + BLOCK, self.size) - 1
        for attempt in range(4):
            try:
                request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
                with urllib.request.urlopen(request, timeout=60) as response:
                    if response.status != 206:
                        raise RuntimeError("Server ignored Range; refusing unbounded download")
                    data = response.read()
                    if len(data) != end - start + 1:
                        raise RuntimeError("Truncated range")
                    return number, data
            except (OSError, RuntimeError):
                if attempt == 3:
                    raise
                time.sleep(1 + attempt)

    def read(self, count=-1):
        count = min(self.size - self.position, count if count >= 0 else self.size)
        if count <= 0:
            return b""
        first, last = self.position // BLOCK, (self.position + count - 1) // BLOCK
        missing = [n for n in range(first, last + 1) if n not in self.blocks]
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            for number, data in pool.map(self._block, missing):
                self.blocks[number] = data
        buffer = b"".join(self.blocks[n] for n in range(first, last + 1))
        offset = self.position - first * BLOCK
        result = buffer[offset : offset + count]
        self.position += len(result)
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--templates-only", action="store_true")
    args = parser.parse_args()
    version = toolchain()["godot"]["version"]
    metadata_path = ROOT / ".tools/downloads/godot_release.json"
    if not metadata_path.exists():
        metadata_path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(f"https://api.github.com/repos/godotengine/godot/releases/tags/{version}-stable", timeout=30) as response:
            metadata_path.write_bytes(response.read())
    metadata = json.loads(metadata_path.read_text())
    records = []
    for filename, folder, selected in [
        ("Godot_v4.7.2-stable_macos.universal.zip", ".tools/godot", None),
        ("Godot_v4.7.2-stable_export_templates.tpz", ".tools/export_templates",
         {"version.txt", "windows_debug_x86_64.exe", "windows_release_x86_64.exe", "macos.zip"}),
    ]:
        if args.templates_only and selected is None:
            continue
        asset = next(a for a in metadata["assets"] if a["name"] == filename)
        with zipfile.ZipFile(RemoteZip(asset)) as archive:
            members = [n for n in archive.namelist() if not n.endswith("/") and (selected is None or Path(n).name in selected)]
            print(filename, "selected", len(members), "files", flush=True)
            for name in members:
                relative = Path(name) if selected is None else Path(name).name
                target = ROOT / folder / relative
                assert target.resolve().is_relative_to((ROOT / folder).resolve())
                target.parent.mkdir(parents=True, exist_ok=True)
                data = archive.read(name)
                target.write_bytes(data)
                mode = archive.getinfo(name).external_attr >> 16
                if mode & 0o111:
                    target.chmod(target.stat().st_mode | 0o111)
                records.append({"path": str(target.relative_to(ROOT)), "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
                print("extracted", name, len(data), flush=True)
    (ROOT / ".tools/runtime_files.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
