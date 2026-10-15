extends Control
## Bounded painted scenery follows the bus from above and the side.
const TRAFFIC = preload("res://assets/traffic-v04.png")
const BUILDINGS = preload("res://assets/building-parts-v05.png")
const TREES = preload("res://assets/tree-parts-v05.png")
const WALKERS = preload("res://assets/neighbors-walk-v07.png")
var actor_regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))
var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment-bounds-v05.json"))
var drive: Dictionary = {}
var visual_distance := 0.0
var visual_lane := 1.0
var age := 0.0
var target := 350.0
var route_label := "BABA GOD DEY · MORNING ROUTE"
var chase := false
var gate: Dictionary = {}
var route_style := 0
var ambient_motion := true
var ambience := 0.0
var cleared_age := 0.0

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
	if ambient_motion: ambience += minf(delta, 0.1)
	if drive.get("gateCleared", false): cleared_age = minf(3, cleared_age + minf(delta, 0.1))
	else: cleared_age = 0
	age = minf(0.8, age + minf(delta, 0.1))
	# Cosmetic prediction only; server distance/ready own progression.
	var predicted: float = drive.distance + (drive.speed * age if not drive.ready else 0.0)
	if not gate.is_empty() and not drive.get("gateCleared", false): predicted = minf(float(gate.at), predicted)
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
		var kind := posmod(lot + route_style, 3)
		_stamp(BUILDINGS, regions["building-parts-v05.png"][kind], Vector2(x + 62, h * 0.47), 118)
		_stamp(BUILDINGS, regions["building-parts-v05.png"][kind + 3], Vector2(x + 62, h * 0.28), 128)
		if posmod(lot, 2) == 0:
			_stamp(TREES, regions["tree-parts-v05.png"][0], Vector2(x + 145, h * 0.5), 28)
			_stamp(TREES, regions["tree-parts-v05.png"][1], Vector2(x + 145, h * 0.26), 82)
	for index in range(-1, int(w / 50) + 2):
		var x := index * 50 - fposmod(offset, 50)
		draw_rect(Rect2(x, h * 0.72, 25, 3), Color("ddd5ad"))
	var bus_x := w * (0.6 if chase else 0.35)
	if chase:
		var runner_x: float = bus_x - 145 + (sin(ambience * 1.3) * 6 if ambient_motion else 0)
		draw_ellipse(Vector2(runner_x, h * 0.89 - 1), 35, 3, Color(0.12, 0.22, 0.16, 0.2))
		_stamp(TRAFFIC, [876, 263, 763, 325], Vector2(runner_x, h * 0.89), 80)
	if not gate.is_empty(): _draw_gate(w, h, bus_x)
	var bay_x := bus_x + (target - visual_distance) * 2
	var bay := Rect2(bay_x - 55, h * 0.77, 110, h * 0.15)
	draw_rect(bay, Color(0.20, 0.49, 0.58, 0.45))
	draw_rect(bay, Color("cfe6d3"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(bay_x - 42, h * 0.77 - 4), "SAFE BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f4efdb"))
	var ground := h * (0.69 + visual_lane * 0.2)
	draw_ellipse(Vector2(bus_x, ground - 1), 58, 5, Color(0.12, 0.22, 0.16, 0.22))
	_stamp(TRAFFIC, [16, 154, 839, 441], Vector2(bus_x, ground), 145)
	draw_rect(Rect2(6, 4, minf(w - 12, 430), 24), Color(0.96, 0.94, 0.85, 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), route_label, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color("193c32"))

func _draw_gate(w: float, h: float, bus_x: float) -> void:
	var x: float = bus_x + (float(gate.at) - visual_distance) * 2
	var cleared: bool = drive.get("gateCleared", false)
	var bay := Rect2(x - 55, h * 0.77, 110, h * 0.15)
	draw_rect(bay, Color(0.56, 0.39, 0.12, 0.5))
	draw_rect(bay, Color("f1da99"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(x - 44, h * 0.77 - 4), "WAITING BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff0c0"))
	if gate.kind == "crossing":
		var crossing_x := x + 88
		for i in range(5): draw_rect(Rect2(crossing_x, h * (0.54 + i * 0.075), 34, h * 0.045), Color("e8dfbd"))
		if not cleared:
			for i in range(2):
				var phase := fposmod(ambience * 0.16 + i * 0.5, 1.0) if ambient_motion else 0.4 + i * 0.3
				var feet := Vector2(crossing_x + 12 + phase * 16, h * (0.37 + phase * 0.85))
				var frame: int = i * 4 + (int(ambience * 4) % 4 if ambient_motion else 1)
				_stamp(WALKERS, actor_regions["neighbors-walk-v07.png"][frame], feet, 18)
	else:
		var move := cleared_age * 230 if cleared else 0.0
		for i in range(2):
			var car_x: float = x + 135 + i * 110 + move
			var ground := h * (0.69 if i == 1 else 0.89)
			draw_ellipse(Vector2(car_x, ground - 1), 38, 3, Color(0.12, 0.22, 0.16, 0.2))
			_stamp(TRAFFIC, [876, 263, 763, 325], Vector2(car_x, ground), 87)

func _stamp(sheet: Texture2D, source: Array, bottom: Vector2, width: float) -> void:
	var height: float = width * float(source[3]) / float(source[2])
	draw_texture_rect_region(sheet, Rect2(bottom - Vector2(width / 2, height), Vector2(width, height)), Rect2(source[0], source[1], source[2], source[3]))
