extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Drive = preload("res://core/driving_task.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func tunde_hub() -> Dictionary:
	return Campaign.normalize({"version": 2, "mission": "A11", "status": "hub", "stage": 9, "lead": "tunde", "paused": false, "completed": ["P00", "A11"], "mastery": {"tunde": 3, "ngozi": 1, "kc": 1}, "evidence": ["wedding_clip", "bag_record"], "choices": {"A11-market_drive": "shortcut"}, "drive": null})
func _initialize() -> void:
	var old := tunde_hub()
	check(old.version == Campaign.VERSION and old.completed == ["P00", "A11"] and old.choices["A11-market_drive"] == "shortcut", "Version-2 completed Tunde preserves route and awards")
	var road := old.duplicate(true)
	road.version = 2
	road.status = "playing"
	road.stage = 3
	road.drive = Drive.fresh(1000)
	road.drive.distance = 150.0
	road.drive.speed = 40.0
	road.drive.lane = 0
	var upgraded := Campaign.normalize(road)
	check(upgraded.version == Campaign.VERSION and upgraded.drive.distance == 150 and upgraded.drive.speed == 40 and upgraded.drive.lane == 0, "Version-2 road upgrade preserves position, pace and lane")
	check(upgraded.drive.lastAt == 0 and road.version == 2, "Restored road resets elapsed clock without mutating old input")
	for approach in ["patient", "firm"]:
		var c := tunde_hub()
		check(Campaign.command(c, "campaign_continue", -1, "", 1000).ok and c.mission == "A12" and c.lead == "ngozi", "Tunde hub continues into Ngozi's chapter")
		var story := Campaign.story("A12")
		for i in range(story.stages.size()):
			var task: Dictionary = story.stages[i]
			check(c.stage == i and c.lead == "ngozi", "Ajo Day checkpoint " + str(i))
			check(not Campaign.command(c, "campaign_choose", i + 1, "next", 1000).ok, "Cannot skip a record checkpoint")
			for option in task.choices:
				if not option.correct:
					var result := Campaign.command(c, "campaign_choose", i, option.id, 1000)
					check(not result.ok and c.stage == i and not result.message.is_empty(), "Incorrect record gives a free hint")
			var choice: String = approach if task.id == "sola_terms" else task.choices[0].id
			check(Campaign.command(c, "campaign_choose", i, choice, 1000).ok, "Supported record/negotiation choice progresses")
			c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
		check(c.status == "hub" and c.mastery == {"tunde": 3, "ngozi": 3, "kc": 1} and c.evidence == ["wedding_clip", "bag_record", "catering_invoice"], "Ajo Day grants invoice and Ngozi mastery once")
		check(c.choices["A12-sola_terms"] == approach and c.choices["A12-sola_receipt"] == "agreed", "Patient/firm approach and agreed receipt survive each reload")
		check(not Campaign.command(c, "campaign_continue").ok and not Campaign.command(c, "campaign_choose", 10, "next").ok, "Unbuilt next chapter and duplicate invoice awards blocked")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	scene.sim.data.campaign = tunde_hub()
	scene._open_campaign()
	for i in range(3): await process_frame
	var continue_button: Button
	for node in scene.campaign_view.controls:
		if node.text.begins_with("Continue"): continue_button = node
	check(continue_button != null and "Ngozi" in continue_button.text, "Hub labels the next lead correctly")
	scene._campaign_command("campaign_continue", -1, "")
	scene._campaign_command("campaign_choose", 0, "next")
	for i in range(3): await process_frame
	check(scene.campaign_view.stage_view.get_script() == load("res://world/canteen_view.gd") and not scene.world.visible, "Ajo Day uses its own canteen staging")
	check(get_nodes_in_group("campaign_record").size() == 2, "Date comparison has two readable record cards")
	scene.cloud.base_url = "http://127.0.0.1:1/api"
	scene.cloud.token = "disposable-poll-fixture"
	scene.cloud.connected = true
	scene.cloud.poll_time = 5
	scene.cloud._process(0.1)
	check(not scene.cloud.busy and scene.cloud.pending.is_empty(), "Reading an active story does not start a control-blocking idle sync")
	scene.cloud.base_url = ""
	var record: Control = get_nodes_in_group("campaign_record")[0]
	check(record.get_rect().size.x <= scene.campaign_view.scroll.size.x, "Record cards fit the scroll width")
	scene._campaign_command("campaign_choose", 1, "accept")
	check("06 and 05" in scene.campaign_view.feedback.text and scene.sim.data.campaign.stage == 1, "Actual wrong date choice preserves checkpoint and explains mismatch")
	scene.campaign_view.display(scene.sim.data.campaign, true)
	check("Saving or refreshing" in scene.campaign_view.feedback.text, "Waiting state explains why the choices are disabled")
	scene.campaign_view.display(scene.sim.data.campaign, false)
	check("06 and 05" in scene.campaign_view.feedback.text, "Waiting refresh preserves the previous retry hint")
	var before_summary: int = scene.campaign_view.content.get_child_count()
	scene.campaign_view.show_summary = true
	scene.campaign_view.build()
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_record").size() == 2 and before_summary == scene.campaign_view.content.get_child_count(), "Summary retains the source records without duplicate cards")
	scene._exit_campaign()
	check(scene.campaign_view == null and scene.sim.data.campaign.paused and scene.world.visible, "Pause preserves Ngozi checkpoint and restores street")
	scene._open_campaign()
	check(scene.sim.data.campaign.stage == 1 and not scene.sim.data.campaign.paused, "Reopen resumes the same comparison")
	scene.queue_free()
	print("Ajo Day: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
