"""Native capacity edit and continuous camera-orbit costs, never parallel to imports."""
import json
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main():
    native.OUT = ROOT / 'reports/water_performance'
    native.OUT.mkdir(parents=True, exist_ok=True)
    before = production_files()
    capacity = native.probe('capacity_edit', ['--w09-stress', '--season=summer', '--weather=clear',
        '--hour=12', '--edit-benchmark'], 60, audio_args=['--audio-driver', 'Dummy'])
    path = native.OUT / 'orbit.json'
    step = run_step('water_orbit', [engine_binary(), '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/water_orbit_probe.gd', '--', '--qa-settings',
        '--art-fhd', '--w09-stress', str(path)], timeout=65)
    orbit = json.loads(path.read_text())
    assert orbit['frames'] > 300 and orbit['duration_ms'] >= 30000 and orbit['source_unchanged']
    assert 100 < orbit['captures'] <= 244
    assert 'were leaked' not in (ROOT / 'reports/water_orbit.log').read_text()
    assert before == production_files()
    targets = {'capacity_frame_p95_20ms': capacity['p95_frame_ms'] <= 20,
               'orbit_frame_p95_20ms': orbit['p95_frame_ms'] <= 20,
               'rss_2gib': capacity['rss_peak_bytes'] < 2 * 1024**3,
               'edit_p95_150ms': capacity['metrics']['commit_latency_p95_ms'] <= 150,
               'edit_max_150ms': capacity['metrics']['commit_latency_max_ms'] <= 150}
    result = {'capacity': capacity, 'orbit': orbit, 'step': step, 'targets': targets,
              'production_unchanged': True, 'audio': 'Dummy', 'physical_audio_verified': False,
              'note': 'All camera-frame intervals including initial source construction retained. Edit maximum gate remains independent.'}
    (ROOT / 'reports/pond_water_performance.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PASS water performance collection; independent targets:', targets)


if __name__ == '__main__':
    main()
