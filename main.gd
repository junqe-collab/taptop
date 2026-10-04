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
var manage_sheet: AcceptDialog
var manage_box: VBoxContainer
var manage_mode = "party"
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
	ui_theme.set_stylebox("panel", "AcceptDialog", _style(Color("16202c"), Color("617582")))
	ui_theme.set_stylebox("embedded_border", "Window", _style(Color("16202c"), Color("617582")))
	ui_theme.set_stylebox("embedded_unfocused_border", "Window", _style(Color("16202c"), Color("617582")))
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
	margins = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 12)
	add_child(margins)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	manage_sheet = AcceptDialog.new()
	manage_sheet.name = "Management"
	manage_sheet.ok_button_text = "닫기"
	add_child(manage_sheet)
	manage_sheet.get_ok_button().name = "CloseManagement"
	for dialog in [sheet, log_sheet, manage_sheet]:
		dialog.get_ok_button().custom_minimum_size.y = 44
	var manage_scroll = ScrollContainer.new()
	manage_scroll.name = "ManagementScroll"
	manage_scroll.custom_minimum_size = Vector2(280, 300)
	manage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	manage_sheet.add_child(manage_scroll)
	manage_box = VBoxContainer.new()
	manage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manage_box.add_theme_constant_override("separation", 10)
	manage_scroll.add_child(manage_box)
	resized.connect(_on_resized)
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
	button.custom_minimum_size.y = 52
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
	page.add_theme_constant_override("separation", 6 if game.phase == "combat" else 8)
	if game.phase == "combat":
		_combat()
		return
	var top = HBoxContainer.new()
	top.add_child(_label("T A P T O P", 14, GOLD))
	var subtitle = _label("원정 준비" if game.phase == "camp" else "%d층 · %d/2구역" % [game.floor_number, game.room], 12, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(subtitle)
	page.add_child(top)
	page.add_child(_label("%d G    /    식량 %d    /    돌파 %d·6" % [game.gold, game.food, game.wins], 12, GOLD))
	match game.phase:
		"camp": _camp()
		"exploration": _exploration()
		"event": _event()
		"reward": _reward()
		"rest": _rest()
		"complete": _ending(true)
		"defeat": _ending(false)
	if manage_sheet.visible: _render_management()


func _heading(kicker: String, title: String, description: String) -> void:
	page.add_child(_label(kicker, 13, GREEN))
	page.add_child(_label(title, 24))
	if not description.is_empty():
		page.add_child(_label(description, 15, MUTED))


func _arena(battle = false, height = 125) -> void:
	var arena = DungeonView.new()
	arena.custom_minimum_size.y = height
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_heading("PARTY / 짧은 원정, 달라지는 빌드", "심연의 문을 향해", "세 사람 · 여섯 전투 · 한 번의 도전")
	_arena(false, 92)
	var relic = Battle.Data.RELICS[game.relic_id]
	page.add_child(_button("유물  /  " + relic.name + "  ›\n" + relic.description, _show_management.bind("relic"), "ChooseRelic"))
	page.add_child(_label("동료와 유물을 고른 뒤 출발하세요. 진행은 저장되지 않습니다.", 12, MUTED))
	_bottom()
	var start = _button("원정 시작  →", _act.bind(game.explore, true), "StartExpedition", true)
	start.disabled = game.companions.size() != 2
	page.add_child(start)


func _exploration() -> void:
	_heading("DEPTH %02d / 갈림길" % game.floor_number, Battle.Data.FLOORS[game.floor_number - 1], "")
	_progress_track()
	var choices = _grid(2)
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(game.routes.size()):
		var route = game.routes[i]
		var data = Battle.Data.ROUTES[route.kind]
		var field = Battle.Data.BATTLEFIELDS[route.field]
		var tint = RED if route.risk else GREEN
		var button = _button("", _act.bind(game.choose_route.bind(i), true), "Route_%d" % i)
		button.custom_minimum_size.y = 290
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _style(Color("2b2429") if route.risk else Color("202f30"), tint.darkened(0.4)))
		choices.add_child(button)
		var face = _card_content(button)
		face.add_child(_label("위험  /  +12 G" if route.risk else "일반 경로", 13, tint))
		face.add_child(_portrait({"cache": 91, "supply": 91, "shrine": 33, "spring": 111, "shop": 101}[route.kind], 44))
		face.add_child(_label(data.name, 16))
		face.add_child(_label(data.description, 12, MUTED))
		face.add_child(_label(field.name, 14, Color(field.color)))
		face.add_child(_label(field.description, 12, Color(field.color)))
		var space = Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		face.add_child(space)
		var foe_row = HBoxContainer.new()
		foe_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for key in route.foes: foe_row.add_child(_portrait(Battle.Data.FOES[key].tile, 28))
		face.add_child(foe_row)
		var names: Array[String] = []
		for key in route.foes: names.append(Battle.Data.FOES[key].name)
		face.add_child(_label(" · ".join(names), 11, RED))
		face.add_child(_label("적 HP +5 / 공격 +1" if route.risk else "카드를 눌러 이동 →", 11, tint))
	_bottom()


