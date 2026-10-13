extends Node2D
## Illustrated street with bounded traffic, pedestrian routines and authored chatter.

const StreetActivity = preload("res://core/street_activity.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
const ActorVisual = preload("res://core/actor_visual.gd")
const DistrictLayout = preload("res://world/district_layout.gd")
const ModularScenery = preload("res://world/modular_scenery.gd")
const STREET_ATLAS = preload("res://assets/street-life-atlas.png")
const HERO_SHEET = preload("res://assets/hero-walk-v04.png")
const HERO_IDLE_SHEET = preload("res://assets/hero-idle-v04.png")
const PEDESTRIAN_SHEET = preload("res://assets/pedestrians-v04.png")
const WILDLIFE_SHEET = preload("res://assets/wildlife-v04.png")
const TRAFFIC_SHEET = preload("res://assets/traffic-v04.png")

const SIZE = Vector2(1536, 1024)
const PLACES = {
	"food": {"name": "Amaka's kitchen", "position": Vector2(405, 400)},
	"repair": {"name": "Yemi's workshop", "position": Vector2(780, 400)},
	"home": {"name": "Your little corner", "position": Vector2(1220, 400)},
	"square": {"name": "Community square", "position": Vector2(430, 785)},
	"park": {"name": "Park crew", "position": Vector2(725, 882)},
	"bus": {"name": "Bus stop", "position": Vector2(1035, 870)},
}
var camera: Camera2D
var layout = DistrictLayout.new()
var scenery: Node2D
var hero: Node2D
var hero_sprite
var home_flag: Polygon2D
var actors: Array[Node2D] = []
var people: Node2D
var street = StreetActivity.new()
var vehicle_nodes: Array[Node2D] = []
var pedestrian_nodes: Array[Node2D] = []
var dog_nodes: Array[Node2D] = []
var bird_nodes: Array[Node2D] = []
var leaf_nodes: Array[Polygon2D] = []
var sprite_bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))
var previous_hero_position := Vector2.ZERO
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
var animate := true

func _ready() -> void:
	var bounds := Control.new()
	bounds.size = SIZE
	bounds.clip_contents = true
	bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bounds)
	scenery = ModularScenery.new()
	bounds.add_child(scenery)
	camera = Camera2D.new()
	camera.position = SIZE / 2
	add_child(camera)
	people = Node2D.new()
	people.y_sort_enabled = true
	bounds.add_child(people)
	scenery.build(people, sprite_bounds)
	hero = _person(Vector2(768, 635), "hero")
	people.add_child(hero)
	hero_sprite = hero.get_node("Sprite")
	previous_hero_position = hero.position
	for item in [[Vector2(301, 350), 0], [Vector2(676, 350), 1]]:
		var actor := _still_person(item[0], preload("res://assets/neighbors.png"), sprite_bounds["neighbors.png"][item[1]], 100)
		people.add_child(actor)
		actors.append(actor)
	speakers.amaka = actors[0]
	speakers.yemi = actors[1]
	_build_street_life()
	_build_nature(bounds)
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

func _atlas_region(rect: Rect2, sheet: Texture2D = STREET_ATLAS) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = rect
	return texture

