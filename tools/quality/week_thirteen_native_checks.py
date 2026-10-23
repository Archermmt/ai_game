"""W13 native illustrations, fictional calendar, four seasons and weather."""
import json
import struct
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    out = ROOT / 'reports/week_13/native'
    out.mkdir(parents=True, exist_ok=True)
    before = production_files()
    step = run_step('week_13_native', [engine_binary(), '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/native_probe.gd', '--', '--qa-settings', '--art-fhd', str(out)])
    result = json.loads((out / 'native_report.json').read_text())
    assert result['passed'] and len(result['checks']) >= 10 and all(result['checks'].values())
    for name in ['illustrated_build', 'spring', 'summer', 'autumn_cloud', 'winter_snow', 'rain_lightning', 'night', 'calendar_150', 'cloud_shadow_a', 'cloud_shadow_b', 'relief_overview']:
        assert struct.unpack_from('>II', (out / (name + '.png')).read_bytes(), 16) == (1920, 1080)
    assert production_files() == before, 'W13 touched formal saves/preferences'
    result.update({'step': step, 'production_unchanged': True, 'qa_audio': 'Dummy', 'real_audio_verified': False, 'windows_real_device': False})
    (ROOT / 'reports/week_13_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W13 native PASS:', len(result['checks']), 'checks; real-device gates separate')


if __name__ == '__main__':
    main()
