# ProtonScatter integration

Pinned upstream addon: **4.2.0**, commit `7198cc00078ebde61307578137c3f35223c6e438` (2026-09-27).

- Source: <https://github.com/HungryProton/scatter/tree/7198cc00078ebde61307578137c3f35223c6e438/addons/proton_scatter>
- Canonical upstream: <https://codeberg.org/hungryproton/proton_scatter>
- License: `addons/proton_scatter/LICENSE` (MIT).
- Provenance and complete copied-file hashes: `proton_scatter.lock.json`.
- Only the addon is installed. Bundled demos and upstream tests are omitted; addon runtime/editor source is unchanged. Its mask textures and default presets are retained because the editor uses them.

`LandscapeScatterAdapter.generate(parent, region, amount, seed, sample_surface, options)` evaluates the upstream **Create Inside (Random)** and **Randomize Transforms** modifiers. The explicit seed produces stable candidates. The adapter does not generate its own random positions.

The projection modifier is the project-specific boundary: `sample_surface(Vector2(world_x, world_z))` returns `{height: float, normal: Vector3, allowed: bool}` from the authoritative surface. It filters blocked roots and excessive slopes, projects onto the latest terrain and optionally aligns the instance to its normal. No saved source document, transaction or physics collider is modified. Returned transforms use world coordinates; a transformed rendering parent must convert them to its local space.

Supported options: `scale_min`/`scale_max` (default 0.8/1.2), `normal_alignment` (0.75), `max_slope_degrees` (55), `root_offset_m` (0). `last_candidate_count` and `last_accepted_count` are diagnostics for the most recent call. Each grass layer should use its own stable seed and amount; overlapping layers are intentional.

The runtime adapter does not require enabling the editor plugin. Enable `res://addons/proton_scatter/plugin.cfg` to author ScatterShape nodes and modifier stacks in the editor. Final rendering and its grass shaders remain the landscape lab's responsibility: scattering alone does not repair atlas opacity, leaf normals or flat terrain materials.

Static verification: `.venv/bin/gdformat --check features/landscape_lab/scatter_adapter.gd features/landscape_lab/sample_surface_modifier.gd` and `.venv/bin/gdlint` on those same files. Native Godot and scene verification belongs to the lab's integration validation.
