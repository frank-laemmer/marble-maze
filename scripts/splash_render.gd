extends Node

## Renders a 1920×1080 loading splash image — marble on dark background.
## Open scenes/splash_render.tscn and press F6, or: make splash
## Output: res://assets/splash.png

const SIZE := Vector2i(1920, 1080)

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var root := Node3D.new()
	vp.add_child(root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.30, 0.48)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_density = 0.03
	env.fog_light_color = Color(0.05, 0.05, 0.12)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 55, 0)
	key.light_energy = 2.0
	key.light_color = Color(1.0, 0.93, 0.86)
	key.shadow_enabled = true
	root.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-4, 3, -3)
	rim.light_energy = 2.5
	rim.light_color = Color(0.35, 0.42, 0.90)
	rim.omni_range = 14.0
	root.add_child(rim)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30, 30)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.07, 0.12)
	floor_mat.roughness = 0.85
	floor_mat.metallic = 0.15
	floor_mesh.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(0, -1.05, 0)
	root.add_child(floor_mi)

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var marble_mat := ShaderMaterial.new()
	marble_mat.shader = preload("res://shaders/marble.gdshader")
	var marble := MeshInstance3D.new()
	marble.mesh = sphere
	marble.material_override = marble_mat
	marble.rotation_degrees = Vector3(22, -35, 0)
	root.add_child(marble)

	# Camera — same angle as the main menu background, frozen at a nice frame
	var cam := Camera3D.new()
	cam.fov = 52.0
	cam.look_at_from_position(Vector3(2.2, 1.1, 3.2), Vector3(0.0, 0.1, 0.0))
	root.add_child(cam)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png("res://assets/splash.png")
	print("Splash saved → res://assets/splash.png")
	get_tree().quit()
