"""Serial native art views, photo restoration, real GPU batches and wall-clock metrics."""
import argparse
import hashlib
import json
import os
import subprocess
import struct
import time
from pathlib import Path
from common import ROOT, engine_binary
from run_checks import ERRORS, run_step


def production_files():
    directory = Path.home() / "Library/Application Support/WindhavenDiorama/week_08"
    files = [*directory.glob("saves/*"), directory / "preferences.cfg"]
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files if p.is_file()}


def run(name, program, flags, duration=0):
    out = ROOT / "reports/art_pass_01/native"
    report = out / (name + ".json")
    command = [*program, "--resolution", "1920x1080", "--", "--qa-settings",
               "--art-fhd",
               "--smoke-output=" + str(report), "--capture=" + str(out / (name + ".png")), *flags]
    if duration:
        command.append("--benchmark-seconds=" + str(duration))
    before = production_files()
    started = time.monotonic()
    rss = []
    with (out / (name + ".log")).open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        while process.poll() is None:
            if time.monotonic() - started > 180:
                process.kill()
                process.wait()
                raise RuntimeError("Native probe timed out: " + name)
            if os.name != "nt":
                reading = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)], text=True, capture_output=True).stdout.strip()
                if reading.isdigit():
                    rss.append(int(reading) * 1024)
            time.sleep(0.25)
    assert process.returncode == 0 and not ERRORS.search((out / (name + ".log")).read_text()), name
    assert production_files() == before, "QA touched production saves/preferences"
    data = json.loads(report.read_text())
    stress = "--w09-stress" in flags
    empty = "--w09-empty" in flags
    assert data["buildings"] == (24 if stress else (0 if empty else 3))
    assert data["instances"] == (1000 if stress else (20 if empty else 170))
    assert data["frames"] > 100 and data["viewport_size"] == [1920, 1080]
    if "--edit-benchmark" in flags:
        assert data["edit_metrics"]["probe_edits"] == 20
    result = {"report": str(report.relative_to(ROOT)), "seconds": time.monotonic() - started,
              "production_unchanged": True, "rss_peak_bytes": max(rss) if rss else None,
              "logical_viewport": data["viewport_size"],
              "captured_framebuffer": list(struct.unpack_from(">II", (out / (name + ".png")).read_bytes(), 16)),
              "p95_frame_ms": data["p95_frame_ms"], "metrics": data["edit_metrics"]}
    assert result["captured_framebuffer"] == [1920, 1080], "Physical render target was clamped"
    print(name, "p95", data["p95_frame_ms"], "commit", data["edit_metrics"]["commit_latency_max_ms"], flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--views-only", action="store_true")
    parser.add_argument("--metrics-only", action="store_true")
    args = parser.parse_args()
    out = ROOT / "reports/art_pass_01/native"
    out.mkdir(parents=True, exist_ok=True)
    program = [str(args.executable.resolve())] if args.executable else [engine_binary(), "--path", str(ROOT)]
    result = {"build": "release" if args.executable else "runtime", "native_device": "Apple M4 Pro / 20 GPU / 48 GB / macOS arm64",
              "gpu_timing": None, "views": {}, "metrics": {}}
    if not args.metrics_only:
        for name, flags in [("day", []), ("dusk", ["--dusk"]), ("near", ["--art-near"]),
                            ("east", ["--art-angle=110"]), ("back", ["--art-angle=200"]),
                            ("west", ["--art-angle=290"]), ("low", ["--art-low"]),
                            ("far", ["--art-far"]), ("empty", ["--w09-empty"]),
                            ("entry", ["--w09-entry"]), ("entry_150", ["--w09-entry", "--ui-scale=1.5"])]:
            result["views"][name] = run(name, program, ["--wind-time=0", "--water-time=0", *([] if name.startswith("entry") else ["--hide-ui"]), *flags])
        if not args.executable:
            environment = os.environ.copy()
            environment["WINDHAVEN_ART_NATIVE_BATCHES_REQUIRED"] = "1"
            with (out / "catalog_native.log").open("w") as log:
                native = subprocess.run([engine_binary(), "--path", str(ROOT), "-s", "addons/gut/gut_cmdln.gd",
                    "-gtest=res://tests/art_pass_01/test_art_catalog.gd", "-gexit",
                    "-gjunit_xml_file=reports/art_pass_01/native/catalog_native.xml"], cwd=ROOT, env=environment,
                    stdout=log, stderr=log, timeout=120)
            assert native.returncode == 0 and not ERRORS.search((out / "catalog_native.log").read_text())
            assert "GPU_READBACK true" in (out / "catalog_native.log").read_text()
        run_step("art_01_photography", [*program, "--", "--qa-settings", "--w09-photo-probe", "--photo-output=" + str(out),
            "--smoke-output=" + str(out / "photo_smoke.json")])
        photo = json.loads((out / "photo_report.json").read_text())
        assert all(row["ok"] for row in photo["results"]) and photo["failure_retry"]
        assert all(photo[key] for key in ["source_unchanged", "camera_restored", "selection_restored", "outline_restored"])
        run_step("art_01_png_decode", [engine_binary(), "--headless", "--path", str(ROOT), "-s", "tests/week_09/image_probe.gd", "--", str(out)])
        result["photography"] = photo
    if not args.views_only:
        for name, flags in [("demo_idle", []), ("demo_edit", ["--edit-benchmark"]),
                            ("capacity_edit", ["--w09-stress", "--edit-benchmark"])]:
            result["metrics"][name] = run(name, program, ["--hide-ui", *flags], duration=60)
        result["targets"] = {
            "p95_20ms": all(row["p95_frame_ms"] <= 20 for row in result["metrics"].values()),
            "local_150ms": all(row["metrics"]["commit_latency_max_ms"] <= 150 for row in result["metrics"].values()),
            "resident_2gb": all(row["rss_peak_bytes"] <= 2 * 1024**3 for row in result["metrics"].values())}
    name = "render_release_checks.json" if args.executable else ("metrics_checks.json" if args.metrics_only else ("views_checks.json" if args.views_only else "render_checks.json"))
    (ROOT / "reports/art_pass_01" / name).write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print("Native evidence saved. Failed performance targets remain open; visual approval is separate.")


if __name__ == "__main__":
    main()
