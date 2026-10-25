extends SceneTree

const Store = preload("res://scripts/save_store.gd")
var game
var failures := 0

func _initialize() -> void:
	if not Store.automated_run_safe():
		push_error("Persistence test requires isolated QA storage.")
		quit(2)
		return
	run.call_deferred()

func check(ok: bool, caption: String) -> void:
	if ok: print("PASS: " + caption)
	else:
		failures += 1
		push_error("FAIL: " + caption)

func apply_money(value: String) -> void:
	game.show_settings()
	game.money_input.get_line_edit().text = value
	for button in game.menu.get_children():
		if button is Button and button.text == "应用金额":
			button.pressed.emit()
			return

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	apply_money("250")
	check(game.home.state.wallet == 250, "Settings input applies a typed exact wallet amount")
	game.learning.start("shop")
	game.learning.s.recipe = [0, 1]
	game.learning.accept_offer()
	game.home.state.items.append({"uid": 99, "kind": "sofa", "room": "home", "cell": [2, 1], "dir": 1})
	game.home.state.next_uid = 100
	game.home.save()
	var business: Dictionary = game.home.state.shop.duplicate(true)
	apply_money("1234")
	check(game.home.state.wallet == 1234 and game.learning.s.wallet == 1234 and game.home.state.shop.wallet == 1234, "Configured amount synchronizes ordinary, live business and saved business wallets")
	check(game.home.state.items.size() == 1 and game.home.item(99).room == "home" and game.home.item(99).dir == 1, "Configuring money preserves house placement and furniture ownership")
	check(game.learning.s.phase == business.phase and game.learning.recipe() == business.recipe, "Configuring money preserves the current customer and recipe")
	var restored = game.HomeScript.new(game)
	check(restored.state.wallet == 1234 and int(restored.item(99).cell[0]) == 2 and int(restored.item(99).cell[1]) == 1, "Exact configured wallet and decorated house survive a new loader instance")
	game.home.toggle_unlimited()
	apply_money("0")
	check(game.home.state.wallet == 0 and game.home.unlimited(), "Zero balance is supported without changing the unlimited switch")
	apply_money("400")
	var path: String = game.home.SAVE
	var absolute := ProjectSettings.globalize_path(path)
	Store.session_backed_up.erase(absolute)
	game.home.save()
	var backups := absolute.get_base_dir().path_join("backups")
	check(not DirAccess.get_files_at(backups).is_empty(), "First save of a launch preserves an additional session backup")
	var before: Dictionary = Store.read_json(path + ".bak")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("{broken-json")
	damaged.close()
	Store.session_backed_up.erase(absolute)
	restored = game.HomeScript.new(game)
	check(restored.state.wallet == before.wallet and restored.state.items.size() == before.items.size() and not restored.storage_notice.is_empty(), "Damaged primary falls back to a valid wallet and furniture backup with a notice")
	restored.save()
	check(Store.valid_family(Store.read_json(path)), "Recovery writes a complete valid primary via temporary file replacement")
	var damaged_preserved := false
	for name in DirAccess.get_files_at(backups):
		damaged_preserved = damaged_preserved or name.begins_with("damaged_family_home_")
	check(damaged_preserved, "Damaged original is preserved separately instead of silently discarded")
	var first_backup = Store.read_json(path + ".bak2")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	corrupt = FileAccess.open(path + ".bak", FileAccess.WRITE)
	corrupt.store_string("broken too")
	corrupt.close()
	var fallback := Store.read_family(path)
	check(fallback.recovered and fallback.data == first_backup, "Second known-good backup is available when primary and first backup are damaged")
	# Restore a valid primary before closing this isolated test profile.
	Store.session_backed_up.erase(absolute)
	Store.write_family(path, fallback.data)
	check(not absolute.contains("/builds/") and absolute.begins_with(OS.get_environment("YILIN_GAME_QA_DIR").replace("\\", "/")), "Persistence path is independent of build version and contained in the isolated test directory")
	game.queue_free()
	await process_frame
	print("SAVE_PERSISTENCE_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
