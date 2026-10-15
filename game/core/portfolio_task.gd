extends RefCounted
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/portfolio-task.json"))
static func inputs() -> Array:
	var values: Array = []
	for q in catalogue().questions:
		for option in q.options: values.append(q.id + ":" + option.id)
	for action in catalogue().actions: values.append(action.id)
	return values
static func fresh() -> Dictionary:
	return {"answers": {}, "attempts": 0, "ready": false, "needsRecovery": false, "route": "first", "hint": ""}
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("answers") is Dictionary: return {}
	if not (value.get("attempts") is int or value.get("attempts") is float): return {}
	var p := fresh()
	for q in catalogue().questions:
		for option in q.options:
			if value.answers.get(q.id) == option.id: p.answers[q.id] = option.id
	p.attempts = clampi(int(value.attempts), 0, 100000)
	p.route = value.get("route") if value.get("route") in ["first", "practice", "callback"] else "first"
	var consistent := true
	for q in catalogue().questions:
		for option in q.options:
			if option.correct and p.answers.get(q.id) != option.id: consistent = false
	p.ready = value.get("ready", false) == true and consistent and p.attempts > 0
	p.needsRecovery = value.get("needsRecovery", false) == true and not p.ready
	p.hint = str(value.get("hint", "")).left(300)
	return p
static func advance(p: Dictionary, input: String) -> void:
	var data := catalogue()
	if p.ready: return
	if input in ["practice", "callback"]:
		if not p.needsRecovery:
			p.hint = data.messages.no_recovery
			return
		p.needsRecovery = false
		p.route = input
		p.hint = data.messages[input]
		return
	if p.needsRecovery:
		p.hint = data.messages.recover_first
		return
	if input == "assist":
		for q in data.questions:
			for option in q.options:
				if option.correct: p.answers[q.id] = option.id
		p.hint = data.messages.guided
		return
	if input == "present":
		p.attempts = mini(100000, p.attempts + 1)
		p.ready = true
		for q in data.questions:
			for option in q.options:
				if option.correct and p.answers.get(q.id) != option.id: p.ready = false
		p.needsRecovery = not p.ready
		p.hint = data.messages.ready if p.ready else data.messages.correction
		return
	var parts := input.split(":")
	if parts.size() != 2: return
	for q in data.questions:
		for option in q.options:
			if q.id == parts[0] and option.id == parts[1]:
				p.answers[q.id] = option.id
				p.hint = data.messages.selected
