extends Node

## Runtime level builder — parses the text maze format and creates a Node3D
## hierarchy with physics and visuals. Used in place of the Python build script.
##
## Tile characters (spaces between tiles are stripped for backward compat):
##   S  — start position (floor tile + StartMarker)
##   G  — goal / end    (floor tile + GoalZone)
##   #  — wall block    (solid, 4-unit tall; floor tile underneath)
##   I  — invisible wall (collision + floor, no mesh; ghost shimmer on hit)
##   F  — fake wall     (mesh + floor, no collision; transparent on pass-through)
##   K  — key item      (floor tile + hovering collectible key)
##   K/J/X — yellow/green/red key (floor + hovering collectible)
##   D/E/R — yellow/green/red door (auto-detects direction; H is a legacy yellow-door alias)
##   V  — invisible floor (collision only, no mesh; looks like empty but marble rolls on it)
##   .  — floor tile    (open corridor)
##   _  — empty         (no floor; marble falls through)

const CELL    : float = 4.0
const WALL_H  : float = 4.0
const FLOOR_Y : float = -0.25
const FLOOR_H : float = 0.5

const _GOAL_SCRIPT          = preload("res://scripts/goal_zone.gd")
const _INVISIBLE_WALL_SCRIPT = preload("res://scripts/invisible_wall.gd")
const _FAKE_WALL_SCRIPT      = preload("res://scripts/fake_wall.gd")
const _KEY_ITEM_SCRIPT       = preload("res://scripts/key_item.gd")
const _DOOR_SCRIPT           = preload("res://scripts/door.gd")

# ── Minimap data (populated after each build_from_*) ─────────────────────────
var grid: Array[String] = []
var grid_rows: int = 0
var grid_cols: int = 0
var start_cell: Vector2i = Vector2i.ZERO
var goal_cell:  Vector2i = Vector2i.ZERO

# ── Level metadata (populated after each build_from_*) ────────────────────────
## Time limit in seconds; defaults to 180 if not set in the level file.
var level_time: int = 180
## Display name; defaults to empty string if not set.
var level_name: String = ""
## Tilt in degrees around the X axis (slopes toward higher row indices) and Z axis (slopes toward higher col indices).
var level_tilt_x: int = 0
var level_tilt_z: int = 0

# ── Public API ────────────────────────────────────────────────────────────────

## Parse only the metadata (name/timer) from raw level content without building
## any geometry. Call this early (e.g. in _enter_tree) so GameState.level_timer
## is correct before child nodes run their _ready().
func peek_metadata(content: String) -> void:
	_parse(content)

func build_from_file(path: String) -> Node3D:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LevelLoader: cannot open " + path)
		return null
	var content := file.get_as_text()
	file.close()
	return build_from_string(content)

func build_from_string(content: String) -> Node3D:
	var rows := _parse(content)
	if rows.is_empty():
		push_error("LevelLoader: empty level content")
		return null
	return _build(rows)

# ── Parsing ───────────────────────────────────────────────────────────────────

func _parse(content: String) -> Array:
	# Reset metadata to defaults before each parse.
	level_time = 180
	level_name = ""
	level_tilt_x = 0
	level_tilt_z = 0

	var rows: Array = []
	for line in content.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("!"):
			# Metadata line — preserve internal spaces (e.g. "!name=Born to roll").
			var kv := trimmed.substr(1).split("=", true, 1)
			if kv.size() == 2:
				match kv[0]:
					"timer": level_time = kv[1].to_int()
					"name":  level_name = kv[1]
					"tilt":
						var parts := kv[1].split(",")
						level_tilt_x = parts[0].to_int()
						level_tilt_z = parts[1].to_int() if parts.size() > 1 else 0
		else:
			# Grid row — strip spaces/tabs so the old "S # . #" format still works.
			var stripped := ""
			for ch in line:
				if ch != " " and ch != "\t" and ch != "\r":
					stripped += ch
			if not stripped.is_empty():
				rows.append(stripped)
	return rows

# ── Scene building ────────────────────────────────────────────────────────────

