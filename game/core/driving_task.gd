extends RefCounted
const INPUTS = ["accelerate", "brake", "coast", "upper", "lower", "assist"]
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
	return result
static func advance(drive: Dictionary, input: String, now: int, target: float) -> void:
	var dt := clampf((now - int(drive.lastAt)) / 1000.0, 0, 1) if drive.lastAt > 0 else 0.0
	drive.lastAt = now
	if drive.ready: return
	if input == "upper": drive.lane = 0
	if input == "lower": drive.lane = 1
	var previous: float = drive.speed
	if input == "assist":
		drive.lane = 1
		drive.distance = minf(target, drive.distance + 50 * dt)
		drive.speed = 0.0 if drive.distance >= target else 50.0
	else:
		var acceleration := 30 if input == "accelerate" else -60 if input == "brake" else -10
		drive.speed = clampf(drive.speed + acceleration * dt, 0, 70)
		drive.distance += (previous + drive.speed) * 0.5 * dt
	if drive.distance > target + 90:
		var misses: int = drive.misses + 1
		drive.assign(fresh(now))
		drive.misses = misses
		drive.hint = "Missed the bay. Take the free loop; start braking earlier, or use Guided approach."
		return
	drive.ready = drive.distance >= target - 40 and drive.speed <= 2 and drive.lane == 1
	if drive.ready: drive.hint = "Safe stop. Read the passenger cue and choose your next move."
