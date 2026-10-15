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
func kc_hub(prior: String = "defer") -> Dictionary:
	var phone := Phone.fresh()
	phone.battery = 3
	phone.pan = 1
	phone.zoom = 1
	phone.ready = true
	phone.takes = 2
	return Campaign.normalize({"version": 4, "mission": "A13", "status": "hub", "stage": 11, "lead": "kc", "paused": false, "completed": ["P00", "A11", "A12", "A13"], "mastery": {"tunde": 3, "ngozi": 3, "kc": 3}, "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "choices": {"A13-disclose": prior}, "drive": null, "phone": phone})
func _initialize() -> void:
	var old := kc_hub()
	check(old.version == Campaign.VERSION and old.phone.battery == 3 and old.phone.ready and old.choices["A13-disclose"] == "defer", "Version-4 phone and disclosure migrate without replay")
	check(not Journal.available(old) and not Campaign.command(old, "campaign_review").ok, "Journal recovery is not available before the meeting")
	var missing := old.duplicate(true)
	missing.evidence.erase("bag_record")
	check(not Campaign.normalize(missing).evidence.has("bag_record"), "Explicit missing snapshot source is not falsely labelled saved after reload")
	missing.erase("evidence")
	check(Campaign.normalize(missing).evidence.has("bag_record"), "Legacy absent evidence field can reconstruct only completed sources")
	var depleted := old.duplicate(true)
	depleted.version = 4
	depleted.status = "playing"
	depleted.stage = 2
	depleted.phone = Phone.fresh()
	depleted.phone.battery = 0
	depleted.phone.takes = 4
	var restored := Campaign.normalize(depleted)
	check(restored.phone.battery == 0 and restored.phone.takes == 4 and not restored.phone.ready, "Version-4 depleted frame remains recoverable after upgrade")
	var scenarios := [
		{"prior": "admit", "correction": "later", "custody": "ngozi_record", "pact": "protect"},
		{"prior": "defer", "correction": "tell", "custody": "joint_record", "pact": "public_case"},
		{"prior": "defer", "correction": "later", "custody": "joint_record", "pact": "protect"},
		{"prior": "admit", "correction": "tell", "custody": "ngozi_record", "pact": "public_case"}
	]
	for scenario in scenarios:
		var c := kc_hub(scenario.prior)
		Campaign.command(c, "campaign_continue")
		check(c.mission == "A14" and c.lead == "tunde" and Journal.available(c), "Meeting opens with Tunde and the journal")
		var story := Campaign.story("A14")
		for i in range(story.stages.size()):
			var task: Dictionary = story.stages[i]
			check(c.stage == i and c.lead == task.lead, "Ensemble checkpoint " + str(i))
			check(not Campaign.command(c, "campaign_choose", i + 1, "next").ok, "Cannot skip an evidence/meeting checkpoint")
			if i == 3:
				c.evidence.erase("bag_record")
				check(not Campaign.command(c, "campaign_choose", i, "location").ok, "Missing required source blocks the comparison")
				var mastery: Dictionary = c.mastery.duplicate(true)
				check(Campaign.command(c, "campaign_review").ok and c.stage == i and c.evidence.has("bag_record") and c.mastery == mastery, "Journal restores earned source without stage or mastery award")
				check(not c.evidence.has("diary") and not c.evidence.has("nneka_account"), "Review cannot invent unearned future clues")
			for option in task.choices:
				if not option.correct: check(not Campaign.command(c, "campaign_choose", i, option.id).ok and c.stage == i, "Wrong meeting choice keeps checkpoint and gives a hint")
			var choice: String = scenario.correction if task.id == "disclosure" else scenario.custody if task.id == "custody" else scenario.pact if task.id == "pact" else task.choices[0].id
			check(Campaign.command(c, "campaign_choose", i, choice).ok, "Supported ensemble choice progresses")
			c = Campaign.normalize(JSON.parse_string(JSON.stringify(c)))
		check(c.status == "hub" and c.mastery == {"tunde": 4, "ngozi": 4, "kc": 4} and c.evidence.size() == 4 and c.phone.battery == 3, "Meeting awards each lead once and preserves phone/source state")
		var labels: Dictionary = Journal.catalogue().states
		var status := Journal.status(c)
		check(status.disclosure == (labels.disclosure_admitted if scenario.prior == "admit" or scenario.correction == "tell" else labels.disclosure_open), "Disclosure repair preserves any earlier admission")
		check(status.custody == (labels.custody_ngozi_record if scenario.custody == "ngozi_record" else labels.custody_joint_record), "Custody remains the chosen recorded arrangement")
		check(status.pact == (labels.pact_protect if scenario.pact == "protect" else labels.pact_public_case), "Both informed pacts remain explicit saved choices")
		check(not Campaign.command(c, "campaign_choose", 11, "next").ok, "Duplicate meeting rewards are blocked")
		for who in Campaign.LEADS: check(Campaign.command(c, "campaign_switch", -1, who).ok and c.lead == who, "Completed meeting permits all three perspectives")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	scene.sim.data.campaign = kc_hub()
	scene._open_campaign()
	scene._campaign_command("campaign_continue", -1, "")
	for i in range(3): await process_frame
	var c: Dictionary = scene.sim.data.campaign
	check(scene.campaign_view.stage_view.get_script() == load("res://world/meeting_view.gd") and scene.campaign_view.stage_view.lead == "tunde", "Actual meeting stages all leads with the current perspective")
	check(scene.campaign_view.journal_button.visible and not scene.campaign_view.journal_button.disabled, "Meeting exposes the journal in navigation")
	scene.campaign_view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(scene.campaign_view.show_journal and get_nodes_in_group("campaign_record").size() == 6, "Journal shows four sources, initial account and meeting decisions")
	c.evidence.erase("bag_record")
	scene._campaign_command("campaign_review", -1, "")
	for i in range(3): await process_frame
	check(c.evidence.has("bag_record") and c.stage == 0 and c.mastery.kc == 3 and scene.sim.data.coins == 240, "Actual restore control path does not award mastery or coins")
	check(get_nodes_in_group("campaign_record").size() == 6, "Refreshing restored journal does not duplicate cards")
	scene.campaign_view.journal_button.pressed.emit()
	scene.cloud.base_url = "http://127.0.0.1:1/api"
	scene.cloud.token = "disposable-offline-journal-fixture"
	scene.cloud.connected = false
	scene.cloud.busy = false
	scene.cloud.pending = {}
	scene._cloud_changed()
	check("Offline" in scene.campaign_view.feedback.text and get_nodes_in_group("campaign_choice")[0].disabled, "Cached offline scene blocks save actions and explains why")
	check(not scene.campaign_view.back_button.disabled and not scene.campaign_view.journal_button.disabled, "Offline navigation remains enabled")
	var summary: Button
	for node in scene.campaign_view.controls:
		if node.text == "Read summary": summary = node
	check(summary != null and not summary.disabled, "Summary is a local readable action while offline")
	summary.pressed.emit()
	check(scene.campaign_view.show_summary and c.stage == 0 and not c.paused, "Offline summary changes only presentation")
	scene.campaign_view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	var restore_button: Button
	for node in scene.campaign_view.controls:
		if node.text == "Restore earned records": restore_button = node
	check(get_nodes_in_group("campaign_record").size() == 6 and restore_button.disabled, "Offline journal is readable but cannot save a restoration")
	scene._exit_campaign()
	check(scene.campaign_view == null and scene.campaign_hidden and not c.paused and scene.world.visible, "Leaving offline does not falsely acknowledge a server pause")
	scene._cloud_changed()
	check(scene.campaign_view == null, "Background connection changes do not reopen a dismissed scene")
	scene._open_cloud()
	check(scene.modal != null, "Reconnect controls remain reachable after leaving the cached scene")
	scene.cloud.base_url = ""
	scene._open_campaign()
	scene._exit_campaign()
	check(c.paused and scene.campaign_view == null, "Normal local pause still saves and returns to the street")
	scene.queue_free()
	print("Family Meeting: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
