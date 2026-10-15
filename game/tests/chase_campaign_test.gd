extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Drive = preload("res://core/driving_task.gd")
const Phone = preload("res://core/phone_task.gd")
const Portfolio = preload("res://core/portfolio_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func interview_hub() -> Dictionary:
	var phone := Phone.fresh()
	phone.battery = 0
	phone.takes = 4
	var portfolio := Portfolio.fresh()
	for input in ["present", "callback", "assist", "present"]: Portfolio.advance(portfolio, input)
	return Campaign.normalize({"version": 7, "mission": "A22", "status": "hub", "stage": 12, "lead": "kc", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14", "A21", "A22"], "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "choices": {"A13-disclose": "defer", "A14-pact": "protect", "A14-custody": "joint_record", "A22-piece": "practice_piece", "A22-opportunity": "ask_time"}, "phone": phone, "portfolio": portfolio})
func _initialize() -> void:
	var old := interview_hub()
	check(old.version == Campaign.VERSION and old.portfolio.ready and old.portfolio.route == "callback" and old.phone.battery == 0, "Version-7 upgrade preserves checked callback, phone and completed interview")
	for at in [150, 170]:
		var gate := {"at": at, "kind": "crossing" if at == 150 else "queue"}
		var d := Drive.fresh(1000)
		Drive.advance(d, "assist", 1000000, 350, gate)
		check(d.distance == 50 and not d.ready, "Long absence advances at most one second")
		for value in [[at - 31, 0, 1], [at, 3, 1], [at, 0, 0], [at + 1, 0, 1]]:
			d.distance = value[0]
			d.speed = value[1]
			d.lane = value[2]
			Drive.advance(d, "yield", 1001000, 350, gate)
			check(not d.get("gateCleared", false), "Cannot yield outside the waiting bay, while moving or in the upper lane")
	for first in ["left_marked", "cousin_detour"]:
		for second in ["canal_right", "loop_rejoin"]:
			for copy in ["private_copy", "redacted_copy"]:
				var c := interview_hub()
				var phone: Dictionary = c.phone.duplicate(true)
				var portfolio: Dictionary = c.portfolio.duplicate(true)
				var decisions := Journal.status(c)
				var now := 1000
				check(Campaign.command(c, "campaign_continue", -1, "", now).ok and c.mission == "A23", "Chase follows the interview")
				check(not Campaign.command(c, "campaign_drive", 0, "yield", now).ok, "Cannot issue a road wait before the road stage")
				for i in range(Campaign.story("A23").stages.size()):
					var task: Dictionary = Campaign.story("A23").stages[i]
					check(c.stage == i and c.lead == "tunde", "Tunde checkpoint " + str(i))
					if task.get("kind") == "drive":
						check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id, now).ok, "Cannot skip road leg")
						for j in range(4):
							now += 1000
							Campaign.command(c, "campaign_drive", i, "accelerate", now)
						check(c.drive.misses == 1 and c.drive.distance == 0 and not c.drive.gateCleared, "Missed waiting bay gives a free loop")
						for j in range(4):
							now += 1000
							Campaign.command(c, "campaign_drive", i, "assist", now)
						check(c.drive.distance == task.driveGate.at and c.drive.speed == 0 and not c.drive.ready and not c.drive.gateCleared, "Guided route waits at each required bay")
						Campaign.command(c, "campaign_pause", -1, "", now)
						c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
						now += 600000
						Campaign.command(c, "campaign_resume", -1, "", now)
						check(c.drive.distance == task.driveGate.at and not c.drive.gateCleared, "Reload/pause retains uncleared gate without absence travel")
						check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id, now).ok, "Waiting bay is not the final stop")
						Campaign.command(c, "campaign_drive", i, "yield", now)
						check(c.drive.gateCleared and not c.drive.ready, "Explicit wait clears only the required gate")
						c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
						check(c.drive.gateCleared, "Cleared crossing survives reload")
						Campaign.command(c, "campaign_resume", -1, "", now)
						for j in range(4):
							now += 1000
							Campaign.command(c, "campaign_drive", i, "assist", now)
						check(c.drive.ready and c.drive.lane == 1 and c.drive.speed == 0, "Final safe bay follows the cleared crossing")
					for option in task.choices:
						if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id, now).ok, "Unsafe route or overstated source is recoverable")
					var choice: String = first if task.id == "market_turn" else second if task.id == "gap_turn" else copy if task.id == "copy" else task.choices[0].id
					check(Campaign.command(c, "campaign_choose", i, choice, now).ok, "Supported turn/source choice progresses")
				check(c.status == "hub" and c.mastery == {"tunde": 9, "ngozi": 6, "kc": 6} and c.completed.count("A23") == 1, "All eight routes award three Tunde mastery once")
				check(c.evidence.size() == 5 and c.evidence.count("service_slip") == 1, "One service clue is earned on every route")
				check(c.phone == phone and c.portfolio == portfolio and Journal.status(c) == decisions, "Phone, opportunity and family decisions remain intact")
				check(c.choices["A23-market_turn"] == first and c.choices["A23-gap_turn"] == second and c.choices["A23-copy"] == copy, "Both detours and both source copy choices persist")
				check(not Campaign.command(c, "campaign_choose", 11, "next", now).ok, "Completion cannot award twice")
				c.evidence.erase("service_slip")
				check(not "service_slip" in Campaign.normalize(c).evidence, "Explicit missing earned source stays visibly missing")
				Journal.restore_earned(c)
				check(c.evidence.count("service_slip") == 1 and c.mastery.tunde == 9, "Earned service copy is restorable without mastery")
	call_deferred("scene_checks")
