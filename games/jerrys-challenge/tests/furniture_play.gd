extends SceneTree

var failures := 0
func check(ok: bool, caption: String) -> void:
	if ok: print("PASS: " + caption)
	else:
		failures += 1
		push_error("FAIL: " + caption)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var home = game.home
	home.state.items = [{"uid": 1, "kind": "bed", "room": "home", "cell": [4, 2], "dir": 0}, {"uid": 2, "kind": "dining_chair", "room": "home", "cell": [10, 4], "dir": 0}]
	home.enter()
	var wallet: int = home.state.wallet
	home.positions[0] = Vector2(home.item_rect(home.item(1)).get_center().x, home.item_rect(home.item(1)).end.y + 24)
	home.use(0)
	check(home.play[0].get("pose") == "stand", "E near bed mounts it instead of moving furniture")
	home.use(0)
	check(home.play[0].get("pose") == "sleep", "Second E tucks player under blanket")
	home.use_furniture(1, 1)
	check(home.play[1].is_empty(), "Occupied furniture cannot be shared or stolen")
	check(not home.pickup(1, 1), "Sleeping furniture cannot be picked up by partner")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	home.input(key)
	check(home.play[0].pose == "stand" and home.play[0].jump > 0, "W wakes sleeper and starts a jump")
	home.tick(0.8)
	check(home.play[0].jump == 0, "Jump lands back on furniture")
	home.use_furniture(1, 2)
	check(home.play[1].pose == "sit", "Partner can sit independently on chair")
	home.use(1)
	check(home.play[1].pose == "stand", "O switches chair from sitting to standing")
	key.physical_keycode = KEY_UP
	home.input(key)
	check(home.play[1].jump > 0, "Up starts partner chair jump")
	Input.action_press("p1_left")
	home.tick(0.016)
	Input.action_release("p1_left")
	check(home.play[0].is_empty() and home.walkable(home.positions[0]), "Directional movement exits onto safe floor")
	home.positions[0] = home.positions[1]
	check(home.store_nearby(0) and home.item(2).room == "home", "Cannot store furniture while partner is using it")
	home.store_nearby(1)
	check(home.play[1].is_empty() and home.item(2).room == "inventory", "Owner can leave and store their chair")
	check(home.state.wallet == wallet, "Furniture play costs no money")
	home.pack_all()
	check(home.play[0].is_empty() and home.play[1].is_empty(), "Scene transitions clear transient poses")
	game.queue_free()
	await process_frame
	print("FURNITURE_PLAY_RESULT: %d failure(s)" % failures)
	quit(1 if failures else 0)
