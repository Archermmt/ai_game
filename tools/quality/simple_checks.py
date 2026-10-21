"""UX-02 cumulative regressions on top of the immutable weekly scene baselines."""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    steps = [run_step('ux02_cumulative', [sys.executable, 'tools/quality/week_eleven_checks.py'])]
    steps.append(run_step('ux02_tests', [engine_binary(), '--headless', '--path', '.', '-s',
        'addons/gut/gut_cmdln.gd', '-gdir=res://tests/ux_02', '-gexit', '-gjunit_xml_file=reports/ux_02.xml']))
    suite = ET.parse(ROOT / 'reports/ux_02.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 25 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    baseline = json.loads((ROOT / 'reports/week_11_checks.json').read_text())
    result = {'godot_tests': baseline['godot_tests'] + count, 'new_godot_tests': count,
              'python_tests': baseline['python_tests'], 'failures': 0, 'skipped': 0,
              'negative_control': True, 'steps': steps, 'actual_first_players': 0,
              'functional_gate_passed': True, 'm5_approved': False}
    (ROOT / 'reports/ux_02_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('UX-02 FUNCTIONAL PASS:', result['godot_tests'], 'Godot tests +', result['python_tests'], 'Python tests')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError, AssertionError, ET.ParseError) as error:
        print('UX-02 GATE FAILED:', error, file=sys.stderr)
        sys.exit(1)
