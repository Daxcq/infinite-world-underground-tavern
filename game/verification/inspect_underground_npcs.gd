extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(480, 640)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("18191c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -45, 0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.3
	stage.add_child(camera)
	var index: int = 0
	for file: String in DirAccess.get_files_at("res://assets/npcs"):
		if not file.ends_with(".glb"): continue
		var model: Node3D = load("res://assets/npcs/" + file).instantiate()
		stage.add_child(model)
		var bounds := AABB()
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		print("NPC %d %s: %s" % [index, file, bounds])
		var center := bounds.get_center()
		camera.size = bounds.size.y * 1.15
		camera.position = center + Vector3(bounds.size.y * 2.0, 0.18, 0)
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/npc_%d.png" % index)
		model.queue_free()
		await process_frame
		index += 1
	quit()
