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

Week 1 `.blend`, GLB models and their Python generator are original project assets;
they do not incorporate third-party models, demo textures or optional add-on output.
Concept images in `docs/` remain design references and are excluded from game exports.
