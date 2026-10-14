extends SceneTree
const Simulation = preload("res://core/simulation.gd")
const Quest = preload("res://core/neighborhood_errand.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
const Cloud = preload("res://core/cloud.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func _initialize() -> void:
	for spot in ["board", "bench"]:
		var sim = Simulation.new()
		check(not sim.errand_choice("accept").ok and not sim.errand_choice("finish").ok and not sim.begin_action("lantern").ok, "Errand requires greeting, starter history and ordered stages")
		sim.meet_amaka()
		sim.data.gig_done = true
		sim.data.repair = 2
		sim.neighbor_choice("park_space")
		check(sim.errand_choice("accept").ok and sim.goal().place == "park" and sim.goal().step == 8, "Accept tracks the collection objective")
		check(not sim.errand_choice("install_" + spot).ok, "Cannot install before repair")
		check(sim.errand_choice("collect").ok and sim.goal().place == "repair", "Collect changes carried item and destination")
		sim.data.energy = 14
		check(not sim.begin_action("lantern").ok, "Repair respects need threshold")
		sim.data.energy = 78
		check(sim.begin_action("lantern").ok and not sim.begin_action("lantern").ok, "One active lantern repair")
		sim.tick(9.999)
		check(sim.data.errand.stage == "repair" and sim.data.coins == 240, "No early completion or payment")
		sim.tick(0.002)
		check(sim.data.errand.stage == "ready" and sim.data.career.completed == 0 and sim.goal().place == "park", "Timed repair advances the quest without paid-job credit")
		check(not sim.begin_action("lantern").ok and not sim.errand_choice("finish").ok, "Cannot repair again or skip installation")
		check(sim.errand_choice("install_" + spot).ok and sim.data.errand.spot == spot and sim.goal().place == "food", "Installation branch persists and points to Amaka")
		check(not sim.errand_choice("install_board").ok, "Placement is a single consequential choice")
		check(sim.errand_choice("finish").ok and sim.data.coins == 280 and sim.data.neighbors.park == 3 and sim.data.social == 2, "Completion awards forty once and updates relationships")
		check(not sim.errand_choice("finish").ok and not sim.errand_choice("accept").ok and sim.data.coins == 280, "No reward farming or quest reset")
		check(sim.data.favor == "available" and sim.data.neighbors.park_choice == "space", "Lunch favour and requested park space stay independent")
		check(Dialogue.neighbor_line("amaka", sim.data, "At the counter").contains("lantern neighbour") and Dialogue.chatter("available", false, sim.data.errand)[4][1].contains("lantern"), "Authored dialogue and paired chatter remember completion")
		var loaded = Simulation.new()
		loaded.load_json(JSON.stringify({"version": 1, "state": sim.data}), false)
		check(loaded.data.errand == sim.data.errand and Quest.objective(loaded.data.errand).step == 5, "Save reload preserves branch and completed journal")
	var old = Simulation.new()
	old.load_json('{"version":1,"state":{"coins":425,"favor":"complete","career":{"completed":4},"inventory":{"owned":["plant"],"equipped":["plant"]}}}', false)
	check(old.data.errand.stage == "available" and old.data.coins == 425 and old.data.career.completed == 4 and old.data.inventory.owned == ["plant"], "Old saves gain empty quest without losing career or purchases")
	old.load_json('{"version":1,"state":{"errand":{"stage":"ready","spot":"bench"}}}', false)
	check(old.data.errand.spot == "", "Uninstalled save cannot render a lantern early")
	var cloud = Cloud.new()
	cloud.sim = old
	cloud._apply({"serverTime": 100000, "character": {"revision": 4, "state": {"updatedAt": 100000, "coins": 330, "errand": {"stage": "repair", "spot": ""}, "active": {"code": "lantern", "endsAt": 105000}}}})
	check(old.data.errand.stage == "repair" and old.data.active.remaining == 5 and old.data.coins == 330, "Cloud cache never completes repair or grants a reward locally")
	cloud.free()
	call_deferred("world_checks")

func world_checks() -> void:
	var world = load("res://world/neighborhood_2d.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.apply_settings({"quality": "Low", "distance": 0, "effects": false, "shadows": false})
	var sim = Simulation.new()
	world.set_context(sim.data)
	check(world.scenery.square_lantern == null, "No lantern before installation")
	for spot in ["board", "bench"]:
		sim.data.errand = {"stage": "installed", "spot": spot}
		sim.data.minutes = 800
		world.set_context(sim.data)
		var lamp = world.scenery.square_lantern
		var rect: Rect2 = world.layout.furniture[5 if spot == "board" else 4].rect
		check(lamp != null and rect.has_point(lamp.position - Vector2(0, 1)), "Installed lantern stays within existing solid furniture footprint")
		check(not world.scenery.lantern_glow.visible, "Daytime lantern has no evening glow")
		sim.data.minutes = 1140
		world.set_context(sim.data)
		check(world.scenery.square_lantern == lamp and world.scenery.lantern_glow.visible and world.scenery.lantern_pool.visible, "Low retains evening glow without rebuilding or ambient animation")
		check(not world.route_to(world.places.park.position).is_empty(), "Lantern does not block the park approach")
	world.free()
	print("Neighbourhood errand: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
