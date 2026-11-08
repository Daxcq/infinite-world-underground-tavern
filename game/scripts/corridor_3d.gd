extends Node3D
## One-table spatial sample: authored contact poses, physical furniture, two cameras.

const WALKER = preload("res://assets/tavern3d/patron_contact.glb")
const PATRON = preload("res://assets/tavern3d/patron_contact.glb")
const TABLE_CENTER := Vector3(-1.45, 0, 0)
const TABLE_HEIGHT: float = 0.84
const TABLE_RADIUS: float = 0.78
const MODEL_SCALE: float = 1.7947244
const SEAT_POSITION := TABLE_CENTER + Vector3(0, 0, 1.15)

var player: CharacterBody3D
var player_model: Node3D
var player_animation: AnimationPlayer
var drinker: Node3D
var sleeper: Node3D
var drink_animation: AnimationPlayer
var sleep_animation: AnimationPlayer
var drink_skeleton: Skeleton3D
var mug: Node3D
var mug_grip: Transform3D
var holding_hand: int
var explore_camera: Camera3D
var seat_camera: Camera3D
var detail_camera: Camera3D
var hint: Label
var seated: bool = false
var detail: bool = false
var return_position: Vector3
var yaw: float = 0.0
var pitch: float = -0.22
var materials: Dictionary = {}


func _ready() -> void:
	get_window().title = "雨夜酒馆 · 像素长廊小样"
	if not InputMap.has_action(&"inspect_table"):
		InputMap.add_action(&"inspect_table")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_TAB
		InputMap.action_add_event(&"inspect_table", key)
	build_pixel_rendering()
	build_materials()
	build_room()
	build_table()
	build_people()
	build_cameras()
	build_ui()


func build_pixel_rendering() -> void:
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	viewport.scaling_3d_scale = 1.0 / 3.0
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.name = "PixelWorldPalette"
	layer.layer = 1
	add_child(layer)
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/tavern3d/pixel_palette.gdshader")
	screen.material = shader
	layer.add_child(screen)


func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.82
	value.metallic = metallic
	return value


func build_materials() -> void:
	materials = {
		"wood": material(Color("543a2b")), "edge": material(Color("291d18")),
		"plaster": material(Color("726557")), "green": material(Color("293b34")),
		"brass": material(Color("a27b42"), 0.6), "glass": material(Color("355550"), 0.2),
		"ceramic": material(Color("b08349")), "beer": material(Color("dfbb73")),
		"cream": material(Color("e5d5b6")), "window": material(Color("3a5a71")),
	}
	materials.window.emission_enabled = true
	materials.window.emission = Color("2b465c")
	materials.window.emission_energy_multiplier = 0.35


func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		collision(parent, label + "Collision", at, shape)
	return node


func cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: Material, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = mat
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision(parent, label + "Collision", at, shape)
	return node


