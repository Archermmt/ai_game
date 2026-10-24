# ai_game

A Godot game project collection, expanded from the original “ai_game test for godot” into a monorepo of self-contained games and tutorials. Each game lives in its own directory and keeps its own `project.godot`; open the game directory in Godot to edit or run it.

## Projects

### Tiny Glade

A cozy, free-form building game prototype with an illustrated forest garden, editable cottages, seasonal lighting, weather, and first-person wandering.

- Project: [`tiny_glade/`](tiny_glade/)
- Open `tiny_glade/project.godot` in Godot 4.7 or newer.
- Development status and weekly evidence: [`tiny_glade/STATUS.md`](tiny_glade/STATUS.md)
- Product requirements: [`tiny_glade/docs/PRD_风栖小筑.md`](tiny_glade/docs/PRD_风栖小筑.md)

## Adding another game

Add a new top-level directory containing that game's `project.godot`, source, assets, documentation, and tests. The monorepo is the Git boundary; do not nest another `.git` repository inside a game directory. Add a short entry to this README when the project is ready to share.
