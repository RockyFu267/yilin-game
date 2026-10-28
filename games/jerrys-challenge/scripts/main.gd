extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const LearningScript = preload("res://scripts/learning.gd")
const HomeScript = preload("res://scripts/home.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const SKINS = PlayerScript.SKINS
const SKIN_NAMES = ["青蛙伙伴", "面具伙伴", "粉粉伙伴", "蓝蓝伙伴", "Jerry 小老鼠", "Tom 小猫"]
const CHAPTERS = ["家门口", "三个苹果", "花朵小桥", "我们的野餐"]
const SAVE_PATH = "user://picnic_progress.json"
const INK = Color("203e36")
const CREAM = Color("fff3d6")
const GREEN = Color("247b60")
const HOLD_SECONDS: float = 1.8
var mode: String = "title"
var stage: int = 0
var selected: Array[int] = [5, 4]
var confirmed: Array[bool] = [false, false]
var players: Array = []
var solids: Array[StaticBody2D] = []
var barriers: Array[StaticBody2D] = []
var menu: Control
var fruit_foreground: Node2D
var font: SystemFont
var bold: SystemFont
var ticks: float = 0
var stage_time: float = 0
var solved: bool = false
var paused: bool = false
var muted: bool = false
var hint_mode: bool = false
var toast: String = ""
var toast_time: float = 0
var apples: Array[Vector2] = []
var deposited: int = 0
var handles: Array[bool] = [false, false]
var crank_by: int = -1
var flower_by: int = -1
var lights: Array[bool] = [false, false]
var hold_charge: float = 0.0
var pixel_font: Font
var sits: Array[bool] = [false, false]
var particles: Array = []
var note_player: AudioStreamPlayer
var saved: Dictionary = {}
var texture_cache: Dictionary = {}
var learning
var home
var requested_activity: String = "picnic"
var name_fields: Array[LineEdit] = []
var names_return_to_select := false
var money_input: SpinBox

func _ready() -> void:
	if not SaveStore.automated_run_safe():
		push_error("Automated test/capture blocked: use tools/run_checks.ps1 or an isolated APPDATA with YILIN_GAME_QA_DIR.")
		set_process(false)
		set_process_unhandled_key_input(false)
		get_tree().quit(2)
		return
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	bold = SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	bold.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font = load("res://assets/fonts/Silkscreen-Regular.ttf")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_input()
	home = HomeScript.new(self)
	learning = LearningScript.new(self)
	for i in range(2):
		var actor = PlayerScript.new()
		actor.player_id = i
		actor.display_name = player_name(i)
		actor.skin = selected[i]
		actor.label_font = font
		add_child(actor)
		players.append(actor)
	fruit_foreground = Node2D.new()
	fruit_foreground.name = "FruitForeground"
	fruit_foreground.z_index = 20
	fruit_foreground.draw.connect(_draw_fruit_foreground)
	add_child(fruit_foreground)
	_make_solid(Rect2(0, 600, 1280, 120), false)
	menu = Control.new()
	menu.size = Vector2(1280, 720)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.z_index = 30
	add_child(menu)
	_setup_audio()
	_load_progress()
	show_title()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			_capture_demo(arg.trim_prefix("--capture="))
	if args.has("--verify"):
		_verify_release.call_deferred()

func _setup_input() -> void:
	var keys := {"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W, "p1_use": KEY_E, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP, "p2_use": KEY_O}
	keys.merge({"home_p1_up": KEY_W, "home_p1_down": KEY_S, "home_p2_up": KEY_UP, "home_p2_down": KEY_DOWN})
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if action == "p2_use":
			InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func _exit_tree() -> void:
	if note_player:
		note_player.stop()
	if note_player:
		note_player.stream = null

func _setup_audio() -> void:
	note_player = AudioStreamPlayer.new()
	note_player.volume_db = -19
	add_child(note_player)

func _process(delta: float) -> void:
	ticks += delta
	if mode == "game" and not paused:
		stage_time += delta
		_tick_game(delta)
	if mode == "learning" and not paused:
		learning.tick(delta)
	if mode == "home" and not paused:
		home.tick(delta)
	toast_time = maxf(0, toast_time - delta)
	for p in particles:
		p.position += p.velocity * delta
		p.velocity.y += 70 * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	fruit_foreground.visible = mode in ["game", "garden", "learning"] and not paused
	fruit_foreground.queue_redraw()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		if mode == "home":
			home.escape()
		elif mode == "learning":
			learning.pause()
		elif mode == "game":
			_toggle_pause()
		elif mode == "select":
			show_title()
		elif mode == "settings":
			show_title()
		elif mode == "names":
			_return_from_names()
		return
	if mode == "title" and event is InputEventKey and event.physical_keycode == KEY_ENTER:
		show_select()
	elif mode == "select":
		for i in range(2):
			var prefix := "p%d_" % (i + 1)
			if event.is_action_pressed(prefix + "left"):
				_cycle(i, -1)
			elif event.is_action_pressed(prefix + "right"):
				_cycle(i, 1)
			elif event.is_action_pressed(prefix + "use"):
				_confirm(i)
	elif mode == "home":
		home.input(event)
	elif mode == "learning" and not paused:
		for i in range(2):
			if event.is_action_pressed("p%d_use" % (i + 1)):
				learning.use(i)
	elif mode == "game" and not paused:
		for i in range(2):
			if event.is_action_pressed("p%d_use" % (i + 1)):
				interact(i)
		if event is InputEventKey and event.physical_keycode == KEY_F1:
			hint_mode = not hint_mode

func _clear_menu() -> void:
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()

func _button(caption: String, rect: Rect2, callback: Callable, primary: bool = true) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_outline_color", Color("251f23"))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", _button_skin(Color("735536") if primary else Color("414a36")))
	button.add_theme_stylebox_override("hover", _button_skin(Color("997145") if primary else Color("61704c")))
	button.add_theme_stylebox_override("pressed", _button_skin(Color("3c332b")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 14, Color("e9b759")))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	menu.add_child(button)
	return button

func _button_skin(base: Color) -> StyleBoxTexture:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color("2c2829"))
	image.fill_rect(Rect2i(2, 2, 20, 20), Color("a77b48"))
	image.fill_rect(Rect2i(3, 3, 18, 2), Color("dfbc78"))
	image.fill_rect(Rect2i(3, 5, 2, 15), Color("b38d54"))
	image.fill_rect(Rect2i(5, 5, 14, 15), base)
	image.fill_rect(Rect2i(5, 19, 15, 2), Color("49382e"))
	image.fill_rect(Rect2i(19, 5, 2, 14), Color("49382e"))
	for p in [Vector2i(3, 3), Vector2i(18, 3), Vector2i(3, 18), Vector2i(18, 18)]:
		image.fill_rect(Rect2i(p, Vector2i(2, 2)), Color("e4c78a"))
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.texture_margin_top = 8
	style.texture_margin_bottom = 8
	return style

func show_title() -> void:
	mode = "title"
	paused = false
	for actor in players:
		actor.active = false
	_clear_menu()
	_button("一起去野餐", Rect2(290, 402, 330, 48), func(): requested_activity = "picnic"; show_select())
	_button("冰激凌小铺 · 十以内", Rect2(660, 402, 330, 48), func(): requested_activity = "shop"; show_select())
	_button("数字天平桥 · 5 以内", Rect2(290, 461, 330, 46), func(): requested_activity = "ducks5"; show_select())
	_button("数字天平桥 · 10 以内", Rect2(660, 461, 330, 46), func(): requested_activity = "ducks10"; show_select())
	_button("数字天平桥 · 20 以内", Rect2(660, 520, 330, 44), func(): requested_activity = "ducks20"; show_select(), false)
	if not saved.is_empty():
		_button("继续野餐", Rect2(290, 520, 157, 44), resume_game, false)
	if FileAccess.file_exists(learning.SAVE):
		_button("继续小店 / 天平桥", Rect2(290, 574, 330, 44), learning.resume_saved, false)
	_button("我们的小家 · 装修", Rect2(660, 574, 330, 44), func(): requested_activity = "home"; show_select())
	_button("设置", Rect2(910, 27, 140, 40), show_settings, false)
	_button("声音：开" if not muted else "声音：关", Rect2(1070, 27, 155, 40), _toggle_sound, false)

