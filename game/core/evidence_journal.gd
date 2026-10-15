extends RefCounted
const Receipt = preload("res://core/receipt_task.gd")
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/evidence-journal.json"))
static func available(c: Dictionary) -> bool:
	return c.get("mission") == "A14" or "A14" in c.get("completed", [])
static func restore_earned(c: Dictionary) -> void:
	for id in earned(c):
		if not id in c.evidence: c.evidence.append(id)
static func earned(c: Dictionary, mission: String = "") -> Array:
	var result: Array = []
	for entry in catalogue().entries:
		if not mission.is_empty() and entry.mission != mission: continue
		if not entry.mission in c.completed: continue
		if entry.has("requiresChoice") and c.choices.get(entry.requiresChoice.id) != entry.requiresChoice.value: continue
		if entry.get("requiresWitnessReview", false) and not Receipt.has_witness_consent(c): continue
		result.append(entry.id)
	return result
static func status(c: Dictionary) -> Dictionary:
	var labels: Dictionary = catalogue().states
	var admitted: bool = c.choices.get("A13-disclose") == "admit" or c.choices.get("A14-disclosure") == "tell"
	var disclosure: String = labels.disclosure_admitted if admitted else labels.disclosure_open if c.choices.get("A13-disclose") == "defer" or c.choices.get("A14-disclosure") == "later" else labels.disclosure_none
	var custody: String = labels.custody_ngozi_record if c.choices.get("A14-custody") == "ngozi_record" else labels.custody_joint_record if c.choices.get("A14-custody") == "joint_record" else labels.custody_none
	var pact: String = labels.pact_protect if c.choices.get("A14-pact") == "protect" else labels.pact_public_case if c.choices.get("A14-pact") == "public_case" else labels.pact_none
	return {"disclosure": disclosure, "custody": custody, "pact": pact}
