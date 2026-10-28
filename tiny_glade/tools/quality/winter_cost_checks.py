"""Serial 3 x 6 winter ablations; diagnostic evidence, never G4 acceptance."""
import hashlib
import json
import math
import shutil
import statistics
import subprocess
from pathlib import Path

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import run_step
from weather_immersion_checks import LEAKS


def power():
    return subprocess.check_output(['pmset', '-g', 'batt'], text=True).strip()


def main():
    out = ROOT / 'reports/week_14/winter_cost'
    out.mkdir(parents=True, exist_ok=True)
    for name in ['native.json', 'checks.json']:
        (out / name).unlink(missing_ok=True)
    environment = preflight()
    before = production_files()
    environment['power_before'] = power()
    files = ['features/landscape/production_grass.gdshader',
             'features/weather_plugins/blanket_snow_renderer.gd',
             'features/weather_plugins/sunshine_cloud_adapter.gd',
             'tests/week_14/production_landscape/winter_cost_probe.gd',
             'tools/quality/winter_cost_checks.py']
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}
    step = run_step('winter_cost_native', [engine_binary(), '--always-on-top',
        '--audio-driver', 'Dummy', '--path', str(ROOT), '--script',
        'res://tests/week_14/production_landscape/winter_cost_probe.gd'], timeout=480)
    log = ROOT / 'reports/winter_cost_native.log'
    assert not LEAKS.search(log.read_text()), 'Native diagnostic leaked resources'
    shutil.copy2(log, out / 'native.log')
    result = json.loads((out / 'native.json').read_text())
    modes = ['full', 'no_caps', 'no_clouds', 'no_grass', 'no_snowfall', 'all_off']
    assert result['driver'] == 'metal' and result['viewport'] == [1920, 1080]
    assert result['vsync'] == 0 and result['max_fps'] == 0
    assert result['source_unchanged'] and result['history_unchanged']
    rows = result['rows']
    assert len(rows) == 18 and {(r['mode'], r['repeat']) for r in rows} == {
        (mode, repeat) for mode in modes for repeat in [1, 2, 3]}
    for row in rows:
        samples = row['intervals_ms']
        assert len(samples) >= 100 and row['duration_ms'] >= 10000
        assert all(math.isfinite(x) and x > 0 for x in samples)
        assert sorted(samples)[math.ceil(len(samples) * 0.95) - 1] == row['p95_ms']
    summary = {mode: {'p95_samples_ms': [r['p95_ms'] for r in rows if r['mode'] == mode],
        'median_p95_ms': statistics.median(r['p95_ms'] for r in rows if r['mode'] == mode),
        'median_draw_calls': statistics.median(r['draw_calls'] for r in rows if r['mode'] == mode)}
        for mode in modes}
    environment['power_after'] = power()
    assert before == production_files()
    assert hashes == {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}
    (out / 'checks.json').write_text(json.dumps({'passed': True, 'environment': environment,
        'source_hashes': hashes, 'step': step, 'summary': summary, 'native': result,
        'production_unchanged': True, 'g4_accepted': False,
        'protocol': 'TAA, no MSAA, frozen animation, 3s warmup and 10s accelerated full orbit per mode; alternate order in round 2; not GPU timing or a 60s G4 run'}, indent=2) + '\n')
    print(json.dumps(summary, indent=2), flush=True)
    print('WINTER COST DIAGNOSTIC PASS: 18 samples; G4 acceptance remains separate')


if __name__ == '__main__':
    main()
