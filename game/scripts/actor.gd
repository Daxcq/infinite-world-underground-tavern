class_name TavernActor
extends CharacterBody2D

@export var speed: float = 155.0
var controls_enabled: bool = false
var facing: Vector2 = Vector2.DOWN
@export var sheet: Texture2D
@export var walk_sheet: Texture2D
@export var pose: int = 0
@export var sprite_scale: float = 0.21
@export var foot_origins: PackedVector2Array = PackedVector2Array([Vector2(279.4, 462), Vector2(253.5, 463)])
@onready var sprite: Sprite2D = $Sprite2D
var walk_clock: float = 0.0
var walk_row: int = 1


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	sprite.texture = walk_sheet if walk_sheet != null else sheet
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.centered = false
	set_pose(pose)
	queue_redraw()


func set_pose(value: int) -> void:
	pose = value
	if sprite == null:
		return
	if walk_sheet != null:
		walk_row = 1 if pose == 1 else 0
		sprite.region_rect = Rect2(0, walk_row * 256, 256, 256)
		sprite.offset = Vector2(-128, -215)
		return
	# Atlas cells are static poses; they are never played as walking frames.
	sprite.region_rect = Rect2((pose % 3) * 512, (pose / 3 as int) * 512, 512, 512)
	# Anchor actual boots, not the bottom of a padded 512-pixel atlas cell.
	sprite.offset = -foot_origins[mini(pose, foot_origins.size() - 1)]


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		if walk_sheet != null:
			_update_walk(0.0, Vector2.ZERO)
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var target_speed := speed * (1.45 if Input.is_action_pressed(&"sprint") else 1.0)
	# Short acceleration, immediate braking: no drifting into an interactable.
	velocity = velocity.move_toward(direction * target_speed, 1800.0 * delta)
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
	else:
		facing = direction
		if walk_sheet == null:
			set_pose(1 if direction.y < -0.2 else 0)
		# Front/back poses are not side views; mirroring them shifts the boot pivot.
		sprite.flip_h = false
	move_and_slide()
	if walk_sheet != null:
		_update_walk(delta, direction)


func _update_walk(delta: float, direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			walk_row = 2 if direction.x < 0 else 3
		else:
			walk_row = 1 if direction.y < 0 else 0
	var frame_index: int = 0
	if controls_enabled and get_position_delta().length_squared() > 0.01:
		walk_clock += delta * get_real_velocity().length() / speed
		frame_index = 1 + int(walk_clock * 15.0) % 12
	else:
		walk_clock = 0.0
	sprite.region_rect = Rect2(frame_index * 256, walk_row * 256, 256, 256)


func _draw() -> void:
	draw_set_transform(Vector2(0, -3), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.28))
