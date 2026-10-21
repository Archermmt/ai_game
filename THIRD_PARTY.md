# Third-party software

| Component | Version | License | Use |
| --- | --- | --- | --- |
| Godot Engine | 4.7.2 stable Standard | MIT | Editor, runtime and desktop export templates; downloaded to ignored `.tools/` |
| GUT | v9.7.1, `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` | MIT, Tom “Butch” Wesley | Vendored under `addons/gut/`; tests only, excluded from exports |
| gdtoolkit | 4.5.0 | MIT | Local lint / formatting; requirements recorded, excluded from exports |
| Blender | 5.1.2 | GPL-3.0-or-later | Installed authoring tool; not included in game exports |

GUT's complete license is in `addons/gut/LICENSE.md`. Godot's license and required
third-party acknowledgements are available at <https://godotengine.org/license/>.
Export bundles must include the Godot license notice. Blender does not impose its
software license on original artwork created using it.

Week 1–7 `.blend`, GLB models, painted-source PNGs and their Python generators are original project assets;
they do not incorporate third-party models, demo textures or optional add-on output.
Concept images in `docs/` remain design references and are excluded from game exports.

## Bundled Chinese font

Noto Sans CJK SC Regular (subset OTF), Copyright 2014–2021 Adobe,
SIL Open Font License 1.1. Unmodified font and complete license are distributed at
`assets/fonts/NotoSansSC-Regular.otf` and `assets/fonts/OFL.txt`; the latter is
included in game packs and also copied next to exported bundles as `FONT_OFL.txt`.
Pinned upstream commit: `f8d157532fbfaeda587e826d4cd5b21a49186f7c`.
[Official font source](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf)
and [complete license](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE).
Hash and origin are recorded in `assets/fonts/manifest.json`.

Week 6 tool/feedback SVGs and DSP-generated PCM audio are original project assets,
with editable SVG and synthesis scripts retained. Audio uses synthesized noise and
original note sequences, without third-party field recordings, samples or music.

Week 7 continuous circular window and editable material swatches are original project assets.
Native material thumbnails reuse the project’s original painted textures; no new external artwork is bundled.

ART-01 replacement nature geometry, painted forest atlas and nine material maps
are original project artwork. Editable Blender sources, paint recipes, licenses
and hashes are retained under `art_source/art_pass_01/`. No external models,
textures or runtime plugins were added. The entry thumbnail is a native Godot
capture of the editable scene; concept reference images are not shipped as scene assets.

### W10 stereo forest

`assets/audio/forest_stereo.wav` derives exclusively from the project-original W06 DSP forest source, with stereo decorrelation and a short seam envelope. Rebuild: `python3 tools/art/build_week_ten_audio.py`; source and hash in `art_source/week_10/audio_manifest.json`. No external samples, recordings, services, or additional licenses. W10 playback reuses the existing original W06 wind, water, wood/stone/grass/UI and optional 24-second musical motif; the motif is not represented as a final 2–3 minute composition.
