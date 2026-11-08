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


func pick(event: String) -> void:
	if paused: game.resume_game()
	for _i: int in range(12):
		game.ui.reveal()
		if game._story_line < game.flow.lines().size() - 1 and not game._confirm_surrender:
			game._on_option(0)
			continue
		for index: int in range(game._story_options.size()):
			if game._story_options[index].event == event:
				check(game._story_options[index].enabled, "UI enables %s at %s" % [event, game.flow.node_id])
				game._on_option(index)
				if game.mode == game.Mode.TRANSITION: await create_timer(0.65, true).timeout
				await process_frame
				return
		check(false, "Missing UI event %s at %s" % [event, game.flow.node_id])
		return
	check(false, "Dialogue never reached choices")


func capture(name_value: String) -> void:
	game.ui.reveal()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/" + name_value + ".png")
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	for control: Control in [game.ui.dialogue, game.ui.body, game.ui.choices, game.ui.story_form]:
		if control.visible:
			var rect: Rect2 = control.get_global_rect()
			check(rect.end.y <= viewport_size.y + 1 and rect.end.x <= viewport_size.x + 1, "Controls fit viewport: %s" % name_value)


func read_node() -> void:
	for _i: int in range(12):
		game.ui.reveal()
		if game._confirm_surrender or game._story_line >= game.flow.lines().size() - 1: return
		game._on_option(0)


