extends RefCounted
const VERSION = 13
const STORY_PATH = "res://story/prologue.json"
const TUNDE_PATH = "res://story/tunde-intro.json"
const NGOZI_PATH = "res://story/ngozi-intro.json"
const KC_PATH = "res://story/kc-intro.json"
const MEETING_PATH = "res://story/family-meeting.json"
const GENERATOR_PATH = "res://story/generator-wars.json"
const INTERVIEW_PATH = "res://story/japa-interview.json"
const CHASE_PATH = "res://story/danfo-chase.json"
const INFILTRATION_PATH = "res://story/aso-ebi-infiltration.json"
const RECEIPTS_PATH = "res://story/small-small-receipts.json"
const PROMISE_PATH = "res://story/promises.json"
const Promise = preload("res://core/promise_task.gd")
const VIRAL_PATH = "res://story/viral.json"
const Viral = preload("res://core/viral_task.gd")
const QUEUE_PATH = "res://story/fuel-queue-standoff.json"
const Queue = preload("res://core/queue_task.gd")
const Receipt = preload("res://core/receipt_task.gd")
const LEADS = ["tunde", "ngozi", "kc"]
const ORDER = ["P00", "A11", "A12", "A13", "A14", "A21", "A22", "A23", "A24", "A25", "A26", "A27", "A31"]
const Drive = preload("res://core/driving_task.gd")
const Phone = preload("res://core/phone_task.gd")
const Journal = preload("res://core/evidence_journal.gd")
const Portfolio = preload("res://core/portfolio_task.gd")

static func story(id: String = "P00") -> Dictionary:
	if not id in ORDER: return {}
	var path: String = {"P00": STORY_PATH, "A11": TUNDE_PATH, "A12": NGOZI_PATH, "A13": KC_PATH, "A14": MEETING_PATH, "A21": GENERATOR_PATH, "A22": INTERVIEW_PATH, "A23": CHASE_PATH, "A24": INFILTRATION_PATH, "A25": RECEIPTS_PATH, "A26": QUEUE_PATH, "A27": VIRAL_PATH, "A31": PROMISE_PATH}[id]
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if id == "P00":
		content.mastery = {"tunde": 1, "ngozi": 1, "kc": 1}
		content.evidence = ["wedding_clip"]
	return content

