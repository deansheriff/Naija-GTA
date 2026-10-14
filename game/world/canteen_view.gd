extends Control
## Posed Ngozi staging under her canteen awning. Records are readable UI below.
const HEROES = preload("res://assets/campaign-heroes.png")
var scene_id := "canteen"
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("bdac82"))
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("a58a61"))
	# Shaded serving room, rather than a shopkeeper standing in the road.
	draw_rect(Rect2(w * 0.13, 24, w * 0.74, h * 0.66), Color("456052"))
	for i in range(5):
		var x := w * 0.17 + i * w * 0.14
		draw_line(Vector2(x, h * 0.72), Vector2(x + 18, h), Color(0.26, 0.31, 0.22, 0.16), 1)
	var hero_h := h * 0.86
	var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	var hero_w := hero_h * source.x / source.y
	draw_texture_rect_region(HEROES, Rect2(w * 0.41 - hero_w / 2, h - hero_h, hero_w, hero_h), Rect2(Vector2(source.x, 0), source))
	# Counter, covered dishes and a fictional terminal/document tray.
	draw_rect(Rect2(w * 0.16, h * 0.76, w * 0.68, h * 0.24), Color("795538"))
	draw_rect(Rect2(w * 0.14, h * 0.73, w * 0.72, 9), Color("d9bc84"))
	for i in range(2):
		var x := w * (0.23 + i * 0.1)
		draw_rect(Rect2(x, h * 0.65, 26, h * 0.08), Color("afb7a0"))
		draw_line(Vector2(x - 2, h * 0.65), Vector2(x + 28, h * 0.65), Color("e5dfc3"), 3)
	var pos := Rect2(w * 0.65, h * 0.53, 28, h * 0.19)
	draw_rect(pos, Color("233d34"))
	draw_rect(Rect2(pos.position + Vector2(4, 5), Vector2(20, 12)), Color("c6dc8f"))
	var paper := Rect2(w * 0.52, h * 0.66, 37, 11)
	draw_rect(paper, Color("ede4cb"))
	if scene_id in ["ledger", "invoice"]: draw_rect(paper.grow(3), Color("d4ed85"), false, 2)
	if scene_id == "pos": draw_rect(pos.grow(3), Color("d4ed85"), false, 2)
	# Striped fabric canopy, with an unobscured caption at every width.
	for i in range(12):
		draw_rect(Rect2(i * w / 12, 0, w / 12 + 1, 30), Color("923f3a") if i % 2 == 0 else Color("d6c492"))
	draw_rect(Rect2(7, 4, minf(w - 14, 280), 22), Color("f1e6c9"))
	draw_string(ThemeDB.fallback_font, Vector2(13, 20), "NGOZI'S CANTEEN · AJO DAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("25483a"))
