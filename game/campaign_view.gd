extends Control
const Campaign = preload("res://core/campaign.gd")
const Stage = preload("res://world/campaign_stage.gd")
signal requested(kind: String, stage: int, choice: String)
signal exit_requested
const NAMES = {"tunde": "Tunde · Baba God Dey", "ngozi": "Ngozi · Aunty Boss", "kc": "KC · Content is loading"}
const BIOS = {"tunde": "A danfo driver dreaming of a fleet. His shortcuts need witnesses.", "ngozi": "Canteen queen and savings-circle organiser. Every grand speech still needs an invoice.", "kc": "A content creator learning the difference between attention and trust."}
var content: VBoxContainer
var feedback: Label
var scroll: ScrollContainer
var controls: Array[Button] = []
var snapshot: Dictionary = {}
var show_summary := false
var busy := false
var fingerprint := ""
var margin: MarginContainer
var back_button: Button
var focus_before_wait: Control

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
	node.custom_minimum_size.y = 52
	node.pressed.connect(action)
	controls.append(node)
	return node

func display(campaign: Dictionary, waiting: bool = false) -> void:
	var restore_focus := busy and not waiting
	if waiting and not busy:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_ancestor_of(focused): focus_before_wait = focused
	busy = waiting
	var next_fingerprint := JSON.stringify(campaign)
	if next_fingerprint == fingerprint:
		for node in controls:
			if is_instance_valid(node): node.disabled = busy
		if restore_focus:
			if is_instance_valid(focus_before_wait) and focus_before_wait.is_visible_in_tree() and not focus_before_wait.is_queued_for_deletion(): focus_before_wait.grab_focus()
			else: back_button.grab_focus()
		return
	fingerprint = next_fingerprint
	snapshot = campaign.duplicate(true)
	show_summary = false
	build()

func build() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	controls = controls.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	scroll.scroll_vertical = 0
	var c := snapshot
	if c.get("version") != 1:
		content.add_child(label("This campaign needs a newer game client. Its saved progress has been preserved."))
		return
	var story := Campaign.story()
	var stage := Stage.new()
	stage.custom_minimum_size.y = 220 if get_viewport_rect().size.x >= 850 else 170
	stage.lead = c.lead
	if c.status == "playing": stage.scene_id = story.stages[c.stage].scene
	content.add_child(stage)
	if c.status == "unstarted":
		content.add_child(label("Owambe, Owambe", 30, Color("edc06d")))
		content.add_child(label("A wedding loses power. A bag disappears. Three people discover that their next move belongs to the same story."))
		content.add_child(label("Play the wedding introduction with Tunde, Ngozi and KC. Clear labels, free retries and a checkpoint after every step. Your street balances and activities stay separate.", 17, Color("a6b9ad")))
		content.add_child(button("Start the wedding introduction", func(): requested.emit("campaign_start", -1, "")))
	elif c.status == "hub":
		content.add_child(label("Family Meeting", 30, Color("edc06d")))
		content.add_child(label("Wedding introduction complete · P00\nSaved: +1 mastery for each lead · Original wedding recording"))
		content.add_child(label(NAMES[c.lead] + "\n" + BIOS[c.lead], 18, Color("d4ed85")))
		for who in Campaign.LEADS:
			content.add_child(button("Switch to " + NAMES[who], func(): requested.emit("campaign_switch", -1, who)))
		content.add_child(label("Light Out · Act 1 is the next campaign build. The full campaign is still in production. Return to the street while keeping this checkpoint.", 17, Color("a6b9ad")))
	else:
		var task: Dictionary = story.stages[c.stage]
		content.add_child(label("OWAMBE, OWAMBE · " + str(c.stage + 1) + " / " + str(story.stages.size()), 14, Color("a6b9ad")))
		content.add_child(label(task.title, 28, Color("edc06d")))
		content.add_child(label(NAMES[c.lead], 16, Color("d4ed85")))
		content.add_child(label(task.summary if show_summary else task.text))
		content.add_child(button("Full scene" if show_summary else "Read summary", func(): show_summary = not show_summary; build()))
		feedback = label("Choose below. There is no timer or penalty for a retry.", 16, Color("d4ed85"))
		content.add_child(feedback)
		if c.paused:
			content.add_child(button("Resume this checkpoint", func(): requested.emit("campaign_resume", -1, "")))
		else:
			for option in task.choices:
				var choice_button := button(option.label, func(): requested.emit("campaign_choose", int(c.stage), str(option.id)))
				choice_button.add_to_group("campaign_choice")
				content.add_child(choice_button)
	for node in controls:
		if is_instance_valid(node): node.disabled = busy
	if not busy: back_button.grab_focus()

func message(text: String) -> void:
	if is_instance_valid(feedback): feedback.text = text
