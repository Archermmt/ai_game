#!/usr/bin/env python3
"""Run I1 native-renderer evidence and regressions, failing on engine script errors."""
import argparse
import hashlib
import json
import platform
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/reports/art_i1'
ERRORS = re.compile(r'SCRIPT ERROR:|^ERROR:|Assertion failed|Parse Error', re.MULTILINE)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--only', choices=['native', 'rules', 'all'], default='all')
    args = parser.parse_args()
    if not args.godot:
        parser.error('godot must be on PATH or supplied with --godot')
    (OUT / 'logs').mkdir(parents=True, exist_ok=True)
    inputs = sorted({*ROOT.glob('game/**/*.gd'), *ROOT.glob('game/**/*.tscn'),
                     *ROOT.glob('game/**/*.glb'), *ROOT.glob('tests/*.gd'),
                     ROOT / 'game/art_lab/fixtures/bay_baseline.json', ROOT / 'project.godot'})
    source_hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in inputs}
    steps = []
    def run(name, options, marker, expect_failure=False):
        start = time.monotonic()
        try:
            proc = subprocess.run([args.godot, '--path', str(ROOT), *options], cwd=ROOT,
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
            output, code = proc.stdout, proc.returncode
        except subprocess.TimeoutExpired as exc:
            output = str(exc.stdout or '') + '\nTIMEOUT after 90s'
            code = -999
        (OUT / 'logs' / (name + '.log')).write_text(output)
        # A failed pixel comparison is expected only for the explicit negative control.
        okay = ((code == 1 and marker in output) if expect_failure else
                (code == 0 and marker in output and not ERRORS.search(output)))
        steps.append(dict(name=name, passed=okay, exit_code=code,
                          expected_failure=expect_failure, seconds=round(time.monotonic()-start, 3),
                          log='logs/' + name + '.log'))
        print(('PASS ' if okay else 'FAIL ') + name, flush=True)
        if not okay:
            print(output[-3000:], flush=True)
        return okay
    passed = True
    if args.only in ('native', 'all'):
        for renderer, extra in [('gl_compatibility', []), ('forward_plus', ['--rendering-driver', 'metal'])]:
            render = ['--rendering-method', renderer, *extra]
            passed &= run('colors_' + renderer, render + ['res://game/art_lab/color_probe.tscn'], 'COLOR_PROBE')
            passed &= run('materials_' + renderer, render + ['res://game/art_lab/material_probe.tscn'], 'MATERIAL_PROBE_PASS')
            passed &= run('materials_negative_' + renderer, render + ['res://game/art_lab/material_probe.tscn', '--', '--negative-control'], 'MATERIAL_PROBE_NEGATIVE', True)
            passed &= run('normal_negative_' + renderer, render + ['res://game/art_lab/material_probe.tscn', '--', '--normal-negative-control'], 'MATERIAL_PROBE_NEGATIVE', True)
            passed &= run('bay_' + renderer, render + ['res://game/art_lab/art_lab.tscn', '--', '--label=' + renderer], 'ART_LAB_PASS')
            passed &= run('app_' + renderer, render + ['--script', 'tests/test_app.gd'], 'PASS UI signals')
    if args.only in ('rules', 'all'):
        for file in ['test_world', 'test_building', 'test_residents', 'test_playable', 'test_bridge_activity', 'test_static_batcher']:
            passed &= run(file, ['--headless', '--script', 'tests/' + file + '.gd'], 'PASS')
        passed &= run('static_batcher_negative', ['--headless', '--script', 'tests/test_static_batcher.gd', '--', '--negative-control'], 'FAIL static batcher', True)
        passed &= run('assets', ['--headless', '--script', 'game/art/verify_assets.gd'], 'PASS')
    report = dict(passed=bool(passed), host=platform.platform(), machine=platform.machine(),
                  scope=args.only, steps=steps, source_sha256=source_hashes,
                  limits='Local M4 Pro only; does not validate M1/Windows, full PRD stress or artistic acceptance')
    (OUT / ('suite_' + args.only + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return 0 if passed else 1

if __name__ == '__main__':
    raise SystemExit(main())