static func fresh() -> Dictionary:
	return {"version": VERSION, "mission": "P00", "status": "unstarted", "stage": 0, "lead": "tunde", "completed": [], "mastery": {"tunde": 0, "ngozi": 0, "kc": 0}, "evidence": [], "paused": true, "choices": {}, "drive": null, "phone": null, "portfolio": null}

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return fresh()
	if (value.get("version") is int or value.get("version") is float) and value.version > VERSION: return value.duplicate(true)
	if value.get("version") == 1:
		value = value.duplicate(true)
		value.version = VERSION
		value.mission = "P00"
		value.choices = {}
		value.drive = null
		value.phone = null
		value.portfolio = null
	elif value.get("version") in [2, 3]:
		value = value.duplicate(true)
		value.version = VERSION
		value.phone = null
		value.portfolio = null
	elif value.get("version") in [4, 5, 6]:
		value = value.duplicate(true)
		value.version = VERSION
		value.portfolio = null
	elif value.get("version") in [7, 8, 9, 10, 11, 12]:
		value = value.duplicate(true)
		value.version = VERSION
	if value.get("version") != VERSION or not value.get("status") in ["unstarted", "playing", "hub"]: return fresh()
	if not value.get("mission") in ORDER: return value.duplicate(true)
	var content := story(value.mission)
	var count: int = content.stages.size()
	var stage: Variant = value.get("stage")
	if not (stage is int or stage is float) or stage != int(stage) or stage < 0 or stage > count: return fresh()
	if (value.status == "hub") != (stage == count) or (value.status == "unstarted" and (stage != 0 or value.mission != "P00")): return fresh()
	var result := fresh()
	result.status = value.status
	result.mission = value.mission
	result.stage = int(stage)
	result.paused = value.get("paused", true) != false
	result.lead = value.get("lead") if value.get("lead") in LEADS else "tunde"
	if result.status == "playing": result.lead = content.stages[result.stage].lead
	for id in ORDER:
		if (value.get("completed") is Array and id in value.completed) or (id == result.mission and result.status == "hub"):
			result.completed.append(id)
			var finished := story(id)
			for who in LEADS: result.mastery[who] = mini(100, result.mastery[who] + finished.mastery.get(who, 0))
			for fact in finished.evidence:
				if not fact in result.evidence: result.evidence.append(fact)
	# An explicit snapshot list is authoritative. Missing legacy fields may be
	# reconstructed, but a missing stored record must remain visible for recovery.
	if value.get("choices") is Dictionary:
		for id in result.completed + [result.mission]:
			for task in story(id).stages:
				var key: String = id + "-" + task.id
				for option in task.choices:
					if value.choices.get(key) == option.id and option.correct: result.choices[key] = option.id
	if result.mission == "A25" or value.has("receipt"):
		var receipt := Receipt.normalize(value.get("receipt"))
		result.receipt = receipt if not receipt.is_empty() else Receipt.fresh()
	if result.mission == "A25" or value.has("witnessConsent"):
		result.witnessConsent = null
		if Receipt.has_witness_consent(value): result.witnessConsent = value.witnessConsent.duplicate(true)
	if result.mission == "A26" or value.has("queueTask"):
		var queue := Queue.normalize(value.get("queueTask"))
		result.queueTask = queue if not queue.is_empty() else Queue.fresh()
	if result.mission == "A27" or value.has("viral"):
		var viral := Viral.normalize(value.get("viral"))
		result.viral = viral if not viral.is_empty() else Viral.fresh()
	if value.get("choices", {}).get("A27-withdrawn") == "yes": result.choices["A27-withdrawn"] = "yes"
	if result.mission == "A31" or value.has("promiseTask"):
		var promise := Promise.normalize(value.get("promiseTask"))
		result.promiseTask = promise if not promise.is_empty() else Promise.fresh()
	Journal.restore_earned(result)
	if value.get("evidence") is Array: result.evidence = result.evidence.filter(func(fact): return fact in value.evidence)
	if result.status == "playing" and content.stages[result.stage].get("kind") == "drive":
		var drive := Drive.normalize(value.get("drive"))
		result.drive = drive if not drive.is_empty() else Drive.fresh(0)
		if content.stages[result.stage].has("driveGate") and not result.drive.get("gateCleared", false): result.drive.ready = false
	var phone := Phone.normalize(value.get("phone"))
	if not phone.is_empty(): result.phone = phone
	elif result.mission == "A13": result.phone = Phone.fresh()
	var portfolio := Portfolio.normalize(value.get("portfolio"))
	if not portfolio.is_empty(): result.portfolio = portfolio
	elif result.mission == "A22": result.portfolio = Portfolio.fresh()
	return result

static func active(c: Dictionary) -> bool:
	return c.get("version") == VERSION and c.get("mission") in ORDER and c.get("status") != "unstarted" and c.get("paused") == false

static func _stage(c: Dictionary, now: int) -> void:
	var task: Dictionary = story(c.mission).stages[c.stage]
	c.lead = task.lead
	c.drive = Drive.fresh(now) if task.get("kind") == "drive" else null
	if task.has("driveGate") and c.drive is Dictionary: c.drive.gateCleared = false
	if c.mission == "A13":
		if not c.phone is Dictionary: c.phone = Phone.fresh()
		if task.get("kind") == "frame": Phone.reset_frame(c.phone)
	if c.mission == "A22" and not c.portfolio is Dictionary: c.portfolio = Portfolio.fresh()
	if c.mission == "A25":
		if not c.get("receipt") is Dictionary: c.receipt = Receipt.fresh()
		if not c.has("witnessConsent"): c.witnessConsent = null
	if c.mission == "A31" and not c.get("promiseTask") is Dictionary: c.promiseTask = Promise.fresh()
	if c.mission == "A27" and not c.get("viral") is Dictionary: c.viral = Viral.fresh()
	if c.mission == "A26":
		if not c.get("queueTask") is Dictionary: c.queueTask = Queue.fresh()
		if task.get("queuePhase") == "reset": c.queueTask.hint = ""

