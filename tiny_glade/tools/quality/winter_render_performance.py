"""Three serial paired 60s full winter trials. Budget failures retain evidence and fail."""
import hashlib
import json
import math
import re
import statistics
import subprocess
import time

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import ERRORS
from weather_immersion_checks import LEAKS

OUT = ROOT / 'reports/week_14/winter_optimization/performance'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    receipt = OUT / 'checks.json'
    receipt.unlink(missing_ok=True)
    before = production_files()
    environment = preflight()
    environment['power_before'] = subprocess.check_output(['pmset', '-g', 'batt'], text=True).strip()
    names = ['features/weather_plugins/blanket_snow_renderer.gd',
             'features/landscape/production_grass_renderer.gd',
             'features/landscape/production_playground.gd',
             'features/landscape/production_grass.gdshader',
             'tests/week_14/winter_optimization/winter_performance_probe.gd',
             'tools/quality/winter_render_performance.py']
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}
    pairs = []
    result = {'environment': environment, 'source_hashes': hashes, 'pairs': pairs,
              'g4_passed': False, 'windows_verified': False, 'gpu_timing_available': False,
              'protocol': '3 independent processes, paired baseline/optimized 60s dynamic orbit, alternating order in pair 2; 5s warmup per mode; 1080p Metal TAA, no MSAA, VSync disabled, unlimited FPS; all visual effects remain enabled'}
    for repeat in [1, 2, 3]:
        output = OUT / f'pair_{repeat}.json'
        output.unlink(missing_ok=True)
        command = [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', str(ROOT),
                   '--script', 'res://tests/week_14/winter_optimization/winter_performance_probe.gd',
                   '--', f'--repeat={repeat}']
        rss = []
        started = time.monotonic()
        log_path = OUT / f'pair_{repeat}.log'
        with log_path.open('w') as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
            try:
                while process.poll() is None:
                    if time.monotonic() - started > 330:
                        raise RuntimeError('Winter performance pair timed out')
                    reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)],
                                             text=True, capture_output=True, check=False).stdout.strip()
                    if reading.isdigit():
                        rss.append(int(reading) * 1024)
                    time.sleep(0.25)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
        log_text = log_path.read_text()
        assert process.returncode == 0 and not ERRORS.search(log_text) and not LEAKS.search(log_text), log_text[-5000:]
        assert 'Metal' in log_text and 'Forward+' in log_text and rss
        data = json.loads(output.read_text())
        assert data['driver'] == 'metal' and data['viewport'] == [1920, 1080]
        assert data['vsync'] == 0 and data['max_fps'] == 0
        assert data['buildings'] == 24 and data['instances'] == 1000
        assert data['weather'] == 'blizzard' and data['density'] == 0.45
        assert data['clouds_enabled'] and data['taa'] and data['msaa'] == 0
        assert data['source_unchanged'] and data['history_unchanged']
        assert len(data['rows']) == 2 and {r['mode'] for r in data['rows']} == {'baseline', 'optimized'}
        for row in data['rows']:
            samples = row['intervals_ms']
            assert len(samples) >= 300 and row['duration_ms'] >= 60000 and row['repeat'] == repeat
            assert all(math.isfinite(x) and x > 0 for x in samples)
            assert sorted(samples)[math.ceil(len(samples) * 0.95) - 1] == row['p95_ms']
            assert row['cap_count'] == data['rows'][0]['cap_count'] and row['cap_count'] > 1000
        data.update(rss_peak_bytes=max(rss), rss_samples=rss, command=command)
        output.write_text(json.dumps(data, indent=2) + '\n')
        assert not pairs or data['source_sha256'] == pairs[0]['source_sha256']
        pairs.append({key: value for key, value in data.items() if key not in ['command', 'rss_samples']})
        assert before == production_files(), 'Benchmark modified formal saves/preferences'
        receipt.write_text(json.dumps(result, indent=2) + '\n')
        print('PAIR', repeat, [(r['mode'], r['p95_ms']) for r in data['rows']], flush=True)
    summary = {mode: statistics.median(r['p95_ms'] for pair in pairs for r in pair['rows'] if r['mode'] == mode)
               for mode in ['baseline', 'optimized']}
    result.update(summary=summary,
                  sampled_frame_budget_passed=all(r['p95_ms'] <= 20 for pair in pairs for r in pair['rows'] if r['mode'] == 'optimized'),
                  sampled_memory_budget_passed=all(p['rss_peak_bytes'] <= 2 * 1024**3 for p in pairs),
                  production_unchanged=before == production_files())
    result['environment']['power_after'] = subprocess.check_output(['pmset', '-g', 'batt'], text=True).strip()
    assert hashes == {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}
    receipt.write_text(json.dumps(result, indent=2) + '\n')
    print('WINTER RENDER PERFORMANCE', summary, flush=True)
    if not result['sampled_frame_budget_passed'] or not result['sampled_memory_budget_passed']:
        raise RuntimeError('Winter sample budget exceeded; evidence retained; G4 not passed')


if __name__ == '__main__':
    main()