func _formation() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	row.add_child(_button("편성 · 전열", _show_management.bind("party"), "Formation"))
	row.add_child(_button("빌드 · 유물", _show_build, "ViewBuild"))
	row.add_child(_button("도움말", _help, "Help"))
	for button in row.get_children():
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 12)


func _event() -> void:
	var data = Battle.Data.ROUTES[game.route.kind]
	_heading("발견 / " + game.battlefield().name, data.name, "")
	if not selected_item.is_empty():
		_recipient()
		return
	match game.route.kind:
		"cache":
			page.add_child(_label("장비 하나를 골라 동료에게 배분하세요.", 13, MUTED))
			for key in game.gear_offers: _gear_offer(key, false)
			if game.event_used: _arena(false, 100)
		"shop": _shop()
		"shrine":
			_arena(false, 100)
			page.add_child(_label("스킬 하나를 해제해 새 빌드를 준비하세요.", 14, MUTED))
			var button = _button("제단에 바칠 스킬 선택", _show_management.bind("shrine"), "OpenShrine")
			button.disabled = game.event_used
			page.add_child(button)
		_: _arena(false, 120)
	if not game.reward_message.is_empty(): page.add_child(_label(game.reward_message, 13, GREEN))
	_bottom(false)
	page.add_child(_button("전장으로  →", _act.bind(game.enter_battle, true), "EnterBattle", true))


func _gear_offer(key: String, in_shop: bool, parent: Node = null) -> void:
	var gear = Battle.GEAR[key]
	var button = _button("%s  ·  %s\n%s" % [gear.name, ("%d G" % gear.price) if in_shop else ("무기" if gear.slot == "weapon" else "방어구"), _bonus_text(gear.bonus)], _pick_item.bind("gear", key), "Gear_" + key)
	button.custom_minimum_size.y = 74
	button.add_theme_font_size_override("font_size", 14)
	button.disabled = in_shop and game.gold < gear.price
	(page if parent == null else parent).add_child(button)


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
		for key in game.shop_skills:
			var skill = Battle.SKILLS[key]
			var available = game.party.any(func(hero): return game.can_learn(hero.id, key))
			var button = _button("%s  ·  %d G  /  %d MP\n%s\n%s" % [skill.name, game.skill_price(key), skill.cost, skill.description, _bonus_text(skill.bonus) if available else "습득 가능한 빈 슬롯 없음"], _pick_item.bind("skill", key), "ShopSkill_" + key)
			button.custom_minimum_size.y = 78
			button.add_theme_font_size_override("font_size", 13)
			button.disabled = not available or game.gold < game.skill_price(key)
			page.add_child(button)
		if game.shop_skills.is_empty(): page.add_child(_label("스킬 품절", 16, MUTED))
	elif shop_tab == 1:
		for key in game.shop_gear: _gear_offer(key, true)
		if game.shop_gear.is_empty(): page.add_child(_label("장비 품절", 16, MUTED))
	else:
		_arena(false, 100)
		page.add_child(_label("휴식에서 체력 55% · 마력 60% 회복", 14, MUTED))
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
	_spacer()
	page.add_child(_button("선택 취소", _cancel_item, "CancelItem"))