func _toggle_sound() -> void:
	muted = not muted
	if muted:
		note_player.stop()
	if mode == "title":
		show_title()
	elif paused:
		_pause_menu()
	elif mode == "settings":
		show_settings()

func show_settings() -> void:
	mode = "settings"
	paused = false
	for actor in players: actor.active = false
	_clear_menu()
	_button("玩家名字", Rect2(40, 27, 180, 42), func(): show_names(false), false)
	_button("打开存档目录", Rect2(40, 82, 180, 42), func(): OS.shell_open(OS.get_user_data_dir()), false)
	_button("无限金钱：开 ✓" if home.unlimited() else "无限金钱：关", Rect2(425, 260, 430, 51), func(): home.toggle_unlimited(); show_settings())
	money_input = SpinBox.new()
	money_input.position = Vector2(425, 322)
	money_input.size = Vector2(250, 45)
	money_input.min_value = 0
	money_input.max_value = 999999
	money_input.step = 1
	money_input.rounded = true
	money_input.value = int(home.state.wallet)
	money_input.get_line_edit().add_theme_font_override("font", font)
	money_input.get_line_edit().add_theme_font_size_override("font_size", 24)
	menu.add_child(money_input)
	_button("应用金额", Rect2(690, 322, 165, 45), func(): money_input.apply(); home.set_money(int(money_input.value)); show_settings())
	_button("钱袋增加 10 元", Rect2(425, 384, 207, 45), func(): home.set_money(int(home.state.wallet) + 10); show_settings(), false)
	_button("重置钱袋为 6 元", Rect2(647, 384, 208, 45), func(): home.set_money(6, true); show_settings(), false)
	_button("重置小家装饰（含库存全清空）", Rect2(425, 445, 430, 48), func(): home.reset_decorations(); show_settings(), false)
	_button("返回标题", Rect2(425, 560, 430, 48), show_title, false)

func player_name(i: int) -> String:
	var names = home.state.get("player_names", ["Tom", "Jerry"])
	return str(names[i]) if names is Array and names.size() == 2 else "玩家%d" % (i + 1)

func set_player_names(first: String, second: String) -> void:
	var names: Array = []
	for text in [first, second]:
		var clean: String = text.replace("\n", "").replace("\r", "").strip_edges().substr(0, 8)
		names.append(clean if not clean.is_empty() else "玩家%d" % (names.size() + 1))
	home.state.player_names = names
	for i in range(players.size()): players[i].display_name = names[i]
	home.save()

func show_names(from_select: bool = false) -> void:
	names_return_to_select = from_select
	mode = "names"
	_clear_menu()
	name_fields.clear()
	for i in range(2):
		var field := LineEdit.new()
		field.position = Vector2(490, 246 + i * 75)
		field.size = Vector2(310, 47)
		field.text = player_name(i)
		field.max_length = 8
		field.add_theme_font_override("font", font)
		field.add_theme_font_size_override("font_size", 24)
		menu.add_child(field)
		name_fields.append(field)
	_button("保存名字", Rect2(400, 438, 245, 48), func(): set_player_names(name_fields[0].text, name_fields[1].text); _return_from_names())
	_button("返回", Rect2(670, 438, 180, 48), _return_from_names, false)

func _return_from_names() -> void:
	if names_return_to_select: show_select()
	else: show_settings()

func show_select() -> void:
	mode = "select"
	confirmed = [false, false]
	_select_menu()

func _select_menu() -> void:
	_clear_menu()
	_button("修改玩家名字", Rect2(1040, 35, 195, 40), func(): show_names(true), false)
	for i in range(2):
		var x := 180 + i * 510
		_button("‹", Rect2(x + 20, 340, 48, 48), func(): _cycle(i, -1), false)
		_button("›", Rect2(x + 322, 340, 48, 48), func(): _cycle(i, 1), false)
		_button("出发！" if confirmed[0] and confirmed[1] else ("已准备好 ✓" if confirmed[i] else "选好了   " + ("E" if i == 0 else "O")), Rect2(x + 50, 485, 290, 49), func(): _confirm(i))
	if confirmed[0] and confirmed[1]:
		_button("小队集合，出发！", Rect2(460, 587, 360, 55), func(): start_game(0))
	_button("返回", Rect2(45, 35, 100, 40), show_title, false)

func _cycle(i: int, direction: int) -> void:
	selected[i] = posmod(selected[i] + direction, SKINS.size())
	confirmed[i] = false
	_select_menu()
	_ping(470)

func _confirm(i: int) -> void:
	if confirmed[0] and confirmed[1]:
		start_game(0)
		return
	confirmed[i] = not confirmed[i]
	_ping(700 if confirmed[i] else 400)
	_select_menu()

func start_game(chapter: int = 0) -> void:
	if requested_activity != "picnic":
		var activity := requested_activity
		requested_activity = "picnic"
		if activity == "home":
			home.enter()
		else:
			learning.start(activity)
		return
	mode = "game"
	paused = false
	_clear_menu()
	stage = clampi(chapter, 0, 3)
	stage_time = 0
	solved = false
	hold_charge = 0.0
	deposited = 0
	handles = [false, false]
	set_meta("handle_owner", -1)
	crank_by = -1
	flower_by = -1
	lights = [false, false]
	sits = [false, false]
	apples.clear()
	if stage == 1:
		apples.assign([Vector2(300, 568), Vector2(600, 568), Vector2(1010, 568)])
	for body in barriers:
		remove_child(body)
		body.queue_free()
	barriers.clear()
	for actor in players:
		actor.set_skin(selected[actor.player_id])
		actor.position = Vector2(110 + actor.player_id * 85, 590)
		actor.velocity = Vector2.ZERO
		actor.active = true
		actor.carrying = false
		actor.seated = false
	if stage == 2:
		barriers.append(_make_solid(Rect2(493, 330, 22, 270), true))
		barriers.append(_make_solid(Rect2(963, 330, 22, 270), true))
	_game_buttons()
	_save_progress()
	_message(["一起站上两个脚印，花园就会开门。", "篮子有三个空位。我们一起去找苹果！", "先转木柄，再到花岛接力。", "两人同时按住拉杆，把总开关拉下来！"][stage])

