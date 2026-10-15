extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Receipt = preload("res://core/receipt_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func infiltration_hub(boundary: String = "redacted_review", custody: String = "joint_record") -> Dictionary:
	var phone := preload("res://core/phone_task.gd").fresh()
	phone.battery = 0
	var p := preload("res://core/portfolio_task.gd").fresh()
	for input in ["present", "callback", "assist", "present"]: preload("res://core/portfolio_task.gd").advance(p, input)
	return Campaign.normalize({"version": 9, "mission": "A24", "status": "hub", "stage": 17, "lead": "ngozi", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14", "A21", "A22", "A23", "A24"], "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip", "service_slip", "nneka_account"], "choices": {"A13-disclose": "defer", "A14-custody": custody, "A14-pact": "protect", "A22-piece": "practice_piece", "A22-opportunity": "ask_time", "A24-consent": boundary}, "phone": phone, "portfolio": p})
func _initialize() -> void:
	for mask in range(8):
		var task := Receipt.fresh()
		var data := Receipt.catalogue()
		for i in range(3): Receipt.advance(task, data.questions[i].id + ":" + data.questions[i].options[(mask >> i) & 1].id)
		Receipt.advance(task, "check")
		check(task.ready == (mask == 0) and task.attempts == 1, "Only consistent claim set passes: " + str(mask))
		if mask:
			Receipt.advance(task, "assist")
			check(not task.ready, "Guided matching still requires a check")
			Receipt.advance(task, "check")
		var held: Dictionary = task.duplicate(true)
		Receipt.advance(task, "check")
		Receipt.advance(task, "account:everything")
		check(task == held and Receipt.normalize(task).ready, "Checked comparison remains stable")
	var forged := Receipt.fresh()
	forged.ready = true
	check(not Receipt.normalize(forged).ready, "Ready flag alone is not a comparison")
	for path in [["private_only", "private_records"], ["redacted_review", "private_records"], ["redacted_review", "approve_ne1"]]:
		for custody in ["ngozi_record", "joint_record"]:
			var c := infiltration_hub(path[0], custody)
			var phone: Dictionary = c.phone.duplicate(true)
			var portfolio: Dictionary = c.portfolio.duplicate(true)
			var decisions := Journal.status(c)
			check(c.version == Campaign.VERSION and c.mastery == {"tunde": 9, "ngozi": 8, "kc": 8}, "Version-9 hub preserves prior chapters")
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A25", "Receipts follows birthday visit")
			check(not Campaign.command(c, "campaign_compare", 0, "assist").ok, "Cannot use comparison board at an unrelated checkpoint")
			for i in range(13):
				var task: Dictionary = Campaign.story("A25").stages[i]
				check(c.stage == i and c.lead == "ngozi", "Source checkpoint " + str(i))
				if task.id == "custody":
					c.evidence.erase("service_slip")
					check(not Campaign.command(c, "campaign_choose", i, "witnessed_inventory").ok, "Witnessed inventory requires previous source records")
					Journal.restore_earned(c)
					check("service_slip" in c.evidence and not "diary" in c.evidence, "Recovery cannot grant an unearned diary")
				if task.get("kind") == "receipt":
					check(not Campaign.command(c, "campaign_choose", i, "checked").ok, "Cannot skip source comparison")
					Campaign.command(c, "campaign_compare", i, "account:everything")
					Campaign.command(c, "campaign_compare", i, "check")
					check(not c.receipt.ready and c.receipt.attempts == 1, "Overstated claim remains recoverable")
					Campaign.command(c, "campaign_pause")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					Campaign.command(c, "campaign_resume")
					check(c.receipt.answers.account == "everything" and c.receipt.attempts == 1, "Failed selections survive reload/pause")
					Campaign.command(c, "campaign_compare", i, "assist")
					check(not c.receipt.ready, "Guidance is not confirmation")
					Campaign.command(c, "campaign_compare", i, "check")
					check(c.receipt.ready and c.receipt.attempts == 2, "Corrected comparison passes")
				if task.id == "public_review" and path[0] == "private_only": check(not Campaign.command(c, "campaign_choose", i, "approve_ne1").ok, "Private-only boundary cannot grant a public-text review")
				for option in task.choices:
					if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id).ok, "Wrong source/custody claim retains checkpoint")
				check(Campaign.command(c, "campaign_choose", i, path[1] if task.id == "public_review" else task.choices[0].id).ok, "Supported source path progresses")
				c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
			check(c.status == "hub" and c.mastery == {"tunde": 9, "ngozi": 11, "kc": 8}, "All permission/custody routes award equal mastery")
			check(c.evidence.size() == (9 if path[1] == "approve_ne1" else 8) and "diary" in c.evidence and "note_discrepancy" in c.evidence, "Diary and mismatch are earned regardless of public approval")
			check(Receipt.has_witness_consent(c) == (path[1] == "approve_ne1"), "Only scoped exact-text approval is current")
			check(c.phone == phone and c.portfolio == portfolio and Journal.status(c) == decisions, "Earlier phone, opportunity and family state persist")
			check(not Campaign.command(c, "campaign_choose", 12, "next").ok, "Completion cannot award twice")
			if path[1] == "approve_ne1":
				c.witnessConsent.textHash = "f".repeat(64)
				c = Campaign.normalize(c)
				check(c.witnessConsent == null and not "witness_consent" in c.evidence and "diary" in c.evidence, "Changed text invalidates permission without losing the diary")
	var final := infiltration_hub()
	final.mission = "A25"
	final.status = "playing"
	final.stage = 12
	final.choices["A25-public_review"] = "private_records"
	final.evidence.erase("wedding_clip")
	Campaign.command(final, "campaign_choose", 12, "next")
	check(not "wedding_clip" in final.evidence and "diary" in final.evidence, "Completion grants this chapter's records without silently repairing unrelated sources")
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
	var c := infiltration_hub()
	Campaign.command(c, "campaign_continue")
	for i in range(7): Campaign.command(c, "campaign_choose", i, Campaign.story("A25").stages[i].choices[0].id)
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	check(get_nodes_in_group("campaign_receipt").size() == 8 and get_nodes_in_group("campaign_choice")[0].disabled, "Actual source board has six selections, check and guidance")
	var original: Control = view.stage_view
	view._receipt_input("account:everything")
	view._receipt_input("check")
	for i in range(3): await process_frame
	check(view.stage_view == original and c.receipt.attempts == 1 and "overreach" in view.receipt_feedback.text, "Correction and selections update the current board in place")
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._receipt_input("check")
	check(c.receipt.attempts == 1 and get_nodes_in_group("campaign_record").size() == 11, "Journal cannot operate the board or show future sources")
	view.journal_button.pressed.emit()
	view._receipt_input("assist")
	view._receipt_input("check")
	for i in range(3): await process_frame
	check(c.receipt.ready and get_nodes_in_group("campaign_receipt").is_empty() and not get_nodes_in_group("campaign_choice")[0].disabled, "Checked board exposes continuation")
	for i in range(7, 13): scene._campaign_command("campaign_choose", i, "approve_ne1" if i == 9 else Campaign.story("A25").stages[i].choices[0].id)
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_record").size() == 15 and "same approved wording" in all_text(view), "Completed journal shows diary, discrepancy and exact current approval")
	check(scene.sim.data.coins == 240 and c.mastery.ngozi == 11 and Receipt.has_witness_consent(c), "Actual scene reward has no sandbox payout")
	view.journal_button.pressed.emit()
	var private_case := infiltration_hub("private_only")
	Campaign.command(private_case, "campaign_continue")
	for i in range(9):
		if i == 7:
			Campaign.command(private_case, "campaign_compare", i, "assist")
			Campaign.command(private_case, "campaign_compare", i, "check")
		Campaign.command(private_case, "campaign_choose", i, Campaign.story("A25").stages[i].choices[0].id)
	view.display(private_case)
	view.display(private_case, true)
	view.display(private_case, false)
	check(get_nodes_in_group("campaign_choice")[1].disabled and not get_nodes_in_group("campaign_choice")[0].disabled, "Cloud wait/refresh cannot re-enable forbidden witness approval")
	scene.queue_free()
	print("Small Small Receipts: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
