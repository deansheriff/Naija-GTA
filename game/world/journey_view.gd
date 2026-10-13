extends Node2D
## Stream a bounded set of seeded street chunks around an elevated side camera.

signal arrived(destination: int)
const Model = preload("res://core/journey.gd")
const Neighborhood = preload("res://world/neighborhood_2d.gd")
const Layout = preload("res://world/district_layout.gd")
const BUS_SHEET = preload("res://assets/traffic-v04.png")
var model = Model.new()
var chunks: Dictionary = {}
var camera: Camera2D
var bus: Node2D
var settings: Dictionary = {}
var max_loaded := 0
var viewport_size := Vector2(1280, 720)

func begin(origin: int, destination: int, graphics: Dictionary) -> bool:
	if not model.start(origin, destination): return false
	settings = graphics.duplicate(true)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	bus = Node2D.new()
	bus.z_index = 2
	add_child(bus)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))
	var data: Array = metadata["traffic-v04.png"][0]
	var atlas := AtlasTexture.new()
	atlas.atlas = BUS_SHEET
	atlas.region = Rect2(data[0], data[1], data[2], data[3])
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * 280 / data[2]
	sprite.position.y = -atlas.get_height() * sprite.scale.y / 2
	bus.add_child(sprite)
	# Contact patches are essential on every tier, including ambient effects off.
	for x in [-78, 78]:
		var contact := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(16): points.append(Vector2(cos(TAU * i / 16) * 23 + x, sin(TAU * i / 16) * 4 - 1))
		contact.polygon = points
		contact.color = Color(0.08, 0.12, 0.08, 0.6)
		bus.add_child(contact)
	_sync()
	return true

func _process(delta: float) -> void:
	if bus == null: return
	var done: bool = model.advance(delta)
	_sync()
	if done: arrived.emit(model.destination)

func _sync() -> void:
	var needed: Array[int] = model.visible_chunks()
	for index in chunks.keys():
		if index not in needed:
			chunks[index].queue_free()
			chunks.erase(index)
	for index in needed:
		if chunks.has(index): continue
		var chunk = Neighborhood.new()
		chunk.travel_chunk = true
		chunk.district_id = model.origin if index == 0 else model.destination if index == model.last_chunk else -1
		chunk.layout = Layout.new(model.seed_for(index), true, false)
		chunk.position.x = index * Model.CHUNK_WIDTH
		add_child(chunk)
		chunk.apply_settings(settings)
		chunks[index] = chunk
	max_loaded = maxi(max_loaded, chunks.size())
	bus.position = model.position
	for chunk in chunks.values():
		chunk.hero.position = Vector2(-500, -500)
	resize_view(viewport_size)

func resize_view(size: Vector2) -> void:
	viewport_size = size
	if camera == null: return
	var factor: float = size.y / Layout.SIZE.y if size.x < 850 else minf(size.x / Layout.SIZE.x, size.y / Layout.SIZE.y)
	# Very wide windows still fit inside the three loaded tiles.
	factor = maxf(factor, size.x / (Model.CHUNK_WIDTH * 1.5))
	camera.zoom = Vector2.ONE * factor
	camera.position = Vector2(model.position.x + 70, clampf(model.position.y - 110, 430, 650))

func skip() -> void:
	model.skip_to_arrival()
	_sync()

func apply_settings(graphics: Dictionary) -> void:
	settings = graphics.duplicate(true)
	for chunk in chunks.values(): chunk.apply_settings(settings)
