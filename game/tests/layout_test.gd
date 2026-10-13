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
	print("Desktop layout: ", "PASS" if sane else "FAIL")
	quit(0 if sane else 1)
