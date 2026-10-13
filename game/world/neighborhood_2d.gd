extends Node2D
## Illustrated street with bounded traffic, pedestrian routines and authored chatter.

const StreetActivity = preload("res://core/street_activity.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
const STREET_ATLAS = preload("res://assets/street-life-atlas.png")
const BACKGROUND = preload("res://assets/street-painted.png")

const SIZE = Vector2(1536, 1024)
const PLACES = {
	"food": {"name": "Amaka's kitchen", "position": Vector2(405, 438)},
	"repair": {"name": "Yemi's workshop", "position": Vector2(780, 438)},
	"home": {"name": "Your little corner", "position": Vector2(1220, 438)},
	"square": {"name": "Community square", "position": Vector2(430, 785)},
	"park": {"name": "Park crew", "position": Vector2(725, 882)},
	"bus": {"name": "Bus stop", "position": Vector2(1180, 800)},
}
var camera: Camera2D
var hero: Node2D
var hero_sprite: Sprite2D
var home_flag: Polygon2D
var actors: Array[Node2D] = []
var people: Node2D
var street = StreetActivity.new()
var vehicle_nodes: Array[Node2D] = []
var pedestrian_nodes: Array[Node2D] = []
var crew: Dictionary = {}
var speakers: Dictionary = {}
var speech: PanelContainer
var speech_text: Label
var speech_actor: Node2D
var speech_remaining := 0.0
var chatter_timer := 3.0
var chatter_index := 0
var conversation_focus := false
var park_near := false
var park_familiar := false
var detailed_motion := true
var clock := 0.0
var motion := Vector2.ZERO
var animate := true
var facing := 0

func _ready() -> void:
	var bounds := Control.new()
	bounds.size = SIZE
	bounds.clip_contents = true
	bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bounds)
	var background := Sprite2D.new()
	background.texture = BACKGROUND
	background.centered = false
	background.scale = SIZE / background.texture.get_size()
	bounds.add_child(background)
	camera = Camera2D.new()
	camera.position = SIZE / 2
	add_child(camera)
	people = Node2D.new()
	people.y_sort_enabled = true
	bounds.add_child(people)
	hero = _person(Vector2(768, 635), 0)
	people.add_child(hero)
	hero_sprite = hero.get_node("Sprite")
	for item in [[Vector2(360, 427), 0], [Vector2(830, 432), 0]]:
		var actor := _person(item[0], item[1])
		if actors.size() < 2:
			var sprite: Sprite2D = actor.get_node("Sprite")
			sprite.texture = preload("res://assets/neighbors.png")
			sprite.hframes = 2
			sprite.vframes = 1
			sprite.frame = actors.size()
			sprite.scale = Vector2.ONE * (96.0 / sprite.texture.get_height())
			sprite.position.x = -15 if actors.is_empty() else 15
		people.add_child(actor)
		actors.append(actor)
	speakers.amaka = actors[0]
	speakers.yemi = actors[1]
	_build_street_life()
	# Reuse painted foreground pixels as occluders, so passing cars go behind
	# the tree canopy and bus shelter rather than driving over their roofs.
	_foreground([Vector2(0, 376), Vector2(76, 367), Vector2(325, 423), Vector2(385, 475), Vector2(404, 575), Vector2(285, 657), Vector2(175, 695), Vector2(0, 726)], 730)
	_foreground([Vector2(1016, 557), Vector2(1055, 530), Vector2(1397, 568), Vector2(1458, 540), Vector2(1536, 560), Vector2(1536, 610), Vector2(1034, 582)], 805)
	_foreground([Vector2(1092, 671), Vector2(1130, 598), Vector2(1450, 602), Vector2(1536, 655), Vector2(1536, 839), Vector2(1400, 826), Vector2(1110, 777), Vector2(1087, 735)], 805)
	_foreground([Vector2(1025, 574), Vector2(1036, 574), Vector2(1036, 773), Vector2(1025, 773)], 805)
	for key in PLACES:
		var label := Label.new()
		label.text = PLACES[key].name
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color("fff6d6"))
		label.add_theme_color_override("font_outline_color", Color("183e33"))
		label.add_theme_constant_override("outline_size", 8)
		label.position = PLACES[key].position - Vector2(90, 112)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	home_flag = Polygon2D.new()
	home_flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(43, 0), Vector2(43, 55), Vector2(21, 43), Vector2(0, 55)])
	home_flag.position = Vector2(1150, 438)
	add_child(home_flag)
	set_wall("sage")
	_build_speech()

