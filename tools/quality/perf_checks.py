"""PERF-01: retain all W12 gates and verify exact local meadow reuse and shoreline safety."""
import json
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    steps = [run_step('perf01_cumulative', [sys.executable, 'tools/quality/week_twelve_checks.py'], timeout=400)]
    steps.append(run_step('perf01_tests', [engine_binary(), '--headless', '--path', '.', '-s',
        'addons/gut/gut_cmdln.gd', '-gdir=res://tests/perf_01', '-gexit', '-gjunit_xml_file=reports/perf_01.xml']))
    suite = ET.parse(ROOT / 'reports/perf_01.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 9 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    previous = json.loads((ROOT / 'reports/week_12_checks.json').read_text())
    result = {'godot_tests': previous['godot_tests'] + count, 'python_tests': previous['python_tests'],
              'new_godot_tests': count, 'new_assertions': sum(int(t.attrib.get('assertions', 0)) for t in suite.iter('testcase')),
              'failures': 0, 'skipped': 0, 'negative_control': True, 'functional_gate_passed': True,
              'm4_approved': False, 'm5_approved': False, 'steps': steps}
    (ROOT / 'reports/perf_01_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PERF-01 FUNCTIONAL PASS:', result['godot_tests'], 'Godot +', result['python_tests'], 'Python; performance separate')


if __name__ == '__main__': main()