func _party_cards() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	for hero in game.party:
		var button = _button("", _inspect.bind(hero.id), "Hero_" + hero.id)
		button.custom_minimum_size.y = 70
		row.add_child(button)
		var face = _card_content(button, 6)
		face.add_child(_label(("◆ " if hero == game.party[0] else "") + hero.name + " · %d" % hero.level, 12, GREEN if hero.hp > 0 else RED))
		face.add_child(_meter(hero.hp, hero.max_hp, GREEN if hero.hp > 0 else RED))
		face.add_child(_label("%d/%d  ·  MP %d" % [hero.hp, hero.max_hp, hero.mp], 10, MUTED))


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
	var relic = Battle.Data.RELICS[game.relic_id]
	var lines: Array[String] = ["유물: " + relic.name + " · " + relic.description, "전장: " + game.battlefield().name + " · " + game.battlefield().description, "", "보유 스킬 하나가 소유자 전용 카드 한 장입니다.", "매 라운드 최대 5장. 추가 습득은 능력치와 덱을 모두 바꿉니다.", ""]
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
	timeline.custom_minimum_size.y = 28
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
	combat_arena.inspected.connect(_battle_unit_tapped)
	combat_arena.target_id = game.target_id
	combat_arena.field_color = Color(game.battlefield().color)
	page.add_child(combat_arena)
	page.add_child(_label(game.battlefield().name + " · " + game.battlefield().description, 11, Color(game.battlefield().color)))
	_resize_battle()
	var banner = PanelContainer.new()
	banner.custom_minimum_size.y = 42
	var banner_style = _style(Color("182332"), Color("394759"))
	banner_style.content_margin_top = 4
	banner_style.content_margin_bottom = 4
	banner.add_theme_stylebox_override("panel", banner_style)
	action_banner = _label("적을 눌러 집중 공격 · 카드 하나 선택\n나머지 동료는 기본 공격", 12, MUTED)
	if not game.selected_skill.is_empty():
		action_banner.text = "%s · %s\n%s" % [game.find_unit(game.selected_caster).name, Battle.SKILLS[game.selected_skill].name, Battle.SKILLS[game.selected_skill].description]
		action_banner.text += " · " + game.attack_target().name
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
	var redraw = _button("교체 완료" if game.redraw_used else "손패 교체", _act.bind(game.redraw_hand, true), "RedrawHand")
	redraw.custom_minimum_size = Vector2(94, 52)
	redraw.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	redraw.add_theme_font_size_override("font_size", 12)
	redraw.disabled = animating or not game.can_redraw()
	actions.add_child(redraw)
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
	page.add_child(_label("손패 %d · 덱 %d  /  좌우로 넘겨 선택" % [game.hand.size(), game.draw_pile.size()], 11, MUTED))
	var tray = ScrollContainer.new()
	tray.name = "HandTray"
	tray.custom_minimum_size.y = 139
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
		button.custom_minimum_size = Vector2(124, 122)
		button.disabled = animating or game.cursor > 0 or hero.hp <= 0 or hero.mp < game.skill_cost(entry.skill)
		button.add_theme_stylebox_override("normal", _style(Color("303429") if selected else Color("1b2533"), GOLD if selected else tint.darkened(0.5), 2 if selected else 1))
		cards.add_child(button)
		var face = _card_content(button, 7)
		var owner = HBoxContainer.new()
		owner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owner.add_child(_portrait(hero.tile, 18))
		owner.add_child(_label(hero.name, 11, MUTED))
		owner.add_child(_label("%d MP" % game.skill_cost(entry.skill), 11, tint))
		face.add_child(owner)
		var art = _skill_art(skill.kind, tint)
		art.custom_minimum_size.y = 26
		face.add_child(art)
		face.add_child(_label(("✓ " if selected else "") + skill.name, 13, GOLD if selected else INK))
		face.add_child(_label("마력 부족" if hero.mp < game.skill_cost(entry.skill) else skill.description, 10, RED if hero.mp < game.skill_cost(entry.skill) else MUTED))
		if button.disabled: face.modulate = Color(0.66, 0.66, 0.70)
	tray.set_deferred("scroll_horizontal", hand_offset)

func _resolve_round() -> void:
	if animating or not game.begin_round(): return
	animating = true
	_render()
	while game.resolving:
		game.step_action()
		combat_arena.target_id = game.target_id
		var event = game.last_action.duplicate(true)
		var targets: Array[String] = []
		for effect in event.effects:
			var target_name = game.find_unit(effect.target).name
			if not targets.has(target_name): targets.append(target_name)
		action_banner.text = "%s  →  %s\n%s" % [game.find_unit(event.actor).name, "행동 취소" if event.cancelled else " · ".join(targets), event.name]
		if not event.get("relic", "").is_empty(): action_banner.text += " · " + event.relic
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
	_spacer()
	var row = HBoxContainer.new()
	row.add_child(_button("이 스킬 포기", _confirm.bind("스킬 습득 포기", skill.name + "을 포기합니다.\n다시 사용하려면 새로 획득해야 합니다.", game.skip_drop), "SkipReward"))
	row.add_child(_button("현재 빌드", _show_build, "ViewBuild"))
	page.add_child(row)

