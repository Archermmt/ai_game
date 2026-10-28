"""G5 local asset supply audit; availability never grants distribution permission."""
import hashlib
import json
import subprocess

from art_pass_render_checks import production_files
from common import ROOT
from validate_valley_fidelity import validate


def main():
    before = production_files()
    fidelity = validate()
    manifest = json.loads((ROOT / 'art_source/painterly_grass/valley_manifest.json').read_text())
    files = {}
    for row in manifest:
        for kind in ['source', 'export', 'texture']:
            relative = row[kind]
            data = (ROOT / relative).read_bytes()
            tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', relative],
                                     cwd=ROOT, capture_output=True, check=False).returncode == 0
            files[relative] = {'sha256': hashlib.sha256(data).hexdigest(),
                               'bytes': len(data), 'tracked': tracked}
    assert len(files) == 9 and fidelity['source_hashes_match']
    pinned_files = len(files)
    for directory in ['assets/painterly_grass/local', 'art_source/painterly_grass/local']:
        for path in (ROOT / directory).rglob('*'):
            if not path.is_file() or path.name == '.DS_Store' or path.suffix in ['.blend1', '.blend2']:
                continue
            relative = str(path.relative_to(ROOT))
            if relative in files:
                continue
            tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', relative],
                                     cwd=ROOT, capture_output=True, check=False).returncode == 0
            data = path.read_bytes()
            files[relative] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data), 'tracked': tracked}

    assert before == production_files()
    out = ROOT / 'reports/week_14/g5'
    out.mkdir(parents=True, exist_ok=True)
    result = {'passed': True, 'files': files, 'asset_count': len(manifest), 'manifest_bound_file_count': pinned_files,
              'fidelity': fidelity, 'production_unchanged': True,
              'license_status': sorted({r['license_status'] for r in manifest}),
              'git_only_assets_present': all(row['tracked'] for row in files.values()),
              'distribution_approved': False, 'fresh_checkout_run': False,
              'candidate_release_approved': False, 'windows_verified': False}
    (out / 'asset_supply.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('G5 LOCAL SUPPLY PASS:', len(files), 'supplied files; 9 manifest-bound model/source/texture files; distribution pending')


if __name__ == '__main__':
    main()
