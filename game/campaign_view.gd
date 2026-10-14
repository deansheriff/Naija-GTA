extends Control
const Campaign = preload("res://core/campaign.gd")
const Stage = preload("res://world/campaign_stage.gd")
const RoadView = preload("res://world/driving_view.gd")
const CanteenView = preload("res://world/canteen_view.gd")
signal requested(kind: String, stage: int, choice: String)
signal exit_requested
const NAMES = {"tunde": "Tunde · Baba God Dey", "ngozi": "Ngozi · Aunty Boss", "kc": "KC · Content is loading"}
const BIOS = {"tunde": "A danfo driver dreaming of a fleet. His shortcuts need witnesses.", "ngozi": "Canteen queen and savings-circle organiser. Every grand speech still needs an invoice.", "kc": "A content creator learning the difference between attention and trust."}
const EVIDENCE_NAMES = {"wedding_clip": "Original wedding recording", "bag_record": "Bag and seat-location record", "catering_invoice": "Catering invoice CAT-18"}
var content: VBoxContainer
var feedback: Label
var feedback_text := "Choose below. There is no timer or penalty for a retry."
var scroll: ScrollContainer
var controls: Array[Button] = []
var snapshot: Dictionary = {}
var show_summary := false
var busy := false
var fingerprint := ""
var margin: MarginContainer
var back_button: Button
var focus_before_wait: Control
var road_view: Control
var drive_status: Label
var drive_mode := "coast"
var drive_timer := 0.0
var driving_enabled := false
var drive_error := ""
var stage_view: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("112f28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	resized.connect(_layout)
	_layout()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(label("NAIJA STREET LIFE · UP NEPA!", 24, Color("d4ed85")))
	root.add_child(label("A campaign told through three lives", 14, Color("a6b9ad")))
	var nav := HBoxContainer.new()
	root.add_child(nav)
	var back := button("Pause · return to the street", func(): exit_requested.emit())
	back_button = back
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back)
	back.grab_focus()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

func _layout() -> void:
	if margin == null: return
	var gutter := maxi(16, int((size.x - 1040) / 2))
	margin.add_theme_constant_override("margin_left", gutter)
	margin.add_theme_constant_override("margin_right", gutter)
	if is_instance_valid(stage_view): stage_view.custom_minimum_size.y = 220 if size.x >= 850 else 170

func label(text: String, font_size: int = 18, color: Color = Color("f4efdb")) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.y = 56
	node.pressed.connect(action)
	controls.append(node)
	return node

func display(campaign: Dictionary, waiting: bool = false) -> void:
	var restore_focus := busy and not waiting
	if waiting and not busy:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_ancestor_of(focused): focus_before_wait = focused
	busy = waiting
	var structural := campaign.duplicate(true)
	structural.erase("drive")
	# At a safe stop, replace the driving controls with the route decision.
	# Moving snapshots continue to update the existing view in place.
	structural["drive_ready"] = campaign.get("drive") is Dictionary and campaign.drive.ready
	var next_fingerprint := JSON.stringify(structural)
	if campaign.get("drive") is Dictionary and snapshot.get("drive") is Dictionary and campaign.drive.misses > snapshot.drive.misses:
		driving_enabled = false
		drive_mode = "coast"
	snapshot = campaign.duplicate(true)
	if next_fingerprint == fingerprint:
		for node in controls:
			if is_instance_valid(node): node.disabled = busy
		if restore_focus:
			if is_instance_valid(focus_before_wait) and focus_before_wait.is_visible_in_tree() and not focus_before_wait.is_queued_for_deletion(): focus_before_wait.grab_focus()
			else: back_button.grab_focus()
		_update_drive()
		_update_feedback()
		return
	fingerprint = next_fingerprint
	show_summary = false
	drive_mode = "coast"
	driving_enabled = false
	drive_error = ""
	build()

