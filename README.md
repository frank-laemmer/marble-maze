# Marble Maze

A 3D marble maze game built with Godot 4.6. Guide your marble through increasingly tricky mazes before the timer runs out.

Play it on [itch.io](https://franktheprank.itch.io/marble-maze).

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Jump | Space | A / Cross |
| Rotate camera | Arrow keys | Right stick |

Touch controls are supported on mobile.

## Features

- 14 levels with a built-in level editor to create your own
- Minimap
- 180-second countdown per level

## Building

Open `project.godot` in Godot 4.6 and press Play.

To export a release, push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build and publish all platforms (Web, Windows, Linux, macOS) automatically.

## License

This work is licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/). See `LICENSE` for details.
