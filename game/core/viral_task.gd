extends RefCounted
const Receipt = preload("res://core/receipt_task.gd")
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/viral-task.json"))
static func fresh() -> Dictionary:
	return {"rumour": Receipt.fresh(), "correction": Receipt.fresh()}
static func inputs(phase: String) -> Array:
	var result: Array = []
	var board: Dictionary = catalogue()[phase]
	for q in board.questions:
		for option in q.options: result.append(q.id + ":" + option.id)
	for action in board.actions: result.append(action.id)
	return result
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result := fresh()
	for phase in result:
		var task: Variant = value.get(phase)
		if not task is Dictionary or not task.get("answers") is Dictionary or not (task.get("attempts") is int or task.get("attempts") is float): return {}
		var correct := true
		for q in catalogue()[phase].questions:
			for option in q.options:
				if task.answers.get(q.id) == option.id: result[phase].answers[q.id] = option.id
				if option.correct and task.answers.get(q.id) != option.id: correct = false
		result[phase].attempts = clampi(int(task.attempts), 0, 100000)
		result[phase].ready = task.get("ready") == true and correct and result[phase].attempts > 0
		result[phase].hint = str(task.get("hint", "")).left(400)
	return result
static func advance(v: Dictionary, input: String, phase: String) -> void:
	var board: Dictionary = catalogue()[phase]
	var task: Dictionary = v[phase]
	if task.ready: return
	if input == "assist":
		for q in board.questions:
			for option in q.options:
				if option.correct: task.answers[q.id] = option.id
		task.hint = board.messages.guided
		return
	if input == "check":
		task.attempts = mini(100000, task.attempts + 1)
		task.ready = true
		for q in board.questions:
			for option in q.options:
				if option.correct and task.answers.get(q.id) != option.id: task.ready = false
		task.hint = board.messages.ready if task.ready else board.messages.correction
		return
	var parts := input.split(":")
	if parts.size() != 2: return
	for q in board.questions:
		for option in q.options:
			if q.id == parts[0] and option.id == parts[1]:
				task.answers[q.id] = option.id
				task.hint = board.messages.selected
static func publication(c: Dictionary) -> Dictionary:
	var data := catalogue()
	var witness: bool = c.choices.get("A27-route") == "witness" and c.choices.get("A27-permission") == "retain" and Receipt.has_witness_consent(c)
	return {"route": "witness" if witness else "documents", "disclosure": data.disclosure, "scope": data.status.witness if witness else data.status.withdrawn if c.choices.get("A27-permission") == "withdraw" or c.choices.get("A27-withdrawn") == "yes" else data.status.documents, "lines": [Receipt.catalogue().witnessText] if witness else data.documents.duplicate()}
