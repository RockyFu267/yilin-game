extends SceneTree

# Game asset import: slice the generated sheet into the existing 32px animation format.
# A common crop per character preserves alignment between idle, run and air poses.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected the source sheet path")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	if source == null or source.is_empty():
		push_error("Cannot read source sprite sheet")
		quit(1)
		return
	var cell := Vector2i(ceili(source.get_width() / 8.0), ceili(source.get_height() / 4.0))
	for character in range(2):
		var union := Rect2i()
		var frames: Array[Image] = []
		for row in range(2):
			for column in range(8):
				var y_index := character * 2 + row
				var left := roundi(column * source.get_width() / 8.0)
				var right := roundi((column + 1) * source.get_width() / 8.0)
				var top := roundi(y_index * source.get_height() / 4.0)
				var bottom := roundi((y_index + 1) * source.get_height() / 4.0)
				var region := source.get_region(Rect2i(left, top, right - left, bottom - top))
				var frame := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
				frame.fill(Color.TRANSPARENT)
				frame.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), Vector2i.ZERO)
				# Remove low-opacity generation fringe before sprite-sheet alignment.
				for y in range(frame.get_height()):
					for x in range(frame.get_width()):
						var color := frame.get_pixel(x, y)
						color.a = 1.0 if color.a >= 0.5 else 0.0
						frame.set_pixel(x, y, color)
				_keep_main_sprite(frame)
				frames.append(frame)
				var bounds := frame.get_used_rect()
				if bounds.has_area():
					union = bounds if not union.has_area() else union.merge(bounds)
		if not union.has_area():
			push_error("Empty character in sprite sheet")
			quit(1)
			return
		var scale_factor := minf(28.0 / union.size.x, 28.0 / union.size.y)
		var size := Vector2i(maxi(1, roundi(union.size.x * scale_factor)), maxi(1, roundi(union.size.y * scale_factor)))
		var character_name := "Jerry Mouse" if character == 0 else "Tom Cat"
		var dir := "res://assets/characters/" + character_name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var animations := {"Idle": [0, 1, 2, 3], "Run": [8, 9, 10, 11, 12, 13, 14, 15], "Jump": [4, 5], "Fall": [6, 7]}
		for animation in animations:
			var indices: Array = animations[animation]
			var sheet := Image.create(32 * indices.size(), 32, false, Image.FORMAT_RGBA8)
			sheet.fill(Color.TRANSPARENT)
			for i in range(indices.size()):
				var image := frames[indices[i]].get_region(union)
				image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i(i * 32 + (32 - size.x) / 2, 30 - size.y))
			var output: String = dir + "/" + str(animation) + " (32x32).png"
			var error := sheet.save_png(ProjectSettings.globalize_path(output))
			if error != OK:
				push_error("Cannot write " + output)
				quit(1)
				return
		print("IMPORTED ", character_name, " crop=", union, " target=", size)
	quit(0)

func _keep_main_sprite(frame: Image) -> void:
	var width := frame.get_width()
	var height := frame.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var best := PackedInt32Array()
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if visited[index] or frame.get_pixel(x, y).a < 0.5:
				continue
			var component := PackedInt32Array([index])
			visited[index] = 1
			var cursor := 0
			while cursor < component.size():
				var current := component[cursor]
				cursor += 1
				var point := Vector2i(current % width, current / width)
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = point + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					var next := neighbor.y * width + neighbor.x
					if not visited[next] and frame.get_pixelv(neighbor).a >= 0.5:
						visited[next] = 1
						component.append(next)
			if component.size() > best.size():
				best = component
	var keep := PackedByteArray()
	keep.resize(width * height)
	for index in best:
		keep[index] = 1
	for y in range(height):
		for x in range(width):
			if not keep[y * width + x]:
				frame.set_pixel(x, y, Color.TRANSPARENT)
