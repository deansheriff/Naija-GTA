extends Control
## Illustrated story camera and posed KC scenes, without a device-camera feed.
const HEROES = preload("res://assets/campaign-heroes.png")
var phone: Dictionary = {}
var task: Dictionary = {}
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_state(value: Dictionary, current: Dictionary) -> void:
	phone = value.duplicate(true)
	task = current.duplicate(true)
	queue_redraw()
static func included(p: Dictionary) -> Array:
	if p.get("zoom", 2) == 2: return [int(p.get("pan", 0))]
	if p.get("pan", 0) == 1: return [0, 1, 2]
	return [0, 1] if p.get("pan", 0) == 0 else [1, 2]
func _draw() -> void:
	var w := size.x
	var h := size.y
	var framing: bool = task.get("kind") == "frame"
	var review: bool = task.get("scene") == "review"
	draw_rect(Rect2(Vector2.ZERO, size), Color("a69d7c"))
	if framing or review:
		draw_rect(Rect2(0, 0, w, h), Color("243f35"))
		var p := phone if framing else {"pan": 1, "zoom": 1}
		var visible_subjects := included(p)
		var subjects: Array = task.get("subjects", ["MC", "Service-exit sign", "Helping action"])
		var tile_w: float = (w - 28) / visible_subjects.size()
		for i in range(visible_subjects.size()):
			var index: int = visible_subjects[i]
			var rect := Rect2(14 + i * tile_w, 35, tile_w - 6, h - 47)
			draw_rect(rect, Color("c2af88"))
			var c := rect.get_center()
			var practice: bool = task.get("scene") == "practice"
			if index == 0:
				if practice:
					draw_arc(c - Vector2(0, 12), minf(tile_w * 0.23, 24), 0, TAU, 32, Color("474e3e"), 5)
					draw_line(c + Vector2(0, 10), c + Vector2(0, 39), Color("474e3e"), 4)
				else:
					_person(c - Vector2(0, 18), Color("774344"))
					draw_rect(Rect2(c.x - 20, c.y + 5, 40, 34), Color("795438"))
			elif index == 1:
				if practice: _person(c - Vector2(0, 12), Color("476f62"))
				else:
					draw_rect(Rect2(c.x - 27, c.y - 23, 54, 28), Color("315647"))
					draw_string(ThemeDB.fallback_font, c + Vector2(-21, -3), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ede6c9"))
			else:
				if practice:
					draw_rect(Rect2(c.x - 25, c.y - 25, 50, 48), Color("89a99b"))
					draw_line(c + Vector2(0, -25), c + Vector2(0, 23), Color("e3d5b0"), 4)
					draw_line(c + Vector2(-25, -1), c + Vector2(25, -1), Color("e3d5b0"), 4)
				else:
					_person(c - Vector2(15, 11), Color("86604b"))
					_person(c + Vector2(15, 2), Color("657452"))
					draw_line(c + Vector2(-12, 3), c + Vector2(17, 6), Color("684934"), 6)
			var caption := str(index + 1) if w < 600 else str(index + 1) + " · " + str(subjects[index])
			draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 7, rect.end.y - 7), caption, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 14, 14, Color("254137"))
		draw_rect(Rect2(5, 28, w - 10, h - 33), Color("d4ed85") if phone.get("ready", false) and framing else Color("e9dec2"), false, 3)
		draw_string(ThemeDB.fallback_font, Vector2(12, 20), "ILLUSTRATED STORY CAMERA · PRIVATE", HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color("ede6c9"))
	else:
		var charging: bool = task.get("scene") in ["street", "charging"]
		draw_rect(Rect2(0, h * 0.71, w, h * 0.29), Color("a58b64"))
		if charging:
			for i in range(8): draw_rect(Rect2(i * w / 8, 0, w / 8 + 1, 29), Color("476d5b") if i % 2 == 0 else Color("d9c696"))
			draw_rect(Rect2(w * 0.6, h * 0.55, w * 0.26, 10), Color("795438"))
			draw_line(Vector2(w * 0.65, h * 0.55), Vector2(w * 0.65, h * 0.9), Color("795438"), 6)
		else:
			draw_rect(Rect2(w * 0.13, 33, w * 0.22, h * 0.34), Color("809e90"))
			draw_line(Vector2(w * 0.24, 33), Vector2(w * 0.24, h * 0.34 + 33), Color("d7c69d"), 5)
			draw_arc(Vector2(w * 0.72, h * 0.4), 24, 0, TAU, 32, Color("565947"), 5)
			draw_line(Vector2(w * 0.72, h * 0.52), Vector2(w * 0.72, h * 0.91), Color("565947"), 5)
		var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
		var hero_h := h * 0.88
		var hero_w := hero_h * source.x / source.y
		draw_texture_rect_region(HEROES, Rect2(w * 0.46 - hero_w / 2, h - hero_h, hero_w, hero_h), Rect2(Vector2(source.x * 2, 0), source))
		draw_rect(Rect2(7, 4, minf(w - 14, 300), 22), Color("efe1bd"))
		draw_string(ThemeDB.fallback_font, Vector2(13, 20), "FOUR PERCENT · KC'S STORY PHONE", HORIZONTAL_ALIGNMENT_LEFT, w - 26, 13, Color("254137"))
func _person(head: Vector2, clothes: Color) -> void:
	draw_circle(head, 11, Color("725039"))
	draw_rect(Rect2(head + Vector2(-13, 11), Vector2(26, 34)), clothes)
