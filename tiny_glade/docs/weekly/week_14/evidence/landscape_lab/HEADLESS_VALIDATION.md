# Focused landscape validation

2026-10-25 (Asia/Shanghai): `8` focused Godot tests, `365` JUnit testcase assertions, zero failures/skips. Command: `python3 tools/quality/landscape_lab_checks.py --skip-import`. A clean project import had already completed; this focused command does not claim another import.

- The four scatter tests exercise the actual upstream ProtonScatter candidate/transform modifiers, stable seeds, terrain projection/protection and temporary-node cleanup.
- Four lab tests validate the real evaluated grass meshes, all 3277 original instance records, four Terrain3D regions, source burial offsets, layer/distribution source isolation, and all 16 corner/cardinal orbit poses. The camera helper clamps outside terrain queries; plantable-area queries remain disallowed outside the source.
- Headless RenderingServer Dummy does not retain MultiMesh transforms for `get_instance_transform`. The headless root-height test therefore checks the exact `source_poses` cache supplied to the publisher. Actual rendered MultiMesh transforms and visual output are covered separately by the native Metal probe; this report does not substitute for it.
- Source, plugin and patched-file hashes pass; production saves/preferences remain byte-identical. The pinned Terrain3D API emits a deprecated physics interpolation warning; this run has no script error, resource/Node/RID leak, or failed assertion.
- No frame time, FPS, RSS or capacity gate is run. Similarity to the official Valley image still requires visual review.
