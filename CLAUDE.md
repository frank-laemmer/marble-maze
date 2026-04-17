# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marble Maze is a 3D marble maze game built with **Godot 4.6** (Forward Plus rendering) and **Jolt Physics**. The primary scripting language is GDScript. All UI is built entirely in code — there are no `.tscn` files for UI scenes; everything is constructed procedurally in `_build_ui()` and similar methods.

## Common Commands

**Run the game:** Open `project.godot` in Godot 4.6 and press Play. Entry point is `res://scenes/ui/splash_screen.tscn`.

**Test in-editor:** Use the "Test" button inside the level editor scene.

**Generate the app icon PNG:** Open and run `scenes/icon_render.tscn` in Godot (F6). It exports to `res://icon.png` and quits automatically.

**Trigger a release:** Push a version tag — GitHub Actions handles all exports and publishing.
```bash
git tag v1.0.0 && git push origin v1.0.0
```

There are no lint or automated test commands.

## Architecture

### Global Singletons (Autoloads)

- **`GameState`** (`scripts/game_state.gd`) — Cross-scene state: `level_path`, `from_editor`, `editor_level_content`, `entry_mode`, `level_title`, `level_timer`. Also owns progress persistence (`user://progress.cfg`) and touch/settings persistence (`user://settings.cfg`). `FEATURE_KEYS_DOORS` flag gates the keys/doors system.
- **`LevelLoader`** (`scripts/level_loader.gd`) — Parses the text maze format and builds the full 3D scene graph at runtime (StaticBody3D + CollisionShape3D + MeshInstance3D per tile). Exposes `grid`, `start_cell`, `goal_cell` for the minimap. Also owns `peek_metadata()` to read `!name=` / `!time=` headers before geometry is built.

### Scene Flow

```
splash_screen.tscn  → game.tscn  (via GameState.level_path)
                    → level_editor.tscn
```

`game.tscn` contains `marble.tscn` and a `LevelManager` node. The level geometry is added at runtime by `game.gd` calling `LevelLoader.build_from_file()` or `build_from_string()`.

### Level Text Format

Levels are `.txt` files in `res://levels/` (built-in) or `user://levels/` (custom). Metadata lines use `!` prefix:

```
!name=My Level
!time=120
```

Tile characters: `S` start, `G` goal, `#` wall, `.` floor, `_` empty (falls), `I` invisible wall, `F` fake wall, `K/J/X` keys (yellow/green/red), `D/E/R` doors, `V` invisible floor. Spaces between tiles are stripped for readability.

Level progression is sequential — completing level N unlocks level N+1. `GameState.is_level_unlocked()` enforces this.

### Marble Physics

`marble.gd` (RigidBody3D) applies forces via `apply_central_force()` each physics frame. Key constants: `FORCE=38.0`, `MAX_SPEED=22.0`, gravity scale `2.5×`. Coyote time (5 frames) and jump buffering (12 frames) are implemented manually. Wall-climbing is an intentional emergent mechanic.

### Splash Screen / UI

`splash_screen.gd` builds the entire main menu procedurally. The `_build_doc_panel()` method renders `.md` files from `res://content/` as in-game overlays — `about.md` and `how_to_play.md`. The markdown renderer supports `#`/`##` headings, `---` separators, and `[text](url)` links (converted to BBCode). **All `.md` files must be included in export presets** (`include_filter="*.txt, *.md"`).

### CI / Release

Two GitHub Actions workflows:
- **`release.yml`** — triggered on version tags; exports all 4 platforms in `barichello/godot-ci:4.6` container, creates GitHub Release, then a second job (plain `ubuntu-latest`) pushes to itch.io via `josephbmanley/butler-publish-itchio-action`.
- **`pages.yml`** — triggered on push to `main`; exports web build and deploys to `gh-pages` branch → `https://frank-laemmer.github.io/marble-maze/`.

The `godot-ci` container blocks outbound network — Butler and GitHub Pages deployment must run in a separate job without a container.
