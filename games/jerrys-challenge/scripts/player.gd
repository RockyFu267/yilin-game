extends CharacterBody2D

const SKINS = ["Ninja Frog", "Mask Dude", "Pink Man", "Virtual Guy", "Jerry Mouse", "Tom Cat"]
var player_id: int = 0
var skin: int = 0
var display_name: String = ""
var active: bool = false
var carrying: bool = false
var seated: bool = false
var facing: float = 1.0
var clock: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var sheets: Dictionary = {}
var label_font: Font

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(28, 44)
	shape.shape = rectangle
	shape.position = Vector2(0, -22)
	add_child(shape)
	collision_layer = 2
	collision_mask = 1
	z_index = 10 + player_id
	set_skin(skin)

func set_skin(value: int) -> void:
	skin = value
	for anim in ["Idle", "Run", "Jump", "Fall"]:
		sheets[anim] = load("res://assets/characters/%s/%s (32x32).png" % [SKINS[skin], anim])

func _physics_process(delta: float) -> void:
	if not active:
		queue_redraw()
		return
	clock += delta
	if seated:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var prefix := "p%d_" % (player_id + 1)
	var direction := Input.get_axis(prefix + "left", prefix + "right")
	velocity.x = move_toward(velocity.x, direction * 235.0, 1900.0 * delta)
	if direction != 0:
		facing = signf(direction)
	coyote = 0.13 if is_on_floor() else maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if Input.is_action_just_pressed(prefix + "jump"):
		jump_buffer = 0.14
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -460
		jump_buffer = 0
		coyote = 0
	if Input.is_action_just_released(prefix + "jump") and velocity.y < -180:
		velocity.y = -180
	velocity.y += 1400 * delta
	move_and_slide()
	position.x = clampf(position.x, 35, 1245)
	if position.y > 750:
		position = Vector2(150 + 80 * player_id, 580)
		velocity = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var accent := Color("ffe3a0") if player_id == 0 else Color("baf8dd")
	draw_ellipse_shadow()
	var anim := "Idle"
	if not is_on_floor():
		anim = "Jump" if velocity.y < 0 else "Fall"
	elif absf(velocity.x) > 12:
		anim = "Run"
	var texture: Texture2D = sheets.get(anim)
	if texture:
		var frames := maxi(1, texture.get_width() / 32)
		var frame := int(clock * (14 if anim == "Run" else 8)) % frames
		draw_set_transform(Vector2(0, 4 if seated else 0), 0, Vector2(facing * 2.5, 2.5))
		draw_texture_rect_region(texture, Rect2(-16, -32, 32, 32), Rect2(frame * 32, 0, 32, 32))
		draw_set_transform(Vector2.ZERO)
	if label_font:
		var title := "%s  ·  P%d" % [display_name, player_id + 1]
		var width := label_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_style_box(_name_style(), Rect2(-width / 2 - 10, -98 if not carrying else -125, width + 20, 27))
		draw_string(label_font, Vector2(-width / 2, -78 if not carrying else -105), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, accent)
		if player_id == 0:
			draw_circle(Vector2(0, -111 if not carrying else -138), 4, accent)
		else:
			draw_rect(Rect2(-4, -115 if not carrying else -142, 8, 8), accent)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, -2), 0, Vector2(1, 0.23))
	draw_circle(Vector2.ZERO, 24, Color(0.06, 0.2, 0.18, 0.22))
	draw_set_transform(Vector2.ZERO)

func _name_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("373c2e")
	style.border_color = Color("b18e58")
	style.set_border_width_all(2)
	return style
