"""Capture actual engine music/ambient PCM; no microphone or physical-listening claim."""
import argparse
import json
import math
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files


def validate(result):
    assert min(result['frames']) > 48000, 'Mixer did not produce enough PCM'
    assert result['position'] > 8, 'Music playback clock did not advance'
    assert result['music_rms'] > 0.003, 'Music is inaudible at the calibrated default gain'
    ratio = 20 * math.log10(result['music_rms'] / result['ambient_rms'])
    assert -9 < ratio < 0, 'Music must be discernible below the ambience in this fixed clear-day mix'
    assert 0 < max(result['peaks']) < 0.5, 'Silent or excessively loud mix'
    return ratio


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--driver', default='CoreAudio')
    args = parser.parse_args()
    before = production_files()
    step = run_step('seasonal_music_mix', [engine_binary(), '--audio-driver', args.driver,
        '--path', '.', '-s', 'tests/week_13/music_mix_probe.gd', '--', '--qa-settings'], timeout=50)
    path = ROOT / ('reports/music_mix_' + args.driver + '.json')
    result = json.loads(path.read_text())
    assert result['driver'] == args.driver
    ratio = validate(result)
    assert production_files() == before
    result.update(passed=True, production_unchanged=True, step=step, music_to_ambient_db=ratio)
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(f'PASS actual{args.driver} PCM; music relative to ambience{ratio:.2f}dB; physical listening separate')


if __name__ == '__main__':
    main()
