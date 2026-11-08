extends SceneTree

var game: Node
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(label)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/underground_" + label + ".png")


func run() -> void:
	create_timer(90.0, true).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_underground()
	await create_timer(0.7, true).timeout
	if paused: game.resume_game()
	check(game.flow.state.underground and game._underground_shown, "Direct entry reaches actual underground flow")
	var table: TavernTableView = game.table_view
	var stage: UndergroundTable = table.underground
	check(stage != null and not game.world.visible, "Underground stage replaces surface")
	check(not table.get_node("Characters").visible and not table.get_node("Room/Floor").visible, "Old room and duplicate characters hidden")
	check(stage.guests.size() == 7 and stage.bartender != null, "All seven distinct NPCs and bartender present")
	check(stage.get_node("Spectators").get_child_count() == 32, "Distant spectators surround table")
	check(stage.spotlight.shadow_enabled and stage.environment.ambient_light_energy < 0.1, "Strong overhead light in dark environment")
	table.look(Vector2(0, -10000))
	check(table.pitch > 1.0, "Player can look up at overhead light")
	table.look(Vector2(10000, 0))
	check(absf(table.yaw) > 3.0, "Player can inspect guests behind the seat")
	table.yaw = 0
	table.pitch = -0.28
	table.camera.rotation = Vector3(-0.28, 0, 0)
	game.flow._enter("N00")
	game._story_line = 0
	game._present_story(true)
	await capture("choose")
	var selector := game.ui.story_form.get_child(1) as OptionButton
	check(selector.item_count == game.flow.npc_roster.size(), "Every table-side NPC offered by real UI")
	var money: int = game.flow.funds()
	for index: int in range(selector.item_count):
		game._on_story_npc(index)
		check(game.flow.candidate == index and not game.flow.state.npc_selected and game.flow.funds() == money, "Inspect %d does not commit or charge" % index)
		check(game._story_revision == game.flow.revision, "Candidate refresh keeps UI revision current")
		game.flow._enter("N01")
		game._story_line = 0
		game._present_story(true)
		check(game.flow.send("SELECT_NPC", game.flow.node_id, game.flow.revision), "Candidate %d can be selected" % index)
		check(game.flow.state.npc_id == game.flow.npc_roster[index].id, "Chosen identity survives selection")
		stage.seat_guest(index)
		check(stage.guests[index].position.distance_to(Vector3(1.38, 0, -0.38)) < 0.01, "Chosen model occupies third place")
		if index > 0:
			check(stage.guests[index - 1].position == stage.ring_positions[index - 1], "Previous guest returns to spectators")
		game.flow.state.npc_selected = false
		game.flow._enter("N00")
		game._story_line = 0
		game._present_story(true)
	stage.seat_guest(4)
	game.ui.hide_dialogue()
	game.ui.observe_button.hide()
	table.camera.rotation = Vector3(-0.18, 0, 0)
	table.yaw = 0
	table.pitch = -0.18
	await capture("seated")
	table.camera.rotation = Vector3(0.9, 0, 0)
	await capture("overhead")
	table.camera.position = Vector3(4.8, 4.3, 5.8)
	table.camera.look_at(Vector3(0, 1.0, 0))
	await capture("overview")
	table.camera.position = Vector3(0, 1.38, 1.6)
	table.camera.rotation = Vector3(-0.18, 0, 0)
	game.flow._enter("N01")
	game._story_line = 0
	game._present_story(true)
	root.size = Vector2i(960, 600)
	await create_timer(0.2, true).timeout
	await capture("choose_960")
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	check(game.ui.story_form.get_global_rect().end.x < viewport_size.x and game.ui.dialogue.get_global_rect().position.y >= 0, "Selection fits 960x600")
	game.flow._enter("F10")
	check(not game.flow.choose_candidate(1), "Committed table cannot change NPC")
	game.leave_seat()
	check(not game.world.visible, "Cannot leave underground table through surface action")
	print("UNDERGROUND: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
