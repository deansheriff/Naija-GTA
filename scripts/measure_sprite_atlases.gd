extends SceneTree
## Measure visible alpha bounds only; PNG assets are never edited by this script.

func _initialize() -> void:
	var result: Dictionary = {}
	for source in [["hero-walk-v04.png", 4, 3], ["hero-idle-v04.png", 3, 1], ["pedestrians-v04.png", 4, 3], ["wildlife-v04.png", 4, 2], ["neighbors.png", 2, 1]]:
		var texture: Texture2D = load("res://assets/" + source[0])
		var image := texture.get_image()
		image.decompress()
		var cells: Array = []
		for row in range(source[2]):
			for col in range(source[1]):
				var start := Vector2i(col * image.get_width() / source[1], row * image.get_height() / source[2])
				var end := Vector2i((col + 1) * image.get_width() / source[1], (row + 1) * image.get_height() / source[2])
				cells.append(measure(image, Rect2i(start, end - start)))
		result[source[0]] = cells
	var vehicles: Texture2D = load("res://assets/traffic-v04.png")
	var image := vehicles.get_image()
	image.decompress()
	var vehicle_cells: Array = []
	# Read actual alpha gaps, never coordinates from a resized image preview.
	var start := -1
	for x in range(image.get_width() + 1):
		var count := 0
		if x < image.get_width():
			for y in range(image.get_height()):
				if image.get_pixel(x, y).a > 0.25: count += 1
		if count > 8 and start == -1: start = x
		if count <= 8 and start >= 0:
			if x - start > 150:
				vehicle_cells.append(measure(image, Rect2i(start, 0, x - start, image.get_height())))
			start = -1
	assert(vehicle_cells.size() == 3, "Expected three isolated vehicle silhouettes")
	print("Vehicle alpha regions: ", vehicle_cells)
	result["traffic-v04.png"] = vehicle_cells
	var crew_sheet: Texture2D = load("res://assets/street-life-atlas.png")
	var crew_image := crew_sheet.get_image()
	crew_image.decompress()
	var crew_cells: Array = []
	for rect in [Rect2i(174, 426, 247, 557), Rect2i(665, 449, 249, 534), Rect2i(1065, 433, 365, 550)]:
		crew_cells.append(measure(crew_image, rect))
	result["street-life-atlas.png"] = crew_cells
	var file := FileAccess.open("res://assets/sprite-bounds-v04.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("Measured sprite bounds: ", result.keys())
	quit()

func measure(image: Image, cell: Rect2i) -> Array:
	var left: int = cell.end.x
	var right: int = cell.position.x
	var top: int = cell.end.y
	var bottom: int = cell.position.y
	for y in range(cell.position.y, mini(cell.end.y, image.get_height())):
		for x in range(cell.position.x, mini(cell.end.x, image.get_width())):
			if image.get_pixel(x, y).a > 0.25:
				left = mini(left, x); right = maxi(right, x)
				top = mini(top, y); bottom = maxi(bottom, y)
	var head_left: int = right
	var head_right: int = left
	for y in range(top + int((bottom - top) * 0.08), top + int((bottom - top) * 0.28)):
		for x in range(left, right + 1):
			if image.get_pixel(x, y).a > 0.25:
				head_left = mini(head_left, x); head_right = maxi(head_right, x)
	return [left, top, right - left + 1, bottom - top + 1, (head_left + head_right) / 2.0 - left]
