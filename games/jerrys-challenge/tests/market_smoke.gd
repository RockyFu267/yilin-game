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

func manufacture() -> void:
	travel()
	for n in range(2):
		use_at(n, shop.supply_x(n))
		for coin in range(n + 1): use_at(n, 790)
		use_at(n, 1060)
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

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	shop = game.learning
	game.show_names(true)
	game.name_fields[0].text = "Jerry"
	game.name_fields[1].text = "小伙伴"
	for button in game.menu.get_children():
		if button is Button and button.text == "保存名字": button.pressed.emit(); break
	check(game.mode == "select" and game.player_name(0) == "Jerry" and game.player_name(1) == "小伙伴", "Names can be edited and saved independently of left/right keyboard and selected skin")
	check(game.players[0].display_name == "Jerry" and game.players[1].display_name == "小伙伴" and game.selected == [5, 4], "Renaming updates character labels without changing appearances")
	var saved_home = game.HomeScript.new(game)
	check(saved_home.state.player_names == ["Jerry", "小伙伴"], "Player names survive disk reload")
	shop.market_rng.seed = 20261025
	shop.start("shop")
	check(shop.s.phase == "offer", "Fresh customers quote before ingredients or production")
	var bids: Dictionary = {}
	var cashes: Dictionary = {}
	var last_cash := -1
	var streak := 0
	var valid := true
	for n in range(1000):
		var bid: int = shop.price()
		var cash: int = shop.tender()
		bids[bid] = true
		cashes[cash] = true
		streak = streak + 1 if cash == last_cash else 1
		last_cash = cash
		valid = valid and bid >= 1 and bid <= 10 and cash >= bid and cash <= 10 and streak <= 2
		use_at(0, 910)
	check(valid and bids.size() == 10 and cashes.size() >= 5, "1000 random offers cover 1–10 with valid varied tender and no three identical payments in a row")
	check(shop.s.wallet == 6 and shop.s.stock == [0, 0, 0, 0, 0] and shop.s.served == 0, "Declining customers costs no money or ingredients and does not count as a sale")
	var expected := 6
	var prices := [1, 2, 3, 4, 6, 10]
	var payments := [2, 5, 3, 7, 9, 10]
	for n in range(prices.size()):
		shop.s.recipe = [0, 1]
		shop.s.bid = prices[n]
		shop.s.cash = payments[n]
		use_at(1, 1060)
		check(shop.s.phase == "ingredients" and shop.price() == prices[n], "Accepts chosen %d-yuan offer, including optional loss or break-even deals" % prices[n])
		var agreed: int = shop.price()
		var paid: int = shop.tender()
		shop.next_customer()
		check(shop.price() == agreed and shop.tender() == paid, "Accepted price and tender cannot change during production")
		manufacture()
		check(shop.s.phase == "change" and shop.price() == prices[n], "Production and delivery retain the agreed selling price")
		var change: int = payments[n] - prices[n]
		if change > 0:
			use_at(0, 1060)
			check(shop.s.phase == "change", "Wrong change does not prematurely settle a variable-price order")
		for coin in range(change): use_at(1, 790)
		use_at(0, 1060)
		expected += prices[n] - 3
		check(shop.s.phase == "celebrate" and shop.s.wallet == expected and shop.s.served == n + 1 and game.home.state.wallet == expected, "Order %d settles real profit/loss and shared wallet exactly once" % prices[n])
		use_at(1, 1060)
		check(shop.s.phase == "offer", "After settlement, next customer waits for a fresh accept/reject decision")
	# New household goods use original code-drawn art, no paid pack required.
	game.home.toggle_unlimited()
	game.home.enter("furniture")
	var first_position: Vector2 = game.home.positions[0]
	var first_wallet: int = game.home.state.wallet
	var first_inventory: int = game.home.state.items.size()
	for button in game.menu.get_children():
		if button is Button and button.text == "下一页 →": button.pressed.emit(); break
	check(game.home.display_page == 1, "Independent header mouse button switches furniture product page")
	check(game.home.positions[0] == first_position and game.home.state.wallet == first_wallet and game.home.state.items.size() == first_inventory, "Paging neither moves players nor buys products or charges money")
	for button in game.menu.get_children():
		if button is Button and button.text == "← 上一页": button.pressed.emit(); break
	check(game.home.display_page == 0, "Independent previous-page button returns to first product page")
	game.home.turn_page(1)
	for kind in ["tv", "plate", "cutlery", "cup", "fan", "kettle", "dining_chair"]:
		var index := -1
		for n in range(game.home.GOODS.size()):
			if game.home.GOODS[n].id == kind: index = n
		game.home.positions[0] = game.home.display_pos(index)
		game.home.use(0)
		check(game.home.inventory_count(kind) == 1 and game.home.art_texture(kind) != null, "New product can be bought and rendered: " + kind)
	game.home.buy(0, "table")
	game.home.enter()
	game.home.take_kind(0, "dining_chair")
	game.home.rotate(0)
	check(game.home.place(0, Vector2i(3, 4)) and game.home.good("dining_chair").art.size() == 4, "Additional dining chair can be purchased, rotated and placed independently of the original chair")
	game.home.take_kind(0, "table")
	check(game.home.place(0, Vector2i(5, 2)), "Dining table can be placed for small household accessories")
	for pair in [["plate", Vector2i(5, 2)], ["cup", Vector2i(6, 2)], ["cutlery", Vector2i(7, 2)], ["kettle", Vector2i(5, 3)]]:
		game.home.take_kind(0, pair[0])
		var uid: int = game.home.hands[0]
		check(game.home.place(0, pair[1]) and game.home.furniture_depth(game.home.item(uid)) > 416, "Small accessory can sit visibly on the dining table: " + pair[0])
	game.home.bag_choice = 8
	game.home.bag_menu(0, false)
	var visible := 0
	for node in game.menu.get_children():
		if node is Button and ("电视机" in node.text or "水壶" in node.text): visible += 1
	check(visible == 2, "Furniture inventory paginates and shows new products without pushing controls offscreen")
	for button in game.menu.get_children():
		if button is Button and button.text == "上一页": button.pressed.emit(); break
	check(game.home.bag_choice == 0, "Inventory previous-page button returns to page one")
	for button in game.menu.get_children():
		if button is Button and button.text == "下一页": button.pressed.emit(); break
	check(game.home.bag_choice == 8, "Inventory next-page button reaches page two")
	var legacy: Dictionary = shop.s.duplicate(true)
	for field in ["deal_version", "bid", "cash"]: legacy.erase(field)
	legacy.phase = "change"
	legacy.order = 2
	legacy.tray = 2
	game.home.state.shop = legacy
	shop.start("shop")
	check(shop.price() == 5 and shop.tender() == 10 and shop.s.phase == "change" and shop.s.tray == 2, "Legacy in-progress five-yuan order migrates without changing its agreed price or refund tray")
	game.queue_free()
	await process_frame
	print("MARKET_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
