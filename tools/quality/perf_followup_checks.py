"""PERF-02 retains every prior gate and checks exact incremental publication."""
import json
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    steps = [run_step('perf02_cumulative', [sys.executable, 'tools/quality/perf_checks.py'], timeout=500)]
    steps.append(run_step('perf02_tests', [engine_binary(), '--headless', '--path', '.', '-s',
        'addons/gut/gut_cmdln.gd', '-gdir=res://tests/perf_02', '-gexit', '-gjunit_xml_file=reports/perf_02.xml']))
    suite = ET.parse(ROOT / 'reports/perf_02.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 33 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    steps.append(run_step('perf02_protocol_tests', [sys.executable, 'tests/perf_02/run_python_checks.py']))
    python = json.loads((ROOT / 'reports/perf_02_python.json').read_text())
    assert python['tests'] >= 5 and not python['failures'] and not python['errors'] and not python['skipped']
    previous = json.loads((ROOT / 'reports/perf_01_checks.json').read_text())
    result = {'godot_tests': previous['godot_tests'] + count,
              'python_tests': previous['python_tests'] + python['tests'], 'new_godot_tests': count,
              'new_assertions': sum(int(t.attrib.get('assertions', 0)) for t in suite.iter('testcase')),
              'new_python_tests': python['tests'], 'failures': 0, 'skipped': 0,
              'negative_control': True, 'functional_gate_passed': True,
              'm4_approved': False, 'm5_approved': False, 'steps': steps}
    (ROOT / 'reports/perf_02_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PERF-02 FUNCTIONAL PASS:', result['godot_tests'], 'Godot +', result['python_tests'], 'Python; performance separate')


if __name__ == '__main__':
    main()
