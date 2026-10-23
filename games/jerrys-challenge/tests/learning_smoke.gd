extends SceneTree

var game
var lesson
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, name: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + name)
	else:
		print("PASS: " + name)

func use_at(i: int, x: float) -> void:
	game.players[i].position = Vector2(x, 600)
	game.players[i].velocity = Vector2.ZERO
	lesson.use(i)

func buy(item: int, actor: int) -> void:
	use_at(actor, 330 + 180 * item)
	for n in range(item + 1):
		use_at(actor, 790)
	use_at(actor, 1060)

func travel() -> void:
	game.players[1].position = Vector2(140, 600)
	game.players[1].velocity = Vector2.ZERO
	use_at(0, 100)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	lesson = game.learning
	lesson.start("shop")
	use_at(0, 100)
	check(lesson.s.room == "shop", "Stairs wait for partner")
	travel()
	check(lesson.s.room == "supply", "Both travel to basement")
	use_at(0, 330)
	use_at(0, 1060)
	check(lesson.s.stock == [0, 0], "Underpayment cannot purchase")
	use_at(0, 790)
	use_at(1, 790)
	use_at(0, 1060)
	check(lesson.s.wallet == 4 and lesson.s.stock == [0, 0], "Overpayment remains reversible escrow")
	use_at(1, 910)
	use_at(1, 1060)
	check(lesson.s.wallet == 5 and lesson.s.stock == [1, 0], "Corrected payment purchases once")
	use_at(0, 1060)
	use_at(0, 330)
	check(lesson.s.stock == [1, 0] and lesson.s.purchase == -1, "Repeat confirm and duplicate buying cannot duplicate ingredients")
	buy(1, 1)
	check(lesson.s.wallet == 3 and lesson.s.stock == [1, 1], "Two ingredient costs total three")
	travel()
	use_at(0, 320)
	use_at(1, 480)
	use_at(0, 650)
	use_at(1, 650)
	check(lesson.s.phase == "mix" and lesson.s.hands == ["", ""], "Both carried ingredients reach processing table")
	game.players[0].position = Vector2(lesson.MIX_LEFT, 600)
	game.players[1].position = Vector2(lesson.MIX_RIGHT, 600)
	Input.action_press("p1_use")
	lesson.tick(2.0)
	check(lesson.s.phase == "mix", "One player cannot process alone")
	Input.action_press("p2_use")
	lesson.tick(0.7)
	lesson.pause()
	check(lesson.charge == 0 and game.paused, "Pause resets processing progress")
	lesson.pause()
	lesson.tick(1.9)
	Input.action_release("p1_use")
	Input.action_release("p2_use")
	check(lesson.s.phase == "ready", "Dual stations complete ice cream")
	use_at(0, 650)
	use_at(1, 650)
	check(lesson.s.hands == ["ice", ""], "One finished product cannot be picked up twice")
	use_at(0, 1060)
	use_at(0, 1060)
	check(lesson.s.wallet == 8 and lesson.s.served == 1, "Exact tender completes sale and net profit two")
	lesson.s.order = 1
	lesson.s.phase = "change"
	lesson.s.tray = 0
	use_at(1, 790)
	use_at(0, 1060)
	check(lesson.s.phase == "change" and lesson.s.wallet == 8, "Incorrect change neither loses money nor completes sale")
	use_at(1, 790)
	use_at(1, 790)
	lesson.persist()
	lesson.s.wallet = 999
	lesson.resume_saved()
	check(lesson.s.wallet == 8 and lesson.s.tray == 3 and lesson.s.phase == "change", "Save restores exact money, phase and pending change")
	use_at(0, 1060)
	check(lesson.s.wallet == 13 and lesson.s.served == 2, "Eight tender minus three change leaves five")
	lesson.s.order = 2
	lesson.s.phase = "change"
	lesson.s.tray = 6
	use_at(1, 910)
	use_at(1, 1060)
	check(lesson.s.wallet == 18 and lesson.s.served == 3, "Ten tender with reversible five change")
	# Rendering exercises each screen, including full 20-duck layout and paused UI.
	lesson.s.room = "supply"
	game.queue_redraw()
	await process_frame
	print("LEARNING_RESULT: %d failure(s)" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
