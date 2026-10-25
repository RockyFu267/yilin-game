extends SceneTree

var failures: int = 0
var game

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func use_at(player: int, x: float) -> void:
	game.players[player].position = Vector2(x, 600)
	game.interact(player)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.mode == "title" and game.SKINS.size() == 6, "Title loads with six selectable characters")
	var use_o := InputEventKey.new()
	use_o.physical_keycode = KEY_O
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	check(InputMap.action_has_event("p2_use", use_o) and not InputMap.action_has_event("p2_use", down), "P2 interaction uses O and never the Down movement key")
	for skin in range(game.SKINS.size()):
		game.players[0].set_skin(skin)
		var valid := true
		for animation in ["Idle", "Run", "Jump", "Fall"]:
			var texture: Texture2D = game.players[0].sheets[animation]
			valid = valid and texture != null and texture.get_height() == 32 and texture.get_width() % 32 == 0
		check(valid, "All animation strips load for " + game.SKINS[skin])
	check(game.players[0].display_name == "Tom" and game.players[1].display_name == "Jerry", "Player names are Tom and Jerry, independent of family roles")
	check(game.fruit_foreground.z_index > maxi(game.players[0].z_index, game.players[1].z_index) and game.fruit_foreground.z_index < game.menu.z_index, "Fruit renders above both players and below menu controls")
	game.show_select()
	game._cycle(0, 1)
	game._cycle(1, -1)
	check(game.selected == [0, 3], "Each player independently cycles skins")
	game._confirm(0)
	game._confirm(1)
	check(game.confirmed == [true, true], "Both players can ready independently")
	game._confirm(0)
	check(game.mode == "game" and game.stage == 0, "Both confirmations enter tutorial")
	await create_timer(0.2).timeout
	var start_x: float = game.players[0].position.x
	Input.action_press("p1_right")
	Input.action_press("p2_right")
	await create_timer(0.3).timeout
	Input.action_release("p1_right")
	Input.action_release("p2_right")
	check(game.players[0].position.x > start_x + 30, "Physics moves P1 using independent input")
	check(game.players[1].position.x > 230, "Physics moves P2 concurrently")
	Input.action_press("p2_jump")
	await physics_frame
	await physics_frame
	Input.action_release("p2_jump")
	check(game.players[1].velocity.y < 0, "P2 jump input works")
	game.players[0].position.x = 870
	game.players[1].position.x = 870
	game._tick_game()
	check(not game.solved, "Two players on same pad cannot solve tutorial")
	game.players[1].position.x = 1030
	game._tick_game()
	check(game.solved, "Separate occupied pads unlock exit")
	game.players[0].position.x = 1200
	game._tick_game()
	check(game.stage == 0, "One player cannot leave partner behind")
	game.players[1].position.x = 1200
	game._tick_game()
	check(game.stage == 1, "Both players at exit enter fruit puzzle")
	use_at(0, 300)
	check(game.players[0].carrying and game.apples.size() == 2, "Pick up one apple")
	use_at(0, 400)
	check(not game.players[0].carrying and game.apples.size() == 3, "Dropped apple remains recoverable")
	use_at(1, 440)
	use_at(1, 780)
	use_at(0, 600)
	use_at(0, 780)
	use_at(1, 1010)
	use_at(1, 780)
	check(game.deposited == 3 and game.apples.is_empty(), "All three apples can be collected and deposited")
	use_at(0, 1010)
	Input.action_press("p1_use")
	game._tick_game(1.0)
	check(game.handles[0] and not game.handles[1] and game.hold_charge == 0, "A single held lever lights its circuit without advancing master")
	Input.action_release("p1_use")
	game._tick_game(0.1)
	check(not game.handles[0], "Released fruit lever springs back")
	game.players[1].position.x = 1140
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	game._tick_game(0.6)
	check(not game.solved and game.hold_charge > 0, "Both players must maintain simultaneous lever hold")
	game.players[0].position.x = 900
	game._tick_game(0.1)
	check(game.hold_charge == 0 and not game.handles[0], "Walking away restores lever and resets joint progress")
	game.players[0].position.x = 1010
	game.players[0].velocity.y = -150
	game._tick_game(0.1)
	check(not game.handles[0] and game.hold_charge == 0, "Jumping cannot keep a ground lever held")
	game.players[0].velocity.y = 0
	game._tick_game(game.HOLD_SECONDS)
	Input.action_release("p1_use")
	Input.action_release("p2_use")
	check(game.solved, "Sustained simultaneous fruit levers latch master switch")
	game.start_game(2)
	check(game.barriers.size() == 2 and game.barriers[0].collision_layer == 1, "Bridge starts physically blocked")
	game.players[1].position = Vector2(460, 600)
	Input.action_press("p2_right")
	await create_timer(0.4).timeout
	Input.action_release("p2_right")
	check(game.players[1].position.x < 485, "Closed bridge physically blocks player traversal")
	use_at(0, 280)
	check(game.crank_by == 0 and game.barriers[0].collision_layer == 0, "Crank permanently opens first route")
	Input.action_press("p2_right")
	await create_timer(0.4).timeout
	Input.action_release("p2_right")
	check(game.players[1].position.x > 520, "Player traverses opened bridge using normal physics")
	use_at(0, 765)
	check(not game.solved, "Crank operator must let partner relay")
	use_at(1, 765)
	check(game.solved and game.barriers[1].collision_layer == 0, "Partner opens second route")
	game.start_game(3)
	game.players[0].position.x = 460
	game.players[1].position.x = 820
	Input.action_press("p1_use")
	game._tick_game(2.0)
	check(game.lights[0] and not game.lights[1] and not game.solved, "One player cannot permanently power both lights")
	Input.action_release("p1_use")
	Input.action_press("p2_use")
	game._tick_game(0.5)
	check(not game.lights[0] and game.lights[1] and game.hold_charge == 0, "Sequential holds cannot substitute for simultaneous cooperation")
	Input.action_press("p1_use")
	game._tick_game(0.5)
	Input.action_release("p2_use")
	game._tick_game(0.1)
	check(not game.solved and game.hold_charge == 0 and not game.lights[1], "Releasing either lever resets unfinished master")
	Input.action_press("p2_use")
	game._tick_game(0.5)
	game._toggle_pause()
	check(game.hold_charge == 0 and not game.lights[0], "Pause clears unfinished held levers")
	game._toggle_pause()
	game._tick_game(game.HOLD_SECONDS)
	Input.action_release("p1_use")
	Input.action_release("p2_use")
	game._tick_game(0.1)
	check(game.solved and game.lights[0] and game.lights[1], "Completed master stays latched after both release")
	use_at(0, 1060)
	check(game.mode == "game", "Picnic waits for both partners")
	use_at(1, 1110)
	check(game.mode == "ending", "Complete journey reaches ending")
	game._stay()
	check(game.mode == "garden" and not game.players[0].seated, "Stay in garden allows free movement")
	game.start_game(1)
	game._toggle_pause()
	check(not game.players[0].is_physics_processing(), "Pause stops physics")
	game._toggle_pause()
	check(game.players[0].is_physics_processing() and game.players[0].visible, "Resume restores movement and visibility")
	game.resume_game()
	check(game.stage == 1 and game.deposited == 0 and game.apples.size() == 3, "Save resumes at a clean checkpoint")
	game.selected.assign([5, 4])
	game.start_game(1)
	game.selected.assign([0, 0])
	game.resume_game()
	check(game.selected == [5, 4] and game.players[0].skin == 5 and game.players[1].skin == 4, "Save restores the new Tom and Jerry appearances")
	game.start_game(0)
	check(game.stage == 0 and not game.solved and not game.players[0].carrying, "New game resets puzzle and carry states")
	game.start_game(1)
	game.players[0].position.x = 300
	var use_event := InputEventKey.new()
	use_event.physical_keycode = KEY_E
	use_event.pressed = true
	game._unhandled_key_input(use_event)
	check(game.players[0].carrying, "Physical E key event reaches in-game interaction")
	print("RESULT: %d failure(s)" % failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
