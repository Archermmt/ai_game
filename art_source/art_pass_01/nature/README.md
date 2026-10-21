# Painted forest · Art pass 01

Original P0 replacements guided by `docs/art/concepts/01_key_visual.png` and
`04_props_nature.png`. Historical source/export files are preserved.

The broadleaf and fruit crowns use irregular dark inner value masses plus folded
compound-leaf sprays, with individually painted scalloped leaf edges and veins.
The conifer uses ten layers of drooping bough sprays and closed, tapered needle
fans. The solid fans preserve full distant coverage after alpha mip reduction;
their pointed outline replaces stacked cones and round cushions. Broadleaf and
fruit-tree LOD use a dedicated high-coverage compound-leaf atlas region with
matching near/far crown dimensions. Roots and trunks are closed tapered branching meshes. The undergrowth
includes an arching seven-frond fern, a mixed meadow clump with ivory daisies and
two lavender stems, and a compact leafy shrub. Rock and flat-stone moss follows
the actual upper rock surface, with texture-cut irregular edges. No extra P1
asset family is introduced. NAT-07 continues to reuse the NAT-06 shrub.

Rebuild with Blender **5.1.2**, no plugins:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/art/build_art_foliage.py -- --root "$PWD" --preview
```

Reopen-only validation, retaining its machine-readable report:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/art/build_art_foliage.py -- --root "$PWD" --audit-only
```

The generator checks triangle budgets, UV, finite positions/normals, source
unit transforms, wind channels and ground sockets after reopening all 11 source
files. `source_reopen_audit.json` records this check. The project-wide
`tools/art/audit_sources.py` is also run with `--root`,
`--extra-manifest art_source/art_pass_01/nature/manifest.json` and `--output`;
`project_source_audit.json` records its 46-source baseline and these 11 new
sources. `glb_contract_audit.json` additionally checks actual exported binary
normal lengths, UV, color channels, indices, counts and sockets.

| Identity | LOD0 triangles | LOD1 triangles | PRD LOD0 budget |
| --- | ---: | ---: | ---: |
| NAT-01 broadleaf | 3630 | 1676 | 4000 |
| NAT-02 conifer | 3412 | 1576 | 3500 |
| NAT-03 fruit | 3154 | 1500 | 4000 |
| NAT-04 fern | 448 | — | 500 |
| NAT-05 wildflower | 290 | — | 450 |
| NAT-06 shrub | 342 | — | 500 |
| NAT-08 moss rock | 682 | — | 1000 |
| NAT-09 flat rock | 450 | — | 800 |

The explicit source LOD is authoritative. Godot importer-generated LOD should
be disabled for these files. The wrapper switches tree detail at 37 m. Exported
meshes are joined by role: 2–4 draw parts per asset per level, not one node per
leaf. The shared 2048² atlas is generated from the retained paint recipe and
contains leaf, twig, bark, meadow, flower, stone and moss regions with extended
RGB under transparent pixels. It is an updated MAT-03 source, not another atlas
family. All artwork is project original; no downloaded models or textures.

Runtime integration uses `ArtFoliageCatalog.configure(shader)` before `create`.
The shader must expose `atlas`, `phase`, `amplitude`, `foliage_tint`, the existing
wind/freeze/reduce-motion uniforms and `batched`. UV picks the semantic surface;
do not recolor trunks and stones with a universal green override. `COLOR_0.r`
is root-pinned wind strength, `.g` local phase, `.b` fruit only and `.a` always
1. Texture alpha supplies coverage and needs scissor, double-sided rendering.
Wind cull margin is 0.35 m. The contact sheet is a Blender preview of the actual
source geometry; native Godot multi-angle/day/dusk review and stress timing
remain part of integration and are not replaced by this preview.

`--audit-only --preview --preview-lod` renders the same camera with the explicit
LOD1 trees for visual comparison, without rewriting model source or GLBs.
