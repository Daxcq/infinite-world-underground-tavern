extends SceneTree

var stage: Node3D
const OUTPUT: String = "res://verification/corridor_"


func _initialize() -> void:
	call_deferred("run")


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("CAPTURE ", label)


func run() -> void:
	create_timer(45).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1440, 900)
	stage = load("res://scenes/corridor_3d.tscn").instantiate()
	root.add_child(stage)
	await create_timer(1).timeout
	await capture("overview")
	stage.drink_animation.pause()
	stage.sleep_animation.pause()
	stage.drink_animation.seek(0, true)
	stage.detail_camera.make_current()
	await create_timer(0.15).timeout
	await capture("contact_rest")
	stage.drink_animation.seek(2.0, true)
	await create_timer(0.15).timeout
	await capture("contact_drink")
	stage.detail_camera.position = stage.TABLE_CENTER + Vector3(2.3, 1.75, -2.3)
	stage.detail_camera.look_at(stage.sleeper.position + Vector3(0, 0.8, 0.35))
	await capture("contact_sleep")
	stage.player.position = stage.SEAT_POSITION + Vector3(0.80, 0, 0.1)
	stage.sit()
	await create_timer(0.2).timeout
	await capture("seated")
	print("CORRIDOR_RENDER_COMPLETE")
	quit(0)
