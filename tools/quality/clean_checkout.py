"""Verify committed sources in an empty import cache; reuse locked host tools only."""
import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

from common import ROOT, engine_binary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--week', type=int, default=6, choices=[1, 2, 3, 4, 5, 6])
    args = parser.parse_args()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    archive = subprocess.check_output(['git', 'archive', revision], cwd=ROOT)
    with tempfile.TemporaryDirectory(prefix='windhaven-clean-') as folder:
        checkout = Path(folder)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(checkout, filter='data')
        if '.godot' in os.listdir(checkout):
            raise RuntimeError('Archive unexpectedly contains an import cache')
        version = f'config/version="0.{args.week}.0-w{args.week:02d}"'
        if version not in (checkout / 'project.godot').read_text():
            raise RuntimeError('Committed version does not match week; commit implementation first')
        (checkout / '.venv').symlink_to(ROOT / '.venv', target_is_directory=True)
        environment = os.environ.copy()
        environment['GODOT_BIN'] = engine_binary()
        process = subprocess.run([sys.executable, 'tools/quality/run_checks.py', '--week', str(args.week),
                                  '--negative-control'], cwd=checkout, env=environment,
                                 text=True, capture_output=True, timeout=300)
        print(process.stdout, end='')
        if process.returncode:
            print(process.stderr, file=sys.stderr)
            raise RuntimeError('Clean checkout regression failed')
        summary = json.loads((checkout / f'reports/week_{args.week:02d}_checks.json').read_text())
        result = {'revision': revision, 'cache_reused': False, 'host_tools_reused': ['locked Godot', 'gdtoolkit venv'],
                  'gate': summary, 'passed': True}
        (ROOT / f'reports/week_{args.week:02d}_clean_checkout.json').write_text(json.dumps(result, indent=2) + '\n')
        print('CLEAN CHECKOUT PASS', revision[:7])


if __name__ == '__main__':
    main()
