extends Node

enum Mode { TITLE, EXPLORE, DIALOGUE, TRANSITION, SEATED }

var mode: Mode = Mode.TITLE
@onready var world: TavernWorld = $Tavern
@onready var ui: TavernUI = $GameUI
@onready var table_view: TavernTableView = $TableView
var current_target: TavernInteractable
var greeted: bool = false
var met_companion: bool = false
var visited_table: bool = false
var _lines: Array[Dictionary] = []
var _line_index: int = 0
var _dialogue_result: StringName = &""
var _option_count: int = 0
var flow := TavernDialogueFlow.new()
var _story_visible: bool = false
var _story_line: int = 0
var _story_options: Array[Dictionary] = []
var _story_revision: int = 0
var _story_node: String = ""
var _underground_shown: bool = false
var _ending_shown: bool = false
var _confirm_surrender: bool = false
var _resume_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.start_requested.connect(start_game)
	ui.option_selected.connect(_on_option)
	ui.resume_requested.connect(resume_game)
	ui.restart_requested.connect(restart_game)
	ui.quit_requested.connect(func() -> void: get_tree().quit())
	ui.leave_seat_requested.connect(leave_seat)
	ui.sensitivity_changed.connect(func(value: float) -> void: table_view.sensitivity = value)
	ui.story_amount_changed.connect(func(value: int) -> void: flow.amount = value)
	ui.story_die_clicked.connect(_on_story_die)
	ui.story_hand_requested.connect(_on_story_hand)
	ui.story_peek_requested.connect(_on_story_peek)
	ui.story_npc_changed.connect(_on_story_npc)
	ui.observe_requested.connect(observe_table)
	get_tree().root.focus_exited.connect(_on_focus_lost)
	if "--underground" in OS.get_cmdline_user_args():
		call_deferred("start_underground")


func start_underground() -> void:
	if mode != Mode.TITLE: return
	get_window().title = "地下 · 第二十席"
	ui.title_screen.hide()
	flow.state.initialized = true
	flow._enter("I01")
	greeted = true
	world.player.controls_enabled = false
	world.hide()
	table_view.activate()
	await _descend()


func start_game() -> void:
	if mode != Mode.TITLE:
		return
	ui.title_screen.hide()
	flow.send("START", flow.node_id, flow.revision)
	mode = Mode.EXPLORE
	world.player.controls_enabled = true
	_update_objective()