func _build_street_life() -> void:
	var vehicle_regions: Array = sprite_bounds["traffic-v04.png"]
	for vehicle in street.vehicles:
		var car := Node2D.new()
		car.position = street.vehicle_position(vehicle)
		car.rotation = atan(StreetActivity.ROAD_SLOPE)
		var shadow := _shadow(Vector2(vehicle.width * 0.43, 9))
		shadow.position.y = -3
		car.add_child(shadow)
		# Tire contact stays visible even when decorative shadows are disabled.
		for side in [-1, 1]:
			var contact := _shadow(Vector2(vehicle.width * 0.095, 4))
			contact.color = Color(0.08, 0.13, 0.09, 0.52)
			contact.position = Vector2(vehicle.width * side * 0.28, -1)
			car.add_child(contact)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		var rect: Array = vehicle_regions[vehicle.kind]
		sprite.texture = _atlas_region(Rect2(rect[0], rect[1], rect[2], rect[3]), TRAFFIC_SHEET)
		var scale_factor: float = vehicle.width / sprite.texture.get_width()
		sprite.scale = Vector2.ONE * scale_factor
		sprite.position.y = -sprite.texture.get_height() * scale_factor / 2.0
		sprite.flip_h = vehicle.direction < 0
		car.add_child(sprite)
		people.add_child(car)
		vehicle_nodes.append(car)
	var kinds := ["market_woman", "office_worker", "elder", "market_woman", "office_worker", "elder"]
	for i in range(street.walkers.size()):
		var walker := _person(street.walkers[i].position, kinds[i], 94 if kinds[i] == "elder" else 100)
		people.add_child(walker)
		pedestrian_nodes.append(walker)
	var crew_data := [
		["razor", Vector2(626, 866), 0],
		["smallie", Vector2(693, 920), 1],
		["chidi", Vector2(788, 892), 2],
	]
	for item in crew_data:
		var actor := _still_person(item[1], STREET_ATLAS, sprite_bounds["street-life-atlas.png"][item[2]], 100)
		people.add_child(actor)
		crew[item[0]] = actor
		speakers[item[0]] = actor
	# Conductor belongs to the parked modular danfo, not a moving vehicle.
	var conductor := _person(Vector2(1044, 832), "office_worker", 100)
	people.add_child(conductor)
	actors.append(conductor)
	speakers.conductor = conductor

func _build_nature(bounds: Control) -> void:
	for i in range(street.dogs.size()):
		var dog := _person(street.dogs[i].position, "dog", 42)
		dog.get_node("Sprite").stride = 45.0
		if i == 1: dog.get_node("Sprite").modulate = Color("d7cec2")
		people.add_child(dog)
		dog_nodes.append(dog)
	var bird_regions: Array = []
	for i in range(4):
		bird_regions.append([i * WILDLIFE_SHEET.get_width() / 4.0, WILDLIFE_SHEET.get_height() / 2.0, WILDLIFE_SHEET.get_width() / 4.0, WILDLIFE_SHEET.get_height() / 2.0])
	for i in range(3):
		var bird := Node2D.new()
		bird.z_index = 25
		var sprite = ActorVisual.new()
		sprite.name = "Sprite"
		sprite.grounded = false
		sprite.configure(WILDLIFE_SHEET, bird_regions, 48)
		bird.add_child(sprite)
		bounds.add_child(bird)
		bird_nodes.append(bird)
	for i in range(6):
		var leaf := Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -2), Vector2(5, 0), Vector2(0, 2)])
		leaf.color = Color("9eaa56")
		leaf.z_index = 24
		bounds.add_child(leaf)
		leaf_nodes.append(leaf)

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

func _person(at: Vector2, kind: String = "hero", height: float = 96) -> Node2D:
	var person := Node2D.new()
	person.position = at
	person.add_child(_shadow(Vector2(23, 7)))
	var sprite = ActorVisual.new()
	sprite.name = "Sprite"
	if kind == "hero":
		sprite.configure(HERO_SHEET, sprite_bounds["hero-walk-v04.png"], height, true, [[0, 1, 2, 3], [0, 3, 2, 3], [0, 1, 2, 3]])
		sprite.configure_idle(HERO_IDLE_SHEET, sprite_bounds["hero-idle-v04.png"])
		sprite.stride = 100.0
	elif kind == "dog":
		sprite.configure(WILDLIFE_SHEET, sprite_bounds["wildlife-v04.png"].slice(0, 4), height)
		person.get_child(0).scale = Vector2(1.25, 0.65)
	else:
		var row: int = ["market_woman", "office_worker", "elder"].find(kind)
		sprite.configure(PEDESTRIAN_SHEET, sprite_bounds["pedestrians-v04.png"].slice(row * 4, row * 4 + 4), height, false, [[0, 3, 2, 3]])
	person.add_child(sprite)
	return person

func _still_person(at: Vector2, sheet: Texture2D, rect: Array, height: float) -> Node2D:
	var person := Node2D.new()
	person.position = at
	person.add_child(_shadow(Vector2(23, 7)))
	var sprite = ActorVisual.new()
	sprite.name = "Sprite"
	sprite.configure(sheet, [rect], height)
	person.add_child(sprite)
	return person

