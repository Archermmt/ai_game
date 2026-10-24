"""Desktop icon input and actual real-time weather/sky screenshots, serial GPU run."""
import json
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    folder = ROOT / 'reports/sky_weather'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'report.json').unlink(missing_ok=True)
    before = production_files()
    step = run_step('sky_weather_native', [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/sky_weather_native_probe.gd', '--', '--qa-settings', '--art-fhd', str(folder)], timeout=180)
    report = json.loads((folder / 'report.json').read_text())
    assert report['passed'] and len(report['checks']) >= 18 and all(report['checks'].values())
    assert production_files() == before
    report.update(step=step, production_unchanged=True, audio='Dummy', foreground_window=True, physical_trackpad_verified=False)
    (ROOT / 'reports/sky_weather_native.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PASS sky/weather native:', len(report['checks']))


if __name__ == '__main__':
    main()
