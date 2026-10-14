extends SceneTree
const Simulation = preload("res://core/simulation.gd")
const Repair = preload("res://core/repair_task.gd")
const Cloud = preload("res://core/cloud.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func _initialize() -> void:
	var sim = Simulation.new()
	check(not sim.repair_move(0).ok, "Dial moves require an active radio")
	sim.data.repair = 1
	check(sim.begin_action("gig").ok and sim.data.active.puzzle.turns.size() == 6, "Qualified starter creates six channels")
	var puzzle: Dictionary = sim.data.active.puzzle
	check(not Repair.matches(puzzle) and not puzzle.solved, "New radio starts unsolved")
	check(not sim.repair_move(-1).ok and not sim.repair_move(6).ok, "Dial bounds enforced")
	var before: int = puzzle.turns[0]
	sim.repair_move(0)
	check(puzzle.turns[0] == (before + 1) % 4, "Turn advances one channel clockwise")
	sim.tick(10)
	check(sim.data.coins == 240 and not sim.data.gig_done and not sim.data.active.is_empty(), "Timer alone never awards unsolved work")
	var saved = Simulation.new()
	saved.load_json(JSON.stringify({"version": 1, "state": sim.data}), true)
	check(saved.data.active.puzzle == sim.data.active.puzzle and saved.data.coins == 240, "Offline catch-up preserves unfinished board without payment")
	for tile in range(6):
		var steps: int = (sim.data.active.puzzle.target[tile] - sim.data.active.puzzle.turns[tile] + 4) % 4
		for step in range(steps): sim.repair_move(tile)
	check(sim.data.coins == 330 and sim.data.gig_done and sim.data.active.is_empty() and sim.data.repair == 2, "Final matching move settles an elapsed radio once")
	sim.tick(100)
	check(not sim.repair_move(0).ok and not sim.begin_action("gig").ok and sim.data.coins == 330, "Completed radio cannot be replayed for money")
	var early = Simulation.new()
	early.data.repair = 1
	early.begin_action("gig")
	for tile in range(6):
		var steps: int = (early.data.active.puzzle.target[tile] - early.data.active.puzzle.turns[tile] + 4) % 4
		for step in range(steps): early.repair_move(tile)
	check(early.data.active.puzzle.solved and early.data.coins == 240, "Early solution waits for the test deadline")
	early.tick(9.999)
	check(early.data.coins == 240, "No payment before minimum test time")
	early.tick(0.002)
	check(early.data.coins == 330, "Solved radio pays at deadline")
	var legacy = Simulation.new()
	legacy.load_json('{"version":1,"state":{"active":{"code":"gig","remaining":0},"repair":1}}', false)
	legacy.tick(0)
	check(legacy.data.coins == 330 and legacy.data.gig_done, "Existing pre-puzzle timed activities retain their completion rule")
	var invalid: Dictionary = puzzle.duplicate(true)
	invalid.turns[0] = 4
	check(Repair.normalize(invalid).is_empty(), "Out-of-range cached dial rejected")
	invalid = puzzle.duplicate(true)
	invalid.target = [0, 1]
	check(Repair.normalize(invalid).is_empty(), "Incomplete board rejected")
	var forged := {"turns": [0, 0, 0, 0, 0, 0], "target": [1, 1, 1, 1, 1, 1], "solved": true}
	check(not Repair.normalize(forged).solved, "Loader recomputes match rather than trusting solved flag")
	var cloud = Cloud.new()
	cloud.sim = saved
	cloud._apply({"serverTime": 100000, "character": {"revision": 4, "state": {"updatedAt": 100000, "coins": 240, "active": {"code": "gig", "endsAt": 90000, "puzzle": forged}}}})
	check(saved.data.active.remaining == 0 and not saved.data.active.puzzle.solved and saved.data.coins == 240, "Cloud snapshot keeps unfinished board, never pays locally")
	cloud.free()
	call_deferred("scene_checks")

func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	scene.sim.data.repair = 1
	scene.sim.begin_action("gig")
	scene._refresh()
	scene._open_repair_task()
	for i in range(6): await process_frame
	check(get_nodes_in_group("radio_dial").size() == 6 and scene.activity_task_button.visible, "Actual scene exposes all six dials and resume control")
	var rect: Rect2 = scene.modal_panel.get_rect()
	check(rect.end.y <= scene.get_viewport().get_visible_rect().size.y and rect.end.x <= scene.get_viewport().get_visible_rect().size.x, "Radio modal fits desktop viewport")
	scene._close_modal()
	scene._open_repair_task()
	check(get_nodes_in_group("radio_dial").size() == 6, "Closing and resuming replaces controls without duplicating dials")
	scene.queue_free()
	print("Interactive radio: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
