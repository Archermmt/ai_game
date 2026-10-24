"""Three serial30s severe-weather capacity probes, separate from edit-latency gates."""
import json
import hashlib
from common import ROOT
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main():
    native.OUT = ROOT / 'reports/week_13/weather_capacity'
    native.OUT.mkdir(parents=True, exist_ok=True)
    before = production_files()
    rows = {}
    for weather, season, particles in [('storm', 'summer', 1400), ('blizzard', 'winter', 900), ('duststorm', 'summer', 700)]:
        row = native.probe(weather, ['--w09-stress', '--ux-select', '--season=' + season,
            '--weather=' + weather, '--hour=12'], 30, audio_args=['--audio-driver', 'Dummy'])
        assert row['metrics']['calendar']['weather'] == weather
        assert row['metrics']['weather_particles'] == particles
        rows[weather] = row
    assert production_files() == before
    targets = {'frame_p95_20ms': all(p['p95_frame_ms'] <= 20 for p in rows.values()),
               'rss_2gib': all(p['rss_peak_bytes'] and p['rss_peak_bytes'] < 2 * 1024**3 for p in rows.values())}
    result = {'probes': rows, 'targets': targets, 'functional_passed': True,
              'production_unchanged': True, 'audio': 'Dummy', 'physical_audio_verified': False,
              'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
                  'features/living_world/living_atmosphere.gd', 'features/living_world/precipitation.gdshader',
                  'features/living_world/calendar_state.gd', 'features/living_world/weather_cycle.gd']},
              'note': 'Fixed24-house/1000-instance capacity,30s each. No edit benchmarks; previous first-edit spikes remain open.'}
    (ROOT / 'reports/weather_capacity.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Weather capacity functional PASS; budgets:', targets)


if __name__ == '__main__':
    main()
