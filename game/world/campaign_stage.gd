extends Control
## Layered wedding staging. Characters are posed art, not walking animations.
const HEROES = preload("res://assets/campaign-heroes.png")
var scene_id := "hall"
var lead := "tunde"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	var dark := scene_id == "blackout"
	draw_style_box(_panel(Color("26382f") if dark else Color("c9b891")), Rect2(Vector2.ZERO, size))
	var floor_y := h * 0.5
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color("364139") if dark else Color("b4946c"))
	for x in range(0, int(w), 64):
		draw_line(Vector2(x, floor_y), Vector2(x - 40, h), Color(0.23, 0.26, 0.18, 0.15), 1)
	for i in range(9):
		var x := w * (i + 0.5) / 9
		draw_line(Vector2(x, 0), Vector2(x, 24 + (i % 2) * 8), Color("716948"), 1)
		draw_circle(Vector2(x, 27 + (i % 2) * 8), 4, Color("7c8065") if dark else Color("f8e6a5"))
	draw_rect(Rect2(0, 0, 28, floor_y + 18), Color("633940"))
	draw_rect(Rect2(w - 28, 0, 28, floor_y + 18), Color("633940"))
	# A clear central aisle, independent service tables and a collection tray.
	draw_rect(Rect2(w * 0.42, floor_y, w * 0.16, h * 0.5), Color("a98c5c") if not dark else Color("434b3b"))
	for side in [0.14, 0.86]:
		var p := Vector2(w * side, h * 0.67)
		paint_oval(p, Vector2(minf(w * 0.1, 55), 18), Color("e2c69c") if not dark else Color("5d6050"))
		for n in range(3): draw_circle(p + Vector2((n - 1) * 16, -2), 6, Color("dccda6") if not dark else Color("70705d"))
	draw_rect(Rect2(w * 0.74, 50, 42, 22), Color("315647"))
	draw_string(ThemeDB.fallback_font, Vector2(w * 0.74 + 4, 66), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e9e6cb"))
	var source_size := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	var hero_h := minf(h * 0.79, 230)
	var hero_w := hero_h * source_size.x / source_size.y
	for i in range(3):
		var x := w * (0.31 + i * 0.19)
		var selected: bool = ["tunde", "ngozi", "kc"][i] == lead
		if selected: paint_oval(Vector2(x, h - 9), Vector2(hero_w * 0.36, 4), Color("d4ed85"))
		draw_texture_rect_region(HEROES, Rect2(x - hero_w / 2, h - hero_h - 10, hero_w, hero_h), Rect2(Vector2(i * source_size.x, 0), source_size), Color("787f72") if dark else Color.WHITE)
	if dark: draw_string(ThemeDB.fallback_font, Vector2(42, 45), "POWER OUT · Everyone stays together", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e9e6cb"))
func paint_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24): points.append(center + Vector2(cos(i * TAU / 24) * radius.x, sin(i * TAU / 24) * radius.y))
	draw_colored_polygon(points, color)
func _panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	return style
