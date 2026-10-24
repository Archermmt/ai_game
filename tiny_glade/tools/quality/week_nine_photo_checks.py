"""Native photography and new-entry UI evidence, separate from performance sampling."""
import argparse
import json
from pathlib import Path
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--executable', type=Path)
    args = parser.parse_args()
    program = [str(args.executable.resolve())] if args.executable else [engine_binary(), '--path', str(ROOT)]
    out = ROOT / 'reports/week_09_photography'
    out.mkdir(exist_ok=True)
    steps = []
    steps.append(run_step('w09_photography', [*program, '--', '--qa-settings', '--w09-photo-probe',
        '--photo-output=' + str(out), '--smoke-output=' + str(out / 'photo_smoke.json')]))
    report = json.loads((out / 'photo_report.json').read_text())
    assert len(report['results']) == 3 and all(r['ok'] for r in report['results'])
    assert report['source_unchanged'] and report['camera_restored'] and report['selection_restored']
    assert report['outline_restored'] and not report['photo_active'] and report['failure_retry']
    steps.append(run_step('w09_png_decode', [engine_binary(), '--headless', '--path', str(ROOT), '-s',
        'tests/week_09/image_probe.gd', '--', str(out)]))
    for name, flags in [('entry', ['--w09-entry']), ('entry_150', ['--w09-entry', '--ui-scale=1.5']),
                        ('photography', ['--w09-photo']), ('photography_150', ['--w09-photo', '--ui-scale=1.5']),
                        ('empty', ['--w09-empty'])]:
        steps.append(run_step('w09_ui_' + name, [*program, '--', '--qa-settings', '--wind-time=0', '--water-time=0',
            '--capture=' + str(out / (name + '.png')), '--smoke-output=' + str(out / (name + '.json')), *flags]))
        data = json.loads((out / (name + '.json')).read_text())
        assert data['buildings'] == (0 if name == 'empty' else 2)
        assert data['instances'] == (12 if name == 'empty' else 51)
    (ROOT / 'reports/week_09_photo_checks.json').write_text(json.dumps({'report': report, 'steps': steps,
        'build': 'release' if args.executable else 'runtime'}, indent=2, ensure_ascii=False) + '\n')
    print('W09 native photo and entry checks pass')


if __name__ == '__main__':
    main()
