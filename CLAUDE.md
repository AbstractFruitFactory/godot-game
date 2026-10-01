# Cozy Game

Godot 4.5+, GDScript with static typing, Forward+ renderer. Low-poly, low-res textures, Valheim-style lighting.

## Rules
- Godot 4 APIs only. Never Godot 3 (`KinematicBody`, `yield`, `export var`, `onready var`, etc.).
- Keep `.tscn` files small; build complex node trees in code. Tunable values go in `@export` vars.
- Input actions are registered in code (`main.gd` `KEYS`), not in project.godot.
- Low-res textures: set `texture_filter = TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` on materials.
- Make small changes and commit after each working step.

## Verify your changes
- Check for errors: `godot --headless --path . --quit` (read the output, fix all errors/warnings).
- See the game: `godot --path . -- --screenshot` renders ~60 frames, saves `screenshots/latest.png`, then quits. Look at the image after visual changes. F12 does the same during play.
