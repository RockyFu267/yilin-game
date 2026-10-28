extends RefCounted

const SaveStore = preload("res://scripts/save_store.gd")

const SAVE := "user://family_home.json"
const ATLAS := "res://assets/home/interiors_demo.png"
const CELL := 48
const COLS := 18
const ROWS := 8
const ORIGIN := Vector2(208, 224)
const RESERVE := 3
# The regions are from the free Pixel Lands demo, not its paid kitchen pack.
# Alternate views are authored sprites, never a rotated upright furniture image.
const GOODS := [
	{"id": "plant", "name": "大盆栽", "price": 1, "size": [1, 1], "art": [[224, 96, 16, 32]], "solid": true},
	{"id": "flower", "name": "小花盆", "price": 1, "size": [1, 1], "art": [[240, 112, 16, 16]], "solid": true},
	{"id": "rug", "name": "红地毯", "price": 3, "size": [3, 3], "art": [[80, 80, 48, 48]], "solid": false},
	{"id": "chair", "name": "小椅子", "price": 2, "size": [2, 1], "art": [[128, 0, 32, 32], [160, 0, 32, 32], [192, 0, 32, 32], [224, 0, 32, 32]], "solid": true},
	{"id": "table", "name": "木餐桌", "price": 4, "size": [3, 2], "art": [[192, 144, 48, 32]], "solid": true},
	{"id": "sofa", "name": "小沙发", "price": 5, "size": [3, 1], "art": [[0, 128, 48, 32], [80, 128, 48, 32]], "solid": true},
	{"id": "bed", "name": "小床", "price": 6, "size": [2, 3], "art": [[224, 32, 32, 64]], "solid": true},
	{"id": "shelf", "name": "书柜", "price": 4, "size": [2, 1], "art": [[160, 128, 32, 48]], "solid": true},
	{"id": "tv", "name": "电视机", "price": 8, "size": [2, 1], "art": [[0, 0, 32, 32]], "solid": true, "own": true},
	{"id": "plate", "name": "餐盘", "price": 1, "size": [1, 1], "art": [[0, 0, 16, 16]], "solid": false, "own": true, "tabletop": true},
	{"id": "cutlery", "name": "餐具", "price": 2, "size": [1, 1], "art": [[0, 0, 16, 16]], "solid": false, "own": true, "tabletop": true},
	{"id": "cup", "name": "水杯", "price": 1, "size": [1, 1], "art": [[0, 0, 16, 16]], "solid": false, "own": true, "tabletop": true},
	{"id": "fan", "name": "电风扇", "price": 5, "size": [1, 1], "art": [[0, 0, 16, 32]], "solid": true, "own": true},
	{"id": "kettle", "name": "水壶", "price": 3, "size": [1, 1], "art": [[0, 0, 16, 16]], "solid": false, "own": true, "tabletop": true},
	{"id": "dining_chair", "name": "餐椅", "price": 2, "size": [1, 1], "art": [[128, 96, 16, 32], [144, 96, 16, 32], [160, 96, 16, 32], [176, 96, 16, 32]], "solid": true}
]
var h
var state: Dictionary = {"version": 1, "wallet": 6, "next_uid": 1, "items": [], "shop": {}, "unlimited_money": false}
var room := "home"
var positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var facing: Array[Vector2i] = [Vector2i.DOWN, Vector2i.DOWN]
var face_x: Array[float] = [1.0, -1.0]
var moving: Array[bool] = [false, false]
var hands: Array[int] = [-1, -1]
var directions: Array[int] = [0, 0]
var message := "空房间就是我们的新家。先去家具店看看吧！"
var menu_kind := ""
var bag_owner := 0
var bag_choice := 0
var atlas: Texture2D
var owned_textures: Dictionary = {}
var display_page := 0
var storage_notice := ""
# Furniture play is transient: never changes ownership or the saved arrangement.
var play: Array = [{}, {}]

func playable(kind: String) -> bool:
	return kind in ["bed", "chair", "dining_chair", "sofa"]

func leave_play(i: int) -> bool:
	if play[i].is_empty(): return true
	var entry := item(int(play[i].uid))
	var rect := item_rect(entry)
	var candidates: Array[Vector2] = [Vector2(rect.get_center().x, rect.end.y + 24), Vector2(rect.position.x - 28, rect.end.y), Vector2(rect.end.x + 28, rect.end.y), Vector2(rect.get_center().x, rect.position.y - 22)]
	for pos in candidates:
		if walkable(pos):
			positions[i] = pos
			play[i] = {}
			return true
	message = "旁边有家具挡住了，先请伙伴挪开周围的家具。"
	return false

