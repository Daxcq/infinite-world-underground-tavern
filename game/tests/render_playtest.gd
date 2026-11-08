extends SceneTree

var game: Node
var output: String = "res://verification/"


func _initialize() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + filename + ".png")
	print("CAPTURE: " + filename)


func finish_dialogue() -> void:
	for _index: int in range(8):
		if game.mode != game.Mode.DIALOGUE:
			break
		game.ui.reveal()
		game._on_option(0)
		await process_frame


func run() -> void:
	create_timer(30.0, true).timeout.connect(func() -> void: quit(1))
	root.title = "酒馆画面验收"
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await capture("01_title_1280x800")
	game.start_game()
	await capture("02_entrance_1280x800")
	game.world.player.position = Vector2(485, 600)
	game.world.camera.reset_smoothing()
	await create_timer(0.5).timeout
	await capture("03_bar_1280x800")
	game.interact(&"bartender")
	game.ui.reveal()
	await capture("04_dialogue_1280x800")
	await finish_dialogue()
	game.interact(&"companion")
	await finish_dialogue()
	game.world.player.position = Vector2(450, 805)
	game.interact(&"table")
	game.ui.reveal()
	await capture("05_seat_confirmation_1280x800")
	game._on_option(0)
	await create_timer(0.7).timeout
	await capture("06_table_1280x800")
	game.table_view.look(Vector2(260, -50))
	await capture("07_companion_1280x800")
	game.pause_game()
	await capture("08_pause_1280x800")
	root.size = Vector2i(960, 600)
	await create_timer(0.2, true).timeout
	await capture("09_pause_960x600")
	game.resume_game()
	game.leave_seat()
	await create_timer(0.7).timeout
	game.interact(&"bartender")
	game.ui.reveal()
	await capture("10_dialogue_960x600")
	root.size = Vector2i(1600, 900)
	await create_timer(0.2, true).timeout
	await capture("11_dialogue_1600x900")
	print("RENDER_PLAYTEST_COMPLETE")
	quit(0)
