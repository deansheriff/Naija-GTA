extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Viral = preload("res://core/viral_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
const Queue = preload("res://core/queue_task.gd")
const Receipt = preload("res://core/receipt_task.gd")
const Portfolio = preload("res://core/portfolio_task.gd")
const Phone = preload("res://core/phone_task.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func receipts_hub(permission: String = "approved") -> Dictionary:
	var phone := Phone.fresh()
	phone.battery = 0
	var p := Portfolio.fresh()
	for input in ["present", "callback", "assist", "present"]: Portfolio.advance(p, input)
	var receipt := Receipt.fresh()
	Receipt.advance(receipt, "assist")
	Receipt.advance(receipt, "check")
	var evidence := ["wedding_clip", "bag_record", "catering_invoice", "original_clip", "service_slip", "nneka_account", "diary", "note_discrepancy"]
	if permission == "approved": evidence.append("witness_consent")
	return Campaign.normalize({"version": 10, "mission": "A25", "status": "hub", "stage": 13, "lead": "ngozi", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14", "A21", "A22", "A23", "A24", "A25"], "evidence": evidence, "choices": {"A13-disclose": "defer", "A14-custody": "joint_record", "A14-pact": "protect", "A22-piece": "practice_piece", "A22-opportunity": "ask_time", "A24-consent": "private_only" if permission == "private" else "redacted_review", "A25-public_review": "approve_ne1" if permission == "approved" else "private_records"}, "phone": phone, "portfolio": p, "receipt": receipt, "witnessConsent": {"textHash": str(Receipt.catalogue().witnessText).sha256_text(), "scope": "redacted_text", "active": true} if permission == "approved" else null})
func fuel_hub(permission: String = "approved") -> Dictionary:
	var c := receipts_hub(permission)
	Campaign.command(c, "campaign_continue")
	for i in range(13):
		var task: Dictionary = Campaign.story("A26").stages[i]
		if task.get("kind") == "queue":
			Campaign.command(c, "campaign_queue", i, "assist")
			Campaign.command(c, "campaign_queue", i, "check")
		Campaign.command(c, "campaign_choose", i, task.choices[0].id)
	c.version = 11
	return c
func _initialize() -> void:
	var invalid := Viral.fresh()
	invalid.rumour.ready = true
	check(not Viral.normalize(invalid).rumour.ready, "Ready cannot bypass board answers and checks")
	invalid.rumour.attempts = -900
	check(Viral.normalize(invalid).rumour.attempts == 0, "Check counts are bounded on load")
	var recovery := Campaign.normalize(fuel_hub())
	Campaign.command(recovery, "campaign_continue")
	Campaign.command(recovery, "campaign_choose", 0, "compare")
	for input in ["assist", "check"]: Campaign.command(recovery, "campaign_publish", 1, input)
	recovery.evidence.erase("original_clip")
	check(not Campaign.command(recovery, "campaign_choose", 1, "limited").ok, "Checked answers cannot bypass a missing required source")
	Campaign.command(recovery, "campaign_review")
	check(Campaign.command(recovery, "campaign_choose", 1, "limited").ok and recovery.stage == 2, "Explicit recovery restores only the earned missing source")
	for permission in ["approved", "private", "declined"]:
		for route in ["witness", "documents"]:
			var legacy := fuel_hub(permission)
			var held: Dictionary = legacy.duplicate(true)
			var c := Campaign.normalize(legacy)
			check(legacy == held and c.version == Campaign.VERSION and c.mastery.kc == 9, "Version-11 fuel hub upgrades without rewriting the input")
			var retained: Dictionary = c.duplicate(true)
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A27", "Viral follows the checked transport chapter")
			check(not Campaign.command(c, "campaign_publish", 0, "assist").ok, "Board input cannot skip narrative stages")
			for i in range(10):
				var task: Dictionary = Campaign.story("A27").stages[i]
				check(c.stage == i and c.lead == "kc", "KC owns Viral checkpoint " + str(i))
				if task.get("kind") == "viral":
					check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id).ok, "Narrative cannot bypass the board check")
					check(not Campaign.command(c, "campaign_publish", i, "visual:limited" if task.viralPhase == "rumour" else "stamp:limited").ok, "Cross-phase selections are rejected")
					Campaign.command(c, "campaign_publish", i, "check")
					check(not c.viral[task.viralPhase].ready, "An incomplete check retains the stage")
					Campaign.command(c, "campaign_publish", i, "stamp:limited" if task.viralPhase == "rumour" else "disclosure:limited")
					var partial: Dictionary = c.viral.duplicate(true)
					Campaign.command(c, "campaign_pause")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					Campaign.command(c, "campaign_resume")
					check(c.viral == partial, "Partial selection and attempt count survive pause/reload")
					if route == "witness":
						for q in Viral.catalogue()[task.viralPhase].questions: Campaign.command(c, "campaign_publish", i, q.id + ":limited")
					else: Campaign.command(c, "campaign_publish", i, "assist")
					check(not c.viral[task.viralPhase].ready, "Manual and guided selections still require a check")
					Campaign.command(c, "campaign_publish", i, "check")
					check(c.viral[task.viralPhase].ready and c.viral[task.viralPhase].attempts == 2, "Explicit check accepts the limited source/correction answers")
				var choice: String = task.choices[0].id
				if task.id == "permission":
					if permission != "approved": check(not Campaign.command(c, "campaign_choose", i, "retain").ok, "A private or declined witness cannot be retained as approved")
					choice = "retain" if permission == "approved" and route == "witness" else "withdraw" if permission == "approved" else "documents"
				if task.id == "route":
					if not Receipt.has_witness_consent(c): check(not Campaign.command(c, "campaign_choose", i, "witness").ok, "Current permission gates the witness route")
					choice = "witness" if Receipt.has_witness_consent(c) and route == "witness" else "documents"
				check(Campaign.command(c, "campaign_choose", i, choice).ok, "Valid source route progresses checkpoint " + str(i))
			check(c.status == "hub" and c.mastery == {"tunde": 10, "ngozi": 12, "kc": 12}, "Viral adds three KC mastery once")
			for field in ["phone", "portfolio", "receipt", "queueTask"]: check(c[field] == retained[field], "Publication preserves " + field)
			for key in retained.choices: check(c.choices[key] == retained.choices[key], "Earlier choice retained: " + key)
			check(not Campaign.command(c, "campaign_choose", 9, "next").ok and c.completed.count("A27") == 1, "Completed chapter cannot award again")
			if permission == "approved" and route == "witness": check(Viral.publication(c).lines == [Receipt.catalogue().witnessText], "Witness package is exactly approved NE-1 without extra words")
			check(Campaign.command(c, "campaign_withdraw").ok, "Permission can be withdrawn after the presentation")
			var before: Array = c.evidence.duplicate()
			Campaign.command(c, "campaign_review")
			check(not Receipt.has_witness_consent(c) and not "witness_consent" in c.evidence and Viral.publication(c).route == "documents", "Withdrawal removes current receipt authority and falls back to documents")
			c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
			check(c.evidence == before and c.choices.get("A27-withdrawn") == "yes", "Restore/reload cannot revive withdrawn permission")
			check("KC explained" in Journal.status(c).disclosure, "Correction repairs the earlier delayed disclosure without rewriting it")
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
	var c := Campaign.normalize(fuel_hub())
	Campaign.command(c, "campaign_continue")
	Campaign.command(c, "campaign_choose", 0, "compare")
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	var original: Control = view.stage_view
	check(get_nodes_in_group("campaign_viral").size() == 6 and get_nodes_in_group("campaign_choice")[0].disabled, "Actual source board has two questions, guidance/check and gated continuation")
	view._viral_input("stamp:limited")
	for i in range(3): await process_frame
	check(view.stage_view == original and c.viral.rumour.answers.stamp == "limited", "Selections update the existing source desk in place")
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._viral_input("assist")
	check(not c.viral.rumour.answers.has("original") and not "Current corrected presentation" in all_text(view), "Journal blocks task input and hides future dossier")
	view.journal_button.pressed.emit()
	view._viral_input("assist")
	view._viral_input("check")
	for i in range(3): await process_frame
	check(c.viral.rumour.ready and get_nodes_in_group("campaign_viral").is_empty(), "Checked sources replace choices with continuation")
	for i in range(1, 4):
		if i == 3:
			scene._campaign_command("campaign_publish", i, "assist")
			scene._campaign_command("campaign_publish", i, "check")
		scene._campaign_command("campaign_choose", i, Campaign.story("A27").stages[i].choices[0].id)
	scene._campaign_command("campaign_choose", 4, "retain")
	scene._campaign_command("campaign_choose", 5, "witness")
	for i in range(3): await process_frame
	check(Receipt.catalogue().witnessText in all_text(view) and "Current corrected presentation · witness" in all_text(view), "Actual preview includes the exact approved written account")
	view.journal_button.pressed.emit()
	scene._campaign_command("campaign_withdraw", -1, "")
	for i in range(3): await process_frame
	check(not Receipt.has_witness_consent(c) and "NE-1 withdrawn" in all_text(view), "Journal withdrawal saves current permission status")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(not Receipt.catalogue().witnessText in all_text(view) and "Current corrected presentation · documents" in all_text(view), "Preview replaces withdrawn quotation with anonymised documents")
	for i in range(6, 10): scene._campaign_command("campaign_choose", i, Campaign.story("A27").stages[i].choices[0].id)
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check("Current corrected presentation · documents" in all_text(view) and not Receipt.catalogue().witnessText in all_text(view), "Completed journal shows current permitted package")
	check(c.mastery.kc == 12 and scene.sim.data.coins == 240 and c.evidence.size() == 8, "Actual completion and withdrawal preserve currency and private evidence")
	scene.queue_free()
	print("Viral: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
