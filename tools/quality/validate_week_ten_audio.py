"""Check the new stereo source and a conservative simultaneous-voice headroom bound."""
import array
import hashlib
import json
import math
import wave
from common import ROOT


def peak(path):
    with wave.open(str(ROOT / path)) as stream:
        values = array.array('h', stream.readframes(stream.getnframes()))
    return max(abs(v) for v in values) / 32768


def main():
    entry = json.loads((ROOT / 'art_source/week_10/audio_manifest.json').read_text())
    raw = (ROOT / entry['export']).read_bytes()
    assert raw == (ROOT / entry['source']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == entry['sha256']
    with wave.open(str(ROOT / entry['export'])) as stream:
        assert stream.getnchannels() == 2 and stream.getsampwidth() == 2 and stream.getframerate() == 48000
        values = array.array('h', stream.readframes(stream.getnframes()))
        assert values[:2] == values[-2:] == array.array('h', [0, 0])
        assert values[::2] != values[1::2], 'stereo must contain distinct channels'
    # Triangle/Cauchy bounds cover all phases, four overlapping effects, all sliders at 100%.
    bed = peak(entry['export']) * .6
    wind = math.hypot(peak('assets/audio/wind_low.wav'), peak('assets/audio/wind_high.wav')) * .65
    water = peak('assets/audio/water.wav') * .7
    effect = max(peak(f'assets/audio/{family}_{i}.wav') for family in ['wood', 'stone', 'grass', 'ui'] for i in range(1, 4)) * .8 * 4
    music = peak('assets/audio/sparse_music.wav') * .5
    bound = bed + wind + water + effect + music
    assert bound < 1, f'Worst-case mixer may clip: {bound}'
    result = {'stereo_original_source': True, 'worst_case_linear_peak_bound': bound,
              'headroom_db': -20 * math.log10(bound), 'max_effect_voices': 4,
              'music': '24 second original optional motif; full 2–3 minute arrangement remains final audio work', 'passed': True}
    (ROOT / 'reports/week_10_audio_assets.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W10 AUDIO PASS; worst-case peak bound', round(bound, 4))


if __name__ == '__main__':
    main()
