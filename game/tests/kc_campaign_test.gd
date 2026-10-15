extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Phone = preload("res://core/phone_task.gd")
const View = preload("res://world/phone_view.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func ngozi_hub() -> Dictionary:
	return Campaign.normalize({"version": 3, "mission": "A12", "status": "hub", "stage": 11, "lead": "ngozi", "paused": false, "completed": ["P00", "A11", "A12"], "mastery": {"tunde": 3, "ngozi": 3, "kc": 1}, "evidence": ["wedding_clip", "bag_record", "catering_invoice"], "choices": {"A12-sola_terms": "firm"}, "drive": null})
func _initialize() -> void:
	var old := ngozi_hub()
	check(old.version == Campaign.VERSION and old.choices["A12-sola_terms"] == "firm" and old.phone == null, "Version-3 Ajo schedule and mastery migrate without replay")
	var p := Phone.fresh()
	Phone.advance(p, "left", 1)
	check(p.pan == 0 and p.battery == 4, "Left bound and free pan")
	for i in range(3): Phone.advance(p, "right", 1)
	check(p.pan == 2 and p.battery == 4 and View.included(p) == [2], "Right bound/detail has one subject")
	Phone.advance(p, "wide", 1)
	check(View.included(p) == [1, 2], "Wide offset crop still misses a subject")
	for i in range(4): Phone.advance(p, "record", 1)
	check(p.battery == 0 and p.takes == 4 and not p.ready, "Four incorrect saved attempts exhaust the staged battery")
	Phone.advance(p, "record", 1)
	check(p.battery == 0 and p.takes == 4, "Empty battery does not create another take")
	Phone.advance(p, "charge", 1)
	check(p.battery == 4 and p.charges == 1, "Free recovery provides enough charge")
	Phone.advance(p, "assist", 1)
	check(p.ready and p.battery == 3 and View.included(p) == [0, 1, 2], "Guided full frame has the same successful cost")
	Phone.advance(p, "record", 1)
	check(p.battery == 3 and p.takes == 5, "Completed take cannot debit twice")
	for route in ["kiosk", "bank", "bench"]:
		var c := ngozi_hub()
		Campaign.command(c, "campaign_continue")
		check(c.mission == "A13" and c.lead == "kc" and c.phone.battery == 4, "Continue enters KC's four-percent setup")
		var story := Campaign.story("A13")
		for i in range(story.stages.size()):
			var task: Dictionary = story.stages[i]
			check(c.stage == i and c.lead == "kc", "KC checkpoint " + str(i))
			check(not Campaign.command(c, "campaign_choose", i + 1, "next").ok, "Cannot skip the current camera/conversation task")
			if task.get("kind") == "frame":
				check(not Campaign.command(c, "campaign_choose", i, "keep").ok, "Cannot claim an unsaved frame")
				if task.id == "practice":
					for take in range(4): Campaign.command(c, "campaign_phone", i, "record")
					check(c.phone.battery == 0 and c.phone.takes == 4 and not c.phone.ready, "Practice can fail into recoverable depletion")
					c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
					check(c.phone.battery == 0 and c.evidence.has("wedding_clip"), "Reload preserves empty phone and existing evidence")
					Campaign.command(c, "campaign_phone", i, "charge")
					Campaign.command(c, "campaign_phone", i, "right")
					Campaign.command(c, "campaign_phone", i, "wide")
					check(c.phone.battery == 4, "Adjustments after recovery cost nothing")
					Campaign.command(c, "campaign_phone", i, "record")
				else: Campaign.command(c, "campaign_phone", i, "assist")
				check(c.phone.ready and c.phone.battery == 3, "Manual/guided complete the required wide frame")
			for option in task.choices:
				if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id).ok and c.stage == i, "Wrong narrative choice gives a free retry")
			var choice: String = route if task.id == "route" else ("defer" if route == "bank" else "admit") if task.id == "disclose" else task.choices[0].id
			check(Campaign.command(c, "campaign_choose", i, choice).ok, "Supported KC checkpoint progresses")
			c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
		check(c.status == "hub" and c.mastery == {"tunde": 3, "ngozi": 3, "kc": 3} and c.evidence == ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "Original source and KC mastery awarded once")
		check(c.choices["A13-route"] == route and c.choices["A13-disclose"] == ("defer" if route == "bank" else "admit"), "Charging route and disclosure remain explicit choices")
		check(not Campaign.command(c, "campaign_choose", 10, "next").ok, "Duplicate source rewards blocked")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	scene.sim.data.campaign = ngozi_hub()
	scene._open_campaign()
	scene._campaign_command("campaign_continue", -1, "")
	scene._campaign_command("campaign_choose", 0, "next")
	scene._campaign_command("campaign_choose", 1, "ask")
	for i in range(3): await process_frame
	var c: Dictionary = scene.sim.data.campaign
	check(get_nodes_in_group("campaign_phone").size() == 7 and scene.campaign_view.phone_view != null, "Camera scene exposes framing, guided and recovery controls")
	check(get_nodes_in_group("campaign_choice")[0].disabled, "Continue is locked until a take is saved")
	var view = scene.campaign_view.phone_view
	for take in range(4): scene.campaign_view._phone_input("record")
	check(c.phone.battery == 0 and scene.campaign_view.phone_view == view, "Phone snapshots update in place through depletion")
	var charge: Button
	var record: Button
	for node in get_nodes_in_group("campaign_phone"):
		if node.get_meta("phone_input") == "charge": charge = node
		if node.get_meta("phone_input") == "record": record = node
	check(not charge.disabled and record.disabled and "Battery empty" in scene.campaign_view.phone_status.text, "Empty phone offers usable recovery and explains the stop")
	charge.pressed.emit()
	check(c.phone.battery == 4 and not record.disabled, "Actual recovery control restores a playable phone")
	for key in [KEY_RIGHT, KEY_UP, KEY_R]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		scene.campaign_view._input(event)
	for i in range(3): await process_frame
	check(c.phone.ready and c.phone.battery == 3 and get_nodes_in_group("campaign_phone").is_empty(), "Keyboard full frame replaces finished controls with the decision")
	get_nodes_in_group("campaign_choice")[0].pressed.emit()
	check(c.stage == 3, "Actual saved-frame decision advances to charging route")
	scene._campaign_command("campaign_choose", 3, "bank")
	for i in range(3): await process_frame
	var has_variant := false
	for child in scene.campaign_view.content.get_children():
		if child is Label and "The power bank is empty" in child.text: has_variant = true
	check(has_variant and c.choices["A13-route"] == "bank", "Saved route selects its authored empty-bank response")
	scene._exit_campaign()
	check(scene.campaign_view == null and c.paused and c.phone.battery == 3, "Pause preserves battery, route and evidence")
	scene.queue_free()
	print("Four Percent: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
