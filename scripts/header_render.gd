extends Node

## Render a 1920×622 itch.io banner — marble + title on transparent background.
## Open scenes/header_render.tscn in Godot and press F6.
## Output: res://assets/header.png

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 622)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# ── Lighting — no sky, ambient + two directional lights ──────────────────
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, 40.0, 0.0)
	key.light_energy     = 2.2
	key.shadow_enabled   = false  # no surface to cast on
	vp.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 220.0, 0.0)
	fill.light_energy     = 0.5
	vp.add_child(fill)

	# ── Marble — large, positioned right-of-centre ────────────────────────────
	var sphere := SphereMesh.new()
	sphere.radius          = 1.7
	sphere.height          = 3.4
	sphere.radial_segments = 128
	sphere.rings           = 64
	var marble_mat := ShaderMaterial.new()
	marble_mat.shader = preload("res://shaders/marble.gdshader")
	var marble := MeshInstance3D.new()
	marble.mesh              = sphere
	marble.material_override = marble_mat
	marble.position          = Vector3(3.5, 0.0, 0.0)
	vp.add_child(marble)

	# Camera: looking at origin, marble offset right → appears in right third.
	# FOV 32° keeps the sphere undistorted despite the wide 3:1 aspect.
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.look_at_from_position(Vector3(0.0, 1.5, 10.0), Vector3(0.0, 0.0, 0.0))
	vp.add_child(cam)

	# ── "Marble Maze" — game title typography (matches splash_screen.gd) ──────
	var font := SystemFont.new()
	font.font_names  = PackedStringArray(["Helvetica", "Arial", "Liberation Sans", "sans-serif"])
	font.font_weight = 700

	var title := Label.new()
	title.text = "Marble\nMaze"
	title.position = Vector2(80.0, 50.0)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 200)
	title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	vp.add_child(title)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://assets/header.png")
	print("Header saved -> res://assets/header.png")
	get_tree().quit()