func _confirm(title: String, message: String, action: Callable) -> void:
	var return_to_management = manage_sheet.visible
	manage_sheet.hide()
	var dialog = ConfirmationDialog.new()
	dialog.name = "ChoiceConfirmation"
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "확인"
	dialog.cancel_button_text = "취소"
	dialog.confirmed.connect(func():
		dialog.hide()
		_act(action, true)
		dialog.queue_free()
		if return_to_management: _show_management(manage_mode))
	dialog.canceled.connect(func():
		dialog.hide()
		dialog.queue_free()
		if return_to_management: _show_management(manage_mode))
	add_child(dialog)
	dialog.popup_centered(Vector2i(int(minf(370, get_viewport_rect().size.x - 20)), 210))


func _rest() -> void:
	_heading("REST / 숨 고르기", "모닥불 곁에서", "")
	_party_cards()
	if get_viewport_rect().size.y >= 760: _arena(false, 70)
	var recover = _button("회복 완료" if game.rested else "식량 1개 · 체력 55% / 마력 60% 회복", _act.bind(game.rest), "RestRecover", true)
	recover.add_theme_font_size_override("font_size", 14)
	recover.disabled = game.rested or game.food <= 0
	page.add_child(recover)
	if game.food <= 0 and not game.rested: page.add_child(_label("식량 부족 · 이번 휴식에서는 회복할 수 없습니다.", 12, RED))
	var event_box = _panel(Color("282822"))
	event_box.add_child(_label(game.rest_event.name, 17, GOLD))
	event_box.add_child(_label(_bonus_text(game.rest_event.bonus), 13, GREEN))
	if game.rest_event_used:
		event_box.add_child(_label("동료에게 적용 완료", 13, GREEN))
	else:
		var row = HBoxContainer.new()
		event_box.add_child(_label("이야기를 나눌 동료", 12, MUTED))
		event_box.add_child(row)
		for hero in game.party:
			var button = _button(hero.name, _act.bind(game.apply_rest_event.bind(hero.id)), "RestEvent_" + hero.id)
			button.custom_minimum_size.y = 44
			row.add_child(button)
	_spacer()
	_formation()
	var next_text = "%d층으로 내려가기" % (game.floor_number + 1) if game.room == 2 else "다음 구역으로"
	page.add_child(_button(next_text + ("  →" if game.rested else " · 회복 없이 →"), _act.bind(game.continue_run, true), "ContinueRun", true))


func _ending(won: bool) -> void:
	_heading("EXPEDITION / " + ("완료" if won else "실패"), "심연의 문을 열었다" if won else "다시 모닥불 앞으로", "새 유물과 동료로 다른 빌드를 만들어 보세요.")
	_arena(false, 80)
	var summary = _panel()
	summary.add_child(_label("%d/6 돌파 · %d라운드 · %s" % [game.wins, game.total_rounds, Battle.Data.RELICS[game.relic_id].name], 14, GOLD))
	summary.add_child(_label("SEED %d" % game.run_seed, 12, MUTED))
	_party_cards()
	var details = HBoxContainer.new()
	details.add_child(_button("최종 빌드", _show_build, "ViewBuild"))
	details.add_child(_button("원정 기록", _show_log, "FullLog"))
	page.add_child(details)
	var retry = HBoxContainer.new()
	retry.add_child(_button("새 원정", _restart.bind(false), "Restart", true))
	retry.add_child(_button("같은 시드", _restart.bind(true), "ReplaySeed"))
	page.add_child(retry)


func _restart(same_seed = false) -> void:
	if animating: return
	manage_sheet.hide()
	game.reset(game.run_seed if same_seed else -1)
	selected_item = ""
	selected_kind = ""
	_render(true)

func _resize_battle() -> void:
	if is_instance_valid(combat_arena):
		var occupied = 24.0 + (page.get_child_count() - 1) * 6
		for child in page.get_children():
			if child != combat_arena: occupied += child.get_combined_minimum_size().y
		combat_arena.custom_minimum_size.y = maxf(210, get_viewport_rect().size.y - occupied - 8)

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

func _spacer() -> void:
	var space = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(space)


func _bottom(show_party = true) -> void:
	if not page.get_children().any(func(child): return child.size_flags_vertical & Control.SIZE_EXPAND): _spacer()
	if show_party: _party_cards()
	_formation()


