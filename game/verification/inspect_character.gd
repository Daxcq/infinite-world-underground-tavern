extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(600, 600)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("242b30")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d8e0ed")
	world.environment.ambient_light_energy = 0.7
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7
	stage.add_child(camera)
	camera.make_current()
	var files := DirAccess.get_files_at("res://assets/models")
	var index := 0
	for file: String in files:
		if file != "adventurer 3d model (1).glb":
			continue
		var model: Node3D = load("res://assets/models/" + file).instantiate()
		stage.add_child(model)
		var bounds := AABB()
		for mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		var center := bounds.get_center()
		camera.position = center + Vector3(2.0, 1.1, 2.4)
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/model_%02d.png" % index)
		print("MODEL %02d %s BOUNDS %s" % [index, file, bounds])
		model.queue_free()
		await process_frame
		index += 1
	quit()

