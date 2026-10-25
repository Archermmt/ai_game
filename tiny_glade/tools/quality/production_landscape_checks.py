"""Production F5 landscape gates. Real edits/storage/photo proof; no FPS/RSS gate."""

import argparse
import json
import shutil
import struct
import sys
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from landscape_lab_checks import validate_scatter_plugin, validate_terrain_plugin
from painterly_grass_g0_checks import preflight
from run_checks import run_step
from validate_valley_fidelity import validate

OUT = ROOT / 'reports/week_14/production_landscape'
SUITE = 'tests/week_14/production_landscape/test_production_landscape.gd'


def inspect_junit(path):
    root = ET.parse(path).getroot()
    suites = {row.get('name'): row for row in root.findall('testsuite')}
    assert SUITE in suites, 'Production F5 suite was omitted'
    count = int(root.get('tests', 0))
    assert count >= 8, f'Empty/incomplete production run: {count}'
    for row in [root, *suites.values()]:
        assert all(int(row.get(field, 0)) == 0 for field in
                   ['failures', 'errors', 'skipped', 'disabled']), row.attrib
    suite = suites[SUITE]
    cases = list(suite.iter('testcase'))
    assert int(suite.get('tests', 0)) >= 8 and cases
    assert not any(case.find(field) is not None for case in cases
                   for field in ['failure', 'error', 'skipped'])
    assertions = sum(int(row.get('assertions', 0)) for row in cases)
    assert assertions > 0, 'Assertion-free production test run'
    return {'tests': count, 'assertions': assertions, 'failures': 0, 'skipped': 0}


def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack_from('>II', data, 16)


def native_gate(before):
    folder = OUT / 'native'
    folder.mkdir(parents=True, exist_ok=True)
    result_file = folder / 'result.json'
    result_file.unlink(missing_ok=True)
    (OUT / 'native_checks.json').unlink(missing_ok=True)
    run_step('production_landscape_native_parse', [engine_binary(), '--headless', '--path',
        str(ROOT), '--script',
        'res://tests/week_14/production_landscape/production_landscape_native_probe.gd',
        '--check-only'], timeout=60)
    step = run_step('production_landscape_native', [engine_binary(), '--audio-driver', 'Dummy',
        '--path', str(ROOT), '--resolution', '1920x1080', '--script',
        'res://tests/week_14/production_landscape/production_landscape_native_probe.gd'], timeout=360)
    result = json.loads(result_file.read_text())
    assert result['passed'] and len(result['checks']) >= 40
    assert all(result['checks'].values()) and result['rendering_driver'] in ['metal', 'vulkan']
    assert result['gpu_origin_error_m'] < 0.002
    assert result['performance_gate_run'] is False
    assert len(result['images']) == 9
    for resource_path in result['images']:
        assert resource_path.startswith('res://reports/week_14/production_landscape/native/')
        assert png_size(ROOT / resource_path.removeprefix('res://')) == (1920, 1080)
    assert len(result['exports']) == 2 and all(row['ok'] for row in result['exports'])
    for name, size in [('photo_1080.png', (1920, 1080)), ('photo_2k.png', (2560, 1440))]:
        assert png_size(folder / name) == size
    assert before == production_files(), 'Native regression touched production files'
    result.update(step=step, production_before=before, production_after=production_files(),
                  production_unchanged=True, windows_real_device_verified=False)
    (OUT / 'native_checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    shutil.copyfile(ROOT / 'reports/production_landscape_native.log', folder / 'native.log')
    print('PRODUCTION LANDSCAPE NATIVE PASS:', len(result['checks']), 'checks; no performance gate')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-import', action='store_true')
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--cumulative', action='store_true', help='Also run W01-W14 and landscape-lab regressions')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'reports/.gdignore').touch()
    environment = preflight()
    before = production_files()
    if args.native_only:
        native_gate(before)
        return
    (OUT / 'checks.json').unlink(missing_ok=True)
    steps = []
    if not args.skip_import:
        steps.append(run_step('production_landscape_import', [engine_binary(), '--headless',
            '--path', str(ROOT), '--editor', '--import'], timeout=240))
    assets = validate()
    plugins = {'scatter': validate_scatter_plugin(), 'terrain3d': validate_terrain_plugin()}
    cumulative = None
    if args.cumulative:
        steps.append(run_step('production_landscape_cumulative', [sys.executable,
            'tools/quality/landscape_lab_checks.py', '--cumulative'], timeout=1600))
        cumulative = json.loads((ROOT / 'reports/week_14/landscape_lab/checks.json').read_text())
        assert cumulative['cumulative_run'] and cumulative['godot_tests'] >= 781
    xml_path = OUT / 'tests.xml'
    xml_path.unlink(missing_ok=True)
    steps.append(run_step('production_landscape_tests', [engine_binary(), '--headless',
        '--path', str(ROOT), '-s', 'addons/gut/gut_cmdln.gd',
        '-gdir=res://tests/week_14/production_landscape', '-gexit',
        '-gjunit_xml_file=' + str(xml_path.relative_to(ROOT))], timeout=900))
    tests = inspect_junit(xml_path)
    assert before == production_files(), 'Production-scene regression touched real saves/preferences'
    result = {'passed': True, 'environment': environment, 'assets': assets, 'plugins': plugins,
              'focused': tests, 'steps': steps, 'production_before': before,
              'production_after': production_files(), 'production_unchanged': True,
              'cumulative_run': cumulative is not None,
              'godot_tests': cumulative['godot_tests'] + tests['tests'] if cumulative else None,
              'python_tests': cumulative['python_tests'] if cumulative else None,
              'performance_gate_run': False, 'windows_real_device_verified': False,
              'visual_acceptance': 'User accepted the lab direction; formal garden review pending'}
    (OUT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    shutil.copyfile(ROOT / 'reports/production_landscape_tests.log', OUT / 'tests.log')
    print('PRODUCTION LANDSCAPE PASS:', tests['tests'], 'focused tests; no performance gate')


if __name__ == '__main__':
    main()
