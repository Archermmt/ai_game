"""Original stereo forest derived only from the project's W06 DSP synthesis."""
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import wave

ROOT = Path(__file__).resolve().parents[2]
with wave.open(str(ROOT / 'art_source/week_06/audio/forest.wav')) as stream:
    samples = array.array('h', stream.readframes(stream.getnframes()))
    rate = stream.getframerate()
# Same bed, a quiet decorrelated channel; fade boundaries preserve a silent seam.
stereo = array.array('h')
for i, value in enumerate(samples):
    edge = min(1.0, i / 480, (len(samples) - 1 - i) / 480)
    other = samples[(i + 4321) % len(samples)]
    stereo.extend([round(value * edge * .85), round((.65 * value + .35 * other) * edge * .85)])
source = ROOT / 'art_source/week_10/audio/forest_stereo.wav'
source.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(source), 'wb') as stream:
    stream.setparams((2, 2, rate, 0, 'NONE', 'not compressed'))
    stream.writeframes(stereo.tobytes())
target = ROOT / 'assets/audio/forest_stereo.wav'
shutil.copyfile(source, target)
manifest = {'family': 'AUD-01', 'source': str(source.relative_to(ROOT)), 'export': str(target.relative_to(ROOT)),
            'channels': 2, 'rate': rate, 'seconds': len(samples) / rate,
            'peak_dbfs': 20 * math.log10(max(abs(v) for v in stereo) / 32768),
            'license': 'Project original DSP synthesis; no external recordings or samples',
            'generator': 'tools/art/build_week_ten_audio.py', 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
(ROOT / 'art_source/week_10/audio_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Stereo forest:', manifest['seconds'], 'seconds;', manifest['peak_dbfs'], 'dBFS')
