extends Control
const HEROES = preload("res://assets/campaign-heroes.png")
var lead := "tunde"
var state: Dictionary = {}
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_receipt(value: Dictionary) -> void:
	state = value.duplicate(true)
	queue_redraw()
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("b7b994"))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("8e795b"))
	draw_rect(Rect2(w * 0.12, h * 0.14, w * 0.76, h * 0.2), Color("718a74"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(w * 0.17, h * 0.25), "QUESTIONS + WRITTEN REPLIES", HORIZONTAL_ALIGNMENT_LEFT, w * 0.68, 12, Color("f4efdb"))
	var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	for i in range(3):
		var height := h * 0.64
		var width := height * source.x / source.y
		var feet := Vector2(w * (0.22 + i * 0.28), h * 0.94)
		draw_texture_rect_region(HEROES, Rect2(feet - Vector2(width / 2, height), Vector2(width, height)), Rect2(Vector2(source.x * i, 0), source))
		if lead == ["tunde", "ngozi", "kc"][i]: draw_line(feet + Vector2(-24, 1), feet + Vector2(24, 1), Color("eed77c"), 3)
	draw_rect(Rect2(w * 0.4, h * 0.64, w * 0.2, h * 0.3), Color("705b41"))
	draw_rect(Rect2(w * 0.36, h * 0.6, w * 0.28, h * 0.07), Color("e6d8b1"))
	for i in range(3): draw_circle(Vector2(w * (0.44 + i * 0.06), h * 0.63), 3, Color("527a46") if state.get("ready", false) else Color("b99c61") if state.get("answers", {}).has(["lights", "bus", "pay"][i]) else Color("8e795b"))
	draw_rect(Rect2(6, 4, w - 12, 24), Color("eee3c5"))
	draw_string(font, Vector2(12, 20), "PROMISES · FICTIONAL COMMUNITY FORUM", HORIZONTAL_ALIGNMENT_LEFT, w - 24, 10 if w < 500 else 12, Color("25483a"))