static func command(c: Dictionary, kind: String, stage: int = -1, choice: String = "", now: int = -1) -> Dictionary:
	if now < 0: now = Time.get_ticks_msec()
	var fail := {"ok": false, "message": "This choice does not match your active campaign checkpoint. Reopen the story."}
	if c.get("version") != VERSION or not c.get("mission") in ORDER: return {"ok": false, "message": "This campaign needs a newer game client. Its saved progress has been preserved."}
	if kind == "campaign_start":
		if c.status != "unstarted": return {"ok": false, "message": "Your campaign has already started. Resume its checkpoint."}
		c.status = "playing"
		c.paused = false
		_stage(c, now)
		return {"ok": true, "message": "Wedding introduction started. Your street progress is separate."}
	if c.status == "unstarted": return {"ok": false, "message": "Start the wedding introduction first."}
	if kind in ["campaign_pause", "campaign_resume"]:
		c.paused = kind == "campaign_pause"
		if c.drive is Dictionary: c.drive.lastAt = now
		return {"ok": true, "message": "Campaign checkpoint saved."}
	if kind == "campaign_withdraw":
		if not "A25" in c.completed: return fail
		c.witnessConsent = null
		c.evidence.erase("witness_consent")
		c.choices["A27-withdrawn"] = "yes"
		return {"ok": true, "message": "NE-1 permission withdrawn. The document version is current."}
	if kind == "campaign_review":
		if not Journal.available(c): return {"ok": false, "message": "The evidence journal opens at Family Meeting."}
		Journal.restore_earned(c)
		return {"ok": true, "message": "Earned records rechecked. No extra mastery or StreetCoins."}
	if kind == "campaign_switch":
		if c.status != "hub": return {"ok": false, "message": "This mission has a staged perspective. Finish or pause this task first."}
		if not choice in LEADS: return fail
		c.lead = choice
		return {"ok": true, "message": "Family Meeting · " + choice.capitalize()}
	if kind == "campaign_continue":
		if c.status != "hub" or c.paused: return fail
		var index: int = ORDER.find(c.mission) + 1
		if index >= ORDER.size(): return {"ok": false, "message": "The next chapter is still in production. Your checkpoint is saved."}
		c.mission = ORDER[index]
		c.stage = 0
		c.status = "playing"
		_stage(c, now)
		return {"ok": true, "message": "Starting " + story(c.mission).title}
	if c.status != "playing" or c.paused or stage != c.stage: return fail
	var content := story(c.mission)
	var task: Dictionary = content.stages[c.stage]
	if kind == "campaign_promises":
		if task.get("kind") != "promise" or not c.get("promiseTask") is Dictionary or not choice in Promise.inputs(): return fail
		Promise.advance(c.promiseTask, choice)
		return {"ok": true, "message": "Promise comparisons saved."}
	if kind == "campaign_publish":
		if task.get("kind") != "viral" or not c.get("viral") is Dictionary or not choice in Viral.inputs(task.viralPhase): return fail
		Viral.advance(c.viral, choice, task.viralPhase)
		return {"ok": true, "message": "Source and correction checkpoint saved."}
	if kind == "campaign_queue":
		if task.get("kind") != "queue" or not c.get("queueTask") is Dictionary or not choice in Queue.inputs(task.queuePhase): return {"ok": false, "message": "Use a listed queue control for this checkpoint."}
		Queue.advance(c.queueTask, choice, task.queuePhase)
		return {"ok": true, "message": "Queue checkpoint saved."}
	if kind == "campaign_compare":
		if task.get("kind") != "receipt" or not c.get("receipt") is Dictionary or not choice in Receipt.inputs(): return {"ok": false, "message": "Use a listed source-comparison control for this checkpoint."}
		Receipt.advance(c.receipt, choice)
		return {"ok": true, "message": "Source comparison saved."}
	if kind == "campaign_portfolio":
		if task.get("kind") != "portfolio" or not c.portfolio is Dictionary or not choice in Portfolio.inputs(): return {"ok": false, "message": "Use one of the portfolio controls shown for this checkpoint."}
		Portfolio.advance(c.portfolio, choice)
		return {"ok": true, "message": "Portfolio checkpoint saved."}
	if kind == "campaign_phone":
		if task.get("kind") != "frame" or not c.phone is Dictionary or not choice in Phone.INPUTS: return {"ok": false, "message": "Use the illustrated phone controls shown for this checkpoint."}
		Phone.advance(c.phone, choice, int(task.recordCost))
		return {"ok": true, "message": "Phone checkpoint saved."}
	if kind == "campaign_drive":
		if task.get("kind") != "drive" or not c.drive is Dictionary or not choice in Drive.INPUTS or (choice == "yield" and not task.has("driveGate")): return {"ok": false, "message": "Use the driving controls shown for this road leg."}
		Drive.advance(c.drive, choice, now, float(task.target), task.get("driveGate", {}))
		return {"ok": true, "message": "Driving checkpoint saved."}
	if kind != "campaign_choose": return fail
	if task.get("kind") == "drive" and (not c.drive.get("ready", false) or (task.has("driveGate") and not c.drive.get("gateCleared", false))): return {"ok": false, "message": "Reach the lower-lane safe bay and stop first. Guided approach is available."}
	if task.get("kind") == "frame" and not c.phone.get("ready", false): return {"ok": false, "message": "Save the full centred wide frame first. Guided full frame is available at the same battery cost."}
	if task.get("kind") == "portfolio" and not c.portfolio.get("ready", false): return {"ok": false, "message": "Check the three portfolio answers first. Free practice, callback and guided answers are available."}
	if task.get("kind") == "receipt" and not c.get("receipt", {}).get("ready", false): return {"ok": false, "message": "Check all three source comparisons first. Guided matching is free."}
	if task.get("kind") == "queue" and not c.get("queueTask", {}).get("lineReady" if task.queuePhase == "line" else "resetReady", false): return {"ok": false, "message": "Check the current queue task first. Free guidance is available."}
	if task.get("kind") == "promise" and not c.get("promiseTask", {}).get("ready", false): return fail
	if task.get("kind") == "viral" and not c.get("viral", {}).get(task.viralPhase, {}).get("ready", false): return fail
	for option in task.choices:
		if option.id != choice: continue
		if option.get("requiresWitnessConsent", false) and not Receipt.has_witness_consent(c): return {"ok": false, "message": "Current exact-text permission is unavailable. Use the anonymised document route."}
		if option.has("requiresChoice") and c.choices.get(option.requiresChoice.id) != option.requiresChoice.value: return {"ok": false, "message": "The saved witness boundary does not permit this review. Use the anonymised-record route."}
		if not option.correct: return {"ok": false, "message": option.get("hint", "Try the labelled objective again.")}
		for fact in task.get("requiresEvidence", []):
			if not fact in c.evidence: return {"ok": false, "message": "A source record is missing. Open the evidence journal and choose Restore earned records."}
		if task.get("effect") == "publication_permission" and choice == "withdraw":
			c.witnessConsent = null
			c.evidence.erase("witness_consent")
			c.choices["A27-withdrawn"] = "yes"
		if task.get("effect") == "witness_review": c.witnessConsent = {"textHash": str(Receipt.catalogue().witnessText).sha256_text(), "scope": "redacted_text", "active": true} if choice == "approve_ne1" else null
		if task.get("effect") == "charge_phone" and c.phone is Dictionary: c.phone.battery = 4
		c.choices[c.mission + "-" + task.id] = choice
		c.stage += 1
		if c.stage == content.stages.size():
			c.status = "hub"
			c.drive = null
			if not c.mission in c.completed:
				c.completed.append(c.mission)
				for who in LEADS: c.mastery[who] = mini(100, c.mastery[who] + content.mastery.get(who, 0))
				for fact in content.evidence:
					if not fact in c.evidence: c.evidence.append(fact)
				for fact in Journal.earned(c, c.mission):
					if not fact in c.evidence: c.evidence.append(fact)
		else: _stage(c, now)
		return {"ok": true, "message": "Campaign checkpoint saved."}
	return fail
