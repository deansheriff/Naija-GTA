extends SceneTree

const Activity = preload("res://core/street_activity.gd")
const Dialogue = preload("res://core/street_dialogue.gd")
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	var street = Activity.new()
	var first: Dictionary = street.vehicles[0]
	var original_x: float = first.x
	street.advance(0.1, street.vehicle_position(first) + Vector2(110, 0))
	check(first.stopped and first.x == original_x, "Traffic yields to a player ahead in its lane")
	street.advance(0.1, Vector2(800, 880))
	check(not first.stopped and first.x > original_x, "Traffic resumes after the player clears the road")
	street.vehicles[2].x = first.x + 125
	street.advance(0.1, Vector2(800, 880))
	check(first.stopped, "Following traffic keeps a gap behind another vehicle")
	street.traffic_count = 1
	first.x = Activity.END_X - 1
	street.advance(0.1, Vector2(800, 880))
	check(first.x < Activity.START_X + 20, "Traffic wraps off-scene without spawning new nodes")
	street.configure({"quality": "Low", "distance": 0, "effects": true})
	check(street.traffic_count == 1 and street.walker_count == 1 and street.moving, "Low retains essential street motion at bounded density")
	street.configure({"quality": "High", "distance": 2, "effects": false})
	var previous_position: Vector2 = street.walkers[0].position
	original_x = first.x
	street.advance(0.1, Vector2(800, 880))
	check(first.x == original_x and street.walkers[0].position == previous_position, "Animation preference pauses both traffic and pedestrian motion")
	check(street.walkers[0].movement == Vector2.ZERO, "Pausing clears the last step so a stationary pedestrian cannot keep animating")
	street.configure({"quality": "High", "distance": 2, "effects": true})
	var continuous := true
	var same_heading := true
	var hidden_recycling := true
	var crossings := [0, 0, 0, 0, 0, 0]
	for i in range(4000):
		var before: Array[Vector2] = []
		for walker in street.walkers: before.append(walker.position)
		street.advance(0.05, Vector2(800, 880))
		for j in range(street.walker_count):
			var walker: Dictionary = street.walkers[j]
			continuous = continuous and absf(walker.movement.length() - walker.speed * 0.05) < 0.001
			var displacement: Vector2 = walker.position - before[j]
			if absf(displacement.x) > 1000:
				crossings[j] += 1
				hidden_recycling = hidden_recycling and ((before[j].x > 1636 and walker.position.x < -100) or (before[j].x < -100 and walker.position.x > 1636))
			else:
				same_heading = same_heading and displacement.dot(walker.direction) > 0
	check(continuous, "Every active pedestrian keeps a constant stride without endpoint pauses")
	check(same_heading, "Pedestrians never reverse their route while crossing the street")
	check(hidden_recycling, "Pedestrian exit and re-entry occur with the whole body beyond the scene edges")
	check(crossings.all(func(count): return count >= 2), "Every pedestrian walks off the scene repeatedly in both travel directions")
	var bounded := true
	for walker in street.walkers:
		if walker.position.y > 500 and walker.position.y < 800:
			bounded = false
	for vehicle in street.vehicles:
		bounded = bounded and vehicle.x >= Activity.START_X and vehicle.x < Activity.END_X
	check(bounded and street.vehicles.size() == 5 and street.walkers.size() == 6, "Long running ambience stays on assigned paths with fixed actor counts")
	var fractional = Activity.new()
	var regular = Activity.new()
	for i in range(100): regular.advance(0.1, Vector2(800, 880))
	for i in range(200): fractional.advance(0.05, Vector2(800, 880))
	check(absf(regular.vehicles[0].x - fractional.vehicles[0].x) < 0.1, "Unblocked traffic speed is independent of frame rate")
	check(regular.walkers[0].position.distance_to(fractional.walkers[0].position) < 0.1, "Pedestrian travel speed is independent of frame rate")
	street.configure({"quality": "Low", "distance": 0, "effects": true})
	var inactive_position: Vector2 = street.walkers[1].position
	street.advance(0.1, Vector2(800, 880))
	check(street.walkers[1].position == inactive_position and street.walkers[1].movement == Vector2.ZERO, "Reducing crowd density freezes hidden pedestrians and clears their stride")
	street.configure({"quality": "High", "distance": 2, "effects": true})
	street.advance(0.1, Vector2(800, 880))
	check(street.walkers[1].position.distance_to(inactive_position) < 6 and street.walkers[1].movement.x < 0, "Restoring crowd density resumes the same route without a jump or turn")
	var exits := ["leave", "repair", "poll"]
	var valid := true
	for key in Dialogue.PARK:
		var pending: Array = [key]
		var visited: Array = []
		var can_exit := false
		while not pending.is_empty():
			var page: String = pending.pop_front()
			if page in exits:
				can_exit = true
				continue
			if page in visited: continue
			visited.append(page)
			if not Dialogue.PARK.has(page):
				valid = false
				continue
			for choice in Dialogue.PARK[page].choices: pending.append(choice[1])
		valid = valid and can_exit
	check(valid, "Every park dialogue branch has valid links and an exit")
	var texture: Texture2D = load("res://assets/street-life-atlas.png")
	var image: Image = texture.get_image()
	print("Atlas alpha at corner: ", image.get_pixel(0, 0).a, "; between sprites: ", image.get_pixel(40, 450).a)
	check(image.get_pixel(0, 0).a == 0 and image.get_pixel(40, 450).a == 0, "Generated street atlas has a transparent backdrop")
	print("Street activity: %s checks, %s failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
