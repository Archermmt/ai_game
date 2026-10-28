"""G4 preview functional checks; performance is a separate, strict failing gate."""
import argparse
import json
import shutil
import sys

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-only', action='store_true')
    args = parser.parse_args()
    out = ROOT / 'reports/week_14/g4'
    out.mkdir(parents=True, exist_ok=True)
    result_path = out / 'functional_checks.json'
    result_path.unlink(missing_ok=True)
    before = production_files()
    steps = []
    functional = None
    if not args.native_only:
        steps.append(run_step('capacity_landscape_tests', [sys.executable,
            'tools/quality/production_landscape_checks.py', '--skip-import'], timeout=240))
        functional = json.loads((ROOT / 'reports/week_14/production_landscape/checks.json').read_text())
        assert functional['passed'] and functional['focused']['tests'] >= 11
        assert functional['focused']['capacity_tests'] == 3
    (out / 'ui').mkdir(exist_ok=True)
    (out / 'ui/result.json').unlink(missing_ok=True)
    steps.append(run_step('capacity_ui_native', [engine_binary(), '--audio-driver', 'Dummy',
        '--path', str(ROOT), '--script',
        'res://tests/week_14/production_landscape/capacity_ui_probe.gd'], timeout=180))
    native = json.loads((out / 'ui/result.json').read_text())
    assert native['passed'] and len(native['checks']) >= 11 and all(native['checks'].values())
    assert native['rendering_driver'] == 'metal'
    assert before == production_files(), 'G4 GUI probe changed real saves/preferences'
    result = {'functional_passed': True, 'headless_run': not args.native_only,
              'focused_tests': functional['focused'] if functional else None,
              'native_checks': len(native['checks']), 'steps': steps,
              'production_unchanged': True, 'g4_performance_approved': False,
              'windows_verified': False}
    result_path.write_text(json.dumps(result, indent=2) + '\n')
    shutil.copy2(ROOT / 'reports/capacity_ui_native.log', out / 'ui/native.log')
    print('G4 CAPACITY FUNCTIONAL PASS:', len(native['checks']), 'native checks; performance separate')


if __name__ == '__main__':
    main()
