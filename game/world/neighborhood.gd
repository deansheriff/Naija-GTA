extends Node3D
## Original procedural blockout art: no external game assets or textures.

const PLACES = {
	"food": {"name": "Amaka's kitchen", "tag": "FOOD & FRIENDS", "position": Vector3(-8, 0, 2.4), "color": Color("d88759")},
	"repair": {"name": "Yemi's workshop", "tag": "LEARN & EARN", "position": Vector3(1, 0, 2.4), "color": Color("559481")},
	"home": {"name": "Your little corner", "tag": "REST & RESET", "position": Vector3(10, 0, 2.4), "color": Color("e3c889")},
	"square": {"name": "Community square", "tag": "HAVE YOUR SAY", "position": Vector3(-10, 0, 10), "color": Color("82a2b5")},
	"bus": {"name": "Bus stop", "tag": "THE STREET IS MOVING", "position": Vector3(10, 0, 10), "color": Color("e9b953")},
}

var sunlight: DirectionalLight3D
var camera: Camera3D
var hero: Node3D
var home_wall: MeshInstance3D
var decorations: Array[Node3D] = []
var crowds: Array[Node3D] = []
var material_cache: Dictionary = {}
var clock := 0.0
var animate := true

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var config := Environment.new()
	config.background_mode = Environment.BG_COLOR
	config.background_color = Color("b4ccc2")
	config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	config.ambient_light_color = Color("e4ede4")
	config.ambient_light_energy = 0.7
	config.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = config
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -28, 0)
	sunlight.light_color = Color("fff0d3")
	sunlight.light_energy = 1.5
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 70
	add_child(sunlight)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27
	camera.position = Vector3(29, 32, 38)
	add_child(camera)
	camera.look_at(Vector3(1, 0, 2))
	camera.current = true
	box(Vector3(0, -0.3, 2), Vector3(47, 0.5, 35), Color("b9b793"))
	box(Vector3(0, -0.02, 6), Vector3(44, 0.12, 5.8), Color("626f65"))
	box(Vector3(0, 0, 2.8), Vector3(42, 0.18, 1.0), Color("c9cfb4"))
	box(Vector3(0, 0, 9.2), Vector3(42, 0.18, 1.0), Color("c9cfb4"))
	for x in range(-20, 22, 4):
		box(Vector3(x, 0.06, 6), Vector3(1.4, 0.02, 0.14), Color("d9d2a9"))
	# A shallow original open-front neighborhood; doors face the accessible street.
	building(-9, Color("cf8760"), "AMAKA'S", "JOLLOF • GOOD GIST")
	building(0, Color("639b86"), "YEMI'S", "REPAIR & LEARN")
	building(9, Color("e1c795"), "HOME", "A LITTLE PEACE")
	home_wall = box(Vector3(9, 1.6, -0.5), Vector3(5.5, 3.0, 0.24), Color("b4c5a0"))
	# Food stall and kitchen.
	box(Vector3(-9, 0.65, 0.6), Vector3(4.0, 1.2, 0.85), Color("c78351"))
	box(Vector3(-9, 1.3, 0.6), Vector3(4.4, 0.12, 1.0), Color("f3d496"))
	for x in [-10.3, -9, -7.7]:
		cylinder(Vector3(x, 1.43, 0.6), 0.32, 0.25, Color("51594e"))
		cylinder(Vector3(x, 1.59, 0.6), 0.28, 0.05, Color("d6ba7d"))
	person(Vector3(-7.4, 0, 1.4), Color("d8aa3e"), false)
	label("AMAKA", Vector3(-7.4, 2.4, 1.4), 22, Color("fff5d8"))
	# Repair bench, stool and a radio.
	box(Vector3(0, 0.85, 0.4), Vector3(4, 0.2, 1), Color("714e3c"))
	for x in [-1.4, 1.4]:
		box(Vector3(x, 0.4, 0.4), Vector3(0.15, 0.8, 0.5), Color("536f64"))
	box(Vector3(0.1, 1.17, 0.4), Vector3(0.8, 0.5, 0.3), Color("e9bf65"))
	person(Vector3(1.9, 0, 1.2), Color("537f94"), false)
	label("YEMI", Vector3(1.9, 2.4, 1.2), 22, Color("fff5d8"))
	# Home furnishings visible from the street.
	box(Vector3(8.7, 0.3, 0.4), Vector3(2.6, 0.5, 1.8), Color("77553c"))
	box(Vector3(8.7, 0.59, 0.4), Vector3(2.5, 0.2, 1.7), Color("f4eee0"))
	box(Vector3(8.7, 0.72, 0.6), Vector3(2.5, 0.07, 1.1), Color("7eaa98"))
	box(Vector3(8.7, 0.78, -0.2), Vector3(1.4, 0.2, 0.5), Color("e2d9b8"))
	box(Vector3(11, 0.6, 1.2), Vector3(0.7, 1.0, 0.6), Color("9b7253"))
	cylinder(Vector3(11, 1.25, 1.2), 0.23, 0.3, Color("e0ad65"))
	# Community seating and a public notice board.
	box(Vector3(-10, 0.03, 12), Vector3(9, 0.18, 6), Color("b6c599"))
	for x in [-12.8, -8.0]:
		bench(Vector3(x, 0, 11))
	box(Vector3(-10.5, 1.6, 12.5), Vector3(3.7, 2.2, 0.2), Color("49685c"))
	label("YOUR STREET\nYOUR SAY", Vector3(-10.5, 1.85, 12.65), 24, Color("e5edb2"))
	# Yellow minibus: original simplified mesh, not a copied vehicle asset.
	bus(Vector3(9, 0, 7))
	for x in [-17, -4, 5, 17]:
		tree(Vector3(x, 0, -3.4))
	for x in [-17, -2, 15]:
		tree(Vector3(x, 0, 12.5))
	for x in [-15, -4, 5, 15]:
		box(Vector3(x, 2.8, 2.5), Vector3(0.1, 5.6, 0.1), Color("657468"))
		box(Vector3(x + 0.45, 5.5, 2.5), Vector3(1, 0.1, 0.12), Color("657468"))
		box(Vector3(x + 0.85, 5.4, 2.5), Vector3(0.35, 0.1, 0.35), Color("e6db9c"))
	for x in [-19, -13, 4, 14, 19]:
		var extra := person(Vector3(x, 0, 8.9), Color("d29a70") if x < 0 else Color("7c9fad"), true)
		crowds.append(extra)
	for x in [-18, 17]:
		var crate := box(Vector3(x, 0.25, 0.8), Vector3(0.7, 0.5, 0.7), Color("a3794e"))
		decorations.append(crate)
	# Distant blocks.
	for x in range(-24, 28, 7):
		var block := box(Vector3(x, 2.0, -10), Vector3(5.3, 4, 5), Color("91a699"))
		decorations.append(block)
		box(Vector3(x, 4.1, -10), Vector3(5.6, 0.3, 5.3), Color("758d82"))
	hero = person(Vector3(3, 0, 6), Color("dbec82"), false)
	hero.name = "Player"
	var marker := cylinder(Vector3(0, 0.025, 0), 0.5, 0.015, Color("d2ee83"), hero)
	marker.name = "PlayerMarker"
	_batch_static_geometry()

