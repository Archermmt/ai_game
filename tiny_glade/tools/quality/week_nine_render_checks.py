"""Serial W09 native/release probes: exact capacity, wall-clock samples and photo output."""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path

from common import ROOT, engine_binary
from run_checks import ERRORS


def user_files():
    directory = Path.home() / 'Library/Application Support/WindhavenDiorama/week_08/saves'
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.glob('*') if p.is_file()}


def run(name, program, flags, duration=60):
    out = ROOT / 'reports/week_09_visuals'
    report = out / (name + '.json')
    command = [*program, '--resolution', '1920x1080', '--', '--qa-settings',
               '--hide-ui', '--benchmark-seconds=' + str(duration),
               '--smoke-output=' + str(report), '--capture=' + str(out / (name + '.png')), *flags]
    rss = []
    ready_seconds = None
    ready_file = report.with_name(report.stem + "_first_draw.json")
    ready_file.unlink(missing_ok=True)
    started_unix = time.time()
    before = user_files()
    log_path = out / (name + '.log')
    started = time.monotonic()
    with log_path.open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        while process.poll() is None:
            if time.monotonic() - started > 180:
                process.kill()
                raise RuntimeError('native probe timed out: ' + name)
            output = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], text=True, capture_output=True).stdout.strip()
            if output.isdigit():
                rss.append({'elapsed_s': round(time.monotonic() - started, 3), 'rss_bytes': int(output) * 1024})
            if ready_seconds is None and ready_file.exists():
                try:
                    ready_seconds = round(json.loads(ready_file.read_text())["unix_seconds"] - started_unix, 3)
                except json.JSONDecodeError:
                    pass
            time.sleep(0.25)
    if process.returncode or ERRORS.search(log_path.read_text()):
        raise RuntimeError('engine error: ' + name)
    assert user_files() == before, 'QA modified production saves'
    data = json.loads(report.read_text())
    assert data['buildings'] == 24 and data['instances'] == (500 if '--w09-stress-reduced' in flags else 1000)
    assert data['frames'] > 100 and data['viewport_size'] == [1920, 1080]
    if '--edit-benchmark' in flags:
        assert data['edit_metrics']['probe_edits'] == (8 if '--large-brush-benchmark' in flags else 20)
    result = {'report': str(report.relative_to(ROOT)), 'process_peak_rss_bytes': max(s['rss_bytes'] for s in rss),
              'rss_samples': rss, 'production_saves_unchanged': True, 'first_draw_seconds': ready_seconds, 'wall_seconds': time.monotonic() - started,
              'p95_frame_ms': data['p95_frame_ms'], 'metrics': data['edit_metrics']}
    (out / (name + '_resident.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(name, 'p95', data['p95_frame_ms'], 'commit', data['edit_metrics']['commit_latency_max_ms'], flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--executable', type=Path)
    parser.add_argument('--startup-only', action='store_true')
    args = parser.parse_args()
    out = ROOT / 'reports/week_09_visuals'
    out.mkdir(exist_ok=True)
    program = [str(args.executable.resolve())] if args.executable else [engine_binary(), '--path', str(ROOT)]
    if args.startup_only:
        summary_path = ROOT / 'reports/week_09_render_checks.json'
        summary = json.loads(summary_path.read_text())
        trials = [run('startup_' + str(i), program, ['--w09-stress'], duration=5) for i in range(3)]
        summary['startup_trials'] = trials
        summary['tentative_targets']['load_5s'] = all(t['first_draw_seconds'] is not None and t['first_draw_seconds'] <= 5 for t in trials)
        summary['startup_measurement_note'] = 'Separate trials after replacing a buffered stdout marker with a flushed first-draw JSON marker; 60s timing runs are retained unchanged.'
        summary_path.write_text(json.dumps(summary, indent=2) + '\n')
        return
    result = {'build': 'release' if args.executable else 'runtime',
              'device': 'Apple M4 Pro / 20 GPU cores / 48 GB / macOS arm64',
              'settings': '1920x1080 Forward+ Metal; inherited medium MVP settings; 2s warmup then 60s wall-clock',
              'gpu_timing': None, 'runs': {}}
    for name, flags in [('stress_idle', []), ('stress_local', ['--edit-benchmark']),
                        ('stress_large', ['--edit-benchmark', '--large-brush-benchmark'])]:
        result['runs'][name] = run(name, program, ['--w09-stress', *flags])
    runs = result['runs']
    metrics = runs['stress_local']['metrics']
    big = runs['stress_large']['metrics']
    result['tentative_targets'] = {
        'p95_20ms': all(r['p95_frame_ms'] <= 20 for r in runs.values()),
        'local_150ms': metrics['commit_latency_max_ms'] <= 150,
        'large_500ms': big['commit_latency_max_ms'] <= 500,
        'measured_main_callbacks_100ms': max(metrics['main_callback_max_ms'], big['main_callback_max_ms'],
                                          metrics['preparation_slice_max_ms'], big['preparation_slice_max_ms'],
                                          metrics['main_apply_max_ms'], big['main_apply_max_ms']) <= 100,
        'load_5s': all(r['first_draw_seconds'] is not None and r['first_draw_seconds'] <= 5 for r in runs.values()),
        'resident_2gb': all(r['process_peak_rss_bytes'] <= 2 * 1024**3 for r in runs.values())}
    if not all(result['tentative_targets'].values()):
        result['runs']['reduced_local'] = run('reduced_local', program, ['--w09-stress-reduced', '--edit-benchmark'])
    (ROOT / 'reports/week_09_render_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Native data recorded; failed targets stay visible; no minimum-PC or Windows claim.')


if __name__ == '__main__':
    main()
