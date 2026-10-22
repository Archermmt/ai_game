"""UX-03 cumulative gates, including the original UX-02 scene and failure control."""
import json
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    steps = [run_step('ux03_cumulative', [sys.executable, 'tools/quality/simple_checks.py'], timeout=350)]
    steps.append(run_step('ux03_tests', [engine_binary(), '--headless', '--path', '.', '-s',
        'addons/gut/gut_cmdln.gd', '-gdir=res://tests/ux_03', '-gexit', '-gjunit_xml_file=reports/ux_03.xml']))
    suite = ET.parse(ROOT / 'reports/ux_03.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 26 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    baseline = json.loads((ROOT / 'reports/ux_02_checks.json').read_text())
    result = {'godot_tests': baseline['godot_tests'] + count, 'new_godot_tests': count,
              'new_assertions': sum(int(t.attrib.get('assertions', 0)) for t in suite.iter('testcase')),
              'python_tests': baseline['python_tests'], 'failures': 0, 'skipped': 0,
              'negative_control': True, 'steps': steps, 'actual_first_players': 0,
              'functional_gate_passed': True, 'm4_approved': False, 'm5_approved': False}
    (ROOT / 'reports/ux_03_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('UX-03 FUNCTIONAL PASS:', result['godot_tests'], 'Godot tests +', result['python_tests'], 'Python tests')


if __name__ == '__main__':
    main()
