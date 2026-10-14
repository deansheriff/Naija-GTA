extends SceneTree
const Campaign = preload("res://core/campaign.gd")
const Simulation = preload("res://core/simulation.gd")
const View = preload("res://campaign_view.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func _initialize() -> void:
	var sim = Simulation.new()
	var story := Campaign.story()
	check(sim.data.campaign == Campaign.fresh(), "Fresh campaign is separate and unstarted")
	check(not sim.campaign_command("campaign_choose", 0, "next").ok, "Cannot choose before starting")
	sim.begin_action("learn")
	check(sim.campaign_command("campaign_start").ok, "Start wedding without deleting street job")
	var initial: Dictionary = sim.data.duplicate(true)
	sim.tick(1200)
	check(sim.data.food == initial.food and sim.data.energy == initial.energy and sim.data.active == initial.active, "Story freezes street needs and active job")
	check(not sim.begin_action("rest").ok, "Story blocks new street actions")
	check(not sim.campaign_command("campaign_start").ok and not sim.campaign_command("campaign_switch", -1, "kc").ok, "No restart or perspective bypass")
	for i in range(story.stages.size()):
		var task: Dictionary = story.stages[i]
		check(sim.data.campaign.lead == task.lead and sim.data.campaign.stage == i, "Task uses authored lead/checkpoint " + str(i))
		check(not sim.campaign_command("campaign_choose", i + 1, "next").ok, "Out-of-order checkpoint rejected " + str(i))
		for option in task.choices:
			if not option.correct:
				var before: Dictionary = sim.data.campaign.duplicate(true)
				var result: Dictionary = sim.campaign_command("campaign_choose", i, option.id)
				check(not result.ok and sim.data.campaign == before and result.message.length() > 15, "Wrong choice gives hint without progress " + task.id)
		if i == 6:
			sim.campaign_command("campaign_pause")
			var restored = Simulation.new()
			restored.load_json(JSON.stringify({"version": 1, "state": sim.data}), false)
			check(restored.data.campaign == sim.data.campaign, "Paused checkpoint survives save/reload")
			check(not restored.campaign_command("campaign_choose", i, "18").ok, "Paused story cannot advance")
			sim.campaign_command("campaign_resume")
		for option in task.choices:
			if option.correct: sim.campaign_command("campaign_choose", i, option.id)
	check(sim.data.campaign.status == "hub" and sim.data.campaign.completed == ["P00"], "Wedding completes one mission")
	check(sim.data.campaign.mastery == {"tunde": 1, "ngozi": 1, "kc": 1} and sim.data.campaign.evidence == ["wedding_clip"], "Three mastery awards and original recording")
	check(sim.data.coins == 240 and not sim.campaign_command("campaign_choose", story.stages.size(), "next").ok, "No street payment or repeat reward")
	for who in Campaign.LEADS:
		check(sim.campaign_command("campaign_switch", -1, who).ok and sim.data.campaign.lead == who, "Family Meeting switches to " + who)
	sim.campaign_command("campaign_pause")
	sim.tick(8)
	check(sim.data.active.is_empty() and sim.data.repair == 1, "Street job resumes after campaign pause")
	var legacy = Simulation.new()
	legacy.load_json('{"version":1,"state":{"coins":301}}', false)
	check(legacy.data.coins == 301 and legacy.data.campaign.status == "unstarted", "Legacy save gains unstarted campaign without resetting money")
	var future := {"version": 2, "unknown": ["keep", 9]}
	check(Campaign.normalize(future) == future and not Campaign.command(future, "campaign_start").ok, "Future campaign is preserved and downgrade blocked")
	check(Campaign.normalize({"version": 1, "status": "playing", "stage": -1}).status == "unstarted", "Invalid checkpoint never indexes content")
	call_deferred("scene_checks")
func scene_checks() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	scene.set_process(false)
	scene.cloud.base_url = ""
	scene.sim.reset()
	scene._open_campaign()
	for i in range(3): await process_frame
	check(scene.campaign_view != null and not scene.world.visible, "Story opens actual scene with layered staging")
	check(not scene.sidebar.visible and not scene.mobile_nav.visible and not scene.header.visible, "Hidden street controls cannot take campaign keyboard focus")
	scene._campaign_command("campaign_start", -1, "")
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_choice").size() == 1, "Arrival has exactly one advancing control")
	scene._campaign_command("campaign_choose", 0, "next")
	for i in range(3): await process_frame
	check(get_nodes_in_group("campaign_choice").size() == 3, "Invitation exposes three choices without duplicate controls")
	var focused: Button = get_nodes_in_group("campaign_choice")[0]
	focused.grab_focus()
	scene.campaign_view.display(scene.sim.data.campaign, true)
	scene.campaign_view.display(scene.sim.data.campaign, false)
	check(scene.get_viewport().gui_get_focus_owner() == focused, "Polling restores keyboard focus after buttons re-enable")
	check(scene.campaign_view.get_rect().end.x <= scene.get_viewport().get_visible_rect().size.x, "Story fits viewport width")
	scene._exit_campaign()
	check(scene.campaign_view == null and scene.world.visible and scene.sim.data.campaign.paused, "Returning to street pauses and reveals world")
	scene._open_campaign()
	check(scene.sim.data.campaign.stage == 1 and not scene.sim.data.campaign.paused, "Reopening resumes saved task")
	scene.queue_free()
	print("Wedding campaign: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
