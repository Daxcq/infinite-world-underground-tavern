extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	print("%s: %s" % ["PASS" if value else "FAIL", message])


func peak(buffer: PackedVector2Array) -> float:
	var result: float = 0.0
	for sample: Vector2 in buffer:
		result = maxf(result, maxf(absf(sample.x), absf(sample.y)))
	return result


func run() -> void:
	create_timer(40.0, true).timeout.connect(func() -> void: quit(2))
	var music: AudioStreamPlayer = root.get_node("Music")
	var bus: int = AudioServer.get_bus_index(&"Music")
	check(music.playing and music.stream.loop, "Autoload starts a looping stream")
	check(absf(music.stream.get_length() - 126.5455) < 0.1, "Full track imported")
	check(absf(AudioServer.get_bus_volume_linear(bus) - 0.4) < 0.001, "Default music volume is 40 percent")
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	music.seek(30.0)
	await create_timer(0.4).timeout
	var audible_peak: float = peak(capture.get_buffer(capture.get_frames_available()))
	print("AUDIO: driver=%s, output_peak=%f" % [AudioServer.get_driver_name(), audible_peak])
	check(audible_peak > 0.001 and audible_peak < 1.0, "Master output contains non-clipping music samples")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_game()
	game.pause_game()
	var before_pause: float = music.get_playback_position()
	await create_timer(0.2, true).timeout
	check(music.get_playback_position() > before_pause, "Music continues while paused")
	var slider: HSlider = game.ui.menu_box.get_node("MusicVolume")
	slider.value = 0
	await create_timer(0.2, true).timeout
	capture.clear_buffer()
	await create_timer(0.2, true).timeout
	check(peak(capture.get_buffer(capture.get_frames_available())) < 0.00001, "Zero volume silences actual master output")
	slider.value = 70
	check(absf(AudioServer.get_bus_volume_linear(bus) - 0.7) < 0.001, "Slider changes music volume while paused")
	game.resume_game()
	game.greeted = true
	await game.enter_seat()
	check(music.get_playback_position() > before_pause, "First-person transition preserves music position")
	game.pause_game()
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = dimensions
		await create_timer(0.15, true).timeout
		var viewport_rect: Rect2 = game.get_viewport().get_visible_rect()
		check(viewport_rect.encloses(game.ui.menu.get_global_rect()), "Seated pause menu fits %s" % dimensions)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://verification/music_pause_%dx%d.png" % [dimensions.x, dimensions.y])
	game.restart_game()
	await process_frame
	await process_frame
	check(root.get_node("Music") == music and music.get_playback_position() > before_pause, "Restart preserves the same player and playback position")
	check(absf(AudioServer.get_bus_volume_linear(bus) - 0.7) < 0.001, "Restart preserves session music volume")
	check(root.find_children("*", "AudioStreamPlayer", true, false).size() == 1, "Restart creates no duplicate music players")
	music.seek(music.stream.get_length() - 0.08)
	await create_timer(0.35, true).timeout
	check(music.playing and music.get_playback_position() < 1.0, "Track loops across its actual ending")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	print("MUSIC: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)
