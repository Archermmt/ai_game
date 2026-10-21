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
    parser.add_argument('--week', type=int, default=7, choices=[1, 2, 3, 4, 5, 6, 7, 8, 9])
    parser.add_argument("--art-pass", action="store_true")
    args = parser.parse_args()
    if args.art_pass and args.week != 9:
        raise RuntimeError("ART-01 requires week 9")
    label = "art_pass_01" if args.art_pass else f"week_{args.week:02d}"
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    archive = subprocess.check_output(['git', 'archive', revision], cwd=ROOT)
    with tempfile.TemporaryDirectory(prefix='windhaven-clean-') as folder:
        checkout = Path(folder)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(checkout, filter='data')
        if '.godot' in os.listdir(checkout):
            raise RuntimeError('Archive unexpectedly contains an import cache')
        expected_version = "0.9.1-art01" if args.art_pass else f"0.{args.week}.0-w{args.week:02d}"
        version = f'config/version="{expected_version}"'
        if version not in (checkout / 'project.godot').read_text():
            raise RuntimeError('Committed version does not match week; commit implementation first')
        (checkout / '.venv').symlink_to(ROOT / '.venv', target_is_directory=True)
        environment = os.environ.copy()
        environment['GODOT_BIN'] = engine_binary()
        command = ([sys.executable, 'tools/quality/art_pass_checks.py'] if args.art_pass else
                   [sys.executable, 'tools/quality/run_checks.py', '--week', str(args.week), '--negative-control'])
        process = subprocess.run(command, cwd=checkout, env=environment,
                                 text=True, capture_output=True, timeout=300)
        print(process.stdout, end='')
        if process.returncode:
            print(process.stderr, file=sys.stderr)
            raise RuntimeError('Clean checkout regression failed')
        summary = json.loads((checkout / f'reports/{label}_checks.json').read_text())
        evidence = ROOT / f'reports/{label}_clean_evidence'
        evidence.mkdir(exist_ok=True)
        for pattern in ['*.xml', '*.log', '*_checks.json']:
            for report in (checkout / 'reports').glob(pattern):
                shutil.copyfile(report, evidence / report.name)
        result = {'revision': revision, 'cache_reused': False, 'host_tools_reused': ['locked Godot', 'gdtoolkit venv'],
                  'gate': summary, 'passed': True}
        (ROOT / f'reports/{label}_clean_checkout.json').write_text(json.dumps(result, indent=2) + '\n')
        print('CLEAN CHECKOUT PASS', revision[:7])


if __name__ == '__main__':
    main()
