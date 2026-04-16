extends Node3D

## Sliding door — blocks the marble until the player uses a key.
## Single slab (no split seam). On open it sinks straight down into the floor.
## variant "ns" / "ew" is kept so level_loader can still pass it; the visual
## and animation are identical for both orientations.

signal marble_touched

const SLIDE_DURATION := 0.60

var color:     String = "yellow"
var _opened:   bool = false
var _slab:     Node3D
var _col:      CollisionShape3D
var _lock:     Node3D
var _wall_h:   float


## Called by level_loader immediately after set_script().
func build(variant: String, cell: float, wall_h: float, key_color: String = "yellow") -> void:
	color   = key_color
	_wall_h = wall_h
	add_to_group("door")

	var wall_mat := _mat(Color(0.22, 0.32, 0.52))

	var lock_color: Color
	var lock_emit:  Color
	match key_color:
		"green":
			lock_color = Color(0.18, 0.82, 0.28)
			lock_emit  = Color(0.05, 0.45, 0.10)
		"red":
			lock_color = Color(0.88, 0.18, 0.18)
			lock_emit  = Color(0.50, 0.05, 0.05)
		_: # yellow
			lock_color = Color(0.90, 0.72, 0.10)
			lock_emit  = Color(0.55, 0.38, 0.00)

	var gold_mat := _mat(lock_color)
	gold_mat.emission_enabled           = true
	gold_mat.emission                   = lock_emit
	gold_mat.emission_energy_multiplier = 0.45
	gold_mat.metallic                   = 0.6
	gold_mat.roughness                  = 0.35

	var hole_mat := _mat(Color(0.05, 0.05, 0.09))

	var phys_mat       := PhysicsMaterial.new()
	phys_mat.bounce     = 0.20

	# ── Single slab, centred at mid-wall height ───────────────────────────────
	_slab          = Node3D.new()
	_slab.name     = "Slab"
	_slab.position = Vector3(0.0, wall_h * 0.5, 0.0)

	# Physics body
	var body                      := StaticBody3D.new()
	body.name                      = "Body"
	body.physics_material_override = phys_mat
	_col       = CollisionShape3D.new()
	var shp    = BoxShape3D.new()
	shp.size   = Vector3(cell, wall_h, cell)
	_col.shape  = shp
	body.add_child(_col)
	_slab.add_child(body)

	# Main slab mesh
	_add_mesh(_slab, Vector3(cell, wall_h, cell), Vector3.ZERO, wall_mat)

	# Raised border panels on all four vertical faces
	var margin      := 0.16
	var panel_thick := 0.12
	var pw          := cell   - margin * 2.0
	var ph          := wall_h - margin * 2.0
	for sign in [-1.0, 1.0]:
		_add_mesh(_slab, Vector3(pw, ph, panel_thick),
				  Vector3(0.0, 0.0, sign * (cell * 0.5 + panel_thick * 0.5 - 0.02)), wall_mat)
		_add_mesh(_slab, Vector3(panel_thick, ph, pw),
				  Vector3(sign * (cell * 0.5 + panel_thick * 0.5 - 0.02), 0.0, 0.0), wall_mat)

	# Lock plates — shown on the two faces the marble approaches from
	var face_positions: Array
	if variant == "ns":
		face_positions = [Vector3(0.0, 0.0, -(cell * 0.5 + 0.09)),
						  Vector3(0.0, 0.0,  (cell * 0.5 + 0.09))]
		_lock = _build_lock_faces(face_positions,
				Vector3(0.56, 0.68, 0.18), Vector3(0.15, 0.26, 0.22), gold_mat, hole_mat)
	else:
		face_positions = [Vector3(-(cell * 0.5 + 0.09), 0.0, 0.0),
						  Vector3( (cell * 0.5 + 0.09), 0.0, 0.0)]
		_lock = _build_lock_faces(face_positions,
				Vector3(0.18, 0.68, 0.56), Vector3(0.22, 0.26, 0.15), gold_mat, hole_mat)
	_slab.add_child(_lock)

	add_child(_slab)

	# ── Trigger area ──────────────────────────────────────────────────────────
	var trigger      := Area3D.new()
	trigger.name      = "Trigger"
	trigger.position  = Vector3(0.0, wall_h * 0.5, 0.0)
	var tc := CollisionShape3D.new()
	var ts := BoxShape3D.new()
	ts.size = Vector3(cell + 0.6, wall_h, cell + 0.6)
	tc.shape = ts
	trigger.add_child(tc)
	trigger.body_entered.connect(_on_trigger_body_entered)
	add_child(trigger)


## Sink the slab into the floor.
func open() -> void:
	if _opened:
		return
	_opened = true

	_col.disabled = true
	_lock.hide()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Slide the slab down until its top surface is flush with the floor (y = 0)
	tween.tween_property(_slab, "position:y", -_wall_h * 0.5, SLIDE_DURATION)
	tween.finished.connect(func(): _slab.hide())


func _on_trigger_body_entered(body: Node3D) -> void:
	if not _opened and body.is_in_group("marble"):
		marble_touched.emit()


# ── Construction helpers ───────────────────────────────────────────────────────

func _build_lock_faces(positions: Array, plate_size: Vector3, hole_size: Vector3,
					   gold_mat: StandardMaterial3D, hole_mat: StandardMaterial3D) -> Node3D:
	var lock := Node3D.new()
	lock.name = "Lock"
	for face_pos: Vector3 in positions:
		var pm  := BoxMesh.new(); pm.size = plate_size
		var pv  := MeshInstance3D.new()
		pv.mesh              = pm
		pv.material_override = gold_mat
		pv.position          = face_pos
		lock.add_child(pv)

		var hm  := BoxMesh.new(); hm.size = hole_size
		var hv  := MeshInstance3D.new()
		hv.mesh              = hm
		hv.material_override = hole_mat
		hv.position          = face_pos + Vector3(0.0, -0.06, 0.0)
		lock.add_child(hv)
	return lock


func _add_mesh(parent: Node3D, size: Vector3, offset: Vector3,
			   mat: StandardMaterial3D) -> void:
	var bm  := BoxMesh.new(); bm.size = size
	var vis := MeshInstance3D.new()
	vis.mesh              = bm
	vis.material_override = mat
	vis.position          = offset
	parent.add_child(vis)


func _mat(color: Color) -> StandardMaterial3D:
	var m          := StandardMaterial3D.new()
	m.albedo_color  = color
	return m
