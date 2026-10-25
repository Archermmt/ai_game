"""G0: cumulative/tool regressions or serial native old-grass baselines."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
from common import ROOT, engine_binary, toolchain
from run_checks import ERRORS, run_step
from art_pass_render_checks import production_files
from painterly_views_checks import VIEWS

OUT = ROOT / 'reports/week_14/g0'


def preflight():
    engine = engine_binary()
    version = subprocess.check_output([engine, '--version'], text=True).strip()
    lock = toolchain()
    assert version.startswith(lock['godot']['version'] + '.stable'), version
    expected = next(row['sha256'] for row in lock['godot']['selected_runtime_files']
                    if row['path'].endswith('/MacOS/Godot'))
    actual = hashlib.sha256(Path(engine).read_bytes()).hexdigest()
    assert actual == expected, 'Executable differs from pinned macOS runtime'
    packages = json.loads(subprocess.check_output(
        [str(ROOT / '.venv/bin/python'), '-m', 'pip', 'list', '--format=json'], text=True))
    installed = {row['name'].lower(): row['version'] for row in packages}
    for line in (ROOT / 'tools/requirements-dev.lock.txt').read_text().splitlines():
        name, version_value = line.split('==')
        assert installed.get(name.lower()) == version_value, name
    return {'engine': version, 'engine_sha256': actual,
            'python': sys.version, 'locked_python_packages': installed,
            'revision': os.environ.get('WINDHAVEN_SOURCE_REVISION') or subprocess.check_output(
                ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()}


def walk_baseline(layout):
    path = OUT / (layout + '_walk.json')
    log_path = OUT / (layout + '_walk.log')
    path.unlink(missing_ok=True)
    command = [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--resolution', '1920x1080', '-s', 'tests/week_13/walk_performance_probe.gd', '--',
               '--qa-settings', '--art-fhd', '--walk-seconds=60', '--baseline-capture',
               *(['--w09-stress'] if layout == 'capacity' else []), str(path)]
    started = time.monotonic()
    rss = []
    with log_path.open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        try:
            while process.poll() is None:
                if time.monotonic() - started > 120:
                    raise RuntimeError('G0 walking baseline timed out')
                reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)],
                                         text=True, capture_output=True, check=True).stdout.strip()
                if reading.isdigit():
                    rss.append(int(reading) * 1024)
                time.sleep(0.25)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    log_text = log_path.read_text()
    assert process.returncode == 0 and not ERRORS.search(log_text), log_text[-4000:]
    assert 'Metal' in log_text and 'Forward+' in log_text, 'Baseline must use native Metal Forward+'
    data = json.loads(path.read_text())
    assert data['layout'] == layout and data['requested_seconds'] == 60
    assert data['frames'] > 300 and data['duration_ms'] >= 60000
    assert len(data['trajectory']) >= 60 and data['safe_support'] and data['source_unchanged']
    assert data['history_unchanged']
    samples = data['frame_intervals_ms']
    assert len(samples) == data['frames'] and all(math.isfinite(x) and x > 0 for x in samples)
    assert data['p95_frame_ms'] == sorted(samples)[math.ceil(len(samples) * 0.95) - 1]
    assert data['buildings'] == (24 if layout == 'capacity' else 3)
    assert data['instances'] == (1000 if layout == 'capacity' else 170)
    assert data['viewport_size'] == [1920, 1080] and data['grass_density'] == 0.45
    for suffix in ['_start.png', '_end.png']:
        assert struct.unpack_from('>II', path.with_name(path.stem + suffix).read_bytes(), 16) == (1920, 1080)
    assert rss, 'No real RSS samples collected'
    data.update(rss_peak_bytes=max(rss), frame_budget_passed=data['p95_frame_ms'] <= 20,
                memory_budget_passed=max(rss) <= 2 * 1024**3, command=command,
                audio='Dummy; physical audio unverified', gpu_timing_ms=None,
                input_protocol='held W, horizontal look 0.3 radians/second, recorded 1Hz feet positions',
                cold_start_verified=False, edit_latency_verified=False)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('G0', layout, 'p95', data['p95_frame_ms'], 'ms; RSS', max(rss), flush=True)
    return {key: value for key, value in data.items() if key not in ['frame_intervals_ms', 'trajectory']}


def native_baselines():
    before = production_files()
    views = OUT / 'views'
    views.mkdir(exist_ok=True)
    step = run_step('g0_fixed_views', [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy',
        '--path', str(ROOT), '--resolution', '1920x1080', '-s', 'tests/week_13/painterly_views_probe.gd',
        '--', '--qa-settings', '--art-fhd', str(views)], timeout=120)
    checks = json.loads((views / 'report.json').read_text())
    assert checks['passed'] and checks['checks'] and all(checks['checks'].values())
    for name in VIEWS:
        assert struct.unpack_from('>II', (views / (name + '.png')).read_bytes(), 16) == (1920, 1080)
    shutil.copyfile(ROOT / 'reports/g0_fixed_views.log', OUT / 'fixed_views.log')
    rows = {layout: walk_baseline(layout) for layout in ['demo', 'capacity']}
    after = production_files()
    assert before == after, 'G0 modified formal saves/preferences'
    result = {'environment': preflight(), 'fixed_views': VIEWS, 'fixed_view_checks': checks,
              'view_step': step, 'walk_baselines': rows, 'production_before': before,
              'production_after': after, 'production_unchanged': True,
              'old_grass_only': True, 'new_assets_imported': False, 'windows_verified': False}
    (OUT / 'native_baseline.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    # Preserve genuine baseline failures for diagnosis rather than hiding them in historical data.
    if not all(row['frame_budget_passed'] and row['memory_budget_passed'] for row in rows.values()):
        raise RuntimeError('Current old-grass baseline exceeds budget; evidence retained')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-only', action='store_true', help='Serial visible GPU baselines; run after functional gate')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    environment = preflight()
    if args.native_only:
        native_baselines()
        return
    steps = [run_step('g0_python_tests', [sys.executable, 'tests/week_14/run_python_checks.py'])]
    steps.append(run_step('g0_cumulative', [sys.executable, 'tools/quality/week_thirteen_checks.py'], timeout=800))
    historical = json.loads((ROOT / 'reports/week_13_checks.json').read_text())
    python = json.loads((OUT / 'python_checks.json').read_text())
    assert historical['godot_tests'] >= 745 and python['tests'] >= 9
    assert not any(python[key] for key in ['failures', 'errors', 'skipped'])
    result = {'environment': environment, 'godot_tests': historical['godot_tests'],
              'python_tests': historical['python_tests'] + python['tests'],
              'new_python_tests': python['tests'], 'failures': 0, 'skipped': 0,
              'negative_control': historical['negative_control'], 'functional_gate_passed': True, 'steps': steps}
    assert result['negative_control']
    (OUT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('G0 FUNCTIONAL PASS:', result['godot_tests'], 'Godot +', result['python_tests'], 'Python')


if __name__ == '__main__':
    main()
