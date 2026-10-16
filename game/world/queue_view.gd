extends Control
## A bounded queue tableau. Saved positions drive existing distance-based walk cycles.
const Actor = preload("res://core/actor_visual.gd")
const Queue = preload("res://core/queue_task.gd")
const PEOPLE = preload("res://assets/pedestrians-v04.png")
const TRAFFIC = preload("res://assets/traffic-v04.png")
const HEROES = preload("res://assets/campaign-heroes.png")
var bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))
var task: Dictionary = {}
var phase := "line"
var ambient_motion := true
var people: Dictionary = {}
var positioned := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var person := Node2D.new()
		var visual := Actor.new()
		visual.configure(PEOPLE, bounds["pedestrians-v04.png"].slice(i * 4, i * 4 + 4), 60, false, [[0, 3, 2, 3]])
		visual.heading = "left"
		visual.walk(Vector2.ZERO)
		person.add_child(visual)
		add_child(person)
		people[Queue.catalogue().order[i]] = person
	resized.connect(func(): positioned = false; queue_redraw())

func update_state(value: Dictionary) -> void:
	task = value.duplicate(true)
	queue_redraw()

func slot(index: int) -> Vector2:
	return Vector2(size.x * (0.33 + index * 0.21), size.y * (0.72 if phase == "reset" else 0.81))

func _process(delta: float) -> void:
	if task.is_empty() or size.x < 20: return
	for id in people:
		var person: Node2D = people[id]
		person.visible = phase == "line"
		var index: int = task.order.find(id)
		if not positioned: person.position = slot(index)
		var goal := slot(index)
		if task.lineReady and phase == "line": goal.x = -80 - index * 60
		var before := person.position
		person.position = person.position.move_toward(goal, minf(delta, 0.1) * 90) if ambient_motion else goal
		var visual = person.get_child(0)
		if not is_equal_approx(visual.display_height, size.y * 0.36):
			visual.display_height = size.y * 0.36
		visual.walk(person.position - before if ambient_motion else Vector2.ZERO)
	positioned = true
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("b9ba94"))
	draw_rect(Rect2(0, h * 0.5, w, h * 0.5), Color("b8a47b"))
	draw_rect(Rect2(w * 0.03, h * 0.24, w * 0.18, h * 0.37), Color("64826f"))
	draw_rect(Rect2(w * 0.02, h * 0.57, w * 0.2, 10), Color("e7d4a4"))
	draw_string(ThemeDB.fallback_font, Vector2(w * 0.04, h * 0.44), "DESK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f5edcd"))
	for i in range(3):
		if phase != "line": break
		var at := slot(i)
		draw_rect(Rect2(at.x - w * 0.075, h * 0.68, w * 0.15, h * 0.18), Color("d5c598"), false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(at.x - 4, h * 0.94), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("25483a"))
	for id in people:
		var person: Node2D = people[id]
		if phase == "line": draw_ellipse(person.position + Vector2(0, -1), 12, 3, Color(0.15, 0.23, 0.17, 0.18))
	var bus_source := Rect2(16, 154, 839, 441)
	var bus_width := minf(w * 0.23, h * 0.35 * 839 / 441)
	var bus_ground := Vector2(w * 0.86, h * 0.68)
	draw_rect(Rect2(w * 0.74, h * 0.49, w * 0.25, h * 0.21), Color("8e9880"))
	draw_ellipse(bus_ground + Vector2(0, -1), bus_width * 0.4, 3, Color(0.15, 0.23, 0.17, 0.18))
	draw_texture_rect_region(TRAFFIC, Rect2(bus_ground - Vector2(bus_width / 2, bus_width * 441 / 839), Vector2(bus_width, bus_width * 441 / 839)), bus_source)
	if phase == "reset":
		draw_rect(Rect2(w * 0.43, h * 0.43, w * 0.23, h * 0.14), Color("8e9880"), false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.45, h * 0.41), "CHAIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("25483a"))
		var hero_source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
		var hero_h := h * 0.57
		var hero_w := hero_h * hero_source.x / hero_source.y
		draw_texture_rect_region(HEROES, Rect2(w * 0.3 - hero_w / 2, h * 0.78 - hero_h, hero_w, hero_h), Rect2(Vector2(2 * hero_source.x, 0), hero_source))
		var upright: bool = task.get("bucketUpright", false)
		var clear: bool = task.get("aisleClear", false)
		draw_rect(Rect2(w * 0.23, h * 0.87, w * 0.58, h * 0.1), Color("e0d09e"), false, 2)
		var bucket := Vector2(w * 0.87, h * 0.82) if upright else Vector2(w * 0.48, h * 0.94)
		draw_set_transform(bucket, 0 if upright else PI * 0.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(6, 0), Vector2(-6, 0)]), Color("b97849"))
		draw_line(Vector2(-9, -18), Vector2(9, -18), Color("ead9b3"), 2)
		draw_set_transform(Vector2.ZERO)
		for i in range(2):
			var x: float = w * (0.5 + i * 0.1) if clear else w * (0.57 + i * 0.1)
			var y: float = h * (0.54 if clear else 0.92)
			draw_rect(Rect2(x - 7, y - 17, 14, 4), Color("6f6048"))
			draw_line(Vector2(x - 6, y - 14), Vector2(x - 6, y), Color("6f6048"), 2)
			draw_line(Vector2(x + 6, y - 14), Vector2(x + 6, y), Color("6f6048"), 2)
	if phase == "allocation":
		draw_rect(Rect2(w * 0.28, h * 0.29, w * 0.39, h * 0.5), Color("eee3c5"))
		for i in range(4): draw_line(Vector2(w * 0.32, h * (0.4 + i * 0.075)), Vector2(w * 0.62, h * (0.4 + i * 0.075)), Color("8c9c7b"), 2)
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.32, h * 0.37), "RESERVED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("25483a"))
	draw_rect(Rect2(6, 4, minf(w - 12, 430), 24), Color("eee3c5"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "FUEL QUEUE · " + ("EMPTY PROP / CLEAR AISLE" if phase == "reset" else "TRANSPORT RESERVATION" if phase == "allocation" else "TICKETS CHECKED" if phase == "served" else "FRONT AT THE SERVICE DESK"), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, Color("25483a"))
