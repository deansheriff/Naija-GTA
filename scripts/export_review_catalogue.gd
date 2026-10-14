extends SceneTree
const Dialogue = preload("res://core/street_dialogue.gd")
const Simulation = preload("res://core/simulation.gd")
const Errand = preload("res://core/neighborhood_errand.gd")
var units: Array = []
var seen: Dictionary = {}
func item(id: String, context: String, text: String, choices: Array = []) -> void:
	var key := text + JSON.stringify(choices)
	if seen.has(key): return
	seen[key] = true
	units.append({"id": id, "context": context, "text": text, "choices": choices})
func _initialize() -> void:
	for key in Dialogue.PARK:
		var node: Dictionary = Dialogue.PARK[key]
		var choices: Array = []
		for option in node.choices: choices.append(option[0])
		item("park-" + key, node.speaker + " / park conversation / " + key, node.line, choices)
	var sim = Simulation.new()
	for who in ["amaka", "yemi"]:
		for favor in ["available", "carrying", "delivered", "complete"]:
			for met in [false, true]:
				for gig in [false, true]:
					for stage in ["available", "collect", "repair", "ready", "installed", "complete"]:
						for spot in ["board", "bench"]:
							sim.reset()
							sim.data.favor = favor
							sim.data.met_amaka = met
							sim.data.gig_done = gig
							sim.data.errand = {"stage": stage, "spot": spot}
							var id: String = who + "-" + favor + "-" + str(int(met)) + str(int(gig)) + "-" + stage + "-" + spot
							item(id, who.capitalize() + " / " + ("introduced" if met else "first meeting") + " / radio " + ("repaired" if gig else "not repaired") + " / lunch " + favor + " / lantern " + stage + " / " + spot, Dialogue.neighbor_line(who, sim.data, "At the counter"))
	for favor in ["available", "carrying", "delivered", "complete"]:
		for on_break in [false, true]:
			for stage in ["available", "installed", "complete"]:
				var lines: Array = Dialogue.chatter(favor, on_break, {"stage": stage})
				for i in range(lines.size()): item("chatter-" + favor + "-" + str(int(on_break)) + "-" + stage + "-" + str(i), "Nearby exchange " + str(i + 1) + " / " + str(lines[i][0]) + " / lunch " + favor + " / lantern " + stage + " / " + ("on break" if on_break else "working"), str(lines[i][1]))
	for stage in ["available", "collect", "repair", "ready", "installed", "complete"]:
		for spot in ["board", "bench"]:
			for place in ["food", "repair", "park"]:
				sim.reset()
				sim.data.errand = {"stage": stage, "spot": spot}
				item("errand-" + stage + "-" + spot + "-" + place, "Lantern errand / " + stage + " / " + place + " / " + spot, Errand.line(place, sim.data))
	var hashes := {}
	for path in ["core/street_dialogue.gd", "core/neighborhood_errand.gd"]: hashes[path] = FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").sha256_text()
	hashes["../scripts/export_review_catalogue.gd"] = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../scripts/export_review_catalogue.gd")).replace("\r\n", "\n").sha256_text()
	var path := ProjectSettings.globalize_path("res://../server/src/street-review.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write review catalogue")
		quit(1)
		return
	file.store_string(JSON.stringify({"sources": hashes, "units": units}, "  ") + "\n")
	file.close()
	print("Exported ", units.size(), " distinct street dialogue review units")
	quit(0)
