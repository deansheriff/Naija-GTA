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
func _initialize() -> void:
	var d := Drive.fresh(1000)
	Drive.advance(d, "accelerate", 2000, 350)
	check(d.speed == 30 and d.distance == 15, "Acceleration integrates bounded pace")
	Drive.advance(d, "accelerate", 102000, 350)
	check(d.speed == 60 and d.distance == 60, "Background/closed gap advances at most one second")
	Drive.advance(d, "brake", 103000, 350)
	check(d.speed == 0 and d.distance == 90, "Braking comes to a stop")
	d.assign({"distance": 340.0, "speed": 0.0, "lane": 0, "lastAt": 103000, "ready": false, "misses": 0, "hint": ""})
	Drive.advance(d, "coast", 104000, 350)
	check(not d.ready, "Upper lane is not the safe bay")
	Drive.advance(d, "lower", 105000, 350)
	check(d.ready, "Stopped lower-lane bus completes approach")
	var missed := Drive.fresh(1000)
	for i in range(1, 13): Drive.advance(missed, "accelerate", 1000 + i * 1000, 350)
	check(missed.misses > 0 and "free loop" in missed.hint, "Missed bay offers a free loop")
	var guided := Drive.fresh(1000)
	for i in range(1, 8): Drive.advance(guided, "assist", 1000 + i * 1000, 350)
	check(guided.ready and guided.distance == 350 and guided.speed == 0, "Guided approach reaches the same safe stop")
	var old := {"version": 1, "status": "hub", "stage": 14, "lead": "kc", "paused": true, "completed": ["P00"], "mastery": {"tunde": 1, "ngozi": 1, "kc": 1}, "evidence": ["wedding_clip"]}
	var c := Campaign.normalize(old)
	check(c.version == Campaign.VERSION and c.mission == "P00" and c.stage == 14 and c.evidence == ["wedding_clip"], "Existing completed wedding upgrades without replay")
	Campaign.command(c, "campaign_resume", -1, "", 1000)
	check(Campaign.command(c, "campaign_continue", -1, "", 1000).ok and c.mission == "A11" and c.lead == "tunde", "Continue enters Tunde's authored mission")
	var story := Campaign.story("A11")
	var now := 1000
	for i in range(story.stages.size()):
		var task: Dictionary = story.stages[i]
		check(c.stage == i, "Tunde checkpoint " + str(i))
		if task.get("kind") == "drive":
			check(not Campaign.command(c, "campaign_choose", i, task.choices[0].id, now).ok, "Cannot skip unfinished road leg")
			for step in range(7):
				now += 1000
				Campaign.command(c, "campaign_drive", i, "assist", now)
			check(c.drive.ready, "Road leg uses validated guided controls")
			var restored := Campaign.normalize(c)
			check(restored.drive.ready and restored.drive.distance == c.drive.distance, "Road progress survives normalization")
		for option in task.choices:
			if option.correct:
				Campaign.command(c, "campaign_choose", i, option.id, now)
				break
	check(c.status == "hub" and c.completed == ["P00", "A11"] and c.mastery.tunde == 3 and c.evidence == ["wedding_clip", "bag_record"], "Tunde grants mastery and evidence once")
	check(not Campaign.command(c, "campaign_choose", story.stages.size(), "next").ok, "Duplicate mission rewards blocked")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	var c: Dictionary = scene.sim.data.campaign
	Campaign.command(c, "campaign_start", -1, "", 1000)
	var wedding := Campaign.story()
	for i in range(wedding.stages.size()):
		for option in wedding.stages[i].choices:
			if option.correct:
				Campaign.command(c, "campaign_choose", i, option.id, 1000)
				break
	scene._open_campaign()
	for i in range(3): await process_frame
	check(scene.campaign_view != null, "Actual hub renders upgraded wedding and continue control")
	scene._campaign_command("campaign_continue", -1, "")
	scene._campaign_command("campaign_choose", 0, "next")
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_driving").size() == 6 and scene.campaign_view.road_view != null, "Driving scene exposes six touch/keyboard controls and elevated view")
	var sent := [0]
	scene.campaign_view.requested.connect(func(kind, _stage, _choice):
		if kind == "campaign_drive": sent[0] += 1)
	scene.campaign_view._process(3)
	check(sent[0] == 0, "Reading the driving tutorial sends no idle command stream")
	scene.campaign_view._drive_input("assist")
	scene.campaign_view.stop_driving("Test connection failure")
	scene.campaign_view._process(3)
	check(sent[0] == 0 and not scene.campaign_view.driving_enabled, "A failed drive request stops automatic retries until deliberate input")
	var node = scene.campaign_view.road_view
	var structural_count: int = scene.campaign_view.content.get_child_count()
	c.drive.distance = 100.0
	c.drive.speed = 50.0
	scene.campaign_view.display(c)
	check(scene.campaign_view.road_view == node and scene.campaign_view.content.get_child_count() == structural_count, "Driving snapshots update in place without rebuilding scenery/UI")
	check(get_nodes_in_group("campaign_choice")[0].disabled, "Route choices stay locked before safe stop")
	c.drive.distance = 350.0
	c.drive.speed = 0.0
	c.drive.ready = true
	scene.campaign_view.display(c)
	check(not get_nodes_in_group("campaign_choice")[0].disabled, "Safe stop unlocks narrative route choice")
	for i in range(2): await process_frame
	check(get_nodes_in_group("campaign_driving").is_empty(), "Safe stop replaces completed driving controls with the decision")
	# Exercise the real hit target after a cloud-style waiting/snapshot cycle.
	scene.campaign_view.display(c.duplicate(true), true)
	scene.campaign_view.display(c.duplicate(true), false)
	var route: Button = get_nodes_in_group("campaign_choice")[0]
	check(not route.disabled, "Cloud-style refresh keeps the safe-stop decision enabled")
	scene.campaign_view.scroll.ensure_control_visible(route)
	for i in range(3): await process_frame
	var position := route.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = position
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release, true)
	await process_frame
	check(c.stage == 2, "Actual route button advances the mission after a safe stop")
	for i in range(2): await process_frame
	get_nodes_in_group("campaign_choice")[-1].pressed.emit()
	check("doorway" in scene.campaign_view.feedback.text and c.stage == 2, "Actual wrong-choice button keeps checkpoint and shows its hint")
	scene._exit_campaign()
	check(scene.campaign_view == null and c.paused, "Pausing driving saves checkpoint and stops input loop")
	scene.queue_free()
	print("Tunde driving: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
