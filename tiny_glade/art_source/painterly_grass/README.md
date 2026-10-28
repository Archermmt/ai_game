# Painterly Grass · G1 local samples

`manifest.json` records the three supplied CGChefs models and derived source/GLB hashes.
The original vendor `.blend` is opened read-only. Extracted editable sources are preserved in
`local/*.blend`; the shared coverage PNG and three material-free GLBs are in
`assets/painterly_grass/local/`. These two directories are intentionally local-only while
source-asset repository/distribution terms remain unrecorded. Do not delete the editable sources.

Run from the project root with Blender 5.1.2:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec \
  --python tools/art/extract_painterly_grass.py -- --root "$PWD" \
  --library /Users/tongmeng/Desktop/assets/3d/PainterlyGrass/CGC_Painterly_Grass_1.0/CGC_Painterly_Grass_1.0.blend
python3 tools/quality/painterly_grass_checks.py --stage 1
```

Reopen source audit after extraction:

```bash
mkdir -p reports/week_14/g1
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --disable-autoexec \
  --python tools/art/audit_sources.py -- --root "$PWD" --output reports/week_14/g1/source_audit.json \
  --extra-manifest art_source/art_pass_01/nature/manifest.json \
  --extra-manifest art_source/painterly_grass/manifest.json
```

The C JPEG atlas is an RGB opacity/brush mask, not an albedo map. Its linear RGB intensity
is converted to alpha in a shared 2048px PNG. Original `UVMap` is coverage; the chosen models'
other two UV sets are duplicates. Godot recreates color, thin-leaf light and wind.
`COLOR_0` remains `wind_mask`; glTF performs Z-up to Y-up exactly once.
No vendor node graph, scatter system, demo terrain or original lighting is exported.

A Git checkout alone currently has code/recipes/hash records, not the vendor derivatives.
Use the extractor locally, or supply the exact manifest-bound local assets.
The preview explicitly reports missing assets and never substitutes old grass as new.
