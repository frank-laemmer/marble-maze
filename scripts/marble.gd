extends RigidBody3D

const FORCE: float = 38.0
const MAX_SPEED: float = 22.0
const JUMP_IMPULSE: float = 10.0
const COUNTER_STEER_MULT: float = 2.5  # force boost when input opposes current velocity

const JUMP_BUFFER_FRAMES: int = 12  # frames a buffered jump input stays valid
const COYOTE_FRAMES: int = 5        # frames after leaving ground where jump still works

const CAM_ROTATE_SPEED: float = 2.2    # radians/s — yaw
const CAM_PITCH_SPEED: float = 1.0     # radians/s — pitch
const CAM_PITCH_MIN: float = -1.4      # steepest (most overhead)
const CAM_PITCH_MAX: float = -0.3      # shallowest (most side-on)

# ── Flyover (entry countdown camera animation) ─────────────────────────────────
const FLYOVER_SPRING_START: float = 72.0   ## pull-out distance at the start
const FLYOVER_PITCH_START:  float = -1.4   ## fully overhead at start
const FLYOVER_YAW_OFFSET:   float = 1.2    ## radians swept during flyover

@onready var cam_pivot:  Node3D       = $CamPivot
@onready var spring_arm: SpringArm3D  = $CamPivot/SpringArm3D
@onready var _camera:    Camera3D     = $CamPivot/SpringArm3D/Camera3D
@onready var _mesh:      MeshInstance3D = $MeshInstance3D

var _cam_yaw: float = 0.0
var _cam_pitch: float = -1.0
var _ground_ray: RayCast3D
var _jump_buffered: bool = false
var _jump_buffer_frames: int = 0
var _coyote_frames: int = 0
var _was_grounded: bool = false
var _air_flat_vel: Vector3 = Vector3.ZERO  # horizontal velocity while airborne

## Set by level_manager during level-entry (preview) mode.
## Camera rotation still works; movement and jumping are suppressed.
var entry_mode: bool = false

## Touch joystick node — set by game.gd after it is added to the tree.
var _touch_input = null

# Flyover state
var _flyover_active:   bool  = false
var _flyover_elapsed:  float = 0.0
var _flyover_duration: float = 3.0
var _flyover_yaw_target: float = 0.0   # yaw to land on at the end
var _spring_length_play: float = 13.0  # read from scene in _ready


func _ready() -> void:
	add_to_group("marble")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.collision_mask = 0
	gravity_scale = 2.5

	_spring_length_play = spring_arm.spring_length

	var mat := PhysicsMaterial.new()
	mat.bounce   = 0.22
	mat.friction = 0.8
	physics_material_override = mat

	var marble_mat := ShaderMaterial.new()
	marble_mat.shader = preload("res://shaders/marble.gdshader")
	_mesh.material_override = marble_mat

	_ground_ray = RayCast3D.new()
	_ground_ray.target_position = Vector3(0.0, -1.3, 0.0)
	add_child(_ground_ray)

	# Shift the view so the marble sits in the lower-left area of the screen,
	# clear of the minimap in the top-right corner.
	_camera.h_offset = 4.0
	_camera.v_offset = 1.5

	_apply_cam_rotation()


## Called by game.gd after the touch joystick node has been added to the tree.
func set_touch_input(node) -> void:
	_touch_input = node


## Called by level_manager when the entry countdown begins.
## Kicks the camera to a high pull-out position and animates it in.
func begin_flyover(duration: float) -> void:
	_flyover_duration  = duration
	_flyover_elapsed   = 0.0
	_flyover_active    = true
	_flyover_yaw_target = _cam_yaw
	# Snap camera to the start-of-flyover position immediately
	_cam_pitch              = FLYOVER_PITCH_START
	_cam_yaw                = _flyover_yaw_target + FLYOVER_YAW_OFFSET
	spring_arm.spring_length = FLYOVER_SPRING_START
	_apply_cam_rotation()


## Called by level_manager when play begins (either countdown finished or skipped).
## Snaps the camera to play position if the flyover is still mid-animation.
func end_flyover() -> void:
	if not _flyover_active:
		return
	_flyover_active          = false
	_cam_pitch               = -1.0
	_cam_yaw                 = _flyover_yaw_target
	spring_arm.spring_length = _spring_length_play
	_apply_cam_rotation()


func _input(event: InputEvent) -> void:
	if entry_mode:
		return
	if event.is_action_pressed("jump"):
		_jump_buffered = true
		_jump_buffer_frames = JUMP_BUFFER_FRAMES


func _process(_delta: float) -> void:
	cam_pivot.global_position = global_position
	_apply_cam_rotation()


