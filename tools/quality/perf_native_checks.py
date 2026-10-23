"""PERF-01 serial native probes; keep legacy gates and first-draw diagnostic separate."""
import argparse
import json
from common import ROOT, engine_binary
from run_checks import run_step
from hover_native_checks import main as hover_main
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main(label="perf_01"):
    parser = argparse.ArgumentParser()
    parser.add_argument('--silent-audio', action='store_true')
    parser.add_argument('--followup', action='store_true', help='Archive the same protocol under PERF-02')
    args = parser.parse_args()
    if args.followup:
        label = 'perf_02'
    before = production_files()
    audio = ['--audio-driver', 'Dummy'] if args.silent_audio else []
    hover_main(label, audio)
    result = json.loads((ROOT / f'reports/{label}_native_checks.json').read_text())
    native.OUT = ROOT / f'reports/{label}/native'
    probes = {'capacity': result['capacity']}
    probes['demo'] = native.probe('demo_edit', ['--ux-select', '--edit-benchmark'], 60, audio_args=audio)
    probes['large_brush'] = native.probe('capacity_large_brush',
        ['--w09-stress', '--ux-select', '--edit-benchmark', '--large-brush-benchmark'], 60, audio_args=audio)
    targets = {
        'frame_p95_20ms': all(p['p95_frame_ms'] <= 20 for p in probes.values()),
        'local_edit_p95_150ms': all(probes[k]['metrics']['commit_latency_p95_ms'] <= 150 for k in ['capacity', 'demo']),
        'legacy_upper_local_150ms': all(probes[k]['metrics']['commit_latency_legacy_upper_ms'] <= 150 for k in ['capacity', 'demo']),
        'large_brush_500ms': probes['large_brush']['metrics']['commit_latency_max_ms'] <= 500,
        'main_callback_100ms': all(p['metrics']['main_callback_max_ms'] <= 100 for p in probes.values()),
        'rss_2gib': all(p['rss_peak_bytes'] < 2 * 1024**3 for p in probes.values()),
    }
    for name, probe in probes.items():
        count = 8 if name == 'large_brush' else 20
        assert len(probe['metrics']['commit_latency_samples_ms']) == count
        assert len(probe['metrics']['rebuild_phase_timings']) == count
    phases = {}
    for name, flags in [('legacy', ['--edit-benchmark']), ('visible', ['--perf-visible-input'])]:
        output = ROOT / f'reports/{label}/phases_{name}.json'
        run_step(label + '_latency_' + name, [engine_binary(), *audio, '--path', str(ROOT), '--resolution', '1920x1080',
            '-s', 'tests/perf_01/editor_latency_probe.gd', '--', '--qa-settings', '--art-fhd', '--w09-stress',
            '--ux-select', '--perf-report=' + str(output), *flags])
        phases[name] = json.loads(output.read_text())
        assert len(phases[name]['commits_ms']) == 20 and phases[name]['warmup_edits'] == 0
    assert production_files() == before, 'Performance QA changed formal saves/preferences'
    result.update({'probes': probes, 'combined_targets': targets, 'phases': phases,
                   'm4_approved': False, 'm5_approved': False,
                   'protocol_note': 'Pre-draw 60-second samples retained. p95 corrected to nearest-rank; raw samples, maximum and previous upper statistic retained. Visible-input is a separate diagnostic.'})
    (ROOT / f'reports/{label}_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print(label.upper() + ' native functional PASS; unchanged performance gates:', targets)


if __name__ == '__main__': main()
