extends Control
const HEROES = preload("res://assets/campaign-heroes.png")
var lead := "ngozi"
var scene_id := "meeting"
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	var quiet := scene_id == "quiet"
	draw_rect(Rect2(Vector2.ZERO, size), Color("aabb95") if quiet else Color("c3af82"))
	draw_rect(Rect2(w * 0.1, 28, w * 0.8, h * 0.68), Color("698370") if quiet else Color("456052"))
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Color("ac9268"))
	for i in range(10): draw_rect(Rect2(i * w / 10, 0, w / 10 + 1, 26), Color("93433a") if i % 2 == 0 else Color("d8c79a"))
	var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	var hero_h := h * 0.79
	var hero_w := hero_h * source.x / source.y
	for i in range(3):
		var x := w * (0.25 + i * 0.25)
		draw_texture_rect_region(HEROES, Rect2(x - hero_w / 2, h - hero_h - 7, hero_w, hero_h), Rect2(Vector2(i * source.x, 0), source))
	draw_rect(Rect2(w * 0.12, h * 0.84, w * 0.76, h * 0.16), Color("795438"))
	draw_rect(Rect2(w * 0.1, h * 0.8, w * 0.8, 8), Color("dbbf88"))
	var bag := Rect2(w * 0.56, h * 0.68, 39, h * 0.12)
	draw_rect(bag, Color("a47b4e"))
	for i in range(3): draw_rect(Rect2(bag.position + Vector2(i * 13 + 3, 0), Vector2(4, bag.size.y)), Color("315e52"))
	draw_arc(bag.position + Vector2(19, 0), 8, PI, TAU, 12, Color("684c35"), 3)
	draw_rect(Rect2(w * 0.32, h * 0.74, 35, h * 0.06), Color("eee1c0"))
	draw_rect(Rect2(w * 0.73, h * 0.7, 17, h * 0.1), Color("254238"))
	var active_index := ["tunde", "ngozi", "kc"].find(lead)
	if active_index >= 0: draw_rect(Rect2(w * (0.25 + active_index * 0.25) - 27, h - 10, 54, 4), Color("d4ed85"))
	draw_rect(Rect2(7, 4, minf(w - 14, 300), 22), Color("f0e2c0"))
	draw_string(ThemeDB.fallback_font, Vector2(13, 20), "FAMILY MEETING · " + ("QUIET SIDE" if quiet else "CANTEEN"), HORIZONTAL_ALIGNMENT_LEFT, w - 26, 13, Color("254137"))
