extends RefCounted
## Versioned seeded geometry shared by drawing, collision and routing.

const VERSION = 2
const SIZE = Vector2(1536, 1024)
const WALK_BOUNDS = Rect2(100, 300, 1340, 660)
const BODY_RADIUS = 14.0
const CELL = 20.0
const BUILDINGS = [
	{"id": "food", "footprint": Rect2(235, 310, 340, 130), "door": Vector2(405, 440), "inside": Vector2(405, 400), "color": "ce784c", "kind": 0},
	{"id": "repair", "footprint": Rect2(610, 310, 340, 130), "door": Vector2(780, 440), "inside": Vector2(780, 400), "color": "568b80", "kind": 1},
	{"id": "home", "footprint": Rect2(1050, 310, 340, 130), "door": Vector2(1220, 440), "inside": Vector2(1220, 400), "color": "c4a873", "kind": 2},
]
const FURNITURE = [
	{"id": "kitchen_counter", "kind": "counter", "rect": Rect2(255, 365, 95, 28)},
	{"id": "repair_bench", "kind": "counter", "rect": Rect2(630, 365, 95, 28)},
	{"id": "home_desk", "kind": "counter", "rect": Rect2(1070, 350, 100, 28)},
	{"id": "square_bench", "kind": "bench", "rect": Rect2(282, 790, 120, 32)},
	{"id": "park_bench", "kind": "bench", "rect": Rect2(470, 842, 120, 32)},
	{"id": "noticeboard", "kind": "board", "rect": Rect2(424, 747, 72, 20)},
]
const TREES = [Vector2(170, 700), Vector2(1440, 750), Vector2(1000, 260), Vector2(70, 1010), Vector2(1480, 1010)]
const PARKED_BUS = Rect2(1080, 740, 280, 82)
var obstacles: Array[Dictionary] = []
var grid := AStarGrid2D.new()
var seed_value := 0
var buildings: Array = []
var furniture: Array = []
var trees: Array = []
var bus_rect := PARKED_BUS
var road_slope := 0.045
var junction_x := -1.0
var junction_width := 90.0
var places: Dictionary = {}
var ground_color := Color("cfbc92")
var grass_color := Color("879b71")

func _init(world_seed: int = 0, flat_road: bool = false, with_navigation: bool = true) -> void:
	seed_value = world_seed
	buildings = BUILDINGS.duplicate(true)
	furniture = FURNITURE.duplicate(true)
	trees = TREES.duplicate()
	if world_seed != 0: _generate(world_seed)
	if flat_road: road_slope = 0.0
	for building in buildings:
		var rect: Rect2 = building.footprint
		_add(building.id + "_back", Rect2(rect.position, Vector2(rect.size.x, 12)))
		_add(building.id + "_left", Rect2(rect.position, Vector2(12, rect.size.y)))
		_add(building.id + "_right", Rect2(rect.end.x - 12, rect.position.y, 12, rect.size.y))
		_add(building.id + "_front_left", Rect2(rect.position.x, rect.end.y - 10, 130, 10))
		_add(building.id + "_front_right", Rect2(rect.end.x - 130, rect.end.y - 10, 130, 10))
	for item in furniture: _add(item.id, item.rect)
	_add("parked_bus", bus_rect)
	for i in range(trees.size()): _add("tree_%s" % i, Rect2(trees[i] - Vector2(12, 8), Vector2(24, 16)))
	for building in buildings:
		places[building.id] = {"position": building.inside, "name": ["Amaka's kitchen", "Yemi's workshop", "Your little corner"][building.kind] if world_seed == 0 else ["Corner canteen", "Repair stall", "Courtyard flat"][building.kind]}
	var square_position := Vector2(430, 785) if world_seed == 0 else Vector2(furniture[5].rect.get_center().x, furniture[5].rect.end.y + 40)
	places.square = {"position": square_position, "name": "Community square"}
	places.park = {"position": Vector2(725, 882), "name": "Park crew" if world_seed == 0 else "Shaded square"}
	places.bus = {"position": Vector2(bus_rect.position.x - 45, 870), "name": "Danfo stop"}
	if not with_navigation: return
	grid.region = Rect2i(0, 0, 78, 52)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			grid.set_point_solid(Vector2i(x, y), not walkable(Vector2(x, y) * CELL))

