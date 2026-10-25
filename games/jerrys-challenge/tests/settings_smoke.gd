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

func click(text: String) -> bool:
	for button in game.menu.get_children():
		if button is Button and button.text.begins_with(text):
			button.pressed.emit()
			return true
	return false

func use_at(x: float) -> void:
	game.players[0].position = Vector2(x, 600)
	game.players[0].velocity = Vector2.ZERO
	shop.use(0)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	home = game.home
	shop = game.learning
	check(click("设置") and game.mode == "settings", "Settings are available directly on outer title screen")
	check(not home.unlimited(), "Unlimited money defaults off")
	check(click("钱袋增加") and home.state.wallet == 16, "Visible settings button adds ten to ordinary wallet")
	check(click("重置钱袋") and home.state.wallet == 6, "Visible reset button restores six")
	game.show_title()
	shop.start("shop")
	shop.s.room = "supply"
	use_at(330)
	use_at(790)
	check(shop.s.wallet == 5 and shop.s.tray == 1, "Normal mode pays a real coin")
	game.show_settings()
	check(click("无限金钱") and home.unlimited(), "Settings switch enables unlimited mode")
	shop.start("shop")
	use_at(790)
	use_at(790)
	use_at(910)
	use_at(910)
	use_at(910)
	check(shop.s.wallet == 6 and shop.s.tray == 0, "Mixed ordinary and free coins refund only genuinely paid money")
	use_at(790)
	use_at(1060)
	check(shop.s.stock == [1, 0] and shop.s.wallet == 6, "Unlimited ingredient purchase keeps exact-payment puzzle without charging wallet")
	home.set_money(0, true)
	use_at(510)
	use_at(790)
	use_at(790)
	use_at(1060)
	check(shop.s.stock == [1, 1] and shop.s.wallet == 0 and home.state.wallet == 0, "Unlimited mode can purchase fruit at zero ordinary balance")
	home.enter("furniture")
	check(home.buy(0, "bed") and home.state.wallet == 0 and home.state.items.size() == 1, "Unlimited furniture bypasses reserve and charges no hidden balance")
	var loaded = game.HomeScript.new(game)
	check(loaded.unlimited() and loaded.state.wallet == 0 and loaded.state.items.size() == 1, "Unlimited setting and real balance persist across reload")
	game.show_settings()
	click("无限金钱")
	home.enter("furniture")
	check(not home.buy(1, "plant") and home.state.wallet == 0, "Disabling unlimited restores actual insufficient balance rules")
	game.show_settings()
	click("钱袋增加")
	shop.start("shop")
	check(shop.s.wallet == 10 and shop.s.stock == [1, 1], "Settings money synchronizes with saved and active shop without resetting inventory")
	shop.s.room = "supply"
	# Simulate pending payment from a later order, then use the actual reset UI.
	shop.s.stock = [0, 0]
	shop.persist()
	use_at(330)
	use_at(790)
	game.show_settings()
	click("重置钱袋")
	check(home.state.wallet == 6 and shop.s.wallet == 6 and shop.s.tray == 0 and shop.s.purchase == -1 and home.state.items.size() == 1, "Reset clears pending payment without deleting purchased home furniture")
	shop.resume_saved()
	check(shop.s.wallet == 6 and shop.s.tray == 0 and shop.s.purchase == -1, "Old shop save cannot undo money reset or restore refundable escrow")
	home.enter("furniture")
	home.buy(0, "chair")
	home.buy(0, "plant")
	home.enter()
	home.state.items[0].room = "home"
	home.state.items[0].cell = [2, 1]
	home.take_kind(0, "chair")
	var balance: int = home.state.wallet
	var business := JSON.stringify(home.state.shop)
	check(home.state.items.size() == 3 and home.inventory_count("plant") == 1, "Reset fixture includes placed, held and unused inventory furniture")
	game.show_settings()
	check(click("重置小家装饰"), "Decoration reset is available on outer settings page")
	check(home.hands == [-1, -1] and home.state.items.is_empty() and home.inventory_count("plant") == 0, "Decoration reset deletes placed, held and unused inventory furniture")
	check(home.state.wallet == balance and JSON.stringify(home.state.shop) == business, "Decoration reset preserves money and business state")
	var restored = game.HomeScript.new(game)
	check(restored.state.items.is_empty(), "Full furniture wipe persists after disk reload")
	click("重置小家装饰")
	check(home.state.items.is_empty() and home.state.wallet == balance, "Repeated decoration reset keeps inventory empty and preserves money")
	game.queue_free()
	await process_frame
	print("SETTINGS_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