func _make_solid(rect: Rect2, _temporary: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.position = rect.size / 2
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _game_buttons() -> void:
	_clear_menu()
	_button("提示 F1", Rect2(1002, 25, 115, 40), func(): hint_mode = not hint_mode, false)
	_button("暂停 Esc", Rect2(1130, 25, 118, 40), _toggle_pause, false)

func _tick_game(delta: float = 0.0) -> void:
	if not solved and ((stage == 1 and deposited == 3) or stage == 3):
		_update_hold_puzzle(delta)
	if stage == 0 and not solved:
		var p0 := int(absf(players[0].position.x - 870) < 46) + int(absf(players[1].position.x - 870) < 46)
		var p1 := int(absf(players[0].position.x - 1030) < 46) + int(absf(players[1].position.x - 1030) < 46)
		if p0 > 0 and p1 > 0:
			_complete("两个脚印，都有人啦！一起走进右边的门。")
	if solved and stage < 3 and players[0].position.x > 1155 and players[1].position.x > 1155:
		start_game(stage + 1)

func _update_hold_puzzle(delta: float) -> void:
	var held: Array[bool] = [false, false]
	for i in range(2):
		var lever_x := float(1010 + i * 130) if stage == 1 else float(460 + i * 360)
		held[i] = Input.is_action_pressed("p%d_use" % (i + 1)) and absf(players[i].position.x - lever_x) < 58 and players[i].position.y > 560 and absf(players[i].velocity.y) < 1.0
	if stage == 1:
		handles.assign(held)
	else:
		lights.assign(held)
	if held[0] and held[1]:
		hold_charge = minf(HOLD_SECONDS, hold_charge + delta)
		if hold_charge >= HOLD_SECONDS:
			_complete("总开关锁住啦！现在可以松手，一起进门。" if stage == 1 else "总开关锁住啦！松开拉杆，一起去野餐！")
	else:
		hold_charge = 0.0

func interact(i: int) -> void:
	if mode != "game" or paused:
		return
	var actor = players[i]
	var x: float = actor.position.x
	match stage:
		1:
			if actor.carrying and absf(x - 780) < 85:
				actor.carrying = false
				deposited += 1
				_burst(Vector2(780, 510))
				_ping(520 + deposited * 100)
				_message("篮子装满啦！两位伙伴各按住一个拉杆。" if deposited == 3 else "放好了！再找 %d 个苹果。" % (3 - deposited))
				return
			if not actor.carrying:
				for a in range(apples.size()):
					if absf(x - apples[a].x) < 65:
						apples.remove_at(a)
						actor.carrying = true
						_ping(620)
						return
			elif absf(x - 780) >= 85:
				apples.append(Vector2(clampf(x + actor.facing * 40, 45, 1225), 568))
				actor.carrying = false
		2:
			if crank_by < 0 and absf(x - 280) < 75:
				crank_by = i
				barriers[0].collision_layer = 0
				_burst(Vector2(280, 510))
				_ping(650)
				_message("第一段桥好了！请另一位伙伴去花岛接力。")
			elif crank_by >= 0 and flower_by < 0 and absf(x - 765) < 80:
				if i == crank_by:
					_message("把花朵机关留给伙伴。这次换 ta 帮你！")
				else:
					flower_by = i
					barriers[1].collision_layer = 0
					_complete("刚才你帮我，现在我帮你！一起到出口碰面。")
		3:
			if solved and absf(x - 1090) < 115:
				sits[i] = true
				actor.seated = true
				actor.position.x = 1040 + i * 100
				if sits[0] and sits[1]:
					_finish()

func _complete(message: String) -> void:
	solved = true
	_message(message)
	_burst(Vector2(1155 if stage < 3 else 640, 430))
	_ping(880)

func _message(message: String) -> void:
	toast = message
	toast_time = 6

func _ping(frequency: float) -> void:
	if muted:
		return
	var data := PackedByteArray()
	data.resize(6400)
	for i in range(3200):
		var envelope := minf(1.0, i / 100.0) * (1.0 - i / 3200.0)
		var sample := sin(i * TAU * frequency / 22050.0) * envelope * 9800
		data.encode_s16(i * 2, int(sample))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	note_player.stream = stream
	note_player.play()

func _burst(origin: Vector2) -> void:
	for i in range(32):
		particles.append({"position": origin, "velocity": Vector2(randf_range(-150, 150), randf_range(-180, -40)), "life": randf_range(1.2, 2.8), "color": [Color("ffc878"), Color("fff4ce"), Color("f49caf"), Color("76c9a5")][i % 4]})

func _toggle_pause() -> void:
	paused = not paused
	if paused and not solved:
		hold_charge = 0
		handles = [false, false]
		lights = [false, false]
	for actor in players:
		actor.set_physics_process(not paused)
		actor.visible = not paused
	if paused:
		_pause_menu()
	else:
		_game_buttons()

func _pause_menu() -> void:
	_clear_menu()
	_button("继续冒险", Rect2(470, 270, 340, 48), _toggle_pause)
	_button("重试当前小关", Rect2(470, 333, 340, 44), func(): _unfreeze(); start_game(stage), false)
	_button("帮伙伴回到安全处", Rect2(470, 389, 340, 44), _rescue, false)
	_button("声音：开" if not muted else "声音：关", Rect2(470, 445, 340, 44), _toggle_sound, false)
	_button("保存并回到标题", Rect2(470, 501, 340, 44), func(): _unfreeze(); show_title(), false)

func _unfreeze() -> void:
	paused = false
	for actor in players:
		actor.set_physics_process(true)
		actor.visible = true

func _rescue() -> void:
	var safe_x: float = minf(players[0].position.x, players[1].position.x)
	for actor in players:
		actor.position = Vector2(clampf(safe_x + actor.player_id * 65, 45, 1210), 590)
		actor.velocity = Vector2.ZERO
	_toggle_pause()
	_message("小队重新集合！慢慢来，我们一起想办法。")

func _finish() -> void:
	mode = "ending"
	_save_progress()
	_clear_menu()
	_button("再冒险一次", Rect2(350, 430, 270, 52), show_select)
	_button("留在花园", Rect2(650, 430, 270, 52), _stay, false)
	_burst(Vector2(640, 330))

func _stay() -> void:
	mode = "garden"
	for actor in players:
		actor.seated = false
	_clear_menu()
	_button("回到标题", Rect2(1100, 25, 140, 40), show_title, false)

func _save_progress() -> void:
	saved = {"stage": stage, "skins": selected.duplicate()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved))

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary and data.has("stage") and data.get("skins") is Array and data.skins.size() == 2:
		saved = data

func resume_game() -> void:
	requested_activity = "picnic"
	for i in range(2):
		selected[i] = clampi(int(saved.skins[i]), 0, SKINS.size() - 1)
	start_game(clampi(int(saved.stage), 0, 3))

func _style(color: Color, radius: int = 16, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_color = border if border.a > 0 else Color("30272a")
	style.set_border_width_all(3)
	return style

func _texture(path: String) -> Texture2D:
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]

func _panel(rect: Rect2, color: Color = CREAM, _radius: int = 0) -> void:
	var wood := Color("513b30") if color == CREAM else color
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0.04, 0.08, 0.07, 0.55))
	draw_rect(rect, Color("30262a"))
	draw_rect(rect.grow(-3), Color("aa7b4b"))
	draw_rect(rect.grow(-6), Color("503b2e"))
	draw_rect(rect.grow(-8), wood)
	draw_line(rect.position + Vector2(5, 4), Vector2(rect.end.x - 5, rect.position.y + 4), Color("d3ad70"), 2)
	for point in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 9, rect.position.y + 5), Vector2(rect.position.x + 5, rect.end.y - 9), rect.end - Vector2(9, 9)]:
		draw_rect(Rect2(point, Vector2(4, 4)), Color("dfbf80"))

