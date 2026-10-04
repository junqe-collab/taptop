extends RefCounted
## Seeded three-floor expedition. No scene/UI dependencies.

const Data = preload("res://game_data.gd")
const SKILLS = Data.SKILLS
const GEAR = Data.GEAR
const STAT_NAMES = Data.STAT_NAMES
const LEVEL_XP = [0, 10, 30, 50]
const HAND_SIZE = 5

var rng = RandomNumberGenerator.new()
var world_rng = RandomNumberGenerator.new()
var run_seed = 0
var companions: Array = ["ria", "mira"]
var party: Array = []
var enemies: Array = []
var phase = "camp"
var floor_number = 1
var room = 1
var wins = 0
var total_rounds = 0
var gold = 40
var food = 3
var routes: Array = []
var route: Dictionary = {}
var gear_offers: Array = []
var shop_skills: Array = []
var shop_gear: Array = []
var food_stock = true
var event_used = false
var pending_drops: Array = []
var pending_drop = ""
var rest_event: Dictionary = {}
var rest_event_used = false
var rested = false
var reward_message = ""
var log_lines: Array[String] = []
var order: Array = []
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var round_number = 0
var cursor = 0
var selected_skill = ""
var selected_caster = ""
var resolving = false
var last_actor = ""
var last_action: Dictionary = {}
var relic_offers: Array = []
var relic_id = ""
var target_id = ""
var redraw_used = false


func _init(seed_value: int = -1):
	reset(seed_value)


func reset(seed_value: int = -1) -> void:
	if seed_value < 0:
		world_rng.randomize()
		seed_value = world_rng.randi_range(1, 2147483646)
	run_seed = seed_value
	world_rng.seed = run_seed
	rng.seed = run_seed ^ 0x5A17
	phase = "camp"
	floor_number = 1
	room = 1
	wins = 0
	total_rounds = 0
	gold = 40
	food = 3
	routes.clear()
	route.clear()
	gear_offers.clear()
	shop_skills.clear()
	shop_gear.clear()
	pending_drops.clear()
	pending_drop = ""
	rest_event.clear()
	rest_event_used = false
	rested = false
	event_used = false
	food_stock = true
	reward_message = ""
	log_lines.clear()
	enemies.clear()
	_clear_combat()
	_make_party()
	relic_offers = _sample(Data.RELICS.keys(), 3)
	relic_id = relic_offers[0]


func _unit(id: String, display_name: String, tile: int, stats: Array) -> Dictionary:
	return {"id": id, "name": display_name, "tile": tile, "max_hp": stats[0], "hp": stats[0],
		"max_mp": stats[1], "mp": stats[1], "patk": stats[2], "pdef": stats[3],
		"matk": stats[4], "mdef": stats[5], "speed": stats[6], "shield": 0,
		"level": 1, "xp": 0, "skills": [], "gear": {}, "rest_bonus": {}, "intent": ""}


func _make_party() -> void:
	party.clear()
	for id in ["leon"] + companions:
		var data = Data.HEROES[id]
		var hero = _unit(id, data.name, data.tile, data.stats)
		hero.skills.append(data.skill)
		_rebuild_stats(hero)
		hero.hp = hero.max_hp
		hero.mp = hero.max_mp
		party.append(hero)


func toggle_companion(id: String) -> bool:
	if phase != "camp" or id == "leon" or not Data.HEROES.has(id):
		return false
	if companions.has(id):
		companions.erase(id)
	elif companions.size() < 2:
		companions.append(id)
	else:
		return false
	_make_party()
	return true


func set_front(id: String) -> bool:
	var hero = find_unit(id)
	if phase not in ["camp", "exploration", "event", "rest"] or hero.is_empty() or not party.has(hero):
		return false
	party.erase(hero)
	party.push_front(hero)
	return true


