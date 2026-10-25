extends RefCounted

const BalanceScript = preload("res://scripts/balance.gd")
const MIX_LEFT := 480.0
const MIX_RIGHT := 820.0
const MIX_RADIUS := 48.0

# Independent learning adventures; the picnic keeps its existing rules and save.
const SAVE := "user://learning_progress.json"
var h
var activity := "ducks5"
var s: Dictionary = {}
var charge := 0.0
var message := ""
var balance

func _init(host) -> void:
	h = host
	balance = BalanceScript.new(self)

func start(kind: String) -> void:
	activity = kind
	if kind == "shop" and not h.home.state.shop.is_empty():
		s = h.home.state.shop.duplicate(true)
		s.wallet = int(h.home.state.wallet)
		_enter()
		message = "小店的水果、订单和钱都还在。左边的小门通往我们的新家。"
		return
	s = {"limit": 5,
		"hands": ["", ""], "done": false, "room": "shop", "wallet": 6,
		"stock": [0, 0], "order": 0, "phase": "ingredients", "tray": 0,
		"purchase": -1, "purchase_funded": 0, "delivered": [0, 0], "customer": 0, "served": 0}
	if kind == "shop":
		s.wallet = int(h.home.state.wallet)
	if kind == "ducks10":
		s.limit = 10
	elif kind == "ducks20":
		s.limit = 20
	_enter()
	if kind != "shop":
		balance.generate()
	else:
		message = "先一起到左边楼梯口，去地下材料铺买水果。"
		persist()

func _enter() -> void:
	h._unfreeze()
	h.mode = "learning"
	h.apples.clear()
	for body in h.barriers:
		body.queue_free()
	h.barriers.clear()
	if activity != "shop":
		h.barriers.append(h._make_solid(Rect2(1233, 420, 18, 180), true))
	for i in range(2):
		var p = h.players[i]
		p.set_skin(h.selected[i])
		p.position = Vector2(130 + i * 80, 600)
		p.velocity = Vector2.ZERO
		p.active = true
		p.carrying = false
		p.seated = false
	charge = 0
	buttons()

func buttons() -> void:
	h._clear_menu()
	if activity == "shop":
		h._button("数一数 / 提示", Rect2(910, 22, 180, 42), hint, false)
	h._button("休息 Esc", Rect2(1100, 22, 150, 42), pause, false)

func pause() -> void:
	h.paused = not h.paused
	charge = 0
	for p in h.players:
		p.set_physics_process(not h.paused)
	if not h.paused:
		buttons()
		return
	persist()
	h._clear_menu()
	h._button("继续玩", Rect2(460, 270, 360, 50), pause)
	h._button("重新集合（钱和原料保留）" if activity == "shop" else "重玩这一小段", Rect2(460, 335, 360, 48), retry, false)
	h._button("保存并回到标题", Rect2(460, 400, 360, 48), leave, false)

func retry() -> void:
	if activity == "shop":
		# Reposition the team without minting a new opening float or losing goods.
		_enter()
		message = "伙伴回到门口了，钱、原料和订单都保留。"
	else:
		h._unfreeze()
		balance.reset_board()
		buttons()

func leave() -> void:
	persist()
	h._unfreeze()
	h.show_title()

func persist() -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "activity": activity, "state": s, "skins": h.selected}))
	if activity == "shop":
		h.home.capture_shop(s)

func resume_saved() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not data is Dictionary or data.get("version") != 1 or not data.get("state") is Dictionary:
		message = "存档不可读取，可以从标题重新开始。"
		return
	if not data.get("activity", "") in ["shop", "ducks5", "ducks10", "ducks20"]:
		return
	activity = data.activity
	s = data.state
	if activity == "shop":
		if not h.home.state.shop.is_empty(): s = h.home.state.shop.duplicate(true)
		s.wallet = int(h.home.state.wallet)
	if activity != "shop" and (not s.get("balance") is Dictionary or s.balance.get("revision") != 2):
		start(activity)
		return
	for i in range(2):
		h.selected[i] = clampi(int(data.skins[i]), 0, h.SKINS.size() - 1)
	_enter()
	message = "小队回来啦！手里的东西和钱都保留了。"

func hint() -> void:
	if activity == "shop":
		message = "材料铺：选水果 → 一枚枚付款 → 确认。小店：放水果 → 两人加工 → 送货 → 找零。"
	else:
		message = "从两侧搬数字牌，中间放加号或减号，算出的结果要等于目标。"

func near(i: int, x: float, radius: float = 65.0) -> bool:
	return absf(h.players[i].position.x - x) < radius and h.players[i].position.y > 565 and absf(h.players[i].velocity.y) < 1.0

func say(text: String) -> void:
	message = text
	h._ping(600)
	persist()

func use(i: int) -> void:
	if h.paused or h.mode != "learning":
		return
	if activity == "shop":
		shop_use(i)
	else:
		balance.use(i)

