class_name TavernTableView
extends Node3D

@onready var camera: Camera3D = $SeatCamera

var active: bool = false
var sensitivity: float = 0.0022
var yaw: float = 0.0
var pitch: float = -0.28
var underground: UndergroundTable


func _ready() -> void:
	if get_tree().current_scene == self:
		get_window().title = "赌桌资产布置预览"
		activate()
	else:
		deactivate()


func activate() -> void:
	active = true
	visible = true
	yaw = 0
	pitch = -0.28
	camera.rotation = Vector3(pitch, yaw, 0)
	camera.make_current()
	set_process(true)


func deactivate() -> void:
	active = false
	visible = false
	camera.clear_current()
	set_process(false)


func look(relative: Vector2) -> void:
	var limit: float = PI if underground != null else 0.95
	yaw = clampf(yaw - relative.x * sensitivity, -limit, limit)
	pitch = clampf(pitch - relative.y * sensitivity, -0.85, 1.15 if underground != null else 0.30)
	camera.rotation = Vector3(pitch, yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	# F6 preview: drag with the left mouse button; main-game input is in main.gd.
	if get_tree().current_scene == self and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		look(event.screen_relative)


func _process(delta: float) -> void:
	if active:
		var limit: float = PI if underground != null else 0.95
		yaw = clampf(yaw - Input.get_axis(&"look_left", &"look_right") * delta, -limit, limit)
		camera.rotation = Vector3(pitch, yaw, 0)


func enter_underground(roster: Array) -> void:
	if underground != null: return
	$Characters.hide()
	for part: Node3D in $Room.get_children():
		part.visible = String(part.name).begins_with("Chair")
	$WarmTableLight.hide()
	$CoolWindowLight.hide()
	$SoftFrontLight.hide()
	underground = UndergroundTable.new()
	underground.name = "Underground"
	add_child(underground)
	underground.build(roster)
	$WorldEnvironment.environment = underground.environment


func focus_guest(index: int) -> void:
	if underground == null: return
	var target: Vector3 = underground.guests[index].global_position + Vector3(0, 1.25, 0)
	camera.look_at(target)
	yaw = camera.rotation.y
	pitch = camera.rotation.x
