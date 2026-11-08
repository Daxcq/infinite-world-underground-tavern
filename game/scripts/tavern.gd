class_name TavernWorld
extends Node2D

const ActorScene: PackedScene = preload("res://scenes/actor.tscn")
const Interaction = preload("res://scripts/interactable.gd")
const BACKGROUND: Texture2D = preload("res://assets/environment/tavern.png")
const PLAYER_SHEET: Texture2D = preload("res://assets/characters/player.png")
const PLAYER_WALK_SHEET: Texture2D = preload("res://assets/characters/motion/player_walk.png")
const BARTENDER_SHEET: Texture2D = preload("res://assets/characters/bartender.png")
const COMPANION_SHEET: Texture2D = preload("res://assets/characters/companion.png")
const LivePeople = preload("res://scripts/tavern_people_3d.gd")

var player: TavernActor
var camera: Camera2D
var sorted: Node2D
var interactables: Array[TavernInteractable] = []
var obstacles: Array[Rect2] = []
var live_people: Node2D


func _ready() -> void:
	sorted = Node2D.new()
	sorted.name = "DepthSortedActorsAndFurniture"
	sorted.y_sort_enabled = true
	add_child(sorted)
	# Ground-contact bounds, authored against the original 971 x 1620 painting.
	add_obstacle(Rect2(0, 0, 78, 1620))
	add_obstacle(Rect2(893, 0, 78, 1620))
	add_obstacle(Rect2(0, 0, 971, 528))
	add_obstacle(Rect2(0, 1400, 971, 220))
	for center: Vector2 in [Vector2(236, 760), Vector2(752, 760), Vector2(230, 1150), Vector2(750, 1150)]:
		add_obstacle(Rect2(center - Vector2(109, 56), Vector2(218, 112)))
		add_obstacle(Rect2(center + Vector2(-29, 53), Vector2(58, 63)))
		add_obstacle(Rect2(center + Vector2(-28, -129), Vector2(56, 57)))
	# Trace only furniture silhouettes: rectangular patches would hide nearby NPCs.
	for center: Vector2 in [Vector2(236, 741), Vector2(752, 741), Vector2(230, 1127), Vector2(750, 1127)]:
		add_table_occlusion(center)
	for x: float in [350, 428, 507, 587, 665]:
		add_obstacle(Rect2(x - 21, 520, 42, 26))
	add_actor(BARTENDER_SHEET, Vector2(486, 449), 0, 0.24, false)
	add_actor(COMPANION_SHEET, Vector2(680, 667), 0, 0.21, true)
	player = add_actor(PLAYER_SHEET, Vector2(486, 1325), 1, 0.21, false)
	player.name = "Player"
	# The live body's coat and shoulder bag need clearance as well as its feet.
	var player_collision := player.get_node("FeetCollision") as CollisionShape2D
	player_collision.shape = player_collision.shape.duplicate()
	(player_collision.shape as CircleShape2D).radius = 48.0
	# Keep the painted room and its existing controller; render actual people meshes.
	for actor: Node in sorted.get_children():
		if actor is TavernActor:
			actor.sprite.visible = false
	live_people = LivePeople.new()
	live_people.player_actor = player
	add_child(live_people)
	# A slim part of the front bar covers the bartender's lower body.
	var bar := Sprite2D.new()
	bar.texture = BACKGROUND
	bar.region_enabled = true
	bar.region_rect = Rect2(269, 405, 478, 136)
	bar.centered = false
	bar.position = Vector2(269, 541)
	bar.offset.y = -136
	sorted.add_child(bar)
	add_interaction(&"bartender", "酒保", "交谈", Vector2(485, 573), 82)
	add_interaction(&"companion", "落单的客人", "交谈", Vector2(641, 674), 77)
	add_interaction(&"table", "靠窗的空位", "查看赌桌", Vector2(398, 803), 74)
	add_interaction(&"window", "雨窗", "看看窗外", Vector2(200, 1358), 64)
	add_interaction(&"door", "来时的门", "查看出口", Vector2(485, 1374), 54)
	camera = Camera2D.new()
	camera.position = Vector2(485.5, 1200)
	camera.zoom = Vector2(1.34, 1.34)
	camera.limit_left = 0
	camera.limit_right = 971
	camera.limit_top = 0
	camera.limit_bottom = 1498
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()


