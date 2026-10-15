extends RefCounted
const INPUTS = ["accelerate", "brake", "coast", "upper", "lower", "assist", "yield"]
static func chase_catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/chase-driving.json"))
static func fresh(now: int) -> Dictionary:
	return {"distance": 0.0, "speed": 0.0, "lane": 1, "lastAt": now, "ready": false, "misses": 0, "hint": ""}
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result := fresh(0)
	for field in ["distance", "speed", "lane", "misses"]:
		if not (value.get(field) is int or value.get(field) is float): return {}
	result.distance = clampf(float(value.distance), 0, 440)
	result.speed = clampf(float(value.speed), 0, 70)
	result.lane = clampi(int(value.lane), 0, 1)
	result.misses = clampi(int(value.misses), 0, 100000)
	result.ready = value.get("ready", false) == true and result.distance >= 310 and result.speed <= 2 and result.lane == 1
	result.hint = str(value.get("hint", "")).left(200)
	if value.has("gateCleared"): result.gateCleared = value.gateCleared == true
	return result
static func advance(drive: Dictionary, input: String, now: int, target: float, gate: Dictionary = {}) -> void:
	var dt := clampf((now - int(drive.lastAt)) / 1000.0, 0, 1) if drive.lastAt > 0 else 0.0
	drive.lastAt = now
	if drive.ready: return
	var waiting: bool = not gate.is_empty() and not drive.get("gateCleared", false)
	var goal: float = float(gate.at) if waiting else target
	if input == "yield":
		if not waiting: return
		if drive.distance >= goal - 30 and drive.distance <= goal and drive.speed <= 2 and drive.lane == 1:
			drive.gateCleared = true
			drive.hint = chase_catalogue().messages.cleared
		else: drive.hint = chase_catalogue().messages.wrongWait
		return
	if input == "upper": drive.lane = 0
	if input == "lower": drive.lane = 1
	var previous: float = drive.speed
	if input == "assist":
		drive.lane = 1
		drive.distance = minf(goal, drive.distance + 50 * dt)
		drive.speed = 0.0 if drive.distance >= goal else 50.0
	else:
		var acceleration := 30 if input == "accelerate" else -60 if input == "brake" else -10
		drive.speed = clampf(drive.speed + acceleration * dt, 0, 70)
		drive.distance += (previous + drive.speed) * 0.5 * dt
	if drive.distance > goal + (0 if waiting else 90):
		var misses: int = drive.misses + 1
		drive.assign(fresh(now))
		drive.misses = misses
		drive.hint = chase_catalogue().messages.loop if waiting else "Missed the bay. Take the free loop; start braking earlier, or use Guided approach."
		if not gate.is_empty(): drive.gateCleared = false
		return
	drive.ready = not waiting and drive.distance >= target - 40 and drive.speed <= 2 and drive.lane == 1
	if waiting and drive.distance >= goal - 30 and drive.speed <= 2 and drive.lane == 1: drive.hint = chase_catalogue().messages.stop
	if drive.ready: drive.hint = "Safe stop. Read the passenger cue and choose your next move."
