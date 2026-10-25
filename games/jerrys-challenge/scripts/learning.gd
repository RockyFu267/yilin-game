extends RefCounted

const BalanceScript = preload("res://scripts/balance.gd")
const MIX_LEFT := 480.0
const MIX_RIGHT := 820.0
const MIX_RADIUS := 48.0
const FRUITS := [
	{"id": "apple", "name": "苹果", "price": 1, "file": "Apple.png", "color": Color("e98575")},
	{"id": "berry", "name": "草莓", "price": 2, "file": "Strawberry.png", "color": Color("ed91b3")},
	{"id": "orange", "name": "橙子", "price": 3, "file": "Orange.png", "color": Color("f3b35b")},
	{"id": "banana", "name": "香蕉", "price": 4, "file": "Bananas.png", "color": Color("f3df82")},
	{"id": "kiwi", "name": "猕猴桃", "price": 5, "file": "Kiwi.png", "color": Color("9fc969")}
]

# Independent learning adventures; the picnic keeps its existing rules and save.
const SAVE := "user://learning_progress.json"
var h
var activity := "ducks5"
var s: Dictionary = {}
var charge := 0.0
var message := ""
var balance
var market_rng := RandomNumberGenerator.new()

func _init(host) -> void:
	h = host
	balance = BalanceScript.new(self)
	market_rng.randomize()

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
		"stock": [0, 0, 0, 0, 0], "order": 0, "phase": "ingredients", "tray": 0,
		"purchase": -1, "purchase_funded": 0, "delivered": [0, 0, 0, 0, 0], "customer": 0, "served": 0}
	if kind == "shop":
		s.wallet = int(h.home.state.wallet)
		s.deal_version = 1
		s.phase = "offer"
		s.bid = 5
		s.cash = 5
		s.recipe = [0, 1]
		s.accepted_offer = false
	if kind == "ducks10":
		s.limit = 10
	elif kind == "ducks20":
		s.limit = 20
	_enter()
	if kind != "shop":
		balance.generate()
	else:
		next_customer()

func _enter() -> void:
	if activity == "shop" and not s.has("deal_version"):
		# An already accepted legacy order retains its agreed five-yuan price.
		s.deal_version = 1
		s.bid = 5
		s.cash = [5, 8, 10][clampi(int(s.get("order", 0)), 0, 2)]
	if activity == "shop": normalize_shop()
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

func normalize_shop() -> void:
	for field in ["stock", "delivered"]:
		while s[field].size() < FRUITS.size(): s[field].append(0)
	if not s.has("recipe"): s.recipe = [0, 1]
	# Old builds entered ingredients even before the player accepted anything.
	if not s.has("accepted_offer"):
		var untouched: bool = s.phase == "ingredients" and s.stock.all(func(n): return n == 0) and s.delivered.all(func(n): return n == 0) and s.hands == ["", ""] and s.purchase < 0 and s.tray == 0
		if untouched: s.phase = "offer"
		s.accepted_offer = s.phase not in ["offer", "celebrate"]
	if s.phase == "offer": s.room = "shop"

func recipe() -> Array:
	return s.get("recipe", [0, 1])

func recipe_names() -> String:
	return "%s＋%s" % [FRUITS[int(recipe()[0])].name, FRUITS[int(recipe()[1])].name]

func cost_expression() -> String:
	return "%d + %d" % [FRUITS[int(recipe()[0])].price, FRUITS[int(recipe()[1])].price]

func recipe_cost() -> int:
	return int(FRUITS[int(recipe()[0])].price) + int(FRUITS[int(recipe()[1])].price)

func ingredients_ready() -> bool:
	return s.delivered[int(recipe()[0])] == 1 and s.delivered[int(recipe()[1])] == 1

func fruit_index(id: String) -> int:
	for n in range(FRUITS.size()):
		if FRUITS[n].id == id: return n
	return -1

func supply_x(index: int) -> float:
	return 250.0 + index * 100.0

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
		if s.room == "shop" and s.phase == "mix" and ingredients_ready():
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
	return int(s.get("cash", 5))

func price() -> int:
	return int(s.get("bid", 5))

func next_customer() -> void:
	if s.phase not in ["offer", "celebrate"]: return
	var bids: Array = range(1, 11)
	bids.erase(price())
	var last_cash: int = s.get("last_cash", -1)
	var streak: int = s.get("cash_streak", 0)
	if last_cash == 10 and streak >= 2: bids.erase(10)
	s.bid = bids[market_rng.randi_range(0, bids.size() - 1)]
	var cash_options: Array = range(price(), 11)
	if streak >= 2 and cash_options.size() > 1: cash_options.erase(last_cash)
	s.cash = cash_options[market_rng.randi_range(0, cash_options.size() - 1)]
	s.cash_streak = streak + 1 if tender() == last_cash else 1
	s.last_cash = tender()
	s.customer = market_rng.randi_range(0, 3)
	var recipes: Array = []
	for a in range(FRUITS.size()):
		for b in range(a + 1, FRUITS.size()):
			if [a, b] != recipe(): recipes.append([a, b])
	s.recipe = recipes[market_rng.randi_range(0, recipes.size() - 1)]
	s.accepted_offer = false
	s.phase = "offer"
	s.order += 1
	s.tray = 0
	s.delivered = [0, 0, 0, 0, 0]
	say("客人想吃%s，愿出 %d 元。成本 %s，接单还是下一位？" % [recipe_names(), price(), cost_expression()])

