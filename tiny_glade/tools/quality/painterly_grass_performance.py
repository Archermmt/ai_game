"""G4 serial 1080p capacity comparisons. Pilot is diagnostic, not a G4 sign-off."""
import argparse
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

OUT = ROOT / 'reports/week_14/g4_weather'


def run_probe(renderer, weather, density, repeat):
    name = f'{renderer}_{weather}_{round(density * 100)}_{repeat}'
    path = OUT / (name + '.json')
    path.unlink(missing_ok=True)
    log_path = OUT / (name + '.log')
    command = [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--resolution', '1920x1080', '--script',
               'res://tests/week_14/production_landscape/capacity_performance_probe.gd', '--',
               '--g4-weather=' + weather, '--g4-density=' + str(density),
               '--g4-output=' + str(path), *(['--g4-legacy'] if renderer == 'legacy' else [])]
    rss = []
    started = time.monotonic()
    with log_path.open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        try:
            while process.poll() is None:
                if time.monotonic() - started > 360:
                    raise RuntimeError(name + ' timed out')
                reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)],
                                         text=True, capture_output=True, check=True).stdout.strip()
                if reading.isdigit():
                    rss.append(int(reading) * 1024)
                time.sleep(0.25)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    log = log_path.read_text()
    assert process.returncode == 0 and not ERRORS.search(log), log[-5000:]
    assert not re.search(r'leaked|ObjectDB instances|RID allocations', log, re.I), log[-5000:]
    assert 'Metal' in log and 'Forward+' in log
    result = json.loads(path.read_text())
    assert result['renderer'] == renderer and result['terrain_renderer'] == 'Terrain3D'
    assert result['rendering_driver'] == 'metal' and result['viewport_size'] == [1920, 1080]
    assert result['volume_clouds'] and result['msaa'] == 0 and result['taa']
    assert result['snow_settled']
    if weather == 'blizzard':
        assert result['snow_visible'] and result['snow_bakes'] > 0 and result['snow_views'] > 0
    assert result['vsync_mode'] == 0, 'G4 probe must explicitly disable VSync'
    assert result['buildings'] == 24 and result['instances'] == 1000
    assert result['weather'] == weather and result['grass_density'] == density
    assert result['weather_blend_age'] >= 18 and result['grass_visible'] > 0
    assert result['source_unchanged'] and result['history_unchanged']
    frames = result['frame_intervals_ms']
    assert len(frames) == result['frames'] and len(frames) >= 300
    assert result['duration_ms'] >= 60000 and len(result['trajectory']) >= 60
    assert all(math.isfinite(value) and value > 0 for value in frames)
    assert result['p95_frame_ms'] == sorted(frames)[math.ceil(len(frames) * 0.95) - 1]
    assert rss, 'No RSS samples'
    result.update(rss_peak_bytes=max(rss), rss_samples=rss,
                  frame_budget_passed=result['p95_frame_ms'] <= 20,
                  memory_budget_passed=max(rss) <= 2 * 1024**3,
                  command=command, warmup_seconds=5, repeat=repeat)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    summary = {key: value for key, value in result.items()
               if key not in ['frame_intervals_ms', 'trajectory', 'rss_samples', 'command']}
    print(f'{name}: p95 {result["p95_frame_ms"]:.3f}ms, '
          f'RSS {max(rss) / 1024**2:.1f}MiB, budget {result["frame_budget_passed"]}', flush=True)
    return summary