func _battle_unit_tapped(id: String) -> void:
	if game.enemies.has(game.find_unit(id)) and not animating and game.choose_target(id):
		_render()
	elif not animating:
		_inspect(id)


func _help() -> void:
	sheet.title = "원정 안내"
	sheet_text.text = "탐색 → 전투 → 휴식 · 총 6전투\n\n원정마다 유물과 전장 특성이 달라집니다. 전장 설명은 적과 아군 중 누구에게 적용되는지 보여줍니다.\n\n적을 누르면 집중 공격 대상으로 지정합니다. 한 라운드에 카드 하나를 선택하고 나머지 동료는 기본 공격합니다. 집중 대상이 쓰러지면 생존 적을 공격합니다.\n\n손패 교체는 전투당 한 번입니다. 덱에 다른 카드가 있어야 합니다. 순서와 적 예고는 유지됩니다.\n\n적과 아군의 순서를 보고 방어막과 치유를 선택하세요. 방어막은 받는 캐릭터의 다음 행동 때 사라집니다.\n\n캐릭터별 레벨만큼 스킬을 배울 수 있습니다. 캐릭터를 누르면 자세한 능력치와 스킬을 확인합니다.\n\n전멸하면 원정 종료. 진행은 저장되지 않습니다."
	_popup(sheet)


func _show_management(mode: String) -> void:
	manage_mode = mode
	_render_management()
	_popup(manage_sheet)


func _render_management() -> void:
	for child in manage_box.get_children():
		manage_box.remove_child(child)
		child.queue_free()
	match manage_mode:
		"party":
			manage_sheet.title = "동료와 전열"
			if game.phase == "camp":
				manage_box.add_child(_label("동료 %d / 2 · 선택한 동료를 누르면 해제" % game.companions.size(), 14, GOLD))
				for id in Battle.Data.HEROES:
					if id == "leon": continue
					var data = Battle.Data.HEROES[id]
					var picked = game.companions.has(id)
					var button = _button(("✓ " if picked else "") + data.name + " · " + data.role + "\n" + Battle.SKILLS[data.skill].name, _act.bind(game.toggle_companion.bind(id)), "Companion_" + id)
					button.disabled = not picked and game.companions.size() >= 2
					button.add_theme_font_size_override("font_size", 14)
					manage_box.add_child(button)
			manage_box.add_child(_label("전열 · 적의 전열 공격을 받는 동료", 14, GOLD))
			for hero in game.party:
				var button = _button(("◆ " if hero == game.party[0] else "") + hero.name, _act.bind(game.set_front.bind(hero.id)), "Front_" + hero.id)
				button.disabled = hero == game.party[0] or game.phase not in ["camp", "exploration", "event", "rest"]
				manage_box.add_child(button)
		"relic":
			manage_sheet.title = "이번 원정의 유물 · 하나 선택"
			for id in game.relic_offers:
				var data = Battle.Data.RELICS[id]
				var button = _button(("✓ " if id == game.relic_id else "") + data.name + "\n" + data.description, _act.bind(game.choose_relic.bind(id)), "Relic_" + id, id == game.relic_id)
				button.custom_minimum_size.y = 76
				button.add_theme_font_size_override("font_size", 14)
				manage_box.add_child(button)
			manage_box.add_child(_label("SEED %d · 같은 시드와 선택은 같은 결과" % game.run_seed, 12, MUTED))
			manage_box.add_child(_button("새 시드로 준비", _restart.bind(false), "NewSeed"))
		"shrine":
			manage_sheet.title = "망각의 제단"
			manage_box.add_child(_label("스킬과 습득 능력치가 함께 제거됩니다.", 14, MUTED))
			if game.event_used:
				manage_box.add_child(_label("제단 사용 완료", 16, GREEN))
				return
			for hero in game.party:
				for key in hero.skills:
					var skill = Battle.SKILLS[key]
					var button = _button(hero.name + " · " + skill.name + " 해제\n" + _bonus_text(skill.bonus, -1), _confirm.bind("스킬 해제", hero.name + " · " + skill.name + "을 해제합니다.", game.forget_skill.bind(hero.id, key)), "Forget_" + hero.id + "_" + key)
					button.add_theme_font_size_override("font_size", 14)
					manage_box.add_child(button)

func _on_resized() -> void:
	if game.phase == "combat": _resize_battle()
	else: _render()
	for dialog in [sheet, log_sheet, manage_sheet]:
		if dialog.visible: _popup(dialog)
