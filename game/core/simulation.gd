extends RefCounted
## Local prototype rules. Real economy/eligibility moves server-side in Milestone 1.

const VERSION = 1
const ACTIONS = {
	"eat": {"name": "Jollof at Amaka's", "seconds": 6.0, "cost": 25, "food": 35, "energy": 4},
	"communitymeal": {"name": "Amaka's community plate", "seconds": 12.0, "cost": 0, "food": 25},
	"lantern": {"name": "Repair the park lantern", "seconds": 10.0, "cost": 0, "energy": -8},
	"learn": {"name": "Practice a repair", "seconds": 8.0, "cost": 0, "energy": -8, "repair": 1},
	"gig": {"name": "Repair Yemi's radio", "seconds": 10.0, "cost": 0, "energy": -12, "coins": 90, "repair": 1},
	"rest": {"name": "Rest at home", "seconds": 8.0, "cost": 0, "energy": 35},
	"wash": {"name": "Freshen up", "seconds": 5.0, "cost": 0, "comfort": 20},
	"study": {"name": "Learn digital skills", "seconds": 8.0, "cost": 0, "energy": -8, "digital": 1},
	"fan": {"name": "Service a standing fan", "seconds": 20.0, "cost": 0, "coins": 45, "repair": 1},
	"inverter": {"name": "Diagnose an inverter", "seconds": 30.0, "cost": 0, "coins": 75, "repair": 1},
}
const REPAIR_JOBS = {
	"fan": {"energy": 18, "food": 8, "skill": 2, "completed": 0},
	"inverter": {"energy": 26, "food": 12, "skill": 4, "completed": 3},
}
const HOME_ITEMS = {
	"rug": {"name": "Woven floor mat", "price": 90, "detail": "A warm pattern at your doorway."},
	"plant": {"name": "Desk plant", "price": 60, "detail": "A little green by the window."},
	"radio": {"name": "Table radio", "price": 180, "detail": "Your own radio on the home desk."},
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
		"world_seed": 260713,
		"neighbors": {"amaka": 0, "yemi": 0, "park": 0, "park_choice": ""}, "favor": "available",
		"career": {"completed": 0, "cooldown": 0.0}, "inventory": {"owned": [], "equipped": []},
		"errand": {"stage": "available", "spot": ""},
		"settings": {"quality": "Medium", "shadows": true, "effects": true, "distance": 1,
			"fps": 30, "data_saver": true, "manual": false},
	}

func begin_action(code: String) -> Dictionary:
	if not ACTIONS.has(code):
		return {"ok": false, "message": "That activity is unavailable."}
	if not data.active.is_empty():
		return {"ok": false, "message": "Finish your current activity first."}
	if code == "lantern" and (data.errand.stage != "repair" or data.repair < 1):
		return {"ok": false, "message": "Collect the park lantern and bring it to the repair bench first."}
	if code == "communitymeal" and (data.coins >= 25 or data.food >= 20):
		return {"ok": false, "message": "Community plates are for neighbors below 20 food with fewer than 25 SC."}
	if code == "gig" and data.gig_done:
		return {"ok": false, "message": "Yemi's radio is already repaired."}
	if code == "gig" and data.repair < 1:
		return {"ok": false, "message": "Practice once at the repair bench to unlock this gig."}
	if REPAIR_JOBS.has(code):
		var problem := repair_problem(code)
		if not problem.is_empty(): return {"ok": false, "message": problem}
	var action: Dictionary = ACTIONS[code]
	if data.coins < action.cost:
		return {"ok": false, "message": "You need %s StreetCoins." % action.cost}
	if action.get("energy", 0) < 0 and data.energy < 15:
		return {"ok": false, "message": "A quick rest at home will help. Energy must be at least 15."}
	data.coins -= action.cost
	if REPAIR_JOBS.has(code):
		data.energy -= REPAIR_JOBS[code].energy
		data.food -= REPAIR_JOBS[code].food
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
	data.career.cooldown = maxf(0, data.career.cooldown - seconds)
	if data.active.is_empty():
		return false
	data.active.remaining -= seconds
	if data.active.remaining > 0:
		return false
	var code: String = data.active.code
	var action: Dictionary = ACTIONS[code]
	if REPAIR_JOBS.has(code):
		data.career.completed += 1
		data.career.cooldown = maxf(0, 45 + data.active.remaining)
	# Clear before awarding: repeated ticks cannot pay the same action twice.
	data.active = {}
	for stat in ["food", "energy", "comfort"]:
		data[stat] = clampf(data[stat] + action.get(stat, 0), 0, 100)
	for skill in ["repair", "digital"]:
		data[skill] = mini(100, int(data[skill]) + int(action.get(skill, 0)))
	data.coins += action.get("coins", 0)
	if code == "gig":
		data.gig_done = true
	if code == "lantern": data.errand.stage = "ready"
	notice = action.name + " complete" + (" · +%s StreetCoins" % action.coins if action.has("coins") else "")
	return true

