extends Node2D
## An authored reference block assembled from independent painted modules.

const Layout = preload("res://world/district_layout.gd")
const BUILDING_SHEET = preload("res://assets/building-parts-v05.png")
const TREE_SHEET = preload("res://assets/tree-parts-v05.png")
const TRAFFIC_SHEET = preload("res://assets/traffic-v04.png")
var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment-bounds-v05.json"))
var roofs: Dictionary = {}
var canopies: Array[Sprite2D] = []
var decorative_shadows: Array[CanvasItem] = []
var furniture_nodes: Array[Node2D] = []
var building_nodes: Array[Node2D] = []
var tree_nodes: Array[Node2D] = []
var detailed_motion := true
var animate := true

func build(sorted_world: Node2D, sprite_bounds: Dictionary) -> void:
	for building in Layout.BUILDINGS:
		var front := Vector2(building.footprint.get_center().x, building.footprint.end.y)
		var shell := Node2D.new()
		shell.name = building.id + "_shell"
		# Sort the floor/back shell at its rear ground edge. This keeps trees
		# planted behind the building behind its walls, and room occupants above.
		shell.position = Vector2(front.x, building.footprint.position.y)
		sorted_world.add_child(shell)
		building_nodes.append(shell)
		var data: Array = regions["building-parts-v05.png"][building.kind]
		var wall := _sprite(shell, BUILDING_SHEET, data, building.footprint.size.x)
		wall.position.y = building.footprint.size.y - wall.texture.get_height() * wall.scale.y / 2.0
		# Only the two low front walls sort in front of someone inside the room.
		var facade := Node2D.new()
		facade.position = front
		sorted_world.add_child(facade)
		var factor: float = building.footprint.size.x / data[2]
		for side in [0, 1]:
			var part: Array = [data[0] + (data[2] * 0.62 if side == 1 else 0), data[1] + data[3] * 0.65, data[2] * 0.38, data[3] * 0.35]
			var face := _sprite(facade, BUILDING_SHEET, part, part[2] * factor)
			face.position = Vector2((0.31 if side == 1 else -0.31) * building.footprint.size.x, -part[3] * factor / 2.0)
		var roof_anchor := Node2D.new()
		roof_anchor.name = building.id + "_roof"
		roof_anchor.position = front
		sorted_world.add_child(roof_anchor)
		var roof := _sprite(roof_anchor, BUILDING_SHEET, regions["building-parts-v05.png"][building.kind + 3], building.footprint.size.x + 30)
		roof.position.y = -90 - roof.texture.get_height() * roof.scale.y / 2.0
		roofs[building.id] = roof
		var sign_anchor := Node2D.new()
		facade.add_child(sign_anchor)
		_box(sign_anchor, Rect2(-118, -80, 100, 25), Color("264c40"))
		var sign_text := Label.new()
		sign_text.text = ["AMAKA · FOOD", "YEMI · REPAIRS", "HOME"][building.kind]
		sign_text.add_theme_font_size_override("font_size", 10)
		sign_text.add_theme_color_override("font_color", Color("f4efdb"))
		sign_text.position = Vector2(-113, -74)
		sign_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sign_anchor.add_child(sign_text)
	for item in Layout.FURNITURE: _furniture(sorted_world, item)
	for at in Layout.TREES: _tree(sorted_world, at)
	var bus := Node2D.new()
	bus.name = "ParkedDanfo"
	bus.position = Vector2(Layout.PARKED_BUS.get_center().x, Layout.PARKED_BUS.end.y)
	var shadow := _ellipse(bus, Vector2(125, 13), Color(0.09, 0.15, 0.11, 0.3))
	decorative_shadows.append(shadow)
	for x in [-76, 76]:
		var contact := _ellipse(bus, Vector2(23, 4), Color(0.08, 0.12, 0.08, 0.6))
		contact.position.x = x
	var bus_sprite := _sprite(bus, TRAFFIC_SHEET, sprite_bounds["traffic-v04.png"][0], Layout.PARKED_BUS.size.x)
	bus_sprite.position.y = -bus_sprite.texture.get_height() * bus_sprite.scale.y / 2.0
	sorted_world.add_child(bus)
	# A separate shelter module, deliberately clear of the boarding approach.
	var shelter := Node2D.new()
	shelter.position = Vector2(1400, 845)
	sorted_world.add_child(shelter)
	_box(shelter, Rect2(-8, -148, 8, 148), Color("556b60"))
	_shape(shelter, [Vector2(-142, -164), Vector2(24, -164), Vector2(44, -145), Vector2(-163, -145)], Color("778b7d"))
	_box(shelter, Rect2(-160, -145, 205, 7), Color("344f45"))

