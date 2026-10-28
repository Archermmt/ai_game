"""Regression and native fidelity gates for winter rendering; performance separate."""
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
from weather_immersion_checks import LEAKS

OUT = ROOT / 'reports/week_14/winter_optimization'


def step(name, command, timeout=300):
    result = run_step(name, command, timeout=timeout)
    path = ROOT / ('reports/' + name + '.log')
    assert not LEAKS.search(path.read_text()), name + ' leaked resources'
    shutil.copy2(path, OUT / (name + '.log'))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--headless-only', action='store_true')
    group.add_argument('--native-only', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    receipt = OUT / ('headless_checks.json' if args.headless_only else 'native_checks.json' if args.native_only else 'checks.json')
    receipt.unlink(missing_ok=True)
    environment = preflight()
    before = production_files()
    names = ['features/weather_plugins/blanket_snow_renderer.gd',
             'features/landscape/production_grass_renderer.gd',
             'features/landscape/production_playground.gd',
             'tests/week_14/winter_optimization/test_winter_rendering.gd',
             'tests/week_14/winter_optimization/winter_optimization_probe.gd']
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}
    command = [sys.executable, 'tools/quality/weather_adoption_checks.py']
    command += ['--native-only'] if args.native_only else ['--cumulative']
    if args.headless_only:
        command.append('--headless-only')
    steps = [step('winter_opt_prior', command, timeout=1500)]
    adoption = json.loads((ROOT / 'reports/week_14/weather_adoption' / ('native_checks.json' if args.native_only else 'checks.json')).read_text())
    assert adoption['passed'] and adoption['production_unchanged']
    tests = assertions = 0
    if not args.native_only:
        xml = OUT / 'tests.xml'
        xml.unlink(missing_ok=True)
        steps.append(step('winter_opt_unit', [engine_binary(), '--headless', '--path', str(ROOT),
            '-s', 'addons/gut/gut_cmdln.gd', '-gtest=res://tests/week_14/winter_optimization/test_winter_rendering.gd',
            '-gexit', '-gjunit_xml_file=' + str(xml.relative_to(ROOT))]))
        suite = ET.parse(xml).getroot()
        for row in suite.iter():
            assert row.tag not in ['failure', 'error', 'skipped']
            assert all(int(row.get(key, 0)) == 0 for key in ['failures', 'errors', 'skipped', 'disabled'])
        tests = int(suite.get('tests', 0))
        assertions = sum(int(row.get('assertions', 0)) for row in suite.iter('testcase'))
        assert tests == 6 and assertions >= 40
    pixels = None
    if not args.headless_only:
        (OUT / 'result.json').unlink(missing_ok=True)
        steps.append(step('winter_opt_pixels', [engine_binary(), '--audio-driver', 'Dummy', '--path', str(ROOT),
            '--script', 'res://tests/week_14/winter_optimization/winter_optimization_probe.gd'], timeout=420))
        pixels = json.loads((OUT / 'result.json').read_text())
        assert pixels['passed'] and pixels['rendering_driver'] == 'metal'
        assert len(pixels['comparisons']) == 36
        for row in pixels['comparisons']:
            assert row['difference'] <= row['noise'] + 0.00025 and row['significant_fraction'] <= 0.003
        assert pixels['source_unchanged'] and pixels['instance_count_unchanged']
    assert before == production_files(), 'Winter regression changed formal saves/preferences'
    assert hashes == {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}
    receipt.write_text(json.dumps({'passed': True, 'environment': environment, 'source_hashes': hashes,
        'steps': steps, 'adoption': adoption, 'new_tests': tests, 'new_assertions': assertions,
        'pixel_comparisons': pixels, 'production_unchanged': True,
        'performance_gate_run': False, 'windows_verified': False}, indent=2) + '\n')
    print('WINTER OPTIMIZATION CHECKS PASS:', tests, 'new tests;', 36 if pixels else 0, 'pixel pairs')


if __name__ == '__main__':
    main()