func _process(delta: float) -> void:
	clock += delta
	hero_sprite.walk(hero.position - previous_hero_position)
	previous_hero_position = hero.position
	for i in range(actors.size()):
		var visual = actors[i].get_node("Sprite")
		visual.position = visual.base_position + Vector2(0, sin(clock * 1.6 + i) * 0.7 if animate and detailed_motion else 0)
	street.advance(delta, hero.position)
	for i in range(vehicle_nodes.size()):
		vehicle_nodes[i].position = street.vehicle_position(street.vehicles[i])
	for i in range(pedestrian_nodes.size()):
		var walker: Dictionary = street.walkers[i]
		# Animate real steps, excluding the off-screen recycling jump.
		pedestrian_nodes[i].get_node("Sprite").walk(walker.movement)
		pedestrian_nodes[i].position = walker.position
	for i in range(dog_nodes.size()):
		dog_nodes[i].get_node("Sprite").walk(street.dogs[i].position - dog_nodes[i].position)
		dog_nodes[i].position = street.dogs[i].position
	for i in range(bird_nodes.size()):
		bird_nodes[i].position = street.bird_position(i)
		bird_nodes[i].get_node("Sprite").flight(street.elapsed + i, i == 1)
	for i in range(crew.size()):
		crew.values()[i].get_node("Sprite").rotation = sin(clock * 0.9 + i * 2.0) * 0.025 if animate and detailed_motion else 0.0
	home_flag.rotation = sin(clock * 1.2) * 0.02 if animate and detailed_motion else 0.0
	_tick_wind(delta)
	_tick_chatter(delta)

func _tick_wind(delta: float) -> void:
	var gust: float = street.gust_strength() if animate and detailed_motion else 0.0
	scenery.tick(delta, hero.position, street.elapsed, gust)
	var phase: float = fposmod(street.elapsed + 1.0, 19.0)
	for i in range(leaf_nodes.size()):
		leaf_nodes[i].visible = gust > 0.02 and animate and detailed_motion
		leaf_nodes[i].position = Vector2(190 + i * 13 + phase * 35, 590 + i * 18 + phase * 7 + sin(phase * 2 + i) * 8)
		leaf_nodes[i].rotation = phase * 1.5 + i
		leaf_nodes[i].modulate.a = gust * 0.7

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
	# Interior feet can be above the old pavement limit. Follow them upward
	# in portrait so the player's head stays below the objective panel.
	camera.position = Vector2(clampf(hero.position.x, 480, 1056), clampf(hero.position.y, 360, 680)) if size.x < 850 else SIZE / 2

func set_wall(color: String) -> void:
	if home_flag != null:
		home_flag.color = Color("90aa87") if color == "sage" else Color("c98160") if color == "clay" else Color("5a9eb1")

func apply_settings(settings: Dictionary) -> void:
	animate = settings.effects
	detailed_motion = settings.quality != "Low"
	street.configure(settings)
	scenery.apply_settings(settings)
	for i in range(actors.size()):
		actors[i].visible = true
		actors[i].get_child(0).visible = settings.shadows
	for i in range(vehicle_nodes.size()):
		vehicle_nodes[i].visible = i < street.traffic_count
		vehicle_nodes[i].get_child(0).visible = settings.shadows
	for i in range(pedestrian_nodes.size()):
		pedestrian_nodes[i].visible = i < street.walker_count
		pedestrian_nodes[i].get_child(0).visible = settings.shadows
	for i in range(dog_nodes.size()):
		dog_nodes[i].visible = i < street.dog_count
		dog_nodes[i].get_child(0).visible = settings.shadows
	for i in range(bird_nodes.size()): bird_nodes[i].visible = i < street.bird_count
	for actor in crew.values():
		actor.get_child(0).visible = settings.shadows
	hero.get_child(0).visible = settings.shadows
	# HD source is shared for now; downloadable art tiers are a later optimization.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func walkable(point: Vector2) -> bool:
	return layout.walkable(point)

func move_player(displacement: Vector2) -> void:
	hero.position = layout.move(hero.position, displacement)

func route_to(point: Vector2) -> PackedVector2Array:
	return layout.route(hero.position, point)
