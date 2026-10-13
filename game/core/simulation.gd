extends RefCounted
## Local prototype rules. Real economy/eligibility moves server-side in Milestone 1.

const VERSION = 1
const ACTIONS = {
	"eat": {"name": "Jollof at Amaka's", "seconds": 6.0, "cost": 25, "food": 35, "energy": 4},
	"learn": {"name": "Practice a repair", "seconds": 8.0, "cost": 0, "energy": -8, "repair": 1},
	"gig": {"name": "Repair Yemi's radio", "seconds": 10.0, "cost": 0, "energy": -12, "coins": 90, "repair": 1},
	"rest": {"name": "Rest at home", "seconds": 8.0, "cost": 0, "energy": 35},
	"wash": {"name": "Freshen up", "seconds": 5.0, "cost": 0, "comfort": 20},
	"study": {"name": "Learn digital skills", "seconds": 8.0, "cost": 0, "energy": -8, "digital": 1},
}

var data: Dictionary = {}
var notice := ""

func _init() -> void:
	reset()

func reset() -> void:
	data = {
		"name": "New neighbor", "bio": "Finding my feet, one small win at a time.",
		"coins": 240, "food": 65.0, "energy": 78.0, "comfort": 70.0,
		"repair": 0, "digital": 0, "social": 0, "met_amaka": false,
		"gig_done": false, "decorated": false, "wall": "sage", "active": {},
		"day": 1, "minutes": 480.0, "posts": [], "vote": "", "last_saved": 0.0,
		"settings": {"quality": "Medium", "shadows": true, "effects": true, "distance": 1,
			"fps": 30, "data_saver": true, "manual": false},
	}

func begin_action(code: String) -> Dictionary:
	if not ACTIONS.has(code):
		return {"ok": false, "message": "That activity is unavailable."}
	if not data.active.is_empty():
		return {"ok": false, "message": "Finish your current activity first."}
	if code == "gig" and data.gig_done:
		return {"ok": false, "message": "Yemi's radio is already repaired."}
	if code == "gig" and data.repair < 1:
		return {"ok": false, "message": "Practice once at the repair bench to unlock this gig."}
	var action: Dictionary = ACTIONS[code]
	if data.coins < action.cost:
		return {"ok": false, "message": "You need %s StreetCoins." % action.cost}
	if action.get("energy", 0) < 0 and data.energy < 15:
		return {"ok": false, "message": "A quick rest at home will help. Energy must be at least 15."}
	data.coins -= action.cost
	data.active = {"code": code, "remaining": action.seconds, "total": action.seconds}
	return {"ok": true, "message": action.name + "…"}

func tick(seconds: float) -> bool:
	seconds = maxf(0.0, seconds)
	data.minutes += seconds * 0.8
	if data.minutes >= 1440:
		data.day += int(data.minutes / 1440)
		data.minutes = fmod(data.minutes, 1440)
	data.food = clampf(data.food - seconds * 0.025, 0, 100)
	data.energy = clampf(data.energy - seconds * 0.015, 0, 100)
	data.comfort = clampf(data.comfort - seconds * 0.01, 0, 100)
	if data.active.is_empty():
		return false
	data.active.remaining -= seconds
	if data.active.remaining > 0:
		return false
	var code: String = data.active.code
	var action: Dictionary = ACTIONS[code]
	# Clear before awarding: repeated ticks cannot pay the same action twice.
	data.active = {}
	for stat in ["food", "energy", "comfort"]:
		data[stat] = clampf(data[stat] + action.get(stat, 0), 0, 100)
	for skill in ["repair", "digital"]:
		data[skill] = mini(100, int(data[skill]) + int(action.get(skill, 0)))
	data.coins += action.get("coins", 0)
	if code == "gig":
		data.gig_done = true
	notice = action.name + " complete" + (" · +90 StreetCoins" if code == "gig" else "")
	return true

func meet_amaka() -> String:
	if not data.met_amaka:
		data.met_amaka = true
		data.social += 1
		return "Amaka: Welcome, neighbor! Yemi needs a hand with his radio. Try his repair bench first."
	return "Amaka: Small steps still take you somewhere. How is your day going?"

func decorate(color: String) -> void:
	if color in ["sage", "clay", "ocean"]:
		data.wall = color
		data.decorated = true

func post_job(title: String, budget: int) -> Dictionary:
	title = title.strip_edges().left(60)
	if title.length() < 5:
		return {"ok": false, "message": "Write a title of at least five characters."}
	if data.posts.size() >= 3:
		return {"ok": false, "message": "This local prototype allows three listings."}
	if budget < 10 or budget > 10000:
		return {"ok": false, "message": "Budget must be 10–10,000 StreetCoins."}
	# Reserve budget separately from the posting charge; no negative balance.
	if data.coins < 100 + budget:
		return {"ok": false, "message": "You need the 100-coin posting fee plus the reserved budget."}
	data.coins -= 100 + budget
	data.posts.append({"id": str(data.posts.size() + 1), "title": title, "budget": budget, "status": "Local draft", "refunded": false})
	return {"ok": true, "message": "Local draft saved. 100-coin fee paid; %s coins reserved." % budget}

