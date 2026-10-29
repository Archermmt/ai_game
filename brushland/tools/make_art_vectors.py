"""Original vector artwork for brushes, actions, wishes and state indicators."""
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'game/ui/vectors';OUT.mkdir(exist_ok=True)
brushes=[
'<path fill="#a7bc87" d="M8 32 32 18 56 32 32 46Z"/><path d="M12 29v-8m8 5v-9m9 4v-7"/>',
'<path fill="#e1c995" d="M8 32 32 18 56 32 32 46Z"/><circle cx="29" cy="29" r="1"/><circle cx="36" cy="35" r="1"/>',
'<path fill="#a8ada1" d="m16 45 8-27 15-4 12 31Z"/><path d="m24 18 8 17 7-21"/>',
'<path d="M10 26q6-8 12 0t12 0 12 0 10 0M10 39q6-8 12 0t12 0 12 0 10 0"/>',
'<path d="M32 50V14m-13 13 13-13 13 13"/>',
'<path d="M32 14v36M19 37l13 13 13-13"/>',
'<path fill="#d7c6a2" d="M8 49c2-18 24-12 28-28l13 5c-3 20-24 12-25 27Z"/>',
'<path d="M32 51V28m0 15L20 34"/><circle fill="#d9b2b5" cx="32" cy="20" r="8"/><circle fill="#f2da9b" cx="32" cy="20" r="2"/>']
actions=[
'<path d="m24 17-13 12 13 10M12 29h25c18 0 19 22 0 22"/>',
'<path d="m40 17 13 12-13 10m12-10H27c-18 0-19 22 0 22"/>',
'<path d="M32 9v46M9 32h46m-30-16 7-7 7 7m-23 9-7 7 7 7m9 9 7 7 7-7m9-23 7 7-7 7"/>',
'<path d="m16 16 32 32m0-32L16 48"/>',
'<path d="M18 21a19 19 0 1 1-2 25M18 10v15H5"/>',
'<rect x="10" y="20" width="44" height="31" rx="5"/><circle cx="32" cy="35" r="9"/><path d="m22 20 4-8h13l5 8"/>']
wishes=[
'<path d="M11 36h42M16 28h32M16 36v16m32-16v16M16 17v19m32-19v19"/>',
'<path d="M32 53V29m0 6C8 35 15 15 32 29m0 3c22-3 19-23 0-11"/>',
'<path d="M13 24h32v16c0 17-32 17-32 0Zm32 4c17-3 17 17 0 14M20 16q5-5 0-9m12 9q5-5 0-9"/>',
'<path d="M7 40q25-23 50 0M8 29q24-23 48 0M12 27v14m13-20v11m14-11v11m13-5v14"/>',
'<path d="m12 29 20-16 20 16v25H12Zm0 0h40M32 13v41M12 42h40"/>',
'<path d="m23 50 4-30h11l4 30Zm0-30 9-11 10 11M19 53h27M29 27h7m-7 9h7M12 20l-7-3m47 3 7-3"/>']
states=[
'<path d="m27 37 10-10m-18 14-3 3a10 10 0 0 1-14-14l12-12a10 10 0 0 1 14 0m8 4 3-3a10 10 0 0 1 14 14L41 46a10 10 0 0 1-14 0"/>',
'<path d="m24 40-6 6a10 10 0 0 1-14-14l9-9m27 1 6-6a10 10 0 0 1 14 14l-9 9M24 24l16 16"/>',
'<rect x="17" y="29" width="30" height="25" rx="4"/><path d="M23 29V19a9 9 0 0 1 18 0v10m-9 8v8"/>',
'<rect x="17" y="29" width="30" height="25" rx="4"/><path d="M24 29V17a9 9 0 0 1 18-1M32 37v8"/>']
for group,items in [('UI_001',brushes),('UI_002',actions),('UI_003',wishes),('UI_004',states)]:
 for i,shape in enumerate(items):
  (OUT/f'{group}_{i:02}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#496c5b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>\n')
print('Created 24 original SVG icons')
