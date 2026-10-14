extends SceneTree

const Routines = preload("res://core/npc_routines.gd")
const Layout = preload("res://world/district_layout.gd")
const Simulation = preload("res://core/simulation.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	var layout = Layout.new()
	var routines = Routines.new(layout)
	routines.advance(0.1)
	check(Routines.phase_at("amaka", 510) == "break" and Routines.phase_at("yemi", 510) == "work", "Staggered tea breaks")
	check(Routines.phase_at("amaka", 1200) == "home" and Routines.phase_at("yemi", 1140) == "home", "Individual closing times")
	check(Routines.phase_at("amaka", 360) == "work" and Routines.phase_at("yemi", 1440) == "home", "Opening and midnight wrap")
	for who in routines.agents:
		for time in [530.0, 600.0, 1250.0, 400.0]:
			routines.minutes = time
			var agent: Dictionary = routines.agents[who]
			routines.advance(0.01)
			var route: PackedVector2Array = agent.route
			check(not route.is_empty(), who + " has a complete route for " + agent.phase)
			var previous: Vector2 = agent.position
			var safe := true
			for i in range(2200):
				routines.advance(0.1)
				var point: Vector2 = agent.position
				if point.distance_to(previous) > 6.41: safe = false
				# Off-screen home exits use the clear pavement extension.
				if layout.WALK_BOUNDS.has_point(point) and (not layout.walkable(point) or layout.on_main_road(point)): safe = false
				previous = point
				if agent.route.is_empty(): break
			check(safe and agent.route.is_empty(), who + " reaches " + agent.phase + " without walls, main-road traffic or jumps")
	var paused: Vector2 = routines.agents.amaka.position
	routines.minutes = 530
	routines.advance(3, true)
	check(routines.agents.amaka.position == paused, "Conversation focus holds NPC position")
	var sim = Simulation.new()
	check(not sim.neighbor_choice("favor_finish").ok and not sim.neighbor_choice("favor_accept").ok, "Favor cannot skip greeting/delivery gates")
	sim.meet_amaka()
	for choice in ["yemi_hello", "yemi_hello", "park_welcome", "park_welcome", "park_space", "favor_accept", "favor_deliver", "favor_finish"]:
		check(sim.neighbor_choice(choice).ok, "Approved local neighbor choice " + choice)
	check(sim.data.coins == 270 and sim.data.social == 4 and sim.data.neighbors.amaka == 3, "Local outcomes match authoritative contract")
	check(not sim.neighbor_choice("favor_finish").ok and not sim.neighbor_choice("favor_accept").ok and sim.data.coins == 270, "Fresh command cannot repeat favor reward")
	var restored = Simulation.new()
	restored.load_json(JSON.stringify({"version": 1, "state": sim.data}), false)
	check(restored.data.favor == "complete" and restored.data.neighbors.park_choice == "space" and restored.data.neighbors.yemi == 3, "Cloud cache/local loader preserves quest and boundaries")
	var old = Simulation.new()
	old.load_json('{"version":1,"state":{"met_amaka":true,"coins":315}}', false)
	check(old.data.neighbors.amaka == 1 and old.data.favor == "available" and old.data.coins == 315, "Old version-1 saves upgrade without resetting progress")
	check(Dialogue.neighbor_line("amaka", restored.data, "On a pavement break").contains("trusted") and Dialogue.chatter("complete", false)[3][1].contains("good neighbor"), "Dialogue and paired chatter respond to saved outcome")
	var sheet: Texture2D = load("res://assets/neighbors-walk-v07.png")
	var image := sheet.get_image()
	image.decompress()
	check(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(380, 500).a < 0.01, "Named walking atlas has genuine alpha gaps")
	var bounds: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite-bounds-v04.json"))["neighbors-walk-v07.png"]
	var upper_end := 0.0
	var lower_start := float(image.get_height())
	for i in range(4):
		upper_end = maxf(upper_end, bounds[i][1] + bounds[i][3])
		lower_start = minf(lower_start, bounds[i + 4][1])
	check(lower_start - upper_end > 1 and lower_start < image.get_height() / 2.0, "Real alpha gutter separates rows without clipping Yemi's head into Amaka's frames")
	call_deferred("render_checks")

func render_checks() -> void:
	var world = load("res://world/neighborhood_2d.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.apply_settings({"quality": "Low", "distance": 0, "effects": false, "shadows": false})
	world._process(0.1)
	world.routines.minutes = 530
	var poses := {}
	var moved := 0.0
	for i in range(20):
		world._process(0.1)
		var visual = world.speakers.amaka.get_node("Sprite")
		poses[visual.pose_index] = true
		moved += world.routines.agents.amaka.movement.length()
	check(poses.size() > 1 and moved > 60, "Actual named actor changes walking poses on Low with ambient effects off")
	var visual = world.speakers.amaka.get_node("Sprite")
	check(absf(visual.position.y + visual.texture.get_height() * visual.scale.y / 2) < 0.01, "Rendered named actor feet stay on their route")
	var before: Vector2 = world.speakers.amaka.position
	world.conversation_focus = true
	world._process(2)
	check(world.speakers.amaka.position == before and visual.pose_index < 0, "Conversation freezes named route and uses an actual idle pose")
	var sim = Simulation.new()
	sim.neighbor_choice("park_space")
	world.set_context(sim.data)
	world.hero.position = world.places.park.position
	world.park_near = false
	world.conversation_focus = false
	world.speech_remaining = 0
	world.chatter_timer = 5
	world._tick_chatter(0.1)
	check(world.park_boundary and world.speech_remaining <= 0, "Saved park boundary suppresses unsolicited approach greetings")
	world.queue_free()
	print("NPC routines and relationships: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
