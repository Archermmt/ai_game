from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"art_source/ui_meadow_01/icons"
SOURCE.mkdir(parents=True,exist_ok=True)
paths={
'palette':'M20 48 C4 41 11 17 31 13 C51 10 60 27 48 35 C37 33 33 37 38 43 C40 51 28 55 20 48 Z M22 25 h1 M34 21 h1 M46 27 h1 M19 37 h1',
'edit':'M14 44 L42 16 L50 24 L22 52 L12 54 Z M37 21 L45 29 M14 44 L22 52',
'camera':'M10 24 H22 L26 17 H39 L43 24 H55 V51 H10 Z M42 37 A10 10 0 1 1 22 37 A10 10 0 1 1 42 37',
'sun':'M42 32 A10 10 0 1 1 22 32 A10 10 0 1 1 42 32 M32 7 V14 M32 50 V57 M7 32 H14 M50 32 H57 M14 14 L19 19 M45 45 L50 50 M14 50 L19 45 M45 19 L50 14',
'settings':'M26 11 H38 L40 20 L49 20 L55 31 L49 40 L40 42 L38 53 H26 L24 44 L15 44 L9 33 L15 24 L24 22 Z M40 32 A8 8 0 1 1 24 32 A8 8 0 1 1 40 32',
'library':'M10 17 H27 L32 23 H54 V52 H10 Z M17 34 H45 M17 42 H38',
'undo':'M17 17 L8 26 L17 35 M9 26 H35 Q54 26 51 45 M51 45 L46 50',
'redo':'M47 17 L56 26 L47 35 M55 26 H29 Q10 26 13 45 M13 45 L18 50'}
for name,d in paths.items():
 (ROOT/f'assets/ui/garden/{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><path d="{d}" fill="none" stroke="#40594b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>\n')

for name in paths:
    raw=(ROOT/f"assets/ui/garden/{name}.svg").read_bytes()
    (SOURCE/f"{name}.svg").write_bytes(raw)
(ROOT/"art_source/ui_meadow_01/icons_manifest.json").write_text(json.dumps({"license":"Project original SVG paths", "generator":"tools/art/build_garden_ui.py", "files":{name:hashlib.sha256((SOURCE/f"{name}.svg").read_bytes()).hexdigest() for name in paths}},indent=2)+"\n")