func _generate(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var order := [0, 1, 2]
	for i in range(2, 0, -1):
		var swap: int = rng.randi_range(0, i)
		var old: int = order[i]
		order[i] = order[swap]
		order[swap] = old
	var centers := [300.0, 805.0, 1240.0]
	for slot in range(3):
		var building: Dictionary = buildings[order[slot]]
		var center: float = centers[slot] + rng.randi_range(-15, 15)
		building.footprint = Rect2(center - 170, 310, 340, 130)
		building.door = Vector2(center, 440)
		building.inside = Vector2(center, 400)
		furniture[building.kind].rect.position.x = center - 150
	# A reserved gap between lots creates a connected northbound T junction.
	# Its pavement crossing stays clear of buildings, trees and shop thresholds.
	junction_x = 550.0 + rng.randi_range(-5, 5)
	road_slope = 0.0
	trees[0].x = rng.randi_range(145, 190)
	trees[1].x = rng.randi_range(1408, 1450)
	trees[2] = Vector2(1008 + rng.randi_range(-12, 12), 255)
	trees[3].x = rng.randi_range(48, 82)
	trees[4].x = rng.randi_range(1460, 1496)
	# Furniture stays in reserved park lots, outside the through-pedestrian lanes.
	furniture[3].rect.position.x += rng.randi_range(-15, 15)
	furniture[4].rect.position.x += rng.randi_range(-15, 15)
	ground_color = [Color("cfbc92"), Color("c7bb96"), Color("d1bf9c")][rng.randi_range(0, 2)]
	grass_color = [Color("879b71"), Color("7c9570"), Color("8b9d79")][rng.randi_range(0, 2)]

func on_main_road(point: Vector2) -> bool:
	return point.y >= 486 + point.x * road_slope and point.y <= 655 + point.x * road_slope

func road_modules() -> Array:
	var result := [{"kind": "through", "from": Vector2(0, 570), "to": Vector2(SIZE.x, 570 + SIZE.x * road_slope)}]
	if junction_x >= 0: result.append({"kind": "junction", "from": Vector2(junction_x, 0), "to": Vector2(junction_x, 570)})
	return result

func _add(id: String, rect: Rect2) -> void:
	obstacles.append({"id": id, "rect": rect})

func walkable(point: Vector2) -> bool:
	if not WALK_BOUNDS.has_point(point): return false
	for obstacle in obstacles:
		if obstacle.rect.grow(BODY_RADIUS).has_point(point): return false
	return true

func clear_segment(from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1, ceili(from.distance_to(to) / 4.0))
	for i in range(steps + 1):
		if not walkable(from.lerp(to, float(i) / steps)): return false
	return true

func move(from: Vector2, displacement: Vector2) -> Vector2:
	# Swept small steps prevent tunneling, including a slow/resumed frame.
	var steps: int = maxi(1, ceili(displacement.length() / 4.0))
	var step := displacement / steps
	var result := from
	for i in range(steps):
		if walkable(result + step):
			result += step
		else:
			if walkable(result + Vector2(step.x, 0)): result.x += step.x
			if walkable(result + Vector2(0, step.y)): result.y += step.y
	return result

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not walkable(from) or not walkable(to): return PackedVector2Array()
	if clear_segment(from, to): return PackedVector2Array([to])
	var start := _nearest_cell(from)
	var finish := _nearest_cell(to)
	if start.x < 0 or finish.x < 0: return PackedVector2Array()
	var path := grid.get_point_path(start, finish)
	if path.is_empty(): return path
	# Verify the exact click/venue endpoints as well as the grid points.
	if not clear_segment(from, path[0]) or not clear_segment(path[path.size() - 1], to): return PackedVector2Array()
	path.append(to)
	var smooth := PackedVector2Array()
	var anchor := from
	var index := 0
	while index < path.size():
		var next := index
		while next + 1 < path.size() and clear_segment(anchor, path[next + 1]): next += 1
		smooth.append(path[next])
		anchor = path[next]
		index = next + 1
	return smooth

func _nearest_cell(point: Vector2) -> Vector2i:
	var center := Vector2i(roundi(point.x / CELL), roundi(point.y / CELL))
	var result := Vector2i(-1, -1)
	var distance := INF
	for y in range(center.y - 2, center.y + 3):
		for x in range(center.x - 2, center.x + 3):
			var cell := Vector2i(x, y)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
			var candidate := Vector2(cell) * CELL
			var gap := point.distance_squared_to(candidate)
			if gap < distance and clear_segment(point, candidate):
				result = cell
				distance = gap
	return result

func interior_at(point: Vector2) -> String:
	for building in buildings:
		if building.footprint.has_point(point): return building.id
	return ""
