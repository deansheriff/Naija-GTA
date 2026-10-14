extends RefCounted
## Cosmetic daily schedules. Clock snapshots never grant progress or currency.

var layout: RefCounted
var agents: Dictionary = {}
var minutes := 480.0

func _init(district: RefCounted) -> void:
	layout = district
	for who in ["amaka", "yemi"]:
		var venue: String = "food" if who == "amaka" else "repair"
		var work: Vector2 = layout.places[venue].position + Vector2(-104, -50)
		agents[who] = {"position": work, "movement": Vector2.ZERO, "route": PackedVector2Array(), "phase": "work", "work": work,
			"break": Vector2(layout.places[venue].position.x + 110, 465), "edge": Vector2(120 if who == "amaka" else 1420, 465),
			"home": Vector2(-160 if who == "amaka" else 1696, 465), "initialized": false}

static func phase_at(who: String, time: float) -> String:
	var minute := fposmod(time, 1440.0)
	var closing := 1200.0 if who == "amaka" else 1140.0
	if minute < 360 or minute >= closing: return "home"
	var tea := 510.0 if who == "amaka" else 525.0
	var lunch := 720.0 if who == "amaka" else 735.0
	if (minute >= tea and minute < 540) or (minute >= lunch and minute < lunch + 60): return "break"
	return "work"

func _route(agent: Dictionary, target: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	var start: Vector2 = agent.position
	if not layout.WALK_BOUNDS.has_point(start):
		result.append(agent.edge)
		start = agent.edge
	var end: Vector2 = agent.edge if target == "home" else agent[target]
	result.append_array(layout.route(start, end))
	if target == "home": result.append(agent.home)
	return result

func advance(delta: float, paused: bool = false) -> void:
	for who in agents:
		var agent: Dictionary = agents[who]
		agent.movement = Vector2.ZERO
		var target := phase_at(who, minutes)
		if not agent.initialized:
			agent.position = agent[target]
			agent.phase = target
			agent.initialized = true
		if paused: continue
		if target != agent.phase:
			agent.phase = target
			agent.route = _route(agent, target)
		var previous: Vector2 = agent.position
		var remaining := minf(delta, 0.1) * 64.0
		while remaining > 0 and not agent.route.is_empty():
			var point: Vector2 = agent.route[0]
			var distance: float = agent.position.distance_to(point)
			if distance <= remaining:
				agent.position = point
				agent.route.remove_at(0)
				remaining -= distance
			else:
				agent.position = agent.position.move_toward(point, remaining)
				remaining = 0
		agent.movement = agent.position - previous

func status(who: String) -> String:
	var agent: Dictionary = agents[who]
	if not agent.route.is_empty(): return "Walking home" if agent.phase == "home" else "Returning to work" if agent.phase == "work" else "Walking to a tea break"
	return {"work": "At the counter", "break": "On a pavement break", "home": "Home for the night"}[agent.phase]
