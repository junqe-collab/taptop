extends Control
## Persistent battlefield. Presentation never reads or advances the game's RNG.
signal inspected(unit_id: String)

const ATLAS = preload("res://assets/kenney/tiny_dungeon.png")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const GOLD = Color("efc879")
const RED = Color("ff897e")
const GREEN = Color("93e3be")
const BLUE = Color("86bbff")
var heroes: Array = []
var foes: Array = []
var active_id = ""
var in_battle = false
var floor_number = 1
var resting = false
var action: Dictionary = {}
var progress = 1.0
var after_units: Dictionary = {}
var elapsed = 0.0
var display_font = FontVariation.new()

func _ready() -> void:
	display_font.base_font = FONT
	display_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	gui_input.connect(_inspect_input)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		for unit in heroes + foes:
			if Rect2(unit_position(unit.id) - Vector2(48, 36), Vector2(96, 100)).has_point(event.position):
				inspected.emit(unit.id)
				accept_event()
				return

func unit_position(id: String) -> Vector2:
	for i in range(heroes.size()):
		if heroes[i].id == id:
			if in_battle: return Vector2(size.x * (0.18 + i * 0.32), size.y - 86)
			return Vector2(size.x * (0.17 + i * 0.23), size.y * 0.55)
	for i in range(foes.size()):
		if foes[i].id == id: return Vector2(size.x * (0.30 + i * 0.40), 70)
	return size * 0.5

func play_action(event: Dictionary, next_heroes: Array, next_foes: Array, duration: float) -> void:
	action = event.duplicate(true)
	active_id = action.actor
	progress = 0.0
	after_units.clear()
	for unit in next_heroes + next_foes: after_units[unit.id] = unit.duplicate(true)
	var tween = create_tween()
	tween.tween_method(func(value): progress = value, 0.0, 1.0, maxf(0.001, duration))
	await tween.finished
	heroes = next_heroes.duplicate(true)
	foes = next_foes.duplicate(true)
	action = {}
	after_units.clear()
	queue_redraw()

