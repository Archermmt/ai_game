"""Serial60s W13 climate budgets; fixed capacity source plus actual rolling demo."""
import json
import subprocess
from common import ROOT
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main():
    native.OUT = ROOT / 'reports/week_13/performance'
    native.OUT.mkdir(parents=True, exist_ok=True)
    before = production_files()
    rows = {}
    cases = [('rolling_demo', ['--ux-select', '--season=spring', '--weather=clear']),
             ('capacity_clear', ['--w09-stress', '--ux-select', '--season=summer', '--weather=clear']),
             ('capacity_rain', ['--w09-stress', '--ux-select', '--season=autumn', '--weather=rain']),
             ('capacity_snow', ['--w09-stress', '--ux-select', '--season=winter', '--weather=snow'])]
    for name, flags in cases:
        row = native.probe(name, [*flags, '--hour=12', '--edit-benchmark'], 60, audio_args=['--audio-driver', 'Dummy'])
        assert len(row['metrics']['commit_latency_samples_ms']) == 20
        assert 'calendar' in row['metrics']
        expected = 1400 if name == 'capacity_rain' else (900 if name == 'capacity_snow' else 0)
        assert row['metrics']['weather_particles'] == expected
        rows[name] = row
    assert rows['rolling_demo']['metrics']['terrain_profile'] == 'rolling_hills_v2'
    assert production_files() == before
    targets = {'frame_p95_20ms': all(p['p95_frame_ms'] <= 20 for p in rows.values()),
               'local_p95_150ms': all(p['metrics']['commit_latency_p95_ms'] <= 150 for p in rows.values()),
               'local_max_150ms': all(p['metrics']['commit_latency_max_ms'] <= 150 for p in rows.values()),
               'main_callback_100ms': all(p['metrics']['main_callback_max_ms'] <= 100 for p in rows.values()),
               'rss_2gib': all(p['rss_peak_bytes'] < 2 * 1024**3 for p in rows.values())}
    result = {'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'probes': rows, 'targets': targets, 'functional_passed': True, 'production_unchanged': True,
              'audio': 'Dummy; real audio unverified', 'm4_approved': False, 'm5_approved': False,
              'note': 'Capacity preserves the fixed W09 geometry for climate cost comparisons; rolling terrain measured separately. No prewarm edits or dropped first sample.'}
    (ROOT / 'reports/week_13_performance.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W13 performance functional PASS; independent budget targets:', targets)


if __name__ == '__main__':
    main()
