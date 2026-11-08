extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model: Node3D = load("res://assets/characters/motion/adventurer_motion.glb").instantiate()
	root.add_child(model)
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		print("ANIMATION_PLAYER ", model.get_path_to(player), " clips ", player.get_animation_list())
		for name_value: String in player.get_animation_list():
			var animation := player.get_animation(name_value)
			print("CLIP ", name_value, " length ", animation.length, " first_track ", animation.track_get_path(0))
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		print("SKELETON ", model.get_path_to(skeleton), " bones ", skeleton.get_bone_count())
	quit()
