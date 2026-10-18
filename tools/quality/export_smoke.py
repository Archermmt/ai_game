"""Serial desktop exports plus a visible macOS clean-room smoke on this host."""

import argparse
import hashlib
import json
import platform
import shutil
import struct
import zipfile

from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--week", type=int, default=5, choices=[1, 2, 3, 4, 5])
    args = parser.parse_args()
    label = f"week_{args.week:02d}"
    if f'config/version="0.{args.week}.0-w{args.week:02d}"' not in (ROOT / "project.godot").read_text():
        raise RuntimeError("Project version does not match requested export week; use its Git revision")
    build_root = ROOT / "builds" / label
    (ROOT / "builds").mkdir(exist_ok=True)
    (ROOT / "builds/.gdignore").touch()
    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "reports/.gdignore").touch()
    engine = engine_binary()
    steps = []
    for folder, preset, filename in [
        ("windows", "Windows Desktop", f"windhaven_{label}.exe"),
        ("macos", "macOS Local", f"windhaven_{label}.zip"),
    ]:
        target = build_root / folder / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        steps.append(run_step("export_" + folder, [
            engine, "--headless", "--path", str(ROOT), "--export-release", preset, str(target),
        ]))
    windows = build_root / "windows" / f"windhaven_{label}.exe"
    raw = windows.read_bytes()
    assert raw[:2] == b"MZ", "not a Windows executable"
    pe = struct.unpack_from("<I", raw, 0x3C)[0]
    assert raw[pe:pe + 4] == b"PE\x00\x00"
    assert struct.unpack_from("<H", raw, pe + 4)[0] == 0x8664
    result = {"week": args.week, "windows_pe_x86_64": True, "windows_real_device": "not_run_on_macos", "steps": steps}
    if platform.system() == "Darwin":
        extracted = build_root / "macos/unpacked"
        extracted.mkdir(exist_ok=True)
        with zipfile.ZipFile(build_root / "macos" / f"windhaven_{label}.zip") as archive:
            for name in archive.namelist():
                assert (extracted / name).resolve().is_relative_to(extracted.resolve())
            archive.extractall(extracted)
        executable = next(p for p in extracted.rglob("*") if p.is_file() and p.parent.name == "MacOS")
        executable.chmod(executable.stat().st_mode | 0o111)
        clean_room = build_root / "clean_room"
        clean_room.mkdir(exist_ok=True)
        smoke_file = ROOT / f"reports/{label}_exported_macos_smoke.json"
        steps.append(run_step("exported_macos_boot", [
            str(executable), "--", "--smoke-output=" + str(smoke_file),
            "--capture=" + str(ROOT / f"reports/{label}_exported_macos.png"), "--wind-time=0",
        ], working_directory=clean_room))
        smoke = json.loads(smoke_file.read_text())
        assert smoke["buildings"] == 2 and smoke["frames"] > 0
        assert not smoke["test_framework_in_pack"] and not smoke["test_sources_in_pack"]
        result["macos_clean_room_visible_boot"] = smoke
    result["artifacts"] = []
    for target in [windows, build_root / "macos" / f"windhaven_{label}.zip"]:
        result["artifacts"].append({"path": str(target.relative_to(ROOT)), "bytes": target.stat().st_size,
                                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    for folder in ["windows", "macos"]:
        shutil.copyfile(ROOT / "THIRD_PARTY.md", build_root / folder / "THIRD_PARTY.md")
        license_path = ROOT / "docs/licenses/GODOT_LICENSE.txt"
        if license_path.exists():
            shutil.copyfile(license_path, build_root / folder / "GODOT_LICENSE.txt")
    (ROOT / f"reports/{label}_exports.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Export checks passed; Windows 3D/input real-device gate remains external.")


if __name__ == "__main__":
    main()
