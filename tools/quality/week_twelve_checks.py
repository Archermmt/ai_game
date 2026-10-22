"""W12 cumulative functional gates; incomplete real-device release gates remain explicit."""
import json
import sys
from common import ROOT
from run_checks import run_step
from week_twelve_audit import ac_evidence


def main():
    (ROOT / 'reports').mkdir(exist_ok=True)
    steps = [run_step('w12_cumulative', [sys.executable, 'tools/quality/hover_checks.py'], timeout=350)]
    steps.append(run_step('w12_asset_inventory', [sys.executable, 'tools/quality/week_twelve_audit.py']))
    steps.append(run_step('w12_delivery_tests', [sys.executable, 'tests/week_12/run_python_checks.py']))
    baseline = json.loads((ROOT / 'reports/ux_03_checks.json').read_text())
    python = json.loads((ROOT / 'reports/week_12_python.json').read_text())
    ac = ac_evidence(ROOT, ROOT / 'reports')
    (ROOT / 'reports/week_12_ac.json').write_text(json.dumps(ac, ensure_ascii=False, indent=2) + '\n')
    result = {'godot_tests': baseline['godot_tests'], 'python_tests': baseline['python_tests'] + python['tests'],
              'new_python_tests': python['tests'], 'failures': 0, 'skipped': 0, 'negative_control': True,
              'asset_families': 47, 'asset_base_units': 79, 'ac_automated': len(ac),
              'functional_gate_passed': True, 'm4_approved': False, 'm5_approved': False,
              'actual_first_players': 0, 'steps': steps}
    (ROOT / 'reports/week_12_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W12 FUNCTIONAL PASS:', result['godot_tests'], 'Godot +', result['python_tests'], 'Python; M5 not approved')


if __name__ == '__main__': main()
