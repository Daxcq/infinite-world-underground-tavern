extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	var player: TavernActor = game.world.player
	check(player.sprite.texture.resource_path.ends_with("player_walk.png"), "Exploration player uses actual walking frames")
	var image := player.sprite.texture.get_image()
	for row: int in range(4):
		var left_stride := image.get_region(Rect2i(4 * 256, row * 256, 256, 256)).get_data()
		var right_stride := image.get_region(Rect2i(10 * 256, row * 256, 256, 256)).get_data()
		check(left_stride != right_stride, "Left and right strides contain visibly different limb frames: direction %d" % row)
	var anchor := player.sprite.offset
	for action: StringName in [&"move_down", &"move_up", &"move_left", &"move_right"]:
		player.position = Vector2(485, 1000)
		var frames: Dictionary = {}
		Input.action_press(action)
		for index: int in range(24):
			await physics_frame
			frames[player.sprite.region_rect.position] = true
		Input.action_release(action)
		await physics_frame
		await physics_frame
		check(frames.size() >= 4, "Walking advances limb frames: %s" % action)
		check(player.sprite.region_rect.position.x == 0, "Stopping selects a still idle frame: %s" % action)
		check(player.sprite.offset == anchor, "Animation keeps the collision/sort anchor fixed: %s" % action)
	var people: Node3D = game.table_view.get_node("Characters")
	for name_value: String in ["AdventurerLeft", "AdventurerRight"]:
		var person: Node3D = people.get_node(name_value)
		var animation_player := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(animation_player != null and animation_player.has_animation("seated"), "Table character has authored seated animation: %s" % name_value)
		if animation_player != null:
			check(animation_player.assigned_animation == "seated", "Table character holds the seated pose: %s" % name_value)
	game.queue_free()
	await process_frame
	print("ANIMATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
