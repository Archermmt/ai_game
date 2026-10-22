"""Serial W10 native mixer, accessible settings, photography and capacity probes."""
import json
import os
from pathlib import Path
import struct
import subprocess
import time
from common import ROOT, engine_binary
from run_checks import ERRORS, run_step
from art_pass_render_checks import production_files

OUT = ROOT / 'reports/week_10/native'


def probe(name, flags, seconds=0, audio_args=None):
    report = OUT / (name + '.json')
    command = [engine_binary(), *(audio_args or []), '--path', str(ROOT), '--verbose', '--resolution', '1920x1080', '--', '--qa-settings', '--art-fhd',
               '--smoke-output=' + str(report), '--capture=' + str(OUT / (name + '.png')), *flags]
    if seconds:
        command.append('--benchmark-seconds=' + str(seconds))
    started = time.monotonic()
    rss = []
    with (OUT / (name + '.log')).open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        while process.poll() is None:
            if time.monotonic() - started > 180:
                process.kill()
                process.wait()
                raise RuntimeError('Native timeout: ' + name)
            if os.name != 'nt':
                reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], text=True, capture_output=True).stdout.strip()
                if reading.isdigit():
                    rss.append(int(reading) * 1024)
            time.sleep(.25)
    assert process.returncode == 0 and not ERRORS.search((OUT / (name + '.log')).read_text()), name
    data = json.loads(report.read_text())
    capacity = '--w09-stress' in flags
    assert data['buildings'] == (24 if capacity else 3)
    assert data['instances'] == (1000 if capacity else 170)
    assert data['viewport_size'] == [1920, 1080]
    assert struct.unpack_from('>II', (OUT / (name + '.png')).read_bytes(), 16) == (1920, 1080)
    if '--edit-benchmark' in flags:
        assert data['edit_metrics']['probe_edits'] == (8 if '--large-brush-benchmark' in flags else 20)
    result = {'report': str(report.relative_to(ROOT)), 'rss_peak_bytes': max(rss) if rss else None,
              'p95_frame_ms': data['p95_frame_ms'], 'seconds': time.monotonic() - started, 'metrics': data['edit_metrics']}
    print(name, 'p95=', result['p95_frame_ms'], 'commit=', result['metrics']['commit_latency_max_ms'], flush=True)
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    before = production_files()
    run_step('week_10_native_audio', [engine_binary(), '--path', str(ROOT), '-s', 'tests/week_10/audio_native_probe.gd'])
    audio = json.loads((ROOT / 'reports/week_10_audio_native.json').read_text())
    assert audio['passed'] and audio['audio_driver'] != 'Dummy' and audio['effect_events'] == 24
    settings = probe('settings_150', ['--w10-settings-zoom', '--w08-reduced'])
    x, y, width, height = settings['metrics']['settings_rect']
    assert x >= 0 and y >= 0 and x + width <= 1920 and y + height <= 1080
    run_step('week_10_photography', [engine_binary(), '--path', str(ROOT), '--', '--qa-settings', '--art-fhd',
        '--w09-photo-probe', '--photo-output=' + str(OUT), '--smoke-output=' + str(OUT / 'photo_smoke.json')])
    photo = json.loads((OUT / 'photo_report.json').read_text())
    assert all(row['ok'] for row in photo['results']) and photo['failure_retry']
    assert all(photo[k] for k in ['source_unchanged', 'camera_restored', 'selection_restored', 'outline_restored'])
    run_step('week_10_png_decode', [engine_binary(), '--headless', '--path', str(ROOT), '-s', 'tests/week_09/image_probe.gd', '--', str(OUT)])
    metrics = {}
    for name, flags in [('demo_edit', []), ('capacity_edit', ['--w09-stress']),
                        ('capacity_large_brush', ['--w09-stress', '--large-brush-benchmark'])]:
        metrics[name] = probe(name, ['--hide-ui', '--edit-benchmark', *flags], 60)
    assert production_files() == before, 'QA touched formal saves/preferences'
    targets = {'local_150ms': all(metrics[k]['metrics']['commit_latency_max_ms'] <= 150 for k in ['demo_edit', 'capacity_edit']),
               'large_brush_500ms': metrics['capacity_large_brush']['metrics']['commit_latency_max_ms'] <= 500,
               'p95_20ms': all(row['p95_frame_ms'] <= 20 for row in metrics.values()),
               'callback_100ms': all(row['metrics']['main_callback_max_ms'] <= 100 for row in metrics.values()),
               'rss_2gib': all(row['rss_peak_bytes'] < 2 * 1024**3 for row in metrics.values())}
    result = {'audio': audio, 'settings': settings, 'photo': photo, 'metrics': metrics, 'targets': targets,
              'production_unchanged': True, 'gpu_timing': None, 'windows_device': 'not_run_on_macos',
              'human_first_players': 0, 'functional_checks_passed': True, 'm4_performance_passed': all(targets.values())}
    (ROOT / 'reports/week_10_native_checks.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print('W10 native functional checks PASS; performance targets:', targets)


if __name__ == '__main__':
    main()
