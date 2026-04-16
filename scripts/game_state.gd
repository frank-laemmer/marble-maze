extends Node

## Shared state passed between scenes.

## Feature flags — set to true to re-enable work-in-progress features.
const FEATURE_KEYS_DOORS := false

## Path to the level file to load when entering game.tscn
var level_path: String = "res://levels/level_01.txt"

## True when the game was launched from the level editor (test mode)
var from_editor: bool = false

## Level content string set by the editor when testing a level.
## Persists across reloads so retry (R on fail) reloads the same content.
var editor_level_content: String = ""

## File basename (no extension) of the level being tested from the editor.
var editor_level_name: String = ""

## Time limit (seconds) for the current level, set after the level is parsed.
var level_timer: float = 180.0

## Whether the next game load should start in level-entry (preview) mode.
var entry_mode: bool = false

## Display title of the current level (from !name= metadata).
var level_title: String = ""

## Basenames of built-in levels the player has completed (e.g. "level_01").
var completed_levels: Array[String] = []

func _ready() -> void:
	_load_progress()
	_load_settings()

# ── Progress helpers ───────────────────────────────────────────────────────────

## Mark a built-in level complete and persist to disk.
func mark_complete(path: String) -> void:
	if not path.begins_with("res://levels/"):
		return
	var base := path.get_file().get_basename()
	if base not in completed_levels:
		completed_levels.append(base)
	_save_progress()

## True if the level at path is available to play.
## Custom (user://) levels are always unlocked.
## Built-in level N requires level N-1 to be completed.
func is_level_unlocked(path: String) -> bool:
	if not path.begins_with("res://levels/"):
		return true
	var files := _list_builtin_levels()
	var idx := files.find(path.get_file())
	if idx <= 0:
		return true  # first level or not found — always open
	return files[idx - 1].get_basename() in completed_levels

## Returns the path of the next built-in level after current_path, or "".
func next_builtin_level(current_path: String) -> String:
	if not current_path.begins_with("res://levels/"):
		return ""
	var files := _list_builtin_levels()
	var idx := files.find(current_path.get_file())
	if idx == -1 or idx >= files.size() - 1:
		return ""
	return "res://levels/" + files[idx + 1]

func _list_builtin_levels() -> Array[String]:
	var files: Array[String] = []
	var d := DirAccess.open("res://levels/")
	if not d:
		return files
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if fn.ends_with(".txt"):
			files.append(fn)
		fn = d.get_next()
	files.sort()
	return files

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "completed", completed_levels)
	cfg.save("user://progress.cfg")

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		completed_levels = cfg.get_value("progress", "completed", [])

## Wipe all level completion data and persist the change.
func reset_progress() -> void:
	completed_levels.clear()
	_save_progress()

# ── Touch control settings ─────────────────────────────────────────────────────

## True when the player has manually enabled touch controls.
## Touch controls are also auto-enabled on devices that report a touchscreen.
var touch_enabled: bool = false

## When true, the joystick is placed on the right side (for left-handed players).
var touch_left_handed: bool = false

## Returns true if touch controls should be shown (auto-detected or manually on).
func is_touch_active() -> bool:
	return touch_enabled \
		or DisplayServer.is_touchscreen_available() \
		or OS.has_feature("mobile") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("touch", "enabled",      touch_enabled)
	cfg.set_value("touch", "left_handed",  touch_left_handed)
	cfg.save("user://settings.cfg")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		touch_enabled     = cfg.get_value("touch", "enabled",     false)
		touch_left_handed = cfg.get_value("touch", "left_handed", false)
