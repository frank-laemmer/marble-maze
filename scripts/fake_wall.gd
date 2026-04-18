extends Area3D

## Fake wall — visible mesh but no physical collision; marble passes through.
## While the marble is inside the wall volume the mesh turns transparent;
## it returns to opaque once the marble has fully exited.

const TRANS_ALPHA : float = 0.18

var _normal_mat        : StandardMaterial3D
var _trans_mat         : StandardMaterial3D
var _vis               : MeshInstance3D
var _inside_count      : int = 0
var _panel_vis         : MeshInstance3D = null
var _panel_normal_mat  : StandardMaterial3D = null
var _panel_trans_mat   : StandardMaterial3D = null

## Call immediately after adding to the scene tree.
## wall_mesh — shared BoxMesh for the visual
## wall_mat  — the same opaque wall material used by normal walls
func setup(wall_mesh: BoxMesh, wall_mat: StandardMaterial3D) -> void:
	_normal_mat = wall_mat

	_trans_mat = wall_mat.duplicate()
	_trans_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trans_mat.albedo_color.a = TRANS_ALPHA

	_vis = MeshInstance3D.new()
	_vis.mesh = wall_mesh
	_vis.material_override = _normal_mat
	add_child(_vis)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func register_panel(panel: MeshInstance3D, mat: StandardMaterial3D) -> void:
	_panel_vis        = panel
	_panel_normal_mat = mat
	_panel_trans_mat  = mat.duplicate()
	_panel_trans_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_panel_trans_mat.albedo_color.a = TRANS_ALPHA

func _on_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_inside_count += 1
	_vis.material_override = _trans_mat
	if _panel_vis:
		_panel_vis.material_override = _panel_trans_mat

func _on_body_exited(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	_inside_count = max(0, _inside_count - 1)
	if _inside_count == 0:
		_vis.material_override = _normal_mat
		if _panel_vis:
			_panel_vis.material_override = _panel_normal_mat
