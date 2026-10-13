extends Sprite2D
## One direction owns its complete cycle; left mirrors right. Feet anchor at y=0.

var frames: Array[AtlasTexture] = []
var anchors: Array[float] = []
var idle_frames: Array[AtlasTexture] = []
var idle_anchors: Array[float] = []
var heading := "down"
var travelled := 0.0
var stride := 72.0
var directional := false
var display_height := 96.0
var cycle := 0
var pose_index := 0
var grounded := true
var orders: Array = [[0, 1, 2, 3]]
var base_position := Vector2.ZERO

func configure(sheet: Texture2D, regions: Array, height: float, directions: bool = false, playback: Array = []) -> void:
	display_height = height
	directional = directions
	if not playback.is_empty(): orders = playback
	frames.clear()
	anchors.clear()
	for data in regions:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = sheet
		frame_texture.region = Rect2(data[0], data[1], data[2], data[3])
		frames.append(frame_texture)
		anchors.append(float(data[4]) if data.size() > 4 else float(data[2]) / 2.0)
	if not directional: heading = "right"
	walk(Vector2.ZERO)

func walk(displacement: Vector2) -> void:
	var idle: bool = displacement.length_squared() < 0.0001
	if idle:
		cycle = 1 if frames.size() > 1 else 0
	else:
		var x := absf(displacement.x)
		var y := absf(displacement.y)
		# A small diagonal change cannot flip facing back and forth each frame.
		if not directional or x > y * 1.18:
			heading = "left" if displacement.x < 0 else "right"
		elif y > x * 1.18:
			heading = "up" if displacement.y < 0 else "down"
		elif heading in ["left", "right"]:
			heading = "left" if displacement.x < 0 else "right"
		else:
			heading = "up" if displacement.y < 0 else "down"
		travelled = fposmod(travelled + displacement.length(), stride)
		cycle = int(travelled / stride * 4.0) % 4
	var row: int = 0 if not directional or heading in ["left", "right"] else 1 if heading == "down" else 2
	var order: Array = orders[mini(row, orders.size() - 1)]
	flip_h = heading == "left"
	if idle and not idle_frames.is_empty():
		pose_index = -row - 1
		_show_frame(idle_frames[row], idle_anchors[row])
		return
	_set_pose(row * 4 + order[cycle])

func configure_idle(sheet: Texture2D, regions: Array) -> void:
	idle_frames.clear(); idle_anchors.clear()
	for data in regions:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = sheet
		frame_texture.region = Rect2(data[0], data[1], data[2], data[3])
		idle_frames.append(frame_texture)
		idle_anchors.append(float(data[4]))
	walk(Vector2.ZERO)

func _set_pose(index: int) -> void:
	pose_index = clampi(index, 0, frames.size() - 1)
	_show_frame(frames[pose_index], anchors[pose_index])

func _show_frame(selected: AtlasTexture, anchor_x: float) -> void:
	texture = selected
	# Normalize per-frame heights; alpha padding never changes the feet baseline.
	scale = Vector2.ONE * (display_height / texture.get_height())
	base_position = Vector2(0, -display_height / 2.0) if grounded else Vector2.ZERO
	base_position.x = (texture.get_width() / 2.0 - anchor_x) * scale.x * (-1.0 if flip_h else 1.0)
	position = base_position

func flight(phase: float, left: bool) -> void:
	flip_h = left
	_set_pose(int(phase * 6.0) % frames.size())
