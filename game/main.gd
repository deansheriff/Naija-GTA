extends Node2D

const Simulation = preload("res://core/simulation.gd")
const Neighborhood = preload("res://world/neighborhood_2d.gd")
const Cloud = preload("res://core/cloud.gd")
const SAVE_PATH = "user://street-life-v1.json"
const CLOUD_CACHE_PATH = "user://cloud-character-cache-v1.json"
const INK = Color("193c32")
const MUTED = Color("a6b9ad")
const CREAM = Color("f4efdb")
const LIME = Color("d4ed85")
const GOLD = Color("edc06d")

var sim = Simulation.new()
var cloud = Cloud.new()
var world: Node2D
var hud: Control
var header: PanelContainer
var sidebar: PanelContainer
var mission_panel: PanelContainer
var needs_panel: PanelContainer
var mobile_nav: HBoxContainer
var activity_panel: PanelContainer
var toast_label: Label
var wallet_label: Label
var clock_label: Label
var brand_title: Label
var brand_subtitle: Label
var balances_column: VBoxContainer
var mission_title: Label
var mission_body: Label
var mission_step: Label
var mission_button: Button
var save_label: Label
var activity_label: Label
var activity_bar: ProgressBar
var stat_bars: Dictionary = {}
var modal: ColorRect
var modal_panel: PanelContainer
var modal_body: VBoxContainer
var modal_scroll: ScrollContainer
var destination := Vector2.ZERO
var walking := false
var destination_place := ""
var save_timer := 0.0
var ui_timer := 0.0
var toast_remaining := 0.0
var benchmark_frames: Array[float] = []
var benchmark_time := 0.0
var suggested_preset := "Measuring…"
var current_place := "street"
var last_dialog := ""

func _ready() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var loaded: Dictionary = _load_progress()
	world = Neighborhood.new()
	add_child(world)
	_build_hud()
	world.set_wall(sim.data.wall)
	_apply_graphics()
	get_viewport().size_changed.connect(_resize)
	_resize()
	call_deferred("_settle_layout")
	_refresh()
	cloud.sim = sim
	cloud.changed.connect(_cloud_changed)
	cloud.notice.connect(_toast)
	add_child(cloud)
	_save()
	_toast(loaded.message)
	if not loaded.ok and not cloud.enabled():
		_open_welcome()
	if OS.has_feature("web") and not JavaScriptBridge.get_interface("NSLSaveStore").available():
		_toast("Browser storage is unavailable. Progress may not survive closing this tab.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()

func _process(delta: float) -> void:
	if cloud.enabled():
		if not sim.data.active.is_empty():
			sim.data.active.remaining = maxf(0, sim.data.active.remaining - delta)
	elif sim.tick(delta):
		_toast(sim.notice)
		_save()
	ui_timer += delta
	save_timer += delta
	if ui_timer >= 0.2:
		ui_timer = 0
		_refresh()
	if save_timer >= 10:
		save_timer = 0
		_save()
	toast_remaining -= delta
	toast_label.visible = toast_remaining > 0
	if modal == null:
		_move_player(delta)
	if benchmark_time < 8 and delta < 0.25:
		benchmark_time += delta
		benchmark_frames.append(delta)
		if benchmark_time >= 8:
			var average := 0.0
			for frame in benchmark_frames:
				average += frame
			average /= maxf(1, benchmark_frames.size())
			suggested_preset = "Low" if average > 0.034 else "Medium"
			if not sim.data.settings.manual and suggested_preset == "Low":
				_preset("Low", false)
				_toast("Low graphics selected for smoother play. Change it in Settings.")

func _move_player(delta: float) -> void:
	var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_W): motion.y -= 1
	if Input.is_physical_key_pressed(KEY_S): motion.y += 1
	if Input.is_physical_key_pressed(KEY_A): motion.x -= 1
	if Input.is_physical_key_pressed(KEY_D): motion.x += 1
	if motion.length() > 0:
		walking = false
		world.hero.position += motion.normalized() * delta * 220
	elif walking:
		var remaining: Vector2 = destination - world.hero.position
		if remaining.length() < 4:
			walking = false
			current_place = destination_place
			_open_place(destination_place)
		else:
			motion = remaining.normalized()
			world.hero.position += motion * minf(delta * 340, remaining.length())
	world.hero.position.x = clampf(world.hero.position.x, 100, 1440)
	world.hero.position.y = clampf(world.hero.position.y, 420, 960)
	world.move_animation(motion)
	if get_viewport().get_visible_rect().size.x < 850:
		world.resize_view(get_viewport().get_visible_rect().size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close_modal()
		if event.keycode == KEY_E and modal == null:
			var nearest := ""
			var distance := 100.0
			for key in Neighborhood.PLACES:
				var value: float = world.hero.position.distance_to(Neighborhood.PLACES[key].position)
				if value < distance:
					nearest = key
					distance = value
			if distance < 125:
				_open_place(nearest)
			else:
				_toast("Walk closer to a venue, or choose one from Explore.")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and modal == null:
		var point := world.get_global_mouse_position()
		if world.walkable(point):
			destination = point
			destination_place = "street"
			walking = true

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", LIME)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.1))
	theme.set_stylebox("normal", "Button", _style(Color("2e5145"), 11, 12))
	theme.set_stylebox("hover", "Button", _style(Color("3f6655"), 11, 12))
	theme.set_stylebox("pressed", "Button", _style(LIME, 11, 12))
	theme.set_stylebox("disabled", "Button", _style(Color("294237"), 11, 12))
	var focus := _style(Color(0, 0, 0, 0), 11, 12)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "PanelContainer", _style(INK, 16, 18))
	theme.set_stylebox("normal", "LineEdit", _style(Color("2e5145"), 8, 12))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_stylebox("normal", "TextEdit", _style(Color("2e5145"), 8, 12))
	theme.set_color("font_color", "TextEdit", CREAM)
	theme.set_stylebox("background", "ProgressBar", _style(Color("365647"), 5, 0))
	theme.set_stylebox("fill", "ProgressBar", _style(LIME, 5, 0))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	return theme

