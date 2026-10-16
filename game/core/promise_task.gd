extends RefCounted
const Receipt = preload("res://core/receipt_task.gd")
static func catalogue() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://story/promise-task.json"))
static func fresh() -> Dictionary:
	return Receipt.fresh()
static func normalize(value: Variant) -> Dictionary:
	return Receipt.normalize(value, catalogue())
static func inputs() -> Array:
	return Receipt.inputs(catalogue())
static func advance(task: Dictionary, input: String) -> void:
	Receipt.advance(task, input, catalogue())
