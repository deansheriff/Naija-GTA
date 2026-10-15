extends RefCounted
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/receipt-task.json"))
static func inputs() -> Array:
	var result: Array = []
	for q in catalogue().questions:
		for option in q.options: result.append(q.id + ":" + option.id)
	for action in catalogue().actions: result.append(action.id)
	return result
static func fresh() -> Dictionary:
	return {"answers": {}, "attempts": 0, "ready": false, "hint": ""}
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("answers") is Dictionary: return {}
	if not (value.get("attempts") is int or value.get("attempts") is float): return {}
	var result := fresh()
	var consistent := true
	for q in catalogue().questions:
		for option in q.options:
			if value.answers.get(q.id) == option.id: result.answers[q.id] = option.id
			if option.correct and value.answers.get(q.id) != option.id: consistent = false
	result.attempts = clampi(int(value.attempts), 0, 100000)
	result.ready = value.get("ready", false) == true and consistent and result.attempts > 0
	result.hint = str(value.get("hint", "")).left(400)
	return result
static func has_witness_consent(c: Dictionary) -> bool:
	var consent: Variant = c.get("witnessConsent")
	return c.get("choices", {}).get("A24-consent") == "redacted_review" and c.get("choices", {}).get("A25-public_review") == "approve_ne1" and consent is Dictionary and consent.get("active") == true and consent.get("scope") == "redacted_text" and consent.get("textHash") == str(catalogue().witnessText).sha256_text()
static func advance(task: Dictionary, input: String) -> void:
	var data := catalogue()
	if task.ready: return
	if input == "assist":
		for q in data.questions:
			for option in q.options:
				if option.correct: task.answers[q.id] = option.id
		task.hint = data.messages.guided
		return
	if input == "check":
		task.attempts = mini(100000, task.attempts + 1)
		task.ready = true
		for q in data.questions:
			for option in q.options:
				if option.correct and task.answers.get(q.id) != option.id: task.ready = false
		task.hint = data.messages.ready if task.ready else data.messages.correction
		return
	var parts := input.split(":")
	if parts.size() != 2: return
	for q in data.questions:
		for option in q.options:
			if q.id == parts[0] and option.id == parts[1]:
				task.answers[q.id] = option.id
				task.hint = data.messages.selected
