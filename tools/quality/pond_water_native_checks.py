"""Native water-only pixel tests, real geometry reflection, motion and leak guards."""
import json
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def main():
    folder = ROOT / 'reports/water_final'
    folder.mkdir(parents=True, exist_ok=True)
    before = production_files()
    step = run_step('water_pixels', [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy', '--path', '.',
        '--resolution', '1920x1080', '-s', 'tests/week_13/water_native_probe.gd', '--', '--qa-settings',
        '--art-fhd', str(folder)], timeout=60)
    assert 'were leaked' not in (ROOT / 'reports/water_pixels.log').read_text()
    result = json.loads((folder / 'water_report.json').read_text())
    assert result['passed'] and len(result['checks']) == 9 and all(result['checks'].values())
    assert before == production_files()
    result.update(step=step, production_unchanged=True, audio='Dummy', foreground_window=True, physical_audio_verified=False)
    (ROOT / 'reports/pond_water_native.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PASS9 water checks, real reflection and ripple pixel differences; no RID leak warning')


if __name__ == '__main__':
    main()