func _rebuild_stats(hero: Dictionary) -> void:
	var keys = STAT_NAMES.keys()
	for i in range(keys.size()):
		hero[keys[i]] = Data.HEROES[hero.id].stats[i]
	var growth = hero.level - 1
	hero.max_hp += growth * 5
	hero.max_mp += growth * 2
	hero.patk += growth
	hero.matk += growth
	var sources = [hero.rest_bonus]
	for id in hero.skills:
		sources.append(SKILLS[id].bonus)
	for id in hero.gear.values():
		sources.append(GEAR[id].bonus)
	for bonuses in sources:
		for stat in bonuses:
			hero[stat] += bonuses[stat]
	for stat in keys:
		hero[stat] = maxi(1 if stat in ["max_hp", "max_mp", "speed"] else 0, hero[stat])
	hero.hp = mini(hero.hp, hero.max_hp)
	hero.mp = mini(hero.mp, hero.max_mp)


func shuffle_with(items: Array, random: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var other = random.randi_range(0, i)
		var value = items[i]
		items[i] = items[other]
		items[other] = value


func _sample(items: Array, count: int) -> Array:
	var copy = items.duplicate()
	shuffle_with(copy, world_rng)
	return copy.slice(0, count)


func choose_relic(id: String) -> bool:
	if phase != "camp" or not relic_offers.has(id): return false
	relic_id = id
	return true


func relic_bonus(effect: String) -> int:
	if relic_id.is_empty(): return 0
	var relic = Data.RELICS[relic_id]
	return relic.amount if relic.effect == effect else 0


func battlefield() -> Dictionary:
	return Data.BATTLEFIELDS[route.get("field", "quiet")]


func field_bonus(effect: String) -> int:
	var field = battlefield()
	return field.amount if field.effect == effect else 0


func skill_cost(id: String) -> int:
	return maxi(1, SKILLS[id].cost - field_bonus("cost"))


func attack_bonus(magical: bool, friendly: bool) -> int:
	var effect = "magic" if magical else "physical"
	return field_bonus(effect) + (relic_bonus(effect) if friendly else 0)


func choose_target(id: String) -> bool:
	var target = find_unit(id)
	if phase != "combat" or resolving or cursor > 0 or not enemies.has(target) or target.hp <= 0: return false
	target_id = id
	return true


func attack_target() -> Dictionary:
	var target = find_unit(target_id)
	if not target.is_empty() and enemies.has(target) and target.hp > 0: return target
	return living(enemies)[0]


func can_redraw() -> bool:
	return phase == "combat" and not resolving and cursor == 0 and not redraw_used and (draw_pile + discard_pile).any(func(card): return find_unit(card.caster).hp > 0)


func redraw_hand() -> bool:
	if not can_redraw(): return false
	redraw_used = true
	# Draw from the remaining deck first, then recycle the old hand if needed.
	_draw_hand()
	selected_caster = ""
	selected_skill = ""
	_note("손패 교체 · 이번 전투의 교체 기회 사용")
	return true


func explore() -> bool:
	if phase != "camp" or party.size() != 3:
		return false
	_open_routes()
	return true


func _open_routes() -> void:
	phase = "exploration"
	route = {}
	routes.clear()
	var kinds = _sample(Data.ROUTES.keys(), 2)
	if wins == 0:
		kinds = ["cache", "supply"]
	elif room == 2:
		kinds = ["shop", _sample(["shrine", "spring", "cache"], 1)[0]]
	var fields = _sample(Data.BATTLEFIELDS.keys(), 2)
	for i in range(2):
		var foe_ids = _sample(Data.ENCOUNTER_FOES, 2)
		if floor_number == 3 and room == 2:
			foe_ids[0] = "warden"
		routes.append({"kind": kinds[i], "risk": i, "foes": foe_ids, "roll": world_rng.randi_range(-2, 2), "field": fields[i]})


func choose_route(index: int) -> bool:
	if phase != "exploration" or index < 0 or index >= routes.size():
		return false
	route = routes[index].duplicate(true)
	phase = "event"
	event_used = false
	food_stock = true
	gear_offers.clear()
	shop_skills.clear()
	shop_gear.clear()
	reward_message = ""
	match route.kind:
		"cache": gear_offers = _sample(GEAR.keys(), 3)
		"shop":
			shop_skills = _sample(SKILLS.keys(), 3)
			shop_gear = _sample(GEAR.keys(), 2)
		"supply":
			food += 1
			gold += 8
			reward_message = "식량 +1 · 골드 +8"
		"spring":
			for hero in living(party):
				hero.mp = mini(hero.max_mp, hero.mp + ceili(hero.max_mp * 0.4))
			food += 1
			reward_message = "생존 아군의 마력 회복 · 식량 +1"
		"shrine":
			gold += 12
			reward_message = "제단에서 골드 12를 발견했습니다."
	_note("%d층 %d구역 · %s" % [floor_number, room, Data.ROUTES[route.kind].name])
	return true


func equip(gear_id: String, hero_id: String) -> bool:
	var hero = find_unit(hero_id)
	if phase != "event" or hero.is_empty() or not party.has(hero) or not GEAR.has(gear_id):
		return false
	if route.kind == "cache":
		if event_used or not gear_offers.has(gear_id):
			return false
		event_used = true
		gear_offers.clear()
	elif route.kind == "shop":
		if not shop_gear.has(gear_id) or gold < GEAR[gear_id].price:
			return false
		gold -= GEAR[gear_id].price
		shop_gear.erase(gear_id)
	else:
		return false
	hero.gear[GEAR[gear_id].slot] = gear_id
	_rebuild_stats(hero)
	reward_message = "%s · %s 장착" % [hero.name, GEAR[gear_id].name]
	_note(reward_message)
	return true


func skill_price(_skill_id: String) -> int:
	return 22 + floor_number * 3


func can_learn(hero_id: String, skill_id: String = "") -> bool:
	if skill_id.is_empty():
		skill_id = pending_drop
	var hero = find_unit(hero_id)
	return SKILLS.has(skill_id) and not hero.is_empty() and party.has(hero) \
		and hero.skills.size() < mini(hero.level, 4) and not hero.skills.has(skill_id)


func buy_skill(skill_id: String, hero_id: String) -> bool:
	if phase != "event" or route.kind != "shop" or not shop_skills.has(skill_id) \
		or not can_learn(hero_id, skill_id) or gold < skill_price(skill_id):
		return false
	gold -= skill_price(skill_id)
	shop_skills.erase(skill_id)
	_learn(find_unit(hero_id), skill_id)
	return true


func buy_food() -> bool:
	if phase != "event" or route.kind != "shop" or not food_stock or gold < 16:
		return false
	gold -= 16
	food += 1
	food_stock = false
	reward_message = "식량 +1"
	return true


func forget_skill(hero_id: String, skill_id: String) -> bool:
	var hero = find_unit(hero_id)
	if phase != "event" or route.kind != "shrine" or event_used or hero.is_empty() \
		or not party.has(hero) or not hero.skills.has(skill_id):
		return false
	hero.skills.erase(skill_id)
	_rebuild_stats(hero)
	event_used = true
	reward_message = "%s · %s 해제. 습득 능력치도 제거했습니다." % [hero.name, SKILLS[skill_id].name]
	_note(reward_message)
	return true


func _clear_combat() -> void:
	target_id = ""
	redraw_used = false
	last_action.clear()
	order.clear()
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	round_number = 0
	cursor = 0
	selected_skill = ""
	selected_caster = ""
	resolving = false
	last_actor = ""


func enter_battle() -> bool:
	if phase != "event":
		return false
	phase = "combat"
	_clear_combat()
	gear_offers.clear()
	shop_skills.clear()
	shop_gear.clear()
	enemies.clear()
	for i in range(route.foes.size()):
		var data = Data.FOES[route.foes[i]]
		var foe = _unit("enemy_%d" % i, data.name, data.tile, data.stats)
		foe.kind = data.kind
		foe.max_hp += (floor_number - 1) * 9 + route.risk * 5 + route.roll
		foe.hp = foe.max_hp
		foe.patk += (floor_number - 1) * 2 + route.risk
		foe.matk += (floor_number - 1) * 2 + route.risk
		foe.pdef += floor_number - 1
		foe.mdef += floor_number - 1
		enemies.append(foe)
	for hero in party:
		hero.shield = 0
		if hero.hp > 0: hero.mp = mini(hero.max_mp, hero.mp + relic_bonus("mana"))
		for key in hero.skills:
			draw_pile.append({"caster": hero.id, "skill": key})
	shuffle_with(draw_pile, rng)
	target_id = enemies[0].id
	_note("%d층 %d구역 · %s · 유물: %s" % [floor_number, room, battlefield().name, Data.RELICS[relic_id].name])
	next_round()
	return true


func living(units: Array) -> Array:
	return units.filter(func(u): return u.hp > 0)


func find_unit(id: String) -> Dictionary:
	for unit in party + enemies:
		if unit.id == id:
			return unit
	return {}


func _draw_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	while hand.size() < HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate(true)
			discard_pile.clear()
			shuffle_with(draw_pile, rng)
		var card = draw_pile.pop_back()
		if find_unit(card.caster).hp > 0:
			hand.append(card)


func next_round() -> bool:
	if phase != "combat" or resolving or (not order.is_empty() and cursor < order.size()):
		return false
	round_number += 1
	order.clear()
	cursor = 0
	selected_skill = ""
	selected_caster = ""
	last_actor = ""
	for unit in living(party) + living(enemies):
		var jitter = rng.randi_range(-2, 2)
		order.append({"id": unit.id, "priority": unit.speed + jitter,
			"speed": unit.speed, "jitter": jitter, "tie": rng.randf()})
	order.sort_custom(func(a, b):
		if a.priority != b.priority: return a.priority > b.priority
		if a.speed != b.speed: return a.speed > b.speed
		if a.tie != b.tie: return a.tie > b.tie
		return a.id < b.id)
	for enemy in living(enemies):
		var strong = rng.randf() < 0.35
		if enemy.kind == "boss" and enemy.hp * 2 < enemy.max_hp: strong = true
		enemy.move = Data.ENEMY_PATTERNS[enemy.kind][1 if strong else 0]
		enemy.intent = Data.ENEMY_MOVES[enemy.move].intent
	_draw_hand()
	_note("%d라운드 · 순서와 손패 확정" % round_number)
	return true


func choose_card(caster_id: String, skill_id: String) -> bool:
	if phase != "combat" or resolving or cursor > 0 or not hand.has({"caster": caster_id, "skill": skill_id}):
		return false
	var caster = find_unit(caster_id)
	if caster.is_empty() or caster.hp <= 0 or caster.mp < skill_cost(skill_id):
		return false
	selected_caster = caster_id
	selected_skill = skill_id
	return true


func choose_basic() -> bool:
	if phase != "combat" or resolving or cursor > 0:
		return false
	selected_caster = ""
	selected_skill = ""
	return true


func begin_round() -> bool:
	if phase != "combat" or resolving or cursor != 0:
		return false
	resolving = true
	total_rounds += 1
	return true


func step_action() -> String:
	if not resolving or phase != "combat" or cursor >= order.size():
		return ""
	var actor = find_unit(order[cursor].id)
	cursor += 1
	last_actor = actor.id
	last_action = {"actor": actor.id, "name": "기본 공격", "kind": "physical", "effects": [], "cancelled": actor.hp <= 0}
	var line = ""
	if actor.hp <= 0:
		line = "%s · 쓰러져 행동 취소" % actor.name
	else:
		actor.shield = 0
		if party.has(actor):
			if actor.id == selected_caster and not selected_skill.is_empty():
				line = _cast(actor, selected_skill)
			else:
				line = _strike(actor, attack_target(), actor.patk, "pdef", "기본 공격")
		else:
			line = _enemy_action(actor)
	_note(line)
	last_action.text = line
	var effect_kind = "physical"
	if last_action.kind.contains("shield"): effect_kind = "shield"
	elif last_action.kind.contains("heal"): effect_kind = "heal"
	elif last_action.kind in ["magic", "magic_all", "drain"]: effect_kind = "magic"
	last_action.relic = Data.RELICS[relic_id].name if party.has(actor) and not last_action.cancelled and relic_bonus(effect_kind) > 0 else ""
	if living(enemies).is_empty():
		_victory()
	elif living(party).is_empty():
		phase = "defeat"
		resolving = false
		_note("파티 전멸 · 원정 종료")
	elif cursor >= order.size():
		resolving = false
	if not living(enemies).is_empty(): target_id = attack_target().id
	return line


func _cast(caster: Dictionary, skill_id: String) -> String:
	var skill = SKILLS[skill_id]
	if caster.mp < skill_cost(skill_id):
		return _strike(caster, attack_target(), caster.patk, "pdef", "마력 부족 · 기본 공격")
	caster.mp -= skill_cost(skill_id)
	last_action.name = skill.name
	last_action.kind = skill.kind
	var details: Array[String] = []
	match skill.kind:
		"shield", "party_shield", "magic_shield":
			var targets = [caster]
			if skill.kind == "party_shield": targets = living(party)
			if skill.kind == "magic_shield": targets = [living(party)[0]]
			for target in targets:
				var amount = int(skill.power * caster.matk) if skill.kind == "magic_shield" else int(skill.power)
				amount += relic_bonus("shield")
				target.shield += amount
				_effect(target, "shield", amount)
				details.append("%s 방어막 +%d" % [target.name, amount])
		"heal", "party_heal":
			var targets = living(party) if skill.kind == "party_heal" else [weakest(party)]
			for target in targets:
				var amount = mini(roundi(caster.matk * skill.power) + relic_bonus("heal") + field_bonus("heal"), target.max_hp - target.hp)
				target.hp += amount
				_effect(target, "heal", amount)
				details.append("%s 체력 +%d" % [target.name, amount])
		_:
			var magical = skill.kind in ["magic", "magic_all", "drain"]
			var power = roundi(caster.matk * skill.power) if magical else roundi(caster.patk * skill.power)
			var targets = living(enemies) if skill.kind in ["physical_all", "magic_all"] else [attack_target()]
			for target in targets:
				var defense = target.mdef if magical else target.pdef
				if skill.kind == "pierce": defense = 0
				var before_hp = target.hp
				details.append(_hurt(target, maxi(1, power - defense + attack_bonus(magical, true))))
				if skill.kind == "drain":
					var amount = mini(caster.max_hp - caster.hp, int((before_hp - target.hp) / 2))
					caster.hp += amount
					_effect(caster, "heal", amount)
					details.append("자가 치유 +%d" % amount)
	return "%s · %s → %s" % [caster.name, skill.name, ", ".join(details)]


func weakest(units: Array) -> Dictionary:
	var candidates = living(units)
	candidates.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
	return candidates[0] if not candidates.is_empty() else {}


func _enemy_action(enemy: Dictionary) -> String:
	var move = Data.ENEMY_MOVES[enemy.move]
	last_action.name = move.name
	last_action.kind = move.kind
	var magical = move.kind == "magic"
	var defense = "mdef" if magical else "pdef"
	var power = (enemy.matk if magical else enemy.patk) + move.power
	if move.target == "all":
		var details: Array[String] = []
		for target in living(party):
			details.append(_hurt(target, maxi(1, power - target[defense] + attack_bonus(magical, false))))
		return "%s · %s → %s" % [enemy.name, move.name, ", ".join(details)]
	var target = weakest(party) if move.target == "weak" else living(party)[0]
	return _strike(enemy, target, power, defense, move.name)


func _strike(actor: Dictionary, target: Dictionary, power: int, defense: String, action: String) -> String:
	last_action.name = action
	last_action.kind = "magic" if defense == "mdef" else "physical"
	return "%s · %s → %s" % [actor.name, action, _hurt(target, maxi(1, power - target[defense] + attack_bonus(defense == "mdef", party.has(actor))))]


func _hurt(target: Dictionary, damage: int) -> String:
	var absorbed = mini(target.shield, damage)
	target.shield -= absorbed
	var taken = mini(target.hp, damage - absorbed)
	target.hp -= taken
	var detail = "%s -%d" % [target.name, taken]
	if absorbed > 0: detail += " (방어막 %d)" % absorbed
	if target.hp == 0:
		target.shield = 0
		detail += " · 쓰러짐"
	_effect(target, "damage", taken, absorbed)
	return detail


func _effect(target: Dictionary, kind: String, amount: int, absorbed: int = 0) -> void:
	if not last_action.has("effects"): return
	last_action.effects.append({"target": target.id, "kind": kind, "amount": amount, "absorbed": absorbed, "down": target.hp == 0})


func _victory() -> void:
	phase = "reward"
	resolving = false
	wins += 1
	var earned = 25 + floor_number * 5 + route.risk * 12 + relic_bonus("gold")
	gold += earned
	for hero in party:
		hero.shield = 0
		hero.xp += 10
		while hero.level < 4 and hero.xp >= LEVEL_XP[hero.level]:
			hero.level += 1
		_rebuild_stats(hero)
	pending_drops = _sample(SKILLS.keys(), 2)
	pending_drop = pending_drops[0]
	reward_message = "전원 경험치 +10 · 골드 +%d · 레벨 %d\n스킬 두 개를 차례로 습득하거나 포기합니다." % [earned, party[0].level]
	_note("승리 · %d/6 전투 돌파 · %d레벨" % [wins, party[0].level])


func _learn(hero: Dictionary, skill_id: String) -> void:
	hero.skills.append(skill_id)
	_rebuild_stats(hero)
	reward_message = "%s · %s 습득" % [hero.name, SKILLS[skill_id].name]
	_note(reward_message)


func learn_drop(hero_id: String) -> bool:
	if phase != "reward" or not can_learn(hero_id):
		return false
	_learn(find_unit(hero_id), pending_drop)
	_finish_drop()
	return true


func skip_drop() -> bool:
	if phase != "reward" or pending_drop.is_empty():
		return false
	reward_message = "%s 습득 기회를 포기했습니다." % SKILLS[pending_drop].name
	_note(reward_message)
	_finish_drop()
	return true


func _finish_drop() -> void:
	pending_drops.pop_front()
	pending_drop = "" if pending_drops.is_empty() else pending_drops[0]
	if not pending_drop.is_empty():
		return
	if wins == 6:
		phase = "complete"
		_note("심연의 문지기 격파 · 3층 원정 완료")
	else:
		phase = "rest"
		rested = false
		rest_event_used = false
		rest_event = Data.REST_EVENTS[world_rng.randi_range(0, Data.REST_EVENTS.size() - 1)].duplicate(true)


func rest() -> bool:
	if phase != "rest" or rested or food <= 0:
		return false
	food -= 1
	rested = true
	for hero in party:
		hero.hp = mini(hero.max_hp, hero.hp + ceili(hero.max_hp * 0.55))
		hero.mp = mini(hero.max_mp, hero.mp + ceili(hero.max_mp * 0.6))
	reward_message = "식량 1개 사용 · 파티 체력과 마력 회복"
	_note(reward_message)
	return true


func apply_rest_event(hero_id: String) -> bool:
	var hero = find_unit(hero_id)
	if phase != "rest" or rest_event_used or hero.is_empty() or not party.has(hero):
		return false
	for stat in rest_event.bonus:
		hero.rest_bonus[stat] = hero.rest_bonus.get(stat, 0) + rest_event.bonus[stat]
	_rebuild_stats(hero)
	rest_event_used = true
	reward_message = "%s · %s" % [hero.name, rest_event.name]
	_note(reward_message)
	return true


func continue_run() -> bool:
	if phase != "rest":
		return false
	if room == 2:
		floor_number += 1
		room = 1
	else:
		room += 1
	_open_routes()
	return true


func _note(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 240:
		log_lines.pop_front()
