extends Node

enum State { PLAYING, FAIL, ENTRY }

var state: State = State.PLAYING
var time_remaining: float = 180.0
var next_level: String = ""
var entry_countdown: float = 3.0
var keys_held: Dictionary = {"yellow": 0, "green": 0, "red": 0}

const ENTRY_DELAY: float = 3.0

signal time_changed(t: float)
signal state_changed(s: State)
signal entry_countdown_changed(t: float)
signal keys_changed(counts: Dictionary)

@onready var marble: RigidBody3D = $"../Marble"

var _start_pos: Vector3
var _start_rot: Quaternion

func _ready() -> void:
	time_remaining = GameState.level_timer
	if GameState.entry_mode:
		GameState.entry_mode = false
		call_deferred("_enter_entry_mode")
	else:
		call_deferred("_setup_connections")

func _enter_entry_mode() -> void:
	state = State.ENTRY
	entry_countdown = ENTRY_DELAY
	marble.freeze = true
	marble.entry_mode = true
	marble.begin_flyover(ENTRY_DELAY)
	_setup_connections()
	state_changed.emit(State.ENTRY)
	time_changed.emit(time_remaining)

func _setup_connections() -> void:
	# marble.global_position is already set by game.gd before this deferred call
	_start_pos = marble.global_position
	_start_rot  = marble.quaternion

	for goal in get_tree().get_nodes_in_group("goal_zone"):
		goal.reached.connect(_on_goal_reached)

	var death := get_tree().get_first_node_in_group("death_zone")
	if death:
		death.body_entered.connect(_on_death_zone)

	if marble.has_signal("glass_shattered"):
		marble.glass_shattered.connect(func():
			_respawn()
			marble.restore_glass()
		)

	if GameState.FEATURE_KEYS_DOORS:
		for key in get_tree().get_nodes_in_group("key_item"):
			key.key_collected.connect(_on_key_collected)
		for door in get_tree().get_nodes_in_group("door"):
			door.marble_touched.connect(_on_door_touched.bind(door))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/splash_screen.tscn")
	# Touch: tap anywhere to skip the entry countdown or retry after fail.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if state == State.ENTRY:
			_start_playing()
		elif state == State.FAIL:
			get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if state == State.ENTRY:
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("restart"):
			_start_playing()
			return
		entry_countdown -= delta
		entry_countdown_changed.emit(entry_countdown)
		if entry_countdown <= 0.0:
			_start_playing()
		return

	if state == State.FAIL:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	time_remaining -= delta
	time_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		_set_state(State.FAIL)

func _start_playing() -> void:
	state = State.PLAYING
	marble.freeze = false
	marble.entry_mode = false
	marble.end_flyover()
	state_changed.emit(State.PLAYING)

func _go_next_or_back() -> void:
	if next_level != "":
		GameState.level_path = next_level
		GameState.entry_mode = true
		GameState.editor_level_content = ""
		GameState.from_editor = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	elif GameState.from_editor:
		get_tree().change_scene_to_file("res://scenes/ui/level_editor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/splash_screen.tscn")

func _on_goal_reached() -> void:
	if not GameState.from_editor:
		GameState.mark_complete(GameState.level_path)
		next_level = GameState.next_builtin_level(GameState.level_path)
	marble.freeze = true
	call_deferred("_go_next_or_back")

func _on_key_collected(color: String) -> void:
	keys_held[color] += 1
	keys_changed.emit(keys_held.duplicate())

func _on_door_touched(door: Node) -> void:
	var c: String = door.color if "color" in door else "yellow"
	if keys_held.get(c, 0) > 0:
		keys_held[c] -= 1
		keys_changed.emit(keys_held.duplicate())
		door.open()

func _on_death_zone(body: Node3D) -> void:
	if body == marble:
		_respawn()

func _respawn() -> void:
	marble.linear_velocity  = Vector3.ZERO
	marble.angular_velocity = Vector3.ZERO
	marble.global_position  = _start_pos
	marble.quaternion       = _start_rot

func _set_state(s: State) -> void:
	state = s
	marble.freeze = true
	state_changed.emit(s)
