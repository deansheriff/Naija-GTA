extends SceneTree
const Simulation = preload("res://core/simulation.gd")
const Cloud = preload("res://core/cloud.gd")
const Scenery = preload("res://world/modular_scenery.gd")
const Layout = preload("res://world/district_layout.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func _initialize() -> void:
	var sim = Simulation.new()
	check(not sim.begin_action("fan").ok, "Career gated behind starter job")
	sim.data.gig_done = true
	sim.data.repair = 2
	sim.data.energy = 23
	sim.data.food = 20
	check(sim.begin_action("fan").ok and sim.data.energy == 5 and sim.data.food == 12, "Exact need threshold charges on acceptance")
	check(not sim.begin_action("fan").ok, "One active activity")
	check(not sim.tick(19.999) and sim.data.coins == 240, "No early payment")
	sim.tick(0.002)
	check(sim.data.coins == 285 and sim.data.career.completed == 1, "Completion awards once and progresses career")
	check(sim.data.career.cooldown > 44.9 and not sim.begin_action("fan").ok, "Shared cooldown starts at scheduled completion")
	sim.tick(46)
	check(sim.data.coins == 285 and sim.data.career.cooldown == 0, "Cooldown expires without repeating reward")
	check(not sim.begin_action("fan").ok, "Low needs block work")
	sim.begin_action("rest")
	sim.tick(8)
	sim.begin_action("eat")
	sim.tick(6)
	check(sim.begin_action("fan").ok, "Free rest and paid food restore eligibility")
	sim.tick(90)
	check(sim.data.career.completed == 2 and sim.data.career.cooldown == 0 and sim.data.active.is_empty(), "Absence settles one job and elapsed cooldown")
	check(not sim.begin_action("inverter").ok, "Higher work requires three career jobs")
	sim.data.energy = 100
	sim.data.food = 100
	sim.begin_action("fan")
	sim.tick(65)
	check(sim.begin_action("inverter").ok, "Third completed job and skill unlock inverter")
	sim.tick(30)
	check(sim.data.career.completed == 4 and sim.data.coins == 425, "Inverter pays 75, preserves earlier earnings and food cost")
	check(sim.home_intent("buy", "plant").ok and sim.data.coins == 365, "Purchase charges catalogue price")
	check(not sim.home_intent("buy", "plant").ok and sim.data.coins == 365, "Duplicate item cannot charge twice")
	check(not sim.home_intent("furnish", "radio", "place").ok, "Unowned item cannot be placed")
	check(sim.home_intent("furnish", "plant", "store").ok and sim.data.inventory.equipped.is_empty(), "Store retains ownership")
	check(sim.home_intent("furnish", "plant", "place").ok and sim.data.inventory.equipped == ["plant"], "Owned item can be placed for free")
	var restored = Simulation.new()
	restored.load_json(JSON.stringify({"version": 1, "state": sim.data}), false)
	check(restored.data.inventory == sim.data.inventory and restored.data.career == sim.data.career, "Local save round-trips progress and inventory")
	restored.reset()
	restored.load_json('{"version":1,"state":{"coins":330,"gig_done":true,"favor":"complete"}}', false)
	check(restored.data.career.completed == 0 and restored.data.inventory.owned.is_empty() and restored.data.coins == 330 and restored.data.favor == "complete", "Old saves gain empty fields without resetting history")
	restored.load_json('{"version":1,"state":{"inventory":{"owned":["plant","plant","money_tree"],"equipped":["radio","plant","plant"]}}}', false)
	check(restored.data.inventory == {"owned": ["plant"], "equipped": ["plant"]}, "Loader rejects unknown, duplicate and unowned equipped items")
	var cloud = Cloud.new()
	cloud.sim = restored
	cloud._apply({"serverTime": 100000, "character": {"revision": 2, "state": {"updatedAt": 100000, "coins": 330, "career": {"completed": 3, "readyAt": 130000}, "active": {"code": "inverter", "endsAt": 125000}, "inventory": {"owned": ["rug"], "equipped": ["rug"]}}}})
	check(restored.data.career.cooldown == 30 and restored.data.active.remaining == 25 and restored.data.active.total == 30, "Cloud uses server timestamps for job and cooldown display")
	check(restored.data.coins == 330 and restored.data.career.completed == 3, "Snapshot loading does not award client-side rewards")
	cloud.free()
	var recovery = Simulation.new()
	recovery.data.coins = 0
	recovery.data.food = 5
	check(recovery.begin_action("communitymeal").ok, "Broke hungry player has a free recovery path")
	recovery.tick(12)
	check(recovery.data.coins == 0 and recovery.data.food > 20 and not recovery.begin_action("communitymeal").ok, "Recovery plate grants food, no cash, and cannot be claimed when fed")
	var scenery = Scenery.new()
	scenery.district = Layout.new()
	var sorted_world := Node2D.new()
	scenery.furnish_home(sorted_world, ["rug", "plant", "radio"])
	check(scenery.home_decor.size() == 3, "All purchased items have distinct scene objects")
	var old_decor = scenery.home_decor[0]
	scenery.furnish_home(sorted_world, ["rug", "plant", "radio"])
	check(scenery.home_decor[0] == old_decor, "Per-frame context does not rebuild furnishings")
	check(scenery.district.route(Vector2(1220, 500), Vector2(1220, 400)).size() > 0, "Home doorway remains accessible")
	for item in scenery.home_decor:
		if item.name != "rug": check(Rect2(1070, 350, 100, 28).has_point(item.position - Vector2(0, 1)), "Desk accessory remains on existing furniture footprint")
	scenery.furnish_home(sorted_world, [])
	check(scenery.home_decor.size() == 0, "Storing items removes their visible scene objects")
	scenery.free()
	sorted_world.free()
	var remote = Scenery.new()
	remote.district = Layout.new(991337)
	var remote_world := Node2D.new()
	remote.furnish_home(remote_world, ["plant"])
	check(remote_world.get_child_count() == 0, "Personal items appear only on authored Home street")
	remote.free()
	remote_world.free()
	print("Career and inventory: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
