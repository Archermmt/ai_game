"""Actual scene audio wiring and lifecycle; Dummy is not physical listening QA."""
import json
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    before = production_files()
    step = run_step('seasonal_music_native', [engine_binary(), '--audio-driver', 'Dummy',
        '--path', '.', '-s', 'tests/week_13/music_native_probe.gd', '--', '--qa-settings'], timeout=60)
    path = ROOT / 'reports/seasonal_music_native.json'
    result = json.loads(path.read_text())
    assert result['passed'] and len(result['checks']) == 10 and all(result['checks'].values())
    assert production_files() == before, 'Music probe touched formal saves/preferences'
    result.update(step=step, production_unchanged=True)
    path.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS10 native music checks; formal files unchanged; physical listening separate')


if __name__ == '__main__':
    main()
