"""PERF-01 serial native probes; keep legacy gates and first-draw diagnostic separate."""
import argparse
import json
from common import ROOT, engine_binary
from run_checks import run_step
from hover_native_checks import main as hover_main
import week_ten_native_checks as native


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--silent-audio', action='store_true')
    args = parser.parse_args()
    audio = ['--audio-driver', 'Dummy'] if args.silent_audio else []
    hover_main('perf_01', audio)
    result = json.loads((ROOT / 'reports/perf_01_native_checks.json').read_text())
    native.OUT = ROOT / 'reports/perf_01/native'
    probes = {'capacity': result['capacity']}
    probes['demo'] = native.probe('demo_edit', ['--ux-select', '--edit-benchmark'], 60, audio_args=audio)
    probes['large_brush'] = native.probe('capacity_large_brush',
        ['--w09-stress', '--ux-select', '--edit-benchmark', '--large-brush-benchmark'], 60, audio_args=audio)
    targets = {
        'frame_p95_20ms': all(p['p95_frame_ms'] <= 20 for p in probes.values()),
        'local_edit_p95_150ms': all(probes[k]['metrics']['commit_latency_p95_ms'] <= 150 for k in ['capacity', 'demo']),
        'large_brush_500ms': probes['large_brush']['metrics']['commit_latency_max_ms'] <= 500,
        'main_callback_100ms': all(p['metrics']['main_callback_max_ms'] <= 100 for p in probes.values()),
        'rss_2gib': all(p['rss_peak_bytes'] < 2 * 1024**3 for p in probes.values()),
    }
    phases = {}
    for name, flags in [('legacy', ['--edit-benchmark']), ('visible', ['--perf-visible-input'])]:
        output = ROOT / f'reports/perf_01/phases_{name}.json'
        run_step('perf01_latency_' + name, [engine_binary(), *audio, '--path', str(ROOT), '--resolution', '1920x1080',
            '-s', 'tests/perf_01/editor_latency_probe.gd', '--', '--qa-settings', '--art-fhd', '--w09-stress',
            '--ux-select', '--perf-report=' + str(output), *flags])
        phases[name] = json.loads(output.read_text())
        assert len(phases[name]['commits_ms']) == 20 and phases[name]['warmup_edits'] == 0
    result.update({'probes': probes, 'combined_targets': targets, 'phases': phases,
                   'm4_approved': False, 'm5_approved': False,
                   'protocol_note': 'Legacy pre-draw 60-second gates retained; first-visible-input is a separate diagnostic, never substitutes them'})
    (ROOT / 'reports/perf_01_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PERF-01 native functional PASS; unchanged performance gates:', targets)


if __name__ == '__main__': main()