def read_command(command):
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    output = result.stdout.strip() or result.stderr.strip()
    output = re.sub(r'\s*\(id=\d+\)', '', output)
    return {'exit_code': result.returncode, 'output': output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pilot', action='store_true', help='One default-density pair; no G4 sign-off')
    parser.add_argument('--weather', choices=['clear', 'storm', 'blizzard', 'duststorm'],
                        help='Weather for a single diagnostic pilot pair')
    args = parser.parse_args()
    if args.weather and not args.pilot:
        parser.error('--weather requires --pilot')
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (('pilot_' + (args.weather or 'clear') + '.json') if args.pilot else 'matrix.json')
    path.unlink(missing_ok=True)
    environment = preflight()
    environment['measured_file_sha256'] = {
        name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
            'tools/quality/painterly_grass_performance.py',
            'features/landscape/production_grass.gdshader',
            'features/landscape/production_grass_renderer.gd',
            'features/landscape/production_playground.gd',
            'features/landscape/production_terrain.gd',
            'features/weather_plugins/sunshine_cloud_adapter.gd',
            'features/weather_plugins/blanket_snow_renderer.gd',
            'features/weather_plugins/blanket_baker.gd',
            'features/painterly_grass/previews/grass_capacity.gd',
            'tests/week_14/production_landscape/capacity_performance_probe.gd']}
    environment.update(model=read_command(['sysctl', '-n', 'hw.model']),
                       memory=read_command(['sysctl', '-n', 'hw.memsize']),
                       cpu=read_command(['sysctl', '-n', 'machdep.cpu.brand_string']),
                       power=read_command(['pmset', '-g', 'batt']),
                       power_settings=read_command(['pmset', '-g', 'custom']),
                       thermal=read_command(['pmset', '-g', 'therm']))
    before = production_files()
    rows = []
    result = {'environment': environment, 'pilot': args.pilot, 'runs': rows,
              'g4_passed': False, 'matrix_complete': False, 'performance_gate_run': True,
              'windows_verified': False, 'gpu_timing_available': False,
              'protocol': '1920x1080 Metal Forward+, no MSAA, TAA, volume clouds, settled object/terrain snow, VSync disabled, fixed analytic 60s orbit, 5s warmup; identical source and Terrain3D; one process at a time',
              'remaining_gates': ['edit latency', '20-minute mixed soak', '2K export memory', 'LOD visual review']}

    def save():
        assert before == production_files(), 'Performance QA touched formal files'
        for name, expected in environment['measured_file_sha256'].items():
            assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name + ' changed during measurement'
        result['production_unchanged'] = True
        path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    cases = [(args.weather or 'clear', 0.45)] if args.pilot else [(weather, 0.45) for weather in
             ['clear', 'storm', 'blizzard', 'duststorm']]
    budget_exceeded = False
    for weather, density in cases:
        for repeat in range(1, 2 if args.pilot else 4):
            for renderer in ['legacy', 'valley']:
                rows.append(run_probe(renderer, weather, density, repeat))
                assert len({row['source_sha256'] for row in rows}) == 1, 'A/B source drift'
                save()
            if any(not row['frame_budget_passed'] or not row['memory_budget_passed'] for row in rows[-2:]):
                budget_exceeded = True
                break
        if budget_exceeded:
            break
    if not args.pilot and not budget_exceeded:
        worst = max(['storm', 'blizzard', 'duststorm'], key=lambda weather: statistics.median(
            row['p95_frame_ms'] for row in rows if row['renderer'] == 'valley' and row['weather'] == weather))
        result['worst_weather_at_default'] = worst
        for weather in ['clear', worst]:
            for repeat in range(1, 4):
                for renderer in ['legacy', 'valley']:
                    rows.append(run_probe(renderer, weather, 1.0, repeat))
                    assert len({row['source_sha256'] for row in rows}) == 1
                    save()
        result['matrix_complete'] = len(rows) == 36
    result['sampled_frame_budget_passed'] = all(row['frame_budget_passed'] for row in rows)
    result['sampled_memory_budget_passed'] = all(row['memory_budget_passed'] for row in rows)
    result['stopped_on_budget_failure'] = budget_exceeded
    result['functional_checks_passed'] = True
    comparisons = []
    for old in [row for row in rows if row['renderer'] == 'legacy']:
        new = next(row for row in rows if row['renderer'] == 'valley' and
                   all(row[key] == old[key] for key in ['weather', 'grass_density', 'repeat']))
        increase = new['p95_frame_ms'] / old['p95_frame_ms'] - 1
        comparisons.append({'weather': old['weather'], 'density': old['grass_density'],
                            'repeat': old['repeat'], 'p95_increase': increase,
                            'diagnostic_15_percent_alarm': increase > 0.15})
    result['comparisons'] = comparisons
    save()
    print('G4 pilot complete' if args.pilot else
          ('G4 matrix stopped at failed prerequisite' if budget_exceeded else 'G4 frame matrix complete'), flush=True)
    if not result['sampled_frame_budget_passed'] or not result['sampled_memory_budget_passed']:
        raise RuntimeError('Sampled budget exceeded; evidence retained; G4 not passed')


if __name__ == '__main__':
    main()