func build() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	controls = controls.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	scroll.scroll_vertical = 0
	road_view = null
	drive_status = null
	stage_view = null
	var c := snapshot
	if c.get("version") != Campaign.VERSION or not c.get("mission") in Campaign.ORDER:
		content.add_child(label("This campaign needs a newer game client. Its saved progress has been preserved."))
		return
	var story := Campaign.story(c.mission)
	var task: Dictionary = story.stages[c.stage] if c.status == "playing" else {}
	var road_scene: bool = c.mission == "A11"
	var stage: Control = RoadView.new() if road_scene else CanteenView.new() if c.mission == "A12" else Stage.new()
	stage_view = stage
	stage.custom_minimum_size.y = 220 if get_viewport_rect().size.x >= 850 else 170
	if road_scene:
		road_view = stage
		stage.update_state(c.drive if c.drive is Dictionary else {"distance": 0.0, "speed": 0.0, "lane": 1, "ready": false, "misses": 0}, float(task.get("target", 350)))
	elif c.mission == "A12":
		stage.scene_id = task.get("scene", "canteen")
	else:
		stage.lead = c.lead
		if c.status == "playing": stage.scene_id = task.scene
	content.add_child(stage)
	if task.get("kind") == "drive": _drive_controls()
	if c.status == "unstarted":
		content.add_child(label("Owambe, Owambe", 30, Color("edc06d")))
		content.add_child(label("A wedding loses power. A bag disappears. Three people discover that their next move belongs to the same story."))
		content.add_child(label("Play the wedding introduction with Tunde, Ngozi and KC. Clear labels, free retries and a checkpoint after every step. Your street balances and activities stay separate.", 17, Color("a6b9ad")))
		content.add_child(button("Start the wedding introduction", func(): requested.emit("campaign_start", -1, "")))
	elif c.status == "hub":
		content.add_child(label("Family Meeting", 30, Color("edc06d")))
		content.add_child(label(story.title + " complete\nSaved mastery: Tunde " + str(c.mastery.tunde) + " · Ngozi " + str(c.mastery.ngozi) + " · KC " + str(c.mastery.kc)))
		var facts := PackedStringArray()
		for fact in c.evidence: facts.append(EVIDENCE_NAMES.get(fact, "Recorded evidence"))
		content.add_child(label("Saved evidence: " + ", ".join(facts), 16, Color("a6b9ad")))
		content.add_child(label(NAMES[c.lead] + "\n" + BIOS[c.lead], 18, Color("d4ed85")))
		var next_index: int = Campaign.ORDER.find(c.mission) + 1
		if next_index < Campaign.ORDER.size():
			var next_story := Campaign.story(Campaign.ORDER[next_index])
			var next_lead: String = next_story.stages[0].lead.capitalize()
			content.add_child(button("Continue · " + next_story.title + " (" + next_lead + ")", func(): requested.emit("campaign_continue", -1, "")))
		for who in Campaign.LEADS:
			content.add_child(button("Switch to " + NAMES[who], func(): requested.emit("campaign_switch", -1, who)))
		content.add_child(label("Act 1 · " + ("The next chapter is ready above." if next_index < Campaign.ORDER.size() else "Four Percent is the next mission in production.") + " Return to the street while keeping this checkpoint.", 17, Color("a6b9ad")))
	else:
		content.add_child(label(story.title.to_upper() + " · " + str(c.stage + 1) + " / " + str(story.stages.size()), 14, Color("a6b9ad")))
		content.add_child(label(task.title, 28, Color("edc06d")))
		content.add_child(label(NAMES[c.lead], 16, Color("d4ed85")))
		content.add_child(label(task.summary if show_summary else task.text))
		for record in task.get("records", []): _record_card(record)
		content.add_child(button("Full scene" if show_summary else "Read summary", func(): show_summary = not show_summary; build()))
		feedback_text = "Choose below. There is no timer or penalty for a retry."
		feedback = label(feedback_text, 16, Color("d4ed85"))
		content.add_child(feedback)
		if c.paused:
			content.add_child(button("Resume this checkpoint", func(): requested.emit("campaign_resume", -1, "")))
		else:
			for option in task.choices:
				var choice_button := button(option.label, func(): requested.emit("campaign_choose", int(c.stage), str(option.id)))
				choice_button.add_to_group("campaign_choice")
				choice_button.set_meta("drive_required", task.get("kind") == "drive")
				content.add_child(choice_button)
	for node in controls:
		if is_instance_valid(node): node.disabled = busy
	if not busy: back_button.grab_focus()
	_update_drive()
	_update_feedback()

