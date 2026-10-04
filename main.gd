extends Control

const Battle = preload("res://battle.gd")
const DungeonView = preload("res://dungeon_view.gd")
const ATLAS = preload("res://assets/kenney/tiny_dungeon.png")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const INK = Color("e8e4da")
const MUTED = Color("9caab9")
const GOLD = Color("e5bc70")
const GREEN = Color("86cdbc")
const RED = Color("ed887c")

var game = Battle.new()
var page: VBoxContainer
var scroll: ScrollContainer
var sheet: AcceptDialog
var log_sheet: AcceptDialog
var log_text: Label
var animating = false
var action_delay = 0.85
var selected_item = ""
var selected_kind = ""
var sheet_text: Label
var margins: MarginContainer
var combat_arena: Control
var action_banner: Label
var hand_offset = 0
var shop_tab = 0


func _ready() -> void:
	var ui_theme = Theme.new()
	var regular_font = FontVariation.new()
	regular_font.base_font = FONT
	regular_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	ui_theme.default_font = regular_font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "Button", Color("727e8c"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("202c3b"), Color("394759")))
	ui_theme.set_stylebox("hover", "Button", _style(Color("2c3d50"), GOLD))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("3a3c38"), GOLD))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("151e29"), Color("2b3541")))
	ui_theme.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, GOLD, 2))
	theme = ui_theme
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	margins = MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margins)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	margins.add_child(page)
	sheet = AcceptDialog.new()
	sheet.title = "캐릭터 정보"
	sheet.ok_button_text = "닫기"
	add_child(sheet)
	var info_scroll = ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(280, 300)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(info_scroll)
	sheet_text = _label("", 14)
	info_scroll.add_child(sheet_text)
	log_sheet = AcceptDialog.new()
	log_sheet.title = "전투 기록"
	log_sheet.ok_button_text = "닫기"
	add_child(log_sheet)
	var log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(280, 300)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_sheet.add_child(log_scroll)
	log_text = _label("", 14)
	log_scroll.add_child(log_text)
	resized.connect(_resize_battle)
	_render()


func _style(fill: Color, edge: Color = Color.TRANSPARENT, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(text: String, size_px: int = 16, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(text: String, callback: Callable, node_name: String, primary = false) -> Button:
	var button = Button.new()
	button.name = node_name
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 68
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("d9b471"), Color("f0ce8b")))
		button.add_theme_color_override("font_color", Color("1b2028"))
	return button


