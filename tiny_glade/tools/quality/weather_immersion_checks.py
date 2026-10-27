"""W14 weather plugin lab and production walker contacts; no performance approval."""

import argparse
import hashlib
import json
import re
import shutil
import struct
import sys
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import run_step

OUT = ROOT / 'reports/week_14/weather_immersion'
LEAKS = re.compile(r'\bRIDs?.*leaked|RID allocations|ObjectDB instances?.*leaked', re.I)
EXPECTED_SUITES = {
    'tests/week_14/immersive/test_walker_grass.gd': 7,
    'tests/week_14/immersion/test_snow_footprints.gd': 8,
    'tests/week_14/production_landscape/test_production_landscape.gd': 9,
    'tests/week_14/production_landscape/test_grass_capacity.gd': 3,
}


def strict_step(name, command, timeout=240):
    step = run_step(name, command, timeout=timeout)
    log = ROOT / ('reports/' + name + '.log')
    assert not LEAKS.search(log.read_text()), 'Resource leak: ' + name
    shutil.copy2(log, OUT / (name + '.log'))
    return step


def validate_plugins():
    results = {}
    for label, lock_name in [('clouds', 'sunshine_clouds'), ('snow', 'puchik_snow')]:
        lock = json.loads((ROOT / ('features/weather_plugins/' + lock_name + '.lock.json')).read_text())
        assert len(lock['commit']) == 40 and lock['files']
        paths = {}
        for relative, entry in lock['files'].items():
            path = ROOT / relative if label == 'clouds' else ROOT / 'addons/puchik_snow' / relative
            assert path.is_file(), path
            assert path.stat().st_size == entry['bytes'], path
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
            paths[str(path.relative_to(ROOT))] = entry['sha256']
        for relative, entry in lock.get('import_settings', {}).items():
            path = ROOT / 'addons/puchik_snow' / relative
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
            params = {line.split('=', 1)[0]: line.split('=', 1)[1]
                      for line in path.read_text().split('[params]', 1)[1].splitlines() if '=' in line}
            assert all(params.get(key) == value for key, value in entry['upstream_parameters'].items()), path
            paths[str(path.relative_to(ROOT))] = entry['sha256']
        results[label] = {'commit': lock['commit'], 'files': paths}
    assert 'SunshineClouds2' not in (ROOT / 'project.godot').read_text(), 'Runtime adapter owns cloud lab'
    return results


def inspect_tests(path):
    root = ET.parse(path).getroot()
    suites = {row.get('name'): row for row in root.findall('testsuite')}
    assert set(suites) == set(EXPECTED_SUITES), suites.keys()
    for name, minimum in EXPECTED_SUITES.items():
        assert int(suites[name].get('tests', 0)) >= minimum, name
        assert sum(int(row.get('assertions', 0)) for row in suites[name].iter('testcase')) > 0, name
    assert any(row.get('name') == 'test_fence_only_publication_and_cancel_refresh_actual_footprint_contact_surface'
               for row in root.iter('testcase')), 'Fence-only footprint publication regression was omitted'
    assert any(row.get('name') == 'test_exit_returns_grass_while_restored_photo_time_remains_frozen'
               for row in root.iter('testcase')), 'Frozen-photo exit regression was omitted'
    for row in root.iter():
        assert row.tag not in ['failure', 'error', 'skipped'], row.attrib
        assert all(int(row.get(key, 0)) == 0 for key in ['failures', 'errors', 'skipped', 'disabled'])
    tests = int(root.get('tests', 0))
    assertions = sum(int(row.get('assertions', 0)) for row in root.iter('testcase'))
    assert tests >= 27 and assertions > 0, 'Incomplete/empty regression run'
    return {'tests': tests, 'assertions': assertions, 'failures': 0, 'skipped': 0}


def native_gate(label, script, folder, minimum):
    result_file = folder / 'result.json'
    result_file.unlink(missing_ok=True)
    step = strict_step(label, [engine_binary(), '--audio-driver', 'Dummy', '--path', str(ROOT),
                              '-s', script], timeout=300)
    result = json.loads(result_file.read_text())
    assert result['passed'] and len(result['checks']) >= minimum and all(result['checks'].values())
    assert result['rendering_driver'] == 'metal', 'This receipt is specifically the macOS Metal gate'
    images = result['images']
    for resource in images.values() if isinstance(images, dict) else images:
        assert resource.startswith('res://reports/'), resource
        path = ROOT / resource.removeprefix('res://')
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) > 1024
        size = struct.unpack_from('>II', data, 16)
        assert size in [(1440, 900), (1920, 1080), (2560, 1440)], size
    result['step'] = step
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cumulative', action='store_true', help='Also run required W01-W09 and negative control')
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--headless-only', action='store_true')
    args = parser.parse_args()
    assert not (args.native_only and args.headless_only)
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'reports/.gdignore').touch()
    report_path = OUT / ('native_checks.json' if args.native_only else 'checks.json')
    report_path.unlink(missing_ok=True)
    before = production_files()
    environment = preflight()
    steps = []
    steps.append(strict_step('weather_immersion_import', [engine_binary(), '--headless', '--path',
        str(ROOT), '--editor', '--import']))
    plugins = validate_plugins()
    regression = cumulative = None
    if not args.native_only:
        if args.cumulative:
            steps.append(strict_step('weather_immersion_cumulative', [sys.executable,
                'tools/quality/run_checks.py', '--week', '9', '--negative-control'], timeout=1200))
            cumulative = json.loads((ROOT / 'reports/week_09_checks.json').read_text())
            assert cumulative['tests'] >= 446 and cumulative['negative_control']
        xml = OUT / 'tests.xml'
        xml.unlink(missing_ok=True)
        steps.append(strict_step('weather_immersion_tests', [engine_binary(), '--headless', '--path',
            str(ROOT), '-s', 'addons/gut/gut_cmdln.gd',
            '-gdir=res://tests/week_14/immersive,res://tests/week_14/immersion,res://tests/week_14/production_landscape',
            '-gexit', '-gjunit_xml_file=' + str(xml.relative_to(ROOT))], timeout=900))
        regression = inspect_tests(xml)
    weather = immersion = None
    if not args.headless_only:
        weather = native_gate('weather_plugin_native', 'tests/week_14/weather_plugin_native_probe.gd',
                              ROOT / 'reports/weather_plugins/native', 44)
        immersion = native_gate('immersion_native', 'tests/week_14/immersion_native_probe.gd',
                                ROOT / 'reports/immersion/native', 73)
        assert weather['measurements']['multiview']['full_multiview_approval'] is False
        assert weather['geometric_snow_thickness'] is False
        assert immersion['real_keyboard_walking'] and immersion['baseline_sky_only']
    assert before == production_files(), 'QA changed real saves/preferences'
    assert plugins == validate_plugins(), 'QA changed pinned upstream files/import settings'
    report = {'passed': True, 'environment': environment, 'plugins': plugins,
              'regression': regression, 'cumulative': cumulative, 'steps': steps,
              'weather_native': weather, 'immersion_native': immersion,
              'production_before': before, 'production_after': production_files(),
              'production_unchanged': True, 'performance_gate_run': False,
              'windows_real_device_verified': False, 'thick_snow_approved': False,
              'clouds_formal_default': False}
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('WEATHER / IMMERSION PASS', regression, 'native:', weather is not None)


if __name__ == '__main__':
    main()
