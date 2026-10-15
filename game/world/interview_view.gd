extends Control
const HEROES = preload("res://assets/campaign-heroes.png")
var scene_id := "desk"
var portfolio: Dictionary = {}
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_state(value: Variant) -> void:
	portfolio = value.duplicate(true) if value is Dictionary else {}
	queue_redraw()
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("bbb68d"))
	draw_rect(Rect2(w * 0.06, h * 0.2, w * 0.29, h * 0.38), Color("819f92"))
	draw_line(Vector2(w * 0.205, h * 0.2), Vector2(w * 0.205, h * 0.58), Color("d9c999"), 5)
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("9e8864"))
	var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	var hero_h := h * 0.78
	var hero_w := hero_h * source.x / source.y
	draw_texture_rect_region(HEROES, Rect2(w * 0.38 - hero_w / 2, h - hero_h - 8, hero_w, hero_h), Rect2(Vector2(source.x * 2, 0), source))
	draw_rect(Rect2(w * 0.48, h * 0.78, w * 0.44, 9), Color("6c4f38"))
	var screen := Rect2(w * 0.55, h * 0.29, w * 0.3, h * 0.43)
	draw_rect(screen.grow(5), Color("294c40"))
	draw_rect(screen, Color("dae3c5"))
	for i in range(3):
		var y := screen.position.y + screen.size.y * (0.19 + i * 0.25)
		var answered: bool = not str(portfolio.get("answers", {}).get(["role", "source", "context"][i], "")).is_empty()
		draw_circle(Vector2(screen.position.x + 12, y + 2), 4, Color("557e65") if answered else Color("b8b390"))
		draw_line(Vector2(screen.position.x + 25, y + 2), Vector2(screen.end.x - 10, y + 2), Color("89a18a"), 3)
	draw_rect(Rect2(w * 0.53, h * 0.73, w * 0.34, h * 0.04), Color("365a4a"))
	draw_rect(Rect2(w * 0.85, h * 0.57, w * 0.06, h * 0.15), Color("ecdfb8"))
	draw_rect(Rect2(6, 4, minf(w - 12, 340), 23), Color("f0e2c0"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "JAPA INTERVIEW · " + ("PORTFOLIO BOARD" if scene_id == "board" else "OPEN WINDOW CALL" if scene_id == "call" else "KC'S DESK"), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, Color("254137"))