func _atlas_region(rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = STREET_ATLAS
	texture.region = rect
	return texture

func _foreground(points: Array, ground_y: float) -> void:
	var anchor := Node2D.new()
	anchor.position.y = ground_y
	var painted := Polygon2D.new()
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in points:
		polygon.append(point - anchor.position)
		uv.append(point)
	painted.polygon = polygon
	painted.uv = uv
	painted.texture = BACKGROUND
	anchor.add_child(painted)
	people.add_child(anchor)

func _build_street_life() -> void:
	var vehicle_regions := [Rect2(16, 90, 540, 332), Rect2(557, 140, 552, 286), Rect2(1110, 125, 426, 308)]
	for vehicle in street.vehicles:
		var car := Node2D.new()
		car.position = street.vehicle_position(vehicle)
		var shadow := _shadow(Vector2(vehicle.width * 0.4, 11))
		car.add_child(shadow)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = _atlas_region(vehicle_regions[vehicle.kind])
		var scale_factor: float = vehicle.width / sprite.texture.get_width()
		sprite.scale = Vector2.ONE * scale_factor
		sprite.position.y = -sprite.texture.get_height() * scale_factor / 2.0
		sprite.flip_h = vehicle.direction < 0
		car.add_child(sprite)
		people.add_child(car)
		vehicle_nodes.append(car)
	var colors := [Color("ece1d1"), Color("b8cebc"), Color("d9bb96"), Color("acc7d4"), Color("d9b1b8"), Color("ddd39b")]
	for i in range(street.walkers.size()):
		var walker := _person(street.walkers[i].position, 6)
		walker.get_node("Sprite").modulate = colors[i]
		people.add_child(walker)
		pedestrian_nodes.append(walker)
	var crew_data := [
		["razor", Vector2(626, 866), Rect2(174, 426, 247, 557)],
		["smallie", Vector2(693, 920), Rect2(665, 449, 249, 534)],
		["chidi", Vector2(788, 892), Rect2(1065, 433, 365, 550)],
	]
	for item in crew_data:
		var actor := _person(item[1], 0)
		var sprite: Sprite2D = actor.get_node("Sprite")
		sprite.texture = _atlas_region(item[2])
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.scale = Vector2.ONE * (100.0 / sprite.texture.get_height())
		sprite.position.y = -50
		people.add_child(actor)
		crew[item[0]] = actor
		speakers[item[0]] = actor
	# Conductor belongs to the parked background danfo, not a moving vehicle.
	var conductor := _person(Vector2(1044, 832), 4)
	conductor.get_node("Sprite").modulate = Color("c7d1e3")
	people.add_child(conductor)
	actors.append(conductor)
	speakers.conductor = conductor

func _shadow(radius: Vector2) -> Polygon2D:
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * i / 20
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	shadow.polygon = points
	shadow.color = Color(0.08, 0.17, 0.12, 0.28)
	return shadow

func _build_speech() -> void:
	speech = PanelContainer.new()
	speech.z_index = 20
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4efdb")
	style.border_color = Color("284b3c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	speech.add_theme_stylebox_override("panel", style)
	speech_text = Label.new()
	speech_text.custom_minimum_size.x = 240
	speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_text.add_theme_font_size_override("font_size", 18)
	speech_text.add_theme_color_override("font_color", Color("193c32"))
	speech_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech.add_child(speech_text)
	add_child(speech)
	speech.hide()

func say(speaker: String, line: String) -> void:
	if not speakers.has(speaker):
		return
	if not _speaker_on_screen(speakers[speaker]):
		return
	speech_actor = speakers[speaker]
	speech_text.text = line
	speech_remaining = 4.5
	speech.size = Vector2(264, 0)
	speech.show()

func _speaker_on_screen(actor: Node2D) -> bool:
	var point := actor.get_global_transform_with_canvas().origin - Vector2(0, 45) * camera.zoom
	return get_viewport_rect().grow(-24).has_point(point)

func crew_hit(point: Vector2) -> bool:
	for actor in crew.values():
		if point.distance_to(actor.position - Vector2(0, 45)) < 48:
			return true
	return false

func _person(at: Vector2, frame: int) -> Node2D:
	var person := Node2D.new()
	person.position = at
	person.add_child(_shadow(Vector2(23, 7)))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = preload("res://assets/neighbor-walk.png")
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.frame = frame
	sprite.scale = Vector2.ONE * (96.0 / (sprite.texture.get_height() / 2.0))
	sprite.position.y = -45
	person.add_child(sprite)
	return person

func move_animation(direction: Vector2) -> void:
	motion = direction
	if direction.length() > 0.1:
		if absf(direction.x) > absf(direction.y):
			facing = 4 if direction.x < 0 else 6
		else:
			facing = 2 if direction.y < 0 else 0

func _process(delta: float) -> void:
	clock += delta
	hero_sprite.frame = facing + (int(clock * 7) % 2 if motion.length() > 0.1 else 0)
	for i in range(actors.size()):
		actors[i].get_node("Sprite").position.y = -45 + (sin(clock * 1.6 + i) * 1.5 if animate and detailed_motion else 0)
	street.advance(delta, hero.position)
	for i in range(vehicle_nodes.size()):
		vehicle_nodes[i].position = street.vehicle_position(street.vehicles[i])
	for i in range(pedestrian_nodes.size()):
		var walker: Dictionary = street.walkers[i]
		pedestrian_nodes[i].position = walker.position
		var sprite: Sprite2D = pedestrian_nodes[i].get_node("Sprite")
		var direction: Vector2 = walker.direction
		if direction.length() > 0.1 and animate:
			sprite.frame = (4 if direction.x < 0 else 6) + int(clock * 5 + i) % 2
		else:
			sprite.frame = int(sprite.frame / 2.0) * 2
	for i in range(crew.size()):
		crew.values()[i].get_node("Sprite").rotation = sin(clock * 0.9 + i * 2.0) * 0.025 if animate and detailed_motion else 0.0
	home_flag.rotation = sin(clock * 1.2) * 0.02 if animate and detailed_motion else 0.0
	_tick_chatter(delta)

func _tick_chatter(delta: float) -> void:
	var near_park: bool = hero.position.distance_to(PLACES.park.position) < 170
	if near_park and not park_near and not conversation_focus:
		say("razor", "Razor: Neighbor! Come gist, or keep moving." if park_familiar else "Razor: New face! Come gist, or keep moving.")
	park_near = near_park
	speech_remaining -= delta
	if speech_remaining <= 0 or conversation_focus or (speech_actor != null and not _speaker_on_screen(speech_actor)):
		speech.hide()
	elif speech_actor != null:
		speech.position = speech_actor.position - Vector2(speech.size.x / 2, 106 + speech.size.y)
		var half_width: float = get_viewport_rect().size.x / camera.zoom.x / 2.0
		speech.position.x = clampf(speech.position.x, camera.position.x - half_width + 8, camera.position.x + half_width - speech.size.x - 8)
	chatter_timer -= delta
	if chatter_timer <= 0:
		chatter_timer = 5.5
		if not conversation_focus and animate:
			# Pick a nearby speaker, then their reply on the following turn.
			for attempt in range(Dialogue.CHATTER.size()):
				var item: Array = Dialogue.CHATTER[chatter_index]
				chatter_index = (chatter_index + 1) % Dialogue.CHATTER.size()
				if speakers[item[0]].position.distance_to(hero.position) < 580 and _speaker_on_screen(speakers[item[0]]):
					say(item[0], item[1])
					break

func resize_view(size: Vector2) -> void:
	var factor := minf(size.x / SIZE.x, size.y / SIZE.y)
	# Portrait offers a readable central street slice; venue navigation pans to its destination.
	if size.x < 850:
		factor = size.y / SIZE.y
	camera.zoom = Vector2.ONE * factor
	camera.position = Vector2(clampf(hero.position.x, 480, 1056), 512) if size.x < 850 else SIZE / 2

func set_wall(color: String) -> void:
	if home_flag != null:
		home_flag.color = Color("90aa87") if color == "sage" else Color("c98160") if color == "clay" else Color("5a9eb1")

func apply_settings(settings: Dictionary) -> void:
	animate = settings.effects
	detailed_motion = settings.quality != "Low"
	street.configure(settings)
	for i in range(actors.size()):
		actors[i].visible = true
		actors[i].get_child(0).visible = settings.shadows
	for i in range(vehicle_nodes.size()):
		vehicle_nodes[i].visible = i < street.traffic_count
		vehicle_nodes[i].get_child(0).visible = settings.shadows
	for i in range(pedestrian_nodes.size()):
		pedestrian_nodes[i].visible = i < street.walker_count
		pedestrian_nodes[i].get_child(0).visible = settings.shadows
	for actor in crew.values():
		actor.get_child(0).visible = settings.shadows
	hero.get_child(0).visible = settings.shadows
	# HD source is shared for now; downloadable art tiers are a later optimization.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func walkable(point: Vector2) -> bool:
	return Rect2(100, 420, 1340, 540).has_point(point)
