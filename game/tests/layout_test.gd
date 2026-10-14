extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5):
		await process_frame
	for panel_name in ["header", "sidebar", "mission_panel", "needs_panel"]:
		var panel: Control = scene.get(panel_name)
		print(panel_name, " rect=", panel.get_rect(), " min=", panel.get_combined_minimum_size())
	var sane: bool = scene.header.size.y < 160 and scene.sidebar.size.x < 350 and scene.mission_panel.size.y < 350 and scene.sidebar.position.y + scene.sidebar.size.y <= scene.get_viewport().get_visible_rect().size.y
	scene.world.apply_settings({"quality": "Low", "distance": 0, "effects": true, "shadows": false})
	var car = scene.world.vehicle_nodes[0]
	var sprite: Sprite2D = car.get_node("Sprite")
	var contact: bool = car.get_child(1).visible and car.get_child(2).visible and absf(sprite.position.y + sprite.texture.get_height() * sprite.scale.y / 2.0) < 0.01
	print("Low graphics tire grounding: ", "PASS" if contact else "FAIL")
	sane = sane and contact
	scene.world.apply_settings({"quality": "High", "distance": 2, "effects": true, "shadows": true})
	var continuous_gait := true
	for i in range(2):
		var walker: Dictionary = scene.world.street.walkers[i]
		walker.position.x = 1775 if i == 0 else -239
		walker.position.y = walker.base_y + walker.position.x * walker.slope
		scene.world.pedestrian_nodes[i].position = walker.position
		var visual = scene.world.pedestrian_nodes[i].get_node("Sprite")
		visual.walk(walker.direction)
		var stride_before: float = visual.travelled
		scene.world._process(0.1)
		continuous_gait = continuous_gait and visual.heading == ("right" if i == 0 else "left") and visual.flip_h == (i == 1)
		continuous_gait = continuous_gait and absf(visual.travelled - fposmod(stride_before + walker.speed * 0.1, visual.stride)) < 0.01
		continuous_gait = continuous_gait and (walker.position.x < -100 if i == 0 else walker.position.x > 1636)
	print("Off-screen recycling preserves rendered gait/facing: ", "PASS" if continuous_gait else "FAIL")
	sane = sane and continuous_gait
	for page in ["inventory", "repair", "food"]:
		if page == "inventory": scene._open_home_inventory()
		else: scene._open_place(page)
		for i in range(6): await process_frame
		var rect: Rect2 = scene.modal_panel.get_rect()
		var fits: bool = rect.position.y >= 0 and rect.end.y <= scene.get_viewport().get_visible_rect().size.y and scene.modal_scroll.size.y > 100
		print(page, " modal fit/scroll: ", "PASS" if fits else "FAIL")
		sane = sane and fits
	print("Desktop layout: ", "PASS" if sane else "FAIL")
	quit(0 if sane else 1)
