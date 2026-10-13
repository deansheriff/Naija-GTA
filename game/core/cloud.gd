extends Node
## Intent-only server adapter. Local coin totals are never uploaded.
signal changed
signal notice(message: String)
const PATH = "user://cloud-connection-v1.json"
var sim
var base_url := ""
var token := ""
var recovery_code := ""
var revision := 0
var pending: Dictionary = {}
var busy := false
var connected := false
var status := "Local play"
var poll_time := 0.0

func enabled() -> bool:
	return not base_url.is_empty()

func _ready() -> void:
	var raw := ""
	if OS.has_feature("web"):
		raw = str(JavaScriptBridge.get_interface("NSLPrivateStore").read())
	elif FileAccess.file_exists(PATH):
		raw = FileAccess.get_file_as_string(PATH)
	var saved: Variant = JSON.parse_string(raw) if not raw.is_empty() else null
	if saved is Dictionary:
		base_url = str(saved.get("url", ""))
		token = str(saved.get("token", ""))
		recovery_code = str(saved.get("code", ""))
		if saved.get("pending") is Dictionary:
			pending = saved.pending
	if OS.has_feature("web"):
		var hosted: Variant = JavaScriptBridge.get_interface("window").NSLCloudURL
		if hosted is String and not hosted.is_empty() and hosted != base_url:
			base_url = hosted
			token = ""
			recovery_code = ""
			pending = {}
	if enabled():
		call_deferred("connect_save")

func _process(delta: float) -> void:
	if not enabled() or busy:
		return
	poll_time += delta
	if poll_time >= 5:
		poll_time = 0
		if not token.is_empty():
			if not pending.is_empty():
				retry_pending()
			elif connected:
				submit("sync")
			else:
				refresh()

func _persist() -> bool:
	var payload := JSON.stringify({"url": base_url, "token": token, "code": recovery_code, "pending": pending})
	if OS.has_feature("web"):
		return JavaScriptBridge.get_interface("NSLPrivateStore").write(payload)
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.close()
	return DirAccess.rename_absolute(PATH + ".tmp", PATH) == OK

func _request(path: String, method: int, body: Dictionary = {}, key: String = "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 12
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	if not key.is_empty(): headers.append("Idempotency-Key: " + key)
	var error := request.request(base_url + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		request.queue_free()
		return {"ok": false, "code": 0, "message": "Connection unavailable. Your pending action is kept for retry."}
	var response: Array = await request.request_completed
	request.queue_free()
	var payload: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if not payload is Dictionary:
		payload = {}
	var valid := payload.get("character") is Dictionary and payload.character.get("state") is Dictionary
	return {"ok": response[0] == HTTPRequest.RESULT_SUCCESS and response[1] >= 200 and response[1] < 300 and valid, "code": response[1], "payload": payload, "message": payload.get("message", "Connection unavailable or this URL is not the game server. Your pending action is kept for retry.")}

func configure(url: String, code: String = "") -> void:
	if busy:
		notice.emit("Wait for the current connection request.")
		return
	var normalized := url.strip_edges().trim_suffix("/")
	if not normalized.begins_with("https://") and not normalized.begins_with("http://127.0.0.1:") and not normalized.begins_with("http://localhost:"):
		notice.emit("Use your game's HTTPS URL, or localhost for development.")
		return
	if not normalized.ends_with("/api"): normalized += "/api"
	if OS.has_feature("web") and normalized != str(JavaScriptBridge.get_interface("window").location.origin) + "/api":
		notice.emit("Open that game address in your browser to use its server.")
		return
	if normalized == base_url and code.strip_edges().is_empty() and not token.is_empty():
		connect_save()
		return
	if not pending.is_empty():
		notice.emit("Retry your pending action before changing saves.")
		return
	base_url = normalized
	token = ""
	recovery_code = code.strip_edges()
	connected = false
	_persist()
	connect_save()

func connect_save() -> void:
	if busy or not enabled(): return
	busy = true
	status = "Connecting…"
	changed.emit()
	var result: Dictionary
	if not token.is_empty():
		result = await _request("/v1/me", HTTPClient.METHOD_GET)
		if result.code == 401 and not recovery_code.is_empty():
			token = ""
			result = await _request("/v1/sessions", HTTPClient.METHOD_POST, {"recoveryCode": recovery_code})
	elif not recovery_code.is_empty():
		result = await _request("/v1/sessions", HTTPClient.METHOD_POST, {"recoveryCode": recovery_code})
	else:
		result = await _request("/v1/guests", HTTPClient.METHOD_POST)
	if result.ok:
		token = result.payload.get("token", token)
		recovery_code = result.payload.get("recoveryCode", recovery_code)
		if not _persist(): notice.emit("Keep your save access code: this device cannot store the session.")
		_apply(result.payload)
		notice.emit("Cloud save connected. Local prototype progress stays separate.")
	else:
		connected = false
		status = "Offline · reconnect"
		notice.emit(result.message)
	busy = false
	changed.emit()

func _apply(payload: Dictionary) -> void:
	var character: Dictionary = payload.character
	revision = int(character.revision)
	var state: Dictionary = character.state.duplicate(true)
	var active: Variant = state.get("active")
	if active is Dictionary:
		var remaining := maxf(0, (float(active.endsAt) - float(payload.get("serverTime", state.updatedAt))) / 1000.0)
		state.active = {"code": active.code, "remaining": remaining, "total": sim.ACTIONS[active.code].seconds}
	else:
		state.active = {}
	# The save loader is schema-aware. No offline award/catch-up occurs for server snapshots.
	state.erase("last_saved")
	var settings: Dictionary = sim.data.settings.duplicate(true)
	sim.reset()
	sim.load_json(JSON.stringify({"version": sim.VERSION, "state": state}), false)
	sim.data.settings = settings
	connected = true
	status = "Cloud save connected"
	changed.emit()

func refresh() -> void:
	if busy or token.is_empty(): return
	busy = true
	var result := await _request("/v1/me", HTTPClient.METHOD_GET)
	if result.ok:
		_apply(result.payload)
	else:
		connected = false
		status = "Offline · reconnect"
	busy = false
	changed.emit()

func submit(kind: String, args: Dictionary = {}) -> Dictionary:
	if busy or not pending.is_empty(): return {"ok": false, "message": "An action is waiting. Let it finish or retry it in Cloud save."}
	if not connected: return {"ok": false, "message": "Reconnect your cloud save before starting an activity."}
	var crypto := Crypto.new()
	pending = {"key": crypto.generate_random_bytes(16).hex_encode(), "body": args.duplicate(true)}
	pending.body.kind = kind
	pending.body.revision = revision
	if not _persist():
		pending = {}
		return {"ok": false, "message": "Device storage is unavailable. No action was sent."}
	return await retry_pending()

func retry_pending() -> Dictionary:
	if busy or pending.is_empty(): return {"ok": false, "message": "No action ready for retry."}
	busy = true
	var result := await _request("/v1/intents", HTTPClient.METHOD_POST, pending.body, pending.key)
	if result.ok:
		pending = {}
		_persist()
		_apply(result.payload)
		result.message = "Cloud progress saved."
	elif result.code >= 400 and result.code < 500 and result.code != 429:
		pending = {}
		_persist()
		if result.code == 409:
			var latest := await _request("/v1/me", HTTPClient.METHOD_GET)
			if latest.ok: _apply(latest.payload)
			result.message = "Another device changed this save. Progress refreshed; choose your action again."
	else:
		connected = false
		status = "Offline · action kept for retry"
	busy = false
	changed.emit()
	return result
