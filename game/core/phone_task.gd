extends RefCounted
const INPUTS = ["left", "right", "wide", "detail", "record", "assist", "charge"]
static func fresh() -> Dictionary:
	return {"battery": 4, "pan": 0, "zoom": 2, "ready": false, "takes": 0, "charges": 0, "hint": ""}
static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	for field in ["battery", "pan", "zoom", "takes", "charges"]:
		if not (value.get(field) is int or value.get(field) is float): return {}
	var p := fresh()
	p.battery = clampi(int(value.battery), 0, 100)
	p.pan = clampi(int(value.pan), 0, 2)
	p.zoom = clampi(int(value.zoom), 1, 2)
	p.takes = clampi(int(value.takes), 0, 100000)
	p.charges = clampi(int(value.charges), 0, 100000)
	p.ready = value.get("ready", false) == true and p.pan == 1 and p.zoom == 1
	p.hint = str(value.get("hint", "")).left(240)
	return p
static func reset_frame(p: Dictionary) -> void:
	p.pan = 0
	p.zoom = 2
	p.ready = false
	p.hint = ""
static func advance(p: Dictionary, input: String, cost: int) -> void:
	if p.ready: return
	if input == "charge":
		if p.battery == 0:
			p.battery = 4
			p.charges += 1
			p.hint = "Borrowed enough charge for another try. The original footage is safe."
		else: p.hint = "There is charge left. Adjust the frame and try the take."
		return
	if input == "left": p.pan = maxi(0, p.pan - 1)
	if input == "right": p.pan = mini(2, p.pan + 1)
	if input == "wide": p.zoom = 1
	if input == "detail": p.zoom = 2
	if not input in ["record", "assist"]:
		p.hint = "Frame the three labelled subjects together. Panning uses no battery."
		return
	if p.battery < cost:
		p.hint = "Battery empty. Borrow enough charge; no original footage is lost."
		return
	if input == "assist":
		p.pan = 1
		p.zoom = 1
	p.battery -= cost
	p.takes += 1
	p.ready = p.pan == 1 and p.zoom == 1
	p.hint = "Full frame saved. Continue below." if p.ready else "Battery empty. Borrow enough charge; no original footage is lost." if p.battery == 0 else "The crop misses context. Centre the camera and use Wide, or choose Guided full frame."
