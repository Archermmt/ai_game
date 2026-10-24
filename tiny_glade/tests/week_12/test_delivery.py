"""Synthetic evidence here is isolated in temp directories; never written as real observations."""
import copy
import importlib.util
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/quality'))
from week_twelve_audit import inventory, decision, digest, WINDOWS_STEPS
from week_twelve_package import write_package, verify_package, PAYLOAD


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.index = json.loads((ROOT / 'docs/weekly/week_12/asset_index.json').read_text())
        self.facts = {'revision': 'a' * 40, 'zip_sha256': 'b' * 64, 'native_audio_output_verified': True, 'assets_passed': True,
                      'regression_passed': True, 'ac': {f'AC-{i:02}': True for i in range(1, 15)},
                      'performance': {'frame_p95_ms': 12, 'commit_p95_ms': 120, 'main_callback_ms': 50, 'rss_bytes': 800000000},
                      'playtest_passed': True, 'actual_first_players': 10}
        proof = self.folder / 'observed.md'
        proof.write_text('Synthetic test fixture, not an actual player or device observation.')
        steps = WINDOWS_STEPS + ['frame_target', 'memory_target', 'fresh_machine', 'first_frame_under_5_seconds']
        row = {'revision': 'a' * 40, 'zip_sha256': 'b' * 64, 'os': 'Windows', 'tester_id': 'SYNTHETIC',
               'reviewed': True, 'steps': dict.fromkeys(steps, True),
               'evidence': {'path': 'observed.md', 'sha256': digest(proof)}}
        self.observations = {'schema': 1, 'asset_visual_signoff': 'a' * 40, 'm4_approved_revision': 'a' * 40,
                             'windows': copy.deepcopy(row), 'minimum_spec': copy.deepcopy(row), 'cold_start': copy.deepcopy(row)}

    def test_inventory_has_exact_47_families_79_units_and_21_model_sources(self):
        result = inventory(ROOT, self.index)
        self.assertEqual((result['families'], result['base_units'], result['manual_model_families']), (47, 79, 21))
        self.assertFalse(result['fresh_blender_audit'])
        self.assertEqual(result['visual_signoff'], 'pending')

    def test_manual_model_without_glb_export_cannot_pass_inventory(self):
        row = next(r for r in self.index['assets'] if r['production_type'] == '手工模型')
        row['units'][0]['files'] = [f for f in row['units'][0]['files'] if not f.endswith('.glb')]
        with self.assertRaises(ValueError): inventory(ROOT, self.index)

    def test_inventory_rejects_duplicate_or_missing_family(self):
        self.index['assets'][-1] = self.index['assets'][0]
        with self.assertRaises(ValueError): inventory(ROOT, self.index)

    def test_inventory_cannot_count_instances_as_new_model_families(self):
        self.index['assets'][0]['production_type'] = '手工模型'
        with self.assertRaises(ValueError): inventory(ROOT, self.index)

    def test_inventory_rejects_inflated_base_unit_count(self):
        self.index['assets'][0]['units'].append(self.index['assets'][0]['units'][0])
        with self.assertRaises(ValueError): inventory(ROOT, self.index)

    def test_inventory_rejects_missing_resource_and_path_escape(self):
        for path in ['missing.glb', '../outside-secret', '/etc/passwd']:
            self.index['assets'][0]['units'][0]['files'] = [path]
            with self.assertRaises(ValueError): inventory(ROOT, self.index)

    def test_synthetic_complete_evidence_passes_only_with_matching_revision_and_zip(self):
        self.assertTrue(decision(self.folder, self.facts, self.observations)['m5_approved'])
        self.observations['windows']['zip_sha256'] = 'c' * 64
        self.assertIn('windows_real_device', decision(self.folder, self.facts, self.observations)['blockers'])

    def test_mac_export_and_no_real_records_cannot_approve_release(self):
        self.facts['native_audio_output_verified'] = False
        self.assertIn('native_audio_output', decision(self.folder, self.facts, self.observations)['blockers'])
        result = decision(self.folder, self.facts, {})
        self.assertFalse(result['m5_approved'])
        self.assertIn('windows_real_device', result['blockers'])
        self.assertIn('minimum_spec_pc', result['blockers'])
        self.assertIn('fresh_machine_startup_5s', result['blockers'])

    def test_changed_or_unreviewed_device_evidence_does_not_pass(self):
        (self.folder / 'observed.md').write_text('changed')
        self.assertFalse(decision(self.folder, self.facts, self.observations)['gates']['windows_real_device'])
        self.observations['windows']['reviewed'] = False
        self.assertFalse(decision(self.folder, self.facts, self.observations)['m5_approved'])

    def test_old_revision_or_missing_windows_flow_is_rejected(self):
        self.observations['windows']['revision'] = 'd' * 40
        self.assertFalse(decision(self.folder, self.facts, self.observations)['gates']['windows_real_device'])
        self.observations['windows']['revision'] = 'a' * 40
        del self.observations['windows']['steps']['save_restart_load']
        self.assertFalse(decision(self.folder, self.facts, self.observations)['gates']['windows_real_device'])

    def test_performance_and_ten_player_gates_remain_independent(self):
        self.facts['performance']['commit_p95_ms'] = 241
        self.facts['playtest_passed'] = False
        self.facts['actual_first_players'] = 0
        result = decision(self.folder, self.facts, self.observations)
        self.assertFalse(result['m5_approved'])
        self.assertIn('local_edit_p95_150ms', result['blockers'])
        self.assertIn('t067_ten_first_players', result['blockers'])

    def test_bool_or_missing_metric_is_not_a_valid_measurement(self):
        for value in [True, None, 0, float('nan'), float('inf')]:
            self.facts['performance']['commit_p95_ms'] = value
            self.assertFalse(decision(self.folder, self.facts, self.observations)['gates']['local_edit_p95_150ms'])

    def test_unknown_or_missing_ac_evidence_cannot_pass(self):
        self.facts['ac'] = {f'fake-{i}': True for i in range(14)}
        self.assertFalse(decision(self.folder, self.facts, self.observations)['gates']['ac_01_to_14_automated'])

    def _package(self, name):
        files = {key: ('synthetic-' + key).encode() for key in PAYLOAD - {'PACKAGE.json', 'SHA256SUMS.txt'}}
        path = self.folder / name
        write_package(path, 'a' * 40, '0.12.0-w12', files)
        return path

    def test_package_is_deterministic_exact_and_remains_internal(self):
        first, second = self._package('one.zip'), self._package('two.zip')
        self.assertEqual(digest(first), digest(second))
        manifest = verify_package(first)
        self.assertEqual(manifest['status'], 'internal_qa_only')
        self.assertFalse(manifest['m5_approved'])

    def test_package_detects_changed_payload(self):
        path = self._package('original.zip')
        with zipfile.ZipFile(path) as source:
            files = {name: source.read(name) for name in source.namelist()}
        files['Windhaven.exe'] += b'changed'
        with zipfile.ZipFile(self.folder / 'bad.zip', 'w') as archive:
            for name, value in files.items(): archive.writestr(name, value)
        with self.assertRaises(ValueError): verify_package(self.folder / 'bad.zip')

    def test_package_rejects_cache_secret_and_traversal(self):
        path = self._package('valid.zip')
        for name in ['.git/config', '.env', '../escape']:
            target = self.folder / 'injected.zip'
            target.write_bytes(path.read_bytes())
            with zipfile.ZipFile(target, 'a') as archive: archive.writestr(name, b'not allowed')
            with self.assertRaises(ValueError): verify_package(target)

    def test_package_cannot_self_declare_m5_approval(self):
        path = self._package('valid.zip')
        with zipfile.ZipFile(path) as source:
            files = {name: source.read(name) for name in source.namelist()}
        manifest = json.loads(files['PACKAGE.json']); manifest['m5_approved'] = True
        files['PACKAGE.json'] = json.dumps(manifest).encode()
        with zipfile.ZipFile(self.folder / 'promoted.zip', 'w') as archive:
            for name, value in files.items(): archive.writestr(name, value)
        with self.assertRaises(ValueError): verify_package(self.folder / 'promoted.zip')


if __name__ == '__main__': unittest.main()