func _physics_process(delta: float) -> void:
	# ── Flyover animation (runs during entry countdown) ────────────────────────
	if _flyover_active:
		_flyover_elapsed += delta
		var t := clampf(_flyover_elapsed / _flyover_duration, 0.0, 1.0)
		# Cubic ease-out: fast zoom in, glides smoothly to rest
		var e := 1.0 - pow(1.0 - t, 3.0)
		_cam_pitch               = lerpf(FLYOVER_PITCH_START,    -1.0,                 e)
		_cam_yaw                 = lerpf(_flyover_yaw_target + FLYOVER_YAW_OFFSET,
										 _flyover_yaw_target,                          e)
		spring_arm.spring_length = lerpf(FLYOVER_SPRING_START,   _spring_length_play,  e)
		if t >= 1.0:
			_flyover_active = false
		# Drain any accumulated touch-swipe delta so it doesn't teleport the
		# camera the moment the flyover ends.
		if _touch_input:
			_touch_input.get_camera_delta()
		if entry_mode:
			return
	else:
		# ── Camera yaw/pitch — manual control ─────────────────────────────────
		var cam_turn := Input.get_axis("cam_left", "cam_right")
		_cam_yaw += cam_turn * CAM_ROTATE_SPEED * delta

		var cam_pitch_in := Input.get_axis("cam_up", "cam_down")
		_cam_pitch = clampf(_cam_pitch - cam_pitch_in * CAM_PITCH_SPEED * delta,
				CAM_PITCH_MIN, CAM_PITCH_MAX)

		if _touch_input:
			var cam_delta: Vector2 = _touch_input.get_camera_delta()
			_cam_yaw   += cam_delta.x
			_cam_pitch = clampf(_cam_pitch + cam_delta.y, CAM_PITCH_MIN, CAM_PITCH_MAX)

		if entry_mode:
			return   # marble is frozen; skip movement and jump

	# ── Touch jump (tap on knob) ───────────────────────────────────────────────
	if _touch_input and _touch_input.consume_jump():
		_jump_buffered      = true
		_jump_buffer_frames = JUMP_BUFFER_FRAMES

	# ── Ground detection with coyote time ─────────────────────────────────────
	var is_grounded := _ground_ray.is_colliding()
	if is_grounded:
		_coyote_frames = COYOTE_FRAMES
	elif _coyote_frames > 0:
		_coyote_frames -= 1

	# ── Preserve horizontal momentum through landing ───────────────────────────
	if not is_grounded:
		_air_flat_vel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	elif not _was_grounded:
		var cur_flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		if _air_flat_vel.length() > cur_flat.length():
			linear_velocity = Vector3(_air_flat_vel.x, linear_velocity.y, _air_flat_vel.z)
	_was_grounded = is_grounded

	# ── Jump buffer expiry ─────────────────────────────────────────────────────
	if _jump_buffered:
		_jump_buffer_frames -= 1
		if _jump_buffer_frames <= 0:
			_jump_buffered = false

	# ── Jump ───────────────────────────────────────────────────────────────────
	if _jump_buffered and _coyote_frames > 0:
		linear_velocity.y = JUMP_IMPULSE
		_jump_buffered = false
		_coyote_frames = 0

	# ── Marble movement (WASD, left stick, or touch joystick) ──────────────────
	var cam_basis := cam_pivot.global_basis
	var forward   := -cam_basis.z; forward.y = 0.0; forward = forward.normalized()
	var right     :=  cam_basis.x; right.y   = 0.0; right   = right.normalized()

	var fwd_in := -Input.get_axis("move_forward", "move_back")
	var str_in :=  Input.get_axis("move_left", "move_right")

	if _touch_input:
		var tv: Vector2 = _touch_input.get_stick_vector()
		fwd_in = clampf(fwd_in + tv.y, -1.0, 1.0)
		str_in = clampf(str_in + tv.x, -1.0, 1.0)

	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)

	if abs(fwd_in) > 0.01:
		var dir := forward * fwd_in
		var mult := COUNTER_STEER_MULT if flat.dot(dir) < 0.0 else 1.0
		apply_central_force(dir * FORCE * mult)

	if abs(str_in) > 0.01:
		var dir := right * str_in
		var mult := COUNTER_STEER_MULT if flat.dot(dir) < 0.0 else 1.0
		apply_central_force(dir * FORCE * mult)

	# ── Speed cap ──────────────────────────────────────────────────────────────
	flat = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat.length() > MAX_SPEED:
		var clamped := flat.normalized() * MAX_SPEED
		linear_velocity = Vector3(clamped.x, linear_velocity.y, clamped.z)


func _apply_cam_rotation() -> void:
	cam_pivot.global_rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