func use_furniture(i: int, uid: int) -> bool:
	var entry := item(uid)
	if not playable(entry.kind): return false
	for n in range(2):
		if n != i and not play[n].is_empty() and int(play[n].uid) == uid:
			message = "伙伴正在这里玩，试试另一张床或椅子吧！"
			return true
	play[i] = {"uid": uid, "pose": "stand" if entry.kind == "bed" else "sit", "jump": 0.0}
	var rect := item_rect(entry)
	positions[i] = Vector2(rect.get_center().x, rect.end.y - (48 if entry.kind == "bed" else 22))
	moving[i] = false
	message = "E / O 切换姿势；W / ↑ 蹦蹦；左右或向下离开。R / 斜杠搬动，Q / Backspace 收纳。"
	return true

func jump_furniture(i: int) -> void:
	if play[i].is_empty() or float(play[i].jump) > 0: return
	play[i].pose = "stand"
	play[i].jump = 0.72
	h._ping(620)


func _init(host) -> void:
	h = host
	var loaded := SaveStore.read_family(SAVE)
	if not loaded.data.is_empty():
		state = loaded.data
		if loaded.recovered: storage_notice = "存档读取异常，已从自动备份恢复。"
	elif loaded.invalid:
		storage_notice = "旧存档读取失败；原文件会保留在备份目录。"
	elif FileAccess.file_exists("user://learning_progress.json"):
		var old = JSON.parse_string(FileAccess.get_file_as_string("user://learning_progress.json"))
		if old is Dictionary and old.get("activity") == "shop" and old.get("state") is Dictionary:
			state.wallet = maxi(0, int(old.state.get("wallet", 6)))
			state.shop = old.state.duplicate(true)
	if ResourceLoader.exists(ATLAS):
		atlas = load(ATLAS)
	_build_owned_art()

