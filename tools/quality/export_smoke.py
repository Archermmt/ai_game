"""Serial desktop exports plus a visible macOS clean-room smoke on this host."""

import argparse
import hashlib
import json
import platform
import shutil
import struct
import time
import zipfile

from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--week", type=int, default=7, choices=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    parser.add_argument("--art-pass", action="store_true", help="ART-01 revision after W09")
    parser.add_argument("--garden", action="store_true", help="Context ribbon and dynamic meadow revision")
    args = parser.parse_args()
    if args.garden and (args.week != 10 or args.art_pass):
        raise RuntimeError("Garden revision requires week 10")
    if args.art_pass and args.week != 9:
        raise RuntimeError("ART-01 requires week 9")
    label = "ui_meadow_01" if args.garden else ("art_pass_01" if args.art_pass else f"week_{args.week:02d}")
    expected_version = "0.10.1-garden01" if args.garden else ("0.9.1-art01" if args.art_pass else f"0.{args.week}.0-w{args.week:02d}")
    if f'config/version="{expected_version}"' not in (ROOT / "project.godot").read_text():
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
    result = {"week": args.week, "art_pass": args.art_pass, "windows_pe_x86_64": True, "windows_real_device": "not_run_on_macos", "steps": steps}
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
        first_draw = smoke_file.with_name(smoke_file.stem + "_first_draw.json")
        first_draw.unlink(missing_ok=True)
        started_unix = time.time()
        steps.append(run_step("exported_macos_boot", [
            str(executable), "--", "--smoke-output=" + str(smoke_file),
            "--capture=" + str(ROOT / f"reports/{label}_exported_macos.png"), "--wind-time=0",
            *(["--qa-settings", "--w10-save-probe" if args.week >= 10 else ("--art-save-probe" if args.art_pass else "--w08-save-probe")] if args.week >= 8 else []),
        ], working_directory=clean_room))
        smoke = json.loads(smoke_file.read_text())
        assert smoke["buildings"] == (3 if args.art_pass or args.week >= 10 else 2) and smoke["frames"] > 0
        assert not smoke["test_framework_in_pack"] and not smoke["test_sources_in_pack"]
        if args.week >= 6:
            assert smoke["font_license_in_pack"] and smoke["audio_resource_in_pack"]
        if args.week >= 8:
            assert smoke["edit_metrics"]["save_worker_ms"] > 0
            assert smoke["edit_metrics"]["thumbnail_png_bytes"] > 0
        result["macos_clean_room_visible_boot"] = smoke
        result["macos_first_draw_seconds"] = (
            round(json.loads(first_draw.read_text())["unix_seconds"] - started_unix, 3)
            if first_draw.exists() else None
        )
    result["artifacts"] = []
    for target in [windows, build_root / "macos" / f"windhaven_{label}.zip"]:
        result["artifacts"].append({"path": str(target.relative_to(ROOT)), "bytes": target.stat().st_size,
                                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    for folder in ["windows", "macos"]:
        shutil.copyfile(ROOT / "THIRD_PARTY.md", build_root / folder / "THIRD_PARTY.md")
        if args.week >= 6:
            shutil.copyfile(ROOT / "assets/fonts/OFL.txt", build_root / folder / "FONT_OFL.txt")
        license_path = ROOT / "docs/licenses/GODOT_LICENSE.txt"
        if license_path.exists():
            shutil.copyfile(license_path, build_root / folder / "GODOT_LICENSE.txt")
    (ROOT / f"reports/{label}_exports.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Export checks passed; Windows 3D/input real-device gate remains external.")


if __name__ == "__main__":
    main()
