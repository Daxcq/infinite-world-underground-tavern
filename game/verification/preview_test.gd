extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/" + file + ".png")

func run() -> void:
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/table_view.tscn")
	await scene_changed
	var table := current_scene as TavernTableView
	print("STANDALONE: active=%s visible=%s camera=%s" % [table.active, table.visible, table.camera.current])
	if not table.active or not table.visible or not table.camera.current:
		quit(1)
		return
	await create_timer(0.5).timeout
	await capture("assets_seat")
	table.set_process(false)
	table.camera.position = Vector3(3.0, 2.8, 3.8)
	table.camera.look_at(Vector3(0, 0.8, -0.4))
	await capture("assets_overview")
	var start := Time.get_ticks_msec()
	for index: int in range(120):
		await process_frame
	print("PREVIEW: 120 frames in %d ms, rendered primitives %d" % [Time.get_ticks_msec()-start, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
