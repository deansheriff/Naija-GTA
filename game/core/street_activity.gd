extends RefCounted
## Client-side ambience only. This model cannot award money or change cloud progress.

const START_X = -240.0
const END_X = 1776.0
const ROAD_SLOPE = 0.045
var vehicles: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var dogs: Array[Dictionary] = []
var elapsed := 0.0
var traffic_count := 3
var walker_count := 3
var dog_count := 2
var bird_count := 2
var moving := true
var road_slope := ROAD_SLOPE
var layout: RefCounted
var wrap_agents := true

func _init() -> void:
	for item in [[0, 410.0, 1, 86.0, 0, 270.0], [1, 1200.0, -1, 108.0, 1, 240.0], [2, -170.0, 1, 94.0, 0, 165.0], [1, 1640.0, 1, 86.0, 0, 240.0], [2, 200.0, -1, 108.0, 1, 165.0]]:
		vehicles.append({"kind": item[0], "x": item[1], "direction": item[2], "speed": item[3], "lane": item[4], "width": item[5], "stopped": false})
	# Full-width pavement routes, staggered in both directions. The 240-unit
	# margins keep the whole sprite outside the clipped street during recycling.
	var routes = [
		[Vector2(320, 466), 1, 0.025],
		[Vector2(925, 481), -1, 0.025],
		[Vector2(760, 932), 1, 0.014],
		[Vector2(305, 940), -1, 0.014],
		[Vector2(650, 483), 1, 0.025],
		[Vector2(1150, 922), -1, 0.014],
	]
	for i in range(routes.size()):
		var origin: Vector2 = routes[i][0]
		var slope: float = routes[i][2]
		walkers.append({"position": origin, "base_y": origin.y - origin.x * slope, "slope": slope, "speed": 39.0 + i * 3, "direction": Vector2(routes[i][1], slope * routes[i][1]).normalized(), "movement": Vector2.ZERO, "lane_offset": 0.0})
	for path in [[Vector2(800, 715), Vector2(930, 713), Vector2(995, 799), Vector2(825, 760)], [Vector2(545, 466), Vector2(667, 477), Vector2(918, 478), Vector2(680, 462)]]:
		dogs.append({"position": path[0], "path": path, "target": 1, "pause": 2.0, "speed": 44.0, "direction": Vector2.ZERO})

func apply_layout(district: RefCounted) -> void:
	layout = district
	road_slope = district.road_slope
	if is_zero_approx(road_slope):
		for i in [0, 1, 4]:
			walkers[i].base_y = {0: 466.0, 1: 472.0, 4: 478.0}[i]
			walkers[i].slope = 0.0
			walkers[i].position.y = walkers[i].base_y
			walkers[i].direction = Vector2(signf(walkers[i].direction.x), 0)

func configure(settings: Dictionary) -> void:
	var tier: int = 0 if settings.quality == "Low" else 1 if settings.quality == "Medium" else 2
	traffic_count = [1, 3, 5][tier]
	walker_count = mini([1, 3, 6][tier], [1, 3, 6][int(settings.distance)])
	dog_count = [1, 2, 2][tier]
	bird_count = [1, 2, 3][tier]
	moving = bool(settings.effects)

func vehicle_position(vehicle: Dictionary) -> Vector2:
	return Vector2(vehicle.x, (538.0 if vehicle.lane == 0 else 603.0) + (vehicle.x - 768.0) * road_slope)

func bird_position(index: int) -> Vector2:
	var along: float = elapsed * (90.0 + index * 8.0) + index * 620.0
	if wrap_agents: along = fposmod(along, 1816.0)
	along -= 140.0
	return Vector2(1536.0 - along if index == 1 else along, 565.0 + index * 70.0 + sin(elapsed * 0.4 + index) * 32.0)

func gust_strength() -> float:
	var phase: float = fposmod(elapsed + 1.0, 19.0)
	return pow(sin(phase / 5.0 * PI), 2) if phase < 5.0 else 0.0

