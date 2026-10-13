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
	var sane: bool = scene.header.size.y < 160 and scene.sidebar.size.x < 350 and scene.mission_panel.size.y < 350
	print("Desktop layout: ", "PASS" if sane else "FAIL")
	quit(0 if sane else 1)
