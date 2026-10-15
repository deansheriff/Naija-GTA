extends SceneTree
const Campaign = preload("res://core/campaign.gd")
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
func chase_hub(custody: String = "joint_record") -> Dictionary:
	var phone := Phone.fresh()
	phone.battery = 0
	phone.takes = 4
	var p := Portfolio.fresh()
	for input in ["present", "callback", "assist", "present"]: Portfolio.advance(p, input)
	return Campaign.normalize({"version": 8, "mission": "A23", "status": "hub", "stage": 12, "lead": "tunde", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14", "A21", "A22", "A23"], "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip", "service_slip"], "choices": {"A13-disclose": "defer", "A14-pact": "protect", "A14-custody": custody, "A22-piece": "practice_piece", "A22-opportunity": "ask_time", "A23-market_turn": "cousin_detour", "A23-gap_turn": "loop_rejoin", "A23-copy": "redacted_copy"}, "phone": phone, "portfolio": p})
func _initialize() -> void:
	var old := chase_hub()
	check(old.version == Campaign.VERSION and old.mastery == {"tunde": 9, "ngozi": 6, "kc": 6} and old.portfolio.route == "callback" and old.phone.battery == 0, "Version-8 chase upgrades with source, portfolio and phone intact")
	old.version = 8
	old.status = "playing"
	old.stage = 4
	old.drive = {"distance": 170.0, "speed": 0.0, "lane": 1, "lastAt": 1000, "ready": false, "misses": 2, "hint": "", "gateCleared": true}
	check(Campaign.normalize(old).drive.gateCleared and Campaign.normalize(old).drive.distance == 170, "Cleared queue checkpoint survives the next story upgrade")
	for consent in ["private_only", "redacted_review"]:
		for custody in ["ngozi_record", "joint_record"]:
			var c := chase_hub(custody)
			var phone: Dictionary = c.phone.duplicate(true)
			var portfolio: Dictionary = c.portfolio.duplicate(true)
			var decisions := Journal.status(c)
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A24", "Birthday visit follows the chase")
			check(not Campaign.command(c, "campaign_choose", 16, "next").ok, "Cannot skip to testimony or rewards")
			Journal.restore_earned(c)
			check(c.evidence.size() == 5 and not "nneka_account" in c.evidence, "Review cannot grant future testimony")
			for i in range(17):
				var task: Dictionary = Campaign.story("A24").stages[i]
				check(c.stage == i and c.lead == task.lead, "Staged Ngozi/KC perspective " + str(i))
				for wrong in task.choices:
					if not wrong.correct: check(not Campaign.command(c, "campaign_choose", i, wrong.id).ok and c.stage == i, "Wrong invitation, source or access claim retains checkpoint")
				if task.id == "reference":
					c.evidence.erase("service_slip")
					check(not Campaign.command(c, "campaign_choose", i, "compare").ok, "Source comparison requires earned service slip")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					check(not "service_slip" in c.evidence, "Missing record remains visible after reload")
					Journal.restore_earned(c)
					check("service_slip" in c.evidence and not "nneka_account" in c.evidence, "Restoration grants only already earned sources")
				var choice: String = consent if task.id == "consent" else task.choices[0].id
				check(Campaign.command(c, "campaign_choose", i, choice).ok, "Valid permission and source choice progresses")
				if task.id == "consent":
					Campaign.command(c, "campaign_pause")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					Campaign.command(c, "campaign_resume")
					check(c.choices["A24-consent"] == consent and c.stage == 14, "Permission boundary survives pause/reload without another choice")
			check(c.status == "hub" and c.mastery == {"tunde": 9, "ngozi": 8, "kc": 8}, "Both permission/custody branches grant equal mastery")
			check(c.evidence.size() == 6 and c.evidence.count("nneka_account") == 1 and not "diary" in c.evidence and not "witness_consent" in c.evidence, "Attributed account is saved without a premature diary or public witness approval")
			check(c.phone == phone and c.portfolio == portfolio and Journal.status(c) == decisions, "Prior phone, portfolio and family decisions persist")
			check(not Campaign.command(c, "campaign_choose", 16, "next").ok and c.completed.count("A24") == 1, "Completion cannot be rewarded twice")
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
	var c := chase_hub()
	Campaign.command(c, "campaign_continue")
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	check(view.stage_view.get_script() == load("res://world/birthday_view.gd") and view.stage_view.lead == "ngozi", "Birthday invitation uses original Ngozi/KC scene")
	check("SAGE + TRIANGLE" in all_text(view), "Invitation is readable by words and shape without colour perception")
	for i in range(17):
		var task: Dictionary = Campaign.story("A24").stages[i]
		scene._campaign_command("campaign_choose", i, "private_only" if task.id == "consent" else task.choices[0].id)
		if task.id == "folder": check(view.stage_view.lead == "kc" and view.stage_view.scene_id == "quiet", "Private interview stages the scripted switch to KC")
		if task.id == "consent": check("Private notes only" in all_text(view), "Private-only scope appears in the actual acknowledgement")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_record").size() == 11 and "Blue folder reference" in all_text(view), "Completed journal adds account, folder lead and permission boundary")
	check("Public work uses anonymised service records" in all_text(view) and "No public permission" not in all_text(view), "Journal renders the saved permission scope")
	check(c.mastery.ngozi == 8 and c.mastery.kc == 8 and scene.sim.data.coins == 240, "Actual scene completion preserves sandbox money")
	scene.queue_free()
	print("Aso-Ebi Infiltration: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
