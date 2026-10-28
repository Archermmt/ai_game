"""Production camera-specific clouds and bounded Blanket snow compatibility gates."""

import argparse
import hashlib
import json
import shutil
import sys
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import run_step
from weather_immersion_checks import LEAKS, validate_plugins

OUT = ROOT / 'reports/week_14/weather_adoption'


def step(name, command, timeout=300):
    value = run_step(name, command, timeout=timeout)
    log = ROOT / ('reports/' + name + '.log')
    assert not LEAKS.search(log.read_text()), name + ' leaked resources'
    shutil.copy2(log, OUT / (name + '.log'))
    return value


def blanket_lock():
    lock = json.loads((ROOT / 'features/weather_plugins/blanket.lock.json').read_text())
    assert lock['commit'] == '7b1166a9f03135098c80fc0aba3a19e7e0909b9f'
    assert len(lock['files']) >= 80
    for relative, entry in lock['files'].items():
        data = (ROOT / relative).read_bytes()
        assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], relative
        if relative.endswith(('.glsl', '.inc')):
            assert entry['upstream_sha256'] == entry['sha256'], 'Snow geometry compute was rewritten: ' + relative
    assert 'BlanketShaders' not in (ROOT / 'project.godot').read_text(), 'Compute must stay lazy, not a startup autoload'
    return lock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cumulative', action='store_true')
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--headless-only', action='store_true')
    args = parser.parse_args()
    assert not (args.native_only and args.headless_only)
    OUT.mkdir(parents=True, exist_ok=True)
    result_file = OUT / ('native_checks.json' if args.native_only else 'checks.json')
    result_file.unlink(missing_ok=True)
    before = production_files()
    environment = preflight()
    plugins = validate_plugins()
    blanket = blanket_lock()
    steps = []
    regressions = previous = None
    if not args.native_only:
        command = [sys.executable, 'tools/quality/weather_immersion_checks.py', '--headless-only']
        if args.cumulative:
            command.append('--cumulative')
        steps.append(step('weather_adoption_prior_regressions', command, timeout=1200))
        previous = json.loads((ROOT / 'reports/week_14/weather_immersion/checks.json').read_text())
        xml = OUT / 'tests.xml'
        xml.unlink(missing_ok=True)
        steps.append(step('weather_adoption_tests', [engine_binary(), '--headless', '--path', str(ROOT),
            '-s', 'addons/gut/gut_cmdln.gd', '-gtest=res://tests/week_14/weather_production/test_weather_adoption.gd',
            '-gexit', '-gjunit_xml_file=' + str(xml.relative_to(ROOT))]))
        suite = ET.parse(xml).getroot()
        for row in suite.iter():
            assert row.tag not in ['failure', 'error', 'skipped']
            assert all(int(row.get(key, 0)) == 0 for key in ['failures', 'errors', 'skipped', 'disabled'])
        assert int(suite.get('tests', 0)) == 9
        assertions = sum(int(row.get('assertions', 0)) for row in suite.iter('testcase'))
        assert assertions > 0
        regressions = {'new_tests': 9, 'new_assertions': assertions,
                       'focused_tests': previous['regression']['tests'] + 9,
                       'focused_assertions': previous['regression']['assertions'] + assertions,
                       'failures': 0, 'skipped': 0}
    native = immersion = None
    if not args.headless_only:
        steps.append(step('blanket_native', [engine_binary(), '--audio-driver', 'Dummy', '--path', str(ROOT),
            '-s', 'tests/week_14/weather_production/blanket_native_probe.gd']))
        assert 'BLANKET_COMPATIBILITY true' in (OUT / 'blanket_native.log').read_text()
        (ROOT / 'reports/weather_production/result.json').unlink(missing_ok=True)
        steps.append(step('weather_adoption_native', [engine_binary(), '--audio-driver', 'Dummy', '--path', str(ROOT),
            '-s', 'tests/week_14/weather_production/formal_weather_native_probe.gd'], timeout=420))
        native = json.loads((ROOT / 'reports/weather_production/result.json').read_text())
        assert native['passed'] and len(native['checks']) >= 35 and all(native['checks'].values())
        assert native['camera_histories_independent'] and native['geometric_object_snow']
        assert native['rendering_driver'] == 'metal'
        (ROOT / 'reports/immersion/native/result.json').unlink(missing_ok=True)
        steps.append(step('weather_adoption_immersion', [engine_binary(), '--audio-driver', 'Dummy', '--path', str(ROOT),
            '-s', 'tests/week_14/immersion_native_probe.gd'], timeout=300))
        immersion = json.loads((ROOT / 'reports/immersion/native/result.json').read_text())
        assert immersion['passed'] and len(immersion['checks']) >= 74 and all(immersion['checks'].values())
        assert immersion['production_clouds']
    assert before == production_files(), 'QA changed actual saves/preferences'
    assert plugins == validate_plugins() and blanket == blanket_lock(), 'Pinned plugin changed during QA'
    result = {'passed': True, 'environment': environment, 'steps': steps, 'regressions': regressions,
              'previous': previous, 'blanket': blanket, 'native': native, 'immersion': immersion,
              'production_before': before, 'production_after': production_files(), 'production_unchanged': True,
              'clouds_formal_default': True, 'object_snow_geometry': True,
              'snow_physical_deformation': False, 'performance_gate_run': False,
              'windows_real_device_verified': False}
    result_file.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('WEATHER ADOPTION PASS', regressions, 'native:', native is not None)


if __name__ == '__main__':
    main()
