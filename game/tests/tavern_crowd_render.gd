extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	var target := SubViewport.new()
	target.size = Vector2i(971, 1620)
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var world := load("res://scenes/tavern.tscn").instantiate() as Node2D
	target.add_child(world)
	world.camera.enabled = false
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	target.get_texture().get_image().save_png("res://verification/tavern_populated_full.png")
	var people: Node = world.live_people
	for center: Vector2 in people.TABLE_CENTERS:
		var origin: Vector3 = people.table_point(center) + Vector3(0, people.TABLE_HEIGHT, 0)
		var projected: Vector2 = people.camera_3d.unproject_position(origin) * people.MAP_SIZE / Vector2(people.viewport.size)
		print("TABLE_PROJECTION ", center, " -> ", projected, " error ", projected.distance_to(center))
	print("CROWD_RENDER_COMPLETE guests=", people.seated_guests.size(), " tables=", people.table_guests)
	quit(0)
