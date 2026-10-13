extends SceneTree

const Simulation = preload("res://core/simulation.gd")
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	var state = Simulation.new()
	check(not state.begin_action("gig").ok, "Skill-gated gig cannot begin too early")
	check(state.begin_action("learn").ok, "Free repair practice starts")
	check(not state.begin_action("rest").ok, "Concurrent activity rejected")
	state.tick(8)
	check(state.data.repair == 1, "Completed practice unlocks Repair 1")
	check(state.begin_action("gig").ok, "Qualified gig starts")
	var before: int = state.data.coins
	state.tick(10)
	state.tick(10)
	check(state.data.coins == before + 90, "Repeated tick cannot duplicate gig payment")
	check(not state.begin_action("gig").ok, "Completed starter gig cannot be claimed again")
	state.data.coins = 20
	check(not state.begin_action("eat").ok and state.data.coins == 20, "Insufficient food purchase leaves balance intact")
	state.data.energy = 5
	check(not state.begin_action("learn").ok, "Low energy has an actionable rest gate")
	check(state.begin_action("rest").ok, "Rest remains accessible at low energy")
	state.tick(8)
	check(state.data.energy >= 39, "Rest recovers energy")
	state.reset()
	check(state.goal().step == 1, "First goal points to neighbor")
	state.meet_amaka()
	state.meet_amaka()
	check(state.data.social == 1 and state.goal().step == 2, "Repeated greeting does not farm relationship level")
	state.data.coins = 240
	check(state.post_job("Fix my radio", 30).ok and state.data.coins == 110, "Posting fee and budget reserved once")
	check(state.cancel_job("1") and state.data.coins == 140, "Cancel returns budget, retains disclosed posting fee")
	check(not state.cancel_job("1") and state.data.coins == 140, "Repeated cancellation cannot duplicate refund")
	check(not state.post_job("x", 30).ok and state.data.coins == 140, "Invalid listing does not charge")
	var path := "user://simulation-test.json"
	state.data.name = "Test neighbor"
	state.decorate("ocean")
	state.data.settings.quality = "Low"
	state.data.settings.manual = true
	state.data.settings.fps = 60
	state.data.settings.distance = 2
	check(state.save_to(path), "First save succeeds")
	check(state.save_to(path), "Atomic overwrite succeeds")
	var restored = Simulation.new()
	check(restored.load_from(path).ok, "Versioned save loads")
	check(restored.data.name == "Test neighbor" and restored.data.wall == "ocean", "Profile and home survive restart")
	check(restored.data.settings.quality == "Low" and restored.data.settings.manual, "Manual graphics choice survives restart")
	check(restored.data.settings.fps == 60 and restored.data.settings.distance == 2, "JSON numeric graphics settings survive restart")
	check(restored.data.posts[0].refunded and not restored.cancel_job("1"), "Refund history survives restart")
	state.reset()
	state.begin_action("learn")
	state.save_to(path)
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.state.last_saved = Time.get_unix_time_from_system() - 10000000
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var away = Simulation.new()
	away.load_from(path)
	check(away.data.repair == 1 and away.data.active.is_empty(), "Offline return finishes one existing activity only")
	check(away.data.day <= 2 and away.data.coins == 240, "Long absence does not create new earnings")
	var cached = Simulation.new()
	cached.load_from(path, false)
	check(cached.data.repair == 0 and not cached.data.active.is_empty(), "Cloud cache reload never completes or awards an activity locally")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{invalid save")
	file.close()
	var malformed = Simulation.new()
	check(not malformed.load_from(path).ok and malformed.data.coins == 240, "Malformed save fails safely")
	DirAccess.remove_absolute(path)
	print("Simulation: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