func run() -> void:
	create_timer(75.0, true).timeout.connect(func() -> void:
		push_error("Dialogue integration timed out")
		quit(1)
	)
	root.title = "地下酒馆 · 对话接入验收"
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if await play_path() != true: check(false, "Integration completed without runtime error")
	print("DIALOGUE_INTEGRATION: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


func play_path() -> bool:
	game.start_game()
	game.world.player.position = Vector2(485, 600)
	game.world.camera.reset_smoothing()
	game.interact(&"bartender")
	await capture("v2_01_bartender_1280x800")
	await pick("TAKE_WINE")
	await pick("DRINK_INTRO")
	check(game.greeted and game.mode == game.Mode.EXPLORE, "Wine returns player to exploration toward tutorial table")
	game.interact(&"table")
	game.ui.reveal()
	game._on_option(0)
	await create_timer(0.65, true).timeout
	check(game.flow.node_id == "T00" and game.table_view.active, "Physical seat enters teaching")
	await pick("CONTINUE")
	await pick("CONTINUE")
	var spin: SpinBox = game.ui.story_form.get_child(1)
	spin.value = 50
	check(game.flow.amount == 50, "Real SpinBox updates pledge amount")
	await capture("v2_02_pledge_1280x800")
	await pick("DECLARE_AMOUNT")
	read_node()
	await capture("v2_02b_choices_1280x800")
	await pick("SELECT_HONEST")
	read_node()
	check(game.ui._buttons[1].has_focus(), "Confirmation defaults to cancel")
	game.pause_game()
	var paused_revision: int = game.flow.revision
	game._on_option(0)
	check(game.flow.revision == paused_revision, "Paused confirmation cannot mutate flow")
	game.resume_game()
	check(game.ui._buttons[1].has_focus(), "Pause restores cancel focus")
	await pick("CONFIRM_STAKE")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE")
	game.flow.dice_p.assign([6, 4, 1])
	game.flow.dice_n.assign([3, 2, 1])
	game.flow.dice_dealer.assign([3, 3, 3])
	game.flow.state.npc_dice_locked = [0, 1]
	await pick("CONTINUE")
	await pick("KEEP_ONE")
	await pick("CONFIRM_DICE")
	await pick("CONTINUE_SYSTEM")
	await pick("PLAY_MORE")
	await pick("DRINK_DESCENT")
	await pick("CONTINUE_SYSTEM")
	check(game._underground_shown and not game.ui.seat_toolbar.visible, "Descent changes stage and locks leaving")
	check(game.table_view.underground != null and game.table_view.underground.guests.size() == game.flow.npc_roster.size(), "New underground stage and complete current NPC roster actually instantiate")
	await pick("CONTINUE")
	await pick("CONTINUE")
	await pick("INSPECT_NPC")
	var npc_selector := game.ui.story_form.get_child(1) as OptionButton
	npc_selector.select(4)
	npc_selector.item_selected.emit(4)
	check(game.flow.candidate == 4 and not game.flow.state.npc_selected, "Real NPC selector previews without committing")
	await pick("SELECT_NPC")
	check(game.flow.state.npc_id == "masked_man" and game.table_view.underground.selected_index == 4, "Selected identity and model reach the same table")
	await pick("CONTINUE")
	read_node()
	await capture("v2_03_contract_1280x800")
	game.flow.state.npc_kind = "OATH"
	await pick("CONFIRM_TRIO")
	await pick("CLAIM_READY")
	game.ui.story_form.get_child(1).value = 60
	await pick("DECLARE_AMOUNT")
	await pick("SELECT_HONEST")
	await pick("CONFIRM_STAKE")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE")
	game.flow.dice_p.assign([6, 4, 1])
	game.flow.dice_n.assign([3, 2, 1])
	game.flow.dice_dealer.assign([3, 3, 3])
	game.flow.state.npc_dice_locked = [0, 1]
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE")
	await pick("KEEP_ONE")
	game.ui.story_form.get_child(0).pressed.emit()
	game.ui.story_form.get_child(2).pressed.emit()
	check(game.flow.selected == [1, 2], "Real dice controls select individual dice")
	root.size = Vector2i(960, 600)
	await create_timer(0.15, true).timeout
	await capture("v2_04_pool_960x600")
	var dice_before: Array = game.flow.dice_p.duplicate()
	game.observe_table()
	game.table_view.look(Vector2(200, 0))
	game._present_story(true)
	check(game.flow.dice_p == dice_before and game.flow.selected == [1, 2], "Observe and return preserves dice and selection")
	await pick("CONFIRM_DICE")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE")
	await pick("PREPARE")
	await pick("BUY_PEEK")
	await pick("FINISH_PREP")
	game.ui.story_form.get_child(1).pressed.emit()
	check(game.flow.state.peek_used and game.flow.state.tool == "", "UI uses peek against locked opponent")
	await pick("SELECT_DIE")
	await pick("CONFIRM_CLEAR")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE_SYSTEM")
	await pick("OPEN_DOOR")
	check(game.flow.node_id == "E01" and game.world.visible and not game.table_view.visible, "Playable path returns to rain with all three fragments")
	root.size = Vector2i(1600, 900)
	await create_timer(0.15, true).timeout
	await capture("v2_05_escape_1600x900")
	# Separate fixture verifies loss presentation and irreversible surrender confirmation.
	game.flow = TavernDialogueFlow.new()
	game.flow._enter("C02")
	game.flow.state.underground = true
	game.flow.state.player_penalties = 2
	game.flow.held_dice = true
	game.world.hide()
	game.table_view.activate()
	game.ui.location.text = "地下 · 第二十席"
	game._story_line = 0
	game._present_story(true)
	await pick("CONFIRM_SURRENDER")
	game.ui.reveal()
	check(game._confirm_surrender and game.flow.state.player_penalties == 2, "Opening surrender confirmation does not charge organ")
	check(game.ui._buttons[0].has_focus(), "Surrender defaults to safe cancel")
	await pick("CANCEL")
	check(game.flow.state.player_penalties == 2, "Cancel surrender preserves heart")
	game.flow._enter("P03")
	game.flow.state.paid_organ = "HAND"
	game._story_line = 0
	game._present_story(true)
	await capture("v2_06_organ_1600x900")
	check(game.ui.eye_veil.visible and game.ui.dialogue.visible, "Eye veil is below readable dialogue")
	game.flow._enter("C02")
	game._story_line = 0
	game._present_story(true)
	await pick("CONFIRM_SURRENDER")
	await pick("SURRENDER_YES")
	await pick("CONTINUE_SYSTEM")
	await pick("CONTINUE_SYSTEM")
	check(game.flow.node_id == "P04" and game.flow.state.player_penalties == 3, "Confirmed third penalty consumes heart through actual settlement")
	await pick("CONTINUE_SYSTEM")
	check(game.flow.node_id == "E02" and game.table_view.camera.position.z < 0, "Failure ending moves camera to dealer seat")
	check(not game.ui.observe_button.visible, "Failure ending cannot resume normal observation")
	await capture("v2_07_dealer_1600x900")
	return true
