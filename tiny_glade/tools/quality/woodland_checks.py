"""Validate the editable woodland style on the pinned Godot runtime."""

import argparse
import hashlib
import json
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from demo_assets_checks import main as check_assets
from run_checks import run_step

OUT = ROOT / "reports/week_15/woodland"
SUITES = {
    "tests/art_pass_01/test_architecture_art.gd",
    "tests/week_13/test_walk_surface.gd",
    "tests/week_17/test_path_publication.gd",
    "tests/week_17/test_walkway.gd",
    "tests/week_17/test_entry.gd",
    "tests/week_17/test_partial_eaves.gd",
    "tests/week_17/test_cove.gd",
    "tests/week_16/test_woodland_refinement.gd",
    "tests/week_15/test_woodland_cottage.gd",
    "tests/week_15/test_woodland_nature.gd",
    "tests/week_15/test_woodland_layout.gd",
    "tests/week_14/production_landscape/test_production_landscape.gd",
    "tests/week_14/weather_production/test_weather_adoption.gd",
    "tests/week_13/test_living_scene.gd",
    "tests/week_13/test_painterly_environment.gd",
    "tests/garden_presentation/test_garden_scene.gd",
    "tests/week_13/test_walk.gd",
    "tests/week_14/immersive/test_walker_grass.gd",
    "tests/week_14/immersion/test_snow_footprints.gd",
    "tests/week_14/winter_optimization/test_winter_rendering.gd",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Also capture actual GPU views and HUD panels.")
    args = parser.parse_args()
    check_assets()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "checks.json").unlink(missing_ok=True)
    (ROOT / "reports/.gdignore").touch()
    before = production_files()
    engine = [engine_binary(), "--path", str(ROOT)]
    run_step("woodland_import", [*engine, "--headless", "--editor", "--import"], timeout=360)
    xml = OUT / "tests.xml"
    xml.unlink(missing_ok=True)
    run_step("woodland_focused", [
        *engine, "--headless", "-s", "addons/gut/gut_cmdln.gd", "-gexit",
        "-gtest=" + ",".join("res://" + suite for suite in sorted(SUITES)),
        "-gjunit_xml_file=" + str(xml.relative_to(ROOT)),
    ], timeout=600)
    report = ET.parse(xml).getroot()
    suites = report.findall("testsuite")
    if {suite.get("name") for suite in suites} != SUITES:
        raise RuntimeError("Missing required woodland or gameplay suites")
    for suite in suites:
        if not suite.findall("testcase") or any(int(suite.get(k, 0)) for k in ("errors", "failures", "skipped", "disabled")):
            raise RuntimeError(f"Failed, skipped or empty suite: {suite.attrib}")
    totals = {
        "tests": int(report.attrib["tests"]),
        "assertions": sum(int(test.get("assertions", 0)) for test in report.iter("testcase")),
        "suites": {suite.get("name"): int(suite.get("tests", 0)) for suite in suites},
    }
    if args.native:
        receipt = OUT / "capture.json"
        receipt.unlink(missing_ok=True)
        run_step("woodland_metal", [
            *engine, "--audio-driver", "Dummy", "--resolution", "1600x900",
            "--script", "res://tests/week_17/bridge_walk_capture.gd", "--", "--qa-settings",
        ], timeout=240)
        capture = json.loads(receipt.read_text())
        required = {"day follows path and climbs doorstep", "dusk follows path and climbs doorstep",
                    "moved door and new path published", "undo restores the original garden",
                    "partial contact built through editor transaction"}
        if (not capture["passed"] or not required.issubset(capture["checks"])
                or not all(capture["checks"].values())):
            raise RuntimeError("Woodland GPU capture failed")
        totals["capture"] = capture
        totals["images"] = {name: hashlib.sha256((OUT / (name + ".png")).read_bytes()).hexdigest()
                            for name in ("editor", "spring", "evening", "winter", "walk",
                                         "build_tools", "weather_controls", "walk_controls", "settings", "spring_export", "scaled_weather",
                                         "autumn_without_mist", "autumn_mist_6", "autumn_mist_8", "autumn_mist_10", "winter_mist",
                                         "spring_baseline_camera", "cottage_detail", "contacts_on", "contacts_off",
                                         "bridge_day", "bridge_dusk", "relocated_entry", "partial_eaves")}
    if production_files() != before:
        raise RuntimeError("Formal save or preferences changed")
    totals["player_files_unchanged"] = True
    (OUT / "checks.json").write_text(json.dumps(totals, ensure_ascii=False, indent=2) + "\n")
    print(f"Woodland: {totals['tests']} tests, {totals['assertions']} assertions.")


if __name__ == "__main__":
    main()
