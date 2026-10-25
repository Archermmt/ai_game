"""Capture actual engine music/ambient PCM; no microphone or physical-listening claim."""
import argparse
import json
import math
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def validate(result, baseline=False):
    assert result['weather'] in ['clear', 'storm']
    assert result['weather'] == result['calendar_weather']
    assert result['automatic_weather'] is False
    assert result['master_muted'] is True, 'Probe device output was not muted'
    assert result['bus_order'] == ['QaMusic', 'QaAmbient', 'QaWind']
    assert len(result['frames']) == len(result['peaks']) == 3
    assert min(result['frames']) > 48000, 'Mixer did not produce enough PCM'
    assert result['position'] > 8, 'Music playback clock did not advance'
    for key in ['music_rms', 'ambient_rms', 'wind_rms']:
        assert math.isfinite(result[key]) and result[key] > 0, 'Silent or invalid ' + key
    assert all(0 < peak < 0.5 for peak in result['peaks']), 'Silent or excessively loud bus'
    assert result['weather_blend_age'] >= 18, 'Weather transition did not settle'
    if result['weather'] == 'storm':
        assert result['wind_strength'] >= 0.95, 'Storm did not reach its stronger wind bed'
    ratio = 20 * math.log10(result['music_rms'] / result['ambient_rms'])
    wind_ratio = 20 * math.log10(result['music_rms'] / result['wind_rms'])
    if not baseline:
        assert result['music_rms'] > 0.003, 'Music is inaudible at the calibrated default gain'
        if result['weather'] == 'clear':
            assert 0 < ratio < 6, 'Clear-day music must remain discernible over ambience'
            assert wind_ratio >= 3, 'Clear-day wind masks the music'
        else:
            assert ratio > -4, 'Storm ambience masks the music'
            assert wind_ratio >= 0, 'Storm wind masks the music'
    return ratio, wind_ratio


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--driver', default='CoreAudio')
    parser.add_argument('--weather', choices=['clear', 'storm'], default='clear')
    parser.add_argument('--baseline', action='store_true', help='Record the previous balance without approving new calibration')
    args = parser.parse_args()
    (ROOT / 'reports').mkdir(exist_ok=True)
    before = production_files()
    suffix = '_storm' if args.weather == 'storm' else ''
    path = ROOT / ('reports/music_mix_' + args.driver + suffix + '.json')
    path.unlink(missing_ok=True)
    step = run_step('seasonal_music_mix' + suffix, [engine_binary(), '--audio-driver', args.driver,
        '--path', '.', '-s', 'tests/week_13/music_mix_probe.gd', '--', '--qa-settings',
        '--mix-weather=' + args.weather], timeout=50)
    result = json.loads(path.read_text())
    assert result['driver'] == args.driver
    assert result['weather'] == args.weather
    ratio, wind_ratio = validate(result, args.baseline)
    assert production_files() == before
    result.update(passed=not args.baseline, baseline=args.baseline, capture_valid=True,
                  calibration_passed=not args.baseline, production_unchanged=True, step=step,
                  music_to_ambient_db=ratio, music_to_wind_db=wind_ratio)
    path.write_text(json.dumps(result, indent=2) + '\n')
    label = 'BASELINE captured' if args.baseline else 'PASS calibrated'
    print(f'{label} actual {args.driver} {args.weather} PCM; music/ambience {ratio:.2f}dB; '
          f'music/wind {wind_ratio:.2f}dB; device output muted; physical listening separate')


if __name__ == '__main__':
    main()