func repair_problem(code: String) -> String:
	var job: Dictionary = REPAIR_JOBS[code]
	if not data.gig_done: return "Finish Yemi's starter radio repair first."
	if data.repair < job.skill or data.career.completed < job.completed:
		return "Requires Repair %s and %s completed career jobs." % [job.skill, job.completed]
	if data.career.cooldown > 0: return "Next customer in %ss. Rest or eat while you wait." % ceili(data.career.cooldown)
	if data.energy < job.energy + 5 or data.food < 20: return "Needs %s energy and at least 20 food. Rest at home or eat at Amaka's." % (job.energy + 5)
	return ""

func home_intent(kind: String, item: String, choice: String = "") -> Dictionary:
	if not HOME_ITEMS.has(item): return {"ok": false, "message": "Choose a listed home item."}
	if kind == "buy":
		if item in data.inventory.owned: return {"ok": false, "message": "You already own this item."}
		if data.coins < HOME_ITEMS[item].price: return {"ok": false, "message": "You need more StreetCoins."}
		data.coins -= HOME_ITEMS[item].price
		data.inventory.owned.append(item)
		data.inventory.equipped.append(item)
	elif kind == "furnish":
		if not item in data.inventory.owned or not choice in ["place", "store"]: return {"ok": false, "message": "Choose place or store for an owned item."}
		data.inventory.equipped.erase(item)
		if choice == "place": data.inventory.equipped.append(item)
	else: return {"ok": false, "message": "Choose a listed home action."}
	return {"ok": true, "message": "Home updated. Purchases use fictional StreetCoins."}

func meet_amaka() -> String:
	data.neighbors.amaka = maxi(1, data.neighbors.amaka)
	if not data.met_amaka:
		data.met_amaka = true
		data.social += 1
		return "Amaka: Welcome, neighbor! Yemi needs a hand with his radio. Try his repair bench first."
	return "Amaka: Small steps still take you somewhere. How is your day going?"

func neighbor_choice(choice: String) -> Dictionary:
	match choice:
		"yemi_hello", "park_welcome":
			var who := "yemi" if choice == "yemi_hello" else "park"
			if data.neighbors[who] == 0:
				data.neighbors[who] = 1
				data.social = mini(100, data.social + 1)
			if who == "park": data.neighbors.park_choice = "welcome"
		"park_space": data.neighbors.park_choice = "space"
		"favor_accept":
			if not data.met_amaka or data.favor != "available": return {"ok": false, "message": "Say hello to Amaka first. This favor can be accepted once."}
			data.favor = "carrying"
		"favor_deliver":
			if data.favor != "carrying": return {"ok": false, "message": "Collect Amaka's covered lunch plate first."}
			data.favor = "delivered"
			data.neighbors.yemi = maxi(2, data.neighbors.yemi)
		"favor_finish":
			if data.favor != "delivered": return {"ok": false, "message": "Take the plate to Yemi, then return to Amaka."}
			data.favor = "complete"
			data.neighbors.amaka = 3
			data.neighbors.yemi = 3
			data.social = mini(100, data.social + 1)
			data.coins += 30
		_: return {"ok": false, "message": "Choose a listed neighbor conversation."}
	return {"ok": true, "message": "Your neighbor remembers."}

