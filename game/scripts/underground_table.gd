class_name UndergroundTable
extends Node3D
## Deep table dressing; rules and the selected character remain owned by the flow.

var guests: Array[Node3D] = []
var ring_positions: Array[Vector3] = []
var selected_index: int = -1
var bartender: Node3D
var spotlight: SpotLight3D
var environment: Environment


func build(roster: Array) -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("010102")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5b6c7")
	environment.ambient_light_energy = 0.055
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("020203")
	environment.fog_light_energy = 0.0
	environment.fog_density = 0.065
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("0c0a0b")
	floor_mat.roughness = 0.92
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 8.0
	floor_mesh.bottom_radius = 8.0
	floor_mesh.height = 0.1
	mesh_part("Floor", floor_mesh, floor_mat, Vector3(0, -0.06, 0))
	build_lamp()
	bartender = add_character("Bartender", "res://assets/npcs/vintage gentleman 3d model.glb")
	bartender.position = Vector3(-0.50, 0, -1.55)
	face_table(bartender)
	for index: int in range(roster.size()):
		var guest: Node3D = add_character(String(roster[index].id), roster[index].model)
		var angle: float = -2.45 + float(index) * 0.70
		guest.position = Vector3(sin(angle) * 2.85, 0, -cos(angle) * 2.85)
		face_table(guest)
		guests.append(guest)
		ring_positions.append(guest.position)
	build_crowd()


func mesh_part(label: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)
	return part


func build_lamp() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("31291f")
	metal.metallic = 0.75
	var shade := CylinderMesh.new()
	shade.top_radius = 0.12
	shade.bottom_radius = 0.42
	shade.height = 0.30
	mesh_part("OverheadShade", shade, metal, Vector3(0, 4.32, 0))
	var cable := CylinderMesh.new()
	cable.top_radius = 0.018
	cable.bottom_radius = 0.018
	cable.height = 3.0
	mesh_part("Suspension", cable, metal, Vector3(0, 5.9, 0))
	var bulb := CylinderMesh.new()
	bulb.top_radius = 0.34
	bulb.bottom_radius = 0.34
	bulb.height = 0.025
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("fff0d2")
	mesh_part("LampFace", bulb, glow, Vector3(0, 4.15, 0))
	spotlight = SpotLight3D.new()
	spotlight.name = "OverheadSpot"
	spotlight.position = Vector3(0, 4.1, 0)
	spotlight.rotation_degrees.x = -90
	spotlight.light_color = Color("fff0d5")
	spotlight.light_energy = 7.0
	spotlight.spot_range = 6.3
	spotlight.spot_angle = 36.0
	spotlight.spot_attenuation = 0.65
	spotlight.shadow_enabled = true
	spotlight.shadow_bias = 0.03
	spotlight.shadow_normal_bias = 0.3
	add_child(spotlight)
	var fill := OmniLight3D.new()
	fill.name = "TableBounce"
	fill.position = Vector3(0, 1.35, 0.5)
	fill.light_color = Color("dab88d")
	fill.light_energy = 0.55
	fill.omni_range = 3.4
	add_child(fill)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.05
	beam.bottom_radius = 2.15
	beam.height = 3.25
	beam.cap_top = false
	beam.cap_bottom = false
	var haze := ShaderMaterial.new()
	haze.shader = preload("res://assets/npcs/light_shaft.gdshader")
	var shaft := mesh_part("LightShaft", beam, haze, Vector3(0, 2.48, 0))
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_character(label: String, path: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	var model: Node3D = load(path).instantiate()
	holder.add_child(model)
	var bounds := AABB()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var factor: float = 1.80 / bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null and animation.has_animation("idle"):
		animation.play("idle")
		animation.advance(0)
	return holder


func face_table(character: Node3D) -> void:
	# Supplied models face +X; rotate that axis toward the centre.
	character.rotation.y = atan2(character.position.z, -character.position.x)


func seat_guest(index: int) -> void:
	if index == selected_index: return
	if selected_index >= 0:
		var previous: Node3D = guests[selected_index]
		previous.position = ring_positions[selected_index]
		face_table(previous)
		set_pose(previous, "idle")
	selected_index = index
	if index < 0: return
	var guest: Node3D = guests[index]
	guest.position = Vector3(1.38, 0, -0.38)
	face_table(guest)
	set_pose(guest, "seated")


func set_pose(character: Node3D, clip: String) -> void:
	var animation := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null and animation.has_animation(clip):
		animation.play(clip)
		animation.advance(0)


func build_crowd() -> void:
	var texture: Texture2D = load("res://assets/npcs/spectators.png")
	var crowd := Node3D.new()
	crowd.name = "Spectators"
	add_child(crowd)
	for index: int in range(32):
		var person := Sprite3D.new()
		person.name = "Spectator%d" % index
		person.texture = texture
		person.region_enabled = true
		var cell := Vector2(texture.get_width() / 4.0, texture.get_height() / 2.0)
		person.region_rect = Rect2(Vector2(index % 4, floori((index % 8) / 4.0)) * cell, cell)
		person.pixel_size = 0.0048
		person.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		person.modulate = Color(0.12, 0.105, 0.11, 1)
		person.no_depth_test = false
		person.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = float(index % 16) * TAU / 16.0 + (0.15 if index >= 16 else 0.0)
		var radius: float = 4.1 if index < 16 else 5.0
		person.position = Vector3(sin(angle) * radius, 0.95, -cos(angle) * radius)
		crowd.add_child(person)
