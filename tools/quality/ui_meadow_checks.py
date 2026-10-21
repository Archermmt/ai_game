"""Cumulative W01–10/ART plus contextual ribbon, meadow, focus and restart evidence."""
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    steps = [run_step('garden_cumulative', [sys.executable, 'tools/quality/run_checks.py', '--week', '10', '--negative-control'])]
    manifest = json.loads((ROOT / 'art_source/ui_meadow_01/icons_manifest.json').read_text())
    assert len(manifest['files']) == 8
    for name, sha in manifest['files'].items():
        raw = (ROOT / f'assets/ui/garden/{name}.svg').read_bytes()
        assert raw == (ROOT / f'art_source/ui_meadow_01/icons/{name}.svg').read_bytes()
        assert hashlib.sha256(raw).hexdigest() == sha
    engine = engine_binary()
    steps.append(run_step('garden_tests', [engine, '--headless', '--path', '.', '-s', 'addons/gut/gut_cmdln.gd',
        '-gdir=res://tests/garden_presentation', '-gexit', '-gjunit_xml_file=reports/ui_meadow_01.xml']))
    suite = ET.parse(ROOT / 'reports/ui_meadow_01.xml').getroot()
    count = int(suite.attrib.get('tests', 0))
    assert count >= 23 and not int(suite.attrib.get('failures', 0))
    assert not any(int(s.attrib.get('skipped', 0)) for s in suite.findall('testsuite'))
    for mode in ['write', 'read']:
        steps.append(run_step('garden_restart_' + mode, [engine, '--headless', '--path', '.', '-s',
            'tests/garden_presentation/restart_probe.gd', '--', mode, str(ROOT / 'reports/garden_restart')]))
    baseline = json.loads((ROOT / 'reports/week_10_checks.json').read_text())
    result = {'tests': baseline['tests'] + count, 'new_tests': count, 'failures': 0, 'skipped': 0,
              'negative_control': True, 'icon_sources': 8, 'steps': steps}
    (ROOT / 'reports/ui_meadow_01_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('GARDEN PASS:', result['tests'], 'tests; visual/performance results recorded separately')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError, AssertionError, ET.ParseError) as error:
        print('GARDEN GATE FAILED:', error, file=sys.stderr)
        sys.exit(1)
