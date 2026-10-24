"""ART-01 gate: retain W01–W09, then verify the new live presentation and sources."""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    steps = []
    steps.append(run_step("art_01_cumulative", [sys.executable, "tools/quality/run_checks.py", "--week", "9", "--negative-control"]))
    steps.append(run_step("art_01_assets", [sys.executable, "tools/quality/validate_art_pass_assets.py"]))
    engine = engine_binary()
    steps.append(run_step("art_01_tests", [engine, "--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd",
        "-gdir=res://tests/art_pass_01", "-ginclude_subdirs", "-gexit", "-gjunit_xml_file=reports/art_pass_01.xml"]))
    suite = ET.parse(ROOT / "reports/art_pass_01.xml").getroot()
    count = int(suite.attrib.get("tests", 0))
    failures = int(suite.attrib.get("failures", 0))
    skipped = sum(int(part.attrib.get("skipped", 0)) for part in suite.findall("testsuite"))
    if count < 45 or failures or skipped:
        raise RuntimeError(f"ART-01 invalid suite: {count} tests, {failures} failed, {skipped} skipped")
    restart = str(ROOT / "reports/art_01_restart")
    for mode in ["write", "read"]:
        steps.append(run_step("art_01_restart_" + mode, [engine, "--headless", "--path", ".", "-s",
            "tests/art_pass_01/restart_probe.gd", "--", mode, restart]))
    cumulative = json.loads((ROOT / "reports/week_09_checks.json").read_text())
    result = {"art_tests": count, "historical_tests": cumulative["tests"], "tests": count + cumulative["tests"],
              "failures": failures, "skipped": skipped, "steps": steps, "negative_control": True,
              "visual_approval": "separate_native_review", "windows_device": "not_run_on_macos"}
    (ROOT / "reports/art_pass_01_checks.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"ART-01 PASS: {result['tests']} tests ({count} new), no failures/skips")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError, ET.ParseError) as exc:
        print("ART-01 GATE FAILED:", exc, file=sys.stderr)
        sys.exit(1)