func errand_choice(choice: String) -> Dictionary:
	var stage: String = data.errand.stage
	match choice:
		"accept":
			if stage != "available" or not data.met_amaka or not data.gig_done: return {"ok": false, "message": "Say hello to Amaka and finish Yemi's starter radio first."}
			data.errand.stage = "collect"
		"collect":
			if stage != "collect": return {"ok": false, "message": "Accept Amaka's lantern errand first."}
			data.errand.stage = "repair"
			data.neighbors.park = maxi(1, data.neighbors.park)
		"install_board", "install_bench":
			if stage != "ready": return {"ok": false, "message": "Repair the lantern at Yemi's first."}
			data.errand.stage = "installed"
			data.errand.spot = "board" if choice == "install_board" else "bench"
			data.neighbors.park = maxi(2, data.neighbors.park)
		"finish":
			if stage != "installed": return {"ok": false, "message": "Install the repaired lantern in the square first."}
			data.errand.stage = "complete"
			data.coins += 40
			data.social = mini(100, data.social + 1)
			data.neighbors.amaka = maxi(2, data.neighbors.amaka)
			data.neighbors.yemi = maxi(2, data.neighbors.yemi)
			data.neighbors.park = 3
		_: return {"ok": false, "message": "Choose a listed lantern errand action."}
	return {"ok": true, "message": "Lantern errand updated."}

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
	if data.errand.stage in ["collect", "repair", "ready", "installed"]:
		var objective: Dictionary = preload("res://core/neighborhood_errand.gd").objective(data.errand)
		return {"step": 8, "title": "A light for the square", "body": objective.get("hud", objective.text), "place": objective.place}
	if data.favor in ["carrying", "delivered"]:
		return {"step": 6, "title": "A plate for Yemi", "body": "Deliver Amaka's covered lunch plate to Yemi." if data.favor == "carrying" else "Tell Amaka the lunch arrived. One-time thank-you: 30 SC.", "place": "repair" if data.favor == "carrying" else "food"}
	if not data.met_amaka:
		return {"step": 1, "title": "Meet your neighbor", "body": "Amaka knows this street. Say hello at the food stall.", "place": "food"}
	if data.repair < 1:
		return {"step": 2, "title": "Learn something useful", "body": "Practice at Yemi's repair bench. Everyone starts somewhere.", "place": "repair"}
	if not data.gig_done:
		return {"step": 3, "title": "Your first honest hustle", "body": "Repair Yemi's radio and earn 90 StreetCoins.", "place": "repair"}
	if not data.decorated:
		return {"step": 4, "title": "Make it yours", "body": "Head home and choose an accent color. Your street life has begun.", "place": "home"}
	return {"step": 7, "title": "Build your repair career", "body": "%s jobs completed. Take repeatable work at Yemi's, then furnish your home." % data.career.completed, "place": "repair"}

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
	if incoming.get("world_seed") is float or incoming.get("world_seed") is int:
		data.world_seed = clampi(int(incoming.world_seed), 1, 2147483646)
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
	if incoming.get("neighbors") is Dictionary:
		for who in ["amaka", "yemi", "park"]:
			var value: Variant = incoming.neighbors.get(who)
			if value is float or value is int: data.neighbors[who] = clampi(int(value), 0, 3)
		if incoming.neighbors.get("park_choice") in ["", "welcome", "space"]:
			data.neighbors.park_choice = incoming.neighbors.park_choice
	if data.met_amaka: data.neighbors.amaka = maxi(1, data.neighbors.amaka)
	if incoming.get("favor") in ["available", "carrying", "delivered", "complete"]: data.favor = incoming.favor
	if incoming.get("errand") is Dictionary:
		var errand: Dictionary = incoming.errand
		if errand.get("stage") in ["available", "collect", "repair", "ready", "installed", "complete"]:
			data.errand = {"stage": errand.stage, "spot": ""}
			if errand.stage in ["installed", "complete"]:
				data.errand.spot = errand.get("spot") if errand.get("spot") in ["board", "bench"] else "board"
	if incoming.get("career") is Dictionary:
		var career: Dictionary = incoming.career
		if career.get("completed") is float or career.get("completed") is int: data.career.completed = clampi(int(career.completed), 0, 1000000)
		if career.get("cooldown") is float or career.get("cooldown") is int: data.career.cooldown = clampf(float(career.cooldown), 0, 45)
	if incoming.get("inventory") is Dictionary:
		data.inventory = {"owned": [], "equipped": []}
		for field in ["owned", "equipped"]:
			if incoming.inventory.get(field) is Array:
				for item in incoming.inventory[field]:
					if item is String and HOME_ITEMS.has(item) and not item in data.inventory[field] and (field == "owned" or item in data.inventory.owned): data.inventory[field].append(item)
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
	if catch_up and (not data.active.is_empty() or data.career.cooldown > 0):
		tick(elapsed)
	return {"ok": true, "message": "Welcome back. Your local progress is restored." + (" " + notice if not notice.is_empty() else "")}