func accept_offer() -> void:
	if s.phase != "offer": return
	var needed := 0
	for n in recipe():
		if s.stock[int(n)] + s.hands.count(FRUITS[int(n)].id) < 1: needed += int(FRUITS[int(n)].price)
	if not h.home.unlimited() and s.wallet < needed:
		say("这单的进货钱暂时不够。可以先看下一位，或回标题设置补充钱袋。")
		return
	s.phase = "ingredients"
	s.accepted_offer = true
	say("接下%s口味，成交 %d 元。成本 %s，买好对应水果后合作加工。" % [recipe_names(), price(), cost_expression()])

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
	if s.phase == "offer":
		if near(i, 1060): accept_offer()
		elif near(i, 910): next_customer()
		return
	if s.phase == "ingredients":
		for rack in range(2):
			var item: int = recipe()[rack]
			if near(i, 320 + rack * 160) and s.hands[i] == "" and s.stock[item] > 0:
				s.stock[item] -= 1
				s.hands[i] = FRUITS[item].id
				persist()
				return
		if near(i, 650, 65) and fruit_index(s.hands[i]) >= 0:
			var item := fruit_index(s.hands[i])
			if not item in recipe():
				say("客人想吃%s，这份水果不在订单里。" % recipe_names())
				return
			if s.delivered[item] == 0:
				s.delivered[item] = 1
				s.hands[i] = ""
				if ingredients_ready():
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
		say("成交 %d 元，客人付 %d 元。分出要还给客人的零钱，再确认。" % [price(), tender()])
	elif s.phase == "change":
		if near(i, 790) and s.tray < tender():
			s.tray += 1
		elif near(i, 910) and s.tray > 0:
			s.tray -= 1
		elif near(i, 1060):
			if s.tray == tender() - price():
				s.wallet += price()
				s.served += 1
				s.phase = "celebrate"
				var profit := price() - recipe_cost()
				var result := "赚钱了" if profit > 0 else ("亏钱了" if profit < 0 else "不赚不亏")
				var cost_label := "普通成本参考" if h.home.unlimited() else "原料成本"
				say("%d − %d = %d。%s %s，这单%s。" % [tender(), s.tray, price(), cost_label, cost_expression(), result])
			else:
				say("客人付的钱分两组：小店留下成交价 %d 元，其他的还给客人。" % price())
	elif s.phase == "celebrate" and near(i, 1060):
		next_customer()
	persist()

func supply_use(i: int) -> void:
	if s.phase == "offer":
		say("先回楼上看看客人出价，决定接单后再买水果。")
		return
	for item in range(FRUITS.size()):
		if near(i, supply_x(item), 44):
			if s.purchase >= 0:
				say("这笔先付好，或者把盘里的钱全部退回后再换水果。")
				return
			if not item in recipe():
				say("这单要%s，请挑订单里的水果。" % recipe_names())
				return
			var carried: String = FRUITS[item].id
			if s.phase != "ingredients" or s.stock[item] + s.delivered[item] + s.hands.count(carried) >= 1:
				say("这一单的这种水果已经够啦，不用重复买。")
				return
			s.purchase = item
			s.tray = 0
			s.purchase_funded = 0
			say("选好了！%s要 %d 元，去右边付款盘一枚枚放钱。" % [FRUITS[item].name, FRUITS[item].price])
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
		var cost: int = FRUITS[int(s.purchase)].price
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

func station(x: float, title: String, subtitle: String = "", width: float = 130) -> void:
	h.draw_rect(Rect2(x - (width - 32) / 2, 498, width - 32, 91), Color("62442e"))
	h.draw_rect(Rect2(x - (width - 20) / 2, 492, width - 20, 12), Color("c39960"))
	h.draw_rect(Rect2(x - (width - 42) / 2, 512, width - 42, 4), Color("8e6740"))
	h._panel(Rect2(x - width / 2, 412, width, 49), Color("503d32"))
	label(title, x, 441, 16 if width < 120 else 19)
	label(subtitle, x, 482, 16)

func coin(pos: Vector2) -> void:
	h.draw_rect(Rect2(pos, Vector2(18, 21)), Color("8d5c32"))
	h.draw_rect(Rect2(pos + Vector2(3, 0), Vector2(12, 18)), Color("f5cd68"))
	h.draw_rect(Rect2(pos + Vector2(7, 4), Vector2(3, 9)), Color("fff0a0"))

func fruit(pos: Vector2, berry: bool) -> void:
	fruit_sprite(pos, 1 if berry else 0)

