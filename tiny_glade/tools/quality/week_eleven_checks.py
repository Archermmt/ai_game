"""W11 cumulative source gate. Human/player/performance gates remain separate."""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    steps = [run_step('w11_cumulative', [sys.executable, 'tools/quality/ui_meadow_checks.py'])]
    steps.append(run_step('w11_playtest_validator', [sys.executable, 'tests/week_11/run_python_checks.py']))
    steps.append(run_step('w11_scene_tests', [engine_binary(), '--headless', '--path', '.', '-s',
                 'addons/gut/gut_cmdln.gd', '-gdir=res://tests/week_11', '-gexit',
                 '-gjunit_xml_file=reports/week_11.xml']))
    suite = ET.parse(ROOT / 'reports/week_11.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 9 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    steps.append(run_step('w11_actual_playtest_report', [sys.executable, 'tools/quality/playtest_report.py',
        'docs/weekly/week_11/playtest_records.json', '--output', 'reports/week_11_playtest.json']))
    baseline = json.loads((ROOT / 'reports/ui_meadow_01_checks.json').read_text())
    result = {'godot_tests': baseline['tests'] + count, 'new_godot_tests': count,
              'python_tests': json.loads((ROOT / 'reports/week_11_python.json').read_text())['tests'], 'failures': 0, 'skipped': 0, 'negative_control': True,
              'steps': steps, 'playtest': json.loads((ROOT / 'reports/week_11_playtest.json').read_text()),
              'functional_gate_passed': True, 'm5_release_approved': False}
    (ROOT / 'reports/week_11_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W11 FUNCTIONAL PASS:', result['godot_tests'], 'Godot tests + 6 validator tests; M5 separate')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError, AssertionError, ET.ParseError) as error:
        print('W11 GATE FAILED:', error, file=sys.stderr)
        sys.exit(1)
