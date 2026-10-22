"""Verify committed sources in an empty import cache; reuse locked host tools only."""
import argparse
import io
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

from common import ROOT, engine_binary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--week', type=int, default=7, choices=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    parser.add_argument("--art-pass", action="store_true")
    parser.add_argument("--garden", action="store_true")
    parser.add_argument("--simple", action="store_true", help="UX-02 direct manipulation revision")
    parser.add_argument("--hover", action="store_true", help="UX-03 surface hover revision")
    parser.add_argument("--export", action="store_true", help="W12: export desktop artifacts from this clean archive")
    args = parser.parse_args()
    if args.export and args.week != 12:
        raise RuntimeError("Clean export is registered for week 12 only")
    if args.hover and (args.week != 11 or args.simple or args.garden or args.art_pass):
        raise RuntimeError("UX-03 requires week 11 and no other revision flag")
    if args.simple and (args.week != 11 or args.garden or args.art_pass):
        raise RuntimeError("UX-02 requires week 11 and no historical revision flag")
    if args.garden and (args.week != 10 or args.art_pass):
        raise RuntimeError("Garden revision requires week 10")
    if args.art_pass and args.week != 9:
        raise RuntimeError("ART-01 requires week 9")
    label = "ux_03" if args.hover else "ux_02" if args.simple else "ui_meadow_01" if args.garden else ("art_pass_01" if args.art_pass else f"week_{args.week:02d}")
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    archive = subprocess.check_output(['git', 'archive', revision], cwd=ROOT)
    with tempfile.TemporaryDirectory(prefix='windhaven-clean-') as folder:
        checkout = Path(folder)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(checkout, filter='data')
        if '.godot' in os.listdir(checkout):
            raise RuntimeError('Archive unexpectedly contains an import cache')
        expected_version = "0.11.2-ux03" if args.hover else "0.11.1-ux02" if args.simple else "0.10.1-garden01" if args.garden else ("0.9.1-art01" if args.art_pass else f"0.{args.week}.0-w{args.week:02d}")
        version = f'config/version="{expected_version}"'
        if version not in (checkout / 'project.godot').read_text():
            raise RuntimeError('Committed version does not match week; commit implementation first')
        (checkout / '.venv').symlink_to(ROOT / '.venv', target_is_directory=True)
        environment = os.environ.copy()
        environment['GODOT_BIN'] = engine_binary()
        environment['WINDHAVEN_SOURCE_REVISION'] = revision
        command = ([sys.executable, "tools/quality/week_twelve_checks.py"] if args.week == 12 else
                   [sys.executable, "tools/quality/hover_checks.py"] if args.hover else
                   [sys.executable, "tools/quality/simple_checks.py"] if args.simple else
                   [sys.executable, "tools/quality/week_eleven_checks.py"] if args.week == 11 else
                   [sys.executable, 'tools/quality/ui_meadow_checks.py'] if args.garden else
                   [sys.executable, 'tools/quality/art_pass_checks.py'] if args.art_pass else
                   [sys.executable, 'tools/quality/run_checks.py', '--week', str(args.week), '--negative-control'])
        process = subprocess.run(command, cwd=checkout, env=environment,
                                 text=True, capture_output=True, timeout=420)
        print(process.stdout, end='')
        if process.returncode:
            print(process.stderr, file=sys.stderr)
            raise RuntimeError('Clean checkout regression failed')
        clean_exports = None
        if args.export:
            (checkout / '.tools').symlink_to(ROOT / '.tools', target_is_directory=True)
            export = subprocess.run([sys.executable, 'tools/quality/export_smoke.py', '--week', '12'],
                                    cwd=checkout, env=environment, text=True, capture_output=True, timeout=240)
            print(export.stdout, end='')
            if export.returncode:
                print(export.stderr, file=sys.stderr)
                raise RuntimeError('Clean archive export/smoke failed')
            clean_exports = json.loads((checkout / 'reports/week_12_exports.json').read_text())
            for artifact in clean_exports['artifacts']:
                target = ROOT / artifact['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(checkout / artifact['path'], target)
                for sidecar in (checkout / artifact['path']).parent.iterdir():
                    if sidecar.is_file() and sidecar.suffix in ['.txt', '.md']:
                        shutil.copyfile(sidecar, target.parent / sidecar.name)
            for pattern in ['week_12_export*.json', 'week_12_export*.png']:
                for report in (checkout / 'reports').glob(pattern):
                    shutil.copyfile(report, ROOT / 'reports' / report.name)
        summary = json.loads((checkout / f'reports/{label}_checks.json').read_text())
        evidence = ROOT / f'reports/{label}_clean_evidence'
        evidence.mkdir(exist_ok=True)
        for pattern in ['*.xml', '*.log', '*_checks.json']:
            for report in (checkout / 'reports').glob(pattern):
                shutil.copyfile(report, evidence / report.name)
        result = {'revision': revision, 'cache_reused': False, 'host_tools_reused': ['locked Godot', 'gdtoolkit venv'],
                  'gate': summary, 'passed': True, 'exported_from_clean_archive': args.export, 'exports': clean_exports}
        (ROOT / f'reports/{label}_clean_checkout.json').write_text(json.dumps(result, indent=2) + '\n')
        print('CLEAN CHECKOUT PASS', revision[:7])


if __name__ == '__main__':
    main()