func _sprite(parent: Node, sheet: Texture2D, data: Array, width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(data[0], data[1], data[2], data[3])
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * width / data[2]
	parent.add_child(sprite)
	return sprite

func _furniture(parent: Node2D, item: Dictionary) -> void:
	var node := Node2D.new()
	node.name = item.id
	node.position = Vector2(item.rect.get_center().x, item.rect.end.y)
	parent.add_child(node)
	furniture_nodes.append(node)
	var width: float = item.rect.size.x
	var height: float = 64 if item.kind == "counter" else 44
	if item.kind == "board":
		_box(node, Rect2(-29, -100, 4, 100), Color("79583c"))
		_box(node, Rect2(25, -100, 4, 100), Color("79583c"))
		_box(node, Rect2(-42, -118, 84, 68), Color("476b59"))
		_box(node, Rect2(-35, -111, 70, 52), Color("d7c8a0"))
		for x in [-23, 0, 19]: _box(node, Rect2(x, -102, 15, 30), Color("f0e8cf"))
		return
	var shadow := _ellipse(node, Vector2(width * 0.55, 8), Color(0.10, 0.17, 0.11, 0.2))
	decorative_shadows.append(shadow)
	_box(node, Rect2(-width / 2 + 8, -height, 8, height), Color("735338"))
	_box(node, Rect2(width / 2 - 16, -height, 8, height), Color("735338"))
	_box(node, Rect2(-width / 2, -height, width, 18), Color("93663c"))
	_shape(node, [Vector2(-width / 2, -height), Vector2(-width / 2 + 8, -height - 17), Vector2(width / 2 + 8, -height - 17), Vector2(width / 2, -height)], Color("c99b60"))
	if item.kind == "bench":
		_box(node, Rect2(-width / 2, -height - 24, width, 10), Color("b48a51"))
	else:
		for x in [-26, 8]:
			_box(node, Rect2(x, -height - 28, 22, 12), Color("667c75"))
			_ellipse(node, Vector2(12, 3), Color("c6cec0")).position = Vector2(x + 11, -height - 27)

func _tree(parent: Node2D, at: Vector2) -> void:
	var tree := Node2D.new()
	tree.position = at
	parent.add_child(tree)
	tree_nodes.append(tree)
	var shadow := _ellipse(tree, Vector2(100, 22), Color(0.10, 0.18, 0.12, 0.2))
	decorative_shadows.append(shadow)
	var trunk := _sprite(tree, TREE_SHEET, regions["tree-parts-v05.png"][0], 92)
	trunk.position.y = -trunk.texture.get_height() * trunk.scale.y / 2.0
	var crown := _sprite(tree, TREE_SHEET, regions["tree-parts-v05.png"][1], 285)
	crown.position.y = -trunk.texture.get_height() * trunk.scale.y - crown.texture.get_height() * crown.scale.y * 0.25
	canopies.append(crown)

func _box(parent: Node, rect: Rect2, color: Color) -> Polygon2D:
	return _shape(parent, [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], color)

func _shape(parent: Node, points: Array, color: Color) -> Polygon2D:
	var node := Polygon2D.new()
	node.polygon = PackedVector2Array(points)
	node.color = color
	parent.add_child(node)
	return node

func _ellipse(parent: Node, radius: Vector2, color: Color) -> Polygon2D:
	var points: Array = []
	for i in range(20): points.append(Vector2(cos(TAU * i / 20) * radius.x, sin(TAU * i / 20) * radius.y))
	return _shape(parent, points, color)

func tick(delta: float, player: Vector2, elapsed: float, gust: float) -> void:
	for building in Layout.BUILDINGS:
		var reveal: bool = building.footprint.grow(25).has_point(player)
		roofs[building.id].modulate.a = move_toward(roofs[building.id].modulate.a, 0.08 if reveal else 1.0, delta * 4)
	for i in range(canopies.size()):
		canopies[i].rotation = sin(elapsed * 2.0 + i) * gust * 0.035 if animate and detailed_motion else 0.0

func apply_settings(settings: Dictionary) -> void:
	animate = settings.effects
	detailed_motion = settings.quality != "Low"
	for shadow in decorative_shadows: shadow.visible = settings.shadows

func _draw() -> void:
	# Reusable ground/road/sidewalk layers, independent of buildings and props.
	draw_rect(Rect2(Vector2.ZERO, Layout.SIZE), Color("cfbc92"))
	draw_rect(Rect2(0, 0, 1536, 310), Color("879b71"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for i in range(1400):
		var at := Vector2(rng.randf_range(0, 1536), rng.randf_range(0, 1024))
		draw_line(at, at + Vector2(rng.randf_range(1, 6), 0), Color(0.36, 0.31, 0.20, 0.10), 1)
	for x in range(0, 1600, 48):
		for y in [340, 390, 440, 760, 810, 860, 910, 960]:
			draw_rect(Rect2(x + (24 if y % 100 == 10 else 0), y, 47, 49), Color(0.85, 0.80, 0.65, 0.13), false, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 486), Vector2(1536, 555), Vector2(1536, 724), Vector2(0, 655)]), Color("7a8174"))
	for i in range(700):
		var x := rng.randf_range(0, 1536)
		var y := rng.randf_range(492, 650) + x * 0.045
		draw_line(Vector2(x, y), Vector2(x + 3, y), Color(0.16, 0.21, 0.17, 0.14), 1)
	for y in [486, 655]:
		draw_line(Vector2(0, y), Vector2(1536, y + 69), Color("acaa8e"), 12, true)
		draw_line(Vector2(0, y + 6), Vector2(1536, y + 75), Color("4b6655"), 2, true)
	for x in range(0, 1536, 110):
		draw_line(Vector2(x, 571 + x * 0.045), Vector2(x + 52, 573.3 + x * 0.045), Color("d8cfac"), 4, true)
	for y in range(519, 658, 22):
		draw_colored_polygon(PackedVector2Array([Vector2(730, y), Vector2(798, y + 3), Vector2(798, y + 13), Vector2(730, y + 10)]), Color("d8d2b9"))
	draw_rect(Rect2(260, 732, 380, 163), Color("a8ac7b"))
	for building in Layout.BUILDINGS:
		draw_rect(building.footprint.grow(5), Color("877c5f"))
		draw_rect(building.footprint, Color("caba92"))
