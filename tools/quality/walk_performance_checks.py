"""Capacity first-person walking/looking performance,30s after entering the mode."""
import json
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    before = production_files()
    path = ROOT / 'reports/walk_performance.json'
    path.unlink(missing_ok=True)
    step = run_step('walk_performance', [engine_binary(), '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/walk_performance_probe.gd', '--', '--qa-settings',
        '--art-fhd', '--w09-stress', str(path)], timeout=65)
    result = json.loads(path.read_text())
    assert result['frames'] > 300 and result['duration_ms'] >= 30000
    assert result['safe_support'] and result['source_unchanged']
    assert before == production_files()
    assert 'were leaked' not in (ROOT / 'reports/walk_performance.log').read_text()
    result.update(step=step, frame_budget_passed=result['p95_frame_ms'] <= 20,
                  production_unchanged=True, audio='Dummy', physical_audio_verified=False,
                  note='24-house/1000-instance layout, walking/turning30s after mode entry; no cold-start or edit-latency claim')
    path.write_text(json.dumps(result, indent=2) + '\n')
    print('Walk performance data PASS, p95:', result['p95_frame_ms'], 'budget:', result['frame_budget_passed'])
    if not result['frame_budget_passed']:
        raise RuntimeError('First-person walking exceeds the 20ms frame-p95 budget; report retained')


if __name__ == '__main__':
    main()
