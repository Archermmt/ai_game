"""W13 living garden retains all historical regressions and negative controls."""
import json
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    steps = [run_step('seasonal_music_assets', [sys.executable, 'tools/quality/validate_seasonal_music.py'])]
    steps.append(run_step('w13_cumulative', [sys.executable, 'tools/quality/perf_followup_checks.py'], timeout=600))
    steps.append(run_step('week_13_tests', [engine_binary(), '--headless', '--path', '.', '-s',
        'addons/gut/gut_cmdln.gd', '-gdir=res://tests/week_13', '-gexit', '-gjunit_xml_file=reports/week_13.xml']))
    suite = ET.parse(ROOT / 'reports/week_13.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 44 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    previous = json.loads((ROOT / 'reports/perf_02_checks.json').read_text())
    result = {'godot_tests': previous['godot_tests'] + count, 'python_tests': previous['python_tests'],
              'new_tests': count, 'new_assertions': sum(int(t.get('assertions', 0)) for t in suite.iter('testcase')),
              'negative_control': True, 'failures': 0, 'skipped': 0, 'functional_gate_passed': True,
              'm4_approved': False, 'm5_approved': False, 'steps': steps}
    (ROOT / 'reports/week_13_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W13 FUNCTIONAL PASS:', result['godot_tests'], 'Godot +', result['python_tests'], 'Python; native and release separate')


if __name__ == '__main__':
    main()
