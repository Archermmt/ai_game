"""Deterministic internal Windows ZIP, exact payload checks and offline QA instructions."""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path
from common import ROOT
from week_twelve_audit import digest

PAYLOAD = {'Windhaven.exe', 'HOW_TO_PLAY.zh-CN.md', 'KNOWN_ISSUES.zh-CN.md',
           'WINDOWS_VALIDATION.md', 'START_QA.cmd', 'THIRD_PARTY.md', 'FONT_OFL.txt',
           'GODOT_LICENSE.txt', 'PACKAGE.json', 'SHA256SUMS.txt'}


def verify_package(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != PAYLOAD:
            raise ValueError('Unexpected/missing/duplicate files in candidate ZIP')
        for name in names:
            if '/' in name or '\\' in name or Path(name).is_absolute():
                raise ValueError('Unsafe package path')
        manifest = json.loads(archive.read('PACKAGE.json'))
        if manifest.get('status') != 'internal_qa_only' or manifest.get('m5_approved') is not False:
            raise ValueError('Unreviewed package cannot claim release approval')
        if not re.fullmatch(r'[0-9a-f]{40}', manifest.get('revision', '')):
            raise ValueError('Missing exact source revision')
        records = manifest.get('files', {})
        if set(records) != PAYLOAD - {'PACKAGE.json', 'SHA256SUMS.txt'}:
            raise ValueError('Incomplete package manifest')
        for name, entry in records.items():
            hasher = hashlib.sha256()
            size = 0
            with archive.open(name) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    hasher.update(chunk)
                    size += len(chunk)
            if hasher.hexdigest() != entry['sha256'] or size != entry['bytes']:
                raise ValueError('Package hash mismatch: ' + name)
        checks = {}
        for line in archive.read('SHA256SUMS.txt').decode().splitlines():
            checksum, name = line.split('  ', 1)
            if name in checks:
                raise ValueError('Duplicate checksum')
            checks[name] = checksum
        if set(checks) != PAYLOAD - {'SHA256SUMS.txt'}:
            raise ValueError('Incomplete checksums')
        for name, checksum in checks.items():
            expected = hashlib.sha256(archive.read(name)).hexdigest() if name == 'PACKAGE.json' else records[name]['sha256']
            if expected != checksum:
                raise ValueError('Checksums disagree with manifest')
    return manifest


def write_package(target, revision, version, files):
    if set(files) != PAYLOAD - {'PACKAGE.json', 'SHA256SUMS.txt'}:
        raise ValueError('Unexpected candidate payload')
    records = {name: {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)} for name, data in files.items()}
    manifest = {'version': version, 'revision': revision, 'status': 'internal_qa_only',
                'm5_approved': False, 'files': records}
    payload = dict(files)
    payload['PACKAGE.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
    payload['SHA256SUMS.txt'] = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n' for name, data in sorted(payload.items())).encode()
    Path(target).parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 22, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    verify_package(target)
    return {'path': str(target), 'bytes': Path(target).stat().st_size, 'sha256': digest(target),
            'revision': revision, 'version': version, 'status': 'internal_qa_only', 'm5_approved': False}


def main():
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    exports = json.loads((ROOT / 'reports/week_12_exports.json').read_text())
    if exports.get('revision') != revision or exports.get('version') != '0.12.0-w12':
        raise ValueError('Export receipt must match this exact committed candidate')
    artifact = next(a for a in exports['artifacts'] if a['path'].endswith('.exe'))
    executable = ROOT / artifact['path']
    if digest(executable) != artifact['sha256'] or not exports['windows_pe_x86_64']:
        raise ValueError('Windows export hash/format mismatch')
    files = {'Windhaven.exe': executable.read_bytes()}
    base = ROOT / 'docs/weekly/week_12'
    for name in ['HOW_TO_PLAY.zh-CN.md', 'KNOWN_ISSUES.zh-CN.md', 'WINDOWS_VALIDATION.md']:
        files[name] = (base / name).read_bytes()
    for name, source in [('THIRD_PARTY.md', 'THIRD_PARTY.md'), ('FONT_OFL.txt', 'assets/fonts/OFL.txt'), ('GODOT_LICENSE.txt', 'docs/licenses/GODOT_LICENSE.txt')]:
        files[name] = (ROOT / source).read_bytes()
    files['START_QA.cmd'] = b'@echo off\r\ncd /d "%~dp0"\r\nWindhaven.exe -- --qa-settings\r\n'
    target = ROOT / 'builds/week_12/windows/Windhaven_0.12.0-w12_Windows_Internal.zip'
    result = write_package(target, revision, '0.12.0-w12', files)
    result['path'] = str(target.relative_to(ROOT))
    (ROOT / 'reports/week_12_candidate.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W12 internal Windows ZIP verified:', result['sha256'])


if __name__ == '__main__': main()
