extends SceneTree
const Simulation = preload("res://core/simulation.gd")
const World = preload("res://world/world_plan.gd")
const Layout = preload("res://world/district_layout.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func _initialize() -> void:
	var sim = Simulation.new()
	sim.load_json('{"version":1,"state":{"coins":330,"gig_done":true}}', false)
	check(sim.data.world_seed == World.SEED and sim.data.coins == 330, "Old saves retain their original world and progress")
	sim.load_json('{"version":1,"state":{"world_seed":991337,"coins":270,"favor":"complete"}}', false)
	check(sim.data.world_seed == 991337 and sim.data.favor == "complete" and sim.data.coins == 270, "Cloud cache preserves assigned world seed alongside quest state")
	World.character_seed = sim.data.world_seed
	check(World.profile(0).seed == 0 and World.profile(1).seed == 991438, "Owner seed keeps Home street authored and changes new-character destinations")
	check(World.chunk_seed(0, 1, 2, 4) == World.chunk_seed(0, 1, 2, 4), "Assigned-seed transit chunks are repeatable")
	for seed in [1, 991337, 2147483646]:
		World.character_seed = seed
		var district = Layout.new(World.profile(2).seed)
		check(not district.route(district.places.bus.position, district.places.food.position).is_empty(), "Owner seed preserves doorway access: " + str(seed))
	World.character_seed = World.SEED
	sim.reset()
	var content := {"amakaLine": "A warm welcome, neighbor.", "yemiLine": "The tools are ready."}
	check(Dialogue.neighbor_line("amaka", sim.data, "At the counter", content).contains(content.amakaLine), "Validated owner introduction reaches Amaka dialogue")
	sim.meet_amaka()
	sim.data.favor = "carrying"
	check(not Dialogue.neighbor_line("amaka", sim.data, "At the counter", content).contains(content.amakaLine), "Owner introduction cannot replace Amaka's quest instructions")
	check(not Dialogue.neighbor_line("yemi", sim.data, "At the counter", content).contains(content.yemiLine), "Yemi's delivery conversation stays authored")
	print("Owner controls client: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