func advance(delta: float, player: Vector2) -> void:
	# Clear stride input even when animation is disabled or density is reduced.
	for walker in walkers: walker.movement = Vector2.ZERO
	if not moving:
		return
	# Limit a resumed-tab jump; ambience has no offline completion/reward semantics.
	var step := minf(delta, 0.1)
	elapsed += step
	var positions: Array[float] = []
	for vehicle in vehicles:
		positions.append(vehicle.x)
	for i in range(traffic_count):
		var vehicle: Dictionary = vehicles[i]
		var front: float = (player.x - vehicle.x) * vehicle.direction
		var stop_distance: float = vehicle.width / 2.0 + 52.0
		var stopped: bool = front > -vehicle.width / 2.0 and front < stop_distance and absf(player.y - vehicle_position(vehicle).y) < 38.0
		for j in range(traffic_count):
			if j == i or vehicles[j].lane != vehicle.lane:
				continue
			var gap: float = (positions[j] - positions[i]) * vehicle.direction
			if wrap_agents: gap = fposmod(gap, END_X - START_X)
			if gap >= 0 and gap < (vehicle.width + vehicles[j].width) / 2.0 + 38.0:
				stopped = true
		vehicle.stopped = stopped
		if not stopped:
			var next_x: float = vehicle.x + step * vehicle.speed * vehicle.direction
			vehicle.x = START_X + fposmod(next_x - START_X, END_X - START_X) if wrap_agents else next_x
	for i in range(walker_count):
		var walker: Dictionary = walkers[i]
		walker.movement = walker.direction * step * walker.speed
		var x: float = walker.position.x + walker.movement.x
		if wrap_agents: x = START_X + fposmod(x - START_X, END_X - START_X)
		var lane_y: float = walker.base_y + x * walker.slope
		var desired_offset := 0.0
		var ahead: float = (player.x - walker.position.x) * signf(walker.direction.x)
		if layout != null and ahead > -15 and ahead < 65 and absf(player.y - lane_y) < 30:
			for side in [-1, 1] if player.y >= lane_y else [1, -1]:
				var candidate := Vector2(x, lane_y + side * 36)
				var ahead_clear := Vector2(x + signf(walker.direction.x) * 200, candidate.y + signf(walker.direction.x) * 200 * walker.slope)
				if layout.walkable(candidate) and not layout.on_main_road(candidate) and layout.clear_segment(candidate, ahead_clear):
					desired_offset = side * 36
					break
		var previous_offset: float = walker.lane_offset
		walker.lane_offset = move_toward(walker.lane_offset, desired_offset, step * 70)
		var next := Vector2(x, lane_y + walker.lane_offset)
		if layout != null and desired_offset != 0 and not layout.walkable(next):
			walker.lane_offset = previous_offset
			next.y = lane_y + previous_offset
		walker.movement.y += walker.lane_offset - previous_offset
		walker.position = next
	for i in range(dog_count):
		if dogs[i].position.distance_to(player) < 36:
			dogs[i].direction = Vector2.ZERO
		else:
			_advance_walker(dogs[i], step, 3.0)

func _advance_walker(walker: Dictionary, step: float, pause: float) -> void:
	walker.direction = Vector2.ZERO
	if walker.pause > 0:
		walker.pause -= step
		return
	var offset: Vector2 = walker.path[walker.target] - walker.position
	if offset.length() < 2:
		walker.target = (walker.target + 1) % walker.path.size()
		walker.pause = pause
	else:
		walker.direction = offset.normalized()
		var next: Vector2 = walker.position + walker.direction * minf(step * walker.speed, offset.length())
		if layout != null and (layout.on_main_road(next) or not layout.walkable(next)):
			walker.direction = Vector2.ZERO
			walker.target = (walker.target + 1) % walker.path.size()
			walker.pause = 0.3
		else:
			walker.position = next