func _batch_static_geometry() -> void:
	# Merge static surfaces by shared material in this small block.
	# Movable characters, the editable home wall and tier-dependent props stay separate.
	var groups: Dictionary = {}
	for child in get_children():
		if not child is Node3D:
			continue
		if child == hero or child in crowds or child in decorations or child == home_wall:
			continue
		_collect_static(child, groups)
	for key in groups:
		var tool: SurfaceTool = groups[key].tool
		var merged := MeshInstance3D.new()
		merged.mesh = tool.commit()
		merged.material_override = groups[key].material
		add_child(merged)

func _collect_static(node: Node, groups: Dictionary) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.material_override
		if mat == null:
			return
		var key := mat.get_instance_id()
		if not groups.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"tool": tool, "material": mat}
		groups[key].tool.append_from(node.mesh, 0, global_transform.affine_inverse() * node.global_transform)
		node.queue_free()
	else:
		for child in node.get_children():
			_collect_static(child, groups)

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not material_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		material_cache[key] = mat
	return material_cache[key]

func box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material(color)
	item.position = pos
	parent.add_child(item)
	return item

func cylinder(pos: Vector3, radius: float, height: float, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material(color)
	item.position = pos
	parent.add_child(item)
	return item

func label(text: String, pos: Vector3, font_size: int, color: Color) -> Label3D:
	var item := Label3D.new()
	item.text = text
	item.font_size = font_size
	item.pixel_size = 0.02
	item.modulate = color
	item.position = pos
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.no_depth_test = false
	item.outline_size = 2
	add_child(item)
	return item

func building(x: float, color: Color, title: String, subtitle: String) -> void:
	box(Vector3(x, 0.03, -0.7), Vector3(7, 0.15, 5), Color("d6cfac"))
	box(Vector3(x, 1.65, -2.9), Vector3(6.4, 3.2, 0.25), color)
	for side in [-1, 1]:
		box(Vector3(x + side * 3.2, 1.65, -0.7), Vector3(0.3, 3.2, 4.5), color)
	box(Vector3(x, 3.45, -0.7), Vector3(7.2, 0.3, 5.4), Color("607b6a"))
	box(Vector3(x, 2.85, 1.65), Vector3(6.8, 0.95, 0.3), color.darkened(0.25))
	label(title, Vector3(x, 3.0, 2.5), 30, Color("fff1ce"))
	label(subtitle, Vector3(x, 2.65, 2.6), 15, Color("f2dba1"))
	for i in range(7):
		box(Vector3(x - 3.0 + i, 2.15, 2), Vector3(0.92, 0.13, 0.8), color.lightened(0.2) if i % 2 == 0 else Color("f1dcaa"))

func person(pos: Vector3, shirt: Color, animated: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	box(Vector3(0, 0.98, 0), Vector3(0.62, 0.73, 0.35), shirt, root)
	cylinder(Vector3(0, 1.58, 0), 0.24, 0.42, Color("86593e"), root)
	cylinder(Vector3(0, 1.82, 0), 0.25, 0.1, Color("343e34"), root)
	for side in [-1, 1]:
		box(Vector3(side * 0.17, 0.34, 0), Vector3(0.23, 0.66, 0.24), Color("344f4c"), root)
		box(Vector3(side * 0.38, 0.94, 0), Vector3(0.15, 0.7, 0.2), Color("86593e"), root)
		box(Vector3(side * 0.17, 0.05, 0.07), Vector3(0.27, 0.13, 0.42), Color("39463d"), root)
	root.set_meta("animated", animated)
	return root

func bench(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.6, 0), Vector3(2, 0.13, 0.7), Color("9b7951"))
	box(pos + Vector3(0, 1.0, 0.32), Vector3(2, 0.8, 0.1), Color("9b7951"))
	for side in [-1, 1]:
		box(pos + Vector3(side * 0.75, 0.3, 0), Vector3(0.12, 0.6, 0.7), Color("597568"))

func tree(pos: Vector3) -> void:
	cylinder(pos + Vector3(0, 1.8, 0), 0.18, 3.6, Color("90734e"))
	for offset in [Vector3(0, 4.3, 0), Vector3(-0.8, 3.7, 0.2), Vector3(0.8, 3.8, -0.2)]:
		var sphere := SphereMesh.new()
		sphere.radius = 1.5
		sphere.height = 2.3
		sphere.radial_segments = 12
		sphere.rings = 5
		var leaves := MeshInstance3D.new()
		leaves.mesh = sphere
		leaves.position = pos + offset
		leaves.material_override = material(Color("789366"))
		add_child(leaves)

func bus(pos: Vector3) -> void:
	box(pos + Vector3(0, 1.1, 0), Vector3(4, 1.7, 1.8), Color("eabd50"))
	box(pos + Vector3(0, 1.95, 0), Vector3(3.95, 0.12, 1.82), Color("f2cf6b"))
	box(pos + Vector3(0, 0.75, 0), Vector3(4.04, 0.12, 1.84), Color("393f32"))
	for x in [-1.4, -0.45, 0.5, 1.4]:
		box(pos + Vector3(x, 1.52, 0.92), Vector3(0.75, 0.65, 0.02), Color("527b7b"))
	for x in [-1.2, 1.2]:
		for z in [-0.9, 0.9]:
			var wheel := cylinder(pos + Vector3(x, 0.45, z), 0.43, 0.15, Color("33473f"))
			wheel.rotation_degrees.x = 90
	label("BUS STOP", pos + Vector3(0, 2.8, 0), 26, Color("fff1ca"))

func apply_settings(settings: Dictionary) -> void:
	sunlight.shadow_enabled = settings.shadows
	animate = settings.effects
	for i in crowds.size():
		crowds[i].visible = i < (1 if settings.quality == "Low" else 3 if settings.quality == "Medium" else 5)
	for node in decorations:
		node.visible = settings.distance > 0
	camera.far = 80 if settings.distance == 0 else 120 if settings.distance == 1 else 160
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if settings.quality == "Low" else Viewport.MSAA_2X if settings.quality == "Medium" else Viewport.MSAA_4X
	get_viewport().scaling_3d_scale = 0.75 if settings.quality == "Low" else 0.9 if settings.quality == "Medium" else 1.0

func set_wall(color_name: String) -> void:
	home_wall.material_override = material(Color("b4c5a0") if color_name == "sage" else Color("c98669") if color_name == "clay" else Color("75a5b3"))

func _process(delta: float) -> void:
	clock += delta
	if animate:
		for i in crowds.size():
			crowds[i].position.z = 8.9 + sin(clock * 0.5 + i * 2) * 0.2