func _text(content: String, pos: Vector2, size: int = 20, color: Color = INK, heavy: bool = false) -> void:
	if color.get_luminance() > 0.5:
		draw_string_outline(bold if heavy else font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color("302a29"))
	draw_string(bold if heavy else font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(content: String, y: float, size: int = 20, color: Color = INK, heavy: bool = false, x: float = 640) -> void:
	var use_font: Font = bold if heavy else font
	var w := use_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(content, Vector2(x - w / 2, y), size, color, heavy)

func _draw() -> void:
	if not font:
		return
	_background()
	if mode == "title":
		_draw_title()
	elif mode == "select":
		_draw_select()
	elif mode == "learning":
		learning.paint()
	elif mode == "home":
		home.paint()
	elif mode == "settings":
		_draw_settings()
	elif mode == "names":
		_panel(Rect2(320, 155, 640, 370), Color("49382d"))
		_center("今天，两位伙伴叫什么？", 207, 29, CREAM, true)
		_text("P1 · 左侧键盘", Vector2(345, 277), 19, CREAM)
		_text("P2 · 方向键", Vector2(345, 352), 19, CREAM)
		_center("名字与角色外观无关，每个名字最多 8 个字。", 405, 18, CREAM)
	else:
		_draw_level()
		_hud()
		if mode == "ending":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.17, 0.14, 0.65))
			_panel(Rect2(260, 158, 760, 370))
			_center("WE DID IT, TOGETHER!", 214, 17, Color("c1dc91"), true)
			_center("%s 和 %s，一起完成！" % [player_name(0), player_name(1)], 278, 30, CREAM, true)
			_center("装满了野餐篮，修好了小桥，也点亮了花园。", 334, 22, CREAM)
			_center("谢谢你陪我冒险。", 378, 24, Color("c1dc91"), true)
		elif paused:
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.17, 0.14, 0.65))
			_panel(Rect2(410, 163, 460, 435))
			_center("休息一下，冒险会等你", 228, 27, CREAM, true)
	for p in particles:
		draw_rect(Rect2(p.position, Vector2(5, 8)), p.color)

func _background() -> void:
	# Background art uses a strict 3x pixel grid, matching the terrain atlas.
	# Few colors, clear silhouettes, chunky highlights: the characters set the style.
	draw_set_transform(Vector2.ZERO, 0, Vector2(3, 3))
	draw_rect(Rect2(0, 0, 427, 240), Color("b4dced"))
	for i in range(5):
		var x := floorf(fmod(i * 97 + ticks * 0.6, 490)) - 35
		var y := 28 + i % 3 * 17
		_pixel_cloud(Vector2(x, y))
	# Stepped distant hills, deliberately quieter than foreground sprites.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 160), Vector2(0, 139), Vector2(18, 139), Vector2(18, 129), Vector2(35, 129), Vector2(35, 117), Vector2(56, 117), Vector2(56, 108), Vector2(78, 108), Vector2(78, 113), Vector2(94, 113), Vector2(94, 125), Vector2(111, 125), Vector2(111, 134), Vector2(137, 134), Vector2(137, 124), Vector2(158, 124), Vector2(158, 115), Vector2(180, 115), Vector2(180, 122), Vector2(202, 122), Vector2(202, 137), Vector2(221, 137), Vector2(221, 129), Vector2(242, 129), Vector2(242, 114), Vector2(263, 114), Vector2(263, 105), Vector2(285, 105), Vector2(285, 112), Vector2(301, 112), Vector2(301, 123), Vector2(324, 123), Vector2(324, 134), Vector2(348, 134), Vector2(348, 124), Vector2(373, 124), Vector2(373, 116), Vector2(396, 116), Vector2(396, 130), Vector2(427, 130), Vector2(427, 197), Vector2(0, 197)]), Color("9ccbb5"))
	for i in range(15):
		var x := i * 33 - 12
		var y := 156 + (i % 4) * 5
		draw_rect(Rect2(x + 9, y, 4, 42), Color("7eb397"))
		draw_rect(Rect2(x + 3, y - 12, 18, 23), Color("86bda0"))
		draw_rect(Rect2(x, y - 5, 24, 13), Color("86bda0"))
		draw_rect(Rect2(x + 6, y - 17, 12, 6), Color("86bda0"))
	draw_rect(Rect2(0, 183, 427, 14), Color("91bd7d"))
	for i in range(33):
		var x := (i * 47 + 13) % 427
		draw_rect(Rect2(x, 186 + i % 3 * 3, 4, 2), Color("a2ce88"))
	_pixel_tree(30, 195)
	_pixel_tree(400, 195)
	for x in [100, 340]:
		_pixel_bush(Vector2(x, 192))
	for i in range(19):
		var x := (i * 61 + 27) % 427
		draw_rect(Rect2(x, 192, 1, 4), Color("4f7a30"))
		draw_rect(Rect2(x - 1, 190, 3, 3), Color("f4d49a") if i % 2 else Color("e5a4c4"))
		draw_rect(Rect2(x, 191, 1, 1), Color("fff3cf"))
	draw_set_transform(Vector2.ZERO)
	var terrain: Texture2D = _texture("res://assets/world/Terrain (16x16).png")
	for y in [585, 633, 681]:
		for x in range(0, 1280, 48):
			draw_texture_rect_region(terrain, Rect2(x, y, 48, 48), Rect2(112, 0 if y == 585 else 16, 16, 16))

func _pixel_cloud(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(4, 6), Vector2(36, 9)), Color("94c5dc"))
	draw_rect(Rect2(pos + Vector2(8, 1), Vector2(14, 4)), Color("eef6ed"))
	draw_rect(Rect2(pos + Vector2(5, 5), Vector2(28, 4)), Color("eef6ed"))
	draw_rect(Rect2(pos + Vector2(0, 9), Vector2(41, 5)), Color("eef6ed"))
	draw_rect(Rect2(pos + Vector2(4, 14), Vector2(33, 3)), Color("d6e9e5"))
	draw_rect(Rect2(pos + Vector2(24, 6), Vector2(10, 3)), Color("f7faee"))

func _pixel_tree(x: int, ground_y: int) -> void:
	var bark := Color("684536")
	draw_rect(Rect2(x - 6, ground_y - 77, 13, 77), bark)
	draw_rect(Rect2(x - 4, ground_y - 75, 9, 75), Color("b57750"))
	draw_rect(Rect2(x - 2, ground_y - 72, 3, 66), Color("d8a064"))
	draw_rect(Rect2(x + 3, ground_y - 63, 2, 58), Color("8f5e42"))
	for y in [ground_y - 58, ground_y - 31, ground_y - 13]:
		draw_rect(Rect2(x - 3, y, 4, 2), Color("8f5e42"))
	draw_rect(Rect2(x - 10, ground_y - 3, 22, 3), bark)
	draw_rect(Rect2(x - 8, ground_y - 4, 18, 3), Color("b57750"))
	_pixel_canopy(Vector2(x - 35, ground_y - 93), 1)
	_pixel_canopy(Vector2(x - 5, ground_y - 94), 1)
	_pixel_canopy(Vector2(x - 23, ground_y - 116), 0)

func _pixel_canopy(pos: Vector2, variant: int) -> void:
	var edge := Color("34462a")
	var shade := Color("4b792d")
	var mid := Color("73a33b")
	var light := Color("a6c957")
	var points := PackedVector2Array([Vector2(0, 12), Vector2(4, 12), Vector2(4, 6), Vector2(11, 6), Vector2(11, 2), Vector2(20, 2), Vector2(20, 0), Vector2(30, 0), Vector2(30, 4), Vector2(37, 4), Vector2(37, 10), Vector2(42, 10), Vector2(42, 16), Vector2(46, 16), Vector2(46, 29), Vector2(42, 29), Vector2(42, 35), Vector2(34, 35), Vector2(34, 39), Vector2(13, 39), Vector2(13, 36), Vector2(5, 36), Vector2(5, 30), Vector2(0, 30)])
	for i in range(points.size()):
		points[i] += pos
	draw_colored_polygon(points, edge)
	draw_rect(Rect2(pos + Vector2(2, 14), Vector2(42, 14)), shade)
	draw_rect(Rect2(pos + Vector2(6, 8), Vector2(34, 24)), shade)
	draw_rect(Rect2(pos + Vector2(13, 4), Vector2(22, 32)), shade)
	draw_rect(Rect2(pos + Vector2(8, 9), Vector2(29, 15)), mid)
	draw_rect(Rect2(pos + Vector2(14, 4), Vector2(16, 22)), mid)
	draw_rect(Rect2(pos + Vector2(4, 16), Vector2(13, 9)), mid)
	draw_rect(Rect2(pos + Vector2(23, 13), Vector2(17, 12)), mid)
	for cluster in [Rect2(15, 5, 7, 3), Rect2(9, 10, 5, 3), Rect2(22, 9, 8, 3), Rect2(5, 17, 7, 3), Rect2(16, 17, 6, 3), Rect2(30, 16, 5, 3)]:
		draw_rect(Rect2(pos + cluster.position, cluster.size), light if variant == 0 else Color("8cbb48"))
	draw_rect(Rect2(pos + Vector2(14, 29), Vector2(8, 3)), Color("5c8e31"))
	draw_rect(Rect2(pos + Vector2(29, 27), Vector2(8, 3)), Color("5c8e31"))