func cancel_job(id: String) -> bool:
	for post in data.posts:
		if post.id == id and not post.refunded:
			data.coins += post.budget
			post.refunded = true
			post.status = "Cancelled"
			return true
	return false

func goal() -> Dictionary:
	if not data.met_amaka:
		return {"step": 1, "title": "Meet your neighbor", "body": "Amaka knows this street. Say hello at the food stall.", "place": "food"}
	if data.repair < 1:
		return {"step": 2, "title": "Learn something useful", "body": "Practice at Yemi's repair bench. Everyone starts somewhere.", "place": "repair"}
	if not data.gig_done:
		return {"step": 3, "title": "Your first honest hustle", "body": "Repair Yemi's radio and earn 90 StreetCoins.", "place": "repair"}
	if not data.decorated:
		return {"step": 4, "title": "Make it yours", "body": "Head home and choose an accent color. Your street life has begun.", "place": "home"}
	return {"step": 5, "title": "You belong here", "body": "Explore, grow a skill or share your view at the community square.", "place": "square"}

func save_to(path: String) -> bool:
	data.last_saved = Time.get_unix_time_from_system()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "state": data}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_from(path: String, catch_up: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "Welcome to your new street."}
	var result := load_json(FileAccess.get_file_as_string(path), catch_up)
	if not result.ok:
		DirAccess.copy_absolute(path, path + ".invalid-" + str(int(Time.get_unix_time_from_system())))
	return result

func load_json(json_text: String, catch_up: bool = true) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	var parsed: Variant = parser.data if parse_error == OK else null
	if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("state") is Dictionary:
		return {"ok": false, "message": "Save could not be read. A backup has been kept."}
	var incoming: Dictionary = parsed.state
	# Whitelist schema, types and known enums; local saves are not trusted online records.
	for key in ["coins", "repair", "digital", "social", "day"]:
		if incoming.get(key) is float or incoming.get(key) is int:
			data[key] = clampi(int(incoming[key]), 0 if key != "day" else 1, 1000000 if key == "coins" else 100)
	for key in ["food", "energy", "comfort"]:
		if incoming.get(key) is float or incoming.get(key) is int:
			data[key] = clampf(float(incoming[key]), 0, 100)
	for key in ["met_amaka", "gig_done", "decorated"]:
		if incoming.get(key) is bool:
			data[key] = incoming[key]
	for key in ["name", "bio", "vote"]:
		if incoming.get(key) is String:
			data[key] = incoming[key].left(160 if key == "bio" else 30)
	if incoming.get("wall") in ["sage", "clay", "ocean"]:
		data.wall = incoming.wall
	if incoming.get("minutes") is float or incoming.get("minutes") is int:
		data.minutes = clampf(float(incoming.minutes), 0, 1439)
	if incoming.get("active") is Dictionary:
		var active: Dictionary = incoming.active
		if ACTIONS.has(active.get("code", "")) and (active.get("remaining") is float or active.get("remaining") is int):
			var total: float = ACTIONS[active.code].seconds
			data.active = {"code": active.code, "total": total, "remaining": clampf(float(active.remaining), 0, total)}
	if incoming.get("posts") is Array:
		for item in incoming.posts.slice(0, 3):
			if item is Dictionary and item.get("title") is String and (item.get("budget") is int or item.get("budget") is float):
				data.posts.append({"id": str(data.posts.size() + 1), "title": item.title.left(60), "budget": clampi(int(item.budget), 10, 10000), "refunded": item.get("refunded", false) == true, "status": "Cancelled" if item.get("refunded", false) == true else "Local draft"})
	if incoming.get("settings") is Dictionary:
		var settings: Dictionary = incoming.settings
		if settings.get("quality") in ["Low", "Medium", "High"]:
			data.settings.quality = settings.quality
		for key in ["shadows", "effects", "data_saver", "manual"]:
			if settings.get(key) is bool:
				data.settings[key] = settings[key]
		if (settings.get("fps") is int or settings.get("fps") is float) and int(settings.fps) in [30, 60]:
			data.settings.fps = int(settings.fps)
		if (settings.get("distance") is int or settings.get("distance") is float) and int(settings.distance) in [0, 1, 2]:
			data.settings.distance = int(settings.distance)
	var elapsed := 0.0
	if incoming.get("last_saved") is float or incoming.get("last_saved") is int:
		elapsed = clampf(Time.get_unix_time_from_system() - float(incoming.last_saved), 0, 1200)
	# Prototype catch-up only finishes the single paid-for activity; it never starts new ones.
	if catch_up and not data.active.is_empty():
		tick(elapsed)
	return {"ok": true, "message": "Welcome back. Your local progress is restored." + (" " + notice if not notice.is_empty() else "")}
