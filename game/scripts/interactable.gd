class_name TavernInteractable
extends Node2D

@export var interaction_id: StringName = &""
@export var display_name: String = ""
@export var action_text: String = "交谈"
@export var radius: float = 76.0
var highlighted: bool = false:
	set(value):
		if highlighted != value:
			highlighted = value
			queue_redraw()


func _draw() -> void:
	var tint := Color("d7b071")
	tint.a = 0.9 if highlighted else 0.32
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.45))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 40, tint, 1.5, true)
	draw_circle(Vector2.ZERO, 3.0, tint)
