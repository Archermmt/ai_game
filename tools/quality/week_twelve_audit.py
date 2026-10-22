"""W12 technical inventory and evidence-based release decision; no inferred human approvals."""
import argparse
import csv
import hashlib
import json
import math
import re
from pathlib import Path
from common import ROOT


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def safe_file(root, relative):
    relative = Path(relative)
    target = (Path(root) / relative).resolve()
    if relative.is_absolute() or not target.is_relative_to(Path(root).resolve()) or not target.is_file():
        raise ValueError('Missing or escaping evidence/resource: ' + str(relative))
    return target


def inventory(root, index):
    root = Path(root)
    approved = {r['asset_id']: r for r in csv.DictReader((root / 'docs/art/asset_manifest.csv').open(encoding='utf-8-sig')) if r['mvp'] == '1'}
    rows = index.get('assets', [])
    if len(rows) != 47 or set(approved) != {r['asset_id'] for r in rows}:
        raise ValueError('Expected exactly the 47 unique approved P0 families')
    reopen = set()
    audits = list((root / 'docs/weekly').glob('week_*/source_audit*.json'))
    audits += [root / 'art_source/art_pass_01/nature/source_reopen_audit.json']
    for path in audits:
        for source in json.loads(path.read_text()).get('sources', []):
            if source.get('passed') is True:
                reopen.add(source['source'])
    entries, files, manual = [], {}, 0
    for row in rows:
        expected = approved[row['asset_id']]
        units = row.get('units', [])
        if row.get('production_type') != expected['production_type'] or len(units) != int(expected['quantity']):
            raise ValueError('Family kind / base unit count mismatch: ' + row['asset_id'])
        if len({u['name'] for u in units}) != len(units):
            raise ValueError('Duplicate delivery unit')
        for unit in units:
            if not unit.get('files'):
                raise ValueError('Delivery unit without source/export')
            for relative in unit['files']:
                path = safe_file(root, relative)
                files[relative] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
        if row['production_type'] == '手工模型':
            manual += 1
            exports = [f for u in units for f in u['files'] if f.endswith('.glb')]
            if not exports or any(not safe_file(root, name).read_bytes().startswith(b'glTF') for name in exports):
                raise ValueError('Model lacks a valid GLB export')
            source = row.get('model_source')
            if source not in reopen or source not in [f for u in units for f in u['files']]:
                raise ValueError('Model lacks a recorded source reopening: ' + str(source))
            if not safe_file(root, source).read_bytes().startswith((b'BLENDER', b'\x28\xb5\x2f\xfd')):
                raise ValueError('Invalid Blender source')
        entries.append({'asset_id': row['asset_id'], 'production_type': row['production_type'],
                        'base_units': len(units), 'name': expected['name_zh'], 'technical_passed': True,
                        'final_visual_signoff': 'pending'})
    if sum(r['base_units'] for r in entries) != 79 or manual != 21:
        raise ValueError('Expected 79 units / 21 manual model families')
    for name in ['THIRD_PARTY.md', 'assets/fonts/OFL.txt', 'docs/licenses/GODOT_LICENSE.txt']:
        path = safe_file(root, name)
        files[name] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
    return {'families': 47, 'base_units': 79, 'manual_model_families': manual,
            'technical_passed': True, 'fresh_blender_audit': False,
            'source_reopen_scope': 'Existing audit records checked; sources not modified this week',
            'visual_signoff': 'pending', 'entries': entries, 'files': files}


WINDOWS_STEPS = ['fresh_unzip', 'demo', 'empty_layout', 'build_and_hover_edit', 'door_window_bridge',
                 'undo_redo', 'save_restart_load', 'photo_1080p', 'photo_1440p', 'settings_150', 'clean_exit']


def observation_passed(root, record, revision, zip_hash, required_steps):
    if not isinstance(record, dict):
        return False
    if record.get('revision') != revision or record.get('zip_sha256') != zip_hash:
        return False
    if record.get('reviewed') is not True or record.get('os') != 'Windows' or not record.get('tester_id'):
        return False
    if any(record.get('steps', {}).get(step) is not True for step in required_steps):
        return False
    evidence = record.get('evidence', {})
    try:
        path = safe_file(root, evidence['path'])
        return digest(path) == evidence['sha256']
    except (KeyError, TypeError, ValueError, OSError):
        return False


