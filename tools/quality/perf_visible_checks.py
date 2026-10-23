"""PERF-02 real GUI inputs after first draw, independent of legacy terrain gates."""

import argparse
import json
import math
import struct
import subprocess

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from run_checks import run_step

BEGINNINGS = ('motion', 'press', 'change', 'release')
ENDINGS = ('publish', 'draw', 'grass_settle_draw')
TIMING_FIELDS = {f'{beginning}_to_{ending}_ms' for beginning in BEGINNINGS for ending in ENDINGS}


def validate_report(data, capacity):
    """Reject empty, partial, synthetic, warm-started, or reordered timing records."""
    assert data['functional_passed'] and data['warmup_edits'] == 0
    assert data['protocol'] == 'first_visible_real_gui_roof_input'
    assert data['initial_grass_wait'] is False and data['legacy_terrain_probe_replaced'] is False
    assert data['viewport_size'] == [1920, 1080]
    assert data['buildings'] == (24 if capacity else 3)
    assert data['instances'] == (1000 if capacity else 170)
    assert data['runtime_metrics']['grass_density'] == .45
    assert data['runtime_metrics']['meadow_visible'] > 0
    assert len(data['samples']) == 20 and data['render_frame_intervals_ms']
    assert len(data['runtime_metrics']['commit_latency_samples_ms']) == 20
    assert len(data['runtime_metrics']['rebuild_phase_timings']) == 20
    assert data['samples'][0]['history_before'] == 0, 'Unreported warmup/history exists'
    assert set(data['summary']) == TIMING_FIELDS, 'Timing summary must be complete'
    assert data['first_draw_usec'] >= data['started_usec'] > 0
    assert data['first_input_usec'] >= data['first_draw_usec']
    assert data['samples'][0]['motion_usec'] == data['first_input_usec']
    previous = None
    for index, sample in enumerate(data['samples']):
        assert sample['index'] == index and sample['publication_count'] == 1
        assert sample['revision_after'] == sample['revision_before'] + 1
        assert sample['roof_before'] != sample['roof_after']
        stamps = [sample[name + '_usec'] for name in
                  ['motion', 'press', 'change', 'release', 'publish', 'draw', 'grass_settle_draw']]
        assert stamps[0] > 0 and stamps == sorted(stamps)
        assert sample['grass_visible'] > 0 and sample['grass_total'] >= sample['grass_visible']
        for beginning in BEGINNINGS:
            for ending in ENDINGS:
                actual = sample[f'{beginning}_to_{ending}_ms']
                expected = (sample[ending + '_usec'] - sample[beginning + '_usec']) / 1000
                assert not isinstance(actual, bool) and math.isfinite(actual) and actual >= 0
                assert math.isclose(actual, expected, rel_tol=0, abs_tol=1e-8), 'Duration differs from raw stamps'
        if previous:
            assert sample['revision_before'] == previous['revision_after']
            assert sample['history_before'] == previous['history_before'] + 1
            assert sample['motion_usec'] >= previous['grass_settle_draw_usec']
        previous = sample
    for key, summary in data['summary'].items():
        values = sorted(sample[key] for sample in data['samples'])
        assert set(summary) == {'p95', 'max'}
        assert math.isclose(summary['p95'], values[math.ceil(.95 * len(values)) - 1], rel_tol=0, abs_tol=1e-8)
        assert math.isclose(summary['max'], values[-1], rel_tol=0, abs_tol=1e-8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--silent-audio', action='store_true')
    parser.add_argument('--runs', type=int, default=3)
    parser.add_argument('--layout', choices=['demo', 'capacity', 'both'], default='both')
    args = parser.parse_args()
    assert args.runs >= 1
    out = ROOT / 'reports/perf_02/visible_input'
    out.mkdir(parents=True, exist_ok=True)
    before = production_files()
    audio = ['--audio-driver', 'Dummy'] if args.silent_audio else []
    probes = []
    layouts = ['demo', 'capacity'] if args.layout == 'both' else [args.layout]
    for layout in layouts:
        for index in range(args.runs):
            name = f'{layout}_{index + 1:02d}'
            path = out / (name + '.json')
            flags = ['--w09-stress'] if layout == 'capacity' else []
            step = run_step('perf02_visible_' + name, [engine_binary(), *audio, '--path', str(ROOT),
                '--resolution', '1920x1080', '-s', 'tests/perf_02/visible_input_probe.gd', '--',
                '--qa-settings', '--art-fhd', '--ux-select', '--perf-report=' + str(path), *flags])
            data = json.loads(path.read_text())
            validate_report(data, layout == 'capacity')
            assert struct.unpack_from('>II', path.with_suffix('.png').read_bytes(), 16) == (1920, 1080)
            assert production_files() == before, 'Visible input QA touched formal saves/preferences'
            probes.append({'layout': layout, 'run': index + 1, 'report': str(path.relative_to(ROOT)),
                           'step': step, 'first_sample': data['samples'][0], 'summary': data['summary'],
                           'startup_first_draw_ms': data['startup_first_draw_ms'],
                           'first_draw_to_input_ms': data['first_draw_to_input_ms'],
                           'render_frame_interval_p95_ms': data['render_frame_interval_p95_ms']})
    targets = {}
    for metric in ['motion_to_publish_ms', 'motion_to_draw_ms', 'press_to_publish_ms',
                   'press_to_draw_ms', 'release_to_publish_ms', 'release_to_draw_ms']:
        targets[metric + '_p95_150ms'] = all(p['summary'][metric]['p95'] <= 150 for p in probes)
        targets[metric + '_max_150ms'] = all(p['summary'][metric]['max'] <= 150 for p in probes)
    targets['render_frame_interval_p95_20ms'] = all(p['render_frame_interval_p95_ms'] <= 20 for p in probes)
    result = {'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'protocol': 'first_visible_real_gui_roof_input', 'probes': probes,
              'independent_processes': len(probes), 'warmup_edits': 0, 'functional_passed': True,
              'diagnostic_targets': targets, 'production_unchanged': True,
              'native_audio_output_verified': False, 'qa_audio_arguments': audio,
              'm4_approved': False, 'm5_approved': False,
              'note': 'Separate diagnostic; keeps legacy 20-edit/60-second terrain gates. '
                      'Render completion is frame_post_draw, not physical scanout. '
                      'First input does not wait for meadow; later isolated samples do.'}
    (ROOT / 'reports/perf_02_visible_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PERF-02 real GUI input functional PASS; independent diagnostic targets:', targets)


if __name__ == '__main__':
    main()
