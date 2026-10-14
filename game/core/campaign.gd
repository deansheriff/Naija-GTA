extends RefCounted
const STORY_PATH = "res://story/prologue.json"
const LEADS = ["tunde", "ngozi", "kc"]

static func story() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))

static func fresh() -> Dictionary:
	return {"version": 1, "status": "unstarted", "stage": 0, "lead": "tunde", "completed": [], "mastery": {"tunde": 0, "ngozi": 0, "kc": 0}, "evidence": [], "paused": true}

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return fresh()
	# Preserve newer campaigns instead of downgrading and overwriting them.
	if (value.get("version") is int or value.get("version") is float) and value.version > 1: return value.duplicate(true)
	var count: int = story().stages.size()
	if value.get("version") != 1 or not value.get("status") in ["unstarted", "playing", "hub"]: return fresh()
	var stage: Variant = value.get("stage")
	if not (stage is int or stage is float) or stage != int(stage) or stage < 0 or stage > count: return fresh()
	if (value.status == "hub") != (stage == count) or (value.status == "unstarted" and stage != 0): return fresh()
	var result := fresh()
	result.status = value.status
	result.stage = int(stage)
	result.paused = value.get("paused", true) != false
	result.lead = value.get("lead") if value.get("lead") in LEADS else "tunde"
	if result.status == "playing": result.lead = story().stages[result.stage].lead
	if result.status == "hub":
		result.completed = ["P00"]
		result.mastery = {"tunde": 1, "ngozi": 1, "kc": 1}
		result.evidence = ["wedding_clip"]
	return result

static func active(c: Dictionary) -> bool:
	return c.get("version") == 1 and c.get("status") != "unstarted" and c.get("paused") == false

static func command(c: Dictionary, kind: String, stage: int = -1, choice: String = "") -> Dictionary:
	var fail := {"ok": false, "message": "This choice does not match your active campaign checkpoint. Reopen the story."}
	if c.get("version") != 1: return {"ok": false, "message": "This campaign needs a newer game client. Its saved progress has been preserved."}
	if kind == "campaign_start":
		if c.status != "unstarted": return {"ok": false, "message": "Your campaign has already started. Resume its checkpoint."}
		c.status = "playing"
		c.paused = false
		return {"ok": true, "message": "Wedding introduction started. Your street progress is separate."}
	if c.status == "unstarted": return {"ok": false, "message": "Start the wedding introduction first."}
	if kind in ["campaign_pause", "campaign_resume"]:
		c.paused = kind == "campaign_pause"
		return {"ok": true, "message": "Campaign checkpoint saved."}
	if kind == "campaign_switch":
		if c.status != "hub": return {"ok": false, "message": "The wedding has a staged perspective order. Finish or pause this task first."}
		if not choice in LEADS: return fail
		c.lead = choice
		return {"ok": true, "message": "Family Meeting · " + choice.capitalize()}
	if kind != "campaign_choose" or c.status != "playing" or c.paused or stage != c.stage: return fail
	var content := story()
	var task: Dictionary = content.stages[c.stage]
	for option in task.choices:
		if option.id != choice: continue
		if not option.correct: return {"ok": false, "message": option.get("hint", "Try the labelled objective again.")}
		c.stage += 1
		if c.stage == content.stages.size():
			c.status = "hub"
			c.completed = ["P00"]
			c.mastery = {"tunde": 1, "ngozi": 1, "kc": 1}
			c.evidence = ["wedding_clip"]
		else: c.lead = content.stages[c.stage].lead
		return {"ok": true, "message": "Campaign checkpoint saved."}
	return fail
