extends Control
## Original protagonist poses with code-native invitation, service desk and quiet corner.
const HEROES = preload("res://assets/campaign-heroes.png")
var scene_id := "invitation"
var lead := "ngozi"
var heading := ""
var receipt: Dictionary = {}
func update_receipt(value: Dictionary) -> void:
	receipt = value.duplicate(true)
	queue_redraw()
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("c5bd96"))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("998261"))
	for i in range(10):
		var x := w * i / 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 24), Vector2(x + 20, 24), Vector2(x + 10, 43)]), Color("77947b") if i % 2 == 0 else Color("ddc17c"))
	if scene_id == "quiet":
		draw_rect(Rect2(w * 0.04, h * 0.24, w * 0.28, h * 0.45), Color("798b77"))
		draw_rect(Rect2(w * 0.46, h * 0.2, w * 0.5, h * 0.5), Color("aaad8d"))
	else:
		draw_rect(Rect2(w * 0.04, h * 0.27, w * 0.91, h * 0.2), Color("b4a57b"))
	for i in range(2):
		var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
		var height := h * 0.7
		var width := height * source.x / source.y
		var feet := Vector2(w * (0.31 if i == 0 else 0.67), h * 0.89)
		draw_texture_rect_region(HEROES, Rect2(feet - Vector2(width / 2, height), Vector2(width, height)), Rect2(Vector2((i + 1) * source.x, 0), source))
		if (lead == "ngozi" and i == 0) or (lead == "kc" and i == 1): draw_line(feet + Vector2(-width / 2, 4), feet + Vector2(width / 2, 4), Color("eed77c"), 3)
	draw_rect(Rect2(w * 0.42, h * 0.59, w * 0.18, h * 0.32), Color("6e6048"))
	draw_rect(Rect2(w * 0.37, h * 0.56, w * 0.28, 12), Color("79664d"))
	if scene_id == "invitation":
		draw_rect(Rect2(w * 0.42, h * 0.31, w * 0.18, h * 0.25), Color("eee3c5"))
		var cx := w * 0.51
		draw_colored_polygon(PackedVector2Array([Vector2(cx, h * 0.34), Vector2(cx - 14, h * 0.49), Vector2(cx + 14, h * 0.49)]), Color("77947b"))
	elif scene_id == "service":
		draw_style_box(_tray(), Rect2(w * 0.43, h * 0.48, w * 0.16, h * 0.08))
	else:
		draw_rect(Rect2(w * 0.44, h * 0.43, w * 0.14, h * 0.13), Color("e7dbb7"))
		for i in range(3): draw_line(Vector2(w * 0.46, h * (0.46 + i * 0.025)), Vector2(w * 0.56, h * (0.46 + i * 0.025)), Color("73816a"), 1)
	if not receipt.is_empty():
		for i in range(3): draw_circle(Vector2(w * (0.47 + i * 0.04), h * 0.52), 3, Color("78935b") if receipt.answers.has(["time", "account", "issue"][i]) else Color("b8b08d"))
	draw_rect(Rect2(6, 4, minf(w - 12, 430), 24), Color("eee3c5"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), heading if not heading.is_empty() else "ASO-EBI · " + ("QUIET SERVICE CORNER" if scene_id == "quiet" else "INVITED CATERING GUESTS"), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, Color("25483a"))
func _tray() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d8d7bd")
	style.set_corner_radius_all(8)
	return style