func _build(rows: Array) -> Node3D:
	var R: int = rows.size()
	var C: int = 0
	for row in rows:
		C = max(C, (row as String).length())

	# Pad shorter rows with floor tiles so the grid is rectangular
	var grid: Array[String] = []
	for row in rows:
		grid.append((row as String).rpad(C, "."))

	# Locate start (S) and goal (G); fall back to corners
	var start_col := 0; var start_row := 0
	var goal_col  := C - 1; var goal_row  := R - 1

	for ri in R:
		for ci in grid[ri].length():
			match grid[ri][ci]:
				"S": start_col = ci; start_row = ri
				"G": goal_col  = ci; goal_row  = ri

	# ── Expose grid state for the minimap ────────────────────────────────────
	self.grid  = grid
	grid_rows  = R
	grid_cols  = C
	start_cell = Vector2i(start_col, start_row)
	goal_cell  = Vector2i(goal_col,  goal_row)

	# ── Root node ─────────────────────────────────────────────────────────────
	var root := Node3D.new()
	root.name = "Level"

	# ── Lighting ──────────────────────────────────────────────────────────────
	var key := DirectionalLight3D.new()
	key.name = "DirectionalLight3D"
	key.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	key.light_energy = 1.8
	key.shadow_enabled = true
	root.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-30.0, 225.0, 0.0)
	fill.light_energy = 0.4
	root.add_child(fill)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# ── Shared mesh resources ─────────────────────────────────────────────────
	var floor_mesh := BoxMesh.new(); floor_mesh.size = Vector3(CELL, FLOOR_H, CELL)
	var wall_mesh  := BoxMesh.new(); wall_mesh.size  = Vector3(CELL, WALL_H,  CELL)
	var goal_mesh  := BoxMesh.new(); goal_mesh.size  = Vector3(CELL * 0.85, 0.12, CELL * 0.85)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.58, 0.65)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.22, 0.32, 0.52)

	var goal_mat := StandardMaterial3D.new()
	goal_mat.albedo_color = Color(0.9, 0.75, 0.1)
	goal_mat.emission_enabled = true
	goal_mat.emission = Color(0.6, 0.5, 0.0)
	goal_mat.emission_energy_multiplier = 0.8

	var map_mat := StandardMaterial3D.new()
	map_mat.albedo_color = Color(0.15, 0.65, 0.72)
	map_mat.emission_enabled = true
	map_mat.emission = Color(0.05, 0.4, 0.45)
	map_mat.emission_energy_multiplier = 0.5

	# ── Single static-body for all maze geometry ──────────────────────────────
	var body := StaticBody3D.new()
	body.name = "MazeBody"
	var wall_phys := PhysicsMaterial.new()
	wall_phys.bounce = 0.20  # slight kick off walls
	body.physics_material_override = wall_phys
	root.add_child(body)

	# ── Per-cell geometry ──────────────────────────────────────────────────────
	for ri in R:
		for ci in grid[ri].length():
			var ch: String = grid[ri][ci]
			if ch == "_":
				continue  # explicit empty — no floor, marble falls

			var cx := ci * CELL + CELL * 0.5
			var cz := ri * CELL + CELL * 0.5

			if ch == "#":
				# Floor underneath wall
				_add_box(root, body, floor_mesh, floor_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))
				# Solid wall on top
				_add_box(root, body, wall_mesh, wall_mat,
						 Vector3(cx, WALL_H * 0.5, cz),
						 Vector3(CELL, WALL_H, CELL))
			elif ch == "I":
				# Floor underneath
				_add_box(root, body, floor_mesh, floor_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))
				# Solid collision on MazeBody (no mesh)
				var i_col := CollisionShape3D.new()
				var i_shp := BoxShape3D.new(); i_shp.size = Vector3(CELL, WALL_H, CELL)
				i_col.shape = i_shp
				i_col.position = Vector3(cx, WALL_H * 0.5, cz)
				body.add_child(i_col)
				# Detection Area3D (slightly oversized so marble triggers it on contact)
				var iw := Area3D.new()
				iw.position = Vector3(cx, WALL_H * 0.5, cz)
				iw.set_script(_INVISIBLE_WALL_SCRIPT)
				var iw_col := CollisionShape3D.new()
				var iw_shp := BoxShape3D.new()
				iw_shp.size = Vector3(CELL + 0.8, WALL_H, CELL + 0.8)
				iw_col.shape = iw_shp
				iw.add_child(iw_col)
				iw.call("setup", wall_mesh, wall_mat)
				root.add_child(iw)
			elif ch == "F":
				# Floor underneath
				_add_box(root, body, floor_mesh, floor_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))
				# Fake wall — Area3D with mesh, no StaticBody collision
				var fw := Area3D.new()
				fw.position = Vector3(cx, WALL_H * 0.5, cz)
				fw.set_script(_FAKE_WALL_SCRIPT)
				var fw_col := CollisionShape3D.new()
				var fw_shp := BoxShape3D.new()
				fw_shp.size = Vector3(CELL, WALL_H, CELL)
				fw_col.shape = fw_shp
				fw.add_child(fw_col)
				fw.call("setup", wall_mesh, wall_mat)
				root.add_child(fw)
			elif ch == "M":
				_add_box(root, body, floor_mesh, map_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))
			elif ch == "K" or ch == "J" or ch == "X":
				# Key — floor tile + hovering collectible (disabled by feature flag)
				_add_box(root, body, floor_mesh, floor_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))
				if GameState.FEATURE_KEYS_DOORS:
					var key_color := "yellow" if ch == "K" else ("green" if ch == "J" else "red")
					var key_node := Area3D.new()
					key_node.name     = "Key_%d_%d" % [ri, ci]
					key_node.position = Vector3(cx, 1.2, cz)
					key_node.set_script(_KEY_ITEM_SCRIPT)
					key_node.call("setup", key_color)
					root.add_child(key_node)
			elif ch == "D" or ch == "H" or ch == "E" or ch == "R":
				# Door — disabled by feature flag; renders as a plain wall when off.
				if GameState.FEATURE_KEYS_DOORS:
					var door_color := "yellow"
					if ch == "E": door_color = "green"
					elif ch == "R": door_color = "red"
					var variant := _detect_door_variant(grid, ri, ci, R, C)
					if variant == "":
						_add_box(root, body, wall_mesh, wall_mat,
								 Vector3(cx, WALL_H * 0.5, cz),
								 Vector3(CELL, WALL_H, CELL))
					else:
						_add_box(root, body, floor_mesh, floor_mat,
								 Vector3(cx, FLOOR_Y, cz),
								 Vector3(CELL, FLOOR_H, CELL))
						var door := Node3D.new()
						door.name     = "Door_%d_%d" % [ri, ci]
						door.position = Vector3(cx, 0.0, cz)
						door.set_script(_DOOR_SCRIPT)
						root.add_child(door)
						door.call("build", variant, CELL, WALL_H, door_color)
				else:
					_add_box(root, body, wall_mesh, wall_mat,
							 Vector3(cx, WALL_H * 0.5, cz),
							 Vector3(CELL, WALL_H, CELL))
			elif ch == "V":
				# Invisible floor — collision only, no visual mesh
				var v_col := CollisionShape3D.new()
				var v_shp := BoxShape3D.new(); v_shp.size = Vector3(CELL, FLOOR_H, CELL)
				v_col.shape = v_shp
				v_col.position = Vector3(cx, FLOOR_Y, cz)
				body.add_child(v_col)
			else:
				# . S G  — all get a floor tile
				_add_box(root, body, floor_mesh, floor_mat,
						 Vector3(cx, FLOOR_Y, cz),
						 Vector3(CELL, FLOOR_H, CELL))

	# ── Start marker ───────────────────────────────────────────────────────────
	var sx := start_col * CELL + CELL * 0.5
	var sz := start_row * CELL + CELL * 0.5
	var sm := Marker3D.new()
	sm.name = "StartMarker"
	sm.position = Vector3(sx, 1.0, sz)
	sm.add_to_group("start_marker")
	root.add_child(sm)

	# ── Goal zone ──────────────────────────────────────────────────────────────
	var gx := goal_col * CELL + CELL * 0.5
	var gz := goal_row * CELL + CELL * 0.5

	var gz_node := Area3D.new()
	gz_node.name = "GoalZone"
	gz_node.position = Vector3(gx, 1.0, gz)
	gz_node.add_to_group("goal_zone")
	gz_node.set_script(_GOAL_SCRIPT)
	var gz_col := CollisionShape3D.new()
	var gz_shp := BoxShape3D.new(); gz_shp.size = Vector3(2.5, 2.5, 2.5)
	gz_col.shape = gz_shp
	gz_node.add_child(gz_col)
	root.add_child(gz_node)

	# Goal visual marker (glowing gold pad)
	var gv := MeshInstance3D.new()
	gv.mesh = goal_mesh
	gv.material_override = goal_mat
	gv.position = Vector3(gx, 0.04, gz)
	root.add_child(gv)

	# ── Death zone (catch falling marble) ─────────────────────────────────────
	var total_w := C * CELL
	var total_d := R * CELL
	var dz := Area3D.new()
	dz.name = "DeathZone"
	dz.position = Vector3(total_w * 0.5, -5.0, total_d * 0.5)
	dz.add_to_group("death_zone")
	var dz_col := CollisionShape3D.new()
	var dz_shp := BoxShape3D.new(); dz_shp.size = Vector3(total_w + 200.0, 2.0, total_d + 200.0)
	dz_col.shape = dz_shp
	dz.add_child(dz_col)
	root.add_child(dz)

	_add_grid_lines(root, grid, R, C)
	return root