func all_text(node: Node) -> String:
	var value := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): value += all_text(child)
	return value
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	var c := interview_hub()
	Campaign.command(c, "campaign_continue")
	Campaign.command(c, "campaign_choose", 0, "public_route")
	scene.sim.data.campaign = c
	scene.sim.data.settings.effects = false
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	check(view.road_view.chase and view.drive_gate.kind == "crossing" and not view.road_view.ambient_motion, "Elevated road stage follows the bus and respects the effects setting")
	check(get_nodes_in_group("campaign_driving").size() == 7 and get_nodes_in_group("campaign_driving")[-1].disabled, "Wait control starts disabled until stopped in the marked bay")
	var clock: float = view.road_view.ambience
	view.road_view._process(0.1)
	check(view.road_view.ambience == clock, "Optional pedestrian/chase ambience freezes with effects off")
	view.road_view.ambient_motion = true
	view.road_view._process(0.1)
	check(view.road_view.ambience > clock, "Normal effects advance the original pedestrian frame clock")
	c.drive.distance = 150
	c.drive.speed = 0
	view.display(c)
	view.driving_enabled = true
	view._process(0.1)
	check(not view.driving_enabled and not get_nodes_in_group("campaign_driving")[-1].disabled, "Pace stops at the waiting bay without auto-confirming the wait")
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._drive_input("yield")
	check(not c.drive.gateCleared and get_nodes_in_group("campaign_record").size() == 7, "Journal neither clears a crossing nor reveals the future source")
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._drive_input("yield")
	for i in range(2): await process_frame
	check(c.drive.gateCleared and not view.driving_enabled and get_nodes_in_group("campaign_driving")[-1].disabled, "Actual wait saves once and requires a fresh pace selection")
	for i in range(1, 12):
		var task: Dictionary = Campaign.story("A23").stages[i]
		if task.get("kind") == "drive":
			c.drive.distance = 350
			c.drive.speed = 0
			c.drive.ready = true
			c.drive.gateCleared = true
		scene._campaign_command("campaign_choose", i, "cousin_detour" if task.id == "market_turn" else "loop_rejoin" if task.id == "gap_turn" else "redacted_copy" if task.id == "copy" else task.choices[0].id)
		if task.id == "market_turn": check("pack lunch" in all_text(view), "Saved first detour selects its comic response")
		if task.id == "gap_turn": check("popular wall" in all_text(view), "Saved second detour selects its rejoin response")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_record").size() == 8 and "21:14" in all_text(view) and "Open Window" in all_text(view), "Completed journal adds the limited service source beside retained opportunity")
	check(c.mastery.tunde == 9 and scene.sim.data.coins == 240 and c.evidence.size() == 5, "Actual scene completion has once-only source/mastery and no sandbox money")
	scene.queue_free()
	print("Danfo Chase: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
