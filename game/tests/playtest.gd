extends SceneTree

var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)


func frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func walk(action: StringName, count: int) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames(2)


func tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await frames(2)


func complete_dialogue() -> void:
	for _index: int in range(10):
		if game.mode != game.Mode.DIALOGUE:
			break
		game.ui.reveal()
		game._on_option(0)
		await process_frame


func run() -> void:
	# Wall-clock timeout also covers accidentally paused physics during a test.
	create_timer(40.0, true).timeout.connect(func() -> void:
		push_error("Playtest timed out")
		quit(1)
	)
	if await test_controls_and_flow() != true:
		failed += 1
		push_error("Playtest aborted before completion")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_controls_and_flow() -> bool:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(game.mode == game.Mode.TITLE, "Start screen blocks gameplay")
	check(not game.world.player.controls_enabled, "Movement disabled before entering")
	check(InputMap.action_get_events(&"move_up")[1].physical_keycode == KEY_UP, "Up arrow mapping")
	check(InputMap.action_get_events(&"move_left")[1].physical_keycode == KEY_LEFT, "Left arrow mapping")
	check(InputMap.action_get_events(&"move_down")[1].physical_keycode == KEY_DOWN, "Down arrow mapping")
	check(InputMap.action_get_events(&"move_right")[1].physical_keycode == KEY_RIGHT, "Right arrow mapping")
	check(InputMap.action_get_events(&"sprint")[0].physical_keycode == KEY_SHIFT, "Shift mapping")
	check(InputMap.action_get_events(&"fullscreen")[0].physical_keycode == KEY_F11, "F11 mapping")
	game.start_game()
	var player: TavernActor = game.world.player
	var from: Vector2 = player.position
	await walk(&"move_up", 25)
	var cardinal: float = from.distance_to(player.position)
	check(cardinal > 35 and cardinal < 80, "Physics input actually moves player")
	player.position = from
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	await frames(25)
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	await frames(2)
	var diagonal: float = from.distance_to(player.position)
	check(absf(diagonal - cardinal) < 5, "Diagonal movement has no speed advantage")
	check(player.velocity == Vector2.ZERO, "Key release stops movement")
	player.position = Vector2(485, 590)
	await walk(&"move_up", 60)
	check(player.position.y >= 538, "Bar and stools block player")
	player.position = Vector2(95, 1300)
	await walk(&"move_left", 30)
	check(player.position.x >= 88, "Left wall blocks player")
	player.position = Vector2(485, 1380)
	await walk(&"move_down", 30)
	check(player.position.y <= 1390, "Entrance boundary blocks leaving map")
	player.position = Vector2(236, 875)
	await walk(&"move_up", 45)
	check(player.position.y >= 884, "Chair blocks walking through furniture")
	player.position = Vector2(485, 600)
	await frames(3)
	check(game.current_target != null and game.current_target.interaction_id == &"bartender", "Bartender approachable from aisle")
	check(game.ui.prompt.visible, "Nearby target has visible prompt")
	await tap_key(KEY_E)
	check(game.mode == game.Mode.DIALOGUE, "Keyboard E opens nearby dialogue")
	from = player.position
	await walk(&"move_down", 15)
	check(player.position == from, "Dialogue locks movement")
	await tap_key(KEY_ESCAPE)
	check(game.mode == game.Mode.EXPLORE, "Escape cancels dialogue without pausing")
	check(not game.greeted, "Cancelling dialogue does not silently complete objective")
	game.interact(&"bartender")
	check(game.ui.reveal(), "First confirm reveals typewriter text")
	await complete_dialogue()
	check(game.greeted, "Completed conversation advances objective")
	check(player.controls_enabled, "Controls restored after dialogue")
	check(not game.ui.dialogue.visible, "Dialogue panel closes")
	await tap_key(KEY_ESCAPE)
	check(paused, "Keyboard Escape pauses exploration")
	await tap_key(KEY_ESCAPE)
	check(not paused, "Keyboard Escape resumes exploration")
	player.position = Vector2(642, 654)
	await frames(3)
	check(game.current_target != null and game.current_target.interaction_id == &"companion", "Companion reachable without crossing table")
	game.interact(&"companion")
	await complete_dialogue()
	check(game.met_companion, "Companion conversation completes")
	player.position = Vector2(450, 805)
	await frames(3)
	check(game.current_target != null and game.current_target.interaction_id == &"table", "Seat is reachable from central aisle")
	game.interact(&"table")
	game.ui.reveal()
	game._on_option(1)
	check(game.mode == game.Mode.EXPLORE and not game.visited_table, "Declining seat leaves exploration intact")
	game.interact(&"table")
	game.ui.reveal()
	game._on_option(0)
	await create_timer(0.7).timeout
	check(game.mode == game.Mode.DIALOGUE and game.flow.node_id == "T00", "Seat transition opens v2 teaching in first-person view")
	check(not game.world.visible and game.table_view.visible, "Only table world visible when seated")
	check(not player.controls_enabled, "Seated player cannot walk")
	game.table_view.look(Vector2(100000, 100000))
	check(absf(game.table_view.yaw) <= 0.95 and game.table_view.pitch >= -0.85, "Mouse look stays within seated observation limits")
	game.pause_game()
	check(paused and game.ui.menu.visible, "Pause menu opens and pauses world")
	game.resume_game()
	check(not paused and not game.ui.menu.visible, "Resume restores active state")
	game.leave_seat()
	await create_timer(0.7).timeout
	check(game.mode == game.Mode.EXPLORE and game.world.visible, "Leaving seat restores tavern")
	check(player.position.distance_to(Vector2(450, 805)) < 1, "Returning preserves safe player position")
	check(player.controls_enabled and game.greeted and game.met_companion, "Returning preserves progress and controls")
	await frames(3)
	check(game.ui.prompt.visible, "Interaction prompt returns after leaving seat")
	game.interact(&"table")
	game.ui.reveal()
	game._on_option(0)
	await create_timer(0.7).timeout
	game.leave_seat()
	await create_timer(0.7).timeout
	check(game.mode == game.Mode.EXPLORE and game.greeted, "Repeated seating keeps controls and progress valid")
	# Physical route proof: entrance -> bar -> companion -> seat, without teleports.
	player.position = Vector2(485, 1325)
	await walk(&"move_up", 277)
	check(player.position.y < 650, "Entrance-to-bar route unobstructed")
	# Approach the companion from the left, leaving room for coats and bags.
	await walk(&"move_right", 45)
	await walk(&"move_down", 28)
	var reached_companion: TavernInteractable = game.world.nearest_interaction()
	check(reached_companion != null and reached_companion.interaction_id == &"companion", "Bar-to-companion route reaches the actual conversation prompt")
	await walk(&"move_left", 60)
	await walk(&"move_down", 54)
	check(player.position.x > 390 and player.position.x < 480 and player.position.y > 750, "Companion-to-seat route unobstructed")
	current_scene = game
	game.restart_game()
	await process_frame
	await process_frame
	game = current_scene
	check(game.mode == game.Mode.TITLE and not game.greeted and not game.met_companion, "Restart clears progress and restores title")
	check(not paused, "Restart cannot leave the scene paused")
	game.queue_free()
	await process_frame
	return true
