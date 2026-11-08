extends Node2D
## Live meshes projected onto the unchanged painted tavern, with furniture depth.

const BODY: PackedScene = preload("res://assets/tavern3d/patron_contact.glb")
const MapHeadPose = preload("res://scripts/map_head_pose.gd")
const MAP_SIZE := Vector2(971, 1620)
const PIXELS_PER_METER: float = 100.0
const ELEVATION: float = 1.11977
const TABLE_HEIGHT: float = 0.84
const SEAT_DISTANCE: float = 1.02
const TABLE_CENTERS: Array[Vector2] = [Vector2(236, 741), Vector2(752, 741), Vector2(230, 1127), Vector2(750, 1127)]

var viewport: SubViewport
var space: Node3D
var camera_3d: Camera3D
var player_model: Node3D
var player_animation: AnimationPlayer
var player_actor: TavernActor
var seated_guests: Array[Node3D] = []
var table_guests: Array[int] = []
var depth_material: ShaderMaterial


func _ready() -> void:
	name = "LiveTavernPeople"
	z_index = 1
	viewport = SubViewport.new()
	viewport.name = "PeopleViewport"
	viewport.size = Vector2i(486, 810)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	space = Node3D.new()
	space.name = "PeopleAndFurniture"
	viewport.add_child(space)
	var screen := Sprite2D.new()
	screen.name = "LiveRender"
	screen.texture = viewport.get_texture()
	screen.centered = false
	screen.scale = MAP_SIZE / Vector2(viewport.size)
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(screen)
	camera_3d = Camera3D.new()
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT
	camera_3d.size = MAP_SIZE.y / PIXELS_PER_METER
	camera_3d.position = Vector3(0, sin(ELEVATION), cos(ELEVATION)) * 30
	space.add_child(camera_3d)
	camera_3d.look_at(Vector3.ZERO)
	camera_3d.make_current()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e2c9a6")
	environment.environment.ambient_light_energy = 0.7
	space.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -30, 0)
	light.light_color = Color("ffe0ac")
	light.light_energy = 0.8
	space.add_child(light)
	depth_material = ShaderMaterial.new()
	depth_material.shader = preload("res://assets/tavern3d/furniture_depth.gdshader")
	depth_material.render_priority = -128
	populate_tables()
	populate_bar()
	var companion := person("Companion", floor_point(Vector2(680, 667)), -PI / 2, "idle", 4)
	companion.set_meta("interaction_id", &"companion")
	player_model = person("PlayerMesh", floor_point(player_actor.position), -PI / 2, "idle", 0)
	player_animation = player_model.find_child("AnimationPlayer", true, false)


func floor_point(pixel: Vector2) -> Vector3:
	return Vector3((pixel.x - MAP_SIZE.x / 2) / PIXELS_PER_METER, 0, (pixel.y - MAP_SIZE.y / 2) / (PIXELS_PER_METER * sin(ELEVATION)))


func table_point(pixel: Vector2) -> Vector3:
	return floor_point(pixel + Vector2(0, TABLE_HEIGHT * cos(ELEVATION) * PIXELS_PER_METER))


func person(label: String, at: Vector3, angle: float, clip: String, variant: int) -> Node3D:
	var model := BODY.instantiate() as Node3D
	model.name = label
	model.position = at
	model.rotation.y = angle
	model.scale = Vector3.ONE * 1.7947244
	space.add_child(model)
	var coats: Array[Color] = [Color("69432e"), Color("654b39"), Color("5c4835"), Color("723e3a"), Color("354a36"), Color("514346")]
	var hairs: Array[Color] = [Color("38251f"), Color("211f21"), Color("65442c"), Color("a08360")]
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
			if mat.resource_name == "Pixel_coat":
				mat.albedo_color = coats[variant % coats.size()]
			elif mat.resource_name == "Pixel_hair":
				mat.albedo_color = hairs[variant % hairs.size()]
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			mat.render_priority = 0
			mat.roughness = 1.0
			mesh.set_surface_override_material(surface, mat)
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play(clip)
	animation.advance(0)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if clip != "sleep" and clip != "drink":
		skeleton.add_child(MapHeadPose.new())
	if clip == "drink":
		add_mug(model, skeleton)
		animation.seek(float(variant % 4), true)
	return model


func add_mug(model: Node3D, skeleton: Skeleton3D) -> void:
	var hand := BoneAttachment3D.new()
	hand.name = "MugGrip"
	hand.bone_name = "R_Hand"
	skeleton.add_child(hand)
	hand.on_skeleton_update()
	var mug := MeshInstance3D.new()
	mug.name = "HeldMug"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = 0.095
	mesh.radial_segments = 12
	mug.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ba9257")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.roughness = 1
	mug.material_override = material
	hand.add_child(mug)
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone("R_Hand"))
	mug.transform = pose.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(0.46, 0.925, 0.13) / 1.7947244)
	model.set_meta("holds_mug", true)


