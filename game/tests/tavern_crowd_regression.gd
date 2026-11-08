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
	create_timer(30).timeout.connect(func() -> void: quit(1))
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var world: TavernWorld = game.world
	var people: Node = world.live_people
	check(world.get_node("Background").texture.resource_path == "res://assets/environment/tavern.png", "Keep the original painted tavern")
	check(people.table_guests == [3, 4, 4, 4], "Every table is occupied, with one player seat reserved")
	check(people.seated_guests.size() == 19, "Fifteen table guests and four bar guests")
	check(not world.player.sprite.visible, "The controlled character uses the live mesh rendering")
	check(people.space.get_node("Bartender").get_meta("interaction_id") == &"bartender", "Bartender remains identifiable")
	check(people.space.get_node("Companion").get_meta("interaction_id") == &"companion", "Green companion remains identifiable")
	check(people.space.get_world_3d() != game.table_view.get_world_3d(), "Tavern rendering does not share the seated gambling world")
	var seats: Dictionary = {}
	for guest: Node3D in people.seated_guests:
		var skeleton := guest.find_child("Skeleton3D", true, false) as Skeleton3D
		check(skeleton != null, "Guest has a real skeleton: %s" % guest.name)
		check(guest.find_children("*", "Sprite3D", true, false).is_empty(), "Guest is not a sprite card: %s" % guest.name)
		if guest.has_meta("table_index"):
			var key: String = "%d:%d" % [guest.get_meta("table_index"), guest.get_meta("seat_index")]
			check(not seats.has(key), "Only one guest occupies each chair")
			seats[key] = true
			var hip: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Pelvis")).origin
			check(hip.y > 0.48 and hip.y < 0.72, "Seated hip is at chair height: %s" % guest.name)
	check(not seats.has("0:2"), "The actual player chair is empty")
	for center: Vector2 in people.TABLE_CENTERS:
		var point: Vector3 = people.table_point(center) + Vector3(0, people.TABLE_HEIGHT, 0)
		var painted: Vector2 = people.camera_3d.unproject_position(point) * people.MAP_SIZE / Vector2(people.viewport.size)
		check(painted.distance_to(center) < 1.0, "3D table depth matches painted tabletop within a pixel")
	for point: Vector2 in [Vector2(485, 1325), Vector2(485, 600), Vector2(640, 680)]:
		world.player.position = point
		await process_frame
		await process_frame
		var painted: Vector2 = people.camera_3d.unproject_position(people.player_model.position) * people.MAP_SIZE / Vector2(people.viewport.size)
		check(painted.distance_to(point) < 1.0, "Rendered feet remain on the movement/collision anchor")
	var mugs: Array[Node] = people.space.find_children("HeldMug", "MeshInstance3D", true, false)
	check(mugs.size() == 4, "Four guests hold actual cup meshes")
	for mug: Node3D in mugs:
		check(mug.get_parent() is BoneAttachment3D and mug.get_parent().bone_name == "R_Hand", "Cup follows the right hand")
	print("TAVERN_CROWD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
