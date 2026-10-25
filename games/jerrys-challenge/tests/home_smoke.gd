extends SceneTree

var game
var home
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

func sell_one() -> void:
	shop.s.recipe = [0, 1]
	shop.s.bid = 5
	shop.s.cash = [5, 8, 10][mini(shop.s.served, 2)]
	shop.accept_offer()
	travel()
	for kind in range(2):
		use_at(kind, shop.supply_x(kind))
		for coin in range(kind + 1): use_at(kind, 790)
		use_at(kind, 1060)
	travel()
	use_at(0, 320)
	use_at(1, 480)
	use_at(0, 650)
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
	for n in range(shop.tender() - 5): use_at(1, 790)
	use_at(1, 1060)

func door(index: int) -> void:
	var pos: Vector2 = home.cell_center(Vector2i(4 if index == 0 else 13, 7))
	home.positions[0] = pos - Vector2(15, 0)
	home.positions[1] = pos + Vector2(15, 0)
	home.use(0)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	home = game.home
	shop = game.learning
	check(home.atlas != null and home.state.items.is_empty(), "Home starts empty with the licensed local furniture atlas")
	var valid_art := true
	for good in home.GOODS:
		for rect in good.art:
			valid_art = valid_art and rect[0] >= 0 and rect[1] >= 0 and rect[0] + rect[2] <= 256 and rect[1] + rect[3] <= 176
	check(valid_art and home.good("chair").art.size() == 4 and home.good("sofa").art.size() == 2, "Furniture uses valid atlas rectangles and genuine alternate views")
	shop.start("shop")
	for order in range(4):
		sell_one()
		check(shop.s.served == order + 1 and home.state.wallet == 6 + 2 * (order + 1), "Ice cream order %d contributes real profit to shared wallet" % order)
		if order < 3: use_at(0, 1060)
	use_at(0, 210)
	check(game.mode == "learning", "Home doorway waits for both partners")
	game.players[1].position = Vector2(225, 600)
	game.players[1].velocity = Vector2.ZERO
	use_at(0, 210)
	check(game.mode == "home" and home.room == "home" and not game.players[0].active, "Physical shop doorway switches from platforming to top-down home")
	var before: Vector2 = home.positions[0]
	Input.action_press("home_p1_up")
	Input.action_press("home_p2_down")
	await create_timer(0.15).timeout
	Input.action_release("home_p1_up")
	Input.action_release("home_p2_down")
	check(home.positions[0].y < before.y - 10 and home.positions[1].y > before.y and not game.paused, "Both top-down vertical inputs work; Down no longer triggers an interaction")
	door(0)
	check(home.room == "furniture", "Home floor doorway leads to furniture store")
	for kind in ["sofa", "chair", "rug", "plant"]:
		check(home.buy(0, kind), "Purchase " + kind + " from real earnings")
	check(home.state.wallet == 3 and shop.s.wallet == 3 and home.state.items.size() == 4, "Purchases deduct once and synchronize shop wallet and furniture ownership")
	check(not home.buy(1, "plant") and home.state.wallet == 3 and home.state.items.size() == 4, "Insufficient decorating funds preserves fruit money without creating furniture")
	door(0)
	check(home.room == "home", "Furniture store doorway returns to empty home")
	home.positions[0] = home.cell_center(Vector2i(5, 6))
	home.positions[1] = home.cell_center(Vector2i(12, 6))
	check(home.take_kind(0, "sofa"), "Owner takes purchased sofa from bag")
	var sofa_uid: int = home.hands[0]
	check(not home.take_kind(1, "sofa"), "Partner cannot take the same held sofa")
	home.rotate(0)
	check(home.directions[0] == 1, "Sofa changes to its authored second view")
	check(home.place(0, Vector2i(5, 3)) and home.item(sofa_uid).dir == 1, "Grid placement persists sofa position and direction")
	check(not home.walkable(home.cell_center(Vector2i(6, 3))), "Placed solid sofa blocks player feet")
	home.positions[0] = home.cell_center(Vector2i(4, 3))
	Input.action_press("p1_right")
	await create_timer(0.35).timeout
	Input.action_release("p1_right")
	check(home.positions[0].x < home.item_rect(home.item(sofa_uid)).position.x, "Real movement cannot walk through sofa collision")
	check(home.pickup(0, sofa_uid) and not home.pickup(1, sofa_uid), "Placed furniture can be moved by one player at a time")
	check(home.walkable(home.cell_center(Vector2i(6, 3))), "Picking up furniture frees its old collision footprint")
	check(home.place(0, Vector2i(2, 0)), "Sofa can be placed elsewhere without another payment")
	home.positions[0] = home.cell_center(Vector2i(5, 6))
	home.positions[1] = home.cell_center(Vector2i(12, 6))
	home.take_kind(0, "chair")
	home.take_kind(1, "plant")
	var chair_uid: int = home.hands[0]
	for n in range(3): home.rotate(0)
	check(home.directions[0] == 3, "Chair supports four actual artwork directions")
	check(not home.place(0, Vector2i(-1, 0)) and not home.place(0, Vector2i(4, 7)) and home.hands[0] == chair_uid, "Invalid positions and exit corridor reject placement without losing held furniture")
	check(not home.place(0, Vector2i(5, 6)), "Furniture cannot be placed over a player's feet")
	check(home.place(0, Vector2i(10, 2)) and not home.place(1, Vector2i(10, 2)), "Simultaneous decoration rechecks occupied cells at placement time")
	check(home.place(1, Vector2i(14, 2)), "Partner retains rejected item and can choose a free position")
	home.take_kind(0, "rug")
	check(home.place(0, Vector2i(9, 1)) and home.walkable(home.cell_center(Vector2i(9, 1))), "Rug can sit under furniture and remains walkable")
	var expected = JSON.parse_string(JSON.stringify(home.state))
	var reloaded = game.HomeScript.new(game)
	check(reloaded.state == expected, "Wallet, all purchased furniture, placements and directions survive disk reload")
	home.positions[0] = home.cell_center(Vector2i(1, 0))
	home.positions[1] = home.cell_center(Vector2i(15, 3))
	var store_key := InputEventKey.new()
	store_key.physical_keycode = KEY_Q
	store_key.pressed = true
	Input.parse_input_event(store_key)
	await process_frame
	check(home.item(sofa_uid).room == "inventory" and home.hands[0] == -1 and not game.paused, "Q directly returns highlighted placed sofa to inventory without pickup or a menu")
	store_key.pressed = false
	Input.parse_input_event(store_key)
	store_key = InputEventKey.new()
	store_key.physical_keycode = KEY_BACKSPACE
	store_key.pressed = true
	Input.parse_input_event(store_key)
	await process_frame
	check(home.inventory_count("plant") == 1 and home.hands[1] == -1, "P2 Backspace directly stores placed furniture")
	store_key.pressed = false
	Input.parse_input_event(store_key)
	check(home.state.wallet == 3 and home.state.items.size() == 4 and home.walkable(home.cell_center(Vector2i(2, 0))), "Storing preserves ownership and money and frees floor collision")
	home.take_kind(0, "sofa")
	home.rotate(0)
	check(home.store_nearby(0) and home.inventory_count("sofa") == 1 and home.hands[0] == -1, "Held furniture can be stored and becomes available again")
	reloaded = game.HomeScript.new(game)
	check(reloaded.state.items[0].room == "inventory", "Returned furniture remains in inventory after disk reload")
	shop.resume_saved()
	check(shop.s.wallet == 3 and shop.s.served == 4 and shop.s.phase == "celebrate", "Legacy shop continue cannot roll back money spent decorating")
	shop.retry()
	check(shop.s.wallet == 3 and home.state.wallet == 3 and home.state.items.size() == 4, "Shop retry cannot mint startup money or delete home purchases")
	shop.start("shop")
	check(shop.s.wallet == 3 and shop.s.served == 4, "Starting shop again resumes exact household business state")
	home.enter()
	home.positions[0] = home.cell_center(Vector2i(8, 6))
	home.positions[1] = home.cell_center(Vector2i(10, 6))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_O
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(game.paused and home.menu_kind == "bag" and home.bag_owner == 1, "P2 O opens furniture bag independently of movement keys")
	event.pressed = false
	Input.parse_input_event(event)
	home.escape()
	door(1)
	check(game.mode == "learning" and shop.s.wallet == 3 and shop.s.phase == "celebrate", "Returning through house door restores platforming and original shop order")
	game.queue_free()
	await process_frame
	print("HOME_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