func _record_card(record: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e9dec2")
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.add_to_group("campaign_record")
	content.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	stack.add_child(label(record.title, 19, Color("25483a")))
	stack.add_child(label("\n".join(record.lines), 17, Color("25483a")))

func _drive_controls() -> void:
	drive_status = label("Driving checkpoint", 17, Color("d4ed85"))
	content.add_child(drive_status)
	if snapshot.drive.ready:
		content.add_child(label("Arrived safely. Read the passenger cue and choose your next move below.", 15, Color("a6b9ad")))
		return
	content.add_child(label("Tap a pace control; the bus keeps that mode until you change it. Right/D accelerates, Left/A brakes, Up/Down changes lane. Guided approach has the same reward.", 14, Color("a6b9ad")))
	var grid := GridContainer.new()
	grid.columns = 2
	content.add_child(grid)
	for entry in [["Accelerate", "accelerate"], ["Brake", "brake"], ["Upper lane", "upper"], ["Lower lane · bay", "lower"], ["Guided approach", "assist"], ["Coast", "coast"]]:
		var node := button(entry[0], _drive_input.bind(str(entry[1])))
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.add_theme_font_size_override("font_size", 15)
		node.add_to_group("campaign_driving")
		grid.add_child(node)

func _drive_input(input: String) -> void:
	if busy: return
	driving_enabled = true
	drive_error = ""
	if input in ["upper", "lower"]:
		requested.emit("campaign_drive", int(snapshot.stage), input)
	else:
		drive_mode = input
		drive_timer = 0.8

func _process(delta: float) -> void:
	if not driving_enabled or not Campaign.active(snapshot) or not snapshot.get("drive") is Dictionary: return
	if snapshot.drive.ready: return
	if drive_mode in ["coast", "brake"] and snapshot.drive.speed == 0:
		driving_enabled = false
		return
	drive_timer += minf(delta, 0.1)
	if drive_timer >= 0.8 and not busy:
		drive_timer = 0
		requested.emit("campaign_drive", int(snapshot.stage), drive_mode)

func _input(event: InputEvent) -> void:
	if not Campaign.active(snapshot) or not snapshot.get("drive") is Dictionary or busy: return
	if event is InputEventKey and event.pressed and not event.echo:
		var input: String = {KEY_RIGHT: "accelerate", KEY_D: "accelerate", KEY_LEFT: "brake", KEY_A: "brake", KEY_UP: "upper", KEY_DOWN: "lower"}.get(event.keycode, "")
		if not input.is_empty():
			_drive_input(input)
			get_viewport().set_input_as_handled()

func _update_drive() -> void:
	if not snapshot.get("drive") is Dictionary: return
	var drive: Dictionary = snapshot.drive
	var visual: Dictionary = drive.duplicate(true)
	if not driving_enabled: visual.speed = 0.0
	if is_instance_valid(road_view): road_view.update_state(visual, 350.0)
	if is_instance_valid(drive_status): drive_status.text = "Safe stop · choose below" if drive.ready else "Route %s%% · pace %s · %s\n%s" % [mini(100, int(drive.distance / 350 * 100)), int(drive.speed), "lower lane / safe bay" if drive.lane == 1 else "upper lane", drive.hint]
	if is_instance_valid(drive_status) and not drive_error.is_empty(): drive_status.text = "Driving paused · " + drive_error + "\nChoose a control to continue."
	for node in controls:
		if is_instance_valid(node) and node.get_meta("drive_required", false): node.disabled = busy or not drive.ready
	for node in get_tree().get_nodes_in_group("campaign_driving"): node.disabled = busy or drive.ready

func stop_driving(reason: String) -> void:
	driving_enabled = false
	drive_mode = "coast"
	drive_error = reason
	_update_drive()

func message(text: String) -> void:
	feedback_text = text
	_update_feedback()

func _update_feedback() -> void:
	if is_instance_valid(feedback): feedback.text = "Saving or refreshing your cloud checkpoint…" if busy else feedback_text