func _pixel_bush(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-16, -8), Vector2(32, 10)), Color("42672c"))
	draw_rect(Rect2(pos + Vector2(-12, -13), Vector2(24, 12)), Color("6b9b35"))
	draw_rect(Rect2(pos + Vector2(-7, -17), Vector2(13, 6)), Color("6b9b35"))
	draw_rect(Rect2(pos + Vector2(-10, -12), Vector2(6, 3)), Color("9fc34e"))
	draw_rect(Rect2(pos + Vector2(2, -8), Vector2(7, 3)), Color("9fc34e"))

func _flower(pos: Vector2, color: Color, scale_factor: float = 1.0) -> void:
	draw_set_transform(pos, 0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(-3, -35, 6, 35), Color("3d7046"))
	draw_rect(Rect2(3, -18, 12, 6), Color("6d9953"))
	for offset in [Vector2(-6, -52), Vector2(-18, -40), Vector2(6, -40), Vector2(-6, -28)]:
		draw_rect(Rect2(offset, Vector2(12, 12)), Color("774d59"))
		draw_rect(Rect2(offset + Vector2(2, 1), Vector2(9, 8)), color)
	draw_rect(Rect2(-5, -40, 10, 10), Color("ffe3a2"))
	draw_set_transform(Vector2.ZERO)

func _sprite(skin: int, pos: Vector2, factor: float = 5) -> void:
	var tex: Texture2D = _texture("res://assets/characters/%s/Idle (32x32).png" % SKINS[skin])
	var frame := int(ticks * 7) % maxi(1, tex.get_width() / 32)
	draw_texture_rect_region(tex, Rect2(pos.x - 16 * factor, pos.y - 32 * factor, 32 * factor, 32 * factor), Rect2(frame * 32, 0, 32, 32))

func _draw_title() -> void:
	_title_word("JERRY'S", 190, 68)
	_title_word("CHALLENGE", 275, 68)
	_sign("两位伙伴 · 一起想办法", Vector2(640, 340))
	_sprite(5, Vector2(183, 595), 4.5)
	_sprite(4, Vector2(1090, 595), 4.5)
	_panel(Rect2(42, 641, 484, 55), Color("423e35"))
	_text("%s  A / D 移动  W 跳跃  E 互动" % player_name(0), Vector2(62, 677), 16, Color("f8dda0"), true)
	_panel(Rect2(754, 641, 484, 55), Color("423e35"))
	_text("%s  ← / → 移动  ↑ 跳跃  O 互动" % player_name(1), Vector2(771, 677), 16, Color("c8ebbc"), true)
	_center("慢慢想，一起玩 · 没有计时", 630, 19, CREAM, true)

func _draw_settings() -> void:
	_panel(Rect2(340, 130, 600, 510), Color("49382d"))
	_center("游戏设置", 182, 32, CREAM, true)
	_center("普通钱袋余额：%d 元" % home.state.wallet, 224, 22, Color("f4d79e"))
	if not home.storage_notice.is_empty(): _center(home.storage_notice, 652, 17, CREAM)
	_center("重置钱袋保留家具；重置装饰不改钱和订单。", 527, 17, CREAM)
	_center("房间、库存和手持家具全部清空，不退购买费用。", 549, 17, CREAM)
	_center("无限金钱不扣购买费用，关闭后继续使用普通余额。", 629, 17, Color("f4d79e"))

func _title_word(content: String, y: float, size: int) -> void:
	var width := pixel_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(640 - width / 2, y)
	draw_string_outline(pixel_font, pos + Vector2(0, 6), content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color("182b2a"))
	draw_string_outline(pixel_font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color("3e2d2b"))
	draw_string(pixel_font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("f9d88a"))

func _draw_select() -> void:
	_center("今天，你想当哪位冒险伙伴？", 95, 34, CREAM, true)
	_center("外观随你喜欢，每位伙伴都一样能干。", 134, 18, CREAM)
	for i in range(2):
		var x := 180 + i * 510
		_panel(Rect2(x, 180, 390, 380), Color("4b3931") if i == 0 else Color("354c3c"), 25)
		_center("P%d  /  %s" % [i + 1, player_name(i)], 224, 23, CREAM, true, x + 195)
		draw_rect(Rect2(x + 110, 275, 170, 140), Color("26372f"))
		draw_rect(Rect2(x + 105, 410, 180, 12), Color("b38b50"))
		_sprite(selected[i], Vector2(x + 195, 410), 4)
		_center(SKIN_NAMES[selected[i]] + "  %d / %d" % [selected[i] + 1, SKINS.size()], 449, 20, CREAM, true, x + 195)
		_center("A / D 选择 · E 准备" if i == 0 else "← / → 选择 · O 准备", 476, 16, Color("d4be8e"), false, x + 195)
	_center("双方准备完成！再按 E 或 O 出发。" if confirmed[0] and confirmed[1] else "也可以用鼠标选择。双方准备好后出发。", 680, 18, CREAM)

func _draw_level() -> void:
	match stage:
		0:
			_house(Vector2(130, 585))
			_sign("先走走，再试试小跳跃", Vector2(470, 470))
			for x in [870, 1030]:
				var occupied: bool = absf(players[0].position.x - x) < 46 or absf(players[1].position.x - x) < 46
				draw_style_box(_style(Color("f7d38b") if occupied else Color("d7e7bc"), 10), Rect2(x - 47, 573, 94, 16))
				_text("●" if x == 870 else "■", Vector2(x - 10, 561), 24, INK)
			_gate(solved)
		1:
			for apple in apples:
				_prompt(apple.x, 485, "拿苹果", false)
			_basket(Vector2(780, 581), deposited)
			_prompt(780, 460, "放进篮子", false)
			if deposited == 3:
				_coop_circuit(1010, 1140, handles, 350)
			for i in range(2):
				_lever(Vector2(1010 + i * 130, 585), handles[i], Color("dba765"))
				if deposited == 3:
					_prompt(1010 + i * 130, 477, "按住 E" if i == 0 else "按住 O", solved)
			_gate(solved)
		2:
			draw_rect(Rect2(490, 585, 480, 40), Color("7bc4cd"))
			for i in range(12):
				var x := 500 + i * 39 + sin(ticks + i) * 4
				draw_line(Vector2(x, 606), Vector2(x + 18, 606), Color("c4eeea"), 2)
			_bridge(510, 710, crank_by >= 0)
			_bridge(810, 970, flower_by >= 0)
			draw_style_box(_style(Color("87b65e"), 9), Rect2(710, 569, 103, 40))
			_lever(Vector2(280, 585), crank_by >= 0, Color("c58b5d"))
			_flower(Vector2(765, 565), Color("f4a0b6") if flower_by >= 0 else Color("f8dba0"), 1.6)
			_prompt(280, 469, "转动木柄", crank_by >= 0)
			_prompt(765, 429, "伙伴接力", flower_by >= 0)
			if crank_by < 0:
				_vine(505)
			if flower_by < 0:
				_vine(975)
			_gate(solved)
		3:
			_draw_light_strings()
			_coop_circuit(460, 820, lights, 395)
			for i in range(2):
				var x := 460 + i * 360
				_lever(Vector2(x, 585), lights[i], Color("ffc878") if i == 0 else Color("8edcb7"))
				var label := "%s · 按住 %s" % [player_name(i), "E" if i == 0 else "O"]
				if lights[i] and not solved:
					label = "保持住，等伙伴！" if not lights[1 - i] else "保持住！"
				_prompt(x, 470, label, solved)
			_picnic()
			if solved:
				_prompt(1090, 470, "一起坐下", false)
	if solved and stage < 3:
		_sign("一起进门  →", Vector2(1080, 370))