func _panel(color: Color = Color("16202c")) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color))
	page.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _portrait(tile: int, pixels: int = 48) -> TextureRect:
	var texture = AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = Rect2((tile % 12) * 16, int(tile / 12) * 16, 16, 16)
	var icon = TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _render(reset_scroll = false) -> void:
	var old_tray = find_child("HandTray", true, false)
	if old_tray != null: hand_offset = old_tray.scroll_horizontal
	if reset_scroll: hand_offset = 0
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	combat_arena = null
	page.add_theme_constant_override("separation", 6 if game.phase == "combat" else 12)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if game.phase == "combat" else ScrollContainer.SCROLL_MODE_AUTO
	if game.phase == "combat":
		scroll.scroll_vertical = 0
		_combat()
		return
	var top = HBoxContainer.new()
	top.add_child(_label("T A P T O P", 15, GOLD))
	var subtitle = _label("3층 원정" if game.phase == "camp" else "%d층 · %d/2구역" % [game.floor_number, game.room], 13, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(subtitle)
	page.add_child(top)
	page.add_child(_label("골드 %d    ·    식량 %d    ·    돌파 %d/6" % [game.gold, game.food, game.wins], 13, GOLD))
	match game.phase:
		"camp": _camp()
		"exploration": _exploration()
		"event": _event()
		"reward": _reward()
		"rest": _rest()
		"complete": _ending(true)
		"defeat": _ending(false)
	if reset_scroll: scroll.set_deferred("scroll_vertical", 0)

func _heading(kicker: String, title: String, description: String) -> void:
	page.add_child(_label(kicker, 13, GREEN))
	page.add_child(_label(title, 27))
	if not description.is_empty():
		page.add_child(_label(description, 15, MUTED))


func _arena(battle = false, height = 125) -> void:
	var arena = DungeonView.new()
	arena.custom_minimum_size.y = height
	arena.heroes = game.party.duplicate(true)
	arena.foes = game.enemies.duplicate(true)
	arena.active_id = ""
	arena.in_battle = battle
	arena.resting = game.phase in ["camp", "rest"]
	arena.floor_number = game.floor_number
	page.add_child(arena)

func _act(action: Callable, reset_scroll = false) -> void:
	if animating:
		return
	if action.call():
		selected_item = ""
		selected_kind = ""
		_render(reset_scroll)


func _bonus_text(bonuses: Dictionary, sign_value = 1) -> String:
	var parts: Array[String] = []
	for stat in bonuses:
		parts.append("%s %+d" % [Battle.STAT_NAMES[stat], bonuses[stat] * sign_value])
	return " · ".join(parts)


func _camp() -> void:
	_heading("PARTY  /  원정 준비", "심연의 문을 향해", "스킬을 모으고, 나만의 세 사람을 완성하세요.")
	_arena(false, 135)
	var start = _button("원정 시작  →", _act.bind(game.explore, true), "StartExpedition", true)
	start.disabled = game.companions.size() != 2
	page.add_child(start)
	_party_cards()
	page.add_child(_label("동료 선택  %d / 2" % game.companions.size(), 17, GOLD))
	var grid = _grid(2)
	for id in Battle.Data.HEROES:
		if id == "leon": continue
		var hero = Battle.Data.HEROES[id]
		var picked = game.companions.has(id)
		var button = _choice_card(("✓ " if picked else "") + hero.name, hero.role + "\n" + Battle.SKILLS[hero.skill].name, hero.tile, "Companion_" + id, _act.bind(game.toggle_companion.bind(id)), GREEN if picked else MUTED)
		button.disabled = not picked and game.companions.size() >= 2
		grid.add_child(button)
	page.add_child(_label("선택된 동료를 눌러 빼고, 다른 동료를 선택하세요.", 12, MUTED))
	_formation()
	page.add_child(_label("탐색 → 전투 → 휴식 · 3층 / 6전투\n스킬은 즉시 습득 · 전멸하면 원정 종료 · 저장 없음", 12, MUTED))
	var bottom = HBoxContainer.new()
	bottom.add_child(_label("SEED  %d" % game.run_seed, 11, MUTED))
	bottom.add_child(_small_button("새 시드", _restart.bind(false), "NewSeed"))
	page.add_child(bottom)

func _exploration() -> void:
	_heading("DEPTH %02d  /  탐색" % game.floor_number, Battle.Data.FLOORS[game.floor_number - 1], "보급과 위험 사이, 다음 발걸음을 고르세요.")
	_progress_track()
	_arena(false, 110)
	var branch = Control.new()
	branch.custom_minimum_size.y = 40
	branch.draw.connect(func():
		var center = Vector2(branch.size.x / 2, 2)
		for ratio in [0.25, 0.75]:
			var end = Vector2(branch.size.x * ratio, 35)
			branch.draw_polyline(PackedVector2Array([center, Vector2(center.x, 15), Vector2(end.x, 15), end]), Color("7e7057"), 2, true)
			branch.draw_circle(end, 4, GOLD)
	)
	page.add_child(branch)
	var choices = _grid(2)
	for i in range(game.routes.size()):
		var route = game.routes[i]
		var data = Battle.Data.ROUTES[route.kind]
		var button = _button("", _act.bind(game.choose_route.bind(i), true), "Route_%d" % i)
		button.custom_minimum_size.y = 222
		button.add_theme_stylebox_override("normal", _style(Color("2b2429") if route.risk else Color("202f30"), RED.darkened(0.5) if route.risk else GREEN.darkened(0.5)))
		choices.add_child(button)
		var face = _card_content(button)
		face.add_child(_label("위험 경로  /  +12 G" if route.risk else "일반 경로", 11, RED if route.risk else GREEN))
		face.add_child(_portrait({"cache": 91, "supply": 91, "shrine": 33, "spring": 111, "shop": 101}[route.kind], 40))
		face.add_child(_label(data.name, 16, INK))
		face.add_child(_label(data.description, 11, MUTED))
		var foe_row = HBoxContainer.new()
		foe_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for key in route.foes: foe_row.add_child(_portrait(Battle.Data.FOES[key].tile, 24))
		face.add_child(foe_row)
		var names: Array[String] = []
		for key in route.foes: names.append(Battle.Data.FOES[key].name)
		face.add_child(_label(" · ".join(names), 10, RED))
		if route.risk: face.add_child(_label("적 체력 +5 / 공격 +1", 10, MUTED))
	_party_cards()
	_formation()

func _formation() -> void:
	var header = HBoxContainer.new()
	header.add_child(_label("전열  ·  " + game.party[0].name, 13, GOLD))
	header.add_child(_small_button("빌드", _show_build, "ViewBuild"))
	page.add_child(header)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	for hero in game.party:
		var button = _button(("◆ " if hero == game.party[0] else "") + hero.name, _act.bind(game.set_front.bind(hero.id)), "Front_" + hero.id)
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = hero == game.party[0]
		row.add_child(button)

func _event() -> void:
	var data = Battle.Data.ROUTES[game.route.kind]
	_heading("발견  /  " + ("거래" if game.route.kind == "shop" else "탐색 이벤트"), data.name, data.description)
	if not game.reward_message.is_empty(): page.add_child(_label(game.reward_message, 14, GREEN))
	if not selected_item.is_empty():
		_recipient()
		return
	match game.route.kind:
		"cache":
			_arena(false, 110)
			var grid = _grid(2)
			for key in game.gear_offers: _gear_offer(key, false, grid)
			if game.event_used: page.add_child(_label("보급 완료", 17, GREEN))
		"shop": _shop()
		"shrine":
			_arena(false, 100)
			_shrine()
		_: _arena(false, 150)
	page.add_child(_button("전장으로  →", _act.bind(game.enter_battle, true), "EnterBattle", true))
	page.add_child(_label("떠나면 남은 상품과 습득 기회는 사라집니다.", 11, MUTED))
	_party_cards()
	_formation()

func _gear_offer(key: String, in_shop: bool, parent: Node = null) -> void:
	var gear = Battle.GEAR[key]
	var button = _button("", _pick_item.bind("gear", key), "Gear_" + key)
	button.custom_minimum_size.y = 162
	button.disabled = in_shop and game.gold < gear.price
	var holder = page if parent == null else parent
	holder.add_child(button)
	var face = _card_content(button)
	face.add_child(_label(("무기" if gear.slot == "weapon" else "방어구") + ("   %d G" % gear.price if in_shop else "  /  보급"), 11, GOLD))
	face.add_child(_skill_art("shield" if gear.slot == "armor" else ("magic" if gear.bonus.has("matk") else "physical"), GOLD))
	face.add_child(_label(gear.name, 15))
	face.add_child(_label(_bonus_text(gear.bonus), 12, GREEN))

func _shop() -> void:
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	page.add_child(tabs)
	var names = ["스킬", "장비", "식량"]
	for i in range(3):
		var tab = _button(names[i], _set_shop_tab.bind(i), "ShopTab_%d" % i, shop_tab == i)
		tab.custom_minimum_size.y = 44
		tabs.add_child(tab)
	if shop_tab == 0:
		page.add_child(_label("구입 즉시 습득 · 빈 슬롯이 필요합니다.", 12, MUTED))
		var grid = _grid(2)
		for key in game.shop_skills:
			var skill = Battle.SKILLS[key]
			var available = false
			for hero in game.party:
				if game.can_learn(hero.id, key): available = true
			var button = _button("", _pick_item.bind("skill", key), "ShopSkill_" + key)
			button.custom_minimum_size.y = 188
			button.disabled = not available or game.gold < game.skill_price(key)
			grid.add_child(button)
			var face = _card_content(button)
			face.add_child(_label("%d G    /    %d MP" % [game.skill_price(key), skill.cost], 12, GOLD))
			face.add_child(_skill_art(skill.kind, _skill_color(skill.kind)))
			face.add_child(_label(skill.name, 16))
			face.add_child(_label(skill.description, 11, MUTED))
			face.add_child(_label(_bonus_text(skill.bonus), 11, GREEN))
			if not available: face.add_child(_label("빈 슬롯 / 중복 확인", 10, RED))
		if game.shop_skills.is_empty(): page.add_child(_label("스킬 품절", 16, MUTED))
	elif shop_tab == 1:
		var grid = _grid(2)
		for key in game.shop_gear: _gear_offer(key, true, grid)
		if game.shop_gear.is_empty(): page.add_child(_label("장비 품절", 16, MUTED))
	else:
		_arena(false, 120)
		page.add_child(_label("휴식 한 번을 위한 식량\n보유 %d개 · 체력과 마력을 회복할 때 사용" % game.food, 15))
		var button = _button("식량 +1  ·  16 G" if game.food_stock else "식량 품절", _act.bind(game.buy_food), "BuyFood", true)
		button.disabled = not game.food_stock or game.gold < 16
		page.add_child(button)

func _pick_item(kind: String, key: String) -> void:
	selected_kind = kind
	selected_item = key
	_render(true)


func _cancel_item() -> void:
	selected_item = ""
	selected_kind = ""
	_render(true)


func _recipient() -> void:
	var data = Battle.GEAR[selected_item] if selected_kind == "gear" else Battle.SKILLS[selected_item]
	var featured = _panel(Color("252b2d"))
	featured.add_child(_label(data.name, 24, GOLD))
	featured.add_child(_label(_bonus_text(data.bonus), 14, GREEN))
	page.add_child(_label("받을 캐릭터를 선택하세요", 15, MUTED))
	var grid = _grid(3)
	for hero in game.party:
		if selected_kind == "gear":
			var previous = hero.gear.get(data.slot, "")
			var detail = "빈 부위\n장착" if previous.is_empty() else Battle.GEAR[previous].name + "\n폐기 후 교체"
			grid.add_child(_choice_card(hero.name, detail, hero.tile, "Equip_" + hero.id, _act.bind(game.equip.bind(selected_item, hero.id), true)))
		else:
			var button = _choice_card(hero.name, "스킬 %d / %d\n즉시 습득" % [hero.skills.size(), hero.level], hero.tile, "BuySkill_" + hero.id, _act.bind(game.buy_skill.bind(selected_item, hero.id), true))
			button.disabled = not game.can_learn(hero.id, selected_item)
			grid.add_child(button)
	page.add_child(_button("선택 취소", _cancel_item, "CancelItem"))

func _shrine() -> void:
	page.add_child(_label("해제하면 스킬과 습득 능력치가 함께 사라집니다.\n빈 슬롯은 이후 드랍이나 상점에서 새로 채웁니다.", 14, MUTED))
	if game.event_used:
		page.add_child(_label("제단의 힘을 사용했습니다.", 16, GREEN))
		return
	for hero in game.party:
		for key in hero.skills:
			var skill = Battle.SKILLS[key]
			var action = game.forget_skill.bind(hero.id, key)
			var button = _button("%s · %s 해제\n%s" % [hero.name, skill.name, _bonus_text(skill.bonus, -1)],
				_confirm.bind("스킬 해제", "%s의 %s을 해제합니다.\n%s" % [hero.name, skill.name, _bonus_text(skill.bonus, -1)], action), "Forget_" + hero.id + "_" + key)
			button.add_theme_font_size_override("font_size", 14)
			page.add_child(button)


func _party_cards() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	for hero in game.party:
		var button = _button("", _inspect.bind(hero.id), "Hero_" + hero.id)
		button.custom_minimum_size.y = 112
		row.add_child(button)
		var face = _card_content(button, 7)
		var head = HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(_portrait(hero.tile, 26))
		head.add_child(_label("%s\nLv.%d" % [hero.name, hero.level], 12))
		face.add_child(head)
		face.add_child(_meter(hero.hp, hero.max_hp, RED if hero.hp == 0 else GREEN))
		face.add_child(_label("HP %d/%d  ·  MP %d" % [hero.hp, hero.max_hp, hero.mp], 10, MUTED))
		face.add_child(_label("스킬  " + "◆".repeat(hero.skills.size()) + "◇".repeat(maxi(0, hero.level - hero.skills.size())), 11, GOLD))

func _popup(dialog: AcceptDialog) -> void:
	var area = get_viewport_rect().size
	dialog.popup_centered(Vector2i(int(minf(380, area.x - 20)), int(minf(540, area.y - 30))))


func _inspect(id: String) -> void:
	var hero = game.find_unit(id)
	if game.enemies.has(hero):
		sheet.title = "적 정보"
		sheet_text.text = "%s\n체력 %d / %d\n\n예정 행동: %s\n물공 %d · 물방 %d\n마공 %d · 마방 %d\n속도 %d" % [hero.name, hero.hp, hero.max_hp, hero.intent, hero.patk, hero.pdef, hero.matk, hero.mdef, hero.speed]
		_popup(sheet)
		return
	var lines: Array[String] = ["%s · 레벨 %d · 경험치 %d" % [hero.name, hero.level, hero.xp], ""]
	for stat in Battle.STAT_NAMES:
		lines.append("%s  %d" % [Battle.STAT_NAMES[stat], hero[stat]])
	lines.append("\n보유 스킬  %d/%d" % [hero.skills.size(), hero.level])
	for key in hero.skills:
		lines.append("• %s · 마력 %d\n  %s\n  습득: %s" % [Battle.SKILLS[key].name, Battle.SKILLS[key].cost, Battle.SKILLS[key].description, _bonus_text(Battle.SKILLS[key].bonus)])
	lines.append("\n장비")
	for slot in ["weapon", "armor"]:
		var key = hero.gear.get(slot, "")
		lines.append(("무기: " if slot == "weapon" else "방어구: ") + ("없음" if key.is_empty() else Battle.GEAR[key].name))
	lines.append("\n스킬 해제는 망각의 제단에서만 가능합니다.")
	sheet.title = "캐릭터 정보"
	sheet_text.text = "\n".join(lines)
	_popup(sheet)


func _show_build() -> void:
	var lines: Array[String] = ["보유 스킬 하나가 소유자 전용 카드 한 장입니다.", "매 라운드 최대 5장. 추가 습득은 능력치와 덱을 모두 바꿉니다.", ""]
	for hero in game.party:
		lines.append("%s · Lv.%d · 스킬 %d/%d" % [hero.name, hero.level, hero.skills.size(), hero.level])
		for key in hero.skills:
			lines.append("  %s · %s" % [Battle.SKILLS[key].name, _bonus_text(Battle.SKILLS[key].bonus)])
		lines.append("")
	sheet.title = "파티 빌드와 공용 덱"
	sheet_text.text = "\n".join(lines)
	_popup(sheet)


func _combat() -> void:
	var header = HBoxContainer.new()
	header.custom_minimum_size.y = 44
	header.add_child(_label("%d층  /  %s\n%d구역 · ROUND %02d" % [game.floor_number, "최종 보스" if game.wins == 5 else Battle.Data.FLOORS[game.floor_number - 1], game.room, game.round_number], 13, GOLD))
	header.add_child(_small_button("기록", _show_log, "FullLog"))
	header.add_child(_small_button("덱", _show_build, "ViewBuild"))
	var speed = _small_button("2×" if action_delay < 0.5 else "1×", _toggle_speed, "CombatSpeed")
	header.add_child(speed)
	page.add_child(header)
	var timeline = HBoxContainer.new()
	timeline.name = "Timeline"
	timeline.custom_minimum_size.y = 34
	timeline.add_theme_constant_override("separation", 4)
	page.add_child(timeline)
	for entry in game.order:
		var unit = game.find_unit(entry.id)
		var cell = HBoxContainer.new()
		cell.name = "Order_" + unit.id
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.modulate = Color.WHITE if unit.hp > 0 else Color("555967")
		cell.add_child(_portrait(unit.tile, 20))
		cell.add_child(_label("%s\n%d" % [unit.name.left(2), entry.priority], 10, GREEN if game.party.has(unit) else RED))
		timeline.add_child(cell)
	combat_arena = DungeonView.new()
	combat_arena.name = "Battlefield"
	combat_arena.heroes = game.party.duplicate(true)
	combat_arena.foes = game.enemies.duplicate(true)
	combat_arena.active_id = game.selected_caster
	combat_arena.in_battle = true
	combat_arena.floor_number = game.floor_number
	combat_arena.inspected.connect(_inspect)
	page.add_child(combat_arena)
	_resize_battle()
	var banner = PanelContainer.new()
	banner.custom_minimum_size.y = 42
	banner.add_theme_stylebox_override("panel", _style(Color("182332"), Color("394759")))
	action_banner = _label("카드 선택 → 행동 시작\n선택한 한 명의 스킬 + 나머지는 기본 공격", 12, MUTED)
	if not game.selected_skill.is_empty():
		action_banner.text = "%s · %s\n%s" % [game.find_unit(game.selected_caster).name, Battle.SKILLS[game.selected_skill].name, Battle.SKILLS[game.selected_skill].description]
		action_banner.add_theme_color_override("font_color", GOLD)
	if animating: action_banner.text = "행동 진행 중\n공격자와 대상이 전장에 표시됩니다."
	elif game.cursor >= game.order.size(): action_banner.text = game.log_lines.back()
	banner.add_child(action_banner)
	page.add_child(banner)
	_skill_cards()
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var basic = _button("기본\n공격", _act.bind(game.choose_basic), "SelectBasic")
	basic.custom_minimum_size = Vector2(76, 52)
	basic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	basic.add_theme_font_size_override("font_size", 13)
	basic.disabled = animating or game.cursor > 0
	actions.add_child(basic)
	var resolve_button: Button
	if not animating and game.cursor >= game.order.size():
		resolve_button = _button("다음 라운드  →", _act.bind(game.next_round, true), "NextRound", true)
	else:
		resolve_button = _button("진행 중…" if animating else "행동 시작  →", _resolve_round, "ResolveRound", true)
	resolve_button.custom_minimum_size.y = 52
	resolve_button.disabled = animating
	actions.add_child(resolve_button)
	page.add_child(actions)
	call_deferred("_resize_battle")

func _skill_cards() -> void:
	page.add_child(_label("손패 %d  /  덱 %d  /  버림 %d       좌우로 넘겨 선택" % [game.hand.size(), game.draw_pile.size(), game.discard_pile.size()], 11, MUTED))
	var tray = ScrollContainer.new()
	tray.name = "HandTray"
	tray.custom_minimum_size.y = 153
	tray.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	tray.follow_focus = true
	page.add_child(tray)
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	tray.add_child(cards)
	for entry in game.hand:
		var hero = game.find_unit(entry.caster)
		var skill = Battle.SKILLS[entry.skill]
		var tint = _skill_color(skill.kind)
		var selected = game.selected_skill == entry.skill and game.selected_caster == hero.id
		var button = _button("", _act.bind(game.choose_card.bind(hero.id, entry.skill)), "Skill_" + hero.id + "_" + entry.skill)
		button.custom_minimum_size = Vector2(116, 136)
		button.disabled = animating or game.cursor > 0 or hero.hp <= 0 or hero.mp < skill.cost
		button.add_theme_stylebox_override("normal", _style(Color("303429") if selected else Color("1b2533"), GOLD if selected else tint.darkened(0.5), 2 if selected else 1))
		cards.add_child(button)
		var face = _card_content(button, 7)
		var owner = HBoxContainer.new()
		owner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owner.add_child(_portrait(hero.tile, 18))
		owner.add_child(_label(hero.name, 11, MUTED))
		owner.add_child(_label("%d MP" % skill.cost, 11, tint))
		face.add_child(owner)
		face.add_child(_skill_art(skill.kind, tint))
		face.add_child(_label(("✓ " if selected else "") + skill.name, 13, GOLD if selected else INK))
		face.add_child(_label("마력 부족" if hero.mp < skill.cost else skill.description, 10, RED if hero.mp < skill.cost else MUTED))
		if button.disabled: face.modulate = Color(0.66, 0.66, 0.70)
	tray.set_deferred("scroll_horizontal", hand_offset)

func _resolve_round() -> void:
	if animating or not game.begin_round(): return
	animating = true
	_render()
	while game.resolving:
		game.step_action()
		var event = game.last_action.duplicate(true)
		var targets: Array[String] = []
		for effect in event.effects:
			var target_name = game.find_unit(effect.target).name
			if not targets.has(target_name): targets.append(target_name)
		action_banner.text = "%s  →  %s\n%s" % [game.find_unit(event.actor).name, "행동 취소" if event.cancelled else " · ".join(targets), event.name]
		action_banner.add_theme_color_override("font_color", GREEN if game.party.has(game.find_unit(event.actor)) else RED)
		var timeline = find_child("Timeline", true, false)
		for cell in timeline.get_children():
			cell.modulate = Color.WHITE if cell.name == "Order_" + event.actor else Color("697587")
		await combat_arena.play_action(event, game.party, game.enemies, action_delay)
		if not is_inside_tree(): return
	animating = false
	_render(game.phase != "combat")

func _show_log() -> void:
	log_text.text = "\n".join(game.log_lines)
	_popup(log_sheet)


func _reward() -> void:
	_heading("VICTORY  /  %d번째 승리" % game.wins, "새로운 힘의 조각", "지금 습득할 캐릭터를 선택하세요.")
	var skill = Battle.SKILLS[game.pending_drop]
	var featured = _panel(Color("262b30"))
	featured.add_child(_label("MONSTER DROP    %d / 2" % (3 - game.pending_drops.size()), 11, GOLD))
	featured.add_child(_skill_art(skill.kind, _skill_color(skill.kind)))
	featured.add_child(_label(skill.name, 27, _skill_color(skill.kind)))
	featured.add_child(_label("%d MP  ·  %s" % [skill.cost, skill.description], 14))
	featured.add_child(_label("습득  /  " + _bonus_text(skill.bonus), 14, GREEN))
	var grid = _grid(3)
	for hero in game.party:
		var reason = "습득하기"
		if hero.skills.has(game.pending_drop): reason = "이미 보유"
		elif hero.skills.size() >= hero.level: reason = "슬롯 가득 참"
		var button = _choice_card(hero.name, "Lv.%d  ·  %d/%d\n%s" % [hero.level, hero.skills.size(), hero.level, reason], hero.tile, "Learn_" + hero.id, _act.bind(game.learn_drop.bind(hero.id), true))
		button.disabled = not game.can_learn(hero.id)
		grid.add_child(button)
	page.add_child(_label("포기하면 사라집니다. 스킬은 보관할 수 없습니다.", 12, MUTED))
	var row = HBoxContainer.new()
	row.add_child(_button("이 스킬 포기", _confirm.bind("스킬 습득 포기", skill.name + "을 포기합니다.\n다시 사용하려면 새로 획득해야 합니다.", game.skip_drop), "SkipReward"))
	row.add_child(_button("현재 빌드", _show_build, "ViewBuild"))
	page.add_child(row)

func _confirm(title: String, message: String, action: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.name = "ChoiceConfirmation"
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "확인"
	dialog.cancel_button_text = "취소"
	dialog.confirmed.connect(func():
		_act(action, true)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(int(minf(370, get_viewport_rect().size.x - 20)), 210))


func _rest() -> void:
	_heading("REST  /  숨 고르기", "모닥불 곁에서", "다음 전투를 위한 짧은 쉼.")
	_arena(false, 130)
	_party_cards()
	var recover = _button("회복 완료" if game.rested else "불 곁에서 회복  ·  식량 1개", _act.bind(game.rest), "RestRecover", true)
	recover.disabled = game.rested or game.food <= 0
	page.add_child(recover)
	page.add_child(_label("식량 %d개  ·  체력 55%% / 마력 60%% 회복" % game.food, 12, MUTED))
	if game.food <= 0 and not game.rested: page.add_child(_label("식량이 없어 이번 휴식에서는 회복할 수 없습니다.", 12, RED))
	var event_box = _panel(Color("282822"))
	event_box.add_child(_label(game.rest_event.name, 19, GOLD))
	event_box.add_child(_label(game.rest_event.description, 13, MUTED))
	event_box.add_child(_label(_bonus_text(game.rest_event.bonus), 14, GREEN))
	if game.rest_event_used:
		event_box.add_child(_label("이벤트 적용 완료", 14, GREEN))
	else:
		var grid = _grid(3)
		for hero in game.party:
			grid.add_child(_choice_card(hero.name, "이벤트 적용", hero.tile, "RestEvent_" + hero.id, _act.bind(game.apply_rest_event.bind(hero.id)), GOLD, 112))
	var next_text = "%d층으로 내려가기" % (game.floor_number + 1) if game.room == 2 else "다음 구역으로"
	page.add_child(_button(next_text + ("  →" if game.rested else " · 회복 없이 →"), _act.bind(game.continue_run, true), "ContinueRun", true))
	_formation()

func _ending(won: bool) -> void:
	_heading("원정 완료" if won else "원정 실패", "심연의 문을 열었다" if won else "다시 모닥불 앞으로",
		"세 개의 층을 돌파했습니다." if won else "파티가 모두 쓰러졌습니다. 빌드와 경로를 바꿔 도전하세요.")
	_arena(false, 135)
	_party_cards()
	var summary = _panel()
	summary.add_child(_label("%d/6 전투 돌파 · 총 %d라운드" % [game.wins, game.total_rounds], 19, GOLD))
	summary.add_child(_label("원정 시드 %d" % game.run_seed, 14, MUTED))
	page.add_child(_button("새 원정 준비", _restart.bind(false), "Restart", true))
	page.add_child(_button("같은 시드로 재도전", _restart.bind(true), "ReplaySeed"))
	page.add_child(_button("최종 빌드 보기", _show_build, "ViewBuild"))
	page.add_child(_button("원정 기록", _show_log, "FullLog"))


func _restart(same_seed = false) -> void:
	if animating: return
	game.reset(game.run_seed if same_seed else -1)
	selected_item = ""
	selected_kind = ""
	_render(true)

func _resize_battle() -> void:
	if is_instance_valid(combat_arena):
		var occupied = 24.0 + (page.get_child_count() - 1) * 6
		for child in page.get_children():
			if child != combat_arena: occupied += child.get_combined_minimum_size().y
		combat_arena.custom_minimum_size.y = maxf(185, get_viewport_rect().size.y - occupied - 8)

func _toggle_speed() -> void:
	action_delay = 0.38 if action_delay >= 0.5 else 0.85
	var button = find_child("CombatSpeed", true, false)
	if button != null: button.text = "2×" if action_delay < 0.5 else "1×"

func _small_button(text: String, action: Callable, id: String) -> Button:
	var button = _button(text, action, id)
	button.custom_minimum_size = Vector2(44, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 12)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var style = theme.get_stylebox(key, "Button").duplicate()
		style.content_margin_left = 6
		style.content_margin_right = 6
		button.add_theme_stylebox_override(key, style)
	return button

func _card_content(button: Button, padding = 10) -> VBoxContainer:
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, padding)
	button.add_child(inset)
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	inset.add_child(content)
	return content

func _skill_color(kind: String) -> Color:
	if kind in ["heal", "party_heal"]: return GREEN
	if kind in ["shield", "magic_shield", "party_shield"]: return Color("88bfff")
	if kind in ["magic", "magic_all", "drain"]: return Color("c5a1f1")
	return Color("efa686")

func _skill_art(kind: String, tint: Color) -> Control:
	var art = Control.new()
	art.custom_minimum_size.y = 36
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func():
		var center = art.size / 2
		art.draw_circle(center, 16, Color(tint, 0.07))
		if kind in ["heal", "party_heal"]:
			art.draw_line(center - Vector2(0, 10), center + Vector2(0, 10), tint, 4, true)
			art.draw_line(center - Vector2(10, 0), center + Vector2(10, 0), tint, 4, true)
		elif kind in ["shield", "magic_shield", "party_shield"]:
			var points = PackedVector2Array([center + Vector2(-11, -12), center + Vector2(11, -12), center + Vector2(9, 5), center + Vector2(0, 14), center + Vector2(-9, 5), center + Vector2(-11, -12)])
			art.draw_polyline(points, tint, 2, true)
		elif kind in ["magic", "magic_all", "drain"]:
			art.draw_circle(center, 6, tint)
			art.draw_arc(center, 13, 0.3, 5.7, 24, tint, 1.5, true)
			art.draw_line(center + Vector2(-17, 0), center + Vector2(17, 0), Color(tint, 0.5), 1, true)
		else:
			art.draw_line(center + Vector2(-9, 11), center + Vector2(12, -12), tint, 4, true)
			art.draw_line(center + Vector2(-10, -1), center + Vector2(2, 10), GOLD, 3, true)
	)
	return art

