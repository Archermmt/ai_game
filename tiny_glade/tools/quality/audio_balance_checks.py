"""Current wind/music balance: strict audio regressions and actual engine PCM."""
import argparse
import json
import sys
import xml.etree.ElementTree as ET

from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cumulative', action='store_true', help='Also run the required W01-W09 negative-control gate')
    args = parser.parse_args()
    out = ROOT / 'reports/week_14/audio_balance'
    out.mkdir(parents=True, exist_ok=True)
    result_file = out / 'checks.json'
    result_file.unlink(missing_ok=True)
    steps = []
    if args.cumulative:
        steps.append(run_step('audio_balance_w09', [sys.executable,
            'tools/quality/run_checks.py', '--week', '9', '--negative-control'], timeout=360))
    groups = []
    for label, path, expected in [('world_audio', 'tests/week_10/test_audio.gd', 10),
                                  ('seasonal_audio', 'tests/week_13/test_seasonal_music.gd', 6)]:
        xml = out / (label + '.xml')
        xml.unlink(missing_ok=True)
        steps.append(run_step('audio_balance_' + label, [engine_binary(), '--headless',
            '--path', str(ROOT), '-s', 'addons/gut/gut_cmdln.gd', '-gtest=res://' + path,
            '-gexit', '-gjunit_xml_file=' + str(xml)], timeout=120))
        suite = ET.parse(xml).getroot()
        assert int(suite.get('tests', 0)) == expected, 'Empty/incomplete audio suite'
        for row in [suite, *suite.findall('testsuite')]:
            assert all(int(row.get(field, 0)) == 0 for field in ['failures', 'errors', 'skipped', 'disabled'])
        cases = list(suite.iter('testcase'))
        assertions = sum(int(row.get('assertions', 0)) for row in cases)
        assert assertions > 0 and not any(row.find(field) is not None for row in cases
                                         for field in ['failure', 'error', 'skipped'])
        groups.append({'suite': label, 'tests': expected, 'assertions': assertions})
    for label, script in [('controls', 'seasonal_music_native_checks.py'),
                          ('sources', 'validate_week_ten_audio.py'),
                          ('music_assets', 'validate_seasonal_music.py')]:
        steps.append(run_step('audio_balance_' + label, [sys.executable, 'tools/quality/' + script], timeout=90))
    mixes = {}
    for weather in ['clear', 'storm']:
        steps.append(run_step('audio_balance_pcm_' + weather, [sys.executable,
            'tools/quality/seasonal_music_mix_checks.py', '--driver', 'CoreAudio',
            '--weather', weather], timeout=65))
        suffix = '_storm' if weather == 'storm' else ''
        mix = json.loads((ROOT / ('reports/music_mix_CoreAudio' + suffix + '.json')).read_text())
        assert mix['calibration_passed'] and mix['production_unchanged'] and not mix['baseline']
        mixes[weather] = {'music_to_ambient_db': mix['music_to_ambient_db'],
                          'music_to_wind_db': mix['music_to_wind_db']}
    cumulative = None
    if args.cumulative:
        cumulative = json.loads((ROOT / 'reports/week_09_checks.json').read_text())
        assert cumulative['negative_control'] and cumulative['tests'] >= 446
    result = {'passed': True, 'cumulative_run': args.cumulative,
              'week09_tests': cumulative['tests'] if cumulative else None,
              'audio_tests': groups, 'native_controls': 10, 'mixes': mixes,
              'physical_listening_verified': False, 'steps': steps}
    result_file.write_text(json.dumps(result, indent=2) + '\n')
    print('AUDIO BALANCE PASS: 16 audio tests, 10 native controls, clear/storm CoreAudio PCM')


if __name__ == '__main__':
    main()
