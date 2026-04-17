extends Node3D

## Game scene script — dynamically loads the level selected from the
## splash screen or the level editor test, then positions the marble.

@onready var marble: RigidBody3D = $Marble

func _enter_tree() -> void:
	# Parse metadata BEFORE children's _ready() runs so LevelManager picks up
	# the correct timer and title from GameState (not the default 180 s).
	var content: String = ""
	if GameState.editor_level_content != "":
		content = GameState.editor_level_content
	else:
		var path := GameState.level_path
		if path.is_empty():
			path = "res://levels/level_01.txt"
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			content = f.get_as_text()
			f.close()
	if not content.is_empty():
		LevelLoader.peek_metadata(content)
		GameState.level_timer = float(LevelLoader.level_time)
		GameState.level_title = LevelLoader.level_name

func _ready() -> void:
	var level: Node3D

	if GameState.editor_level_content != "":
		# Editor test: build from the in-memory level string.
		# Do NOT clear it here — level_manager may reload the scene on fail,
		# and the editor needs it when the player returns.
		level = LevelLoader.build_from_string(GameState.editor_level_content)
	else:
		var path := GameState.level_path
		if path.is_empty():
			path = "res://levels/level_01.txt"
		level = LevelLoader.build_from_file(path)

	# Re-sync after full build (build_from_* re-parses; values should match).
	GameState.level_timer = float(LevelLoader.level_time)
	GameState.level_title = LevelLoader.level_name

	if level:
		add_child(level)
		move_child(level, 0)   # Level before Marble so groups are found first
		level.rotation_degrees.x = LevelLoader.level_tilt_x
		level.rotation_degrees.z = LevelLoader.level_tilt_z

	# Place marble at the start marker (groups populated during add_child above)
	var sm := get_tree().get_first_node_in_group("start_marker")
	if sm:
		marble.global_position = sm.global_position
		marble.linear_velocity  = Vector3.ZERO
		marble.angular_velocity = Vector3.ZERO

	# Spawn touch joystick overlay when touch controls are active.
	# Pass the reference directly to marble — avoids deferred-lookup timing
	# issues that can cause _touch_input to remain null on web exports.
	if GameState.is_touch_active():
		var canvas := CanvasLayer.new()
		canvas.layer = 10
		add_child(canvas)
		var joystick: Control = load("res://scripts/touch_joystick.gd").new()
		canvas.add_child(joystick)
		marble.set_touch_input(joystick)