func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(text: String, size: int = 18, color: Color = CREAM) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	if primary:
		button.add_theme_stylebox_override("normal", _style(LIME, 10, 12))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", CREAM)
	return button

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	hud.add_child(panel)
	return panel

func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	parent.add_child(column)
	return column

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = _theme()
	layer.add_child(hud)
	header = _panel()
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	var brand := _column(header_row)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 1)
	brand_title = _label("NAIJA STREET LIFE", 26, LIME)
	brand_subtitle = _label("Build your life. Shape your street.", 14, MUTED)
	brand_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.add_child(brand_title)
	brand.add_child(brand_subtitle)
	balances_column = _column(header_row)
	balances_column.add_theme_constant_override("separation", 1)
	wallet_label = _label("", 24, GOLD)
	clock_label = _label("", 14, MUTED)
	wallet_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	balances_column.add_child(wallet_label)
	balances_column.add_child(clock_label)
	sidebar = _panel()
	var side := _column(sidebar)
	side.add_child(_label("YOUR NEIGHBORHOOD", 13, MUTED))
	for key in ["food", "repair", "home", "square", "bus"]:
		var info: Dictionary = Neighborhood.PLACES[key]
		var button := _button(info.name, _travel.bind(key))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		side.add_child(button)
	side.add_child(HSeparator.new())
	side.add_child(_button("My profile", _open_profile))
	side.add_child(_button("Gig board", _open_market))
	side.add_child(_button("Graphics & settings", _open_settings))
	side.add_child(_label("WASD / arrows to walk\nClick the street to move · E to interact", 13, MUTED))
	save_label = _label("Local save · prototype", 12, MUTED)
	side.add_child(save_label)
	mission_panel = _panel()
	var mission := _column(mission_panel)
	mission_step = _label("", 13, GOLD)
	mission_title = _label("", 25)
	mission_body = _label("", 16, MUTED)
	mission_button = _button("Let's go", _travel_goal, true)
	mission.add_child(mission_step)
	mission.add_child(mission_title)
	mission.add_child(mission_body)
	mission.add_child(mission_button)
	needs_panel = _panel()
	var needs := _column(needs_panel)
	needs.add_child(_label("A LITTLE CHECK-IN", 13, MUTED))
	for key in ["food", "energy", "comfort"]:
		var row := HBoxContainer.new()
		needs.add_child(row)
		var name_label := _label(key.capitalize(), 16)
		name_label.custom_minimum_size.x = 82
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(80, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		stat_bars[key] = bar
	activity_panel = _panel()
	var active := _column(activity_panel)
	activity_label = _label("", 16, CREAM)
	activity_bar = ProgressBar.new()
	activity_bar.show_percentage = false
	activity_bar.custom_minimum_size.y = 8
	active.add_child(activity_label)
	active.add_child(activity_bar)
	activity_panel.visible = false
	toast_label = _label("", 17, INK)
	toast_label.add_theme_stylebox_override("normal", _style(CREAM, 10, 14))
	hud.add_child(toast_label)
	mobile_nav = HBoxContainer.new()
	mobile_nav.add_theme_constant_override("separation", 5)
	hud.add_child(mobile_nav)
	for item in [["Explore", _open_explore], ["Gigs", _open_market], ["Profile", _open_profile], ["Settings", _open_settings]]:
		var button := _button(item[0], item[1])
		button.add_theme_font_size_override("font_size", 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mobile_nav.add_child(button)

func _resize() -> void:
	var physical := DisplayServer.window_get_size()
	var portrait := physical.x < physical.y
	var desired := Vector2i(480, 800) if portrait else Vector2i(1280, 800)
	if get_window().content_scale_size != desired:
		get_window().content_scale_size = desired
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		call_deferred("_resize")
		return
	var size := get_viewport().get_visible_rect().size
	var small := size.x < 850
	balances_column.custom_minimum_size.x = 116 if small else 290
	brand_title.add_theme_font_size_override("font_size", 20 if small else 26)
	brand_subtitle.add_theme_font_size_override("font_size", 12 if small else 14)
	header.position = Vector2(16, 16)
	header.size = Vector2(size.x - 32, 90)
	sidebar.visible = not small
	sidebar.position = Vector2(16, 122)
	sidebar.size = Vector2(250, 562)
	mission_panel.position = Vector2(16, 122) if small else Vector2(size.x - 290, 122)
	mission_panel.size = Vector2(size.x - 32, 190) if small else Vector2(274, 247)
	mission_title.add_theme_font_size_override("font_size", 22 if small else 25)
	needs_panel.position = Vector2(16, size.y - 214) if small else Vector2(size.x - 290, 389)
	needs_panel.size = Vector2(size.x - 32, 118) if small else Vector2(274, 148)
	mobile_nav.visible = small
	mobile_nav.position = Vector2(16, size.y - 64)
	mobile_nav.size = Vector2(size.x - 32, 48)
	activity_panel.position = Vector2(16, size.y - 318) if small else Vector2(290, size.y - 108)
	activity_panel.size = Vector2(size.x - 32, 84) if small else Vector2(size.x - 604, 84)
	toast_label.position = Vector2(16, 326) if small else Vector2(290, 122)
	toast_label.size = Vector2(size.x - 32, 56) if small else Vector2(size.x - 604, 56)
	world.resize_view(size)
	if modal != null:
		_layout_modal()

func _refresh() -> void:
	wallet_label.text = "%s SC" % sim.data.coins
	var hours := int(sim.data.minutes / 60)
	clock_label.text = "DAY %s · %02d:%02d" % [sim.data.day, hours, int(sim.data.minutes) % 60]
	var goal: Dictionary = sim.goal()
	mission_step.text = "FIRST STEPS  ·  %s / 4" % mini(4, goal.step)
	mission_title.text = goal.title
	mission_body.text = goal.body
	mission_button.text = "Explore the square" if goal.step == 5 else "Take me there"
	for key in stat_bars:
		stat_bars[key].value = sim.data[key]
	activity_panel.visible = not sim.data.active.is_empty()
	if activity_panel.visible:
		activity_label.text = "%s · %ss" % [Simulation.ACTIONS[sim.data.active.code].name, ceili(sim.data.active.remaining)]
		activity_bar.value = 100 * (1 - sim.data.active.remaining / sim.data.active.total)

func _settle_layout() -> void:
	# Containers measure wrapped text after their first layout pass.
	await get_tree().process_frame
	await get_tree().process_frame
	_resize()

func _load_progress() -> Dictionary:
	var connection_text := ""
	if OS.has_feature("web"):
		connection_text = str(JavaScriptBridge.get_interface("NSLPrivateStore").read())
	elif FileAccess.file_exists(Cloud.PATH):
		connection_text = FileAccess.get_file_as_string(Cloud.PATH)
	var connection: Variant = JSON.parse_string(connection_text) if not connection_text.is_empty() else null
	var catch_up: bool = not (connection is Dictionary and not str(connection.get("url", "")).is_empty())
	var path := SAVE_PATH if catch_up else CLOUD_CACHE_PATH
	if OS.has_feature("web"):
		var storage = JavaScriptBridge.get_interface("NSLSaveStore" if catch_up else "NSLCloudCacheStore")
		if storage == null:
			return sim.load_from(path, catch_up)
		var payload: String = storage.read()
		if not payload.is_empty():
			var result: Dictionary = sim.load_json(payload, catch_up)
			if not result.ok:
				storage.preserveInvalid(payload)
			return result
	# Migrate existing early browser IndexedDB saves when no synchronous snapshot exists.
	return sim.load_from(path, catch_up)

func _save() -> void:
	var saved := false
	if OS.has_feature("web"):
		sim.data.last_saved = Time.get_unix_time_from_system()
		var storage = JavaScriptBridge.get_interface("NSLCloudCacheStore" if cloud.enabled() else "NSLSaveStore")
		saved = storage.write(JSON.stringify({"version": Simulation.VERSION, "state": sim.data}))
	else:
		saved = sim.save_to(CLOUD_CACHE_PATH if cloud.enabled() else SAVE_PATH)
	if saved:
		if save_label != null:
			save_label.text = cloud.status if cloud.enabled() else "Saved on this device · " + Time.get_time_string_from_system().left(5)
	else:
		_toast("Save failed. Keep this session open and check available storage.")

func _toast(message: String) -> void:
	toast_label.text = message
	toast_remaining = 7
	toast_label.visible = true

func _travel_goal() -> void:
	_travel(sim.goal().place)

func _travel(place: String) -> void:
	_close_modal()
	if not Neighborhood.PLACES.has(place):
		return
	destination = Neighborhood.PLACES[place].position
	destination_place = place
	walking = true
	_toast("Heading to " + Neighborhood.PLACES[place].name + "…")

func _open_explore() -> void:
	_dialog("One street. Plenty of possibilities.", "Choose a place and your character will walk there.")
	for key in ["food", "repair", "home", "square", "bus"]:
		modal_body.add_child(_button(Neighborhood.PLACES[key].name, _travel.bind(key)))

func _open_place(place: String) -> void:
	if place == "street":
		return
	if place == "food":
		_dialog("Amaka's kitchen", "A warm plate, a familiar face, and time to catch your breath.")
		modal_body.add_child(_label("AMAKA · NEIGHBOR", 13, GOLD))
		modal_body.add_child(_button("Say hello", _hello, true))
		modal_body.add_child(_button("Eat jollof · 25 SC · 6 sec", _start.bind("eat")))
		modal_body.add_child(_label("+35 food · SC means fictional StreetCoins", 14, MUTED))
	elif place == "repair":
		_dialog("Yemi's workshop", "Fix something small. Build a skill that lasts.")
		modal_body.add_child(_label("REPAIR SKILL · LEVEL %s" % sim.data.repair, 15, GOLD))
		modal_body.add_child(_button("Practice at the bench · 8 sec", _start.bind("learn"), true))
		var gig := _button("Repair Yemi's radio · earn 90 SC", _start.bind("gig"))
		gig.disabled = sim.data.repair < 1 or sim.data.gig_done
		modal_body.add_child(gig)
		modal_body.add_child(_label("Completed — Yemi's radio works again." if sim.data.gig_done else "Unlocks after one practice. Costs 12 energy; takes 10 seconds.", 15, MUTED))
	elif place == "home":
		_dialog("Your little corner", "No matter how loud the street gets, this place is yours.")
		modal_body.add_child(_button("Rest · +35 energy · 8 sec", _start.bind("rest"), true))
		modal_body.add_child(_button("Freshen up · +20 comfort", _start.bind("wash")))
		modal_body.add_child(_button("Learn digital skills · 8 sec", _start.bind("study")))
		modal_body.add_child(_label("MAKE IT YOURS · FREE HOME ACCENTS", 14, GOLD))
		var colors := HBoxContainer.new()
		modal_body.add_child(colors)
		for color in ["sage", "clay", "ocean"]:
			var button := _button(color.capitalize(), _decorate.bind(color))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			colors.add_child(button)
	elif place == "square":
		_open_poll()
	elif place == "bus":
		_dialog("The street is moving", "This prototype is one walkable neighborhood. More districts and transport routes come after performance testing.")
		modal_body.add_child(_button("Visit the community square", _travel.bind("square"), true))
		modal_body.add_child(_button("Go home", _travel.bind("home")))

func _hello() -> void:
	if cloud.enabled():
		var result: Dictionary = await cloud.submit("greet")
		if result.ok: _close_modal()
		_toast("Amaka: Welcome, neighbor! Try Yemi's repair bench." if result.ok else result.message)
		return
	var response: String = sim.meet_amaka()
	_close_modal()
	_toast(response)
	_save()
	_refresh()

func _start(code: String) -> void:
	var result: Dictionary = await cloud.submit("begin", {"action": code}) if cloud.enabled() else sim.begin_action(code)
	if result.ok:
		_close_modal()
		_save()
	_toast(result.message)
	_refresh()

func _decorate(color: String) -> void:
	if cloud.enabled():
		var result: Dictionary = await cloud.submit("decorate", {"wall": color})
		if result.ok: _close_modal()
		_toast(result.message)
		return
	sim.decorate(color)
	world.set_wall(color)
	_save()
	_close_modal()
	_toast("Home, your way. " + color.capitalize() + " accent applied.")
	_refresh()

func _dialog(title: String, body: String) -> void:
	_close_modal()
	last_dialog = title
	modal = ColorRect.new()
	modal.color = Color(0.04, 0.1, 0.08, 0.75)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(modal)
	modal_panel = PanelContainer.new()
	modal.add_child(modal_panel)
	var outer := _column(modal_panel)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title_label := _label(title, 28, LIME)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	var close := _button("Close", _close_modal)
	close.custom_minimum_size.x = 80
	top.add_child(close)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(modal_scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_scroll.add_child(modal_body)
	modal_body.add_child(_label(body, 18, MUTED))
	modal_body.add_child(HSeparator.new())
	_layout_modal()
	close.grab_focus()

func _layout_modal() -> void:
	var size := get_viewport().get_visible_rect().size
	var width := minf(660, size.x - 32)
	var height := minf(630, size.y - 48)
	modal_panel.position = Vector2((size.x - width) / 2, (size.y - height) / 2)
	modal_panel.size = Vector2(width, height)

func _close_modal() -> void:
	if modal != null:
		hud.remove_child(modal)
		modal.queue_free()
		modal = null

func _open_welcome() -> void:
	_dialog("Your story starts on this street.", "A fresh start, a little room, and a neighborhood full of possibilities. What should we call you?")
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Your character's name"
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 50
	modal_body.add_child(name_input)
	modal_body.add_child(_label("Fictional currency only. Cloud save is available when your game server is connected; otherwise progress stays on this device.", 15, MUTED))
	var begin := func():
		if cloud.enabled():
			var result: Dictionary = await cloud.submit("profile", {"name": name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else "New neighbor", "bio": sim.data.bio})
			if result.ok: _close_modal()
			_toast(result.message)
			return
		sim.data.name = name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else "New neighbor"
		_save()
		_close_modal()
		_toast("Welcome, " + sim.data.name + ". Start by saying hello to Amaka.")
	modal_body.add_child(_button("Step into the neighborhood", begin, true))
	name_input.grab_focus()

func _open_profile() -> void:
	_dialog("Your story, so far", "Game skills help with fictional gigs. They are separate from professional qualifications.")
	var name_input := LineEdit.new()
	name_input.text = sim.data.name
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 48
	modal_body.add_child(_label("CHARACTER NAME", 13, GOLD))
	modal_body.add_child(name_input)
	var bio := TextEdit.new()
	bio.text = sim.data.bio
	bio.custom_minimum_size.y = 100
	bio.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	modal_body.add_child(_label("A LITTLE ABOUT YOU", 13, GOLD))
	modal_body.add_child(bio)
	modal_body.add_child(_label("Repair: %s   ·   Digital: %s   ·   Connection: %s" % [sim.data.repair, sim.data.digital, sim.data.social], 18))
	modal_body.add_child(_label("Experience: " + ("Completed Yemi's radio repair." if sim.data.gig_done else "Your first gig is still ahead."), 16, MUTED))
	var save_profile := func():
		if cloud.enabled():
			var result: Dictionary = await cloud.submit("profile", {"name": name_input.text.strip_edges().left(24) if not name_input.text.strip_edges().is_empty() else "New neighbor", "bio": bio.text.strip_edges().left(160)})
			if result.ok: _close_modal()
			_toast(result.message)
			return
		sim.data.name = name_input.text.strip_edges().left(24) if not name_input.text.strip_edges().is_empty() else "New neighbor"
		sim.data.bio = bio.text.strip_edges().left(160)
		_save()
		_close_modal()
		_toast("Profile saved on this device.")
	modal_body.add_child(_button("Save profile", save_profile, true))
	modal_body.add_child(_button("Cloud save & another device", _open_cloud))

func _open_market() -> void:
	_dialog("Good work starts here", "Private gig drafts · StreetCoins only. Drafts are not published to other players. Cloud-connected drafts save with your character.")
	modal_body.add_child(_label("REPAIR · STARTER GIG", 13, GOLD))
	modal_body.add_child(_label("Yemi's radio needs a second life", 24))
	modal_body.add_child(_label("Learn Repair 1, then finish the task at Yemi's workshop. Payment: 90 SC. No real money or professional qualification implied.", 17, MUTED))
	modal_body.add_child(_button("Completed" if sim.data.gig_done else "Visit the repair shop", _travel.bind("repair"), not sim.data.gig_done))
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_button("Post a local gig draft · 100 SC fee", _open_post))
	for post in sim.data.posts:
		modal_body.add_child(_label(post.title + " · " + str(post.budget) + " SC · " + post.status, 17))
		if not post.refunded:
			var cancel := func():
				if cloud.enabled():
					var result: Dictionary = await cloud.submit("cancel", {"jobId": str(post.id)})
					if result.ok: _open_market()
					_toast(result.message)
					return
				sim.cancel_job(post.id)
				_save()
				_open_market()
				_toast("Reserved budget returned. Posting fee remains paid.")
			modal_body.add_child(_button("Cancel draft & return budget", cancel))

func _open_post() -> void:
	_dialog("Post a game gig", "100 StreetCoins posting fee plus your reserved budget. Canceling returns the budget; the fee remains paid. Private draft: workers cannot apply yet.")
	var title := LineEdit.new()
	title.placeholder_text = "e.g. Help repair a kitchen radio"
	title.max_length = 60
	title.custom_minimum_size.y = 48
	modal_body.add_child(title)
	var budget := SpinBox.new()
	budget.min_value = 10
	budget.max_value = 10000
	budget.value = 30
	budget.step = 10
	budget.suffix = " SC budget"
	budget.custom_minimum_size.y = 48
	modal_body.add_child(budget)
	var submit := func():
		var result: Dictionary = await cloud.submit("post", {"title": title.text, "budget": int(budget.value)}) if cloud.enabled() else sim.post_job(title.text, int(budget.value))
		if result.ok:
			_save()
			_open_market()
		_toast(result.message)
	modal_body.add_child(_button("Pay fee & reserve budget", submit, true))

func _open_poll() -> void:
	_dialog("A better street begins with us", "A private practice poll. Your choice saves with your character when connected, or on this device in local play. These are not live election results.")
	modal_body.add_child(_label("WHAT SHOULD THE NEIGHBORHOOD IMPROVE?", 15, GOLD))
	for option in ["A greener community square", "Better evening street lighting", "More benches at the bus stop"]:
		var select := func():
			if cloud.enabled():
				var result: Dictionary = await cloud.submit("poll", {"choice": option})
				if result.ok: _open_poll()
				_toast(result.message)
				return
			sim.data.vote = option
			_save()
			_open_poll()
			_toast("Practice vote saved. You can change it here.")
		modal_body.add_child(_button(("Selected · " if sim.data.vote == option else "") + option, select, sim.data.vote == option))
	modal_body.add_child(_label("Fictional council candidates, timed voting, server eligibility and visible policy effects arrive in the community milestone. No fabricated voter counts.", 15, MUTED))

func _preset(quality: String, manual: bool = true) -> void:
	sim.data.settings.quality = quality
	sim.data.settings.shadows = quality != "Low"
	sim.data.settings.effects = quality != "Low"
	sim.data.settings.distance = 0 if quality == "Low" else 1 if quality == "Medium" else 2
	sim.data.settings.fps = 30 if quality != "High" else 60
	sim.data.settings.manual = manual
	_apply_graphics()
	_save()

func _apply_graphics() -> void:
	Engine.max_fps = int(sim.data.settings.fps)
	world.apply_settings(sim.data.settings)

func _open_settings() -> void:
	_dialog("Make it work for your device", "Graphics change presentation, never rewards or task eligibility. " + ("Native Android build." if OS.has_feature("Android") else "Browser/desktop-compatible build."))
	modal_body.add_child(_button(cloud.status + " · Cloud save", _open_cloud))
	modal_body.add_child(_label("QUALITY · " + sim.data.settings.quality.to_upper(), 14, GOLD))
	var presets := HBoxContainer.new()
	modal_body.add_child(presets)
	for quality in ["Low", "Medium", "High"]:
		var select := func():
			_preset(quality)
			_open_settings()
		var button := _button(quality, select, quality == sim.data.settings.quality)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
	modal_body.add_child(_label("First-run suggestion: " + suggested_preset + " · measure on real phones before treating this as a benchmark.", 14, MUTED))
	for item in [["shadows", "Shadows"], ["effects", "Ambient animation"], ["data_saver", "Data Saver"]]:
		var key: String = item[0]
		var toggle := CheckButton.new()
		toggle.text = item[1]
		toggle.button_pressed = sim.data.settings[key]
		toggle.custom_minimum_size.y = 48
		var change := func(value: bool):
			sim.data.settings[key] = value
			sim.data.settings.manual = true
			_apply_graphics()
			_save()
		toggle.toggled.connect(change)
		modal_body.add_child(toggle)
	var fps := OptionButton.new()
	fps.add_item("Frame cap · 30 FPS", 30)
	fps.add_item("Frame cap · 60 FPS", 60)
	fps.select(0 if sim.data.settings.fps == 30 else 1)
	fps.custom_minimum_size.y = 48
	fps.item_selected.connect(func(index: int):
		sim.data.settings.fps = fps.get_item_id(index)
		sim.data.settings.manual = true
		_apply_graphics()
		_save())
	modal_body.add_child(fps)
	var distance := OptionButton.new()
	for text in ["View distance · Short", "View distance · Medium", "View distance · Long"]:
		distance.add_item(text)
	distance.select(sim.data.settings.distance)
	distance.custom_minimum_size.y = 48
	distance.item_selected.connect(func(index: int):
		sim.data.settings.distance = index
		sim.data.settings.manual = true
		_apply_graphics()
		_save())
	modal_body.add_child(distance)
	modal_body.add_child(_label("The painted art is included in this build; optional HD packs are not available yet. Cloud progress uses your connected server. Jev and news are not connected.", 14, MUTED))
	modal_body.add_child(_label("Illustrated 2D · FPS: %s · Draw calls: %s\nOriginal painted street and animated character sprites." % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))], 13, MUTED))
	modal_body.add_child(_button("Engine credits & licenses", _open_credits))

