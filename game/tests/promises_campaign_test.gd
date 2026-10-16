extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Promise = preload("res://core/promise_task.gd")
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
func viral_hub(permission: String = "approved") -> Dictionary:
	var c := Campaign.normalize(fuel_hub("approved" if permission == "withdrawn" else permission))
	Campaign.command(c, "campaign_continue")
	for i in range(10):
		var task: Dictionary = Campaign.story("A27").stages[i]
		if task.get("kind") == "viral":
			Campaign.command(c, "campaign_publish", i, "assist")
			Campaign.command(c, "campaign_publish", i, "check")
		var choice: String = task.choices[0].id
		if task.id == "permission": choice = "retain" if permission == "approved" else "withdraw" if permission == "withdrawn" else "documents"
		if task.id == "route": choice = "witness" if permission == "approved" else "documents"
		Campaign.command(c, "campaign_choose", i, choice)
	c.version = 12
	return c
func _initialize() -> void:
	for mask in range(8):
		var p := Promise.fresh()
		for i in range(3): Promise.advance(p, ["lights", "bus", "pay"][i] + (":claim" if mask & (1 << i) else ":record"))
		Promise.advance(p, "check")
		check(p.ready == (mask == 0), "Only record-limited interpretations pass the check")
		if not p.ready:
			Promise.advance(p, "assist")
			check(not p.ready, "Guidance still requires confirmation")
			Promise.advance(p, "check")
		check(p.ready, "All incorrect combinations recover without loss")
	var forged := Promise.fresh()
	forged.ready = true
	forged.attempts = 99
	check(not Promise.normalize(forged).ready, "A ready flag cannot bypass missing promise selections")
	for permission in ["approved", "private", "declined", "withdrawn"]:
		for question in ["lights", "bus", "pay"]:
			var legacy := viral_hub(permission)
			var held: Dictionary = legacy.duplicate(true)
			var c := Campaign.normalize(legacy)
			check(legacy == held and c.version == Campaign.VERSION and c.mastery.kc == 12, "Version-12 completed presentation upgrades without replay")
			var retained: Dictionary = c.duplicate(true)
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A31", "Fictional forum follows Viral")
			check(not Campaign.command(c, "campaign_promises", 0, "assist").ok, "Promise controls cannot skip source conversations")
			for i in range(11):
				var task: Dictionary = Campaign.story("A31").stages[i]
				check(c.stage == i and c.lead == task.lead, "Correct lead at forum checkpoint " + str(i))
				if task.get("kind") == "promise":
					check(not Campaign.command(c, "campaign_choose", i, "checked").ok, "Forum cannot bypass the comparison check")
					check(not Campaign.command(c, "campaign_promises", i, "time:request").ok, "Earlier receipt controls cannot answer forum promises")
					Campaign.command(c, "campaign_promises", i, "check")
					Campaign.command(c, "campaign_promises", i, "lights:record")
					var partial: Dictionary = c.promiseTask.duplicate(true)
					Campaign.command(c, "campaign_pause")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					Campaign.command(c, "campaign_resume")
					check(c.promiseTask == partial and not c.promiseTask.ready, "Partial promise comparison and failed check persist")
					for input in ["bus:record", "pay:record"] if question == "lights" else ["assist"]: Campaign.command(c, "campaign_promises", i, input)
					check(not c.promiseTask.ready, "Manual and guided selection require a check")
					Campaign.command(c, "campaign_promises", i, "check")
					check(c.promiseTask.ready and c.promiseTask.attempts == 2, "Explicit check retains source limits")
				check(Campaign.command(c, "campaign_choose", i, question if task.id == "question" else task.choices[0].id).ok, "Question path progresses forum checkpoint " + str(i))
			check(c.status == "hub" and c.mastery == {"tunde": 11, "ngozi": 13, "kc": 13}, "All questions earn one mastery per lead once")
			for field in ["phone", "portfolio", "receipt", "queueTask", "viral", "witnessConsent", "evidence"]: check(c[field] == retained[field], "Forum preserves earlier " + field)
			for key in retained.choices: check(c.choices[key] == retained.choices[key], "Earlier decision retained: " + key)
			check(c.choices["A31-question"] == question and c.choices["A31-allies"] == "recorded" and c.choices["A31-readiness"] == "packet_ready", "Opening question and actual support offers are saved")
			check(not Campaign.command(c, "campaign_choose", 10, "next").ok and c.completed.count("A31") == 1, "Forum completion cannot grant duplicate mastery")
			Campaign.command(c, "campaign_withdraw")
			check(Viral.publication(c).route == "documents", "Forum does not override later witness withdrawal")
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
	var c := Campaign.normalize(viral_hub("withdrawn"))
	Campaign.command(c, "campaign_continue")
	for i in range(4): Campaign.command(c, "campaign_choose", i, Campaign.story("A31").stages[i].choices[0].id)
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	var original: Control = view.stage_view
	check(get_nodes_in_group("campaign_receipt").size() == 8 and get_nodes_in_group("campaign_choice")[0].disabled, "Actual promise board has six answers, guidance/check and a gated continuation")
	view._receipt_input("lights:record")
	for i in range(3): await process_frame
	check(view.stage_view == original and c.promiseTask.answers.lights == "record" and c.receipt.ready, "Promise selection updates in place without overwriting A25 comparison")
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._receipt_input("assist")
	check(not c.promiseTask.answers.has("bus") and not "Community forum question packet" in all_text(view), "Journal blocks promise input and hides unearned forum packet")
	view.journal_button.pressed.emit()
	view._receipt_input("assist")
	view._receipt_input("check")
	for i in range(3): await process_frame
	check(c.promiseTask.ready and get_nodes_in_group("campaign_receipt").is_empty(), "Checked comparison replaces the active board")
	for i in range(4, 11): scene._campaign_command("campaign_choose", i, "pay" if i == 5 else Campaign.story("A31").stages[i].choices[0].id)
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check("Community forum question packet" in all_text(view) and "Where is the dated settlement" in all_text(view) and "No settlement record is supplied" in all_text(view), "Completed journal records the chosen question and its actual reply")
	check("Current corrected presentation · documents" in all_text(view) and not Receipt.catalogue().witnessText in all_text(view), "Forum keeps the withdrawn document package current")
	check(c.mastery == {"tunde": 11, "ngozi": 13, "kc": 13} and scene.sim.data.coins == 240 and c.evidence.size() == 8, "Actual forum completion leaves street currency and earned source records intact")
	scene.queue_free()
	print("Promises, Promises: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