## Returns "ns", "ew", or "" (fall back to wall) based on which pair of
## neighbouring cells are solid (wall / invis-wall / fake-wall / door / boundary).
func _detect_door_variant(grid: Array, ri: int, ci: int, R: int, C: int) -> String:
	var solid := ["#", "I", "F", "D", "H"]
	var left_solid  := ci == 0     or solid.has(grid[ri][ci - 1])
	var right_solid := ci >= C - 1 or solid.has(grid[ri][ci + 1])
	var above_solid := ri == 0     or solid.has(grid[ri - 1][ci])
	var below_solid := ri >= R - 1 or solid.has(grid[ri + 1][ci])
	if left_solid and right_solid:
		return "ns"
	elif above_solid and below_solid:
		return "ew"
	return ""

# Edge outlines on every visible tile. CULL_DISABLED so every quad is visible
# from both sides regardless of camera angle. Wall tiles also get solid corner
# posts at each vertical edge so adjacent face stripes meet without a gap.
func _add_grid_lines(root: Node3D, g: Array[String], R: int, C: int) -> void:
	var lw := 0.05  # stripe width — barely-there

	# ~96 % of each surface's base colour
	var floor_line_mat := StandardMaterial3D.new()
	floor_line_mat.albedo_color = Color(0.588, 0.622, 0.7, 1.0)   # floor base: 0.55 0.58 0.65
	floor_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_line_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED

	var wall_line_mat := StandardMaterial3D.new()
	wall_line_mat.albedo_color = Color(0.239, 0.344, 0.57, 1.0)    # wall base: 0.22 0.32 0.52
	wall_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_line_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED

	var wall_tiles := ["#", "F", "D", "E", "R", "H"]

	var st_f := SurfaceTool.new(); st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_w := SurfaceTool.new(); st_w.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ri in R:
		for ci in g[ri].length():
			var ch := g[ri][ci]
			if ch == "_" or ch == "V" or ch == "I":
				continue
			var x := ci * CELL
			var z := ri * CELL

			if wall_tiles.has(ch):
				var yt := WALL_H + 0.01   # just above wall-top surface
				var wh := WALL_H + 0.01   # vertical faces extend to match yt → no top gap
				# Top face border
				_hquad(st_w, x,             x + CELL,     z,             z + lw,    yt)
				_hquad(st_w, x,             x + CELL,     z + CELL - lw, z + CELL,  yt)
				_hquad(st_w, x,             x + lw,       z,             z + CELL,  yt)
				_hquad(st_w, x + CELL - lw, x + CELL,     z,             z + CELL,  yt)
				# Vertical face borders — 0.01 outward offset, height = wh so top meets yt
				_vface_z(st_w, x, x + CELL, wh, z - 0.01,        lw)  # north
				_vface_z(st_w, x, x + CELL, wh, z + CELL + 0.01, lw)  # south
				_vface_x(st_w, z, z + CELL, wh, x - 0.01,        lw)  # west
				_vface_x(st_w, z, z + CELL, wh, x + CELL + 0.01, lw)  # east
				# Corner posts — fill the gap between adjacent vertical face stripes
				_box_st(st_w, x,        wh * 0.5, z,        lw, wh, lw)
				_box_st(st_w, x + CELL, wh * 0.5, z,        lw, wh, lw)
				_box_st(st_w, x,        wh * 0.5, z + CELL, lw, wh, lw)
				_box_st(st_w, x + CELL, wh * 0.5, z + CELL, lw, wh, lw)
			else:
				var yf := 0.01
				_hquad(st_f, x,             x + CELL,     z,             z + lw,    yf)
				_hquad(st_f, x,             x + CELL,     z + CELL - lw, z + CELL,  yf)
				_hquad(st_f, x,             x + lw,       z,             z + CELL,  yf)
				_hquad(st_f, x + CELL - lw, x + CELL,     z,             z + CELL,  yf)

	_commit_lines(root, st_f, floor_line_mat)
	_commit_lines(root, st_w, wall_line_mat)