func _draw_light_strings() -> void:
	for i in range(2):
		for k in range(9):
			var bx := 150 + k * 120
			var by := 280 + i * 58 + sin(k * 0.5) * 35
			if k > 0:
				draw_line(Vector2(bx - 120, 280 + i * 58 + sin((k - 1) * 0.5) * 35), Vector2(bx, by), INK, 2)
			draw_rect(Rect2(bx - 8, by + 1, 16, 20), Color("302b2b"))
			draw_rect(Rect2(bx - 5, by + 4, 10, 14), Color("ffe5a0") if lights[i] else Color("7d8a62"))
			if lights[i]:
				draw_rect(Rect2(bx - 14, by - 3, 28, 28), Color(1, 0.9, 0.55, 0.14))

func _hud() -> void:
	_panel(Rect2(27, 24, 300, 84), Color("49382d"))
	_text("JERRY'S CHALLENGE", Vector2(47, 50), 13, Color("d1ae70"), true)
	_text("%02d  %s" % [stage + 1, CHAPTERS[stage]], Vector2(47, 85), 24, CREAM, true)
	for i in range(4):
		var pos := Vector2(352 + i * 29, 46)
		draw_rect(Rect2(pos - Vector2(2, 2), Vector2(18, 18)), Color("3c302e"))
		draw_rect(Rect2(pos, Vector2(14, 14)), Color("dcb36a") if i <= stage else Color("4e6552"))
	_panel(Rect2(28, 650, 464, 46), Color("393b31"))
	_text("%s   A / D 移动   W 跳跃   E 互动" % player_name(0), Vector2(46, 680), 16, Color("ffe0a2"))
	_panel(Rect2(776, 650, 476, 46), Color("393b31"))
	_text("%s   ← / → 移动   ↑ 跳跃   O 互动" % player_name(1), Vector2(792, 680), 16, Color("c4eab7"))
	var message := ""
	if toast_time > 0:
		message = toast
	elif hint_mode or stage_time > 50:
		message = ["每人一个脚印，再一起进门。", "三个苹果装好后，两人同时按住拉杆。", "转木柄的人等一等，让伙伴去花岛。", "站在自己的拉杆旁，同时按住 E 和 O；松手会回弹。"] [stage]
	if not message.is_empty():
		var width := minf(1050, font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 44)
		_panel(Rect2(640 - width / 2, 129, width, 43), Color("4a4031"))
		_center(message, 157, 18, Color("f2dfb7"))

func _prompt(x: float, y: float, caption: String, done: bool) -> void:
	if done:
		draw_rect(Rect2(x - 5, y - 13, 10, 10), Color("b6df79"))
		return
	var near: Array[String] = []
	for actor in players:
		if absf(actor.position.x - x) < 85:
			near.append("E" if actor.player_id == 0 else "O")
	if near.is_empty() and not hint_mode:
		var by := y + sin(ticks * 3) * 3
		draw_colored_polygon(PackedVector2Array([Vector2(x, by - 12), Vector2(x + 5, by - 7), Vector2(x, by - 2), Vector2(x - 5, by - 7)]), Color("f6d589"))
		return
	var text := caption + ("  [" + " / ".join(near) + "]" if not near.is_empty() and not caption.contains("按住") and not caption.contains("保持住") else "")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 24
	_panel(Rect2(x - w / 2, y - 24, w, 34), Color("3f4433"))
	_center(text, y, 17, Color("fff0b8"), true, x)

func _fruit(pos: Vector2, canvas: CanvasItem) -> void:
	var texture: Texture2D = _texture("res://assets/world/Apple.png")
	var frame := int(ticks * 9) % maxi(1, texture.get_width() / 32)
	canvas.draw_texture_rect_region(texture, Rect2(pos - Vector2(26, 45), Vector2(52, 52)), Rect2(frame * 32, 0, 32, 32))

func _draw_fruit_foreground() -> void:
	if mode == "learning":
		if learning.activity != "shop":
			learning.balance.paint_tiles(fruit_foreground)
		return
	if stage == 1:
		for apple in apples:
			_fruit(apple + Vector2(0, sin(ticks * 2 + apple.x) * 3), fruit_foreground)
		for i in range(deposited):
			_fruit(Vector2(780 - 42 + i * 42, 509), fruit_foreground)
	elif stage == 3 and solved:
		for i in range(3):
			_fruit(Vector2(1090 - 42 + i * 42, 506), fruit_foreground)
	for actor in players:
		if actor.active and actor.carrying:
			fruit_foreground.draw_texture_rect_region(_texture("res://assets/world/Apple.png"), Rect2(actor.position + Vector2(-20, -98), Vector2(40, 40)), Rect2(0, 0, 32, 32))

func _basket(pos: Vector2, count: int) -> void:
	draw_rect(Rect2(pos.x - 33, pos.y - 64, 66, 8), Color("352b2a"))
	draw_rect(Rect2(pos.x - 40, pos.y - 56, 8, 34), Color("9e7446"))
	draw_rect(Rect2(pos.x + 32, pos.y - 56, 8, 34), Color("9e7446"))
	draw_style_box(_style(Color("ba884f"), 9), Rect2(pos.x - 48, pos.y - 38, 96, 43))
	for i in range(4):
		draw_line(pos + Vector2(-43, -31 + i * 10), pos + Vector2(43, -31 + i * 10), Color("e7b97a"), 3)
	for i in range(3):
		draw_rect(Rect2(pos + Vector2(-56 + i * 42, -104), Vector2(28, 28)), Color("ad8052") if i < count else Color("354537"))
	_center("%d / 3" % count, pos.y - 165, 26, CREAM, true, pos.x)

func _lever(pos: Vector2, on: bool, color: Color) -> void:
	draw_rect(Rect2(pos.x - 27, pos.y - 16, 54, 16), Color("302b2b"))
	draw_rect(Rect2(pos.x - 23, pos.y - 16, 46, 8), Color("b08a53"))
	draw_rect(Rect2(pos.x - 15, pos.y - 30, 30, 16), Color("685b48"))
	var tip := pos + Vector2(22 if on else -22, -36 if on else -72)
	draw_line(pos + Vector2(0, -22), tip, Color("302b2b"), 12)
	draw_line(pos + Vector2(0, -22), tip, Color("bdab80"), 6)
	draw_rect(Rect2(tip - Vector2(13, 7), Vector2(26, 14)), Color("302b2b"))
	draw_rect(Rect2(tip - Vector2(10, 5), Vector2(20, 9)), Color("c2e28b") if on else color)
	draw_rect(Rect2(pos.x - 5, pos.y - 27, 10, 10), Color("dfbd77"))

