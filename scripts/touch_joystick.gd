extends Control

## On-screen marble joystick for touch input.
## Spawned into a CanvasLayer by game.gd when touch is active.
##
## API (called by marble.gd each physics frame):
##   get_stick_vector()  -> Vector2   (x = strafe, y = forward) magnitude 0–1
##   get_camera_delta()  -> Vector2   (x = yaw Δ rad, y = pitch Δ rad) — resets on read
##   consume_jump()      -> bool      true once after a tap on the knob

const OUTER_RADIUS := 90.0    ## outer ring radius, pixels
const KNOB_RADIUS  := 38.0    ## inner marble knob radius
const DEAD_ZONE    := 12.0    ## pixels near centre that read as zero
const MARGIN       := 40.0    ## distance from screen edges

const CAM_SWIPE_SENSITIVITY := 0.004  ## radians per pixel for camera swipe

const TAP_MAX_MS   := 300    ## max milliseconds for a joystick tap (→ jump)
const TAP_MAX_MOVE := 20.0   ## max pixel travel to still count as a tap

var _stick_origin: Vector2          ## joystick ring centre (screen coords)
var _knob_pos:     Vector2          ## current knob position
var _stick_vector: Vector2 = Vector2.ZERO   ## (x=strafe, y=fwd) clamped −1..1
var _camera_delta: Vector2 = Vector2.ZERO   ## accumulated camera rotation (radians)

var _stick_touch_id:  int = -1      ## touch index controlling the joystick
var _camera_touch_id: int = -1      ## touch index controlling the camera swipe

var _jump_pending:  bool = false
var _tap_start_ms:  int  = 0
var _tap_start_pos: Vector2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group("touch_joystick")
	_update_origin()
	# On web the canvas may report size (0,0) during _ready(); re-run once
	# the node is fully laid out so the joystick lands in the right corner.
	call_deferred("_update_origin")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_origin()
		queue_redraw()


func _update_origin() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var sz := vp.get_visible_rect().size
	if GameState.touch_left_handed:
		_stick_origin = Vector2(sz.x - MARGIN - OUTER_RADIUS, sz.y - MARGIN - OUTER_RADIUS)
	else:
		_stick_origin = Vector2(MARGIN + OUTER_RADIUS, sz.y - MARGIN - OUTER_RADIUS)
	if _stick_touch_id == -1:
		_knob_pos = _stick_origin


# ── Public API ─────────────────────────────────────────────────────────────────

## Stick direction and magnitude: (x = strafe right, y = push forward).
## Dragging the knob upward returns positive y (forward).
func get_stick_vector() -> Vector2:
	return _stick_vector


## Accumulated camera-swipe delta in radians since last call.  Resets on read.
## x = yaw (swipe right → positive), y = pitch (swipe down → positive).
func get_camera_delta() -> Vector2:
	var d := _camera_delta
	_camera_delta = Vector2.ZERO
	return d


## Returns true once after a tap on the joystick, then clears the flag.
func consume_jump() -> bool:
	if _jump_pending:
		_jump_pending = false
		return true
	return false


# ── Touch input ────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _stick_touch_id == -1 and \
				event.position.distance_to(_stick_origin) <= OUTER_RADIUS * 1.4:
			_stick_touch_id = event.index
			_tap_start_ms   = Time.get_ticks_msec()
			_tap_start_pos  = event.position
			_knob_pos       = event.position
			_update_stick()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif _camera_touch_id == -1:
			_camera_touch_id = event.index
	else:
		if event.index == _stick_touch_id:
			var elapsed := Time.get_ticks_msec() - _tap_start_ms
			var moved   := event.position.distance_to(_tap_start_pos)
			if elapsed <= TAP_MAX_MS and moved <= TAP_MAX_MOVE:
				_jump_pending = true
			_stick_touch_id = -1
			_knob_pos       = _stick_origin
			_stick_vector   = Vector2.ZERO
			queue_redraw()
		elif event.index == _camera_touch_id:
			_camera_touch_id = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_touch_id:
		_knob_pos = event.position
		_update_stick()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _camera_touch_id:
		_camera_delta.x += event.relative.x * CAM_SWIPE_SENSITIVITY
		_camera_delta.y += event.relative.y * CAM_SWIPE_SENSITIVITY


func _update_stick() -> void:
	var delta    := _knob_pos - _stick_origin
	var dist     := delta.length()
	var max_dist := OUTER_RADIUS - KNOB_RADIUS

	if dist > max_dist:
		_knob_pos = _stick_origin + delta.normalized() * max_dist
		delta     = _knob_pos - _stick_origin
		dist      = max_dist

	if dist < DEAD_ZONE:
		_stick_vector = Vector2.ZERO
		return

	var mag := (dist - DEAD_ZONE) / (max_dist - DEAD_ZONE)
	var dir := delta.normalized()
	# Invert Y: screen-Y grows downward, but dragging up should mean "forward".
	_stick_vector = Vector2(dir.x, -dir.y) * clampf(mag, 0.0, 1.0)


# ── Drawing — marble-style joystick ───────────────────────────────────────────

func _draw() -> void:
	_draw_outer_ring()
	_draw_knob(_knob_pos)


func _draw_outer_ring() -> void:
	var c := _stick_origin
	# Faint filled background
	draw_circle(c, OUTER_RADIUS, Color(0.10, 0.07, 0.22, 0.28))
	# Subtle crosshair guide lines
	var arm := OUTER_RADIUS * 0.80
	draw_line(c + Vector2(-arm, 0.0), c + Vector2(arm, 0.0),
			Color(0.40, 0.35, 0.72, 0.18), 1.0)
	draw_line(c + Vector2(0.0, -arm), c + Vector2(0.0, arm),
			Color(0.40, 0.35, 0.72, 0.18), 1.0)
	# Outer ring border
	draw_arc(c, OUTER_RADIUS, 0.0, TAU, 64, Color(0.50, 0.44, 0.88, 0.55), 1.8)
	# Rest-position centre dot
	draw_circle(c, 4.0, Color(0.55, 0.50, 0.92, 0.42))


func _draw_knob(pos: Vector2) -> void:
	var r := KNOB_RADIUS
	# Drop shadow
	draw_circle(pos + Vector2(2.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.30))
	# Base marble body — deep indigo/purple
	draw_circle(pos, r, Color(0.12, 0.08, 0.30, 0.92))
	# Internal mid-tone (slight offset simulates refraction depth)
	draw_circle(pos + Vector2(-r * 0.18, -r * 0.10), r * 0.80,
			Color(0.20, 0.14, 0.50, 0.58))
	# Teal internal glow band (characteristic marble swirl colour)
	draw_circle(pos + Vector2(r * 0.20, r * 0.18), r * 0.50,
			Color(0.04, 0.28, 0.38, 0.38))
	# Primary highlight blob (top-left, glassy reflection)
	draw_circle(pos + Vector2(-r * 0.28, -r * 0.32), r * 0.40,
			Color(0.62, 0.55, 0.95, 0.65))
	# Bright secondary sparkle
	draw_circle(pos + Vector2(-r * 0.44, -r * 0.46), r * 0.16,
			Color(0.92, 0.90, 1.00, 0.88))
	# Knob outline ring
	draw_arc(pos, r, 0.0, TAU, 48, Color(0.70, 0.62, 1.00, 0.75), 1.5)
