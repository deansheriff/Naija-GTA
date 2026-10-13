extends SceneTree

const Layout = preload("res://world/district_layout.gd")
const Plan = preload("res://world/world_plan.gd")
const Journey = preload("res://core/journey.gd")
const Activity = preload("res://core/street_activity.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func signature(layout: RefCounted) -> String:
	return JSON.stringify([layout.buildings, layout.furniture, layout.trees, layout.road_modules()])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seeds: Array[int] = [0, Plan.DISTRICTS[1].seed, Plan.DISTRICTS[2].seed]
	for origin in range(3):
		for destination in range(3):
			if origin == destination: continue
			var last: int = 3 + absi(origin - destination)
			for index in range(last + 2):
				var seed_value: int = Plan.chunk_seed(origin, destination, index, last)
				if seed_value not in seeds: seeds.append(seed_value)
	for i in range(1, 65): seeds.append(i * 7919)
	var variants: Dictionary = {}
	var connected := true
	var entrances := true
	var road_clear := true
	var corridors := true
	var modules_connected := true
	for seed_value in seeds:
		var district = Layout.new(seed_value)
		variants[signature(district)] = true
		var spawn := Vector2(768, 635)
		for place in district.places.values():
			var path: PackedVector2Array = district.route(spawn, place.position)
			if path.is_empty(): print("Unreachable seed=", seed_value, " place=", place, " clear endpoint=", district.walkable(place.position))
			connected = connected and not path.is_empty()
			var at := spawn
			for point in path:
				connected = connected and district.clear_segment(at, point)
				at = point
		for building in district.buildings:
			entrances = entrances and district.clear_segment(building.door + Vector2(0, 60), building.inside)
			if seed_value != 0:
				var branch := Rect2(district.junction_x - district.junction_width / 2, 0, district.junction_width, 486)
				road_clear = road_clear and not branch.intersects(building.footprint)
		for tree in district.trees:
			road_clear = road_clear and not district.on_main_road(tree)
			if seed_value != 0: road_clear = road_clear and absf(tree.x - district.junction_x) > district.junction_width / 2 + 12
		var roads: Array = district.road_modules()
		modules_connected = modules_connected and roads[0].from.x == 0 and roads[0].to.x == 1536
		if seed_value != 0: modules_connected = modules_connected and roads[1].to.y == roads[0].from.y and roads[1].to.x > 0 and roads[1].to.x < 1536
		var activity = Activity.new()
		activity.apply_layout(district)
		for walker in activity.walkers:
			for x in range(100, 1440, 40):
				var foot := Vector2(x, walker.base_y + x * walker.slope)
				corridors = corridors and district.walkable(foot) and not district.on_main_road(foot)
	check(connected, "Home, both destinations, all real transit seeds and 64 additional seeds have reachable venues")
	check(entrances, "Generated shop doors preserve body clearance and traversable thresholds")
	check(road_clear, "Buildings and tree roots stay out of the generated road modules")
	check(modules_connected, "Every generated northbound junction joins the same through-road")
	check(corridors, "Every checked seed preserves pavement crossings clear of scenery and main-road traffic")
	check(variants.size() > 50, "Different seeds produce different building, tree and furniture arrangements")
	check(signature(Layout.new(Plan.DISTRICTS[1].seed)) == signature(Layout.new(Plan.DISTRICTS[1].seed)), "A shared seed regenerates the same layout")
	var dogs_safe := true
	for profile in Plan.DISTRICTS:
		var district = Layout.new(profile.seed)
		var activity = Activity.new()
		activity.apply_layout(district)
		activity.configure({"quality": "High", "distance": 2, "effects": true})
		for i in range(1000):
			activity.advance(0.1, Vector2(768, 635))
			for dog in activity.dogs: dogs_safe = dogs_safe and not district.on_main_road(dog.position) and district.walkable(dog.position)
	check(dogs_safe, "Dogs remain on clear pavement across all three playable districts")
	var spacing = Activity.new()
	spacing.apply_layout(Layout.new())
	spacing.configure({"quality": "High", "distance": 2, "effects": true})
	var passer: Dictionary = spacing.walkers[2]
	var initial_x: float = passer.position.x
	var initial_y: float = passer.position.y
	for i in range(10): spacing.advance(0.1, Vector2(initial_x + 45, initial_y))
	check(passer.position.x > initial_x and absf(passer.lane_offset) > 20 and passer.direction.x > 0, "A pedestrian with pavement space steps around the player without reversing or stopping")
	for i in range(10): spacing.advance(0.1, Vector2(-500, -500))
	check(is_zero_approx(passer.lane_offset), "A passer returns smoothly to its corridor after the player clears it")
	var transit_activity = Activity.new()
	transit_activity.apply_layout(Layout.new(Plan.DISTRICTS[1].seed, true, false))
	transit_activity.wrap_agents = false
	transit_activity.traffic_count = 1
	transit_activity.vehicles[0].x = Activity.END_X - 1
	transit_activity.walkers[0].position.x = Activity.END_X - 1
	transit_activity.advance(0.1, Vector2(-500, -500))
	check(transit_activity.vehicles[0].x > Activity.END_X and transit_activity.walkers[0].position.x > Activity.END_X, "Transit cars and pedestrians keep crossing tile seams instead of visibly recycling under the moving camera")
	transit_activity.elapsed = 7.0
	check(transit_activity.bird_position(2).x > Activity.END_X, "Transit birds also continue beyond tile edges instead of popping back into the camera")
	var trip = Journey.new()
	check(not trip.start(-1, 1) and not trip.start(0, 0) and trip.start(0, 2), "Transport rejects invalid or same-stop rides")
	check(not trip.start(0, 1), "A ride cannot be restarted while already active")
	var phases: Dictionary = {}
	var smooth := true
	var bounded := true
	var completed_events := 0
	for i in range(1000):
		var before: Vector2 = trip.position
		if trip.advance(0.05): completed_events += 1
		phases[trip.state] = true
		smooth = smooth and before.distance_to(trip.position) <= 19
		bounded = bounded and trip.visible_chunks().size() <= 3
		if trip.completed: break
	check(phases.has("departing") and phases.has("cruising") and phases.has("arriving") and trip.completed, "A real ride goes through departure, cruising and parking")
	check(smooth, "The moving bus stays continuous across phases and chunk boundaries")
	check(bounded, "The model never requests more than three nearby chunks")
	check(completed_events == 1 and not trip.advance(0.1), "Arrival fires once and cannot repeat after completion")
	check(trip.seed_for(0) == Plan.DISTRICTS[0].seed and trip.seed_for(trip.last_chunk) == Plan.DISTRICTS[2].seed, "Route endpoints use the exact origin and destination layouts")
	var sparse = Journey.new()
	var dense = Journey.new()
	sparse.start(0, 1)
	dense.start(0, 1)
	for i in range(150): sparse.advance(0.1)
	for i in range(750): dense.advance(0.02)
	check(sparse.position.distance_to(dense.position) < 0.1 and sparse.state == dense.state, "Travel pace is independent of frame rate")
	var before_resume: Vector2 = sparse.position
	sparse.advance(3600)
	check(before_resume.distance_to(sparse.position) < 37 and not sparse.completed, "A suspended tab does not jump across the city or finish a ride offline")
	dense.skip_to_arrival()
	check(dense.state == "arriving" and not dense.completed, "Explicit skip keeps the visible arrival phase")
	for i in range(21): dense.advance(0.1)
	check(dense.completed and is_equal_approx(dense.progress(), 1), "Skipping reaches the same destination exactly once")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	if scene.world == null:
		printerr("Scene did not initialize")
		quit(1)
		return
	var coins: int = scene.sim.data.coins
	scene.sim.data.settings.effects = false
	scene.sim.data.settings.quality = "Low"
	scene.sim.data.settings.distance = 0
	check(scene._request_ride(1), "The actual route button initiates walking to a boarding point")
	for i in range(400):
		if scene.walking: scene._move_player(1.0 / 30)
	check(scene.journey_view != null and scene.world.hero.position.distance_to(scene.world.places.bus.position) < 0.6, "The player reaches the stop before boarding")
	var view = scene.journey_view
	view.set_process(false)
	check(scene.journey_panel.visible and not scene.mission_panel.visible and not scene.world.visible, "Riding replaces walking panels with a clear journey panel")
	var no_extra_grids := true
	for chunk in view.chunks.values(): no_extra_grids = no_extra_grids and chunk.layout.grid.region.size == Vector2i.ZERO
	check(no_extra_grids, "Transit scenery does not allocate unused navigation grids")
	var bus_sprite: Sprite2D = view.bus.get_node("Sprite")
	check(view.bus.get_child(1).visible and view.bus.get_child(2).visible and absf(bus_sprite.position.y + bus_sprite.texture.get_height() * bus_sprite.scale.y / 2) < 0.01, "The ride bus keeps grounded tires even on Low with ambient animation off")
	var first_position: Vector2 = view.model.position
	view._process(0.1)
	check(view.model.position != first_position, "Disabling ambient effects never freezes essential vehicle travel")
	scene.sim.data.settings.quality = "Medium"
	scene._apply_graphics()
	var adaptive := true
	for chunk in view.chunks.values(): adaptive = adaptive and chunk.street.traffic_count == 3
	scene.sim.data.settings.quality = "Low"
	scene._apply_graphics()
	for chunk in view.chunks.values(): adaptive = adaptive and chunk.street.traffic_count == 1
	check(adaptive, "Adaptive graphics changes update already loaded transit chunks")
	view.resize_view(Vector2(390, 844))
	var focus: Vector2 = view.camera.position - view.bus.position
	check(absf(focus.x - 70) < 0.01 and focus.y < 0, "Portrait uses the same elevated side-follow camera")
	view.resize_view(Vector2(3200, 720))
	check(view.viewport_size.x / view.camera.zoom.x <= 2304.1, "Wide-window framing fits within the streamed chunk budget")
	for i in range(120): view._process(0.1)
	await process_frame
	check(view.max_loaded <= 3 and view.chunks.size() <= 3 and view.get_child_count() <= 5, "Actual scene chunks unload instead of growing for the whole route")
	scene._skip_ride()
	for i in range(21):
		if scene.journey_view != null: scene.journey_view._process(0.1)
	await process_frame
	check(scene.district_id == 1 and scene.journey_view == null and scene.world.layout.seed_value == Plan.DISTRICTS[1].seed, "Arrival installs the destination's generated walkable district")
	check(scene.world.walkable(scene.world.hero.position) and scene.sim.data.coins == coins, "Arrival is on clear pavement and does not alter the wallet")
	check(scene._request_ride(0, "repair"), "Choosing a starter venue away from home queues a return ride")
	for i in range(20):
		if scene.walking: scene._move_player(1.0 / 30)
	scene._cancel_ride()
	await process_frame
	check(scene.district_id == 1 and scene.journey_view == null and scene.world.visible and scene.pending_venue.is_empty(), "Cancel safely restores the origin stop and clears the queued venue")
	scene._request_ride(0, "repair")
	for i in range(20):
		if scene.walking: scene._move_player(1.0 / 30)
	scene.journey_view.set_process(false)
	scene._skip_ride()
	for i in range(21):
		if scene.journey_view != null: scene.journey_view._process(0.1)
	for i in range(400):
		if scene.walking: scene._move_player(1.0 / 30)
	await process_frame
	check(scene.district_id == 0 and scene.current_place == "repair" and scene.modal != null and scene.sim.data.coins == coins, "A completed return ride continues to the original starter venue without awarding travel money")
	scene._request_ride(1)
	scene._walk_to(Vector2(768, 635), "street")
	check(scene.pending_district == -1 and scene.pending_venue.is_empty(), "Choosing a walking destination cancels a pending boarding request")
	print("World and travel: %s checks, %s failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
