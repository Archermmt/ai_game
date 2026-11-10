"""Inventory demo assets and verify music supply without external download folders."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    assets = []
    for path in sorted((ROOT / 'assets').rglob('*')):
        relative = path.relative_to(ROOT).as_posix()
        if (not path.is_file() or path.suffix == '.import'
                or relative == 'assets/demo_inventory.json'
                or relative.startswith('assets/painterly_grass/local/')):
            continue
        assets.append({'path': relative, 'bytes': path.stat().st_size,
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest = json.loads((ROOT / 'assets/audio/seasonal_music/manifest.json').read_text())
    assert len(manifest['tracks']) == 8
    for row in manifest['tracks']:
        path = ROOT / row['export']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], path
    for path in (ROOT / 'features').rglob('*'):
        assert path.suffix.lower() not in {'.png', '.jpg', '.svg', '.glb', '.wav', '.mp3', '.ttf', '.otf'}, path
    result = {'main_scene': 'res://app/living_root.tscn',
              'generated_mesh_sources': ['features/art_direction/woodland_nature.gd',
                  'features/art_direction/cottage_art.gd', 'features/landscape/woodland_grasses.gd'],
              'music_manifest': 'assets/audio/seasonal_music/manifest.json', 'files': assets}
    (ROOT / 'assets/demo_inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f"Demo assets checked: {len(assets)} files, eight music tracks")


if __name__ == '__main__':
    main()