func _tile(index: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(ATLAS, rect, Rect2((index % 12) * 16, int(index / 12) * 16, 16, 16), tint)

func _text(value: String, center: Vector2, pixels: int, color: Color) -> void:
	var width = display_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string_outline(display_font, center - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 1 if pixels < 18 else 3, Color("111720"))
	draw_string(display_font, center - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func _background() -> void:
	var stone = [Color("242c37"), Color("1f303b"), Color("302639")][clampi(floor_number - 1, 0, 2)]
	draw_style_box(_frame(stone, Color("47505f")), Rect2(Vector2.ZERO, size))
	var cell = 28.0
	for y in range(1, ceili(size.y / cell)):
		for x in range(ceili(size.x / cell)):
			var corner = Vector2(x * cell + (14 if y % 2 else 0), y * cell)
			draw_rect(Rect2(corner, Vector2(26, 26)), Color(1, 1, 1, 0.018 if (x + y) % 3 else 0.04))
	# Low wall, gate and warm torches frame a quiet, readable arena.
	for x in range(ceili(size.x / 24)):
		_tile(39, Rect2(x * 24, 0, 24, 24), Color("7d869b"))
	_tile(33, Rect2(size.x / 2 - 20, 0, 40, 40), Color("b3a7a7"))
	for x in [20.0, size.x - 20]:
		for radius in [30, 20, 10]:
			draw_circle(Vector2(x, 30), radius, Color(1, 0.62, 0.23, 0.025 + sin(elapsed * 3) * 0.008))
		_tile(125, Rect2(x - 9, 15, 18, 18))
	if in_battle:
		draw_line(Vector2(24, size.y * 0.48), Vector2(size.x - 24, size.y * 0.48), Color(0.8, 0.7, 0.5, 0.11), 1)
		_text("VS", Vector2(size.x / 2, size.y * 0.49 + 4), 14, Color("707580"))
	elif resting:
		var center = Vector2(size.x * 0.82, size.y * 0.65)
		for radius in [34, 23, 12]:
			draw_circle(center, radius, Color(1, 0.5, 0.13, 0.06))
		draw_line(center + Vector2(-14, 8), center + Vector2(14, 2), Color("ad7859"), 6)
		draw_line(center + Vector2(-12, 2), center + Vector2(12, 8), Color("ad7859"), 6)
		for i in range(5):
			var rise = fmod(elapsed * 20 + i * 13, 42)
			draw_circle(center + Vector2(sin(i * 2.3 + elapsed) * 10, -rise), 3.0 - rise / 20, GOLD)
	else:
		_tile(91, Rect2(size.x * 0.80, size.y * 0.50, 36, 36))

func _frame(fill: Color, edge: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func _draw() -> void:
	_background()
	for unit in heroes + (foes if in_battle else []):
		_draw_unit(unit, heroes.has(unit))
	if not action.is_empty(): _draw_action()

func _draw_unit(unit: Dictionary, friendly: bool) -> void:
	var pos = unit_position(unit.id)
	var display = after_units.get(unit.id, unit) if progress >= 0.43 else unit
	var hit = false
	if not action.is_empty():
		for effect in action.effects:
			if effect.target == unit.id and effect.kind == "damage": hit = true
		if unit.id == action.actor and action.kind in ["physical", "physical_all", "pierce"] and not action.effects.is_empty():
			var destination = unit_position(action.effects[0].target)
			pos += (destination - pos).normalized() * sin(minf(progress / 0.65, 1.0) * PI) * 24
		if hit and progress > 0.43 and progress < 0.75:
			pos.x += sin(progress * 95) * 4 * (1 - progress)
	var accent = GREEN if friendly else RED
	var sprite_size = 56.0 if in_battle else 42.0
	var alpha = 1.0 if display.hp > 0 else 0.28
	draw_ellipse_shadow(pos + Vector2(0, 25), Vector2(27, 8))
	if unit.id == active_id and display.hp > 0:
		draw_arc(pos + Vector2(0, 22), 27, 0, TAU, 36, GOLD, 2, true)
		_text("행동" if not action.is_empty() else "선택", pos + Vector2(0, -33), 11, GOLD)
	var tint = Color(1, 1, 1, alpha)
	if hit and progress > 0.43 and progress < 0.57: tint = Color(4, 1.1, 1, alpha)
	_tile(unit.tile, Rect2(pos - Vector2(sprite_size / 2, sprite_size / 2), Vector2.ONE * sprite_size), tint)
	if not in_battle:
		_text(unit.name, pos + Vector2(0, 39), 14, Color("ddd9d0"))
		return
	var bar_width = minf(94, size.x * 0.27)
	var bar_pos = pos + Vector2(-bar_width / 2, 38)
	_text(unit.name + (" · 전열" if friendly and unit == heroes[0] else ""), pos + Vector2(0, 36), 13, accent)
	draw_style_box(_frame(Color("111923"), Color("556174")), Rect2(bar_pos, Vector2(bar_width, 15)))
	var displayed_hp = float(display.hp)
	if not action.is_empty() and progress > 0.43:
		displayed_hp = lerpf(float(unit.hp), float(display.hp), minf((progress - 0.43) / 0.22, 1.0))
	draw_rect(Rect2(bar_pos + Vector2.ONE * 2, Vector2((bar_width - 4) * displayed_hp / unit.max_hp, 11)), accent.darkened(0.35))
	_text("%d/%d" % [display.hp, display.max_hp], pos + Vector2(0, 51), 12, Color.WHITE)
	if friendly:
		draw_rect(Rect2(bar_pos + Vector2(0, 19), Vector2(bar_width, 3)), Color("111923"))
		draw_rect(Rect2(bar_pos + Vector2(0, 19), Vector2(bar_width * float(display.mp) / maxf(1, display.max_mp), 3)), BLUE)
		_text("MP %d · Lv.%d" % [display.mp, display.level], pos + Vector2(0, 75), 12, BLUE)
	else:
		_text(display.intent if display.hp > 0 else "쓰러짐", pos + Vector2(0, -34), 12, RED)
	if display.shield > 0:
		draw_arc(pos, 30, PI, TAU, 24, BLUE, 2, true)
		_text("방어막 %d" % display.shield, pos + Vector2(0, -17), 10, BLUE)

func _draw_action() -> void:
	if action.cancelled: return
	var origin = unit_position(action.actor)
	var flight = clampf((progress - 0.12) / 0.31, 0, 1)
	for i in range(action.effects.size()):
		var effect = action.effects[i]
		var target = unit_position(effect.target)
		var color = RED
		if effect.kind == "heal": color = GREEN
		elif effect.kind == "shield": color = BLUE
		elif action.kind in ["magic", "magic_all", "drain"]: color = Color("cba0ff")
		# Travel direction plus arrowhead makes the source/destination explicit.
		if progress > 0.10 and progress < 0.60 and origin.distance_to(target) > 1:
			var direction = (target - origin).normalized()
			var end = origin.lerp(target, flight)
			draw_line(origin, end, Color(color, 0.45), 2, true)
			draw_circle(end, 5 if color != RED else 3, color)
			draw_line(end, end - direction.rotated(0.45) * 10, color, 2, true)
			draw_line(end, end - direction.rotated(-0.45) * 10, color, 2, true)
		if progress > 0.40 and progress < 0.88:
			var impact = (progress - 0.40) / 0.48
			draw_arc(target, 20 + impact * 24, 0, TAU, 32, Color(color, 1 - impact), 3, true)
			if effect.kind == "damage":
				draw_line(target + Vector2(-17, 17) * (1 - impact), target + Vector2(17, -17) * (1 - impact), Color(1, 0.9, 0.75, 1 - impact), 4, true)
			elif effect.kind == "heal":
				draw_line(target + Vector2(-10, 0), target + Vector2(10, 0), Color(color, 1 - impact), 4)
				draw_line(target + Vector2(0, -10), target + Vector2(0, 10), Color(color, 1 - impact), 4)
		if progress > 0.43:
			var rise = (progress - 0.43) * 35
			var number = "-%d" % effect.amount if effect.kind == "damage" else "+%d" % effect.amount
			if effect.kind == "shield": number = "방어막 +" + str(effect.amount)
			if effect.kind == "damage" and effect.amount == 0: number = "방어"
			var label_pos = target + Vector2(0, -12 - rise)
			_text(number, label_pos, 25 if effect.kind != "shield" else 17, color)
			if effect.absorbed > 0: _text("흡수 %d" % effect.absorbed, label_pos + Vector2(0, 17), 11, BLUE)
			if effect.down: _text("쓰러짐", target + Vector2(0, 8), 13, RED)

func draw_ellipse_shadow(center: Vector2, radius: Vector2) -> void:
	var points = PackedVector2Array()
	for i in range(20):
		var angle = TAU * i / 20
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