func tick(delta: float) -> void:
	if activity != "shop":
		balance.tick(delta)
		for gate in h.barriers:
			gate.collision_layer = 0 if s.balance.solved else 1
	else:
		if s.room == "shop" and s.phase == "mix" and s.delivered == [1, 1]:
			var held := mix_holds()
			if held[0] and held[1]:
				charge += delta
				if charge >= 1.8:
					s.phase = "ready"
					charge = 0
					say("水果冰激凌做好啦！到中间取走，送给右边的客人。")
			else:
				charge = 0

func mix_holds() -> Array[bool]:
	var held: Array[bool] = [false, false]
	for i in range(2):
		if Input.is_action_pressed("p%d_use" % (i + 1)):
			held[0] = held[0] or near(i, MIX_LEFT, MIX_RADIUS)
			held[1] = held[1] or near(i, MIX_RIGHT, MIX_RADIUS)
	return held

func tender() -> int:
	return [5, 8, 10][mini(s.order, 2)]

func shop_use(i: int) -> void:
	if s.room == "shop" and near(i, 210, 35):
		if near(1 - i, 210, 65):
			persist()
			h.home.enter()
		else:
			say("两人一起到新家小门旁，再按互动回家。")
		return
	if near(i, 100):
		if near(1 - i, 100, 110):
			if s.purchase >= 0:
				say("先完成这笔购买，或在退回盘取回金币，再离开。")
				return
			s.room = "supply" if s.room == "shop" else "shop"
			charge = 0
			for p in h.players:
				p.position.x = 100 + p.player_id * 50
			say("地下材料铺：先选水果，再付款。" if s.room == "supply" else "回到小店啦，把水果送到加工台。")
		else:
			say("两位伙伴都到楼梯口，再按互动一起上下楼。")
		return
	if s.room == "supply":
		supply_use(i)
		return
	if s.phase == "ingredients":
		for item in range(2):
			if near(i, 320 + item * 160) and s.hands[i] == "" and s.stock[item] > 0:
				s.stock[item] -= 1
				s.hands[i] = "apple" if item == 0 else "berry"
				persist()
				return
		if near(i, 650, 65) and s.hands[i] in ["apple", "berry"]:
			var item := 0 if s.hands[i] == "apple" else 1
			if s.delivered[item] == 0:
				s.delivered[item] = 1
				s.hands[i] = ""
				if s.delivered == [1, 1]:
					s.phase = "mix"
					say("水果放齐啦！每人站一个金色脚印，同时按住自己的 E / O，让冰激凌机转起来。")
				persist()
	elif s.phase == "ready" and near(i, 650) and s.hands[i] == "":
		s.hands[i] = "ice"
		s.phase = "serve"
		say("把冰激凌带给右边的客人。")
	elif s.phase == "serve" and near(i, 1060, 85) and s.hands[i] == "ice":
		s.hands[i] = ""
		s.phase = "change"
		s.tray = 0
		say("客人给了 %d 元。冰激凌 5 元，给客人找零钱，再确认。" % tender())
	elif s.phase == "change":
		if near(i, 790) and s.tray < tender():
			s.tray += 1
		elif near(i, 910) and s.tray > 0:
			s.tray -= 1
		elif near(i, 1060):
			if s.tray == tender() - 5:
				s.wallet += 5
				s.served += 1
				s.phase = "celebrate"
				say("%d - %d = 5。留下售价，零钱找好啦！本单材料 3 元，多了 2 元。" % [tender(), s.tray])
			else:
				say("客人付的钱分两组：小店留下 5 元，其他的还给客人。")
	elif s.phase == "celebrate" and near(i, 1060):
		s.order = mini(s.order + 1, 2)
		s.customer = randi_range(0, 3)
		s.phase = "ingredients"
		s.delivered = [0, 0]
		s.tray = 0
		say("新客人也想要水果冰激凌。不着急，我们一起准备。")
	persist()

