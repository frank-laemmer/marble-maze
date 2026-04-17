extends Node

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1024)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	# Ambient only — background won't be visible at this zoom level
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.45)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Marble mesh with its shader
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/marble.gdshader")

	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = mat
	viewport.add_child(mesh)

	# Key light — warm, upper-right
	var key := DirectionalLight3D.new()
	key.light_energy = 2.0
	key.rotation_degrees = Vector3(-40.0, 50.0, 0.0)
	viewport.add_child(key)

	# Rim light — cool blue, behind-left
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 0.5, -2.0)
	rim.light_color = Color(0.4, 0.55, 1.0)
	rim.light_energy = 1.0
	rim.omni_range = 10.0
	viewport.add_child(rim)

	# Camera — close in with narrow FOV so sphere fills and overflows the frame
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.05
	cam.position = Vector3(0.0, 0.0, 1.6)
	cam.look_at(Vector3.ZERO)
	viewport.add_child(cam)

	# Wait for the renderer to settle
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := viewport.get_texture().get_image()
	img.save_png("res://icon.png")
	print("Icon saved → res://icon.png")
	get_tree().quit()
