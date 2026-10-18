"""Serial desktop exports plus a visible macOS clean-room smoke on this host."""

import hashlib
import json
import platform
import shutil
import struct
import zipfile

from common import ROOT, engine_binary
from run_checks import run_step


def main():
    engine = engine_binary()
    steps = []
    for folder, preset, filename in [
        ("windows", "Windows Desktop", "windhaven_week_01.exe"),
        ("macos", "macOS Local", "windhaven_week_01.zip"),
    ]:
        target = ROOT / "builds" / folder / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        steps.append(run_step("export_" + folder, [
            engine, "--headless", "--path", str(ROOT), "--export-release", preset, str(target),
        ]))
    windows = ROOT / "builds/windows/windhaven_week_01.exe"
    raw = windows.read_bytes()
    assert raw[:2] == b"MZ", "not a Windows executable"
    pe = struct.unpack_from("<I", raw, 0x3C)[0]
    assert raw[pe:pe + 4] == b"PE\x00\x00"
    assert struct.unpack_from("<H", raw, pe + 4)[0] == 0x8664
    result = {"windows_pe_x86_64": True, "windows_real_device": "not_run_on_macos", "steps": steps}
    if platform.system() == "Darwin":
        extracted = ROOT / "builds/macos/unpacked"
        extracted.mkdir(exist_ok=True)
        with zipfile.ZipFile(ROOT / "builds/macos/windhaven_week_01.zip") as archive:
            for name in archive.namelist():
                assert (extracted / name).resolve().is_relative_to(extracted.resolve())
            archive.extractall(extracted)
        executable = next(p for p in extracted.rglob("*") if p.is_file() and p.parent.name == "MacOS")
        executable.chmod(executable.stat().st_mode | 0o111)
        clean_room = ROOT / "builds/clean_room"
        clean_room.mkdir(exist_ok=True)
        smoke_file = ROOT / "reports/exported_macos_smoke.json"
        steps.append(run_step("exported_macos_boot", [
            str(executable), "--", "--smoke-output=" + str(smoke_file),
            "--capture=" + str(ROOT / "reports/exported_macos.png"), "--wind-time=0",
        ], working_directory=clean_room))
        smoke = json.loads(smoke_file.read_text())
        assert smoke["buildings"] == 2 and smoke["frames"] > 0
        assert not smoke["test_framework_in_pack"] and not smoke["test_sources_in_pack"]
        result["macos_clean_room_visible_boot"] = smoke
    result["artifacts"] = []
    for target in [windows, ROOT / "builds/macos/windhaven_week_01.zip"]:
        result["artifacts"].append({"path": str(target.relative_to(ROOT)), "bytes": target.stat().st_size,
                                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    for folder in ["windows", "macos"]:
        shutil.copyfile(ROOT / "THIRD_PARTY.md", ROOT / "builds" / folder / "THIRD_PARTY.md")
        license_path = ROOT / "docs/licenses/GODOT_LICENSE.txt"
        if license_path.exists():
            shutil.copyfile(license_path, ROOT / "builds" / folder / "GODOT_LICENSE.txt")
    (ROOT / "reports/exports.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Export checks passed; Windows 3D/input real-device gate remains external.")


if __name__ == "__main__":
    main()