func collision(parent: Node3D, label: String, at: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body


func build_room() -> void:
	var room := Node3D.new()
	room.name = "Room"
	add_child(room)
	box(room, "Floor", Vector3(0, -0.10, 0), Vector3(7.6, 0.2, 14), materials.edge, true)
	for x: int in range(19):
		for z: int in range(7):
			var shade: float = 0.87 + float((x * 7 + z * 3) % 5) * 0.035
			box(room, "Plank_%d_%d" % [x, z], Vector3(-3.6 + x * 0.4, 0.001, -6 + z * 2), Vector3(0.392, 0.002, 1.985), material(Color("654b35") * shade))
	box(room, "EntranceBoundary", Vector3(0, 0.55, 7.05), Vector3(7.6, 1.1, 0.12), materials.edge, true)
	box(room, "BackWall", Vector3(0, 1.7, -6.6), Vector3(7.6, 3.4, 0.2), materials.plaster, true)
	# Side walls stay low so the fixed RPG camera can see the physical room.
	for side: float in [-1.0, 1.0]:
		box(room, "SideWall", Vector3(side * 3.85, 0.55, 0), Vector3(0.18, 1.1, 14), materials.green, true)
		box(room, "WallCap", Vector3(side * 3.85, 1.12, 0), Vector3(0.23, 0.09, 14), materials.edge)
		for z: float in [-5.8, -2.8, 0.2, 3.2, 6.2]:
			box(room, "TimberPost", Vector3(side * 3.75, 1.55, z), Vector3(0.19, 3.1, 0.2), materials.edge)
		for z: float in [-4.3, -1.3, 1.7, 4.7]:
			box(room, "RainWindow", Vector3(side * 3.75, 1.95, z), Vector3(0.04, 1.25, 1.25), materials.window)
			box(room, "WindowCross", Vector3(side * 3.70, 1.95, z), Vector3(0.06, 0.06, 1.3), materials.edge)
			box(room, "WindowUpright", Vector3(side * 3.70, 1.95, z), Vector3(0.06, 1.3, 0.06), materials.edge)
	box(room, "BarFront", Vector3(0, 0.52, -5.4), Vector3(5.3, 1.04, 0.65), materials.green, true)
	box(room, "BarTop", Vector3(0, 1.08, -5.35), Vector3(5.55, 0.12, 0.95), materials.wood, true)
	for y: float in [1.5, 2.1, 2.7]:
		box(room, "BottleShelf", Vector3(0, y, -6.3), Vector3(5.3, 0.07, 0.37), materials.edge)
		for i: int in range(15):
			var bottle_at := Vector3(-2.4 + i * 0.34, y + 0.17, -6.25)
			cylinder(room, "Bottle", bottle_at, 0.065, 0.27, materials.glass if i % 3 else materials.ceramic)
			cylinder(room, "BottleNeck", bottle_at + Vector3(0, 0.18, 0), 0.028, 0.10, materials.glass)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("181b21")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a4a0a0")
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(environment)
	for z: float in [-4.0, 0.0, 4.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(-0.5, 3.2, z)
		light.light_color = Color("ffd4a0")
		light.light_energy = 1.1
		light.omni_range = 6.0
		light.shadow_enabled = true
		light.shadow_normal_bias = 0.8
		add_child(light)
		cylinder(room, "Pendant", Vector3(-0.5, 3.25, z), 0.25, 0.12, materials.brass)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, -25, 0)
	fill.light_color = Color("c4d6e8")
	fill.light_energy = 0.45
	add_child(fill)


func chair(label: String, at: Vector3, angle: float) -> void:
	var node := Node3D.new()
	node.name = label
	node.position = at
	node.rotation.y = angle
	add_child(node)
	box(node, "Seat", Vector3(0.025, 0.45, 0), Vector3(0.52, 0.06, 0.52), materials.wood, true)
	box(node, "Back", Vector3(-0.255, 0.79, 0), Vector3(0.06, 0.62, 0.52), materials.edge, true)
	for x: float in [-0.19, 0.21]:
		for z: float in [-0.21, 0.21]:
			box(node, "Leg", Vector3(x, 0.215, z), Vector3(0.065, 0.43, 0.065), materials.edge, true)


func build_table() -> void:
	var table := Node3D.new()
	table.name = "Table"
	table.position = TABLE_CENTER
	add_child(table)
	cylinder(table, "Tabletop", Vector3(0, TABLE_HEIGHT - 0.045, 0), TABLE_RADIUS, 0.09, materials.wood, true)
	cylinder(table, "TableRim", Vector3(0, TABLE_HEIGHT - 0.05, 0), TABLE_RADIUS + 0.012, 0.045, materials.edge)
	cylinder(table, "Pedestal", Vector3(0, 0.38, 0), 0.12, 0.76, materials.edge, true)
	box(table, "FootX", Vector3(0, 0.05, 0), Vector3(0.95, 0.1, 0.13), materials.edge, true)
	box(table, "FootZ", Vector3(0, 0.05, 0), Vector3(0.13, 0.1, 0.95), materials.edge, true)
	# An empty plate and lamp leave the authored arm-contact area clear.
	cylinder(table, "Plate", Vector3(0.22, TABLE_HEIGHT + 0.013, 0.18), 0.14, 0.026, materials.cream)
	cylinder(table, "LampBase", Vector3(0.18, TABLE_HEIGHT + 0.02, -0.23), 0.10, 0.04, materials.brass)
	cylinder(table, "LampStem", Vector3(0.18, TABLE_HEIGHT + 0.16, -0.23), 0.018, 0.25, materials.brass)
	cylinder(table, "LampShade", Vector3(0.18, TABLE_HEIGHT + 0.29, -0.23), 0.13, 0.10, materials.cream)
	chair("DrinkerChair", TABLE_CENTER + Vector3(-1.14, 0, 0), 0)
	chair("SleeperChair", TABLE_CENTER + Vector3(0, 0, -1.14), -PI / 2)
	chair("PlayerChair", SEAT_POSITION, PI / 2)


func character(scene: PackedScene, label: String, at: Vector3, angle: float, clip: String) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.name = label
	model.position = at
	model.rotation.y = angle
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	style_character(model)
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play(clip)
	animation.advance(0)
	return model


func style_character(model: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://assets/tavern3d/pixel_outline.gdshader")
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var surface_material := mesh.get_active_material(surface).duplicate() as BaseMaterial3D
			surface_material.roughness = 1
			surface_material.next_pass = outline
			mesh.set_surface_override_material(surface, surface_material)


func build_people() -> void:
	drinker = character(PATRON, "Drinker", TABLE_CENTER + Vector3(-1.14, 0, 0), 0, "drink")
	sleeper = character(PATRON, "Sleeper", TABLE_CENTER + Vector3(0, 0, -1.14), -PI / 2, "sleep")
	drink_animation = drinker.find_child("AnimationPlayer", true, false)
	sleep_animation = sleeper.find_child("AnimationPlayer", true, false)
	drink_skeleton = drinker.find_child("Skeleton3D", true, false)
	for person: Node3D in [drinker, sleeper]:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.40
		shape.height = 1.16
		collision(self, String(person.name) + "Body", person.position + Vector3(0, 0.6, 0), shape)
	mug = Node3D.new()
	mug.name = "HandheldMug"
	add_child(mug)
	cylinder(mug, "Cup", Vector3.ZERO, 0.064, 0.17, materials.ceramic)
	cylinder(mug, "Beer", Vector3(0, 0.086, 0), 0.058, 0.006, materials.beer)
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.028
	torus.outer_radius = 0.043
	torus.rings = 16
	torus.ring_segments = 12
	torus.material = materials.brass
	handle.mesh = torus
	handle.position = Vector3(-0.078, -0.005, 0)
	handle.rotation.x = PI / 2
	mug.add_child(handle)
	drink_skeleton.force_update_all_bone_transforms()
	holding_hand = drink_skeleton.find_bone("R_Hand")
	var hand := drink_skeleton.global_transform * drink_skeleton.get_bone_global_pose(holding_hand)
	var rest_cup := Transform3D(Basis.IDENTITY, drinker.position + Vector3(0.46, TABLE_HEIGHT + 0.085, 0.13))
	mug_grip = hand.affine_inverse() * rest_cup
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandGrip"
	attachment.bone_name = "R_Hand"
	drink_skeleton.add_child(attachment)
	attachment.on_skeleton_update()
	mug.reparent(attachment)
	mug.transform = mug_grip
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.65, 0.02, 3.3)
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.40
	capsule.height = 1.82
	body_shape.shape = capsule
	body_shape.position.y = 0.91
	player.add_child(body_shape)
	player_model = WALKER.instantiate()
	player_model.scale = Vector3.ONE * MODEL_SCALE
	player.add_child(player_model)
	style_character(player_model)
	player_animation = player_model.find_child("AnimationPlayer", true, false)
	for clip: String in ["idle", "walk", "seated"]:
		player_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player_animation.play("idle")


func build_cameras() -> void:
	explore_camera = Camera3D.new()
	explore_camera.name = "ExploreCamera"
	explore_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	explore_camera.size = 8.6
	explore_camera.near = 0.05
	add_child(explore_camera)
	explore_camera.make_current()
	seat_camera = Camera3D.new()
	seat_camera.name = "SeatCamera"
	seat_camera.position = SEAT_POSITION + Vector3(0, 1.28, -0.35)
	seat_camera.fov = 74
	seat_camera.near = 0.04
	add_child(seat_camera)
	detail_camera = Camera3D.new()
	detail_camera.name = "DetailCamera"
	detail_camera.position = TABLE_CENTER + Vector3(-1.7, 1.6, 2.4)
	detail_camera.fov = 48
	detail_camera.near = 0.04
	add_child(detail_camera)
	detail_camera.look_at(TABLE_CENTER + Vector3(-0.2, 0.8, -0.3))
	update_camera(1)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.057, 0.052, 0.90)
	style.border_color = Color("96764f")
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var text := Label.new()
	text.text = "雨夜酒馆 · 像素长廊小样\nWASD 移动　Shift 快步　Tab 桌边近看"
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color("e9dcc6"))
	panel.add_child(text)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -62
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color("ffe1a4"))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hint)


