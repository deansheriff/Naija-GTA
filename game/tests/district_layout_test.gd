extends SceneTree

const Layout = preload("res://world/district_layout.gd")
const Neighborhood = preload("res://world/neighborhood_2d.gd")
const Activity = preload("res://core/street_activity.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var district = Layout.new()
	check(district.walkable(Vector2(768, 635)), "The player spawns on clear ground")
	var reachable := true
	for from in Neighborhood.PLACES.values():
		for to in Neighborhood.PLACES.values():
			var path: PackedVector2Array = district.route(from.position, to.position)
			reachable = reachable and not path.is_empty()
			var at: Vector2 = from.position
			for next in path:
				reachable = reachable and district.clear_segment(at, next)
				at = next
			reachable = reachable and at.distance_to(to.position) < 0.01
	check(reachable, "Every venue is connected to every other venue by a clear route")
	var doors := true
	var rear_walls := true
	for building in Layout.BUILDINGS:
		var at: Vector2 = building.door + Vector2(0, 60)
		var inside: Vector2 = district.move(at, building.inside - at)
		doors = doors and inside.distance_to(building.inside) < 0.01 and district.interior_at(inside) == building.id
		var back: Vector2 = district.move(inside, Vector2(0, -300))
		rear_walls = rear_walls and back.y >= 336 and district.walkable(back)
	check(doors, "All three buildings can be entered through their front doorway")
	check(rear_walls, "Building rear walls stop the player instead of allowing escape through the roof")
	var blocked_bench := district.move(Vector2(250, 780), Vector2(300, 0))
	check(blocked_bench.x < 268, "A bench blocks a long swept move without tunneling")
	check(not district.walkable(Layout.PARKED_BUS.get_center()), "The parked danfo has a solid footprint")
	check(not district.walkable(Layout.FURNITURE[0].rect.get_center()), "A shop counter has a solid footprint")
	var bus_approach := district.move(Vector2(1020, 780), Vector2(400, 0))
	check(bus_approach.x < 1066, "Walking cannot pass through the parked bus")
	var walk_around := district.route(Vector2(250, 810), Vector2(440, 810))
	check(walk_around.size() >= 2, "Click travel plans a detour around a bench")
	check(district.route(Vector2(768, 635), Layout.PARKED_BUS.get_center()).is_empty(), "Blocked click targets cannot produce a fake successful route")
	var edge := district.move(Vector2(768, 635), Vector2(3000, 0))
	check(edge.x < Layout.WALK_BOUNDS.end.x and district.walkable(edge), "Long movement remains inside the authored world bounds")
	var route_a := district.route(Vector2(768, 635), Vector2(405, 400))
	check(route_a == district.route(Vector2(768, 635), Vector2(405, 400)), "Authored routes are reproducible")
	var fine := Vector2(250, 780)
	for i in range(100): fine = district.move(fine, Vector2(3, 0))
	check(fine.distance_to(blocked_bench) < 4.0, "Collision stays consistent with short and long movement steps")
	var ambience = Activity.new()
	ambience.configure({"quality": "High", "distance": 2, "effects": true})
	var clear_corridors := true
	for i in range(4000):
		ambience.advance(0.05, Vector2(768, 635))
		for walker in ambience.walkers:
			if Layout.WALK_BOUNDS.has_point(walker.position): clear_corridors = clear_corridors and district.walkable(walker.position)
	check(clear_corridors, "Continuous pedestrian corridors stay clear of the modular obstacles over repeated crossings")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	if scene.world == null or scene.world.scenery == null:
		printerr("District scene failed to initialize")
		quit(1)
		return
	check(scene.world.scenery.building_nodes.size() == 3 and scene.world.scenery.roofs.size() == 3, "The actual scene uses separate building shells and roofs")
	var wall_sprite: Sprite2D = scene.world.scenery.building_nodes[0].get_child(0)
	var front_y: float = scene.world.scenery.building_nodes[0].position.y + wall_sprite.position.y + wall_sprite.texture.get_height() * wall_sprite.scale.y / 2.0
	check(absf(front_y - Layout.BUILDINGS[0].footprint.end.y) < 0.01 and scene.world.scenery.building_nodes[0].get_parent() == scene.world.people, "Shells sort at their rear edge while keeping the correct front ground anchor")
	check(scene.world.scenery.canopies.size() == 5 and scene.world.scenery.tree_nodes.size() == 5, "Every modular tree has a separate moving canopy")
	var travel_ok: bool = scene._walk_to(Vector2(405, 400), "street")
	for i in range(400):
		if scene.walking: scene._move_player(1.0 / 30.0)
	check(travel_ok and not scene.walking and scene.world.hero.position.distance_to(Vector2(405, 400)) < 0.6, "The actual player controller reaches a shop interior through its doorway")
	scene.world.resize_view(Vector2(390, 844))
	check(absf(scene.world.camera.position.y - 400) < 0.6, "Portrait follows the player into the room instead of hiding their head behind the objective panel")
	scene.world.resize_view(Vector2(1280, 720))
	scene.world.scenery.tick(0.5, scene.world.hero.position, 2.5, 1.0)
	check(scene.world.scenery.roofs.food.modulate.a < 0.1 and scene.world.scenery.roofs.home.modulate.a == 1.0, "Only the approached building's roof reveals its interior")
	scene.world.hero.position = Vector2(768, 635)
	scene.world.scenery.tick(0.5, scene.world.hero.position, 2.5, 1.0)
	check(scene.world.scenery.roofs.food.modulate.a == 1.0, "The roof restores after leaving the building")
	scene.world.apply_settings({"quality": "Low", "distance": 0, "effects": false, "shadows": false})
	scene.world.scenery.tick(0.5, Vector2(405, 400), 2.5, 1.0)
	check(scene.world.scenery.roofs.food.modulate.a < 0.1 and scene.world.scenery.canopies[0].rotation == 0, "Low keeps doorway visibility while optional canopy motion is disabled")
	print("District layout: %s checks, %s failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