func _master_switch(center: Vector2) -> void:
	var on := solved
	var fill := hold_charge / HOLD_SECONDS
	_panel(Rect2(center - Vector2(74, 66), Vector2(148, 110)), Color("463e31"))
	_center("已锁定" if on else ("一起保持！" if fill > 0 else "总开关"), center.y - 36, 17, CREAM, true, center.x)
	for i in range(5):
		draw_rect(Rect2(center.x - 45 + i * 19, center.y - 23, 13, 12), Color("d9c16d") if float(i) / 5.0 < fill else Color("263a31"))
	draw_line(center + Vector2(-35, 14), center + Vector2(35, 14), Color("241f27"), 13)
	var lever_x := lerpf(-34, 34, fill)
	draw_rect(Rect2(center.x + lever_x - 7, center.y - 5, 14, 32), Color("c4df89") if on else Color("d8a95f"))

func _coop_circuit(left: float, right: float, active: Array[bool], master_y: float) -> void:
	var center := Vector2((left + right) / 2, master_y)
	for i in range(2):
		var x := left if i == 0 else right
		var color := Color("e7c46d") if active[i] else Color("423a35")
		draw_polyline(PackedVector2Array([Vector2(x, 566), Vector2(x - 40, 566), Vector2(x - 40, master_y), Vector2(center.x, master_y)]), Color("25312a"), 9)
		draw_polyline(PackedVector2Array([Vector2(x, 566), Vector2(x - 40, 566), Vector2(x - 40, master_y), Vector2(center.x, master_y)]), color, 3)
	_master_switch(center)

func _bridge(left: float, right: float, enabled: bool) -> void:
	if enabled:
		for x in range(int(left), int(right), 24):
			draw_rect(Rect2(x, 578, 22, 15), Color("d9ab70"))
			draw_rect(Rect2(x + 3, 578, 3, 4), Color("8e714e"))
	else:
		for x in range(int(left), int(right), 34):
			draw_line(Vector2(x, 588), Vector2(x + 18, 588), Color("b5e3d4"), 3)

func _vine(x: float) -> void:
	for i in range(7):
		var pos := Vector2(x + int(sin(i) * 3) * 3, 550 - i * 26)
		draw_rect(Rect2(pos - Vector2(6, 10), Vector2(12, 32)), Color("3a6544"))
		draw_rect(Rect2(pos + Vector2(-21 if i % 2 else 0, -7), Vector2(24, 15)), Color("54864b"))
		draw_rect(Rect2(pos + Vector2(-18 if i % 2 else 3, -7), Vector2(15, 5)), Color("91ad61"))
	_flower(Vector2(x, 380), Color("f5c7a4"), 0.8)

func _gate(open: bool) -> void:
	draw_rect(Rect2(1146, 438, 116, 150), Color("2e2927"))
	draw_rect(Rect2(1152, 443, 104, 145), Color("987044"))
	draw_rect(Rect2(1164, 455, 80, 133), Color("9aaf6e") if open else Color("344534"))
	for x in [1155, 1247]:
		for y in [454, 514, 572]:
			draw_rect(Rect2(x, y, 5, 5), Color("e1bb79"))
	if not open:
		draw_rect(Rect2(1190, 509, 28, 24), Color("caab62"))
		draw_rect(Rect2(1195, 499, 18, 14), Color("caab62"))
		draw_rect(Rect2(1201, 516, 6, 12), Color("3a332c"))
	else:
		_center("→", 540, 40, Color("354732"), true, 1204)

func _house(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 85, pos.y - 135, 170, 135), Color("9c754b"))
	for i in range(9):
		draw_rect(Rect2(pos.x - 81, pos.y - 130 + i * 15, 162, 3), Color("624b38"))
	for i in range(9):
		var width := 210 - i * 21
		draw_rect(Rect2(pos.x - width / 2, pos.y - 143 - i * 10, width, 12), Color("41332e"))
		draw_rect(Rect2(pos.x - width / 2 + 3, pos.y - 143 - i * 10, width - 6, 6), Color("94644b") if i % 2 else Color("b08155"))
	draw_rect(Rect2(pos.x - 28, pos.y - 86, 56, 86), Color("322d29"))
	draw_rect(Rect2(pos.x - 22, pos.y - 80, 44, 80), Color("5d7050"))
	draw_rect(Rect2(pos.x + 10, pos.y - 38, 5, 5), Color("dfbe76"))
	draw_rect(Rect2(pos.x + 40, pos.y - 106, 34, 40), Color("3c352c"))
	draw_rect(Rect2(pos.x + 44, pos.y - 102, 26, 32), Color("d6be7a"))
	draw_rect(Rect2(pos.x + 55, pos.y - 102, 4, 32), Color("634c37"))
	draw_rect(Rect2(pos.x + 44, pos.y - 88, 26, 4), Color("634c37"))

func _sign(caption: String, pos: Vector2) -> void:
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 36
	draw_rect(Rect2(pos.x - 5, pos.y + 5, 10, 52), Color("63462f"))
	_panel(Rect2(pos.x - width / 2, pos.y - 27, width, 42), Color("674932"))
	_center(caption, pos.y + 1, 19, CREAM, true, pos.x)
	for x in [pos.x - width / 2 + 10, pos.x + width / 2 - 14]:
		draw_rect(Rect2(x, pos.y - 12, 4, 4), Color("d1af70"))

func _picnic() -> void:
	draw_style_box(_style(Color("f0af98"), 8), Rect2(985, 580, 225, 25))
	for i in range(8):
		draw_rect(Rect2(990 + i * 27, 582, 14, 21), Color("f8d1b0"))
	_basket(Vector2(1090, 578), 3 if solved else 0)