func _physics_process(_delta: float) -> void:
	if mode != Mode.EXPLORE or get_tree().paused:
		return
	var target := world.nearest_interaction()
	if target != current_target:
		if current_target != null:
			current_target.highlighted = false
		current_target = target
		if current_target != null:
			current_target.highlighted = true
		ui.set_prompt(current_target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		if get_tree().paused:
			resume_game()
		elif mode == Mode.DIALOGUE and (not _story_visible or not table_view.active):
			_end_dialogue(false)
		elif mode != Mode.TITLE and mode != Mode.TRANSITION:
			if get_tree().paused:
				resume_game()
			else:
				pause_game()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if mode == Mode.SEATED and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		table_view.look(event.screen_relative)
	elif mode == Mode.SEATED and event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		if mode == Mode.EXPLORE and current_target != null:
			interact(current_target.interaction_id)
		elif mode == Mode.SEATED:
			_present_story()
		elif mode == Mode.DIALOGUE:
			if not ui.reveal() and _option_count == 1:
				_on_option(0)
		get_viewport().set_input_as_handled()


func interact(id: StringName) -> void:
	match id:
		&"bartender":
			if flow.node_id in ["B01", "B02", "B03"]:
				_present_story()
			else:
				show_dialogue([line("酒保", "左边那张桌子还空着。先把规矩看清，再谈离开。")])
		&"companion":
			if not greeted:
				show_dialogue([line("落单的客人", "你也是刚进来的？先去吧台吧。他还没把你的名字写进账里。")])
			elif met_companion:
				show_dialogue([line("算计者", "左边那张桌子。你先坐，我随后就到。")])
			else:
				show_dialogue([
					line("落单的客人", "终于有人来了。先把桌上的规矩看清，再决定信不信我。"),
					line("你", "你在这里等了多久？"),
					line("算计者", "久到不想再数了。一起坐吧——至少现在，我们都想离开。")
				], &"met_companion")
		&"table":
			if not greeted:
				show_dialogue([line("靠窗的空位", "桌沿刻着三个座位的记号。"), line("你", "先和酒保、那位落单的客人聊聊，再决定是否入座。")])
			else:
				show_dialogue([{"speaker": "靠窗的空位", "text": "灯光落在空椅子上。要坐下来看看吗？", "options": ["确认落座", "再逛一会儿"]}], &"seat")
		&"window":
			show_dialogue([line("雨窗", "雨水把窗外的街道连成一片。来时的路，已经看不清了。")])
		&"door":
			show_dialogue([line("来时的门", "门把手冰凉。外面只剩雨声。"), line("你", "先在这里找个落脚的地方。")])


func line(name_value: String, text: String) -> Dictionary:
	return {"speaker": name_value, "text": text, "options": ["继续  [ E / Enter ]"]}


func show_dialogue(lines: Array[Dictionary], result: StringName = &"") -> void:
	mode = Mode.DIALOGUE
	world.player.controls_enabled = false
	world.player.velocity = Vector2.ZERO
	_lines = lines
	_line_index = 0
	_dialogue_result = result
	_present_line()


func _present_line() -> void:
	var current: Dictionary = _lines[_line_index]
	var options: Array[String] = []
	options.assign(current["options"])
	_option_count = options.size()
	ui.show_line(current["speaker"], current["text"], options)


func _on_option(index: int) -> void:
	if mode != Mode.DIALOGUE or get_tree().paused:
		return
	if ui.reveal():
		return
	if _story_visible:
		_on_story_option(index)
		return
	if _dialogue_result == &"seat":
		_end_dialogue(false)
		if index == 0:
			enter_seat()
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_end_dialogue(true)
	else:
		_present_line()


func _end_dialogue(completed: bool) -> void:
	_story_visible = false
	if completed:
		if _dialogue_result == &"met_companion":
			met_companion = true
	ui.hide_dialogue()
	mode = Mode.EXPLORE
	world.player.controls_enabled = true
	_update_objective()
	# Clear selection so the exploration loop restores its contextual prompt.
	if current_target != null:
		current_target.highlighted = false
	current_target = null


func enter_seat() -> void:
	if mode == Mode.TRANSITION or not greeted:
		return
	mode = Mode.TRANSITION
	world.player.controls_enabled = false
	ui.prompt.hide()
	await _fade_to(1.0)
	world.hide()
	table_view.activate()
	ui.location.text = "靠窗的赌桌"
	ui.objective.text = "观察桌面、荷官与同伴"
	ui.hint.text = "移动鼠标 / A、D  环顾     Esc  暂停或起身"
	ui.seat_toolbar.show()
	visited_table = true
	await _fade_to(0.0)
	mode = Mode.SEATED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_present_story()


func leave_seat() -> void:
	if not table_view.active or bool(flow.state.underground):
		return
	get_tree().paused = false
	ui.hide_pause()
	ui.hide_dialogue()
	ui.observe_button.hide()
	_story_visible = false
	mode = Mode.TRANSITION
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade_to(1.0)
	table_view.deactivate()
	world.show()
	world.camera.make_current()
	ui.seat_toolbar.hide()
	ui.location.text = "第二十号酒馆"
	ui.hint.text = "WASD / 方向键  移动     Shift  快步     E  交互     Esc  暂停"
	await _fade_to(0.0)
	mode = Mode.EXPLORE
	world.player.controls_enabled = true
	_update_objective()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", alpha, 0.24)
	await tween.finished


func _update_objective() -> void:
	if not greeted:
		ui.objective.text = "去吧台，与酒保交谈"
	elif flow.node().get("phase") == "TUTORIAL":
		ui.objective.text = "前往左侧圆桌的空位，继续教学"
	elif not visited_table:
		ui.objective.text = "前往左侧圆桌的空位，确认落座"
	else:
		ui.objective.text = "继续探索酒馆，或再次落座"


func pause_game() -> void:
	if mode == Mode.TITLE or mode == Mode.TRANSITION:
		return
	_resume_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_pause(table_view.active and not bool(flow.state.underground), table_view.sensitivity)


func resume_game() -> void:
	get_tree().paused = false
	ui.hide_pause()
	if mode == Mode.SEATED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif _story_visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(_resume_focus) and _resume_focus.is_visible_in_tree():
			_resume_focus.grab_focus()
		elif not ui._buttons.is_empty():
			for button: Button in ui._buttons:
				if not button.disabled:
					button.grab_focus()
					break


func restart_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_focus_lost() -> void:
	if DisplayServer.get_name() != "headless" and not get_tree().paused:
		pause_game()


func _present_story(reveal_text: bool = false) -> void:
	var content: Array[Dictionary] = flow.lines()
	if content.is_empty():
		return
	_story_line = mini(_story_line, content.size() - 1)
	_story_visible = true
	mode = Mode.DIALOGUE
	world.player.controls_enabled = false
	world.player.velocity = Vector2.ZERO
	table_view.set_process(false)
	ui.seat_toolbar.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_story_node = flow.node_id
	_story_revision = flow.revision
	_story_options.assign(flow.options() if _story_line == content.size() - 1 else [{"event": "NEXT", "text": "继续", "enabled": true}])
	if _confirm_surrender:
		var organ: String = ["眼", "手", "心"][mini(2, int(flow.state.player_penalties))]
		content = [{"speaker": "荷官", "text": "认负后将支付%s。你还可以把这句话收回去。" % organ}]
		_story_line = 0
		_story_options = [{"event": "CANCEL", "text": "再检查一次", "enabled": true}, {"event": "SURRENDER_YES", "text": "确认认负", "enabled": true}]
	elif flow.node_id == "C02":
		for option: Dictionary in _story_options:
			if option.event == "CONFIRM_SURRENDER": option.enabled = true
	var labels: Array[String] = []
	for option: Dictionary in _story_options:
		labels.append(option["text"])
	_option_count = labels.size()
	var form: Dictionary = {"summary": _story_summary()}
	if flow.node_id in ["N00", "N01"]:
		form.merge({"npcs": flow.npc_roster, "candidate": flow.candidate})
	if flow.node_id in ["T01A", "F10A"]:
		form.merge({"amount": flow.amount, "maximum": int(flow.state.gold) if flow.node_id == "T01A" else flow.funds()})
	if flow.node_id in ["T11", "F23"]:
		form.merge({"dice": flow.dice_p, "selected": flow.selected})
	if flow.node_id == "C03":
		form.merge({"hand": flow.hand_p, "chosen": flow.chosen, "peek": flow.state.tool == "窥牌眼"})
	if flow.node_id in ["C01", "C02", "C03"] and int(flow.state.player_penalties) >= 2:
		form.merge({"hand_control": true, "held": flow.held_dice})
		if not form.has("hand"): form["hand"] = []
	ui.show_line(content[_story_line]["speaker"], content[_story_line]["text"], labels, _story_options, form)
	ui.observe_button.visible = table_view.active and flow.blocked.is_empty() and flow.node().get("phase") != "END" and flow.node_id != "P04"
	ui.hint.text = "E  显示整句 / 继续     ↑ ↓ / Tab  选择     Enter  确认     Esc  暂停"
	ui.story_status.text = _progress_text()
	ui.chapter_label.text = {"SURFACE": "雨夜来客", "TUTORIAL": "普通赌局 · 教学", "DESCENT": "幽光与幻觉", "TABLE_SETUP": "以身作保", "STAKE": "第一契 · 合注", "POOL": "第二契 · 共渡", "CLEAR": "第三契 · 清桌", "SETTLEMENT": "责任与代价", "END": "终幕"}.get(flow.node().get("phase", ""), "")
	ui.objective.text = flow.node().get("title", "")
	ui.eye_veil.visible = table_view.active and int(flow.state.player_penalties) >= 1
	if reveal_text: ui.reveal()


func _on_story_option(index: int) -> void:
	if index < 0 or index >= _story_options.size(): return
	var option: Dictionary = _story_options[index]
	if not option.get("enabled", true): return
	var event: String = option["event"]
	if event == "CONFIRM_SURRENDER":
		_confirm_surrender = true
		_present_story()
		return
	if _confirm_surrender:
		_confirm_surrender = false
		if event == "CANCEL":
			_present_story(true)
			return
		flow.state.surrender_confirmed = true
		event = "CONFIRM_SURRENDER"
	if event == "NEXT":
		_story_line += 1
		_present_story()
		return
	if event == "TITLE":
		restart_game()
		return
	if not flow.send(event, _story_node, _story_revision): return
	if event == "SELECT_NPC" and table_view.underground != null:
		table_view.underground.seat_guest(flow.candidate)
		table_view.yaw = 0
		table_view.pitch = -0.28
		table_view.camera.rotation = Vector3(-0.28, 0, 0)
	_story_line = 0
	if flow.node_id == "T00" and not table_view.active:
		greeted = true
		_end_dialogue(false)
	elif flow.node_id == "I01" and not _underground_shown:
		_descend()
	elif flow.node_id == "E01" and not _ending_shown:
		_return_to_rain()
	else:
		if flow.node_id == "E02":
			table_view.camera.position = Vector3(0, 1.5, -2.6)
			table_view.camera.rotation = Vector3(-0.3, PI, 0)
		_present_story()


func _on_story_die(index: int) -> void:
	if not _story_visible: return
	if flow.node_id == "C03": flow.chosen = index
	else: flow.toggle_die(index)
	_present_story(true)


func _on_story_npc(index: int) -> void:
	if not _story_visible or not flow.choose_candidate(index): return
	table_view.focus_guest(index)
	_present_story(true)


func _on_story_hand() -> void:
	flow.held_dice = not flow.held_dice
	_present_story(true)


func _on_story_peek() -> void:
	flow.use_peek()
	_present_story(true)


func observe_table() -> void:
	if not table_view.active or mode != Mode.DIALOGUE: return
	ui.hide_dialogue()
	ui.observe_button.hide()
	_story_visible = false
	mode = Mode.SEATED
	table_view.set_process(true)
	ui.seat_toolbar.visible = not bool(flow.state.underground)
	ui.hint.text = "移动鼠标 / A、D  环顾     E  返回当前抉择     Esc  暂停"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _descend() -> void:
	_underground_shown = true
	mode = Mode.TRANSITION
	ui.hide_dialogue()
	ui.observe_button.hide()
	await _fade_to(1.0)
	ui.location.text = "地下 · 第二十席"
	ui.seat_toolbar.hide()
	table_view.enter_underground(flow.npc_roster)
	await _fade_to(0.0)
	_present_story()


func _return_to_rain() -> void:
	_ending_shown = true
	mode = Mode.TRANSITION
	ui.hide_dialogue()
	await _fade_to(1.0)
	table_view.deactivate()
	world.show()
	world.camera.make_current()
	ui.eye_veil.hide()
	ui.observe_button.hide()
	ui.seat_toolbar.hide()
	ui.location.text = "地上 · 来时的门"
	await _fade_to(0.0)
	_present_story()


func _progress_text() -> String:
	var keys: Dictionary = flow.state["keys"]
	return "合注%s  共渡%s  清桌%s    ｜    眼%s  手%s  心%s" % [
		"已得" if keys.has("STAKE") else "未得", "已得" if keys.has("POOL") else "未得", "已得" if keys.has("CLEAR") else "未得",
		"封存" if int(flow.state.player_penalties) > 0 else "尚存", "封存" if int(flow.state.player_penalties) > 1 else "尚存", "封存" if int(flow.state.player_penalties) > 2 else "尚存"]


func _story_summary() -> String:
	var values: Dictionary = flow.variables()
	var text: String = "筹码 %d（私藏 %d）  ｜  公共奖池 %d" % [flow.funds(), int(flow.state.private_chips), int(flow.state.public_pot)] if flow.state.underground else "教学金币 %d  ｜  恢复酒 %d" % [int(flow.state.gold), int(flow.state.rescue_wine_count)]
	if flow.node_id in ["T11", "F23"]: text += "\n投入 %d 点；保留 %s。" % [values.selected_total, values.reserve_text]
	if flow.node_id in ["F20", "F21", "F22", "F23"]:
		if flow.state.open_p: text += "\n明牌诅咒：你的三骰已公开。"
		if flow.state.open_n: text += "\n同伴明牌：%s。" % str(flow.dice_n)
	if not flow.feedback.is_empty(): text += "\n" + flow.feedback
	elif flow.state.peek_used and not flow.hand_n.is_empty(): text += "\n对方已锁定暗骰：%d 点。" % flow.hand_n[int(flow.state.opponent_index)]
	return text
