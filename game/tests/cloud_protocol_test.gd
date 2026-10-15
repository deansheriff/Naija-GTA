extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Cloud = preload("res://core/cloud.gd")
const Fixture = preload("res://tests/cloud_protocol_fixture.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func matching() -> Dictionary:
	return {"api": 1, "campaignVersion": Campaign.VERSION, "campaignMissions": Campaign.ORDER.duplicate(), "campaignCommands": Cloud.CAMPAIGN_COMMANDS.duplicate()}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var cloud = Fixture.new()
	root.add_child(cloud)
	cloud.set_process(false)
	check(cloud.supports_campaign(), "Local play does not require server metadata")
	cloud.base_url = "http://127.0.0.1:1/api"
	cloud.connected = true
	cloud.token = "disposable-protocol-fixture"
	check(not cloud.supports_campaign() and "could not be checked" in cloud.campaign_unavailable_reason(), "Unknown handshake gives reconnect guidance")
	cloud._accept_world({"settings": {"maintenance": false}})
	check(not cloud.supports_campaign() and "update" in cloud.campaign_unavailable_reason(), "Legacy server without metadata blocks story writes with update guidance")
	var result: Dictionary = await cloud.submit("campaign_start")
	check(not result.ok and cloud.calls.is_empty() and cloud.pending.is_empty() and cloud.writes == 0, "Unsupported fresh action never persists or transmits")
	for variant in [{}, {"api": 2}, {"api": 1, "campaignVersion": Campaign.VERSION + 1}, {"api": 1, "campaignVersion": Campaign.VERSION - 1}, {"api": 1, "campaignVersion": Campaign.VERSION, "campaignMissions": "P00", "campaignCommands": []}]:
		cloud._accept_world({"capabilities": variant})
		check(not cloud.supports_campaign(), "Malformed, older and future protocols remain read-only")
	var cap := matching()
	cap.campaignMissions.erase("A21")
	cloud._accept_world({"capabilities": cap})
	check(not cloud.supports_campaign(), "Missing authored mission blocks mismatched UI")
	cap = matching()
	cap.campaignCommands.erase("campaign_review")
	cloud._accept_world({"capabilities": cap})
	check(not cloud.supports_campaign(), "Missing command blocks mismatched story support")
	cloud._accept_world({"settings": {"maintenance": false}, "capabilities": matching()})
	check(cloud.supports_campaign("campaign_start") and not cloud.supports_campaign("campaign_invented"), "Matching protocol enables only advertised commands")
	cloud.responses = [{"ok": false, "code": 503, "payload": {}, "message": "Simulated interrupted request"}]
	result = await cloud.submit("campaign_choose", {"stage": 3, "choice": "stopped"})
	var kept: Dictionary = cloud.pending.duplicate(true)
	check(not result.ok and not kept.is_empty() and cloud.calls.size() == 1, "Interrupted supported action keeps its durable body and key")
	cloud._accept_world({"settings": {}})
	cloud.connected = true
	result = await cloud.retry_pending()
	check(not result.ok and cloud.pending == kept and cloud.calls.size() == 1, "Unsupported pending retry keeps the exact action without HTTP")
	cloud._process(6.0)
	check(cloud.calls.size() == 1 and cloud.pending == kept, "Automatic retry does not spam an incompatible server")
	cloud._accept_world({"capabilities": matching()})
	cloud.responses = [{"ok": true, "code": 200, "payload": {"revision": 1}, "message": ""}]
	result = await cloud.retry_pending()
	check(result.ok and cloud.pending.is_empty() and cloud.applies == 1 and cloud.calls[1].body == kept.body and cloud.calls[1].key == kept.key, "Matching reconnect sends the original intent exactly once")
	cloud.responses = [{"ok": false, "code": 400, "payload": {"error": "invalid_request"}, "message": "Rejected by rollback"}, {"ok": true, "code": 200, "payload": {"settings": {}}, "message": ""}]
	result = await cloud.submit("campaign_review")
	kept = cloud.pending.duplicate(true)
	check(not result.ok and not kept.is_empty() and not cloud.supports_campaign() and cloud.calls[-1].path == "/v1/world", "Rollback rejection rechecks support before discarding a story action")
	cloud._accept_world({"capabilities": matching()})
	cloud.responses = [{"ok": true, "code": 200, "payload": {"revision": 2}, "message": ""}]
	result = await cloud.retry_pending()
	check(result.ok and cloud.calls[-1].key == kept.key and cloud.pending.is_empty(), "Rollback-held action recovers after the matching deployment returns")
	cloud._accept_world({"settings": {}})
	cloud.responses = [{"ok": true, "code": 200, "payload": {"revision": 3}, "message": ""}]
	result = await cloud.submit("greet")
	check(result.ok and cloud.calls[-1].body.kind == "greet", "Legacy server detection does not disable supported sandbox actions")
	cloud.queue_free()
	await scene_checks()
	print("Cloud story protocol: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	var original_cloud = scene.cloud
	scene.remove_child(original_cloud)
	original_cloud.queue_free()
	scene.cloud = Fixture.new()
	scene.cloud.sim = scene.sim
	scene.add_child(scene.cloud)
	scene.cloud.set_process(false)
	scene.cloud.changed.connect(scene._cloud_changed)
	scene.sim.reset()
	scene.sim.data.campaign = Campaign.normalize({"version": 5, "mission": "A14", "status": "hub", "stage": 12, "lead": "ngozi", "paused": true, "completed": ["P00", "A11", "A12", "A13", "A14"], "evidence": ["wedding_clip", "bag_record", "catering_invoice", "original_clip"], "choices": {"A14-pact": "protect"}})
	scene.cloud.base_url = "http://127.0.0.1:1/api"
	scene.cloud.connected = true
	scene.cloud._accept_world({"settings": {}})
	scene._open_campaign()
	for i in range(3): await process_frame
	check(scene.cloud.pending.is_empty() and scene.cloud.get_child_count() == 0 and scene.sim.data.campaign.paused, "Actual mismatched hub does not auto-resume or create a request")
	var view = scene.campaign_view
	check(view.busy and not view.back_button.disabled and not view.journal_button.disabled and view.connection_notice.visible and "update" in view.connection_notice.text, "Actual hub visibly explains mismatch with local navigation enabled")
	view.journal_button.pressed.emit()
	for i in range(3): await process_frame
	check(view.show_journal and get_nodes_in_group("campaign_record").size() == 6, "Existing sources remain readable with an old server")
	scene._exit_campaign()
	check(scene.campaign_view == null and scene.sim.data.campaign.paused and scene.cloud.pending.is_empty(), "Returning from a mismatched hub preserves its confirmed pause")
	scene._open_cloud()
	check(scene.modal != null, "Reconnect controls remain reachable")
	scene._open_campaign()
	var resumed: Dictionary = scene.sim.data.campaign.duplicate(true)
	resumed.paused = false
	scene.cloud.responses = [{"ok": true, "code": 200, "payload": {"revision": 1, "campaign": resumed}, "message": ""}]
	scene.cloud._accept_world({"capabilities": matching()})
	scene._cloud_changed()
	for i in range(3): await process_frame
	check(not scene.sim.data.campaign.paused and not scene.campaign_view.busy and scene.cloud.calls.size() == 1 and scene.cloud.calls[0].body.kind == "campaign_resume", "Matching reconnect resumes a previously blocked open scene once")
	resumed.paused = true
	scene.cloud.responses = [{"ok": true, "code": 200, "payload": {"revision": 2, "campaign": resumed}, "message": ""}]
	scene._exit_campaign()
	for i in range(3): await process_frame
	check(scene.campaign_view == null and scene.sim.data.campaign.paused and scene.cloud.calls.size() == 2 and scene.cloud.calls[1].body.kind == "campaign_pause", "Normal confirmed pause is not accidentally auto-resumed after compatibility recovery")
	scene.queue_free()
