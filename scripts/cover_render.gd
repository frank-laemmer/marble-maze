extends Node

## Renders a 630×500 itch.io cover image — Labyrinthic gameplay + title.
## Open scenes/cover_render.tscn and press F6.
## Output: res://assets/cover.png

const SIZE := Vector2i(630, 500)

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# ── Level — Labyrinthic ────────────────────────────────────────────────────
	var level := LevelLoader.build_from_file("res://levels/level_02.txt")
	if level:
		vp.add_child(level)

	# ── Marble — row 7, col 6: middle of the long central corridor ────────────
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
	marble_node.position          = Vector3(26.0, 0.6, 30.0)
	vp.add_child(marble_node)

	# ── Camera — looking forward into the maze; marble sits in the lower half
	#    leaving dark sky at the top for the title text.
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.look_at_from_position(Vector3(26.0, 12.0, 46.0), Vector3(22.0, 2.0, 22.0))
	vp.add_child(cam)

	# ── "Marble Maze" — game title typography (matches splash_screen.gd) ──────
	var font := SystemFont.new()
	font.font_names  = PackedStringArray(["Helvetica", "Arial", "Liberation Sans", "sans-serif"])
	font.font_weight = 700

	var title := Label.new()
	title.text = "Marble Maze"
	title.position = Vector2(28.0, 24.0)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	vp.add_child(title)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://assets/cover.png")
	print("Cover saved -> res://assets/cover.png")
	get_tree().quit()
