extends SceneTree

var game
var lesson
var scale
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, caption: String) -> void:
	if ok:
		print("PASS: " + caption)
	else:
		failures += 1
		push_error("FAIL: " + caption)

func at(i: int, x: float) -> void:
	game.players[i].position = Vector2(x, 600)
	game.players[i].velocity = Vector2.ZERO
	lesson.use(i)

func put(i: int, tile: int, slot: int) -> void:
	at(i, lesson.s.balance.tiles[tile].x)
	at(i, scale.slot_x(slot))

func setup_example() -> void:
	lesson.start("ducks10")
	var d: Dictionary = lesson.s.balance
	d.target = 6
	for n in range(6):
		d.tiles[n].text = str([8, 2, 4, 1, 7, 3][n])
	scale.reset_board()

func solvable(d: Dictionary) -> bool:
	for a in range(6):
		for b in range(6):
			if a != b:
				var left := int(d.tiles[a].text)
				var right := int(d.tiles[b].text)
				if left + right == d.target or left - right == d.target:
					return true
	return false

func ownership_valid() -> bool:
	var d: Dictionary = lesson.s.balance
	var seen: Array = []
	for id in d.slots:
		if id >= 0:
			if id in seen or d.tiles[int(id)].place != "slot": return false
			seen.append(id)
	for id in d.carry:
		if id >= 0:
			if id in seen or d.tiles[int(id)].place != "hand": return false
			seen.append(id)
	for id in range(d.tiles.size()):
		if d.tiles[id].place == "ground":
			if id in seen: return false
			seen.append(id)
	return seen.size() == 8

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	lesson = game.learning
	scale = lesson.balance
	scale.rng.seed = 42006
	for activity in ["ducks5", "ducks10", "ducks20"]:
		lesson.start(activity)
		var valid := true
		var addition_found := false
		var subtraction_found := false
		var last_signature := ""
		var varied := false
		for round_id in range(1, 401):
			scale.generate(round_id)
			var d: Dictionary = lesson.s.balance
			valid = valid and d.tiles.size() == 8 and d.tiles[6].text == "+" and d.tiles[7].text == "−" and d.target >= 2 and d.target <= lesson.s.limit and solvable(d)
			for n in range(6):
				valid = valid and d.tiles[n].text.is_valid_int() and int(d.tiles[n].text) >= 1 and int(d.tiles[n].text) <= lesson.s.limit
			for a in range(6):
				for b in range(6):
					if a != b:
						addition_found = addition_found or int(d.tiles[a].text) + int(d.tiles[b].text) == d.target
						subtraction_found = subtraction_found or int(d.tiles[a].text) - int(d.tiles[b].text) == d.target
			var signature := JSON.stringify([d.target, d.tiles])
			varied = varied or (not last_signature.is_empty() and signature != last_signature)
			last_signature = signature
		check(valid, activity + " 400 boards contain six bounded number tiles and a distinct-tile solution")
		check(varied and addition_found and subtraction_found, activity + " random boards allow both addition and subtraction")
	setup_example()
	at(0, 100)
	at(1, 100)
	check(lesson.s.balance.carry == [0, -1], "Two players cannot take the same physical tile")
	at(0, 645)
	check(lesson.s.balance.carry[0] == 0 and lesson.s.balance.slots[1] == -1, "Number cannot occupy the operator socket")
	at(0, 350)
	check(lesson.s.balance.carry[0] == -1 and lesson.s.balance.tiles[0].place == "ground", "Held tile can be dropped like an apple")
	var dropped_x: float = lesson.s.balance.tiles[0].x
	at(1, dropped_x)
	check(lesson.s.balance.carry[1] == 0, "Partner can recover a dropped tile")
	at(1, 540)
	at(0, 385)
	at(0, 750)
	check(lesson.s.balance.carry[0] == 6 and lesson.s.balance.slots[2] == -1, "Operator cannot occupy a number socket")
	at(0, 645)
	put(1, 2, 2)
	lesson.tick(0.4)
	check(scale.expression_value() == 12 and not lesson.s.done and scale.tilt > 0, "Wrong sum tilts scale without passing")
	check(game.barriers[0].collision_layer == 1, "Passage remains physically closed for an incorrect equation")
	at(0, 540)
	at(0, 350)
	put(0, 1, 0)
	check(scale.expression_value() == 6 and lesson.s.balance.solved, "Two plus four automatically balances six without submit or lever")
	lesson.tick(0.8)
	check(game.barriers[0].collision_layer == 0 and scale.tilt == 0, "Balanced scale levels and opens the passage")
	check(ownership_valid(), "Tile ownership remains unique after drops and replacements")
	game.players[0].position.x = 1210
	lesson.tick(0.1)
	check(lesson.s.balance.round == 1, "One player crossing cannot refresh the partner's board")
	game.players[1].position.x = 1210
	lesson.tick(0.1)
	check(lesson.s.balance.round == 2 and not lesson.s.balance.solved and lesson.s.balance.slots == [-1, -1, -1] and lesson.s.balance.carry == [-1, -1], "Both cross to a fresh solvable board and reset carried tiles")
	check(solvable(lesson.s.balance), "Next round remains solvable")
	setup_example()
	put(0, 0, 0)
	put(1, 7, 1)
	at(1, 195)
	lesson.persist()
	var saved_board = JSON.parse_string(JSON.stringify(lesson.s.balance))
	lesson.s.balance.target = 999
	lesson.resume_saved()
	check(lesson.s.balance == saved_board and ownership_valid(), "Save restores exact tiles, sockets, target and held tile")
	at(1, 750)
	check(scale.expression_value() == 6 and lesson.s.done, "Eight minus two balances six after save/resume")
	lesson.pause()
	var round_id: int = lesson.s.balance.round
	game.players[0].position.x = 1210
	game.players[1].position.x = 1210
	await process_frame
	check(lesson.s.balance.round == round_id, "Pause cannot advance a completed board")
	lesson.retry()
	check(not game.paused and not lesson.s.balance.solved and ownership_valid() and lesson.s.balance.target == 6, "Retry preserves the puzzle and returns six numbers plus one operator pair")
	# Use actual keyboard input through the normal learning-mode event route.
	game.players[0].position = Vector2(100, 600)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(lesson.s.balance.carry[0] == 0, "Physical E input picks a tile through normal game controls")
	event.pressed = false
	Input.parse_input_event(event)
	game.queue_free()
	await process_frame
	print("BALANCE_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