func fruit_sprite(pos: Vector2, index: int) -> void:
	var texture = h._texture("res://assets/world/" + FRUITS[index].file)
	h.draw_texture_rect_region(texture, Rect2(pos - Vector2(24, 38), Vector2(48, 48)), Rect2(0, 0, 32, 32))

func ice(pos: Vector2) -> void:
	var lower: Color = FRUITS[int(recipe()[0])].color
	var upper: Color = FRUITS[int(recipe()[1])].color
	h.draw_colored_polygon(PackedVector2Array([pos + Vector2(-17, -8), pos + Vector2(17, -8), pos + Vector2(0, 26)]), Color("d6a268"))
	h.draw_rect(Rect2(pos + Vector2(-21, -28), Vector2(42, 22)), lower)
	h.draw_rect(Rect2(pos + Vector2(-16, -23), Vector2(8, 3)), lower.lightened(0.25))
	h.draw_rect(Rect2(pos + Vector2(-15, -37), Vector2(30, 12)), upper)
	h.draw_rect(Rect2(pos + Vector2(-9, -35), Vector2(8, 3)), upper.lightened(0.25))
	h.draw_rect(Rect2(pos + Vector2(-6, -43), Vector2(12, 9)), upper.darkened(0.12))

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
		if fruit_index(s.hands[i]) >= 0: fruit_sprite(pos, fruit_index(s.hands[i]))
		elif s.hands[i] == "ice": ice(pos)
	h._panel(Rect2(30, 641, 1220, 56), Color("49382d"))
	label("%s   A / D 移动  W 跳跃  E 互动          %s   ← / → 移动  ↑ 跳跃  O 互动" % [h.player_name(0), h.player_name(1)], 640, 675, 17)
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
		for n in range(FRUITS.size()):
			station(supply_x(n), "%s%d元" % [FRUITS[n].name, FRUITS[n].price], "选购", 92)
			fruit_sprite(Vector2(supply_x(n), 380), n)
		station(790, "放 1 元", "付款盘")
		station(910, "拿回 1 元", "空盘再按可取消")
		station(1060, "确认付款")
		label("请选择水果" if s.purchase < 0 else "这笔要付 %d 元" % FRUITS[int(s.purchase)].price, 900, 290, 23)
		label("订单：%s · 成本 %s" % [recipe_names(), cost_expression()], 470, 302, 18)
	else:
		label("森林冰激凌小铺", 570, 240, 28)
		h.draw_rect(Rect2(180, 471, 60, 116), Color("42352d"))
		h.draw_rect(Rect2(187, 478, 46, 107), Color("b68e60"))
		h.draw_rect(Rect2(218, 531, 7, 7), Color("f4d486"))
		label("新家", 210, 441, 20)
		label("一起到门口", 210, 464, 15)
		if s.phase == "ingredients":
			for rack in range(2):
				var n: int = recipe()[rack]
				station(320 + rack * 160, FRUITS[n].name + "储物架", "库存 %d" % s.stock[n])
				fruit_sprite(Vector2(320 + rack * 160, 380), n)
		if s.phase == "offer":
			station(650, "原料成本", cost_expression())
			fruit_sprite(Vector2(620, 380), int(recipe()[0]))
			fruit_sprite(Vector2(675, 380), int(recipe()[1]))
			station(910, "下一位", "不接这单")
		else:
			station(650, "加工中" if s.phase == "mix" else ("取冰激凌" if s.phase == "ready" else "加工台"), cost_expression())
		if s.phase == "change":
			station(790, "找回 1 元", "放进找零盘")
			station(910, "拿回 1 元", "调整找零")
		station(1060, "接单" if s.phase == "offer" else "客人 / 确认", "愿出 %d 元" % price() if s.phase == "offer" else "交货 / 结账 / 下一位")
		if s.phase == "mix":
			fruit_sprite(Vector2(630, 355), int(recipe()[0]))
			fruit_sprite(Vector2(670, 355), int(recipe()[1]))
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
		label("想吃：" + recipe_names(), 1035, 266, 18)
		label(("愿出 %d 元" if s.phase == "offer" else "成交 %d 元") % price(), 1070, 295, 22)
		if s.phase == "change":
			label("客人付 %d 元，店里留 %d 元" % [tender(), price()], 900, 332, 19)
			for n in range(tender() - s.tray):
				coin(Vector2(755 + n * 24, 343))
		if s.phase == "celebrate":
			label("谢谢！准备好了再接下一单", 900, 333, 19)
	label("钱袋：无限 · 已卖 %d 杯" % s.served if h.home.unlimited() else "钱袋 %d 元 · 已卖 %d 杯" % [s.wallet, s.served], 310, 273, 19)
	for n in range(s.tray):
		coin(Vector2(755 + n % 5 * 25, (371 if s.room == "shop" else 352) + int(n / 5) * 26))
	if s.purchase >= 0 or s.phase == "change":
		label("盘里 %d 元" % s.tray, 890, 403, 19)
