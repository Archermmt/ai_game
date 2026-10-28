"""G5 committed local candidate with explicit derivatives and a fresh import cache."""
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import tarfile
import tempfile

from art_pass_render_checks import production_files
from clean_checkout import committed_project_archive, run_verified
from common import ROOT, engine_binary


def main():
    before = production_files()
    out = ROOT / 'reports/week_14/g5'
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'portable_checks.json'
    receipt.unlink(missing_ok=True)
    revision, project_prefix, archive = committed_project_archive(ROOT)
    checkout = Path(tempfile.mkdtemp(prefix='candidate_' + revision[:8] + '_', dir=out))
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        source.extractall(checkout, filter='data')
    assert not (checkout / '.godot').exists()
    for name in ['assets/painterly_grass/local', 'art_source/painterly_grass/local']:
        shutil.copytree(ROOT / name, checkout / name,
                        ignore=shutil.ignore_patterns('*.blend1', '*.blend2', '.DS_Store'))
    (checkout / '.venv').symlink_to(ROOT / '.venv', target_is_directory=True)
    environment = os.environ.copy()
    environment.update(GODOT_BIN=engine_binary(), WINDHAVEN_SOURCE_REVISION=revision)
    process = run_verified(['python3', 'tools/quality/winter_render_optimization_checks.py'],
                           checkout, environment, 1500)
    (out / 'portable.log').write_text(process.stdout + process.stderr)
    checks = json.loads((checkout / 'reports/week_14/winter_optimization/checks.json').read_text())
    assert checks['passed'] and checks['new_tests'] == 6 and checks['production_unchanged']
    assert checks['adoption']['regressions']['focused_tests'] == 36
    assert len(checks['pixel_comparisons']['comparisons']) == 36
    assert before == production_files(), 'Candidate QA modified formal saves/preferences'
    launcher = out / 'open_candidate.command'
    launcher.write_text('#!/bin/sh\nexec ' + shlex.join([engine_binary(), '--path', str(checkout),
        '--resolution', '1440x900', 'res://app/living_root.tscn', '--', '--qa-settings',
        '--season=winter', '--weather=clear', '--hour=12']) + '\n')
    launcher.chmod(0o755)
    result = {'passed': True, 'revision': revision, 'project_subdirectory': project_prefix,
              'candidate_directory': str(checkout), 'launcher': str(launcher), 'cache_reused': False,
              'local_derivatives_supplied': True, 'external_locked_toolchain_supplied': True,
              'vendor_bundle_copied': False, 'vendor_original_path_needed_at_runtime': False,
              'git_only_asset_portability': False, 'distribution_approved': False,
              'standalone_export_verified': False, 'windows_verified': False,
              'production_unchanged': True, 'checks': checks}
    receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('G5 FRESH LOCAL CANDIDATE PASS:', checkout)
    print('Distribution, Git-only supply and standalone package gates remain open')


if __name__ == '__main__':
    main()