func _commit_lines(root: Node3D, st: SurfaceTool, mat: StandardMaterial3D) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	root.add_child(vis)


# Four border stripes on a vertical face at constant z (north/south wall face)
func _vface_z(st: SurfaceTool, x0: float, x1: float, wh: float, zf: float, lw: float) -> void:
	_vquad_z(st, x0,        x1,        0.0,     lw,  zf)
	_vquad_z(st, x0,        x1,        wh - lw, wh,  zf)
	_vquad_z(st, x0,        x0 + lw,   0.0,     wh,  zf)
	_vquad_z(st, x1 - lw,   x1,        0.0,     wh,  zf)


# Four border stripes on a vertical face at constant x (west/east wall face)
func _vface_x(st: SurfaceTool, z0: float, z1: float, wh: float, xf: float, lw: float) -> void:
	_vquad_x(st, z0,        z1,        0.0,     lw,  xf)
	_vquad_x(st, z0,        z1,        wh - lw, wh,  xf)
	_vquad_x(st, z0,        z0 + lw,   0.0,     wh,  xf)
	_vquad_x(st, z1 - lw,   z1,        0.0,     wh,  xf)


# Solid box added to a SurfaceTool (CULL_DISABLED so winding doesn't matter)
func _box_st(st: SurfaceTool, cx: float, cy: float, cz: float,
			 sx: float, sy: float, sz: float) -> void:
	var x0 := cx - sx * 0.5; var x1 := cx + sx * 0.5
	var y0 := cy - sy * 0.5; var y1 := cy + sy * 0.5
	var z0 := cz - sz * 0.5; var z1 := cz + sz * 0.5
	_hquad(st, x0, x1, z0, z1, y1)   # top
	_hquad(st, x0, x1, z0, z1, y0)   # bottom
	_vquad_z(st, x0, x1, y0, y1, z0) # north
	_vquad_z(st, x0, x1, y0, y1, z1) # south
	_vquad_x(st, z0, z1, y0, y1, x0) # west
	_vquad_x(st, z0, z1, y0, y1, x1) # east


