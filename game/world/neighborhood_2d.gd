extends Node2D
## Fixed-camera illustrated street. Painted depth, sprite animation and original assets.

const SIZE = Vector2(1536, 1024)
const PLACES = {
	"food": {"name": "Amaka's kitchen", "position": Vector2(405, 438)},
	"repair": {"name": "Yemi's workshop", "position": Vector2(780, 438)},
	"home": {"name": "Your little corner", "position": Vector2(1220, 438)},
	"square": {"name": "Community square", "position": Vector2(430, 785)},
	"bus": {"name": "Bus stop", "position": Vector2(1180, 800)},
}
var camera: Camera2D
var hero: Node2D
var hero_sprite: Sprite2D
var home_flag: Polygon2D
var actors: Array[Node2D] = []
var decorations: Array[Node2D] = []
var clock := 0.0
var motion := Vector2.ZERO
var animate := true
var facing := 0

func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = preload("res://assets/street-painted.png")
	background.centered = false
	background.scale = SIZE / background.texture.get_size()
	add_child(background)
	camera = Camera2D.new()
	camera.position = SIZE / 2
	add_child(camera)
	var people := Node2D.new()
	people.y_sort_enabled = true
	add_child(people)
	hero = _person(Vector2(768, 635), 0)
	people.add_child(hero)
	hero_sprite = hero.get_node("Sprite")
	for item in [[Vector2(360, 427), 0], [Vector2(830, 432), 0], [Vector2(965, 650), 4], [Vector2(635, 700), 0]]:
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

func _person(at: Vector2, frame: int) -> Node2D:
	var person := Node2D.new()
	person.position = at
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * i / 20
		points.append(Vector2(cos(angle) * 23, sin(angle) * 7))
	shadow.polygon = points
	shadow.color = Color(0.08, 0.17, 0.12, 0.28)
	person.add_child(shadow)
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
		actors[i].get_node("Sprite").position.y = -45 + (sin(clock * 1.6 + i) * 1.5 if animate else 0)

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
	for i in range(actors.size()):
		actors[i].visible = i < mini(2 + int(settings.distance), 2 if settings.quality == "Low" else 3 if settings.quality == "Medium" else 4)
		actors[i].get_child(0).visible = settings.shadows
	hero.get_child(0).visible = settings.shadows
	# HD source is shared for now; downloadable art tiers are a later optimization.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func walkable(point: Vector2) -> bool:
	return Rect2(100, 420, 1340, 540).has_point(point)
