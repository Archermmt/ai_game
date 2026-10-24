"""Fixed-camera native painterly views with unchanged world and production files."""
import argparse
import json
import struct
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files

VIEWS = ['overview_default_focus', 'overview_sharp', 'cottage_detail', 'pond_walk',
         'forest_walk', 'grass_detail', 'summer_sky', 'autumn_overview', 'winter_overview',
         'sunset_walk', 'night_walk']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', default='painterly_after')
    parser.add_argument('--diagnostic', action='store_true')
    args = parser.parse_args()
    assert args.label in ['painterly_before', 'painterly_after']
    folder = ROOT / 'reports' / args.label
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'report.json').unlink(missing_ok=True)
    before = production_files()
    step = run_step(args.label, [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/painterly_views_probe.gd', '--', '--qa-settings', '--art-fhd', str(folder)], timeout=120)
    result = json.loads((folder / 'report.json').read_text())
    assert result['passed'] and all(result['checks'].values())
    for name in VIEWS:
        data = (folder / (name+'.png')).read_bytes()
        assert struct.unpack_from('>II', data, 16) == (1920, 1080)
    assert production_files() == before
    assert 'were leaked' not in (ROOT / ('reports/'+args.label+'.log')).read_text()
    result.update(step=step, views=VIEWS, production_unchanged=True, physical_audio_verified=False, audio='Dummy', foreground_window=True)
    (ROOT / ('reports/'+args.label+'_checks.json')).write_text(json.dumps(result, indent=2)+'\n')
    if args.diagnostic:
        diagnostic = ROOT / 'reports/painterly_diagnostic'
        diagnostic.mkdir(exist_ok=True)
        diagnostic_step = run_step('painterly_diagnostic', [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
            '--resolution', '1920x1080', '-s', 'tests/week_13/painterly_render_diagnostic.gd', '--', '--qa-settings', '--art-fhd', str(diagnostic)], timeout=90)
        diagnosis = json.loads((diagnostic / 'report.json').read_text())
        assert diagnosis['passed'] and production_files() == before
        result['shadow_diagnostic'] = diagnosis
        result['diagnostic_step'] = diagnostic_step
        (ROOT / ('reports/'+args.label+'_checks.json')).write_text(json.dumps(result, indent=2)+'\n')
    print('PASS fixed-camera painterly views:', len(VIEWS))


if __name__ == '__main__':
    main()
