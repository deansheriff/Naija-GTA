extends SceneTree
## Read generated PNG alpha bounds; do not modify raster art.

func _initialize() -> void:
	var result: Dictionary = {}
	for source in [["building-parts-v05.png", 3, 2]]:
		var texture: Texture2D = load("res://assets/" + source[0])
		var image := texture.get_image()
		image.decompress()
		print(source[0], " size=", image.get_size(), " corner alpha=", image.get_pixel(0, 0).a)
		if image.get_pixel(0, 0).a > 0.01:
			printerr("Environment atlas must have a transparent backdrop")
			quit(1)
			return
		var cells: Array = []
		for row in range(source[2]):
			for col in range(source[1]):
				var start := Vector2i(col * image.get_width() / source[1], row * image.get_height() / source[2])
				var end := Vector2i((col + 1) * image.get_width() / source[1], (row + 1) * image.get_height() / source[2])
				var left: int = end.x
				var right: int = start.x
				var top: int = end.y
				var bottom: int = start.y
				for y in range(start.y, end.y):
					for x in range(start.x, end.x):
						if image.get_pixel(x, y).a > 0.2:
							left = mini(left, x); right = maxi(right, x)
							top = mini(top, y); bottom = maxi(bottom, y)
				if right <= left or bottom <= top:
					printerr("Empty environment sprite cell")
					quit(1)
					return
				cells.append([left, top, right - left + 1, bottom - top + 1])
		result[source[0]] = cells
	var tree_texture: Texture2D = load("res://assets/tree-parts-v05.png")
	var trees := tree_texture.get_image()
	trees.decompress()
	if trees.get_pixel(0, 0).a > 0.01:
		printerr("Tree atlas must have a transparent backdrop")
		quit(1)
		return
	# The tree generator left a genuine alpha gutter outside the equal cells.
	# Find the two actual silhouettes rather than clipping foliage at mid-sheet.
	var parts: Array = []
	var run_start := -1
	for x in range(trees.get_width() + 1):
		var occupied := 0
		if x < trees.get_width():
			for y in range(trees.get_height()):
				if trees.get_pixel(x, y).a > 0.2: occupied += 1
		if occupied > 8 and run_start < 0: run_start = x
		if occupied <= 8 and run_start >= 0:
			if x - run_start > 150:
				var top := trees.get_height()
				var bottom := 0
				for y in range(trees.get_height()):
					for px in range(run_start, x):
						if trees.get_pixel(px, y).a > 0.2:
							top = mini(top, y); bottom = maxi(bottom, y)
				parts.append([run_start, top, x - run_start, bottom - top + 1])
			run_start = -1
	if parts.size() != 2:
		printerr("Expected exactly two separated tree pieces: ", parts)
		quit(1)
		return
	result["tree-parts-v05.png"] = parts
	var file := FileAccess.open("res://assets/environment-bounds-v05.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("Environment regions: ", result)
	quit()
