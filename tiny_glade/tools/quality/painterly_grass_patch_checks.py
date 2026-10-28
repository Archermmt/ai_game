"""G2 visible Metal probe runner; wall-clock RSS, stderr and real output are required."""
import json
import subprocess
import time
from common import ROOT, engine_binary
from run_checks import ERRORS


def native_patch(out, stage=2):
    native = out / 'native'
    native.mkdir(parents=True, exist_ok=True)
    report_path = native / 'report.json'
    report_path.unlink(missing_ok=True)
    command = [engine_binary(), '--always-on-top', '--audio-driver', 'Dummy',
               '--path', str(ROOT), '--resolution', '1920x1080', '-s',
               f'tests/week_14/{"grass_garden" if stage == 3 else "grass_patch"}_native_probe.gd', '--', f'--g{stage}-fhd', str(native)]
    started = time.monotonic()
    readings = []
    log_path = out / 'native.log'
    with log_path.open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        try:
            while process.poll() is None:
                if time.monotonic() - started > 210:
                    raise RuntimeError(f'G{stage} native probe timed out')
                reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)],
                                         text=True, capture_output=True).stdout.strip()
                if reading.isdigit():
                    readings.append(int(reading) * 1024)
                time.sleep(0.25)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    assert process.returncode == 0 and not ERRORS.search(log_path.read_text()), log_path
    report = json.loads(report_path.read_text())
    assert report['passed'] and len(report['checks']) >= 25 and all(report['checks'].values())
    assert readings and max(readings) <= 2 * 1024**3
    assert len(list(native.glob('*.png'))) >= (14 if stage == 3 else 10)
    report.update(rss_peak_bytes=max(readings), rss_samples=len(readings), command=command,
                  physical_touchpad_verified=False, physical_audio_verified=False,
                  gpu_timing_ms=None, capacity_benchmark=False)
    return report, {'name': f'g{stage}_native', 'exit_code': process.returncode,
                    'seconds': round(time.monotonic() - started, 3)}