func _grid(columns: int) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	return grid

func _choice_card(title: String, detail: String, tile: int, id: String, callback: Callable, accent: Color = GREEN, height = 148) -> Button:
	var button = _button("", callback, id)
	button.custom_minimum_size.y = height
	button.add_theme_stylebox_override("normal", _style(Color("1b2832"), accent.darkened(0.5)))
	var face = _card_content(button, 8)
	face.add_child(_portrait(tile, 40))
	face.add_child(_label(title, 15, accent))
	face.add_child(_label(detail, 11, MUTED))
	return button

func _meter(value: int, maximum: int, tint: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("0e1721"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _style(tint, Color.TRANSPARENT, 0))
	for key in ["background", "fill"]:
		var style = bar.get_theme_stylebox(key)
		style.set_content_margin_all(0)
	return bar

func _set_shop_tab(index: int) -> void:
	shop_tab = index
	_render(true)

func _progress_track() -> void:
	var track = HBoxContainer.new()
	track.add_theme_constant_override("separation", 5)
	for i in range(6):
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 34
		panel.add_theme_stylebox_override("panel", _style(Color("37372c") if i == game.wins else Color("16202a"), GOLD if i == game.wins else Color("34434c")))
		var label = _label("✓" if i < game.wins else ("%d-%d" % [int(i / 2) + 1, i % 2 + 1]), 11, GREEN if i < game.wins else GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		track.add_child(panel)
	page.add_child(track)