func can_sit() -> bool:
	var approach := SEAT_POSITION + Vector3(0.80, 0, 0.1)
	return not seated and player.position.distance_to(approach) < 0.8


func sit() -> void:
	if not can_sit():
		return
	return_position = player.position
	seated = true
	detail = false
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.position = SEAT_POSITION
	player_model.rotation.y = PI / 2
	player_animation.play("seated")
	yaw = 0
	pitch = -0.22
	seat_camera.make_current()


func leave_seat() -> void:
	seated = false
	player.position = return_position
	player.collision_layer = 2
	player.collision_mask = 1
	player_animation.play("idle")
	explore_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if seated:
			leave_seat()
		else:
			sit()
	if event.is_action_pressed("pause") and seated:
		leave_seat()
	if event.is_action_pressed(&"inspect_table") and not seated:
		detail = not detail
		if detail:
			detail_camera.make_current()
		else:
			explore_camera.make_current()
	if seated and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw = clampf(yaw - event.screen_relative.x * 0.003, -1.0, 1.0)
		pitch = clampf(pitch - event.screen_relative.y * 0.003, -0.65, 0.30)


func _physics_process(delta: float) -> void:
	if seated:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if not detail else Vector2.ZERO
	var right := explore_camera.global_basis.x
	var forward := explore_camera.global_basis.z
	right.y = 0
	forward.y = 0
	var direction := (right.normalized() * input.x + forward.normalized() * input.y).normalized() * input.length()
	var speed: float = 3.1 if Input.is_action_pressed("sprint") else 1.8
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, 14 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, 14 * delta)
	player.velocity.y -= 9.8 * delta
	player.move_and_slide()
	var walking: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.08 and player.get_position_delta().length() > 0.001
	player_animation.play("walk" if walking else "idle", 0.12)
	player_animation.speed_scale = speed / 1.8
	if walking:
		player_model.rotation.y = lerp_angle(player_model.rotation.y, atan2(-direction.z, direction.x), 12 * delta)


func update_camera(delta: float) -> void:
	var target := Vector3(clampf(player.position.x, -0.4, 0.4), 0.55, clampf(player.position.z - 0.9, -3.1, 3.2))
	explore_camera.position = explore_camera.position.lerp(target + Vector3(4.6, 8.4, 8.2), minf(1.0, delta * 5))
	explore_camera.look_at(target)
	seat_camera.rotation = Vector3(pitch, yaw, 0)


func _process(delta: float) -> void:
	update_camera(delta)
	if seated:
		yaw = clampf(yaw - Input.get_axis("look_left", "look_right") * delta, -1.0, 1.0)
		hint.text = "拖动鼠标左键 / A、D 环顾　　E / Esc 起身"
	elif detail:
		hint.text = "观察举杯、坐姿与趴桌接触　　Tab 返回探索"
	else:
		hint.text = "E 坐下" if can_sit() else "走到空椅右侧，按 E 落座"
