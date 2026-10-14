extends Control
## Bounded painted scenery follows the bus from above and the side.
const TRAFFIC = preload("res://assets/traffic-v04.png")
const BUILDINGS = preload("res://assets/building-parts-v05.png")
const TREES = preload("res://assets/tree-parts-v05.png")
var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment-bounds-v05.json"))
var drive: Dictionary = {}
var visual_distance := 0.0
var visual_lane := 1.0
var age := 0.0
var target := 350.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func update_state(value: Dictionary, goal: float) -> void:
	if drive.is_empty():
		visual_distance = value.distance
		visual_lane = value.lane
	if not drive.is_empty() and value.misses != drive.misses: visual_distance = value.distance
	drive = value.duplicate(true)
	target = goal
	age = 0
	queue_redraw()

func _process(delta: float) -> void:
	if drive.is_empty(): return
	age = minf(0.8, age + minf(delta, 0.1))
	# Cosmetic prediction only; server distance/ready own progression.
	var predicted: float = drive.distance + (drive.speed * age if not drive.ready else 0.0)
	visual_distance = lerpf(visual_distance, minf(target + 90, predicted), minf(1, delta * 10))
	visual_lane = lerpf(visual_lane, float(drive.lane), minf(1, delta * 8))
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var offset := visual_distance * 2
	draw_rect(Rect2(Vector2.ZERO, size), Color("a7b38b"))
	draw_rect(Rect2(0, h * 0.39, w, h * 0.13), Color("d0bd90"))
	draw_rect(Rect2(0, h * 0.52, w, h * 0.42), Color("7f8a7b"))
	draw_rect(Rect2(0, h * 0.94, w, h * 0.06), Color("c3b086"))
	for index in range(-2, int(w / 160) + 4):
		var lot: int = floori(offset / 160) + index
		var x: float = lot * 160 - offset
		var kind := posmod(lot, 3)
		_stamp(BUILDINGS, regions["building-parts-v05.png"][kind], Vector2(x + 62, h * 0.47), 118)
		_stamp(BUILDINGS, regions["building-parts-v05.png"][kind + 3], Vector2(x + 62, h * 0.28), 128)
		if posmod(lot, 2) == 0:
			_stamp(TREES, regions["tree-parts-v05.png"][0], Vector2(x + 145, h * 0.5), 28)
			_stamp(TREES, regions["tree-parts-v05.png"][1], Vector2(x + 145, h * 0.26), 82)
	for index in range(-1, int(w / 50) + 2):
		var x := index * 50 - fposmod(offset, 50)
		draw_rect(Rect2(x, h * 0.72, 25, 3), Color("ddd5ad"))
	var bus_x := w * 0.35
	var bay_x := bus_x + (target - visual_distance) * 2
	var bay := Rect2(bay_x - 55, h * 0.77, 110, h * 0.15)
	draw_rect(bay, Color(0.20, 0.49, 0.58, 0.45))
	draw_rect(bay, Color("cfe6d3"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(bay_x - 42, h * 0.77 - 4), "SAFE BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f4efdb"))
	var ground := h * (0.69 + visual_lane * 0.2)
	draw_ellipse(Vector2(bus_x, ground - 1), 58, 5, Color(0.12, 0.22, 0.16, 0.22))
	_stamp(TRAFFIC, [16, 154, 839, 441], Vector2(bus_x, ground), 145)
	draw_rect(Rect2(6, 4, 264, 24), Color(0.96, 0.94, 0.85, 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "BABA GOD DEY · MORNING ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("193c32"))

func _stamp(sheet: Texture2D, source: Array, bottom: Vector2, width: float) -> void:
	var height: float = width * float(source[3]) / float(source[2])
	draw_texture_rect_region(sheet, Rect2(bottom - Vector2(width / 2, height), Vector2(width, height)), Rect2(source[0], source[1], source[2], source[3]))
