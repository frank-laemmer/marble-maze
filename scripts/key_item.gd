extends Area3D

## Hovering collectible key. Color (yellow / green / red) set via setup().
## Emits key_collected(color) when the marble rolls through it.

signal key_collected(color: String)

const BOB_AMP  := 0.10
const BOB_FREQ := 1.3
const ROT_SPD  := 2.2

var color: String = "yellow"

var _time:   float = 0.0
var _base_y: float = 0.0
var _pivot:  Node3D


## Called by level_loader before the node is added to the scene tree.
func setup(c: String) -> void:
	color = c


func _ready() -> void:
	_base_y = position.y
	add_to_group("key_item")

	var col := CollisionShape3D.new()
	var shp := SphereShape3D.new()
	shp.radius = 0.75
	col.shape  = shp
	add_child(col)

	# ── Material based on color ───────────────────────────────────────────────
	var key_color: Color
	var emit_color: Color
	match color:
		"green":
			key_color  = Color(0.18, 0.82, 0.28)
			emit_color = Color(0.05, 0.45, 0.10)
		"red":
			key_color  = Color(0.88, 0.18, 0.18)
			emit_color = Color(0.50, 0.05, 0.05)
		_: # yellow
			key_color  = Color(0.92, 0.74, 0.10)
			emit_color = Color(0.60, 0.38, 0.00)

	var mat := StandardMaterial3D.new()
	mat.albedo_color             = key_color
	mat.emission_enabled         = true
	mat.emission                 = emit_color
	mat.emission_energy_multiplier = 1.3
	mat.metallic                 = 0.70
	mat.roughness                = 0.28

	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.04, 0.04, 0.07)

	_pivot = Node3D.new()
	add_child(_pivot)

	# Bow (square ring head)
	_vis(Vector3(0.0,  0.15, 0.0), Vector3(0.32, 0.32, 0.09), mat)
	_vis(Vector3(0.0,  0.15, 0.0), Vector3(0.15, 0.15, 0.13), void_mat)
	# Shaft
	_vis(Vector3(0.0, -0.12, 0.0), Vector3(0.08, 0.40, 0.08), mat)
	# Teeth
	_vis(Vector3(0.09, -0.28, 0.0), Vector3(0.18, 0.07, 0.08), mat)
	_vis(Vector3(0.07, -0.20, 0.0), Vector3(0.13, 0.07, 0.08), mat)

	# ── Floating color label above the key ────────────────────────────────────
	var lbl        := Label3D.new()
	lbl.text        = "⚿"
	lbl.font_size   = 48
	lbl.modulate    = key_color
	lbl.position    = Vector3(0.0, 0.65, 0.0)
	lbl.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	add_child(lbl)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time          += delta
	position.y      = _base_y + sin(_time * BOB_FREQ * TAU) * BOB_AMP
	_pivot.rotation.y += ROT_SPD * delta


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("marble"):
		key_collected.emit(color)
		queue_free()


func _vis(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var bm            := BoxMesh.new()
	bm.size            = size
	var vis            := MeshInstance3D.new()
	vis.mesh           = bm
	vis.material_override = mat
	vis.position       = pos
	_pivot.add_child(vis)
