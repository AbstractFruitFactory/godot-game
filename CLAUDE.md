# Cozy Game

Co-op roguelike dungeon crawler, fantasy aesthetic, angled top-down camera. Rooms get harder; progression is gear found during a run.

Godot 4.5+, GDScript with static typing, Forward+ renderer. Low-poly, low-res textures, Valheim-style lighting.

## Rules
- Godot 4 APIs only. Never Godot 3 (`KinematicBody`, `yield`, `export var`, `onready var`, etc.).
- Keep `.tscn` files small; build complex node trees in code. Tunable values go in `@export` vars.
- Input actions are registered in code (`main.gd` `_setup_input`), not in project.godot.
- Multiplayer: ENet, host is peer 1. Players are spawned by the host via `MultiplayerSpawner`; each player owns its own movement (set authority in `_enter_tree`, never `_ready`). Future shared game state (enemies, damage, loot) must be host-authoritative.
- Low-res textures: set `texture_filter = TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` on materials.
- Make small changes and commit after each working step.

## Verify your changes
- Check for errors: `godot --headless --path . --quit` (read the output, fix all errors/warnings).
- See the game: `godot --path . -- --host --screenshot` renders ~180 frames, saves `screenshots/latest.png`, then quits.
- Co-op test: start `godot --path . -- --host` (with a timeout), then `godot --path . -- --join --screenshot=client` to see the second player's view. Look at the image after visual changes. F12 does the same during play.
