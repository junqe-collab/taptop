extends RefCounted
## Deterministic test player; uses visible offers, stats and hand only.

static func recipient(game, skill_id: String) -> String:
	var best = -INF
	var chosen = ""
	var skill = game.SKILLS[skill_id]
	for hero in game.party:
		if not game.can_learn(hero.id, skill_id): continue
		var value = hero.patk if skill.kind in ["physical", "physical_all", "pierce"] else hero.matk
		if skill.kind in ["shield", "party_shield"]: value = hero.max_hp * 0.3
		value -= hero.skills.size() * 2
		if value > best:
			best = value
			chosen = hero.id
	return chosen

static func gear_choice(game, offers: Array) -> Dictionary:
	var chosen = {}
	var best = 0.0
	for key in offers:
		var item = game.GEAR[key]
		for hero in game.party:
			var weights = {"patk": 1.2, "matk": 1.5 if hero.matk > hero.patk else 0.2,
				"pdef": 2.0 if hero == game.party[0] else 0.7, "mdef": 1.0,
				"speed": 0.5, "max_hp": 0.3, "max_mp": 0.5}
			var value = 0.0
			for stat in item.bonus: value += item.bonus[stat] * weights[stat]
			var old = hero.gear.get(item.slot, "")
			if not old.is_empty():
				for stat in game.GEAR[old].bonus: value -= game.GEAR[old].bonus[stat] * weights[stat]
			if value > best:
				best = value
				chosen = {"gear": key, "hero": hero.id}
	return chosen

static func card(game) -> Dictionary:
	var chosen = {}
	var best = 0.0
	var enemy = game.attack_target()
	for entry in game.hand:
		var hero = game.find_unit(entry.caster)
		var skill = game.SKILLS[entry.skill]
		if hero.hp <= 0 or hero.mp < game.skill_cost(entry.skill): continue
		var basic = mini(enemy.hp, maxi(1, hero.patk - enemy.pdef))
		var value = -float(basic) - game.skill_cost(entry.skill) * 0.3
		match skill.kind:
			"heal", "party_heal":
				var targets = game.living(game.party) if skill.kind == "party_heal" else [game.weakest(game.party)]
				for target in targets:
					value += mini(target.max_hp - target.hp, roundi(hero.matk * skill.power)) * (1.7 if target.hp < target.max_hp * 0.6 else 0.7)
			"shield", "magic_shield", "party_shield":
				value += 2.0 # Prefer damage/heal unless an attack adds almost nothing.
			_:
				var magical = skill.kind in ["magic", "magic_all", "drain"]
				var targets = game.living(game.enemies) if skill.kind in ["physical_all", "magic_all"] else [enemy]
				for target in targets:
					var defense = target.mdef if magical else target.pdef
					if skill.kind == "pierce": defense = 0
					var damage = mini(target.hp, maxi(1, roundi((hero.matk if magical else hero.patk) * skill.power) - defense))
					value += damage
					if damage == target.hp: value += 4
					if skill.kind == "drain": value += mini(hero.max_hp - hero.hp, damage / 2.0)
		if value > best:
			best = value
			chosen = entry
	return chosen

static func event(game) -> void:
	if game.route.kind == "cache":
		var choice = gear_choice(game, game.gear_offers)
		if not choice.is_empty(): game.equip(choice.gear, choice.hero)
	elif game.route.kind == "shop":
		if game.food < 2: game.buy_food()
		for unused in range(2):
			var affordable = game.shop_gear.filter(func(key): return game.GEAR[key].price <= game.gold)
			var choice = gear_choice(game, affordable)
			if not choice.is_empty(): game.equip(choice.gear, choice.hero)
		for key in game.shop_skills.duplicate():
			var hero = recipient(game, key)
			if not hero.is_empty(): game.buy_skill(key, hero)

static func fight(game, use_skills = true) -> void:
	for unused in range(100):
		if game.phase != "combat": return
		if game.cursor >= game.order.size(): game.next_round()
		var choice = card(game) if use_skills else {}
		if not choice.is_empty(): game.choose_card(choice.caster, choice.skill)
		else: game.choose_basic()
		game.begin_round()
		while game.resolving: game.step_action()

static func run(game, use_build = true, risky = false) -> void:
	game.explore()
	for unused in range(6):
		game.choose_route(1 if risky else 0)
		if use_build: event(game)
		game.enter_battle()
		fight(game, use_build)
		while game.phase == "reward":
			var hero = recipient(game, game.pending_drop) if use_build else ""
			if hero.is_empty(): game.skip_drop()
			else: game.learn_drop(hero)
		if game.phase != "rest": return
		game.rest()
		if use_build: game.apply_rest_event(game.party[0].id)
		game.continue_run()
