# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marble Maze is a 3D marble maze game built with **Godot 4.6** (Forward Plus rendering) and **Jolt Physics**. The primary scripting language is GDScript.

## Common Commands

**Generate a level TSCN from `maze_layout.txt`:**
```bash
python3 build_level.py
```
Output: `scenes/levels/level_01.tscn`

**Run the game:** Open `project.godot` in Godot 4.6 and press Play. Entry point is `res://scenes/ui/splash_screen.tscn`.

There are no lint or automated test commands — Godot's built-in debugger and the in-game "Test" button in the level editor are the primary verification tools.

## Architecture

### Global Singletons (Autoloads)

- **`GameState`** (`scripts/game_state.gd`) — Shared cross-scene state: current `level_path`, `editor_level_content` (in-memory level string), and `from_editor` flag.
- **`LevelLoader`** (`scripts/level_loader.gd`) — Runtime level builder that parses text maze format and generates 3D geometry (StaticBody3D, CollisionShape3D, MeshInstance3D) procedurally. Supports both file paths and raw strings.

### Scene Hierarchy

```
splash_screen.tscn  ← Main menu entry point
game.tscn           ← Gameplay scene
  ├── marble.tscn   ← RigidBody3D player marble
  ├── (level)       ← Loaded at runtime by LevelLoader
  ├── hud.tscn      ← Timer and win/fail overlays
  └── LevelManager  ← State machine (PLAYING / WIN / FAIL)
level_editor.tscn   ← In-game grid editor
```

### Level System

Levels are stored as plain text grids. Character legend:
- `S` — start position
- `G` — goal position
- `#` — wall block (4 units tall)
- `.` — floor tile
- `_` or space — empty (marble falls)

Built-in levels live in `res://levels/`; user-created levels go to `user://levels/`.

`build_level.py` converts `maze_layout.txt` into a `.tscn` file. The in-game editor saves directly to `user://levels/` and passes content through `GameState.editor_level_content` for test-play.

### Game Loop

`level_manager.gd` drives the 180-second countdown and transitions:
- Marble enters goal zone → WIN
- Marble enters death zone → respawn at `StartMarker`
- Timer expires → FAIL

`marble.gd` (RigidBody3D) handles WASD/gamepad input and applies forces each physics frame. Key constants: `FORCE=38.0`, `MAX_SPEED=22.0`, `BRAKE_DECEL=36.0`, gravity scale 2.5×.

### Level Editor

`level_editor.gd` manages a 2D grid (3×3 to 50×50). `grid_canvas.gd` handles mouse-driven tile painting and renders the grid via Godot's `_draw()` system. The "Test" button copies grid content into `GameState.editor_level_content` and loads the game scene.
