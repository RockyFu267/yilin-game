extends RefCounted

# Physical, uniquely owned tiles. Only A +/- B is evaluated, never executable text.
var lesson_ref: WeakRef
var lesson:
	get:
		return lesson_ref.get_ref()
var h
var rng := RandomNumberGenerator.new()
var tilt := 0.0

func _init(owner) -> void:
	lesson_ref = weakref(owner)
	h = owner.h
	rng.randomize()

func state() -> Dictionary:
	return lesson.s.balance

func generate(round_number: int = 1) -> void:
	var limit: int = lesson.s.limit
	var target := rng.randi_range(2, limit)
	var a: int
	var b: int
	if target < limit and rng.randi_range(0, 1) == 1:
		b = rng.randi_range(1, limit - target)
		a = target + b
	else:
		a = rng.randi_range(1, target - 1)
		b = target - a
	var numbers: Array = [a, b]
	for n in range(4):
		numbers.append(rng.randi_range(1, limit))
	# Use this RNG for reproducible test cases and independent board generation.
	for n in range(5, 0, -1):
		var j := rng.randi_range(0, n)
		var value = numbers[n]
		numbers[n] = numbers[j]
		numbers[j] = value
	var tiles: Array = []
	for n in range(6):
		var x := 100 + n * 95 if n < 3 else 990 + (n - 3) * 95
		tiles.append({"text": str(numbers[n]), "home": x, "x": x, "place": "ground"})
	for pair in [["+", 385], ["−", 460]]:
		tiles.append({"text": pair[0], "home": pair[1], "x": pair[1], "place": "ground"})
	lesson.s.balance = {"revision": 2, "target": target, "round": round_number,
		"tiles": tiles, "slots": [-1, -1, -1], "carry": [-1, -1], "solved": false}
	lesson.s.done = false
	lesson.s.hands = ["", ""]
	tilt = 0
	lesson.message = "搬数字和 + / − 到天平右边，拼成等于左边的算式。放错可以拿回来。"
	lesson.persist()

func reset_board() -> void:
	var d := state()
	for tile in d.tiles:
		tile.place = "ground"
		tile.x = tile.home
	d.slots = [-1, -1, -1]
	d.carry = [-1, -1]
	d.solved = false
	lesson.s.done = false
	tilt = 0
	lesson.message = "这一题的数字都放回原处了。慢慢试，不用抢时间。"
	lesson.persist()

func expression_value():
	var d := state()
	if d.slots.has(-1):
		return null
	var a: String = d.tiles[int(d.slots[0])].text
	var op: String = d.tiles[int(d.slots[1])].text
	var b: String = d.tiles[int(d.slots[2])].text
	if not a.is_valid_int() or not b.is_valid_int() or op not in ["+", "−"]:
		return null
	return int(a) + int(b) if op == "+" else int(a) - int(b)

func use(i: int) -> void:
	var d := state()
	if d.solved:
		return
	var x: float = h.players[i].position.x
	if h.players[i].position.y < 565 or absf(h.players[i].velocity.y) > 1:
		return
	var held: int = d.carry[i]
	if held >= 0:
		for slot in range(3):
			if absf(x - slot_x(slot)) < 38:
				if d.slots[slot] != -1:
					lesson.say("这个位置已有牌，先空手拿走它，就能换一张。")
					return
				var text: String = d.tiles[held].text
				if (slot == 1) == text.is_valid_int():
					lesson.say("中间放 + 或 −，两旁放数字。")
					return
				d.slots[slot] = held
				d.tiles[held].place = "slot"
				d.carry[i] = -1
				lesson.persist()
				tick(0)
				return
		# Like the picnic apples: use away from a socket drops the held tile.
		d.tiles[held].place = "ground"
		d.tiles[held].x = clampf(x + h.players[i].facing * 42, 45, 1230)
		d.carry[i] = -1
		lesson.persist()
		return
	var closest := -1
	var distance := 44.0
	for n in range(d.tiles.size()):
		var tile: Dictionary = d.tiles[n]
		var tx: float = tile.x
		if tile.place == "slot":
			tx = slot_x(d.slots.find(n))
		elif tile.place != "ground":
			continue
		if absf(x - tx) < distance:
			distance = absf(x - tx)
			closest = n
	if closest >= 0:
		var old_slot: int = d.slots.find(closest)
		if old_slot >= 0:
			d.slots[old_slot] = -1
		d.tiles[closest].place = "hand"
		d.carry[i] = closest
		lesson.persist()

func slot_x(slot: int) -> float:
	return 540.0 + slot * 105.0

