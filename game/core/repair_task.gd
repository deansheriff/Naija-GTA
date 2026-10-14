extends RefCounted
const DIRECTIONS = ["Up", "Right", "Down", "Left"]

static func create() -> Dictionary:
	var puzzle := {"turns": [], "target": [], "solved": false}
	for i in range(6):
		var target := randi_range(0, 3)
		puzzle.target.append(target)
		puzzle.turns.append((target + randi_range(1, 3)) % 4)
	return puzzle

static func matches(puzzle: Dictionary) -> bool:
	return puzzle.get("turns", []).size() == 6 and puzzle.get("target", []).size() == 6 and puzzle.turns == puzzle.target

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result := {"turns": [], "target": [], "solved": false}
	for field in ["turns", "target"]:
		if not value.get(field) is Array or value[field].size() != 6: return {}
		for turn in value[field]:
			if not (turn is int or turn is float) or turn != int(turn) or turn < 0 or turn > 3: return {}
			result[field].append(int(turn))
	result.solved = matches(result)
	return result