func _open_credits() -> void:
	_dialog("Credits & licenses", "Original game code for Naija Street Life. Painted street and character assets generated with OpenAI imagegen. Powered by Godot Engine.")
	modal_body.add_child(_label(Engine.get_license_text(), 14, MUTED))
	modal_body.add_child(_button("Third-party license texts", _open_component_licenses))
	for component in Engine.get_copyright_info():
		modal_body.add_child(_label(component.name, 15, GOLD))
		for part in component.parts:
			modal_body.add_child(_label("\n".join(part.copyright) + "\nLicense: " + str(part.license), 12, MUTED))

func _open_component_licenses() -> void:
	_dialog("Third-party licenses", "Full license texts for components included in this engine build.")
	var licenses: Dictionary = Engine.get_license_info()
	for license_name in licenses:
		modal_body.add_child(_label(license_name, 18, GOLD))
		modal_body.add_child(_label(licenses[license_name], 12, MUTED))

func _cloud_changed() -> void:
	world.set_wall(sim.data.wall)
	_refresh()
	_save()

func _open_cloud() -> void:
	_dialog("Your street, across devices", "Connect to your game server to save progress online. Local prototype balances are not imported. Your save access code opens the same character on another device; keep it private and safe. Lost codes cannot be recovered yet.")
	modal_body.add_child(_label(cloud.status, 17, GOLD))
	var url := LineEdit.new()
	url.placeholder_text = "https://your-game-domain.example"
	url.text = cloud.base_url
	if OS.has_feature("web"):
		url.text = str(JavaScriptBridge.get_interface("window").location.origin) + "/api"
		url.editable = false
	url.custom_minimum_size.y = 48
	modal_body.add_child(_label("GAME SERVER URL", 13, GOLD))
	modal_body.add_child(url)
	if OS.has_feature("web"):
		modal_body.add_child(_label("This browser page uses its own game server. Open your deployed game address to connect there. Android lets you enter that address.", 14, MUTED))
	var code := LineEdit.new()
	code.placeholder_text = "Save access code; blank keeps your current save here"
	code.secret = true
	code.custom_minimum_size.y = 48
	modal_body.add_child(code)
	modal_body.add_child(_button("Connect save", func(): cloud.configure(url.text, code.text), true))
	if cloud.enabled():
		modal_body.add_child(_button("Reconnect current save", cloud.connect_save))
	if not cloud.pending.is_empty():
		modal_body.add_child(_button("Retry pending action", func():
			var result: Dictionary = await cloud.retry_pending()
			_toast(result.message)))
	if not cloud.recovery_code.is_empty():
		modal_body.add_child(_label("SAVE ACCESS CODE · treat it like a password", 13, GOLD))
		var access := LineEdit.new()
		access.text = cloud.recovery_code
		access.editable = false
		access.secret = true
		access.custom_minimum_size.y = 48
		modal_body.add_child(access)
		modal_body.add_child(_button("Show / hide my save access code", func(): access.secret = not access.secret))
	modal_body.add_child(_label("Activities, skills, coins, profile, home color and private drafts use server rules when connected. Graphics settings stay on each device. This is an early self-hosted save system; shared marketplace, elections, payments and email recovery are not available.", 14, MUTED))
