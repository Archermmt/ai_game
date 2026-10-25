"""Focused landscape/plugin gates. Visual acceptance and performance are separate."""

import argparse
import hashlib
import json
import math
import shutil
import struct
import sys
import xml.etree.ElementTree as ET

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import run_step
from validate_valley_fidelity import validate

OUT = ROOT / 'reports/week_14/landscape_lab'
EXPECTED_SUITES = {
    'tests/week_14/landscape/test_scatter_adapter.gd': 4,
    'tests/week_14/landscape/test_landscape_lab.gd': 4,
}


def inspect_junit(path):
    """Reject empty, omitted, failed and assertion-free runs, including stale files."""
    root = ET.parse(path).getroot()
    suites = {row.get('name'): row for row in root.findall('testsuite')}
    count = int(root.get('tests', 0))
    assert count >= sum(EXPECTED_SUITES.values()), f'Empty/incomplete landscape run: {count}'
    for node in [root, *suites.values()]:
        for field in ('failures', 'errors', 'skipped', 'disabled'):
            assert int(node.get(field, 0)) == 0, f'{node.get("name")}: {field}'
    for name, minimum in EXPECTED_SUITES.items():
        assert name in suites, f'Missing required suite: {name}'
        suite = suites[name]
        assert int(suite.get('tests', 0)) >= minimum, name
        cases = list(suite.iter('testcase'))
        assert cases and sum(int(row.get('assertions', 0)) for row in cases) > 0, name
        assert not any(row.find('failure') is not None or row.find('error') is not None
                       or row.find('skipped') is not None for row in cases), name
    return {'tests': count,
            'assertions': sum(int(row.get('assertions', 0)) for row in root.iter('testcase')),
            'failures': 0, 'skipped': 0, 'suites': sorted(suites)}


def validate_scatter_plugin():
    lock = json.loads((ROOT / 'features/landscape_lab/proton_scatter.lock.json').read_text())
    addon = ROOT / 'addons/proton_scatter'
    verified = 0
    for relative, expected in lock['files_sha256'].items():
        path = addon / relative
        assert path.is_file(), path
        # Godot regenerates import sidecars when it imports a pinned source asset.
        # Their upstream hashes remain in the lock as provenance, not source code.
        if path.suffix == '.import':
            continue
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, path
        verified += 1
    assert verified > 100
    assert (addon / 'LICENSE').is_file()
    assert not (addon / 'demos').exists()
    return {'version': lock['version'], 'commit': lock['commit'],
            'verified_source_files': verified, 'license': lock['license']}


