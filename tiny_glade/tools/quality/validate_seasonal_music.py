"""Validate committed user-provided music derivatives without requiring ffmpeg."""
import hashlib
import json
from pathlib import Path
from common import ROOT


def main():
    folder = ROOT / 'assets/audio/seasonal_music'
    manifest = json.loads((folder / 'manifest.json').read_text())
    tracks = manifest['tracks']
    assert len(tracks) == 8 and len({t['id'] for t in tracks}) == 8
    for track in tracks:
        path = ROOT / track['export']
        assert path.parent == folder and path.suffix == '.mp3'
        assert hashlib.sha256(path.read_bytes()).hexdigest() == track['sha256']
        assert 60 < track['seconds'] < 300
        assert -26 < track['integrated_lufs'] < -22
        assert track['true_peak_dbtp'] <= -4
        assert track['rights'].startswith('User-provided')
    assert {p.stem for p in folder.glob('*.mp3')} == {t['id'] for t in tracks}
    print('PASS8 music hashes, durations, measured loudness and source provenance')


if __name__ == '__main__':
    main()
