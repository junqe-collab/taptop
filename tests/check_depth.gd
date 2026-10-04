extends SceneTree

const Battle = preload("res://battle.gd")
const Policy = preload("res://tests/play_policy.gd")
var checks = 0
var failures = 0

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func encounter(relic = "coin", field = "quiet"):
	var game = Battle.new(42)
	game.relic_id = relic
	game.explore()
	game.routes[0].field = field
	game.choose_route(0)
	game.enter_battle()
	return game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fields = {}
	var relics = {}
	for seed_value in range(120):
		var game = Battle.new(seed_value)
		var peer = Battle.new(seed_value)
		expect(game.relic_offers == peer.relic_offers and game.relic_offers.size() == 3, "Seeded three-relic draft")
		var unique = {}
		for id in game.relic_offers:
			relics[id] = true
			unique[id] = true
		expect(unique.size() == 3, "No duplicate relic offers")
		expect(not game.choose_relic("invalid"), "Unknown relic rejected")
		expect(game.choose_relic(game.relic_offers[1]), "Choose offered relic")
		peer.choose_relic(peer.relic_offers[1])
		game.explore()
		peer.explore()
		expect(game.routes == peer.routes, "Identical route previews")
		expect(game.routes[0].field != game.routes[1].field, "Two different battlefield choices")
		for route in game.routes: fields[route.field] = true
		game.choose_route(0)
		expect(not game.choose_relic(game.relic_offers[0]), "Relic locked after departure")
		var before = game.world_rng.state
		for unused in range(5):
			game.battlefield()
			game.skill_cost("shot")
			game.attack_bonus(true, true)
		expect(before == game.world_rng.state, "Presentation queries never reroll world")
	expect(fields.size() == Battle.Data.BATTLEFIELDS.size() and relics.size() == Battle.Data.RELICS.size(), "All field/relic content reachable")

	var game = encounter()
	var first = game.enemies[0]
	var second = game.enemies[1]
	var before_rng = game.rng.state
	var order = game.order.duplicate(true)
	expect(game.choose_target(second.id) and game.attack_target() == second, "Select rear threat")
	expect(not game.choose_target("leon") and not game.choose_target("unknown"), "Only living enemies targetable")
	expect(game.rng.state == before_rng and game.order == order, "Target choice keeps initiative and RNG")
	var second_hp = second.hp
	game.order = [{"id": "ria"}, {"id": "leon"}]
	game.choose_card("ria", "shot")
	game.begin_round()
	expect(not game.choose_target(first.id), "Target locked during resolution")
	game.step_action()
	expect(second.hp < second_hp and first.hp == first.max_hp, "Single skill hits selected rear enemy")
	second.hp = 0
	game.step_action()
	expect(first.hp < first.max_hp, "Basic attack retargets after selected enemy death")

	game = encounter()
	for hero in game.party:
		hero.skills = ["guard", "shot", "spark", "heal"]
	game.draw_pile.clear()
	game.hand.clear()
	for hero in game.party:
		for skill in hero.skills: game.draw_pile.append({"caster": hero.id, "skill": skill})
	game._draw_hand()
	var previous = game.hand.duplicate(true)
	order = game.order.duplicate(true)
	var intents = game.enemies.map(func(enemy): return enemy.intent)
	game.choose_card(previous[0].caster, previous[0].skill)
	expect(game.redraw_hand(), "One tactical redraw available")
	expect(game.hand != previous and game.hand.size() == 5, "Remaining cards replace hand")
	expect(game.order == order and game.enemies.map(func(enemy): return enemy.intent) == intents, "Redraw preserves enemy telegraph and initiative")
	expect(game.hand.size() + game.draw_pile.size() + game.discard_pile.size() == 12, "Redraw conserves deck")
	expect(game.selected_skill.is_empty() and not game.redraw_hand(), "Redraw clears selection and cannot repeat")
	game = encounter()
	expect(not game.can_redraw(), "No redraw when all living cards already in hand")
	game.reset(42)
	expect(not game.redraw_used and game.target_id.is_empty(), "New run resets tactical state")

	for relic in Battle.Data.RELICS:
		game = encounter(relic)
		var hero = game.find_unit("mira")
		match Battle.Data.RELICS[relic].effect:
			"physical", "magic":
				var magical = relic == "moon"
				expect(game.attack_bonus(magical, true) == 2 and game.attack_bonus(magical, false) == 0, "Damage relic helps only heroes")
			"shield":
				game._cast(game.party[0], "rally")
				expect(game.party.all(func(unit): return unit.shield == 11), "Relic buffs each party shield")
			"heal":
				game.party[0].hp = 1
				game._cast(hero, "heal")
				expect(game.party[0].hp == 1 + roundi(hero.matk * 1.6) + 4, "Relic boosts actual healing")
			"mana":
				game.phase = "event"
				hero.mp = 0
				game.party[0].hp = 0
				game.party[0].mp = 0
				game.enter_battle()
				expect(hero.mp == 2 and game.party[0].mp == 0, "Mana relic recovers living allies only")
			"gold":
				var gold = game.gold
				game._victory()
				expect(game.gold == gold + 40, "Coin adds ten gold to first victory")
		# Stat recomputation never mutates the data definitions.
		expect(Battle.Data.HEROES.mira.stats[4] == 8 and Battle.Data.SKILLS.heal.cost == 3, "Shared content remains immutable")

	game = encounter("fang", "embers")
	expect(game.attack_bonus(false, true) == 4 and game.attack_bonus(false, false) == 2, "Physical field affects both sides and stacks with relic")
	game = encounter("moon", "arcane")
	expect(game.attack_bonus(true, true) == 4 and game.attack_bonus(true, false) == 2, "Magic field affects both sides")
	game = encounter("coin", "spring")
	expect(game.skill_cost("quick") == 1 and game.skill_cost("heal") == 2, "Mana field has a one-point floor")
	game.find_unit("mira").mp = 2
	expect(game.choose_card("mira", "heal"), "Discounted card playable at effective cost")
	game._cast(game.find_unit("mira"), "heal")
	expect(game.find_unit("mira").mp == 0, "Cast charges displayed effective cost")
	game = encounter("bloom", "bloom")
	game.party[0].hp = 1
	game._cast(game.find_unit("mira"), "heal")
	expect(game.party[0].hp == 1 + roundi(game.find_unit("mira").matk * 1.6) + 7, "Healing field stacks with relic")

	# Different relic decisions produce different full-run outcomes without losing reproducibility.
	var differences = 0
	for seed_value in range(30):
		game = Battle.new(seed_value)
		var peer = Battle.new(seed_value)
		var variant = Battle.new(seed_value)
		variant.choose_relic(variant.relic_offers[1])
		Policy.run(game)
		Policy.run(peer)
		Policy.run(variant)
		expect(game.party == peer.party and game.log_lines == peer.log_lines, "Full new-system replay deterministic")
		if game.party != variant.party or game.gold != variant.gold: differences += 1
	expect(differences >= 20, "Relic choice changes the expedition")
	print("DEPTH CHECKS: %d checks, %d failures; relics %d, fields %d, different decisions %d/30" % [checks, failures, relics.size(), fields.size(), differences])
	quit(0 if failures == 0 else 1)
