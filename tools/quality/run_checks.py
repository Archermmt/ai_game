"""Week gates. Failed engine logs, empty suites and failed assertions are fatal."""

import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from common import ROOT, engine_binary, toolchain

ERRORS = re.compile(r"SCRIPT ERROR:|(?:^|\n)ERROR:|Program crashed|ObjectDB instances? (?:was|were) leaked")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def run_step(name, command, expected_failure=False, working_directory=ROOT, timeout=180):
    start = time.monotonic()
    process = subprocess.run(command, cwd=working_directory, text=True, capture_output=True, timeout=timeout)
    output = ANSI.sub("", process.stdout + process.stderr)
    (ROOT / "reports" / (name + ".log")).write_text(output)
    success = process.returncode != 0 if expected_failure else (
        process.returncode == 0 and not ERRORS.search(output)
    )
    if expected_failure:
        success = success and "intentional gate control" in output and bool(
            re.search(r"Failing Tests\s+1", output)
        )
    if not success:
        print(output[-6500:])
        raise RuntimeError(f"{name} failed; exit={process.returncode}")
    print(f"PASS {name} ({time.monotonic() - start:.2f}s)")
    return {"name": name, "exit_code": process.returncode, "seconds": round(time.monotonic() - start, 3)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--week", type=int, default=1)
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()
    if args.week not in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
        raise RuntimeError("No gate registered for this week; add its tests before marking it done")
    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "reports/.gdignore").touch()
    engine = engine_binary()
    actual = subprocess.check_output([engine, "--version"], text=True).strip()
    expected = toolchain()["godot"]["version"]
    if not actual.startswith(expected + ".stable"):
        raise RuntimeError(f"Engine mismatch: expected {expected}, got {actual}")
    executable_dir = ROOT / ".venv" / ("Scripts" if sys.platform == "win32" else "bin")
    entries = []
    entries.append(run_step("engine_import", [engine, "--headless", "--path", ".", "--editor", "--import"]))
    source = ["app", "core", "features", "ui", "tests", "levels"]
    entries.append(run_step("format", [str(executable_dir / "gdformat"), "--check", *source]))
    entries.append(run_step("lint", [str(executable_dir / "gdlint"), *source]))
    entries.append(run_step("asset_contract", [sys.executable, "tools/quality/validate_assets.py", "--week", str(min(args.week, 9))]))
    if args.week >= 6:
        entries.append(run_step("week_06_media", [sys.executable, "tools/quality/validate_week_six_media.py"]))
    if args.week >= 7:
        entries.append(run_step("week_07_assets", [sys.executable, "tools/quality/validate_week_seven_assets.py"]))
    if args.week >= 9:
        entries.append(run_step("week_09_assets", [sys.executable, "tools/quality/validate_week_nine_assets.py"]))
    count = failures = skipped = 0
    groups = []
    for week in range(1, args.week + 1):
        label = f"week_{week:02d}"
        entries.append(run_step(label + "_tests", [
            engine, "--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd",
            "-gdir=res://tests/" + label, "-ginclude_subdirs", "-gexit",
            "-gjunit_xml_file=reports/" + label + ".xml",
        ]))
        suite = ET.parse(ROOT / ("reports/" + label + ".xml")).getroot()
        tested = int(suite.attrib.get("tests", 0))
        failed = int(suite.attrib.get("failures", 0))
        omitted = sum(int(part.attrib.get("skipped", 0)) for part in suite.findall("testsuite"))
        if tested < {1: 42, 2: 52, 3: 42, 4: 50, 5: 45, 6: 68, 7: 51, 8: 62, 9: 34, 10: 30}[week] or failed or omitted:
            raise RuntimeError(f"Invalid {label} suite: {tested} tests, {failed} failed, {omitted} skipped")
        count += tested
        failures += failed
        skipped += omitted
        groups.append({"week": week, "tests": tested, "failures": failed, "skipped": omitted})
        restart_file = str(ROOT / ("reports/" + label + "_restart.wgs"))
        for mode in ["write", "read"]:
            entries.append(run_step(label + "_restart_" + mode, [
                engine, "--headless", "--path", ".", "-s", "tests/" + label + "/restart_probe.gd",
                "--", mode, restart_file,
            ]))
    if args.week >= 10:
        entries.append(run_step("art_01_assets", [sys.executable, "tools/quality/validate_art_pass_assets.py"]))
        entries.append(run_step("week_10_audio_assets", [sys.executable, "tools/quality/validate_week_ten_audio.py"]))
        entries.append(run_step("art_01_tests", [engine, "--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd",
            "-gdir=res://tests/art_pass_01", "-ginclude_subdirs", "-gexit", "-gjunit_xml_file=reports/art_pass_01.xml"]))
        art = ET.parse(ROOT / "reports/art_pass_01.xml").getroot()
        art_count = int(art.attrib.get("tests", 0))
        if art_count < 45 or int(art.attrib.get("failures", 0)) or any(int(p.attrib.get("skipped", 0)) for p in art.findall("testsuite")):
            raise RuntimeError("ART baseline regression")
        count += art_count
        groups.append({"week": "art_pass_01", "tests": art_count, "failures": 0, "skipped": 0})
        for mode in ["write", "read"]:
            entries.append(run_step("art_01_restart_" + mode, [engine, "--headless", "--path", ".", "-s",
                "tests/art_pass_01/restart_probe.gd", "--", mode, str(ROOT / "reports/art_01_restart")]))
    if args.week >= 2:
        entries.append(run_step("week_02_risk_metrics", [
            engine, "--headless", "--path", ".", "-s", "tests/week_02/risk_metrics.gd",
            "--", str(ROOT / "reports/week_02_risk_metrics.json"),
        ]))
    if args.negative_control:
        injection = ROOT / "tests/week_01/test_failure_injection.gd"
        if injection.exists():
            raise RuntimeError("Refusing to overwrite existing failure-injection file")
        try:
            injection.write_text('extends GutTest\n\nfunc test_gate_rejects_failure() -> void:\n\tassert_true(false, "intentional gate control")\n')
            entries.append(run_step("negative_control", [
                engine, "--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd",
                "-gtest=res://tests/week_01/test_failure_injection.gd", "-gexit",
            ], expected_failure=True))
        finally:
            injection.unlink(missing_ok=True)
            injection.with_suffix(".gd.uid").unlink(missing_ok=True)
    result = {"week": args.week, "groups": groups, "engine": actual, "tests": count, "failures": failures,
              "skipped": skipped, "negative_control": args.negative_control, "steps": entries}
    (ROOT / f"reports/week_{args.week:02d}_checks.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"WEEK {args.week:02d} PASS: {count} tests, {failures} failures; cumulative regressions")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError, ET.ParseError) as exc:
        print(f"QUALITY GATE FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