func tick(delta: float) -> void:
	var d := state()
	var value = expression_value()
	var target_tilt := -18.0 if value == null else clampf((float(value) - d.target) * 3, -27, 27)
	tilt = move_toward(tilt, target_tilt, delta * 65)
	if value != null and value == d.target and not d.solved:
		d.solved = true
		lesson.s.done = true
		lesson.say("%s %s %s = %d，天平平衡啦！一起走过右边的小桥，进入下一题。" % [d.tiles[int(d.slots[0])].text, d.tiles[int(d.slots[1])].text, d.tiles[int(d.slots[2])].text, d.target])
		h._burst(Vector2(680, 310))
	if d.solved and h.players[0].position.x > 1200 and h.players[1].position.x > 1200:
		generate(int(d.round) + 1)
		for i in range(2):
			h.players[i].position = Vector2(110 + i * 85, 600)
			h.players[i].velocity = Vector2.ZERO

func card(text: String, pos: Vector2, active: bool = false, small: bool = false, canvas = null) -> void:
	var c = h if canvas == null else canvas
	var size := Vector2(54, 54) if small else Vector2(66, 62)
	var rect := Rect2(pos - size / 2, size)
	c.draw_rect(rect.grow(3), Color("483526"))
	c.draw_rect(rect, Color("e8c78b") if text.is_valid_int() else Color("9dbf9a"))
	c.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(size.x - 6, 4)), Color("fff0bd"))
	if active:
		c.draw_rect(rect.grow(5), Color("f9dc86"), false, 3)
	var width: float = h.bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(h.bold, pos + Vector2(-width / 2, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("493927"))

func paint() -> void:
	var d := state()
	# A large in-world scale, with two hanging pans and a carved central pillar.
	h.draw_rect(Rect2(448, 287, 21, 204), Color("775235"))
	h.draw_rect(Rect2(420, 482, 78, 15), Color("b5894c"))
	h.draw_rect(Rect2(450, 284, 18, 12), Color("edc878"))
	h.draw_line(Vector2(240, 302 - tilt), Vector2(645, 302 + tilt), Color("69482e"), 15)
	h.draw_line(Vector2(240, 299 - tilt), Vector2(645, 299 + tilt), Color("ddb978"), 6)
	for pan in [Vector2(240, 302 - tilt), Vector2(645, 302 + tilt)]:
		var half := 90 if pan.x == 240 else 140
		h.draw_line(pan, pan + Vector2(-half + 16, 90), Color("85643f"), 4)
		h.draw_line(pan, pan + Vector2(half - 16, 90), Color("85643f"), 4)
		h.draw_rect(Rect2(pan + Vector2(-half, 88), Vector2(half * 2, 12)), Color("d7b478"))
	card(str(d.target), Vector2(240, 354 - tilt))
	h._center("目标", 253, 22, h.CREAM, true, 240)
	h._center("第 %d 题 · %d 以内" % [d.round, lesson.s.limit], 221, 23, h.CREAM, true, 645)
	# Floor-level stone sockets are directly reachable with the ordinary use key.
	for n in range(3):
		var pos := Vector2(slot_x(n), 552)
		h.draw_rect(Rect2(pos - Vector2(39, 36), Vector2(78, 75)), Color("786b55"))
		h.draw_rect(Rect2(pos - Vector2(34, 31), Vector2(68, 62)), Color("a89876"))
		h._center("+ / −" if n == 1 else "数字", 496, 17, h.CREAM, false, pos.x)
		if d.slots[n] >= 0:
			var text: String = d.tiles[int(d.slots[n])].text
			card(text, pos)
			card(text, Vector2(566 + n * 78, 354 + tilt), false, true)
	var value = expression_value()
	if value != null:
		h._center("%d %s %d" % [d.target, "=" if value == d.target else (">" if d.target > value else "<"), value], 447, 26, Color("ffe4a1"), true, 645)
	else:
		h._center("数字   + / −   数字", 447, 22, h.CREAM, false, 645)
	if d.solved:
		h._bridge(1000, 1270, true)
		h._center("一起往右过桥 →", 474, 21, Color("fff0ac"), true, 1095)
	else:
		# Visible closed passage, rather than a confirm/submit UI button.
		h.draw_rect(Rect2(1235, 474, 12, 111), Color("795939"))
		for y in [500, 535]:
			h.draw_rect(Rect2(1200, y, 70, 9), Color("d2ac6b"))

func paint_tiles(canvas: CanvasItem) -> void:
	var d := state()
	for n in range(d.tiles.size()):
		var tile: Dictionary = d.tiles[n]
		if tile.place == "ground":
			var highlighted := false
			for i in range(2):
				highlighted = highlighted or (d.carry[i] < 0 and absf(h.players[i].position.x - tile.x) < 44)
			card(tile.text, Vector2(tile.x, 552), highlighted, true, canvas)
	for i in range(2):
		if d.carry[i] >= 0:
			card(d.tiles[int(d.carry[i])].text, h.players[i].position + Vector2(0, -139), true, true, canvas)