func supply_use(i: int) -> void:
	for item in range(2):
		if near(i, 330 + item * 180):
			if s.purchase >= 0:
				say("这笔先付好，或者把盘里的钱全部退回后再换水果。")
				return
			var carried := "apple" if item == 0 else "berry"
			if s.phase != "ingredients" or s.stock[item] + s.delivered[item] + s.hands.count(carried) >= 1:
				say("这一单的这种水果已经够啦，不用重复买。")
				return
			s.purchase = item
			s.tray = 0
			s.purchase_funded = 0
			say("选好了！%s要 %d 元，去右边付款盘一枚枚放钱。" % ["苹果" if item == 0 else "莓果", item + 1])
			return
	if s.purchase < 0:
		return
	if near(i, 790) and (s.wallet > 0 or h.home.unlimited()) and s.tray < 10:
		var funded: int = s.get("purchase_funded", s.tray)
		if not h.home.unlimited():
			s.wallet -= 1
			funded += 1
		s.purchase_funded = funded
		s.tray += 1
	elif near(i, 910):
		if s.tray > 0:
			var funded: int = s.get("purchase_funded", s.tray)
			s.tray -= 1
			if funded > 0:
				s.wallet += 1
				funded -= 1
			s.purchase_funded = funded
		else:
			s.purchase = -1
			say("取消购买，可以重新选水果。")
	elif near(i, 1060):
		var cost: int = s.purchase + 1
		if s.tray == cost:
			s.stock[s.purchase] += 1
			s.purchase = -1
			s.tray = 0
			s.purchase_funded = 0
			say("钱正好，水果放进小店的储物架了。另一个水果也买好就能回楼上。")
		else:
			say("这份水果要 %d 元，再数数盘里的钱；多了可以拿回。" % cost)
	persist()

func label(text: String, x: float, y: float, size: int = 20) -> void:
	h._center(text, y, size, h.CREAM, false, x)

func station(x: float, title: String, subtitle: String = "") -> void:
	h.draw_rect(Rect2(x - 49, 498, 98, 91), Color("62442e"))
	h.draw_rect(Rect2(x - 55, 492, 110, 12), Color("c39960"))
	h.draw_rect(Rect2(x - 44, 512, 88, 4), Color("8e6740"))
	h._panel(Rect2(x - 65, 412, 130, 49), Color("503d32"))
	label(title, x, 441, 19)
	label(subtitle, x, 482, 16)

func coin(pos: Vector2) -> void:
	h.draw_rect(Rect2(pos, Vector2(18, 21)), Color("8d5c32"))
	h.draw_rect(Rect2(pos + Vector2(3, 0), Vector2(12, 18)), Color("f5cd68"))
	h.draw_rect(Rect2(pos + Vector2(7, 4), Vector2(3, 9)), Color("fff0a0"))

func fruit(pos: Vector2, berry: bool) -> void:
	var texture = h._texture("res://assets/world/Strawberry.png" if berry else "res://assets/world/Apple.png")
	h.draw_texture_rect_region(texture, Rect2(pos - Vector2(24, 38), Vector2(48, 48)), Rect2(0, 0, 32, 32))

func ice(pos: Vector2) -> void:
	h.draw_colored_polygon(PackedVector2Array([pos + Vector2(-17, -8), pos + Vector2(17, -8), pos + Vector2(0, 26)]), Color("d6a268"))
	h.draw_rect(Rect2(pos + Vector2(-21, -28), Vector2(42, 22)), Color("f3b0b2"))
	h.draw_rect(Rect2(pos + Vector2(-15, -37), Vector2(30, 12)), Color("fff0cd"))
	h.draw_rect(Rect2(pos + Vector2(-6, -43), Vector2(12, 9)), Color("c66b75"))

func paint() -> void:
	if activity == "shop":
		paint_shop()
	else:
		balance.paint()
	h._panel(Rect2(25, 18, 570, 75), Color("49382d"))
	label("冰激凌小铺 · 十以内算账" if activity == "shop" else "数字天平桥 · %d 以内" % s.limit, 310, 52, 24)
	label("没有计时，慢慢想 · E / O 互动", 310, 78, 17)
	h._panel(Rect2(30, 111, 1220, 66), Color("49382d"))
	var lines: Array[String] = [""]
	for letter in message:
		if h.font.get_string_size(lines[-1] + letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 1160:
			lines.append("")
		lines[-1] += letter
	for n in range(mini(lines.size(), 2)):
		label(lines[n], 640, 139 + n * 25, 18)
	for i in range(2):
		var pos: Vector2 = h.players[i].position + Vector2(0, -130)
		match s.hands[i]:
			"apple": fruit(pos, false)
			"berry": fruit(pos, true)
			"ice": ice(pos)
	h._panel(Rect2(30, 641, 1220, 56), Color("49382d"))
	label("Tom   A / D 移动  W 跳跃  E 互动          Jerry   ← / → 移动  ↑ 跳跃  O 互动", 640, 675, 19)
	if h.paused:
		h.draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.14, 0.13, 0.8))
		h._panel(Rect2(420, 185, 440, 300))
		label("休息一下，小伙伴会等你", 640, 240, 25)

