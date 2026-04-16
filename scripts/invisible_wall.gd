extends Area3D

## Invisible wall — physical collision lives on MazeBody (StaticBody3D).
## This Area3D is slightly oversized so it detects the marble on approach
## and briefly flashes a ghost shimmer to reveal the hidden wall.

const GHOST_PEAK_ALPHA : float = 0.55
const GHOST_FADE_IN    : float = 0.06   # seconds — quick flash in
const GHOST_FADE_OUT   : float = 0.45   # seconds — slow fade out

var _ghost_mat : StandardMaterial3D
var _ghost_vis : MeshInstance3D
var _tween     : Tween = null

## Call immediately after adding to the scene tree.
## wall_mesh  — shared BoxMesh (same dimensions as the physical wall)
## wall_mat   — used as colour reference; ghost gets its own blue-white tint
func setup(wall_mesh: BoxMesh, _wall_mat: StandardMaterial3D) -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.55, 0.78, 1.0, 0.0)

	_ghost_vis = MeshInstance3D.new()
	_ghost_vis.mesh = wall_mesh
	_ghost_vis.material_override = _ghost_mat
	add_child(_ghost_vis)

	# Ghost effect disabled — marble bounces normally without visual feedback.
	# body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_ghost_mat, "albedo_color:a", GHOST_PEAK_ALPHA, GHOST_FADE_IN)
	_tween.tween_property(_ghost_mat, "albedo_color:a", 0.0, GHOST_FADE_OUT)
