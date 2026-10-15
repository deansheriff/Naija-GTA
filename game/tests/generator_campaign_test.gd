extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Phone = preload("res://core/phone_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func meeting_hub(pact: String = "protect") -> Dictionary:
	return Campaign.normalize({"version": 5, "mission": "A14", "status": "hub", "stage": 12, "lead": "ngozi", "paused": false, "completed": ["P00", "A11", "A12", "A13", "A14"], "mastery": {"tunde": 4, "ngozi": 4, "kc": 4}, "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "choices": {"A14-pact": pact, "A14-custody": "joint_record", "A13-disclose": "defer", "A14-disclosure": "tell"}, "drive": null, "phone": Phone.fresh()})
func _initialize() -> void:
	var old := meeting_hub()
	check(old.version == Campaign.VERSION and old.mastery == {"tunde": 4, "ngozi": 4, "kc": 4} and old.choices["A14-pact"] == "protect", "Version-5 meeting upgrades without replay or choice loss")
	old.version = 5
	old.phone.battery = 0
	old.phone.takes = 4
	check(Campaign.normalize(old).phone.battery == 0 and Campaign.normalize(old).phone.takes == 4, "Meeting upgrade retains a depleted phone")
	for pact in ["protect", "public_case"]:
		for hours in ["one_first", "two_first"]:
			var c := meeting_hub(pact)
			var evidence: Array = c.evidence.duplicate()
			var phone: Dictionary = c.phone.duplicate(true)
			var decisions := Journal.status(c)
			var now := 1000
			Campaign.command(c, "campaign_continue", -1, "", now)
			check(c.mission == "A21" and c.lead == "ngozi" and Journal.available(c), "Generator chapter begins after the meeting and retains journal access")
			for i in range(Campaign.story("A21").stages.size()):
				var task: Dictionary = Campaign.story("A21").stages[i]
				check(c.stage == i and c.lead == task.lead, "Checkpoint lead and stage " + str(i))
				check(not Campaign.command(c, "campaign_choose", i + 1, "next", now).ok, "Cannot skip generator checkpoints")
				if task.get("kind") == "drive":
					check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id, now).ok, "Junction choice requires a safe stop")
					if i == 3:
						Campaign.command(c, "campaign_drive", i, "coast", now)
						now += 1000
						Campaign.command(c, "campaign_drive", i, "accelerate", now)
						check(c.drive.distance > 0 and c.drive.speed > 0, "Manual controls move the generator route")
						var distance: float = c.drive.distance
						Campaign.command(c, "campaign_pause", -1, "", now)
						now += 600000
						Campaign.command(c, "campaign_resume", -1, "", now)
						check(c.drive.distance == distance, "Closed route time does not advance the bus")
					var distance_before: float = c.drive.distance
					Campaign.command(c, "campaign_review", -1, "", now)
					check(c.drive.distance == distance_before, "Reading/rechecking sources never drives the bus")
					for j in range(7):
						# Reload intentionally resets the local input clock. Prime it
						# at the same instant; only the next elapsed input may move.
						Campaign.command(c, "campaign_drive", i, "coast", now)
						now += 1000
						Campaign.command(c, "campaign_drive", i, "assist", now)
						c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					check(c.drive.ready and c.drive.lane == 1 and c.drive.speed == 0, "Guided approach stops each route at its marked bay")
				for option in task.choices:
					if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id, now).ok and c.stage == i, "Wrong site/route/agreement gives a recoverable correction")
				var choice: String = hours if task.id == "hours" else "joint_copy" if task.id == "permission" and hours == "two_first" else task.choices[0].id
				check(Campaign.command(c, "campaign_choose", i, choice, now).ok, "Supported generator objective progresses")
				c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
			check(c.status == "hub" and c.mastery == {"tunde": 6, "ngozi": 6, "kc": 4}, "Tunde and Ngozi receive two mastery once")
			check(c.evidence == evidence and c.phone == phone and Journal.status(c) == decisions, "Generator agreement preserves wedding records, phone and meeting decisions")
			check(c.choices["A21-hours"] == hours and c.choices["A21-placement"] == "yard_c" and c.choices["A14-pact"] == pact, "Both schedules and prior pacts remain saved")
			check(not Campaign.command(c, "campaign_choose", 12, "next", now).ok and not Campaign.command(c, "campaign_continue", -1, "", now).ok, "Completion cannot award twice or skip into unbuilt content")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	var c := meeting_hub("public_case")
	Campaign.command(c, "campaign_continue", -1, "", 1000)
	for stage in range(3): Campaign.command(c, "campaign_choose", stage, Campaign.story("A21").stages[stage].choices[0].id, 1000)
	Campaign.command(c, "campaign_drive", 3, "accelerate", 2000)
	scene.sim.data.campaign = c
	scene._open_campaign()
	for i in range(3): await process_frame
	var view = scene.campaign_view
	check(view.road_view != null and "GENERATOR WARS" in view.road_view.route_label, "Actual road view identifies Generator Wars")
	view.driving_enabled = true
	view.drive_mode = "accelerate"
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(view.show_journal and not view.driving_enabled and get_nodes_in_group("campaign_driving").is_empty(), "Opening journal removes driving controls and stops automatic driving input")
	var sent: Array = []
	view.requested.connect(func(kind, stage, choice): sent.append([kind, stage, choice]))
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right, true)
	view._process(2.0)
	check(sent.is_empty() and c.drive.distance == 15, "Journal ignores driving keys and automatic ticks")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(not view.show_journal and view.road_view != null and not view.driving_enabled, "Returning to road requires an explicit driving control")
	var now := 3000
	for stage in range(3, 9):
		var task: Dictionary = Campaign.story("A21").stages[stage]
		if task.get("kind") == "drive":
			for j in range(7):
				now += 1000
				Campaign.command(c, "campaign_drive", stage, "assist", now)
		Campaign.command(c, "campaign_choose", stage, task.choices[0].id, now)
	view.display(c)
	for i in range(3): await process_frame
	check(c.stage == 9 and view.stage_view.get_script() == load("res://world/generator_view.gd") and view.stage_view.scene_id == "sites", "Actual placement stage presents the original three-site board")
	check(get_nodes_in_group("campaign_choice").size() == 3 and get_nodes_in_group("campaign_record").size() == 1, "Site board has readable labelled alternatives and record")
	scene._exit_campaign()
	check(c.paused and scene.campaign_view == null and scene.sim.data.coins == 240, "Pause keeps placement checkpoint and sandbox balance")
	scene.queue_free()
	print("Generator Wars: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