def measured(value, limit, inclusive=True):
    return type(value) in (int, float) and math.isfinite(value) and value > 0 and (value <= limit if inclusive else value < limit)


def decision(root, facts, observations):
    revision, zip_hash = facts.get('revision', ''), facts.get('zip_sha256', '')
    valid_identity = bool(re.fullmatch(r'[0-9a-f]{40}', revision) and re.fullmatch(r'[0-9a-f]{64}', zip_hash))
    metrics = facts.get('performance', {})
    gates = {
        'package_identity': valid_identity,
        'asset_47_79_technical': facts.get('assets_passed') is True,
        'asset_visual_signoff': observations.get('asset_visual_signoff') == revision,
        'cumulative_regression': facts.get('regression_passed') is True,
        'ac_01_to_14_automated': set(facts.get('ac', {})) == {f'AC-{i:02}' for i in range(1, 15)} and all(v is True for v in facts.get('ac', {}).values()),
        'frame_p95_20ms': measured(metrics.get('frame_p95_ms'), 20),
        'local_edit_p95_150ms': measured(metrics.get('commit_p95_ms'), 150),
        'main_callback_100ms': measured(metrics.get('main_callback_ms'), 100),
        'rss_2gib': measured(metrics.get('rss_bytes'), 2 * 1024**3, False),
        'windows_real_device': valid_identity and observation_passed(root, observations.get('windows'), revision, zip_hash, WINDOWS_STEPS),
        'minimum_spec_pc': valid_identity and observation_passed(root, observations.get('minimum_spec'), revision, zip_hash, WINDOWS_STEPS + ['frame_target', 'memory_target']),
        'fresh_machine_startup_5s': valid_identity and observation_passed(root, observations.get('cold_start'), revision, zip_hash, ['fresh_machine', 'first_frame_under_5_seconds']),
        't067_ten_first_players': facts.get('playtest_passed') is True,
        'explicit_m4_approval': observations.get('m4_approved_revision') == revision and valid_identity,
    }
    blockers = [name for name, passed in gates.items() if not passed]
    return {'revision': revision, 'zip_sha256': zip_hash, 'gates': gates, 'blockers': blockers,
            'm5_approved': not blockers, 'status': 'approved_candidate' if not blockers else 'internal_qa_only',
            'actual_first_players': facts.get('actual_first_players', 0)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='reports/week_12_assets.json')
    args = parser.parse_args()
    result = inventory(ROOT, json.loads((ROOT / 'docs/weekly/week_12/asset_index.json').read_text()))
    target = ROOT / args.output
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('W12 TECHNICAL INVENTORY PASS: 47 families / 79 units / 21 manual model families; visual sign-off separate')


def ac_evidence(root, reports):
    import xml.etree.ElementTree as ET
    index = json.loads((Path(root) / 'docs/weekly/week_12/ac_index.json').read_text())
    if set(index) != {f'AC-{i:02}' for i in range(1, 15)}:
        raise ValueError('Expected all fourteen acceptance criteria')
    result = {}
    for key, refs in index.items():
        if not refs:
            raise ValueError('Empty acceptance evidence')
        for ref in refs:
            suite = ET.parse(safe_file(reports, ref['suite'])).getroot()
            matches = [t for t in suite.iter('testcase') if t.attrib['name'] == ref['test']]
            if int(suite.attrib.get('failures', 0)) or not matches or any(t.attrib.get('status') != 'pass' or t.find('failure') is not None or t.find('skipped') is not None for t in matches):
                raise ValueError('Acceptance evidence failed/missing: ' + key + ' / ' + ref['test'])
        result[key] = {'automated_passed': True, 'evidence': refs, 'windows_real_device': 'pending'}
    return result


if __name__ == '__main__': main()
