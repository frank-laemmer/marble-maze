extends Area3D

## Fake wall — visible mesh but no physical collision; marble passes through.
## Uses the opaque material when fully solid, switches to the alpha-capable
## duplicate only while fading or semi-transparent.

const TRANS_ALPHA : float = 0.18
const MAP_ALPHA   : float = 0.7
const FADE_SPEED  : float = 1.0 / 0.1   # full range in 100 ms

var _normal_mat     : StandardMaterial3D
var _anim_mat       : StandardMaterial3D
var _vis            : MeshInstance3D
var _inside_count   : int  = 0
var _map_revealed   : bool = false
var _panel_vis      : MeshInstance3D     = null
var _panel_normal_mat : StandardMaterial3D = null
var _panel_anim_mat   : StandardMaterial3D = null

func setup(wall_mesh: BoxMesh, wall_mat: StandardMaterial3D) -> void:
	_normal_mat = wall_mat

	_anim_mat = wall_mat.duplicate()
	_anim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_anim_mat.albedo_color.a = 1.0

	_vis = MeshInstance3D.new()
	_vis.mesh = wall_mesh
	_vis.material_override = _normal_mat
	add_child(_vis)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func register_panel(panel: MeshInstance3D, mat: StandardMaterial3D) -> void:
	_panel_vis        = panel
	_panel_normal_mat = mat

	_panel_anim_mat = mat.duplicate()
	_panel_anim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_panel_anim_mat.albedo_color.a = 1.0
	# panel starts on the opaque material

func set_map_reveal(active: bool) -> void:
	_map_revealed = active

func _target_alpha() -> float:
	if _inside_count > 0:
		return TRANS_ALPHA
	return MAP_ALPHA if _map_revealed else 1.0

func _process(delta: float) -> void:
	var new_a := move_toward(_anim_mat.albedo_color.a, _target_alpha(), FADE_SPEED * delta)
	_anim_mat.albedo_color.a = new_a
	if _panel_anim_mat:
		_panel_anim_mat.albedo_color.a = new_a

	var use_opaque := new_a >= 1.0
	_vis.material_override = _normal_mat if use_opaque else _anim_mat
	if _panel_vis:
		_panel_vis.material_override = _panel_normal_mat if use_opaque else _panel_anim_mat

func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_inside_count += 1

func _on_body_exited(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_inside_count = max(0, _inside_count - 1)
