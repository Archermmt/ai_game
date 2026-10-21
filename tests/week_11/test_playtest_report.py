"""Synthetic validator fixtures only; these are not player observations."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('playtest_report', Path(__file__).resolve().parents[2] / 'tools/quality/playtest_report.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PlaytestReportTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        (self.root / 'synthetic.md').write_text('Synthetic unit test fixture; not a real player.')
        self.data = {'schema': 1, 'm4_approved': True, 'frozen_revision': 'a' * 40, 'records': []}
        for n in range(10):
            self.data['records'].append({'participant_id': f'P{n+1:02}', 'revision': 'a' * 40,
                'system': 'synthetic', 'input_device': 'synthetic', 'evidence': 'synthetic.md',
                'first_time': True, 'consent': True, 'reviewed': True, 'house_independent': True,
                'door': True, 'roof': True, 'path': True, 'house_seconds': 180,
                'screenshot_seconds': 900, 'screenshot_unprompted': True, 'understood_no_management': True})

    def result(self):
        return module.summarize(self.data, self.root)

    def test_empty_live_cohort_does_not_pass(self):
        self.data.update(m4_approved=False, frozen_revision=None, records=[])
        self.assertEqual(self.result()['eligible_first_players'], 0)
        self.assertFalse(self.result()['t067_passed'])

    def test_exact_thresholds_need_full_ten(self):
        for row in self.data['records'][:2]:
            row['house_seconds'] = None
            row['understood_no_management'] = False
        for row in self.data['records'][:3]:
            row['screenshot_seconds'] = None
        self.assertTrue(self.result()['t067_passed'])
        self.data['records'].pop()
        self.assertFalse(self.result()['t067_passed'])

    def test_prompted_late_incomplete_or_unreviewed_does_not_count(self):
        self.data['records'][0]['house_seconds'] = 180.01
        self.data['records'][1]['path'] = False
        self.data['records'][2]['house_independent'] = False
        self.data['records'][3]['screenshot_unprompted'] = False
        self.data['records'][4]['screenshot_seconds'] = 900.01
        self.data['records'][5]['reviewed'] = False
        self.assertFalse(self.result()['t067_passed'])
        self.assertEqual(self.result()['house_3min'], 6)
        self.assertEqual(self.result()['screenshot_15min'], 7)

    def test_pre_freeze_old_revision_and_experienced_do_not_qualify(self):
        self.data['m4_approved'] = False
        self.assertEqual(self.result()['eligible_first_players'], 0)
        self.data['m4_approved'] = True
        self.data['records'][0]['revision'] = 'b' * 40
        self.data['records'][1]['first_time'] = False
        self.data['records'][2]['consent'] = False
        self.assertEqual(self.result()['eligible_first_players'], 7)

    def test_duplicate_invalid_times_and_missing_evidence_fail(self):
        original = copy.deepcopy(self.data)
        for key, value in [('participant_id', 'P02'), ('house_seconds', float('nan')),
                           ('house_seconds', True), ('house_seconds', -1), ('door', 'yes'),
                           ('evidence', '../outside.md'), ('evidence', 'missing.md')]:
            with self.subTest(key=key, value=value):
                self.data = copy.deepcopy(original)
                self.data['records'][0][key] = value
                with self.assertRaises(ValueError):
                    self.result()

    def test_freeze_requires_revision_and_explicit_boolean(self):
        self.data['frozen_revision'] = None
        with self.assertRaises(ValueError):
            self.result()
        self.data['m4_approved'] = 'true'
        with self.assertRaises(ValueError):
            self.result()


if __name__ == '__main__':
    unittest.main()
