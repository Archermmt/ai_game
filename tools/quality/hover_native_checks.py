"""UX-03 native surface GUI dispatch, screenshots and selected capacity measurement."""
import json
import struct
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files
import week_ten_native_checks as native


def main():
    out = ROOT / 'reports/ux_03/native'
    out.mkdir(parents=True, exist_ok=True)
    before = production_files()
    run_step('ux03_native_dispatch', [engine_binary(), '--path', '.', '--resolution', '1920x1080',
        '-s', 'tests/ux_03/native_probe.gd', '--', '--qa-settings', '--art-fhd', str(out)])
    report = json.loads((out / 'native_report.json').read_text())
    assert len(report) >= 24 and all(report.values())
    for name in ['hover_roof', 'roof_raised', 'roof_flat', 'hover_window', 'hover_bridge', 'hover_150', 'photo', 'photo_return']:
        assert struct.unpack_from('>II', (out / (name + '.png')).read_bytes(), 16) == (1920, 1080)
    native.OUT = out
    capacity = native.probe('selected_capacity', ['--w09-stress', '--ux-select', '--edit-benchmark'], 60)
    assert capacity['metrics']['ux03_hover_interface'] and capacity['metrics']['ribbon_categories'] == 11
    assert production_files() == before, 'QA changed formal saves/preferences'
    result = {'native_dispatch': report, 'capacity': capacity, 'production_unchanged': True,
              'targets': {'frame_p95_20ms': capacity['p95_frame_ms'] <= 20,
                          'main_callback_100ms': capacity['metrics']['main_callback_max_ms'] <= 100,
                          'rss_2gib': capacity['rss_peak_bytes'] < 2 * 1024**3,
                          'local_edit_p95_150ms': capacity['metrics']['commit_latency_p95_ms'] <= 150},
              'device': 'Apple M4 Pro / macOS / Metal', 'gpu_timer': None,
              'physical_trackpad': 'not_run', 'windows_real_device': 'not_run', 'functional_passed': True}
    (ROOT / 'reports/ux_03_native_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('UX-03 native functional PASS; targets', result['targets'])


if __name__ == '__main__': main()
