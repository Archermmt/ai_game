"""Winter snow blanket and sparse dry grass in the actual production scene."""
import json
import shutil
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    out = ROOT / 'reports/week_14/winter_cover'
    out.mkdir(parents=True, exist_ok=True)
    result_path = out / 'checks.json'
    result_path.unlink(missing_ok=True)
    before = production_files()
    xml = out / 'weather.xml'
    xml.unlink(missing_ok=True)
    steps = [run_step('winter_weather_tests', [engine_binary(), '--headless', '--path', str(ROOT),
        '-s', 'addons/gut/gut_cmdln.gd', '-gtest=res://tests/week_13/test_weather_blend.gd',
        '-gexit', '-gjunit_xml_file=' + str(xml)], timeout=90)]
    suite = ET.parse(xml).getroot()
    tests = int(suite.get('tests', 0))
    assert tests >= 9, 'Empty/incomplete weather suite'
    for row in suite.iter():
        assert row.tag not in ['failure', 'error', 'skipped']
        assert all(int(row.get(key, 0)) == 0 for key in ['failures', 'errors', 'skipped'])
    assertions = sum(int(row.get('assertions', 0)) for row in suite.iter('testcase'))
    assert assertions > 0
    (out / 'result.json').unlink(missing_ok=True)
    steps.append(run_step('winter_cover_native', [engine_binary(), '--audio-driver', 'Dummy',
        '--path', str(ROOT), '--script',
        'res://tests/week_14/production_landscape/winter_cover_probe.gd'], timeout=150))
    native = json.loads((out / 'result.json').read_text())
    assert native['passed'] and len(native['checks']) >= 31 and all(native['checks'].values())
    assert native['rendering_driver'] == 'metal'
    assert before == production_files(), 'Winter QA changed formal saves or preferences'
    result = {'passed': True, 'weather_tests': tests, 'assertions': assertions,
              'native_checks': len(native['checks']), 'samples': native['samples'],
              'production_unchanged': True, 'steps': steps,
              'windows_verified': False, 'performance_gate_run': False}
    result_path.write_text(json.dumps(result, indent=2) + '\n')
    for label in ['winter_weather_tests', 'winter_cover_native']:
        shutil.copy2(ROOT / ('reports/' + label + '.log'), out / (label + '.log'))
    print('WINTER COVER PASS:', tests, 'weather tests;', len(native['checks']), 'native checks')


if __name__ == '__main__':
    main()
