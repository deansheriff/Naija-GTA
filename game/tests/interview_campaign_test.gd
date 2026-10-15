extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Portfolio = preload("res://core/portfolio_task.gd")
const Phone = preload("res://core/phone_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func generator_hub() -> Dictionary:
	var phone := Phone.fresh()
	phone.battery = 0
	phone.takes = 4
	return Campaign.normalize({"version": 6, "mission": "A21", "status": "hub", "stage": 13, "lead": "tunde", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14", "A21"], "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "choices": {"A13-disclose": "defer", "A14-pact": "protect", "A14-custody": "joint_record", "A21-hours": "two_first"}, "phone": phone})
func _initialize() -> void:
	var old := generator_hub()
	check(old.version == Campaign.VERSION and old.portfolio == null and old.phone.battery == 0 and old.mastery == {"tunde": 6, "ngozi": 6, "kc": 4}, "Version-6 generator hub upgrades with prior mastery, phone and no invented portfolio")
	var road := old.duplicate(true)
	road.version = 6
	road.status = "playing"
	road.stage = 5
	road.drive = {"distance": 145.0, "speed": 30.0, "lane": 0, "lastAt": 1234, "ready": false, "misses": 1, "hint": ""}
	check(Campaign.normalize(road).drive.distance == 145 and Campaign.normalize(road).drive.lane == 0, "Version-6 moving road checkpoint survives the portfolio upgrade")
	for mask in range(8):
		var p := Portfolio.fresh()
		var data := Portfolio.catalogue()
		for i in range(3): Portfolio.advance(p, data.questions[i].id + ":" + data.questions[i].options[(mask >> i) & 1].id)
		Portfolio.advance(p, "present")
		check(p.ready == (mask == 0) and p.needsRecovery == (mask != 0) and p.attempts == 1, "Only consistent answer set passes: " + str(mask))
		if mask != 0:
			var answers: Dictionary = p.answers.duplicate(true)
			Portfolio.advance(p, "assist")
			check(p.answers == answers and p.needsRecovery, "Correction requires a selected recovery path")
			Portfolio.advance(p, "callback")
			Portfolio.advance(p, "assist")
			check(not p.ready and p.route == "callback", "Guided answers still need a review on the callback")
			Portfolio.advance(p, "present")
		var complete: Dictionary = p.duplicate(true)
		Portfolio.advance(p, "present")
		Portfolio.advance(p, "practice")
		check(p == complete and Portfolio.normalize(p).ready, "Ready presentation does not accumulate more attempts or change its route")
	var forged := Portfolio.fresh()
	forged.ready = true
	check(not Portfolio.normalize(forged).ready, "A ready flag without consistent answers is not accepted by the local loader")
	for route in ["first", "practice", "callback"]:
		for piece in ["original_excerpt", "practice_piece"]:
			var c := generator_hub()
			var evidence: Array = c.evidence.duplicate()
			var phone: Dictionary = c.phone.duplicate(true)
			var decisions := Journal.status(c)
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A22", "Interview follows the completed generator chapter")
			check(not Campaign.command(c, "campaign_portfolio", 0, "assist").ok, "Portfolio controls cannot bypass the preparation")
			for i in range(Campaign.story("A22").stages.size()):
				var task: Dictionary = Campaign.story("A22").stages[i]
				check(c.stage == i and c.lead == "kc", "Saved KC checkpoint " + str(i))
				if task.get("kind") == "portfolio":
					check(not Campaign.command(c, "campaign_choose", i, "ready").ok and not Campaign.command(c, "campaign_portfolio", i, "role:invented").ok, "Cannot skip the answer board or invent an input")
					if route != "first":
						Campaign.command(c, "campaign_portfolio", i, "role:everything")
						Campaign.command(c, "campaign_portfolio", i, "present")
						var held: Dictionary = c.portfolio.duplicate(true)
						Campaign.command(c, "campaign_pause")
						c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
						Campaign.command(c, "campaign_resume")
						check(c.portfolio == held and c.portfolio.needsRecovery, "Correction and selections survive pause/reload")
						Campaign.command(c, "campaign_portfolio", i, route)
					if piece == "practice_piece": Campaign.command(c, "campaign_portfolio", i, "assist")
					else:
						for input in ["role:team", "source:original", "context:limits"]: Campaign.command(c, "campaign_portfolio", i, input)
					check(not c.portfolio.ready, "Selections alone do not confirm the presentation")
					Campaign.command(c, "campaign_portfolio", i, "present")
					check(c.portfolio.ready and c.portfolio.route == route and c.portfolio.attempts == (1 if route == "first" else 2), "All presentation routes can finish at equivalent opportunity")
				for option in task.choices:
					if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id).ok and c.stage == i, "Wrong claim/clearance choice retains its checkpoint")
				var choice: String = piece if task.id == "piece" else "ask_time" if task.id == "opportunity" and piece == "practice_piece" else task.choices[0].id
				check(Campaign.command(c, "campaign_choose", i, choice).ok, "Valid interview choice progresses")
				c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
			check(c.status == "hub" and c.mastery == {"tunde": 6, "ngozi": 6, "kc": 6} and c.completed.count("A22") == 1, "Two KC mastery and completion are awarded once")
			check(c.evidence == evidence and c.phone == phone and Journal.status(c) == decisions, "Portfolio choices do not alter wedding sources, battery or family disclosure")
			check(c.choices["A22-piece"] == piece and c.portfolio.route == route and "A22-opportunity" in c.choices, "Both portfolio pieces and opportunity replies are kept")
			check(not Campaign.command(c, "campaign_choose", 11, "next").ok, "Duplicate interview completion remains blocked")
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
	var c := generator_hub()
	Campaign.command(c, "campaign_continue")
	for stage in range(4): Campaign.command(c, "campaign_choose", stage, Campaign.story("A22").stages[stage].choices[0].id)
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	var original_view = view.portfolio_view
	check(view.stage_view.get_script() == load("res://world/interview_view.gd") and view.stage_view.scene_id == "board", "Actual answer board uses the original KC desk scene")
	check(get_nodes_in_group("campaign_portfolio").size() == 10 and get_nodes_in_group("campaign_choice")[0].disabled, "Three answer pairs and four actions are available before continuing")
	view._portfolio_input("role:everything")
	for i in range(3): await process_frame
	check(view.portfolio_view == original_view and c.portfolio.answers.role == "everything" and get_nodes_in_group("campaign_portfolio")[1].text.begins_with("Selected"), "Selecting an answer updates existing controls and illustrated state in place")
	get_nodes_in_group("campaign_portfolio")[6].grab_focus()
	view.display(c, true)
	scene._campaign_command("campaign_portfolio", 4, "present")
	for i in range(3): await process_frame
	check(c.portfolio.needsRecovery and get_nodes_in_group("campaign_portfolio")[0].disabled and not get_nodes_in_group("campaign_portfolio")[-1].disabled, "Actual failed presentation enables recovery and blocks answer edits")
	check(view.portfolio_feedback.visible and "correction" in view.portfolio_feedback.text and view.portfolio_feedback.get_index() < get_nodes_in_group("campaign_portfolio")[6].get_index(), "Recovery feedback sits beside the review actions")
	check(root.gui_get_focus_owner() == get_nodes_in_group("campaign_portfolio")[-2], "A rejected review restores keyboard focus to available practice")
	scene._exit_campaign()
	scene._open_campaign()
	view = scene.campaign_view
	for i in range(3): await process_frame
	check(c.stage == 4 and c.portfolio.needsRecovery and c.portfolio.answers.role == "everything", "Actual pause/resume retains the board correction")
	view._portfolio_input("callback")
	view._portfolio_input("assist")
	view._portfolio_input("present")
	for i in range(3): await process_frame
	check(c.portfolio.ready and c.portfolio.route == "callback" and get_nodes_in_group("campaign_portfolio").is_empty() and not get_nodes_in_group("campaign_choice")[0].disabled, "Checked callback rebuilds to the enabled continuation")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	view._portfolio_input("present")
	check(c.portfolio.attempts == 2 and get_nodes_in_group("campaign_record").size() == 6, "Journal does not mutate the ready board or prematurely show the opportunity")
	view.journal_button.pressed.emit()
	scene._campaign_command("campaign_choose", 4, "ready")
	for i in range(3): await process_frame
	check("kept this callback open" in all_text(view), "Actual call renders the saved callback response")
	for stage in range(5, 12):
		var task: Dictionary = Campaign.story("A22").stages[stage]
		scene._campaign_command("campaign_choose", stage, "practice_piece" if task.id == "piece" else task.choices[0].id)
	for i in range(3): await process_frame
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(c.status == "hub" and c.mastery.kc == 6 and c.evidence.size() == 4 and scene.sim.data.coins == 240, "Actual completion preserves sandbox money and four wedding sources")
	check(get_nodes_in_group("campaign_record").size() == 7 and "Open Window follow-up" in all_text(view), "Completed journal adds a separate opportunity note")
	scene.queue_free()
	print("Japa Interview: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
