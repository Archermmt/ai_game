"""First-person photography with actual UI/key/mouse input and a UI-free PNG."""
import json
import struct
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    folder = ROOT / 'reports/first_person_walk'
    folder.mkdir(parents=True, exist_ok=True)
    for name in ['walk_report.json', 'walk_export.png']:
        (folder / name).unlink(missing_ok=True)
    before = production_files()
    step = run_step('walk_native', [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/walk_native_probe.gd', '--', '--qa-settings',
        '--art-fhd', str(folder)], timeout=90)
    result = json.loads((folder / 'walk_report.json').read_text())
    assert result['passed'] and len(result['checks']) >= 18 and all(result['checks'].values())
    assert struct.unpack_from('>II', (folder / 'walk_export.png').read_bytes(), 16) == (1920, 1080)
    assert 'were leaked' not in (ROOT / 'reports/walk_native.log').read_text()
    assert before == production_files()
    result.update(step=step, production_unchanged=True, audio='Dummy', foreground_window=True, physical_trackpad_verified=False)
    (ROOT / 'reports/walk_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PASS first-person native input, PNG and camera restoration:', len(result['checks']), 'checks')


if __name__ == '__main__':
    main()
