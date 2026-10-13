extends RefCounted
## Guided local transport. Never spends coins or advances a server mission.

const Plan = preload("res://world/world_plan.gd")
const CHUNK_WIDTH = 1536.0
const SPEED = 360.0
const ROAD_Y = 538.0
var origin := 0
var destination := 0
var state := "idle"
var elapsed := 0.0
var phase_time := 0.0
var last_chunk := 0
var position := Vector2(1220, 822)
var drive_end := 0.0
var completed := false

func start(from: int, to: int) -> bool:
	if not Plan.valid(from) or not Plan.valid(to) or from == to or state in ["departing", "cruising", "arriving"]: return false
	origin = from
	destination = to
	last_chunk = 3 + absi(from - to)
	drive_end = last_chunk * CHUNK_WIDTH + 1000
	position = Vector2(1220, 822)
	state = "departing"
	elapsed = 0
	phase_time = 0
	completed = false
	return true

func advance(delta: float) -> bool:
	if state in ["idle", "complete"]: return false
	# Resuming a suspended browser never silently completes a ride.
	var remaining := clampf(delta, 0.0, 0.1)
	elapsed += remaining
	while remaining > 0.000001:
		if state == "departing":
			var step := minf(remaining, 2.0 - phase_time)
			phase_time += step
			remaining -= step
			position = Vector2(1220, 822).lerp(Vector2(1440, ROAD_Y), smoothstep(0, 1, phase_time / 2.0))
			if phase_time >= 2.0:
				state = "cruising"
				phase_time = 0
		elif state == "cruising":
			var step := minf(remaining, maxf(0, drive_end - position.x) / SPEED)
			position = Vector2(minf(drive_end, position.x + step * SPEED), ROAD_Y)
			remaining -= step
			if position.x >= drive_end - 0.001:
				state = "arriving"
				phase_time = 0
		elif state == "arriving":
			var step := minf(remaining, 2.0 - phase_time)
			phase_time += step
			remaining -= step
			position = Vector2(drive_end, ROAD_Y).lerp(Vector2(drive_end + 220, 822), smoothstep(0, 1, phase_time / 2.0))
			if phase_time >= 2.0:
				state = "complete"
				completed = true
				return true
	return false

func skip_to_arrival() -> void:
	if state in ["departing", "cruising"]:
		position = Vector2(drive_end, ROAD_Y)
		state = "arriving"
		phase_time = 0

func progress() -> float:
	return 1.0 if completed else clampf((position.x - 1220) / (drive_end + 220 - 1220), 0, 1)

func visible_chunks() -> Array[int]:
	var index: int = clampi(floori(position.x / CHUNK_WIDTH), 0, last_chunk)
	var result: Array[int] = []
	for offset in [-1, 0, 1]:
		var chunk: int = index + offset
		# One continuation tile beyond the destination keeps arrival edges filled.
		if chunk >= 0 and chunk <= last_chunk + 1: result.append(chunk)
	return result

func seed_for(index: int) -> int:
	return Plan.chunk_seed(origin, destination, index, last_chunk)