func _process(_delta: float) -> void:
	camera.position = Vector2(485.5, player.position.y - 75.0)


func add_actor(texture: Texture2D, at: Vector2, initial_pose: int, scale_value: float, solid: bool) -> TavernActor:
	var actor := ActorScene.instantiate() as TavernActor
	actor.sheet = texture
	if texture == BARTENDER_SHEET:
		actor.foot_origins = PackedVector2Array([Vector2(268.5, 485), Vector2(256.1, 480)])
	elif texture == COMPANION_SHEET:
		actor.foot_origins = PackedVector2Array([Vector2(273.9, 493), Vector2(260.9, 494)])
	actor.pose = initial_pose
	actor.sprite_scale = scale_value
	if texture == PLAYER_SHEET:
		actor.walk_sheet = PLAYER_WALK_SHEET
		actor.sprite_scale = 0.47
	actor.position = at
	sorted.add_child(actor)
	if solid:
		add_obstacle(Rect2(at - Vector2(32, 26), Vector2(64, 52)))
	return actor


func add_obstacle(rect: Rect2) -> void:
	obstacles.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func add_table_occlusion(center: Vector2) -> void:
	var outline := PackedVector2Array()
	for index: int in range(32):
		var angle := TAU * float(index) / 32.0
		outline.append(center + Vector2(cos(angle) * 79.0, sin(angle) * 71.0))
	add_furniture_polygon(outline, center.y + 75)
	var north_chair := PackedVector2Array([
		center + Vector2(-23, -117), center + Vector2(24, -117),
		center + Vector2(27, -66), center + Vector2(-27, -66)
	])
	add_furniture_polygon(north_chair, center.y - 62)
	var south_chair := PackedVector2Array([
		center + Vector2(-28, 60), center + Vector2(28, 60),
		center + Vector2(25, 126), center + Vector2(-25, 126)
	])
	add_furniture_polygon(south_chair, center.y + 126)
	# Side chairs also need their own depth. Otherwise an actor behind one is
	# drawn over its backrest, despite the physical collision being present.
	for side: float in [-1.0, 1.0]:
		var chair := PackedVector2Array([
			center + Vector2(side * 108, -55), center + Vector2(side * 82, -43),
			center + Vector2(side * 79, 35), center + Vector2(side * 105, 50),
			center + Vector2(side * 119, 5)
		])
		add_furniture_polygon(chair, center.y + 55)


func add_furniture_polygon(points: PackedVector2Array, depth: float) -> void:
	var patch := Polygon2D.new()
	var local_points := PackedVector2Array()
	for point: Vector2 in points:
		local_points.append(point - Vector2(0, depth))
	patch.polygon = local_points
	patch.uv = points
	patch.texture = BACKGROUND
	patch.position = Vector2(0, depth)
	sorted.add_child(patch)


func add_interaction(id: StringName, label: String, verb: String, at: Vector2, range_value: float) -> void:
	var interaction := Interaction.new() as TavernInteractable
	interaction.interaction_id = id
	interaction.display_name = label
	interaction.action_text = verb
	interaction.position = at
	interaction.radius = range_value
	add_child(interaction)
	interactables.append(interaction)


func nearest_interaction() -> TavernInteractable:
	var nearest: TavernInteractable = null
	var best := INF
	for candidate: TavernInteractable in interactables:
		var distance := player.position.distance_to(candidate.position)
		if distance > candidate.radius or distance >= best:
			continue
		var query := PhysicsRayQueryParameters2D.create(player.position, candidate.position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		nearest = candidate
		best = distance
	return nearest
