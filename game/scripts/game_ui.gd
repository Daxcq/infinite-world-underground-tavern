class_name TavernUI
extends CanvasLayer

signal option_selected(index: int)
signal resume_requested
signal restart_requested
signal quit_requested
signal start_requested
signal leave_seat_requested
signal sensitivity_changed(value: float)
signal story_amount_changed(value: int)
signal story_die_clicked(index: int)
signal story_hand_requested
signal story_peek_requested
signal story_npc_changed(index: int)
signal observe_requested

const GOLD := Color("d8b477")
const PAPER := Color("e9dfca")
const MUTED := Color("a49d8c")

var root: Control
var objective: Label
var location: Label
var chapter_label: Label
var hint: Label
var prompt: PanelContainer
var prompt_text: Label
var dialogue: PanelContainer
var speaker: Label
var body: RichTextLabel
var choices: VBoxContainer
var veil: ColorRect
var menu: PanelContainer
var menu_box: VBoxContainer
var title_screen: Control
var seat_toolbar: HBoxContainer
var fade: ColorRect
var _text_progress: float = 0.0
var _choice_data: Array[String] = []
var _buttons: Array[Button] = []
var story_form: HBoxContainer
var story_details: RichTextLabel
var story_status: Label
var eye_veil: ColorRect
var observe_button: Button
var _option_meta: Array[Dictionary] = []
var _revision: int = 0
var _safe_focus: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = make_theme()
	eye_veil = ColorRect.new()
	eye_veil.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	eye_veil.anchor_right = 0.23
	eye_veil.color = Color(0.012, 0.008, 0.015, 0.96)
	eye_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(eye_veil)
	eye_veil.hide()
	var header := MarginContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_theme_constant_override("margin_left", 38)
	header.add_theme_constant_override("margin_right", 38)
	header.add_theme_constant_override("margin_top", 27)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var row := HBoxContainer.new()
	header.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(make_label("WORLD 20  /  THE LAST TAVERN", 13, GOLD))
	location = make_label("第二十号酒馆", 27, PAPER)
	left.add_child(location)
	var right := VBoxContainer.new()
	row.add_child(right)
	chapter_label = make_label("雨 夜 来 客", 14, GOLD)
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(chapter_label)
	objective = make_label("去吧台，与酒保交谈", 18, PAPER)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(objective)
	hint = make_label("WASD / 方向键  移动     Shift  快步     E  交互     Esc  暂停", 15, MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	story_status = make_label("", 16, GOLD)
	story_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	story_status.offset_left = 38
	story_status.offset_top = 108
	story_status.offset_bottom = 142
	root.add_child(story_status)
	observe_button = make_button("环顾桌面", func() -> void: observe_requested.emit())
	observe_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	observe_button.offset_left = -190
	observe_button.offset_right = -38
	observe_button.offset_top = 153
	observe_button.offset_bottom = 197
	root.add_child(observe_button)
	observe_button.hide()
	prompt = PanelContainer.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -200
	prompt.offset_right = 200
	prompt.offset_top = -110
	prompt.offset_bottom = -60
	root.add_child(prompt)
	prompt_text = make_label("", 18, PAPER)
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(prompt_text)
	prompt.hide()
	dialogue = PanelContainer.new()
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue.offset_left = 100
	dialogue.offset_right = -100
	dialogue.offset_top = -365
	dialogue.offset_bottom = -65
	root.add_child(dialogue)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	dialogue.add_child(content)
	speaker = make_label("", 17, GOLD)
	var heading_font := SystemFont.new()
	heading_font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC", "serif"])
	speaker.add_theme_font_override("font", heading_font)
	location.add_theme_font_override("font", heading_font)
	content.add_child(speaker)
	body = RichTextLabel.new()
	body.custom_minimum_size.y = 76
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = false
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("normal_font_size", 20)
	content.add_child(body)
	story_details = RichTextLabel.new()
	story_details.custom_minimum_size.y = 52
	story_details.add_theme_font_size_override("normal_font_size", 17)
	story_details.add_theme_color_override("default_color", MUTED)
	story_details.scroll_active = false
	content.add_child(story_details)
	story_form = HBoxContainer.new()
	story_form.add_theme_constant_override("separation", 12)
	content.add_child(story_form)
	story_form.hide()
	story_details.hide()
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	content.add_child(choices)
	dialogue.hide()
	seat_toolbar = HBoxContainer.new()
	seat_toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	seat_toolbar.offset_left = -208
	seat_toolbar.offset_right = -38
	seat_toolbar.offset_top = -112
	seat_toolbar.offset_bottom = -60
	root.add_child(seat_toolbar)
	var stand := make_button("起身返回", func() -> void: leave_seat_requested.emit())
	seat_toolbar.add_child(stand)
	seat_toolbar.hide()
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.018, 0.022, 0.022, 0.82)
	root.add_child(veil)
	veil.hide()
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -235
	menu.offset_right = 235
	menu.offset_top = -230
	menu.offset_bottom = 230
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu.add_child(menu_box)
	menu.hide()
	_build_title()
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.01, 0.012, 0.013, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("default_color", "RichTextLabel", PAPER)
	var panel := make_style(Color("151419"), Color("786044"), 22)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("normal", "Button", make_style(Color("211c24"), Color("695b40"), 12))
	theme.set_stylebox("hover", "Button", make_style(Color("38262f"), GOLD, 12))
	theme.set_stylebox("pressed", "Button", make_style(Color("54232d"), GOLD, 12))
	theme.set_stylebox("focus", "Button", make_style(Color(0, 0, 0, 0), GOLD, 12, 2))
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	return theme