func paint_shop() -> void:
	# Same chunky pixels as the garden, with a shared-screen floor transition.
	h.draw_rect(Rect2(0, 179, 1280, 405), Color("8c6c51"))
	for y in range(190, 580, 36):
		h.draw_rect(Rect2(0, y, 1280, 3), Color("a6805b"))
	for x in [170, 610, 1140]:
		h.draw_rect(Rect2(x, 195, 12, 380), Color("634832"))
	for x in range(0, 1280, 64):
		h.draw_rect(Rect2(x, 180, 64, 24), Color("e7b8a0") if x % 128 == 0 else Color("f5dfb0"))
	# Wooden indoor floor, rather than grass inside the shop.
	h.draw_rect(Rect2(0, 585, 1280, 135), Color("b28a5e"))
	for y in range(588, 720, 18):
		h.draw_rect(Rect2(0, y, 1280, 3), Color("795738"))
		for x in range(0, 1280, 96):
			h.draw_rect(Rect2(x + (48 if y % 36 == 12 else 0), y, 3, 18), Color("8f6845"))
	station(100, "一起上下楼", "双方到齐再互动")
	for n in range(6):
		h.draw_rect(Rect2(46 + n * 14, 582 - n * 10, 20, 10), Color("d9b580"))
	if s.room == "supply":
		label("地下材料铺", 600, 242, 28)
		station(330, "苹果 1 元", "选购")
		station(510, "莓果 2 元", "选购")
		fruit(Vector2(330, 380), false)
		fruit(Vector2(510, 380), true)
		station(790, "放 1 元", "付款盘")
		station(910, "拿回 1 元", "空盘再按可取消")
		station(1060, "确认付款")
		label("请选择水果" if s.purchase < 0 else "这笔要付 %d 元" % (s.purchase + 1), 900, 290, 23)
	else:
		label("森林冰激凌小铺", 570, 240, 28)
		h.draw_rect(Rect2(180, 471, 60, 116), Color("42352d"))
		h.draw_rect(Rect2(187, 478, 46, 107), Color("b68e60"))
		h.draw_rect(Rect2(218, 531, 7, 7), Color("f4d486"))
		label("新家", 210, 441, 20)
		label("一起到门口", 210, 464, 15)
		if s.phase == "ingredients":
			station(320, "苹果储物架", "库存 %d" % s.stock[0])
			station(480, "莓果储物架", "库存 %d" % s.stock[1])
			fruit(Vector2(320, 380), false)
			fruit(Vector2(480, 380), true)
		station(650, "加工中" if s.phase == "mix" else ("取冰激凌" if s.phase == "ready" else "加工台"), "苹果 1 + 莓果 1")
		if s.phase == "change":
			station(790, "找回 1 元", "放进找零盘")
			station(910, "拿回 1 元", "调整找零")
		station(1060, "客人 / 确认", "交货 / 结账 / 下一位")
		if s.phase == "mix":
			fruit(Vector2(630, 355), false)
			fruit(Vector2(670, 355), true)
			h.draw_rect(Rect2(611, 366, 78, 10), Color("eddbb3"))
			h.draw_rect(Rect2(620, 376, 60, 21), Color("91b7b1"))
			h.draw_rect(Rect2(628, 397, 44, 6), Color("527e7a"))
		elif s.phase == "ready":
			ice(Vector2(650, 375))
		if s.phase == "mix":
			label("每人一个脚印 · 同时按住 E / O", 650, 290, 20)
			var held := mix_holds()
			for side in range(2):
				var stand_x: float = MIX_LEFT if side == 0 else MIX_RIGHT
				var lever_x := stand_x + (48 if side == 0 else -48)
				h._lever(Vector2(lever_x, 585), held[side], Color("f6cc7c") if side == 0 else Color("bce0ab"))
				h.draw_rect(Rect2(stand_x - 22, 587, 17, 7), Color("f6cc7c"))
				h.draw_rect(Rect2(stand_x + 5, 587, 17, 7), Color("f6cc7c"))
				label("已按住 ✓" if held[side] else "站脚印，按住互动", stand_x, 439, 18)
				label("搅拌木柄" if side == 0 else "装杯木柄", stand_x, 472, 18)
			h.draw_rect(Rect2(530, 320, 170 * minf(charge / 1.8, 1.0), 9), Color("f6cc7c"))
		h._sprite(s.customer, Vector2(1180, 590), 2.8)
		label("想买：水果冰激凌", 1070, 266, 18)
		label("售价 5 元", 1070, 295, 22)
		if s.phase == "change":
			label("客人付 %d 元，店里留 5 元" % tender(), 900, 332, 19)
			for n in range(tender() - s.tray):
				coin(Vector2(755 + n * 24, 343))
		if s.phase == "celebrate":
			label("谢谢！准备好了再接下一单", 900, 333, 19)
	label("钱袋：无限 · 已卖 %d 杯" % s.served if h.home.unlimited() else "钱袋 %d 元 · 已卖 %d 杯" % [s.wallet, s.served], 310, 273, 19)
	for n in range(s.tray):
		coin(Vector2(755 + n % 5 * 25, (371 if s.room == "shop" else 352) + int(n / 5) * 26))
	if s.purchase >= 0 or s.phase == "change":
		label("盘里 %d 元" % s.tray, 890, 403, 19)
