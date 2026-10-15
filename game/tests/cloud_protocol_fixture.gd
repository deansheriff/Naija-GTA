extends "res://core/cloud.gd"
var calls: Array = []
var responses: Array = []
var writes := 0
var applies := 0
func _persist() -> bool:
	writes += 1
	return true
func _request(path: String, method: int, body: Dictionary = {}, key: String = "") -> Dictionary:
	calls.append({"path": path, "method": method, "body": body.duplicate(true), "key": key})
	return responses.pop_front() if not responses.is_empty() else {"ok": false, "code": 503, "payload": {}, "message": "Disposable unavailable response"}
func _apply(payload: Dictionary) -> void:
	applies += 1
	if payload.get("campaign") is Dictionary: sim.data.campaign = payload.campaign.duplicate(true)
	revision = int(payload.get("revision", revision))
	connected = true
	changed.emit()
