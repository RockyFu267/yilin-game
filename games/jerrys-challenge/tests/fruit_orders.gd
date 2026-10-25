extends SceneTree

var game
var shop
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, caption: String) -> void:
	if ok: print("PASS: " + caption)
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

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	shop = game.learning
	shop.start("shop")
	var order: int = shop.s.order
	use_at(0, 910)
	check(shop.s.phase == "offer" and shop.s.order == order + 1, "First fresh launch immediately permits next customer")
	var legacy: Dictionary = shop.s.duplicate(true)
	legacy.erase("accepted_offer")
	legacy.erase("recipe")
	legacy.phase = "ingredients"
	legacy.room = "supply"
	legacy.stock = [0, 0]
	legacy.delivered = [0, 0]
	game.home.state.shop = legacy
	shop.start("shop")
	check(shop.s.phase == "offer" and shop.s.room == "shop" and shop.s.stock.size() == 5, "Untouched legacy order resumes at quote counter with next-customer choice")
	order = shop.s.order
	use_at(1, 910)
	check(shop.s.order == order + 1, "Next customer also works after legacy first-launch migration")
	legacy = shop.s.duplicate(true)
	legacy.erase("accepted_offer")
	legacy.erase("recipe")
	legacy.phase = "ingredients"
	legacy.stock = [1, 0]
	legacy.delivered = [0, 0]
	game.home.state.shop = legacy
	shop.start("shop")
	check(shop.s.phase == "ingredients" and shop.recipe() == [0, 1] and shop.s.stock == [1, 0, 0, 0, 0], "Already purchased legacy ingredients retain their accepted order and expand safely")
	shop.s.phase = "offer"
	shop.s.stock = [0, 0, 0, 0, 0]
	var combinations: Dictionary = {}
	var valid := true
	for n in range(600):
		shop.next_customer()
		var pair: Array = shop.recipe()
		combinations[str(pair)] = true
		valid = valid and pair.size() == 2 and pair[0] != pair[1] and pair[0] >= 0 and pair[1] < 5 and shop.recipe_cost() <= 9
		valid = valid and not "=" in shop.cost_expression() and shop.recipe_names() in shop.message and not "= " in shop.message
	check(valid and combinations.size() == 10, "Random customers request all ten two-fruit combinations; displayed costs contain only addends")
	check(shop.FRUITS.size() == 5 and shop.FRUITS[2].price == 3 and shop.FRUITS[3].price == 4 and shop.FRUITS[4].price == 5, "Three extra fruits have requested prices three, four and five")
	game.home.set_money(100, true)
	var expected := 100
	for a in range(5):
		for b in range(a + 1, 5):
			shop.s.phase = "offer"
			shop.s.recipe = [a, b]
			shop.s.bid = 10
			shop.s.cash = 10
			shop.accept_offer()
			travel()
			var wrong := (b + 1) % 5
			if wrong == a: wrong = (wrong + 1) % 5
			use_at(0, shop.supply_x(wrong))
			check(shop.s.purchase == -1, "Wrong flavor selection cannot charge money for order %d+%d" % [a, b])
			for n in range(2):
				var fruit: int = [a, b][n]
				use_at(n, shop.supply_x(fruit))
				for coin in range(fruit + 1): use_at(n, 790)
				use_at(n, 1060)
			travel()
			use_at(0, 320)
			use_at(1, 480)
			check(shop.s.hands == [shop.FRUITS[a].id, shop.FRUITS[b].id], "Correct flavors can be carried for order %d+%d" % [a, b])
			use_at(0, 650)
			check(shop.s.phase == "ingredients", "One requested fruit alone cannot start processing")
			use_at(1, 650)
			game.players[0].position = Vector2(shop.MIX_LEFT, 600)
			game.players[1].position = Vector2(shop.MIX_RIGHT, 600)
			Input.action_press("p1_use")
			Input.action_press("p2_use")
			shop.tick(1.9)
			Input.action_release("p1_use")
			Input.action_release("p2_use")
			use_at(0, 650)
			use_at(0, 1060)
			use_at(1, 1060)
			expected += 10 - (a + 1) - (b + 1)
			check(shop.s.phase == "celebrate" and shop.s.wallet == expected and not " = %d 元" % shop.recipe_cost() in shop.message, "Order %d+%d charges true combination cost and settles without printing its answer" % [a, b])
			use_at(0, 1060)
	shop.s.recipe = [3, 4]
	shop.accept_offer()
	travel()
	use_at(0, shop.supply_x(4))
	for n in range(3): use_at(0, 790)
	shop.persist()
	var wallet: int = shop.s.wallet
	shop.s.recipe = [0, 1]
	shop.resume_saved()
	check(shop.recipe() == [3, 4] and shop.s.purchase == 4 and shop.s.tray == 3 and shop.s.wallet == wallet, "Save restores new fruit recipe, selected five-yuan fruit and partial payment")
	for n in range(2): use_at(0, 790)
	use_at(0, 1060)
	check(shop.s.stock[4] == 1 and shop.s.wallet == wallet - 2, "Resumed five-yuan purchase completes once for the remaining two coins")
	game.queue_free()
	await process_frame
	print("FRUIT_ORDERS_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