func _capture_demo(path: String) -> void:
	var view := "bridge"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
	match view:
		"ice-berry-kiwi", "ice-orange-banana", "ice-carried":
			learning.start("shop")
			learning.s.recipe = [1, 4] if view != "ice-orange-banana" else [2, 3]
			learning.s.phase = "ready"
			learning.message = "冰激凌的两层颜色对应订单里的两种水果。"
			if view == "ice-carried":
				learning.s.phase = "serve"
				learning.s.hands[0] = "ice"
				players[0].position = Vector2(650, 600)
		"fruit-offer", "fruit-supply", "fruit-mix":
			learning.start("shop")
			learning.s.recipe = [1, 4]
			learning.s.bid = 8
			learning.s.cash = 10
			learning.s.phase = "offer"
			learning.message = "客人想吃%s，愿出 8 元。成本 %s，接单还是下一位？" % [learning.recipe_names(), learning.cost_expression()]
			if view == "fruit-supply":
				learning.s.room = "supply"
				learning.s.phase = "ingredients"
				learning.s.accepted_offer = true
				learning.message = "按订单挑两种水果，各自付款，再回楼上加工。"
			if view == "fruit-mix":
				learning.s.phase = "mix"
				learning.s.delivered = [0, 1, 0, 0, 1]
				learning.message = "两种口味放齐啦！各站一个脚印，同时按住 E / O。"
				players[0].position = Vector2(learning.MIX_LEFT, 600)
				players[1].position = Vector2(learning.MIX_RIGHT, 600)
		"names", "select-names":
			set_player_names("Jerry", "小伙伴")
			if view == "names": show_names(false)
			else: show_select()
		"home-sleep", "home-jump":
			home.state.items = []
			for data in [["bed", 5, 2], ["dining_chair", 11, 4], ["rug", 10, 3]]:
				home.state.items.append({"uid": home.state.items.size() + 1, "kind": data[0], "room": "home", "cell": [data[1], data[2]], "dir": 0})
			home.enter()
			home.use_furniture(0, 1)
			home.use_furniture(1, 2)
			if view == "home-sleep": home.use(0)
			else:
				home.jump_furniture(0)
				home.jump_furniture(1)
		"furniture-new":
			home.enter("furniture")
			home.display_page = 1
		"home-new":
			home.state.items = []
			for data in [["table", 5, 2], ["rug", 5, 2], ["tv", 11, 1], ["fan", 14, 1], ["plate", 5, 2], ["cup", 6, 2], ["cutlery", 7, 2], ["kettle", 5, 3], ["chair", 4, 5]]:
				home.state.items.append({"uid": home.state.items.size() + 1, "kind": data[0], "room": "home", "cell": [data[1], data[2]], "dir": 0})
			home.state.next_uid = home.state.items.size() + 1
			home.enter()
		"shop-offer-low", "shop-offer-high", "shop-new-change":
			learning.start("shop")
			learning.s.recipe = [0, 1]
			learning.s.bid = 2 if view == "shop-offer-low" else 6
			learning.s.cash = 5 if view == "shop-offer-low" else 9
			learning.s.phase = "offer"
			learning.message = "这位客人愿出 %d 元。苹果 1 元、莓果 2 元，接单还是下一位？" % learning.price()
			if view == "shop-new-change":
				learning.s.bid = 4
				learning.s.cash = 7
				learning.s.phase = "change"
				learning.s.tray = 2
				learning.message = "成交 4 元，客人付 7 元。分出要还给客人的零钱，再确认。"
		"settings":
			show_settings()
		"home-demo", "home-preview", "home-bag", "home-store":
			home.state.items = [
				{"uid": 1, "kind": "sofa", "room": "home", "cell": [3, 1], "dir": 0},
				{"uid": 2, "kind": "rug", "room": "home", "cell": [6, 2], "dir": 0},
				{"uid": 3, "kind": "table", "room": "home", "cell": [6, 2], "dir": 0},
				{"uid": 4, "kind": "plant", "room": "home", "cell": [13, 0], "dir": 0},
				{"uid": 5, "kind": "chair", "room": "inventory", "cell": [0, 0], "dir": 0},
				{"uid": 6, "kind": "bed", "room": "home", "cell": [14, 2], "dir": 0},
				{"uid": 7, "kind": "shelf", "room": "home", "cell": [10, 1], "dir": 0}]
			home.state.next_uid = 8
			home.enter()
			if view == "home-preview":
				home.take_kind(0, "chair")
				home.positions[0] = home.cell_center(Vector2i(4, 6))
			if view == "home-bag":
				home.bag_menu(0)
			if view == "home-store":
				home.positions[0] = home.cell_center(Vector2i(4, 2))
		"home", "furniture", "home-atlas":
			home.enter("furniture" if view == "furniture" else "home")
		"shop-mix", "shop-mix-one", "shop-change":
			learning.start("shop")
			learning.s.bid = 5
			learning.s.cash = 8 if view == "shop-change" else 5
			learning.s.delivered = [1, 1, 0, 0, 0]
			learning.s.recipe = [0, 1]
			learning.s.phase = "change" if view == "shop-change" else "mix"
			if view == "shop-change":
				learning.s.order = 1
				learning.s.tray = 2
				learning.message = "客人付了 8 元，冰激凌 5 元，分出要还给客人的零钱。"
			else:
				learning.message = "水果放齐啦！每人站一个金色脚印，同时按住自己的 E / O。"
			players[0].position = Vector2(learning.MIX_LEFT, 600)
			players[1].position = Vector2(learning.MIX_RIGHT, 600)
			if view == "shop-mix-one":
				Input.action_press("p1_use")
		"shop", "supply", "ducks", "balance", "balance-held", "balance-solved", "balance-wrong":
			learning.start("shop" if view in ["shop", "supply"] else "ducks10")
			if view == "supply":
				learning.s.room = "supply"
			if view == "ducks":
				learning.balance.rng.seed = 601
				learning.balance.generate()
			if view.begins_with("balance"):
				var board: Dictionary = learning.s.balance
				board.target = 6
				for n in range(6):
					board.tiles[n].text = str([8, 2, 4, 1, 7, 3][n])
				if view == "balance-held":
					board.carry[0] = 1
					board.tiles[1].place = "hand"
				if view in ["balance-solved", "balance-wrong"]:
					board.slots = [1 if view == "balance-solved" else 0, 6, 2]
					for id in board.slots:
						board.tiles[id].place = "slot"
			players[0].position.x = 350
			players[1].position.x = 660
		"title":
			show_title()
		"select":
			show_select()
		"fruit":
			start_game(1)
			players[0].position.x = 340
			players[1].position.x = 680
			players[0].carrying = true
			apples.remove_at(0)
		"fruit-layer":
			start_game(1)
			players[0].position.x = 600
			players[1].position.x = 650
			players[1].carrying = true
			apples.remove_at(0)
		"ending":
			start_game(3)
			lights = [true, true]
			solved = true
			players[0].position.x = 1040
			players[1].position.x = 1140
			_finish()
		"hold-one", "hold-both":
			start_game(3)
			players[0].position.x = 460
			players[1].position.x = 820
			Input.action_press("p1_use")
			if view == "hold-both":
				Input.action_press("p2_use")
		_:
			start_game(2)
			players[0].position.x = 330
			players[1].position.x = 765
			crank_by = 0
			barriers[0].collision_layer = 0
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _verify_release() -> void:
	# Run against the exported executable, including its embedded resources.
	for skin_id in range(SKINS.size()):
		if not _texture("res://assets/characters/%s/Idle (32x32).png" % SKINS[skin_id]):
			get_tree().quit(1)
			return
	start_game(0)
	players[0].position.x = 870
	players[1].position.x = 1030
	_tick_game()
	if not solved:
		get_tree().quit(1)
		return
	start_game(1)
	for x in [300, 600, 1010]:
		players[0].position.x = x
		interact(0)
		players[0].position.x = 780
		interact(0)
	players[0].position.x = 1010
	players[1].position.x = 1140
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	_tick_game(HOLD_SECONDS)
	Input.action_release("p1_use")
	Input.action_release("p2_use")
	if not solved or deposited != 3:
		get_tree().quit(1)
		return
	start_game(2)
	players[0].position.x = 280
	interact(0)
	players[1].position.x = 765
	interact(1)
	if not solved:
		get_tree().quit(1)
		return
	start_game(3)
	players[0].position.x = 460
	players[1].position.x = 820
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	_tick_game(HOLD_SECONDS)
	Input.action_release("p1_use")
	Input.action_release("p2_use")
	players[0].position.x = 1040
	interact(0)
	players[1].position.x = 1140
	interact(1)
	if mode != "ending":
		get_tree().quit(1)
		return
	learning.start("shop")
	learning.s.recipe = [0, 1]
	learning.accept_offer()
	learning.s.room = "supply"
	players[0].velocity = Vector2.ZERO
	players[0].position = Vector2(learning.supply_x(0), 600)
	learning.use(0)
	players[0].position.x = 790
	learning.use(0)
	players[0].position.x = 1060
	learning.use(0)
	if learning.s.stock != [1, 0, 0, 0, 0] or learning.s.wallet != 5:
		get_tree().quit(1)
		return
	learning.start("ducks20")
	var board: Dictionary = learning.s.balance
	var found := false
	for a in range(6):
		for b in range(6):
			if a == b:
				continue
			for op in [6, 7]:
				board.slots = [a, op, b]
				if learning.balance.expression_value() == board.target:
					board.tiles[a].place = "slot"
					board.tiles[b].place = "slot"
					board.tiles[op].place = "slot"
					found = true
					break
			if found: break
		if found: break
	learning.tick(0.1)
	if not found or not learning.s.done:
		get_tree().quit(1)
		return
	home.enter("furniture")
	if home.atlas == null or not home.buy(0, "plant"):
		get_tree().quit(1)
		return
	home.enter()
	if not home.take_kind(0, "plant") or not home.place(0, Vector2i(2, 2)):
		get_tree().quit(1)
		return
	print("RELEASE_VERIFY_OK: six skins, picnic journey, supply payment, solvable number scale, home atlas and furniture placement")
	get_tree().quit(0)
