extends SceneTree

var failures: int = 0
var checks: int = 0


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
	var player: TavernActor = game.world.player
	# Rendered walking frames share one floor/sorting anchor in all directions.
	for pose: int in [0, 1]:
		player.set_pose(pose)
		var floor_anchor := Vector2(128, 215)
		check((floor_anchor + player.sprite.offset).length() < 1.0, "Rendered floor anchor aligns with sorting origin for pose %d" % pose)
	var people: Node3D = game.table_view.get_node("Characters")
	check(people.get_child_count() == 4, "Four supplied adventurer instances must be present")
	for person: Node3D in people.get_children():
		var bounds := model_bounds(person)
		if person.name in [&"AdventurerLeft", &"AdventurerRight"]:
			var skeleton := person.find_child("Skeleton3D", true, false) as Skeleton3D
			var hip := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Pelvis")).origin
			var knee := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("L_Calf")).origin
			check(hip.y > 0.48 and hip.y < 0.70, "Seated hips are supported at chair height: %s" % person.name)
			check(knee.y < 0.70, "Seated knees clear the underside of the tabletop: %s" % person.name)
			check(Vector2(hip.x, hip.z).length() > 1.20, "Seated torso clears the table rim: %s" % person.name)
			continue
		# Rest-mesh bounds exclude skin deformation; inspect boot contact in renders.
		check(absf(bounds.size.y - 1.76) < 0.01, "Adventurer height stays at human scale: %s" % person.name)
		var nearest := Vector2(clampf(0, bounds.position.x, bounds.end.x), clampf(0, bounds.position.z, bounds.end.z))
		check(nearest.length() > 1.16, "Adventurer bounds must clear the table rim: %s" % person.name)
	check(game.table_view.find_children("*", "Sprite3D", true, false).is_empty(), "3D models replace the seated sprite cards")
	var table_bounds := model_bounds(game.table_view.get_node("Table"))
	check(absf(table_bounds.position.y) < 0.01 and absf(table_bounds.end.y - 0.84) < 0.01, "Imported table is grounded with a 0.84 m rim")
	var tray_bounds := model_bounds(game.table_view.get_node("Props/MetalTray"))
	check(absf(tray_bounds.position.y - 0.8091) < 0.01, "Tray base rests on the recessed tabletop")
	for die_name: String in ["BrassDie", "GoldDie", "GlassDie"]:
		var die_bounds := model_bounds(game.table_view.get_node("Props/" + die_name))
		check(absf(die_bounds.position.y - 0.8831) < 0.01, "Tray die rests on the tray floor: %s" % die_name)
	for prop_name: String in ["TransparentDie", "HeartDie", "OrnateKey"]:
		var prop_bounds := model_bounds(game.table_view.get_node("Props/" + prop_name))
		check(absf(prop_bounds.position.y - 0.8121) < 0.01, "Loose prop rests on the tabletop: %s" % prop_name)
	var sources: Dictionary = {}
	for model: Node in game.table_view.find_children("Model", "", true, false):
		if sources.has(model.scene_file_path):
			continue
		sources[model.scene_file_path] = true
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			meshes.append(model)
		check(not meshes.is_empty(), "Imported model has geometry: %s" % model.scene_file_path)
		for mesh: MeshInstance3D in meshes:
			var surface := mesh.get_active_material(0) as BaseMaterial3D
			check(surface != null and surface.albedo_texture != null, "Imported model retains its texture: %s" % model.scene_file_path)
	check(sources.size() == 14, "Props, standing originals and the repaired animated derivative are instantiated")
	game.start_game()
	for center: Vector2 in [Vector2(236, 760), Vector2(752, 760), Vector2(230, 1150), Vector2(750, 1150)]:
		player.position = center + Vector2(0, 145)
		Input.action_press(&"move_up")
		Input.action_press(&"sprint")
		for _frame: int in range(30):
			await physics_frame
		Input.action_release(&"move_up")
		Input.action_release(&"sprint")
		await physics_frame
		check(player.position.y >= center.y + 129.5, "Fast movement cannot pass through front chair at %s" % center)
		var side: float = 1.0 if center.x < 485 else -1.0
		var action: StringName = &"move_left" if side > 0 else &"move_right"
		player.position = center + Vector2(side * 160, 0)
		Input.action_press(action)
		Input.action_press(&"sprint")
		for _frame: int in range(30):
			await physics_frame
		Input.action_release(action)
		Input.action_release(&"sprint")
		await physics_frame
		check((player.position.x - center.x) * side >= 122.5, "Fast movement cannot pass through side chair at %s" % center)
	game.queue_free()
	await process_frame
	print("GEOMETRY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		result = bounds if result.size == Vector3.ZERO else result.merge(bounds)
	return result
