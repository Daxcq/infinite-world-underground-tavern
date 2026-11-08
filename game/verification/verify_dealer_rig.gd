extends SceneTree

var checks: int = 0
var failures: int = 0
var capture_enabled: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func box(parent: Node3D, size_value: Vector3, at: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/dealer_rig/" + filename + ".png")


func bone_position(skeleton: Skeleton3D, name_value: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name_value)).origin


func run() -> void:
	capture_enabled = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1000, 800)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var file := ProjectSettings.globalize_path("res://../美术资产/荷官绑骨样例_v1/masked_dealer_rigged.glb")
	var error := document.append_from_file(file, state)
	check(error == OK, "Exported GLB opens in Godot")
	if error != OK:
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var model := document.generate_scene(state)
	stage.add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(skeleton != null, "Imported model contains a Skeleton3D")
	check(player != null, "Imported model contains an AnimationPlayer")
	if skeleton == null or player == null:
		quit(1)
		return
	check(skeleton.get_bone_count() >= 28, "Body and garment bones survived export")
	for bone_name: String in ["Root", "Pelvis", "Head", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "L_Hand", "R_Hand", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "Coat_L_End", "Coat_R_End", "Coat_Back_End"]:
		check(skeleton.find_bone(bone_name) >= 0, "Required bone present: " + bone_name)
	for clip: String in ["idle", "gesture", "seated", "bend_test"]:
		check(player.has_animation(clip), "Required animation present: " + clip)
	player.play("idle")
	player.seek(0, true)
	player.advance(0)
	await process_frame
	var hand_rest := bone_position(skeleton, "L_Hand")
	player.play("gesture")
	player.seek(0.25, true)
	player.advance(0)
	await process_frame
	check(bone_position(skeleton, "L_Hand").distance_to(hand_rest) > 0.08, "Gesture moves the palm through the exported skeleton")
	player.pause()
	if capture_enabled:
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color("20272d")
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color("d7e0ec")
		world.environment.ambient_light_energy = 0.6
		stage.add_child(world)
		var camera := Camera3D.new()
		camera.position = Vector3(3.2, 1.70, 3.0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.45
		stage.add_child(camera)
		camera.look_at(Vector3(0.05, 0.85, 0))
		camera.make_current()
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-38, -40, 0)
		light.light_color = Color("ffe2b3")
		light.light_energy = 1.2
		light.shadow_enabled = true
		stage.add_child(light)
		box(stage, Vector3(6, 0.05, 6), Vector3(0, -0.031, 0), Color("242a2c"))
		await capture("godot_gesture")
	player.play("seated")
	player.seek(0.25, true)
	player.advance(0)
	await process_frame
	for side: String in ["L", "R"]:
		var hip := bone_position(skeleton, side + "_Thigh")
		var knee := bone_position(skeleton, side + "_Calf")
		var foot := bone_position(skeleton, side + "_Foot")
		check(absf(hip.y - knee.y) < 0.07, "Seated thigh is approximately horizontal: " + side)
		check(foot.y > 0.07 and foot.y < 0.14, "Seated ankle remains near the floor: " + side)
	player.pause()
	if capture_enabled:
		var chair := Node3D.new()
		stage.add_child(chair)
		box(chair, Vector3(0.48, 0.06, 0.48), Vector3(-0.04, 0.40, 0), Color("584333"))
		box(chair, Vector3(0.055, 0.44, 0.48), Vector3(-0.28, 0.65, 0), Color("584333"))
		for x: float in [-0.23, 0.15]:
			for z: float in [-0.19, 0.19]:
				box(chair, Vector3(0.045, 0.38, 0.045), Vector3(x, 0.19, z), Color("584333"))
		await capture("godot_seated")
		chair.hide()
		player.play("gesture")
		for index: int in range(16):
			player.seek(float(index) / 16.0, true)
			player.advance(0)
			player.pause()
			await capture("motion_%02d" % index)
	print("DEALER_RIG: %d checks, %d failures; bones=%d, clips=%s" % [checks, failures, skeleton.get_bone_count(), player.get_animation_list()])
	quit(1 if failures else 0)
