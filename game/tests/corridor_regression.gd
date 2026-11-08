extends SceneTree

var checks: int = 0
var failures: int = 0
var stage: Node3D


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	create_timer(45).timeout.connect(func() -> void: quit(1))
	stage = load("res://scenes/corridor_3d.tscn").instantiate()
	root.add_child(stage)
	await physics_frame
	await physics_frame
	check(stage.find_children("*", "Sprite3D", true, false).is_empty(), "Characters must be actual skinned meshes")
	check(stage.drinker.find_child("Skeleton3D", true, false) != null, "Drinker has a skeleton")
	check(stage.sleeper.find_child("Skeleton3D", true, false) != null, "Sleeper has a skeleton")
	check(stage.mug.get_parent() is BoneAttachment3D, "Cup is parented to the actual right-hand bone")
	check(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_NEAREST and absf(root.scaling_3d_scale - 1.0 / 3.0) < 0.001, "Pixel rendering uses nearest enlargement")
	# Real controller input toward table, chairs, walls and a seated person.
	var probes: Array = [
		[Vector3(0.1, 0.02, 0), Vector3(-1, 0, 0), 0.60, "table rim"],
		[stage.SEAT_POSITION + Vector3(0, 0.02, 0.9), Vector3(0, 0, -1), 0.40, "chair back"],
		[Vector3(3.35, 0.02, 3), Vector3(1, 0, 0), 0.35, "side wall"],
		[stage.drinker.position + Vector3(0, 0.02, 0.9), Vector3(0, 0, -1), 0.45, "seated guest"],
	]
	for probe: Array in probes:
		stage.player.position = probe[0]
		stage.player.velocity = Vector3.ZERO
		stage.update_camera(1)
		await physics_frame
		var start: Vector3 = stage.player.position
		var right: Vector3 = stage.explore_camera.global_basis.x
		var back: Vector3 = stage.explore_camera.global_basis.z
		right.y = 0
		back.y = 0
		right = right.normalized()
		back = back.normalized()
		var direction: Vector3 = probe[1]
		var determinant: float = right.x * back.z - back.x * right.z
		var x: float = (direction.x * back.z - back.x * direction.z) / determinant
		var y: float = (right.x * direction.z - direction.x * right.z) / determinant
		press_axis(&"move_left", &"move_right", x)
		press_axis(&"move_up", &"move_down", y)
		Input.action_press(&"sprint")
		for _frame: int in range(75):
			await physics_frame
		for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint"]:
			Input.action_release(action)
		var travel: float = (stage.player.position - start).dot(direction)
		check(travel <= float(probe[2]), "Cannot sprint through %s (travel %.3f)" % [probe[3], travel])
	# An open aisle is actually traversable, with the controller and gravity active.
	stage.player.position = Vector3(1, 0.02, 3)
	stage.player.velocity = Vector3.ZERO
	Input.action_press(&"move_up")
	for _frame: int in range(50):
		await physics_frame
	Input.action_release(&"move_up")
	check(stage.player.position.distance_to(Vector3(1, 0, 3)) > 0.9, "Can walk down the open aisle")
	check(absf(stage.player.position.y) < 0.05, "Player remains on floor")
	stage.player.position = stage.TABLE_CENTER + Vector3(0, 0, -2)
	check(not stage.can_sit(), "Cannot sit through the table from its opposite side")
	for _cycle: int in range(3):
		stage.player.position = stage.SEAT_POSITION + Vector3(0.80, 0, 0.1)
		var before: Vector3 = stage.player.position
		stage.sit()
		check(stage.seated and stage.seat_camera.current, "Sitting switches to first person")
		check(stage.player.collision_mask == 0, "Seat occupancy does not fight chair collision")
		stage.leave_seat()
		check(not stage.seated and stage.explore_camera.current, "Standing restores exploration")
		check(stage.player.position.distance_to(before) < 0.001 and stage.player.collision_mask == 1, "Standing restores a safe position and collision")
	stage.drink_animation.pause()
	var expected: Transform3D = stage.mug_grip
	var first_cup: Vector3
	for sample: int in range(25):
		stage.drink_animation.seek(sample / 6.0, true)
		stage.drink_skeleton.force_update_all_bone_transforms()
		await process_frame
		var hand: Transform3D = stage.drink_skeleton.global_transform * stage.drink_skeleton.get_bone_global_pose(stage.holding_hand)
		var grip: Transform3D = hand.affine_inverse() * stage.mug.global_transform
		check(grip.origin.distance_to(expected.origin) < 0.0001, "Mug remains fixed to hand throughout drinking %d" % sample)
		if sample == 0:
			first_cup = stage.mug.global_position
		if sample == 12:
			check(stage.mug.global_position.y - first_cup.y > 0.15, "Drinking genuinely raises the held cup")
	print("CORRIDOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func press_axis(negative: StringName, positive: StringName, value: float) -> void:
	Input.action_press(positive if value > 0 else negative, absf(value))