func occlusion_box(label: String, at: Vector3, size: Vector3, parent: Node3D) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = depth_material
	node.position = at
	parent.add_child(node)


func chair_depth(at: Vector3, angle: float) -> void:
	var chair := Node3D.new()
	chair.name = "ChairDepth"
	chair.position = at
	chair.rotation.y = angle
	space.add_child(chair)
	occlusion_box("Seat", Vector3(0.025, 0.45, 0), Vector3(0.52, 0.06, 0.52), chair)
	occlusion_box("Back", Vector3(-0.255, 0.79, 0), Vector3(0.06, 0.62, 0.52), chair)


func populate_tables() -> void:
	var seats: Array[Vector3] = [Vector3(-SEAT_DISTANCE, 0, 0), Vector3(0, 0, -SEAT_DISTANCE), Vector3(SEAT_DISTANCE, 0, 0), Vector3(0, 0, SEAT_DISTANCE)]
	var angles: Array[float] = [0, -PI / 2, PI, PI / 2]
	for table_index: int in range(TABLE_CENTERS.size()):
		var center := table_point(TABLE_CENTERS[table_index])
		var table := MeshInstance3D.new()
		table.name = "TableDepth%d" % table_index
		var top := CylinderMesh.new()
		top.top_radius = 0.79
		top.bottom_radius = 0.79
		top.height = 0.09
		top.radial_segments = 48
		table.mesh = top
		table.material_override = depth_material
		table.position = center + Vector3(0, TABLE_HEIGHT - 0.045, 0)
		space.add_child(table)
		var count: int = 0
		for seat_index: int in range(4):
			var at: Vector3 = center + seats[seat_index]
			chair_depth(at, angles[seat_index])
			# The upper-left table keeps its right seat for the player.
			if table_index == 0 and seat_index == 2:
				continue
			var clip: String = "seated"
			if (table_index == 1 or table_index == 3) and seat_index == 1:
				clip = "sleep"
			elif seat_index == 0:
				clip = "drink"
			var guest := person("Table%dGuest%d" % [table_index, seat_index], at, angles[seat_index], clip, table_index * 4 + seat_index + 1)
			guest.set_meta("table_index", table_index)
			guest.set_meta("seat_index", seat_index)
			seated_guests.append(guest)
			count += 1
		table_guests.append(count)


func populate_bar() -> void:
	var bartender := person("Bartender", floor_point(Vector2(486, 449)), -PI / 2, "idle", 1)
	bartender.set_meta("interaction_id", &"bartender")
	for mesh: MeshInstance3D in bartender.find_children("*", "MeshInstance3D", true, false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(surface) as StandardMaterial3D
			if mat.resource_name == "Pixel_coat":
				mat.albedo_color = Color("242127")
			elif mat.resource_name == "Pixel_skin":
				mat.albedo_color = Color("d0c0ab")
	add_glasses(bartender)
	# The bar's near face occludes the bartender's legs while keeping his head clear.
	var bar_center := floor_point(Vector2(508, 522))
	occlusion_box("BarDepth", bar_center + Vector3(0, 0.53, -0.32), Vector3(4.7, 1.06, 0.70), space)
	for x: float in [350, 428, 587, 665]:
		var guest := person("BarGuest%d" % int(x), floor_point(Vector2(x, 548)), PI / 2, "seated", int(x) % 6)
		seated_guests.append(guest)


func add_glasses(model: Node3D) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := BoneAttachment3D.new()
	head.name = "GoldSpectacles"
	head.bone_name = "Head"
	skeleton.add_child(head)
	head.on_skeleton_update()
	var frame := Node3D.new()
	head.add_child(frame)
	frame.transform = skeleton.get_bone_global_pose(skeleton.find_bone("Head")).affine_inverse()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("c49a4f")
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	for side: float in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.019
		mesh.outer_radius = 0.024
		mesh.rings = 12
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.material_override = gold
		ring.position = Vector3(0.155, 0.922, -0.005 + side * 0.048)
		ring.rotation.z = -PI / 2
		frame.add_child(ring)


func _process(_delta: float) -> void:
	player_model.position = floor_point(player_actor.position)
	var direction := player_actor.facing
	player_model.rotation.y = atan2(-direction.y, direction.x)
	var walking: bool = player_actor.controls_enabled and player_actor.get_position_delta().length() > 0.01
	player_animation.play("walk" if walking else "idle", 0.10)
	player_animation.speed_scale = maxf(0.8, player_actor.get_real_velocity().length() / player_actor.speed) if walking else 1.0
