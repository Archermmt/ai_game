# Development contract

- Read `STATUS.md`, the approved PRD, and `docs/DEV_PLAN_MVP_Godot.md` before changing scope.
- Use feature folders, typed GDScript, snake_case files and PascalCase nodes.
- Keep source state separate from generated meshes. Runtime edits go through transactions.
- Every development week must have automated regression tests, a repeatable validation command,
  and an evidence report in `docs/weekly/week_XX/`.
- Run `python3 tools/quality/run_checks.py --week 4 --negative-control` for cumulative W01–W04 regressions; extend gates for later weeks.
  A failing assertion, an empty test run, or a Godot script error must fail the command.
- Update `STATUS.md` with completed tasks, test counts, commands, evidence and remaining gates.
  Never mark a Windows real-device gate passed from a macOS export or headless run.
- Commit reviewable milestones to Git. Do not commit caches, downloaded runtimes, exports,
  credentials, hardware serial numbers or user save files.
- Preserve source `.blend` files and import settings; pin tool and plugin versions.
- No P1/P2 features without an explicit scope change. Do not overwrite the approved PRD.

- After changing Blender generators or sources, run `tools/art/audit_sources.py` in Blender
  with `--root` and `--output`; reopen source files and retain the report, not just GLB checks.
