"""W11 visible feedback and identical 60-second performance scenarios; no human inference."""
import json
import struct
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main():
    out = ROOT / 'reports/week_11/native'
    out.mkdir(parents=True, exist_ok=True)
    native.OUT = out
    before = production_files()
    target = out / 'feedback_150'
    run_step('w11_visible_feedback', [engine_binary(), '--path', '.', '--resolution', '1920x1080',
             '-s', 'tests/week_11/usability_probe.gd', '--', '--qa-settings', '--art-fhd', str(target)])
    feedback = json.loads(target.with_suffix('.json').read_text())
    assert all(feedback[k] for k in ['context_visible', 'context_status_visible',
        'context_inside_viewport', 'feedback_inside_viewport', 'cancel_inside_viewport'])
    assert struct.unpack_from('>II', target.with_suffix('.png').read_bytes(), 16) == (1920, 1080)
    metrics = {}
    for name, flags in [('demo_edit', []), ('capacity_edit', ['--w09-stress']),
                        ('capacity_large_brush', ['--w09-stress', '--large-brush-benchmark'])]:
        metrics[name] = native.probe(name, ['--hide-ui', '--edit-benchmark', *flags], 60)
    assert production_files() == before, 'QA changed formal saves/preferences'
    targets = {'local_p95_150ms': all(metrics[k]['metrics']['commit_latency_p95_ms'] <= 150
                                    for k in ['demo_edit', 'capacity_edit']),
               'large_brush_500ms': metrics['capacity_large_brush']['metrics']['commit_latency_max_ms'] <= 500,
               'frame_p95_20ms': all(r['p95_frame_ms'] <= 20 for r in metrics.values()),
               'callback_100ms': all(r['metrics']['main_callback_max_ms'] <= 100 for r in metrics.values()),
               'rss_2gib': all(r['rss_peak_bytes'] < 2 * 1024**3 for r in metrics.values())}
    result = {'functional_passed': True, 'feedback': feedback, 'metrics': metrics, 'targets': targets,
              'production_unchanged': True, 'device': 'Apple M4 Pro / macOS / Metal',
              'gpu_timer': None, 'minimum_spec_pc': 'not_run', 'windows_real_device': 'not_run',
              'actual_first_players': 0, 'm4_approved': False}
    (ROOT / 'reports/week_11_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W11 native functional PASS; performance:', targets, flush=True)


if __name__ == '__main__':
    main()
