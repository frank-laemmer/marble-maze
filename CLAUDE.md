# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marble Maze is a 3D marble maze game built with **Godot 4.6** (Forward Plus rendering) and **Jolt Physics**. The primary scripting language is GDScript. All UI is built entirely in code — there are no `.tscn` files for UI scenes; everything is constructed procedurally in `_build_ui()` and similar methods.

## Common Commands

**Run the game:** Open `project.godot` in Godot 4.6 and press Play. Entry point is `res://scenes/ui/splash_screen.tscn`.

**Test in-editor:** Use the "Test" button inside the level editor scene.

**Generate the app icon PNG:** Open and run `scenes/icon_render.tscn` in Godot (F6). It exports to `res://icon.png` and quits automatically.

**Trigger a release:** Push a version tag — GitHub Actions handles all exports, publishing, and version patching automatically.
```bash
git tag v0.6.3 && git push origin v0.6.3
```

There are no lint or automated test commands.

## Architecture

### Global Singletons (Autoloads)

- **`GameState`** (`scripts/game_state.gd`) — Cross-scene state: `level_path`, `from_editor`, `editor_level_content`, `entry_mode`, `level_title`, `level_timer`. Also owns progress persistence (`user://progress.cfg`) and touch/settings persistence (`user://settings.cfg`). `FEATURE_KEYS_DOORS` flag gates the keys/doors system.
- **`LevelLoader`** (`scripts/level_loader.gd`) — Parses the text maze format and builds the full 3D scene graph at runtime (StaticBody3D + CollisionShape3D + MeshInstance3D per tile). Exposes `grid`, `start_cell`, `goal_cell` for the minimap, and `level_tilt_x`/`level_tilt_z` for level rotation. Also owns `peek_metadata()` to read headers before geometry is built.

### Scene Flow

```
splash_screen.tscn  → game.tscn  (via GameState.level_path)
                    → level_editor.tscn
```

`game.tscn` contains `marble.tscn` and a `LevelManager` node. The level geometry is added at runtime by `game.gd` calling `LevelLoader.build_from_file()` or `build_from_string()`. After the level node is added, `game.gd` applies `level.rotation_degrees.x/z` from `LevelLoader.level_tilt_x/z`.

### Level Text Format

Levels are `.txt` files in `res://levels/` (built-in) or `user://levels/` (custom). Metadata lines use `!` prefix:

```
!name=My Level
!timer=120
!tilt=15,-10
!marble=dice
```

`!tilt=x,z` rotates the entire level node (degrees). Positive X tilts the +Z edge downward; positive Z tilts the -X edge downward. Single-value `!tilt=N` is also accepted (tilt_z defaults to 0).

`!marble=` accepts `sphere` (default), `dice`, or `pyramid`. The value is stored in `LevelLoader.level_marble_type` and exposed as a chooser in the level editor toolbar, but gameplay behaviour for non-sphere types is not yet implemented.

Tile characters: `S` start, `G` goal, `#` wall, `.` floor, `_` empty (falls), `I` invisible wall, `F` fake wall, `K/J/X` keys (yellow/green/red), `D/E/R` doors, `V` invisible floor. Spaces between tiles are stripped for readability.

Level progression is sequential — completing level N unlocks level N+1. `GameState.is_level_unlocked()` enforces this.

### Marble Physics

`marble.gd` (RigidBody3D) applies forces via `apply_central_force()` each physics frame. Key constants: `FORCE=38.0`, `MAX_SPEED=22.0`, gravity scale `2.5×`. Coyote time (5 frames) and jump buffering (12 frames) are implemented manually. Wall-climbing is an intentional emergent mechanic.

On tilted levels the marble experiences an uphill force penalty: `_uphill_force_mult()` computes the downhill direction from `LevelLoader.level_tilt_x/z` and scales input force down when the player pushes uphill, also suppressing the `COUNTER_STEER_MULT` bonus in that direction. Tune with `UPHILL_PENALTY` (currently `1.7`).

### Splash Screen / UI

`splash_screen.gd` builds the entire main menu procedurally. The `_build_doc_panel()` method renders `.md` files from `res://content/` as in-game overlays — `about.md` and `how_to_play.md`. The markdown renderer supports `#`/`##` headings, `---` separators, and `[text](url)` links (converted to BBCode). **All `.md` files must be included in export presets** (`include_filter="*.txt, *.md"`).

### CI / Release

Two GitHub Actions workflows:
- **`release.yml`** — triggered on version tags; strips the `v` prefix from the tag and patches `application/short_version` and `application/version` in `export_presets.cfg` before export, so the macOS bundle version always matches the tag. Exports all 4 platforms in `barichello/godot-ci:4.6` container, creates a GitHub Release, then a second job pushes to itch.io via `josephbmanley/butler-publish-itchio-action`.
- **`pages.yml`** — triggered on push to `main`; exports a web build and deploys to `gh-pages` → `https://frank-laemmer.github.io/marble-maze/`.

The `godot-ci` container blocks outbound network — Butler and GitHub Pages deployment must run in a separate job without a container.
