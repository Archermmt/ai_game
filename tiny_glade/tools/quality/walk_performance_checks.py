"""Capacity first-person walking/looking performance,30s after entering the mode."""
import json
import argparse
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--transitions', action='store_true')
    args = parser.parse_args()
    label = 'walk_transition_performance' if args.transitions else 'walk_performance'
    (ROOT / 'reports').mkdir(exist_ok=True)
    before = production_files()
    path = ROOT / ('reports/' + label + '.json')
    path.unlink(missing_ok=True)
    step = run_step(label, [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/walk_performance_probe.gd', '--', '--qa-settings',
        '--art-fhd', '--w09-stress', *(['--climate-cycle'] if args.transitions else []), str(path)], timeout=65)
    result = json.loads(path.read_text())
    assert result['frames'] > 300 and result['duration_ms'] >= 30000
    assert result['safe_support'] and result['source_unchanged']
    assert before == production_files()
    assert 'were leaked' not in (ROOT / ('reports/' + label + '.log')).read_text()
    if args.transitions:
        assert result['climate_transitions'] and result['max_visible_weather_types'] >= 2
    result.update(step=step, frame_budget_passed=result['p95_frame_ms'] <= 20,
                  production_unchanged=True, audio='Dummy', foreground_window=True, physical_audio_verified=False,
                  note='24-house/1000-instance layout, walking/turning30s after mode entry; optional6s weather retargets; no cold-start or edit-latency claim')
    path.write_text(json.dumps(result, indent=2) + '\n')
    print('Walk performance data PASS, p95:', result['p95_frame_ms'], 'budget:', result['frame_budget_passed'])
    if not result['frame_budget_passed']:
        raise RuntimeError('First-person walking exceeds the 20ms frame-p95 budget; report retained')


if __name__ == '__main__':
    main()