def validate_source_layout():
    folder = ROOT / 'assets/painterly_grass/local/valley'
    scatter = json.loads((folder / 'scatter_full.json').read_text())
    counts = {row['asset_id']: len(row['instances']) for row in scatter['layers']}
    assert counts == {'blades': 366, 'detail': 305, 'puffs': 161, 'floor': 2445}, counts
    assert scatter['library_sha256'] == '487631daaefc27eec0b02a2457c7eb4d93a78f48c14c0bf891ba1b50d99b3be3'
    metadata = json.loads((folder / 'terrain_height.json').read_text())
    raw = (folder / metadata['file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == metadata['sha256']
    assert metadata['resolution'] == [256, 256] and len(raw) == 256 * 256 * 4
    heights = struct.unpack('<65536f', raw)
    assert all(math.isfinite(value) for value in heights)
    assert max(heights) - min(heights) > 9.0, 'The original Valley relief must be retained'
    for layer in scatter['layers']:
        for instance in layer['instances']:
            assert all(math.isfinite(v) for v in instance['position_local'])
            assert all(math.isfinite(v) for column in instance['basis'] for v in column)
            assert math.isfinite(instance['ground_offset_m'])
    return {'source_instances': sum(counts.values()), 'layer_counts': counts,
            'height_sha256': metadata['sha256'], 'height_range_m': [min(heights), max(heights)]}


def validate_terrain_plugin():
    lock = json.loads((ROOT / 'features/landscape_lab/terrain3d.lock.json').read_text())
    patches = {row['path']: row for row in lock.get('local_patches', [])}
    for relative, metadata in lock['files'].items():
        path = ROOT / relative
        assert path.is_file(), path
        expected = metadata['sha256']
        if relative in patches:
            patch = patches[relative]
            assert patch['upstream_sha256'] == expected
            expected = patch['patched_sha256']
            assert hashlib.sha256((ROOT / patch['patch_file']).read_bytes()).hexdigest() == patch['patch_sha256']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, path
    return {'version': lock['version'], 'source_commit': lock['source_commit'],
            'verified_source_files': len(lock['files']), 'local_patches': list(patches)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-import', action='store_true', help='Use an already completed project import')
    parser.add_argument('--cumulative', action='store_true', help='Also run the existing W01-W14 G3 cumulative gate')
    parser.add_argument('--native-only', action='store_true', help='Render the Metal/Vulkan art evidence and check scene roundtrips; no performance trace')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'reports/.gdignore').touch()
    (OUT / 'checks.json').unlink(missing_ok=True)
    environment = preflight()
    before = production_files()
    steps = []
    if args.native_only:
        native_folder = ROOT / 'reports/landscape_lab/native'
        native_folder.mkdir(parents=True, exist_ok=True)
        result_path = native_folder / 'result.json'
        result_path.unlink(missing_ok=True)
        steps.append(run_step('landscape_lab_native', [engine_binary(), '--path', str(ROOT),
            '--script', 'res://tests/week_14/landscape/landscape_native_probe.gd'], timeout=180))
        result = json.loads(result_path.read_text())
        assert result['passed'] and len(result['checks']) >= 34
        assert all(row['passed'] for row in result['checks'])
        assert len(result['images']) == 12 and not result['performance_gate_run']
        assert result['rendering_driver'] in ['metal', 'vulkan']
        for mode in (0, 1):
            assert result[f'mode{mode}_gpu_origin_error_m'] < 0.001
        for resource_path in result['images']:
            assert resource_path.startswith('res://reports/landscape_lab/native/')
            path = ROOT / resource_path.removeprefix('res://')
            png = path.read_bytes()
            assert png[:8] == b'\x89PNG\r\n\x1a\n'
            assert struct.unpack_from('>II', png, 16) == (1600, 1000)
        assert production_files() == before, 'Native sample touched production files'
        result['production_unchanged'] = True
        result['steps'] = steps
        (native_folder / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print('LANDSCAPE NATIVE PASS:', len(result['checks']), 'checks; performance not evaluated')
        return
    if not args.skip_import:
        steps.append(run_step('landscape_lab_import', [engine_binary(), '--headless',
            '--path', str(ROOT), '--editor', '--import'], timeout=240))
    assets = validate()
    source = validate_source_layout()
    plugin = validate_scatter_plugin()
    terrain_plugin = validate_terrain_plugin()
    cumulative = None
    if args.cumulative:
        steps.append(run_step('landscape_lab_cumulative', [sys.executable,
            'tools/quality/painterly_grass_checks.py', '--stage', '3'], timeout=1200))
        cumulative = json.loads((ROOT / 'reports/week_14/g3/checks.json').read_text())
    xml_path = OUT / 'tests.xml'
    xml_path.unlink(missing_ok=True)
    steps.append(run_step('landscape_lab_tests', [engine_binary(), '--headless', '--path',
        str(ROOT), '-s', 'addons/gut/gut_cmdln.gd',
        '-gdir=res://tests/week_14/landscape', '-gexit',
        '-gjunit_xml_file=' + str(xml_path.relative_to(ROOT))], timeout=300))
    tests = inspect_junit(xml_path)
    shutil.copyfile(ROOT / 'reports/landscape_lab_tests.log', OUT / 'tests.log')
    after = production_files()
    assert before == after, 'Landscape prototype touched production saves/preferences'
    result = {'passed': True, 'environment': environment, 'assets': assets, 'source': source,
              'proton_scatter': plugin, 'terrain3d': terrain_plugin, 'focused': tests, 'steps': steps,
              'production_before': before, 'production_after': after,
              'production_unchanged': True, 'cumulative_run': cumulative is not None,
              'godot_tests': cumulative['godot_tests'] + tests['tests'] if cumulative else None,
              'python_tests': cumulative['python_tests'] if cumulative else None,
              'performance_gate_run': False, 'visual_acceptance': 'requires user review',
              'windows_real_device_verified': False}
    (OUT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('LANDSCAPE LAB PASS:', tests['tests'], 'focused Godot tests; performance not evaluated')


if __name__ == '__main__':
    main()