# Horizontal quad at constant y
func _hquad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	st.add_vertex(Vector3(x0, y, z0))
	st.add_vertex(Vector3(x1, y, z0))
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x0, y, z0))
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x0, y, z1))


# Vertical quad at constant z (XY plane — north/south faces)
func _vquad_z(st: SurfaceTool, x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	st.add_vertex(Vector3(x0, y0, z))
	st.add_vertex(Vector3(x1, y0, z))
	st.add_vertex(Vector3(x1, y1, z))
	st.add_vertex(Vector3(x0, y0, z))
	st.add_vertex(Vector3(x1, y1, z))
	st.add_vertex(Vector3(x0, y1, z))


# Vertical quad at constant x (ZY plane — west/east faces)
func _vquad_x(st: SurfaceTool, z0: float, z1: float, y0: float, y1: float, x: float) -> void:
	st.add_vertex(Vector3(x, y0, z0))
	st.add_vertex(Vector3(x, y0, z1))
	st.add_vertex(Vector3(x, y1, z1))
	st.add_vertex(Vector3(x, y0, z0))
	st.add_vertex(Vector3(x, y1, z1))
	st.add_vertex(Vector3(x, y1, z0))


func _add_box(root: Node3D, body: StaticBody3D,
			  mesh: BoxMesh, mat: StandardMaterial3D,
			  pos: Vector3, size: Vector3) -> void:
	# Physics collision
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = size
	col.shape = shp
	col.position = pos
	body.add_child(col)
	# Visual mesh
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	vis.position = pos
	root.add_child(vis)
