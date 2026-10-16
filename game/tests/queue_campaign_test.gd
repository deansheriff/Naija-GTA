extends SceneTree
const Campaign = preload("res://core/campaign.gd")
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
func _initialize() -> void:
	for order in [["bus", "home", "cart"], ["bus", "cart", "home"], ["home", "bus", "cart"], ["home", "cart", "bus"], ["cart", "bus", "home"], ["cart", "home", "bus"]]:
		var q := Queue.fresh()
		q.order = order.duplicate()
		Queue.advance(q, "check", "line")
		check(not q.lineReady, "Arrival order alone does not resolve the duplicate")
		Queue.advance(q, "verify", "line")
		for id in Queue.catalogue().order:
			while q.order.find(id) > Queue.catalogue().order.find(id): Queue.advance(q, "earlier:" + id, "line")
		check(q.order == Queue.catalogue().order and not q.lineReady, "Every permutation can reorder without dropping a party")
		Queue.advance(q, "check", "line")
		check(q.lineReady, "Checked manual order passes")
		var held: Dictionary = q.duplicate(true)
		Queue.advance(q, "later:bus", "line")
		check(q == held, "Checked queue cannot be rearranged or counted again")
	var forged := Queue.fresh()
	forged.lineReady = true
	forged.resetReady = true
	check(not Queue.normalize(forged).lineReady and not Queue.normalize(forged).resetReady, "Ready flags cannot bypass ticket/prop conditions")
	forged.order = ["bus", "bus", "home"]
	check(Queue.normalize(forged).is_empty(), "Malformed duplicate party lists are rejected")
	for permission in ["approved", "private", "declined"]:
		for approach in ["talk", "patient"]:
			var c := receipts_hub(permission)
			var retained: Dictionary = c.duplicate(true)
			check(c.version == Campaign.VERSION and c.mastery.ngozi == 11, "Version-10 source/permission hub upgrades without replay")
			check(Campaign.command(c, "campaign_continue").ok and c.mission == "A26", "Queue follows receipt investigation")
			check(not Campaign.command(c, "campaign_queue", 0, "assist").ok, "Queue control cannot skip narrative checkpoints")
			for i in range(13):
				var task: Dictionary = Campaign.story("A26").stages[i]
				check(c.stage == i and c.lead == task.lead, "Ensemble checkpoint " + str(i))
				if task.get("kind") == "queue":
					check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id).ok, "Current task requires its explicit check")
					check(not Campaign.command(c, "campaign_queue", i, "bucket" if task.queuePhase == "line" else "earlier:bus").ok, "Cross-phase controls are rejected")
					Campaign.command(c, "campaign_queue", i, "check")
					if task.queuePhase == "line":
						Campaign.command(c, "campaign_queue", i, "earlier:bus")
						var held: Dictionary = c.queueTask.duplicate(true)
						Campaign.command(c, "campaign_pause")
						c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
						Campaign.command(c, "campaign_resume")
						check(c.queueTask == held, "Partial queue and failed check survive pause/reload")
						for input in ["earlier:bus", "later:cart", "verify"] if approach == "talk" else ["assist"]: Campaign.command(c, "campaign_queue", i, input)
						check(not c.queueTask.lineReady and c.queueTask.order == ["bus", "home", "cart"], "Manual and guided ordering both still require a check")
					else:
						Campaign.command(c, "campaign_queue", i, "aisle")
						check(not c.queueTask.aisleClear, "Bucket must be upright before the chairs reset")
						for input in ["bucket", "aisle"] if approach == "talk" else ["assist"]: Campaign.command(c, "campaign_queue", i, input)
						check(not c.queueTask.resetReady, "Reset actions do not substitute for confirmation")
					Campaign.command(c, "campaign_queue", i, "check")
					check(c.queueTask.lineReady if task.queuePhase == "line" else c.queueTask.resetReady, "Explicit task check passes")
				for option in task.choices:
					if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id).ok, "Unsafe queue claim retains checkpoint")
				check(Campaign.command(c, "campaign_choose", i, approach if task.id == "approach" else task.choices[0].id).ok, "Supported queue action progresses")
			check(c.status == "hub" and c.mastery == {"tunde": 10, "ngozi": 12, "kc": 9}, "Both dialogue routes award one mastery each once")
			for field in ["phone", "portfolio", "receipt", "witnessConsent", "evidence"]: check(c[field] == retained[field], "Queue preserves earlier " + field)
			check(c.queueTask.lineReady and c.queueTask.resetReady and c.choices["A26-approach"] == approach, "Both checked task states and chosen approach persist")
			check(not Campaign.command(c, "campaign_choose", 12, "next").ok and c.completed.count("A26") == 1, "Completion cannot award twice")
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
	var c := receipts_hub()
	Campaign.command(c, "campaign_continue")
	for i in range(2): Campaign.command(c, "campaign_choose", i, Campaign.story("A26").stages[i].choices[0].id)
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	var original: Control = view.stage_view
	check(get_nodes_in_group("campaign_queue").size() == 9 and get_nodes_in_group("campaign_choice")[0].disabled, "Actual queue has six position buttons and three desk/check actions")
	view._queue_input("earlier:bus")
	for i in range(3): await process_frame
	check(view.stage_view == original and c.queueTask.order == ["cart", "bus", "home"] and "Cart party" in view.queue_order_label.text, "Reordering updates the existing tableau and readable line")
	view.stage_view.set_process(false)
	var walker: Node2D = view.stage_view.people.bus
	walker.position = view.stage_view.slot(2)
	var poses: Array = []
	for i in range(6):
		view.stage_view._process(0.1)
		if not walker.get_child(0).pose_index in poses: poses.append(walker.get_child(0).pose_index)
	check(poses.size() >= 2 and walker.get_child(0).heading == "left" and walker.get_child(0).flip_h, "Queue reorder uses changing leg poses with a stable movement direction")
	var travelled: float = walker.get_child(0).travelled
	view.stage_view.ambient_motion = false
	view._queue_input("earlier:bus")
	view.stage_view._process(0.1)
	check(walker.position == view.stage_view.slot(0) and walker.get_child(0).travelled == travelled, "Effects-off keeps essential ordered positions while pausing optional walking")
	view.stage_view.ambient_motion = true
	view.journal_button.pressed.emit()
	for i in range(2): await process_frame
	view._queue_input("check")
	check(c.queueTask.checks == 0 and get_nodes_in_group("campaign_record").size() == 15, "Journal cannot operate the queue or reveal the future allocation note")
	view.journal_button.pressed.emit()
	view._queue_input("assist")
	view._queue_input("check")
	for i in range(3): await process_frame
	check(c.queueTask.lineReady and get_nodes_in_group("campaign_queue").is_empty(), "Checked line replaces controls with continuation")
	view.stage_view.set_process(false)
	for i in range(130): view.stage_view._process(0.1)
	var exited := true
	for person in view.stage_view.people.values(): exited = exited and person.position.x < -60
	check(exited, "Served parties walk fully off-scene without recycling back into the line")
	for i in range(2, 6): scene._campaign_command("campaign_choose", i, "patient" if i == 3 else Campaign.story("A26").stages[i].choices[0].id)
	for i in range(3): await process_frame
	check(view.stage_view.phase == "reset" and not view.stage_view.people.bus.visible, "Served queue members do not reappear during the later prop reset")
	check(c.queueTask.hint.is_empty(), "Starting the reset clears unrelated earlier ticket feedback")
	view._queue_input("aisle")
	check(not c.queueTask.aisleClear and "upright first" in view.queue_feedback.text, "Actual reset explains the bucket-first correction")
	view._queue_input("bucket")
	view._queue_input("aisle")
	view._queue_input("check")
	for i in range(3): await process_frame
	check(c.queueTask.resetReady and get_nodes_in_group("campaign_queue").is_empty(), "Actual reset reaches checked continuation")
	for i in range(6, 13): scene._campaign_command("campaign_choose", i, Campaign.story("A26").stages[i].choices[0].id)
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_record").size() == 16 and "Community transport reservation" in all_text(view) and "not wedding evidence" in all_text(view), "Completed journal adds transport as a separate arrangement")
	check(c.mastery == {"tunde": 10, "ngozi": 12, "kc": 9} and scene.sim.data.coins == 240 and c.evidence.size() == 9, "Actual ensemble completion leaves currency and evidence intact")
	scene.queue_free()
	print("Fuel Queue Standoff: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
