extends Control
const HEROES = preload("res://assets/campaign-heroes.png")
var lead := "ngozi"
var scene_id := "yard"
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("afbc98"))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("c4af80"))
	if scene_id == "sites":
		for i in range(3):
			var x := w * (0.04 + i * 0.325)
			var panel := Rect2(x, h * 0.22, w * 0.29, h * 0.64)
			draw_rect(panel, Color("e7d7b0"))
			if i == 0:
				draw_rect(Rect2(x + 10, h * 0.4, w * 0.23, h * 0.37), Color("886d50"))
				draw_rect(Rect2(x + 8, h * 0.34, w * 0.24, h * 0.09), Color("8d493c"))
			elif i == 1:
				draw_rect(Rect2(x + 10, h * 0.36, w * 0.23, h * 0.4), Color("b18a5a"))
				draw_rect(Rect2(x + 17, h * 0.45, w * 0.07, h * 0.29), Color("385346"))
				draw_rect(Rect2(x + w * 0.15, h * 0.43, w * 0.06, h * 0.12), Color("8cadac"))
			else:
				draw_rect(Rect2(x + 8, h * 0.33, w * 0.25, h * 0.32), Color("8ca9b2"))
				draw_rect(Rect2(x + 10, h * 0.7, w * 0.23, 5), Color("4b7256"))
			_generator(Vector2(x + w * 0.14, h * 0.76), minf(42, w * 0.09))
			draw_string(ThemeDB.fallback_font, Vector2(x + 10, h * 0.3), ["A · STORE", "B · DOOR", "C · YARD"][i], HORIZONTAL_ALIGNMENT_LEFT, w * 0.27, 13, Color("254137"))
	else:
		draw_rect(Rect2(w * 0.06, h * 0.24, w * 0.3, h * 0.38), Color("c49d6d"))
		draw_rect(Rect2(w * 0.04, h * 0.2, w * 0.34, 12), Color("8c483b"))
		draw_rect(Rect2(w * 0.12, h * 0.33, w * 0.07, h * 0.29), Color("385346"))
		draw_rect(Rect2(w * 0.22, h * 0.33, w * 0.08, h * 0.13), Color("8cadac"))
		draw_rect(Rect2(w * 0.38, h * 0.69, w * 0.5, 4), Color("537452"))
		_generator(Vector2(w * 0.7, h * 0.79), 58)
		var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
		var hero_h := h * 0.61
		var hero_w := hero_h * source.x / source.y
		for i in range(2):
			var x := w * (0.43 + i * 0.13)
			draw_texture_rect_region(HEROES, Rect2(x - hero_w / 2, h * 0.93 - hero_h, hero_w, hero_h), Rect2(Vector2(i * source.x, 0), source))
			if ["tunde", "ngozi"][i] == lead: draw_rect(Rect2(x - 18, h - 6, 36, 3), Color("d4ed85"))
	draw_rect(Rect2(6, 3, minf(w - 12, 300), 23), Color("f0e2c0"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 19), "GENERATOR WARS · " + ("SITE BOARD" if scene_id == "sites" else "COMMUNITY YARD"), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, Color("254137"))
func _generator(bottom: Vector2, width: float) -> void:
	var body := Rect2(bottom - Vector2(width / 2, width * 0.6), Vector2(width, width * 0.5))
	draw_rect(body.grow(4), Color("2d473c"), false, 3)
	draw_rect(body, Color("bd934e"))
	draw_rect(Rect2(body.position + Vector2(width * 0.59, 4), Vector2(width * 0.3, width * 0.36)), Color("385346"))
	draw_line(body.position + Vector2(8, -5), body.position + Vector2(width - 8, -5), Color("2d473c"), 4)
