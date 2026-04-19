extends Area3D

## Invisible wall — physical collision lives on MazeBody (StaticBody3D).
## This Area3D is slightly oversized so it detects the marble on approach
## and briefly flashes a ghost shimmer to reveal the hidden wall.

var _ghost_mat : StandardMaterial3D
var _ghost_vis : MeshInstance3D

## Call immediately after adding to the scene tree.
## wall_mesh  — shared BoxMesh (same dimensions as the physical wall)
## wall_mat   — used as colour reference; ghost gets its own blue-white tint
func setup(wall_mesh: BoxMesh, wall_mat: StandardMaterial3D) -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(wall_mat.albedo_color.r, wall_mat.albedo_color.g, wall_mat.albedo_color.b, 0.0)

	_ghost_vis = MeshInstance3D.new()
	_ghost_vis.mesh = wall_mesh
	_ghost_vis.material_override = _ghost_mat
	add_child(_ghost_vis)

func set_map_reveal(active: bool) -> void:
	_ghost_mat.albedo_color.a = 0.7 if active else 0.0
