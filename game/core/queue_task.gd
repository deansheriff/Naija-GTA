extends RefCounted
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/queue-task.json"))
static func fresh() -> Dictionary:
	return {"order": catalogue().initialOrder.duplicate(), "duplicateResolved": false, "lineReady": false, "bucketUpright": false, "aisleClear": false, "resetReady": false, "checks": 0, "hint": ""}
static func inputs(phase: String) -> Array:
	var data := catalogue()
	var result: Array = []
	if phase == "line":
		for party in data.parties:
			result.append("earlier:" + party.id)
			result.append("later:" + party.id)
	for action in data.lineActions if phase == "line" else data.resetActions: result.append(action.id)
	return result
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("order") is Array or value.order.size() != 3: return {}
	for id in catalogue().order:
		if value.order.count(id) != 1: return {}
	if not (value.get("checks") is int or value.get("checks") is float): return {}
	var q := fresh()
	q.order = value.order.duplicate()
	for key in ["duplicateResolved", "bucketUpright", "aisleClear"]: q[key] = value.get(key, false) == true
	q.checks = clampi(int(value.checks), 0, 100000)
	q.lineReady = value.get("lineReady", false) == true and q.duplicateResolved and q.order == catalogue().order and q.checks > 0
	q.resetReady = value.get("resetReady", false) == true and q.bucketUpright and q.aisleClear and q.checks > 0
	q.hint = str(value.get("hint", "")).left(400)
	return q
static func advance(q: Dictionary, input: String, phase: String) -> void:
	var data := catalogue()
	if phase == "line":
		if q.lineReady: return
		if input == "check":
			q.checks = mini(100000, q.checks + 1)
			q.lineReady = q.duplicateResolved and q.order == data.order
			q.hint = data.messages.lineReady if q.lineReady else data.messages.lineCorrection
			return
		if input == "assist":
			q.order = data.order.duplicate()
			q.duplicateResolved = true
			q.hint = data.messages.guided
			return
		if input == "verify":
			q.duplicateResolved = true
			q.hint = data.messages.verified
			return
		var parts := input.split(":")
		if parts.size() != 2: return
		var index: int = q.order.find(parts[1])
		var next: int = index + (-1 if parts[0] == "earlier" else 1)
		if index < 0 or next < 0 or next >= q.order.size():
			q.hint = data.messages.edge
			return
		var other: String = q.order[next]
		q.order[next] = q.order[index]
		q.order[index] = other
		q.hint = data.messages.moved
		return
	if q.resetReady: return
	if input == "check":
		q.checks = mini(100000, q.checks + 1)
		q.resetReady = q.bucketUpright and q.aisleClear
		q.hint = data.messages.resetReady if q.resetReady else data.messages.resetCorrection
	elif input == "assist":
		q.bucketUpright = true
		q.aisleClear = true
		q.hint = data.messages.resetGuided
	elif input == "bucket":
		q.bucketUpright = true
		q.hint = data.messages.bucket
	elif input == "aisle":
		if not q.bucketUpright:
			q.hint = data.messages.bucketFirst
			return
		q.aisleClear = true
		q.hint = data.messages.aisle
