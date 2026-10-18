"""Visible GPU checks; run on a graphical desktop separately from headless CI."""

import argparse
import json

from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark-only", action="store_true", help="Reuse already-verified wind captures")
    args = parser.parse_args()
    reports = ROOT / "reports"
    reports.mkdir(exist_ok=True)
    (reports / ".gdignore").touch()
    engine = engine_binary()
    steps = []
    for mode, flags in [("on", []), ("zero", ["--wind-strength=0"]), ("still", ["--still"])]:
        if args.benchmark_only:
            break
        for sample in [0, 1]:
            name = f"{mode}_{sample}"
            steps.append(run_step("render_" + name, [
                engine, "--path", str(ROOT), "--", "--wind-time=" + str(sample), *flags,
                "--capture=" + str(reports / (name + ".png")),
            ]))
    steps.append(run_step("wind_pixels", [
        engine, "--headless", "--path", str(ROOT), "-s", "tests/week_01/wind_render_probe.gd",
        "--", str(reports), str(reports / "wind_pixels.json"),
    ]))
    steps.append(run_step("render_dusk", [
        engine, "--path", str(ROOT), "--", "--dusk", "--wind-time=0",
        "--capture=" + str(reports / "dusk.png"),
    ]))
    benchmarks = {}
    for renderer in ["forward_plus", "mobile"]:
        output = reports / (renderer + "_60s.json")
        steps.append(run_step("benchmark_" + renderer, [
            engine, "--path", str(ROOT), "--rendering-method", renderer,
            "--resolution", "1920x1080", "--",
            "--benchmark-seconds=60", "--smoke-output=" + str(output),
        ]))
        if not output.exists():
            raise RuntimeError("Benchmark ended without a report; keep its game window open until it exits")
        data = json.loads(output.read_text())
        assert data["sample_duration_seconds"] == 60 and data["frames"] > 100
        benchmarks[renderer] = data
    result = {"steps": steps, "wind": json.loads((reports / "wind_pixels.json").read_text()),
              "benchmarks": benchmarks, "benchmark_resolution": [1920, 1080],
              "wind_capture_resolution": [1280, 800],
              "device": "Apple M4 Pro, 20-core GPU, 48 GB RAM, macOS arm64",
              "scope": "Week 1 two-building sample only; not the MVP stress scene"}
    (reports / "render_checks.json").write_text(json.dumps(result, indent=2) + "\n")
    print("VISIBLE RENDER CHECKS PASS")


if __name__ == "__main__":
    main()