func _build_owned_art() -> void:
	# Original code-drawn pixel objects fill gaps in the free furniture demo.
	var shapes := {
		"tv": [[2,4,28,22,"493d3b"],[4,6,22,17,"82aaa6"],[6,8,18,12,"b9dfce"],[8,9,12,2,"e0efcf"],[27,9,2,3,"e3bb70"],[27,15,2,2,"c16d59"],[7,26,4,3,"604738"],[23,26,4,3,"604738"],[9,29,17,2,"aa7b4c"],[12,0,2,5,"765b46"],[14,3,7,2,"765b46"]],
		"plate": [[3,3,10,10,"849b94"],[1,5,14,6,"b8d2ca"],[4,2,8,12,"e4e7cc"],[2,5,12,6,"e4e7cc"],[5,5,6,6,"9fc0b4"],[6,6,4,4,"d5e1c5"]],
		"cutlery": [[2,2,1,4,"e4ddbd"],[4,2,1,4,"e4ddbd"],[6,2,1,4,"e4ddbd"],[2,6,5,2,"b6c2bc"],[4,8,2,6,"9baea8"],[11,2,2,8,"dddcc2"],[10,3,3,5,"dddcc2"],[11,10,2,4,"9baea8"]],
		"cup": [[3,3,8,11,"6b9292"],[4,4,6,9,"a4d6d1"],[4,3,6,2,"e4e7cf"],[11,5,4,6,"8ab9b4"],[11,7,2,2,"4a665f"],[4,12,6,2,"5e8a88"]],
		"fan": [[3,2,10,2,"647e7d"],[1,4,14,12,"647e7d"],[3,3,10,15,"a8c6bd"],[2,5,12,10,"d1dfc8"],[7,6,2,8,"6f9c9d"],[4,8,8,3,"6f9c9d"],[6,6,3,3,"8bb7ad"],[8,11,3,3,"8bb7ad"],[7,17,2,10,"628680"],[4,27,8,2,"b1c9b7"],[2,29,12,2,"6a9188"]],
		"kettle": [[4,5,9,8,"d4c5a0"],[5,4,7,2,"dcae6d"],[7,2,4,2,"6b5d4e"],[1,7,4,3,"bda985"],[0,5,2,3,"d4c5a0"],[13,5,2,7,"705f4d"],[12,5,3,2,"705f4d"],[4,12,9,2,"a9926f"],[7,7,4,3,"e6d7b2"]]
	}
	for entry in GOODS:
		if not entry.get("own", false): continue
		var source: Array = entry.art[0]
		var image := Image.create(source[2], source[3], false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for part in shapes[entry.id]:
			image.fill_rect(Rect2i(part[0], part[1], part[2], part[3]), Color(part[4]))
		owned_textures[entry.id] = ImageTexture.create_from_image(image)

func art_texture(kind: String) -> Texture2D:
	return owned_textures.get(kind, atlas)

func save() -> void:
	var error := SaveStore.write_family(SAVE, state)
	if error != OK:
		storage_notice = "保存失败，请查看存档目录的读写权限。"
		push_error("Family save failed: " + str(error))

func capture_shop(snapshot: Dictionary) -> void:
	state.wallet = int(snapshot.wallet)
	state.shop = snapshot.duplicate(true)
	save()

func unlimited() -> bool:
	return bool(state.get("unlimited_money", false))

func toggle_unlimited() -> void:
	state.unlimited_money = not unlimited()
	save()

func set_money(amount: int, clear_payment: bool = false) -> void:
	state.wallet = maxi(0, amount)
	var snapshots: Array = [state.shop]
	if h.learning.activity == "shop": snapshots.append(h.learning.s)
	for snapshot in snapshots:
		if snapshot.is_empty(): continue
		snapshot.wallet = state.wallet
		if clear_payment:
			snapshot.tray = 0
			snapshot.purchase = -1
			snapshot.purchase_funded = 0
	save()

func enter(destination: String = "home") -> void:
	if h.mode == "learning" and h.learning.activity == "shop":
		h.learning.persist()
	pack_all()
	room = destination
	h._unfreeze()
	h.mode = "home"
	for p in h.players:
		p.active = false
		p.velocity = Vector2.ZERO
		p.set_skin(h.selected[p.player_id])
	positions = [cell_center(Vector2i(8, 6)), cell_center(Vector2i(10, 6))]
	facing = [Vector2i.UP, Vector2i.UP]
	message = "靠近家具按 Q / Backspace 收回库存；空地按同一键打开家具包。" if room == "home" else ("无限金钱已开启，走近家具按 E / O 购买。" if unlimited() else "走到喜欢的家具旁，按 E / O 购买。预留 3 元备用金，其余可装修。")
	buttons()
	save()

func buttons() -> void:
	menu_kind = ""
	h._clear_menu()
	h._button("休息 Esc", Rect2(1100, 23, 150, 42), escape, false)
	if room == "furniture":
		h._button("← 上一页", Rect2(775, 23, 140, 42), func(): turn_page(-1), false)
		h._button("下一页 →", Rect2(930, 23, 140, 42), func(): turn_page(1), false)

func turn_page(turn: int) -> void:
	if h.mode != "home" or h.paused or room != "furniture": return
	display_page = posmod(display_page + turn, int(ceil(GOODS.size() / 8.0)))
	message = "家具第 %d 页；右上角鼠标翻页，走近商品按 E / O 购买。" % (display_page + 1)
	buttons()

func pack_all() -> void:
	play = [{}, {}]
	hands = [-1, -1]
	directions = [0, 0]

func reset_decorations() -> void:
	pack_all()
	state.items.clear()
	save()
	message = "小家和家具库存已全部清空，钱和订单保留。"

func exit_to_title() -> void:
	pack_all()
	save()
	h._unfreeze()
	h.show_title()

func go_shop() -> void:
	pack_all()
	save()
	h._unfreeze()
	h.learning.start("shop")

func good(kind: String) -> Dictionary:
	for entry in GOODS:
		if entry.id == kind: return entry
	return GOODS[0]

func item(uid: int) -> Dictionary:
	for entry in state.items:
		if int(entry.uid) == uid: return entry
	return {}

func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2.ONE * CELL / 2

func item_rect(entry: Dictionary, cell_override = null) -> Rect2:
	var cell: Vector2 = Vector2(entry.cell[0], entry.cell[1]) if cell_override == null else Vector2(cell_override)
	var size: Array = good(entry.kind).size
	return Rect2(ORIGIN + cell * CELL, Vector2(size[0], size[1]) * CELL)

func avatar_rect(pos: Vector2) -> Rect2:
	return Rect2(pos - Vector2(12, 16), Vector2(24, 18))

func walkable(pos: Vector2) -> bool:
	var body := avatar_rect(pos)
	if not Rect2(ORIGIN + Vector2(12, 15), Vector2(COLS * CELL - 24, ROWS * CELL - 17)).has_point(pos):
		return false
	if room == "home":
		for entry in state.items:
			if entry.room == "home" and good(entry.kind).solid and body.intersects(item_rect(entry)):
				return false
	return true

func tick(delta: float) -> void:
	for i in range(2):
		if not play[i].is_empty():
			play[i].jump = maxf(0.0, float(play[i].jump) - delta)
			var sideways := Input.get_axis("p%d_left" % (i + 1), "p%d_right" % (i + 1))
			if absf(sideways) > 0.1 or Input.is_action_pressed("home_p%d_down" % (i + 1)):
				leave_play(i)
			continue
		var direction := Input.get_vector("p%d_left" % (i + 1), "p%d_right" % (i + 1), "home_p%d_up" % (i + 1), "home_p%d_down" % (i + 1))
		moving[i] = direction.length() > 0.1
		if not moving[i]: continue
		if absf(direction.x) > absf(direction.y):
			facing[i] = Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
		else:
			facing[i] = Vector2i.DOWN if direction.y > 0 else Vector2i.UP
		if direction.x != 0: face_x[i] = signf(direction.x)
		# Substeps keep solid furniture blocking even when a frame is slow.
		var remaining := minf(delta, 0.2)
		while remaining > 0:
			var step := minf(remaining, 0.016)
			var next := positions[i] + Vector2(direction.x, 0) * 190 * step
			if walkable(next): positions[i] = next
			next = positions[i] + Vector2(0, direction.y) * 190 * step
			if walkable(next): positions[i] = next
			remaining -= step

func input(event: InputEventKey) -> void:
	for i in range(2):
		var use_key := KEY_E if i == 0 else KEY_O
		if h.paused:
			if menu_kind == "bag" and i == bag_owner:
				if event.physical_keycode in ([KEY_A, KEY_D] if i == 0 else [KEY_LEFT, KEY_RIGHT]):
					bag_choice = posmod(bag_choice + (-1 if event.physical_keycode in [KEY_A, KEY_LEFT] else 1), GOODS.size())
					bag_menu(i, false)
				elif event.physical_keycode == use_key:
					take_kind(i, GOODS[bag_choice].id)
			continue
		if not play[i].is_empty() and event.physical_keycode == (KEY_W if i == 0 else KEY_UP):
			jump_furniture(i)
		elif event.physical_keycode == use_key:
			use(i)
		elif event.physical_keycode == (KEY_R if i == 0 else KEY_SLASH):
			rotate(i)
		elif event.physical_keycode == (KEY_Q if i == 0 else KEY_BACKSPACE):
			if not store_nearby(i):
				bag_menu(i)

func escape() -> void:
	if h.paused:
		h.paused = false
		buttons()
		return
	h.paused = true
	menu_kind = "pause"
	h._clear_menu()
	h._button("继续布置", Rect2(440, 270, 400, 50), escape)
	h._button("收好家具，回冰激凌店", Rect2(440, 336, 400, 48), go_shop, false)
	h._button("保存并回到标题", Rect2(440, 400, 400, 48), exit_to_title, false)

func inventory_count(kind: String) -> int:
	var count := 0
	for entry in state.items:
		if entry.kind == kind and entry.room == "inventory" and not int(entry.uid) in hands:
			count += 1
	return count

func bag_menu(i: int, reset: bool = true) -> void:
	if room != "home":
		message = "买好的家具会收进包里，回到新家再摆放。"
		return
	bag_owner = i
	if reset: bag_choice = 0
	h.paused = true
	menu_kind = "bag"
	h._clear_menu()
	var page := int(bag_choice / 8)
	for n in range(page * 8, mini(page * 8 + 8, GOODS.size())):
		var entry: Dictionary = GOODS[n]
		var caption: String = ("▶ " if n == bag_choice else "") + entry.name + " × %d" % inventory_count(entry.id)
		var local := n % 8
		var button: Button = h._button(caption, Rect2(345 + local % 2 * 305, 237 + int(local / 2) * 65, 285, 49), func(): take_kind(i, entry.id), n == bag_choice)
		if art_texture(entry.id):
			var source: Array = entry.art[0]
			var icon := Sprite2D.new()
			var texture := AtlasTexture.new()
			texture.atlas = art_texture(entry.id)
			texture.region = Rect2(source[0], source[1], source[2], source[3])
			icon.texture = texture
			icon.position = Vector2(28, 24)
			icon.scale = Vector2.ONE * minf(39.0 / source[2], 39.0 / source[3])
			button.add_child(icon)
	h._button("上一页", Rect2(345, 516, 140, 43), func(): bag_choice = posmod(page - 1, int(ceil(GOODS.size() / 8.0))) * 8; bag_menu(i, false), false)
	h._button("关上家具包 Esc", Rect2(495, 516, 270, 43), escape, false)
	h._button("下一页", Rect2(775, 516, 140, 43), func(): bag_choice = posmod(page + 1, int(ceil(GOODS.size() / 8.0))) * 8; bag_menu(i, false), false)

func take_kind(i: int, kind: String) -> bool:
	if hands[i] >= 0: return false
	for entry in state.items:
		if entry.kind == kind and entry.room == "inventory" and not int(entry.uid) in hands:
			hands[i] = int(entry.uid)
			directions[i] = int(entry.dir)
			h.paused = false
			buttons()
			message = "走到喜欢的位置，E / O 放下；R / 斜杠键换朝向，Q / Backspace 收纳。"
			return true
	message = "这件家具还没有存货，去家具店买，或先把家里的收回来。"
	return false

func buy(i: int, kind: String) -> bool:
	if room != "furniture": return false
	var entry := good(kind)
	if not unlimited() and int(state.wallet) - int(entry.price) < RESERVE:
		message = "这件 %d 元，可装修的钱有 %d 元；我们留 3 元作备用金。" % [entry.price, maxi(0, int(state.wallet) - RESERVE)]
		return false
	if not unlimited(): state.wallet -= int(entry.price)
	var owned := {"uid": int(state.next_uid), "kind": kind, "room": "inventory", "cell": [0, 0], "dir": 0}
	state.next_uid += 1
	state.items.append(owned)
	# Wallet and furniture ownership live in the same save transaction.
	if not state.shop.is_empty(): state.shop.wallet = state.wallet
	if h.learning.activity == "shop" and not h.learning.s.is_empty(): h.learning.s.wallet = state.wallet
	save()
	message = ("无限金钱：%s已放进家具包，回家就能摆放。" % entry.name) if unlimited() else ("%s买好啦！%d 元 − %d 元 = %d 元，回家从家具包拿出来摆。" % [entry.name, int(state.wallet) + int(entry.price), entry.price, state.wallet])
	h._ping(700)
	return true

func preview_cell(i: int) -> Vector2i:
	var cell := Vector2i(((positions[i] - ORIGIN) / CELL).floor()) + facing[i] * 2
	if hands[i] >= 0:
		var size: Array = good(item(hands[i]).kind).size
		cell -= Vector2i(int(size[0]) / 2, int(size[1]) / 2)
	return cell

func can_place(i: int, cell: Vector2i) -> bool:
	if room != "home" or hands[i] < 0: return false
	var entry := item(hands[i])
	var size: Array = good(entry.kind).size
	# Bottom row stays a walkable route to both doors.
	if cell.x < 0 or cell.y < 0 or cell.x + size[0] > COLS or cell.y + size[1] > ROWS - 1: return false
	var rect := item_rect(entry, cell)
	var source: Array = good(entry.kind).art[posmod(directions[i], good(entry.kind).art.size())]
	if rect.end.y - source[3] * 3 < ORIGIN.y - 64: return false
	for other in state.items:
		if other.room == "home" and placement_layer(other.kind) == placement_layer(entry.kind) and rect.intersects(item_rect(other)):
			return false
	if good(entry.kind).solid:
		for pos in positions:
			if rect.intersects(avatar_rect(pos)): return false
	return true

func placement_layer(kind: String) -> String:
	return "surface" if good(kind).get("tabletop", false) else ("solid" if good(kind).solid else "floor")

func furniture_depth(entry: Dictionary) -> float:
	var depth := item_rect(entry).end.y
	if good(entry.kind).get("tabletop", false):
		for other in state.items:
			if other.room == "home" and good(other.kind).solid and item_rect(entry).intersects(item_rect(other)):
				depth = maxf(depth, item_rect(other).end.y + 0.1)
	return depth

func place(i: int, cell: Vector2i) -> bool:
	if not can_place(i, cell):
		message = "这里放不下：挪开一点，避开家具、伙伴和门口的通道。"
		return false
	var entry := item(hands[i])
	entry.room = "home"
	entry.cell = [cell.x, cell.y]
	entry.dir = directions[i]
	hands[i] = -1
	save()
	message = "摆好啦！床椅用 E / O 玩耍、R / 斜杠搬动；Q / Backspace 收回库存。"
	return true

func rotate(i: int) -> void:
	if hands[i] < 0:
		var uid := int(play[i].uid) if not play[i].is_empty() else nearby_furniture(i)
		if uid >= 0 and playable(item(uid).kind):
			if leave_play(i): pickup(i, uid)
		return
	var count: int = good(item(hands[i]).kind).art.size()
	if count == 1:
		message = "这件素材目前只有一个朝向；椅子有四向，沙发有前后两向。"
	else:
		directions[i] = (directions[i] + 1) % count
		message = "已换朝向；放下时保存。"

func pickup(i: int, uid: int) -> bool:
	var entry := item(uid)
	if room != "home" or hands[i] >= 0 or entry.is_empty() or entry.room != "home" or uid in hands: return false
	for active in play:
		if not active.is_empty() and int(active.uid) == uid:
			message = "伙伴正在使用这件家具，等下来再搬吧。"
			return false
	if item_rect(entry).grow(52).has_point(positions[i]):
		entry.room = "inventory"
		hands[i] = uid
		directions[i] = int(entry.dir)
		save()
		message = "拿起来啦，可以换位置或朝向；收纳不花钱。"
		return true
	return false

func nearby_furniture(i: int) -> int:
	if room != "home": return -1
	var closest := -1
	var distance := INF
	for entry in state.items:
		if entry.room != "home" or not item_rect(entry).grow(52).has_point(positions[i]): continue
		var candidate := item_rect(entry).get_center().distance_to(positions[i])
		if candidate < distance:
			distance = candidate
			closest = int(entry.uid)
	return closest

func store_nearby(i: int) -> bool:
	if room != "home" or h.paused: return false
	var uid: int = int(play[i].uid) if not play[i].is_empty() else (hands[i] if hands[i] >= 0 else nearby_furniture(i))
	if not play[i].is_empty() and not leave_play(i): return false
	for active in play:
		if not active.is_empty() and int(active.uid) == uid:
			message = "伙伴正在这里玩，等下来再收纳吧。"
			return true
	if uid < 0: return false
	var entry := item(uid)
	if hands[i] == uid: entry.dir = directions[i]
	entry.room = "inventory"
	hands[i] = -1
	save()
	message = "%s已放回家具库存。空地按 Q / Backspace 打开家具包，可再次取出。" % good(entry.kind).name
	return true

func portal(i: int) -> bool:
	for door in range(2):
		var pos := cell_center(Vector2i(4 if door == 0 else 13, 7))
		if positions[i].distance_to(pos) < 62:
			if positions[1 - i].distance_to(pos) >= 95:
				message = "等伙伴也到这扇门，再一起出发。"
			elif door == 1:
				go_shop()
			else:
				enter("furniture" if room == "home" else "home")
			return true
	return false

func use(i: int) -> void:
	if h.paused: return
	if not play[i].is_empty():
		if float(play[i].jump) > 0: return
		var bed: bool = item(int(play[i].uid)).kind == "bed"
		play[i].pose = ("sleep" if bed else "sit") if play[i].pose == "stand" else "stand"
		return
	if portal(i): return
	if room == "furniture":
		var closest := -1
		var distance := 95.0
		for n in range(display_page * 8, mini(display_page * 8 + 8, GOODS.size())):
			var d := positions[i].distance_to(display_pos(n))
			if d < distance:
				distance = d
				closest = n
		if closest >= 0: buy(i, GOODS[closest].id)
		return
	if hands[i] >= 0:
		place(i, preview_cell(i))
		return
	var uid := nearby_furniture(i)
	if uid >= 0:
		if use_furniture(i, uid): return
		if pickup(i, uid): return
	bag_menu(i)

func display_pos(index: int) -> Vector2:
	var local := index % 8
	return Vector2(ORIGIN.x + 72 + local % 4 * CELL * 4, 336 + int(local / 4) * 176)

func draw_art(entry: Dictionary, rect: Rect2, direction: int, tint: Color = Color.WHITE, factor: float = 3.0) -> void:
	var variants: Array = good(entry.kind).art
	var source: Array = variants[posmod(direction, variants.size())]
	var size := Vector2(source[2], source[3]) * factor
	var target := Rect2(Vector2(rect.get_center().x - size.x / 2, rect.end.y - size.y), size)
	var texture := art_texture(entry.kind)
	if texture:
		h.draw_texture_rect_region(texture, target, Rect2(source[0], source[1], source[2], source[3]), tint)
	else:
		h.draw_rect(rect.grow(-5), Color("b88e62") * tint)
		h._center(good(entry.kind).name, rect.end.y - 8, 17, h.CREAM, false, rect.get_center().x)

func paint_actor(i: int) -> void:
	var pos := positions[i]
	var pose: String = "" if play[i].is_empty() else str(play[i].pose)
	var bounce := 0.0 if play[i].is_empty() else sin(float(play[i].jump) / 0.72 * PI) * 64.0
	pos.y -= bounce
	if pose == "sleep":
		# Crop the existing face and tuck it behind a pixel blanket matching the bed.
		var texture: Texture2D = h.players[i].sheets["Idle"]
		var breath := roundf(sin(h.ticks * 2.0)) * 2
		h.draw_texture_rect_region(texture, Rect2(pos.x - 30, pos.y - 105 + breath, 60, 48), Rect2(6, 5, 20, 16))
		h.draw_rect(Rect2(pos.x - 39, pos.y - 51, 78, 48), Color("85aead"))
		h.draw_rect(Rect2(pos.x - 39, pos.y - 51, 78, 8), Color("c4d8c2"))
		for x in range(4): h.draw_rect(Rect2(pos.x - 32 + x * 18, pos.y - 34, 5, 24), Color("729797"))
		h._center("z Z z", pos.y - 103 + sin(h.ticks * 2) * 3, 18, h.CREAM, false, pos.x + 20)
		h._center(h.player_name(i), pos.y - 126, 14, h.CREAM, true, pos.x)
		return
	h.draw_set_transform(pos, 0, Vector2(1, 0.4))
	h.draw_circle(Vector2.ZERO, 16, Color(0.15, 0.12, 0.1, 0.25))
	h.draw_set_transform(Vector2.ZERO)
	var texture: Texture2D = h.players[i].sheets["Jump" if bounce > 0 else ("Run" if moving[i] else "Idle")]
	var frames := maxi(1, texture.get_width() / 32)
	var frame := int(h.ticks * (12 if moving[i] else 7)) % frames
	h.draw_set_transform(pos, 0, Vector2(face_x[i], 0.72 if pose == "sit" else 1.0))
	h.draw_texture_rect_region(texture, Rect2(-32, -64, 64, 64), Rect2(frame * 32, 0, 32, 32))
	h.draw_set_transform(Vector2.ZERO)
	h._center(h.player_name(i), pos.y - 65, 14, Color("ffe4a1") if i == 0 else Color("baf0d1"), true, pos.x)
	if hands[i] >= 0:
		h._center("搬着：" + good(item(hands[i]).kind).name, pos.y - 86, 15, h.CREAM, false, pos.x)

func paint() -> void:
	h.draw_rect(Rect2(0, 0, 1280, 720), Color("4e655b"))
	h.draw_rect(Rect2(ORIGIN - Vector2(20, 65), Vector2(COLS * CELL + 40, ROWS * CELL + 85)), Color("554235"))
	for x in range(COLS):
		for y in range(ROWS):
			var rect := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2.ONE * CELL)
			h.draw_rect(rect, Color("c1996c") if (x + y) % 2 else Color("cba879"))
			if atlas: h.draw_texture_rect_region(atlas, rect, Rect2(112, 32, 16, 16))
		for y in range(2):
			var rect := Rect2(ORIGIN + Vector2(x * CELL, -64 + y * 24), Vector2(CELL, 24))
			if atlas: h.draw_texture_rect_region(atlas, rect, Rect2(16, 0, 16, 8))
			else: h.draw_rect(rect, Color("87aaa4"))
	h.draw_rect(Rect2(ORIGIN + Vector2(0, -12), Vector2(COLS * CELL, 12)), Color("a2794c"))
	for door in range(2):
		var pos := cell_center(Vector2i(4 if door == 0 else 13, 7))
		h.draw_rect(Rect2(pos - Vector2(43, 18), Vector2(86, 40)), Color("e4ba75"))
		h._center(("家具店 ↔" if room == "home" else "回小家 ↔") if door == 0 else "冰激凌店 ↔", 633, 18, h.CREAM, true, pos.x)
	var sorted: Array = []
	if room == "home":
		for entry in state.items:
			if entry.room != "home": continue
			if placement_layer(entry.kind) == "floor":
				draw_art(entry, item_rect(entry), int(entry.dir))
			else:
				sorted.append({"y": furniture_depth(entry), "item": entry})
	else:
		for n in range(display_page * 8, mini(display_page * 8 + 8, GOODS.size())):
			var entry: Dictionary = GOODS[n]
			var pos := display_pos(n)
			var rect := Rect2(pos - Vector2(50, 48), Vector2(100, 48))
			draw_art({"kind": entry.id}, rect, 0, Color.WHITE, 2.0)
			h.draw_rect(Rect2(pos + Vector2(-70, 8), Vector2(140, 25)), Color("76513c"))
			h._center("%s  %d元" % [entry.name, entry.price], pos.y + 28, 17, h.CREAM, false, pos.x)
	for i in range(2):
		var depth := positions[i].y if play[i].is_empty() else item_rect(item(int(play[i].uid))).end.y + 1
		sorted.append({"y": depth, "actor": i})
	sorted.sort_custom(func(a, b): return a.y < b.y)
	for entry in sorted:
		if entry.has("actor"): paint_actor(entry.actor)
		else: draw_art(entry.item, item_rect(entry.item), int(entry.item.dir))
	for i in range(2):
		if room != "home": continue
		if not play[i].is_empty(): continue
		if hands[i] < 0:
			var uid := nearby_furniture(i)
			if uid >= 0:
				var selection := item_rect(item(uid))
				h.draw_rect(selection.grow(2), Color("ffe3a0") if i == 0 else Color("baf0d1"), false, 2)
				var caption := ("E 使用 · R 搬动 · Q 收纳" if i == 0 else "O 使用 · / 搬动 · Backspace 收纳") if playable(item(uid).kind) else ("Q 收回库存" if i == 0 else "Backspace 收回库存")
				h._center(caption, selection.position.y - 7, 15, h.CREAM, false, selection.get_center().x)
			continue
		var cell := preview_cell(i)
		var entry := item(hands[i])
		var rect := item_rect(entry, cell)
		var valid := can_place(i, cell)
		h.draw_rect(rect, Color(0.5, 0.9, 0.6, 0.3) if valid else Color(1, 0.3, 0.3, 0.3))
		h.draw_rect(rect, Color("c5ed9d") if valid else Color("f1948b"), false, 3)
		draw_art(entry, rect, directions[i], Color(1, 1, 1, 0.65))
	h._panel(Rect2(25, 18, 730, 75), Color("49382d"))
	h._text("我们的小家" if room == "home" else "森林家具店", Vector2(45, 49), 25, h.CREAM, true)
	h._text("无限金钱 · 水果和家具不扣钱" if unlimited() else "共用钱袋 %d 元 · 可装修 %d 元 · 留 3 元备用金" % [state.wallet, maxi(0, int(state.wallet) - RESERVE)], Vector2(45, 79), 18, Color("f4d79e"))
	if room == "furniture":
		h._center("第 %d / %d 页 · 鼠标翻页" % [display_page + 1, int(ceil(GOODS.size() / 8.0))], 82, 17, h.CREAM, false, 925)
	h._panel(Rect2(25, 105, 1230, 45), Color("49382d"))
	var size := 18 if h.font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x < 1180 else 15
	h._center(message, 134, size, h.CREAM)
	h._panel(Rect2(25, 655, 1230, 48), Color("49382d"))
	h._center("%s  WASD / E使用放下 / R搬动转向 / Q收纳     %s  方向键 / O使用放下 / 斜杠搬动转向 / Backspace收纳" % [h.player_name(0), h.player_name(1)], 685, 15, h.CREAM)
	if h.paused:
		h.draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.15, 0.13, 0.8))
		h._panel(Rect2(310, 166, 660, 410))
		h._center(h.player_name(bag_owner) + " 的家具包 · 左右选择，互动取出" if menu_kind == "bag" else "小家会等你回来", 208, 23, h.CREAM, true)
