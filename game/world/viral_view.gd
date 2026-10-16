extends Control
const HEROES = preload("res://assets/campaign-heroes.png")
var scene_id := "desk"
var state: Dictionary = {}
var package: Dictionary = {}
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func update_state(value: Dictionary, pack: Dictionary) -> void:
	state = value.duplicate(true)
	package = pack.duplicate(true)
	queue_redraw()
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("8b9e89"))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("897255"))
	var screen := Rect2(w * 0.4, h * 0.2, w * 0.55, h * 0.47)
	draw_rect(screen.grow(4), Color("34443b"))
	draw_rect(screen, Color("eee3c5"))
	var font := ThemeDB.fallback_font
	draw_string(font, screen.position + Vector2(10, 20), "CORRECTION + SOURCES", HORIZONTAL_ALIGNMENT_LEFT, screen.size.x - 16, 12, Color("25483a"))
	for i in range(2):
		var phase: String = ["rumour", "correction"][i]
		var ready: bool = state.get(phase, {}).get("ready", false)
		var y := screen.position.y + 39 + i * 22
		draw_circle(Vector2(screen.position.x + 14, y - 4), 4, Color("527a46") if ready else Color("ad8d55"))
		draw_string(font, Vector2(screen.position.x + 24, y), ("CHECKED " if ready else "READ ") + phase.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, screen.size.x - 30, 11, Color("25483a"))
	draw_line(Vector2(w * 0.68, h * 0.68), Vector2(w * 0.68, h * 0.91), Color("34443b"), 5)
	var source := Vector2(HEROES.get_width() / 3.0, HEROES.get_height())
	var height := h * 0.72
	var width := height * source.x / source.y
	var feet := Vector2(w * 0.22, h * 0.94)
	draw_texture_rect_region(HEROES, Rect2(feet - Vector2(width / 2, height), Vector2(width, height)), Rect2(Vector2(source.x * 2, 0), source))
	draw_rect(Rect2(6, 4, w - 12, 24), Color("eee3c5"))
	draw_string(font, Vector2(12, 20), "VIRAL · " + ("COMMUNITY SCREEN" if scene_id == "screen" else "SOURCE DESK"), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, Color("25483a"))
