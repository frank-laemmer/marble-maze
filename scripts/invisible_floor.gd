extends Area3D

## Invisible floor — collision lives on MazeBody.
## This Area3D detects the marble rolling over it and fades in a ghost mesh.
## Also responds to map-reveal when marble is on a Map tile.

const MARBLE_ALPHA : float = 0.5
const MAP_ALPHA    : float = 0.2
const FADE_SPEED   : float = 1.0 / 0.1   # full range in 100 ms

var _anim_mat    : StandardMaterial3D
var _on_count    : int  = 0
var _map_revealed: bool = false

func setup(floor_mesh: BoxMesh) -> void:
	_anim_mat = StandardMaterial3D.new()
	_anim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_anim_mat.albedo_color = Color(0.60, 0.60, 0.60, 0.0)

	var vis := MeshInstance3D.new()
	vis.mesh = floor_mesh
	vis.material_override = _anim_mat
	add_child(vis)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_map_reveal(active: bool) -> void:
	_map_revealed = active

func _target_alpha() -> float:
	if _on_count > 0:
		return MARBLE_ALPHA
	return MAP_ALPHA if _map_revealed else 0.0

func _process(delta: float) -> void:
	_anim_mat.albedo_color.a = move_toward(
		_anim_mat.albedo_color.a, _target_alpha(), FADE_SPEED * delta)

func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_on_count += 1

func _on_body_exited(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_on_count = max(0, _on_count - 1)
