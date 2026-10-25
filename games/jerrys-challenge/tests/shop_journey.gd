extends SceneTree

var game
var shop
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, caption: String) -> void:
	if ok:
		print("PASS: " + caption)
	else:
		failures += 1
		push_error("FAIL: " + caption)

func use_at(i: int, x: float) -> void:
	game.players[i].position = Vector2(x, 600)
	game.players[i].velocity = Vector2.ZERO
	shop.use(i)

func travel() -> void:
	game.players[1].position = Vector2(140, 600)
	game.players[1].velocity = Vector2.ZERO
	use_at(0, 100)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	shop = game.learning
	shop.start("shop")
	for order in range(3):
		shop.s.recipe = [0, 1]
		shop.s.bid = 5
		shop.s.cash = [5, 8, 10][order]
		shop.accept_offer()
		travel()
		for item in range(2):
			use_at(item, shop.supply_x(item))
			for n in range(item + 1):
				use_at(item, 790)
			use_at(item, 1060)
		travel()
		use_at(0, 320)
		use_at(1, 480)
		use_at(0, 650)
		use_at(1, 650)
		check(shop.s.phase == "mix" and shop.s.stock == [0, 0, 0, 0, 0] and shop.s.delivered == [1, 1, 0, 0, 0], "Order %d buys and combines real ingredients" % order)
		var left := order % 2
		var right := 1 - left
		game.players[left].position = Vector2(shop.MIX_LEFT, 600)
		game.players[right].position = Vector2(shop.MIX_RIGHT, 600)
		game.players[left].velocity = Vector2.ZERO
		game.players[right].velocity = Vector2.ZERO
		if order == 0:
			key(KEY_E, true)
			await create_timer(0.2).timeout
			check(shop.mix_holds() == [true, false] and shop.charge == 0, "Single held crank lights independently without progress")
			key(KEY_O, true)
			await create_timer(0.25).timeout
			check(shop.charge > 0 and shop.s.phase == "mix", "Physical E and O build progress at separate cranks")
			key(KEY_D, true)
			await create_timer(0.45).timeout
			key(KEY_D, false)
			key(KEY_E, false)
			key(KEY_O, false)
			await physics_frame
			check(shop.charge == 0 and shop.s.phase == "mix" and shop.s.delivered == [1, 1, 0, 0, 0], "Walking away resets processing but preserves ingredients")
			game.players[0].position = Vector2(shop.MIX_LEFT, 600)
			game.players[0].velocity = Vector2.ZERO
		key(KEY_E, true)
		key(KEY_O, true)
		await create_timer(2.05).timeout
		key(KEY_E, false)
		key(KEY_O, false)
		await physics_frame
		check(shop.s.phase == "ready", "Order %d completes processing under normal physics, swapped roles supported" % order)
		use_at(left, 650)
		check(shop.s.phase == "serve" and shop.s.hands[left] == "ice", "Order %d finished ice cream can be collected" % order)
		use_at(left, 1060)
		check(shop.s.phase == "change" and shop.s.hands[left] == "", "Order %d reaches customer and receives tender %d" % [order, shop.tender()])
		var change: int = shop.tender() - 5
		if change > 0:
			use_at(right, 1060)
			check(shop.s.phase == "change", "Order %d wrong change can be corrected without completing" % order)
		for n in range(change):
			use_at(right, 790)
		use_at(right, 1060)
		check(shop.s.phase == "celebrate" and shop.s.served == order + 1 and shop.s.wallet == 6 + 2 * (order + 1), "Order %d settles once with exact wallet and profit" % order)
		if order < 2:
			use_at(left, 1060)
			check(shop.s.phase == "offer" and shop.s.delivered == [0, 0, 0, 0, 0], "Next order resets ingredients after completed sale")
	game.queue_free()
	await process_frame
	print("SHOP_JOURNEY_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