func make_style(fill: Color, border: Color, padding: int, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func make_label(text: String, size_value: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button


func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_screen)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.028, 0.027, 0.78)
	title_screen.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 400
	content.add_theme_constant_override("separation", 21)
	center.add_child(content)
	for item: Array in [["第二十号世界", 15, GOLD], ["地下酒馆赌局", 44, PAPER], ["雨还在下。最后一盏灯，还没有熄。", 20, MUTED]]:
		var label := make_label(item[0], item[1], item[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
	var start := make_button("推门而入", func() -> void: start_requested.emit())
	content.add_child(start)
	content.add_child(make_button("退出", func() -> void: quit_requested.emit()))
	start.call_deferred("grab_focus")


func set_prompt(target: TavernInteractable) -> void:
	prompt.visible = target != null
	if target != null:
		prompt_text.text = "[ E ]  %s · %s" % [target.display_name, target.action_text]


func show_line(name_value: String, text: String, options: Array[String], meta: Array[Dictionary] = [], form_data: Dictionary = {}) -> void:
	_revision += 1
	dialogue.show()
	dialogue.offset_top = -280.0 if options.size() == 1 else -344.0
	if not meta.is_empty():
		var choices_height: float = maxi(0, options.size() - 1) * 8.0
		for option: Dictionary in meta:
			choices_height += _story_choice_height(option)
		var form_height: float = 56.0 if form_data.has("amount") or form_data.has("dice") or form_data.has("hand") or form_data.has("npcs") else 0.0
		dialogue.offset_top = -(65.0 + 44.0 + 24.0 + 76.0 + 52.0 + 40.0 + choices_height + form_height)
	prompt.hide()
	speaker.text = name_value
	body.text = text
	body.visible_characters = 0
	_text_progress = 0.0
	_choice_data = options
	_option_meta = meta
	_safe_focus = 0
	for index: int in range(meta.size()):
		if meta[index].get("event") == "CANCEL": _safe_focus = index
	story_details.visible = not meta.is_empty()
	story_details.text = form_data.get("summary", "")
	_build_story_form(form_data)
	_clear_choices()


func _process(delta: float) -> void:
	if dialogue.visible and not get_tree().paused and body.visible_characters < body.get_total_character_count():
		_text_progress += delta * 38.0
		body.visible_characters = mini(int(_text_progress), body.get_total_character_count())
		if body.visible_characters >= body.get_total_character_count():
			_show_choices()


func reveal() -> bool:
	if body.visible_characters < body.get_total_character_count():
		body.visible_characters = body.get_total_character_count()
		_show_choices()
		return true
	return false


func _clear_choices() -> void:
	for child: Node in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	_buttons.clear()


func _show_choices() -> void:
	if not _buttons.is_empty():
		return
	for index: int in range(_choice_data.size()):
		var shown_revision: int = _revision
		var button := make_button(_choice_data[index], func() -> void:
			if shown_revision == _revision: option_selected.emit(index)
		)
		if index < _option_meta.size():
			button.accessibility_name = _choice_data[index]
			button.accessibility_description = _option_meta[index].get("hint", "")
			button.disabled = not _option_meta[index].get("enabled", true)
			button.tooltip_text = _option_meta[index].get("hint", "")
			if not button.tooltip_text.is_empty():
				button.text = ""
				button.custom_minimum_size.y = _story_choice_height(_option_meta[index])
				var content := VBoxContainer.new()
				content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				content.offset_left = 14
				content.offset_right = -14
				content.offset_top = 7
				content.offset_bottom = -7
				content.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(content)
				content.add_child(make_label(_choice_data[index], 18, MUTED if button.disabled else PAPER))
				var description := make_label(button.tooltip_text, 14, MUTED)
				description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				content.add_child(description)
		choices.add_child(button)
		_buttons.append(button)
	if not _buttons.is_empty():
		var preferred: Button = _buttons[mini(_safe_focus, _buttons.size() - 1)]
		if not preferred.disabled: preferred.grab_focus()
		else:
			for button: Button in _buttons:
				if not button.disabled:
					button.grab_focus()
					break


func hide_dialogue() -> void:
	_revision += 1
	dialogue.hide()
	_clear_choices()


func show_pause(seated: bool, sensitivity: float) -> void:
	veil.show()
	menu.show()
	for child: Node in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	menu_box.add_child(make_label("烛火暂歇", 29, PAPER))
	menu_box.add_child(make_label("赌约仍在，下一步由你决定。", 16, MUTED))
	var resume := make_button("继续", func() -> void: resume_requested.emit())
	menu_box.add_child(resume)
	if seated:
		menu_box.add_child(make_button("起身返回酒馆", func() -> void: leave_seat_requested.emit()))
	var label := make_label("视角灵敏度", 16, GOLD)
	menu_box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.001
	slider.max_value = 0.005
	slider.step = 0.0002
	slider.value = sensitivity
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float) -> void: sensitivity_changed.emit(value))
	menu_box.add_child(slider)
	var music_bus := AudioServer.get_bus_index(&"Music")
	var music_label := make_label("音乐音量", 16, GOLD)
	menu_box.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.name = "MusicVolume"
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = AudioServer.get_bus_volume_linear(music_bus) * 100.0
	music_slider.custom_minimum_size.y = 28
	music_label.text = "音乐音量  %d%%" % roundi(music_slider.value)
	music_slider.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_linear(music_bus, value / 100.0)
		music_label.text = "音乐音量  %d%%" % roundi(value)
	)
	menu_box.add_child(music_slider)
	menu_box.add_child(make_button("重新开始", show_restart_confirmation))
	menu_box.add_child(make_button("退出游戏", func() -> void: quit_requested.emit()))
	resume.grab_focus()


