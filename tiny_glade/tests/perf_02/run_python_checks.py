"""Synthetic protocol controls. These fixtures are never native performance evidence."""

import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/quality'))
from perf_visible_checks import BEGINNINGS, ENDINGS, validate_report


def fixture():
    """Twenty independently enumerated, successful, rendered synthetic drags."""
    samples = []
    for index in range(20):
        start = 12000 + index * 100000
        sample = {'index': index, 'revision_before': 1 + index, 'revision_after': 2 + index,
                  'history_before': index, 'publication_count': 1,
                  'roof_before': 1.0 if index % 2 == 0 else 1.5,
                  'roof_after': 1.5 if index % 2 == 0 else 1.0,
                  'grass_visible': 450, 'grass_total': 1000,
                  'motion_usec': start, 'press_usec': start + 1000,
                  'change_usec': start + 2000, 'release_usec': start + 3000,
                  'publish_usec': start + 33000, 'draw_usec': start + 34000,
                  'grass_settle_draw_usec': start + 35000}
        for beginning in BEGINNINGS:
            for ending in ENDINGS:
                sample[f'{beginning}_to_{ending}_ms'] = (
                    sample[ending + '_usec'] - sample[beginning + '_usec']) / 1000
        samples.append(sample)
    # Expected values are fixed constants, independent of the validator's percentile code.
    durations = {'motion': (33, 34, 35), 'press': (32, 33, 34),
                 'change': (31, 32, 33), 'release': (30, 31, 32)}
    summary = {f'{beginning}_to_{ending}_ms': {'p95': value, 'max': value}
               for beginning, values in durations.items() for ending, value in zip(ENDINGS, values)}
    return {'functional_passed': True, 'protocol': 'first_visible_real_gui_roof_input',
            'warmup_edits': 0, 'initial_grass_wait': False, 'legacy_terrain_probe_replaced': False,
            'viewport_size': [1920, 1080], 'buildings': 24, 'instances': 1000,
            'runtime_metrics': {'grass_density': .45, 'meadow_visible': 450,
                                'commit_latency_samples_ms': [30] * 20,
                                'rebuild_phase_timings': [{'complete_ms': 30}] * 20},
            'started_usec': 1000, 'first_draw_usec': 11000, 'first_input_usec': 12000,
            'samples': samples, 'summary': summary, 'render_frame_intervals_ms': [10, 11, 12]}


class VisibleInputProtocolTests(unittest.TestCase):
    def reject(self, mutate):
        report = fixture()
        mutate(report)
        with self.assertRaises((AssertionError, KeyError, TypeError, ValueError)):
            validate_report(report, True)

    def test_complete_twenty_drag_fixture_is_accepted(self):
        report = fixture()
        untouched = copy.deepcopy(report)
        validate_report(report, True)
        self.assertEqual(report, untouched)

    def test_empty_partial_or_missing_first_sample_is_rejected(self):
        for sample_slice in [slice(0, 0), slice(0, 19), slice(1, None)]:
            with self.subTest(sample_slice=sample_slice):
                self.reject(lambda data: data.update(samples=data['samples'][sample_slice]))
        self.reject(lambda data: data['samples'].__setitem__(0, data['samples'][1]))

    def test_predraw_input_reordered_timestamps_and_revision_gap_are_rejected(self):
        self.reject(lambda data: data.update(first_draw_usec=13000))
        self.reject(lambda data: data['samples'][0].update(draw_usec=12001))
        self.reject(lambda data: data['samples'][7].update(revision_before=100, revision_after=101))
        self.reject(lambda data: data['samples'][7].update(history_before=30))

    def test_forged_duration_or_summary_cannot_agree_to_bypass_raw_timestamps(self):
        self.reject(lambda data: data.update(summary={}))
        self.reject(lambda data: data['summary'].pop('release_to_draw_ms'))
        self.reject(lambda data: data['summary']['motion_to_draw_ms'].update(p95=1))

        def forge_both(data):
            for sample in data['samples']:
                sample['release_to_draw_ms'] = 1
            data['summary']['release_to_draw_ms'] = {'p95': 1, 'max': 1}

        self.reject(forge_both)

    def test_missing_or_duplicate_successful_commits_and_hidden_warmup_are_rejected(self):
        self.reject(lambda data: data['runtime_metrics']['commit_latency_samples_ms'].pop())
        self.reject(lambda data: data['runtime_metrics']['rebuild_phase_timings'].clear())
        self.reject(lambda data: data['samples'][0].update(publication_count=0))
        self.reject(lambda data: data['samples'][0].update(publication_count=2))
        self.reject(lambda data: data['samples'][0].update(history_before=1))


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(VisibleInputProtocolTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {'tests': result.testsRun, 'failures': len(result.failures),
              'errors': len(result.errors), 'skipped': len(result.skipped), 'synthetic_only': True}
    (ROOT / 'reports').mkdir(exist_ok=True)
    (ROOT / 'reports/perf_02_python.json').write_text(json.dumps(report, indent=2) + '\n')
    sys.exit(0 if result.wasSuccessful() and result.testsRun >= 5 and not result.skipped else 1)
