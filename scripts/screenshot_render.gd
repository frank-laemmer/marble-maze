extends Node

## Renders itch.io game screenshots at 1280×720.
## Open scenes/screenshot_render.tscn in Godot and press F6.
## Output: res://screenshots/screenshot_0*.png
##
## Re-run whenever tile colours, lighting, or marble shader changes.

const SIZE := Vector2i(1280, 720)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets")

	# ── 01  Martha's Maze — marble deep in the long central corridor ─────────────
	await _shot_game(
		"res://levels/level_05.txt",
		Vector3(22.0, 0.6, 42.0),   # row 10, col 5 — 7-tile open run
		Vector3(26.0, 11.0, 50.0),  # camera: right of marble, above, behind
		Vector3(22.0,  0.6, 42.0),  # look-at: marble
		62.0, "01:15",
		"screenshot_01_marthas_maze.png")

	# ── 02  Grey Skull — marble in centre of open jaw; camera from teeth side
	#        so dome is at top and skull shape reads correctly top-to-bottom.
	await _shot_game(
		"res://levels/level_11.txt",
		Vector3(30.0, 0.6, 42.0),   # row 10, col 7 — centre of open jaw
		Vector3(30.0, 24.0, 62.0),  # camera: behind skull (high Z), above
		Vector3(30.0,  0.6, 42.0),  # look-at: marble
		65.0, "00:18",
		"screenshot_02_grey_skull.png")

	# ── 03  Now you see me — marble beside the cyan Map tile cluster; the
	#        invisible walls around the level are intentionally imperceptible.
	await _shot_game(
		"res://levels/level_06.txt",
		Vector3(30.0, 0.6, 18.0),   # row 4, col 7 — floor right of Map tiles
		Vector3(36.0, 10.0, 28.0),  # camera: right and above, angled left
		Vector3(26.0,  0.0, 14.0),  # look-at: Map tile cluster
		62.0, "00:42",
		"screenshot_03_now_you_see_me.png")

	# ── 04  Look and see — marble on a Map tile; scattered cyan tile pattern visible
	await _shot_game(
		"res://levels/level_19.txt",
		Vector3(22.0, 0.6, 22.0),   # row 5, col 5 — Map tile, mid-level
		Vector3(22.0, 20.0, 40.0),  # camera: high above, looking down the pattern
		Vector3(22.0,  0.6, 22.0),  # look-at: marble
		65.0, "02:30",
		"screenshot_04_look_and_see.png")

	# ── 05  Level editor — Martha's Maze loaded in the editing view ──────────────
	await _shot_editor(
		"res://levels/level_05.txt",
		"screenshot_05_level_editor.png")

	print("All screenshots saved to res://assets/")
	get_tree().quit()


# ── Game viewport screenshot ──────────────────────────────────────────────────

func _shot_game(level_path: String, marble_pos: Vector3,
				cam_pos: Vector3, look_at: Vector3,
				fov: float, timer_text: String, filename: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var level := LevelLoader.build_from_file(level_path)
	if level:
		vp.add_child(level)

	var sphere := SphereMesh.new()
	sphere.radius          = 0.6
	sphere.height          = 1.2
	sphere.radial_segments = 64
	sphere.rings           = 32
	var marble_mat := ShaderMaterial.new()
	marble_mat.shader = preload("res://shaders/marble.gdshader")
	var marble_node := MeshInstance3D.new()
	marble_node.mesh              = sphere
	marble_node.material_override = marble_mat
	marble_node.position          = marble_pos
	vp.add_child(marble_node)

	var timer_lbl := Label.new()
	timer_lbl.text = timer_text
	timer_lbl.position = Vector2(SIZE.x * 0.5 - 28.0, 12.0)
	timer_lbl.add_theme_font_size_override("font_size", 30)
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vp.add_child(timer_lbl)

	var cam := Camera3D.new()
	cam.fov = fov
	cam.look_at_from_position(cam_pos, look_at)
	vp.add_child(cam)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://assets/" + filename)
	print("Saved -> res://assets/" + filename)
	vp.queue_free()
	await get_tree().process_frame


# ── Level-editor screenshot (2D UI scene) ────────────────────────────────────

func _shot_editor(level_path: String, filename: String) -> void:
	GameState.level_path           = level_path
	GameState.from_editor          = false
	GameState.editor_level_content = ""

	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var editor: Control = load("res://scenes/ui/level_editor.tscn").instantiate()
	vp.add_child(editor)

	# Wait for _ready() → _build_ui() to complete.
	await get_tree().process_frame
	await get_tree().process_frame

	var file := FileAccess.open(level_path, FileAccess.READ)
	if file:
		editor._load_from_string(file.get_as_text())
		file.close()

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://assets/" + filename)
	print("Saved -> res://assets/" + filename)
	vp.queue_free()
	await get_tree().process_frame