func show_restart_confirmation() -> void:
	for child: Node in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	menu_box.add_child(make_label("重新推开这扇门？", 25, PAPER))
	menu_box.add_child(make_label("本次探索进度将重新开始。", 17, MUTED))
	var cancel := make_button("继续当前探索", func() -> void: resume_requested.emit())
	menu_box.add_child(cancel)
	menu_box.add_child(make_button("确认重新开始", func() -> void: restart_requested.emit()))
	cancel.grab_focus()


func hide_pause() -> void:
	veil.hide()
	menu.hide()


func _build_story_form(data: Dictionary) -> void:
	for child: Node in story_form.get_children():
		story_form.remove_child(child)
		child.queue_free()
	story_form.visible = data.has("amount") or data.has("dice") or data.has("hand") or data.has("npcs")
	if data.has("npcs"):
		story_form.add_child(make_label("桌边人物", 18, GOLD))
		var selector := OptionButton.new()
		selector.custom_minimum_size = Vector2(260, 44)
		for npc: Dictionary in data.npcs: selector.add_item(npc.name)
		selector.select(data.candidate)
		selector.item_selected.connect(func(index: int) -> void: story_npc_changed.emit(index))
		story_form.add_child(selector)
	if data.has("amount"):
		story_form.add_child(make_label("我的承诺", 18, GOLD))
		var input := SpinBox.new()
		input.min_value = 0
		input.max_value = data.get("maximum", 100)
		input.step = 1
		input.value = data["amount"]
		input.custom_minimum_size = Vector2(180, 44)
		input.value_changed.connect(func(value: float) -> void: story_amount_changed.emit(int(value)))
		story_form.add_child(input)
	for index: int in range(data.get("dice", []).size()):
		var die := make_button("%d" % data["dice"][index], func() -> void: story_die_clicked.emit(index))
		die.custom_minimum_size.x = 65
		die.toggle_mode = true
		die.button_pressed = data.get("selected", []).has(index)
		story_form.add_child(die)
	for index: int in range(data.get("hand", []).size()):
		var die := make_button("%d" % data["hand"][index], func() -> void: story_die_clicked.emit(index))
		die.custom_minimum_size.x = 65
		die.toggle_mode = true
		die.button_pressed = index == data.get("chosen", 0)
		story_form.add_child(die)
	if data.get("hand_control", false):
		story_form.add_child(make_button("放回托盘" if data.get("held", false) else "查看手骰", func() -> void: story_hand_requested.emit()))
	if data.get("peek", false):
		story_form.add_child(make_button("使用窥牌眼", func() -> void: story_peek_requested.emit()))


func _story_choice_height(option: Dictionary) -> float:
	var length: int = String(option.get("hint", "")).length()
	return 46.0 if length == 0 else (76.0 if length > 60 else 64.0)
