extends SceneTree

const Visual = preload("res://core/actor_visual.gd")
const Activity = preload("res://core/street_activity.gd")
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	var bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))
	var hero = Visual.new()
	hero.configure(load("res://assets/hero-walk-v04.png"), bounds["hero-walk-v04.png"], 96, true, [[0, 1, 2, 3], [0, 3, 2, 3], [0, 1, 2, 3]])
	var seen: Dictionary = {}
	var stable := true
	var grounded := true
	for i in range(16):
		hero.walk(Vector2(9, 0))
		seen[hero.pose_index] = true
		stable = stable and hero.heading == "right" and not hero.flip_h and hero.pose_index < 4
		grounded = grounded and absf(hero.position.y + hero.texture.get_height() * hero.scale.y / 2.0) < 0.01
	check(stable and seen.size() == 4, "A full rightward stride changes leg poses without changing facing")
	check(grounded, "Every walking pose shares a feet baseline, independent of PNG padding")
	hero.walk(Vector2(-15, 0))
	check(hero.heading == "left" and hero.flip_h and hero.pose_index < 4, "Left uses the rightward cycle mirrored consistently")
	hero.walk(Vector2(0, -15))
	check(hero.heading == "up" and hero.pose_index >= 8, "Up selects a separate back-facing cycle")
	hero.walk(Vector2(0, 15))
	check(hero.heading == "down" and hero.pose_index >= 4 and hero.pose_index < 8, "Down selects the front-facing cycle")
	hero.walk(Vector2(15, 0))
	for i in range(10): hero.walk(Vector2(5.0, 5.0 + (0.1 if i % 2 == 0 else -0.1)))
	check(hero.heading == "right", "Near-diagonal direction noise does not flicker facing")
	hero.walk(Vector2(-5, -5))
	check(hero.heading == "left" and hero.flip_h, "Reversing a diagonal changes direction without changing the chosen axis")
	var travelled: float = hero.travelled
	hero.walk(Vector2.ZERO)
	check(hero.travelled == travelled, "Standing or blocked movement cannot advance the stride")
	var sparse = Visual.new()
	var dense = Visual.new()
	for visual in [sparse, dense]: visual.configure(load("res://assets/hero-walk-v04.png"), bounds["hero-walk-v04.png"], 96, true)
	for i in range(20): sparse.walk(Vector2(5, 0))
	for i in range(100): dense.walk(Vector2(1, 0))
	check(sparse.pose_index == dense.pose_index, "The same distance gives the same gait at different frame counts")
	var unique_legs: Dictionary = {}
	for rect in bounds["hero-walk-v04.png"].slice(0, 4):
		var image: Image = hero.frames[0].atlas.get_image()
		image.decompress()
		var legs := image.get_region(Rect2i(int(rect[0]), int(rect[1] + rect[3] * 0.65), int(rect[2]), int(rect[3] * 0.35)))
		unique_legs[legs.get_data().hex_encode().sha256_text()] = true
	check(unique_legs.size() > 1, "The asset's lower-body pixels actually differ between poses")
	var idle_sheet: Texture2D = load("res://assets/hero-idle-v04.png")
	hero.configure_idle(idle_sheet, bounds["hero-idle-v04.png"])
	hero.walk(Vector2.ZERO)
	check(hero.texture.atlas == idle_sheet and hero.pose_index < 0 and absf(hero.position.y + hero.texture.get_height() * hero.scale.y / 2.0) < 0.01, "Stopping selects a separate grounded standing pose, not a frozen walking leg")
	var nature = Activity.new()
	nature.configure({"quality": "High", "distance": 2, "effects": true})
	var dog_start: Vector2 = nature.dogs[0].position
	for i in range(100): nature.advance(0.1, Vector2(100, 960))
	check(nature.dogs[0].position.distance_to(dog_start) > 20, "Dogs roam rather than remain a static decoration")
	var bird_before: Vector2 = nature.bird_position(0)
	nature.advance(0.1, Vector2(100, 960))
	check(nature.bird_position(0).distance_to(bird_before) > 1, "Bird flight moves across the scene")
	nature.elapsed = 9.0
	check(nature.gust_strength() == 0, "Foliage has calm periods between gusts")
	nature.elapsed = 1.5
	check(nature.gust_strength() > 0.9, "Occasional gusts have a measurable peak")
	nature.configure({"quality": "Low", "distance": 0, "effects": false})
	var elapsed: float = nature.elapsed
	nature.advance(0.1, Vector2(100, 960))
	check(nature.elapsed == elapsed and nature.dog_count == 1 and nature.bird_count == 1, "Low retains wildlife; animation preference freezes the ambience clock")
	for visual in [hero, sparse, dense]: visual.free()
	print("Actor and nature: %s checks, %s failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
