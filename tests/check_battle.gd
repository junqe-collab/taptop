extends SceneTree

const Battle = preload("res://battle.gd")
const Policy = preload("res://tests/play_policy.gd")
var failures = 0
var checks = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func encounter(seed_value = 42):
	var game = Battle.new(seed_value)
	expect(not game.enter_battle(), "Must choose route before battle")
	game.explore()
	game.choose_route(0)
	Policy.event(game)
	game.enter_battle()
	return game

func resolve(game) -> void:
	expect(game.begin_round(), "Round starts")
	expect(not game.begin_round(), "Cannot double start")
	var steps = 0
	while game.resolving and steps < 6:
		game.step_action()
		steps += 1
	expect(steps <= 5 and not game.resolving, "One action per actor")

func check_invariants(game) -> void:
	expect(game.floor_number <= 3 and game.wins <= 6, "Three floors only")
	expect(game.gold >= 0 and game.food >= 0, "Nonnegative resources")
	for hero in game.party:
		expect(hero.level <= 4 and hero.skills.size() <= hero.level, "Skill slot and level cap")
		expect(hero.hp >= 0 and hero.hp <= hero.max_hp and hero.mp >= 0 and hero.mp <= hero.max_mp, "HP MP bounded")
		var unique = {}
		for skill in hero.skills: unique[skill] = true
		expect(unique.size() == hero.skills.size(), "No local duplicate")
		var stats = []
		for stat in game.STAT_NAMES: stats.append(hero[stat])
		game._rebuild_stats(hero)
		var again = []
		for stat in game.STAT_NAMES: again.append(hero[stat])
		expect(stats == again, "Recomputing stats never accumulates bonuses")

func _run() -> void:
	var game = encounter()
	var peer = encounter()
	var original = game.order.duplicate(true)
	expect(peer.order == original and peer.hand == game.hand, "Seed reproduces hand and initiative")
	for entry in game.hand: game.choose_card(entry.caster, entry.skill)
	game.choose_basic()
	expect(game.order == original and not game.next_round(), "Card changes do not reroll initiative")
	for entry in game.order: expect(entry.jitter >= -2 and entry.jitter <= 2, "Bounded jitter")
	for i in range(1, game.order.size()):
		expect(game.order[i - 1].priority >= game.order[i].priority, "Descending initiative")
	var ria = game.find_unit("ria")
	ria.mp = 0
	expect(not game.choose_card("ria", "shot") and game.choose_basic(), "MP gate/basic fallback")
	resolve(game)
	expect(game.next_round(), "Next round after resolution")
	expect(not game.equip("sword", "leon") and not game.learn_drop("leon"), "No equipment or skill acquisition during combat")

	game = encounter()
	game.choose_card("ria", "shot")
	var before_mp = game.find_unit("ria").mp
	game.find_unit("ria").hp = 0
	resolve(game)
	expect(game.find_unit("ria").mp == before_mp, "Dead caster pays no MP")

	game = encounter()
	var leon = game.find_unit("leon")
	leon.shield = 999
	game.order = [{"id": "enemy_0"}, {"id": "leon"}, {"id": "ria"}, {"id": "mira"}, {"id": "enemy_1"}]
	game.enemies[0].move = "front"
	var hp = leon.hp
	game.begin_round()
	game.step_action()
	expect(leon.hp == hp and leon.shield < 999, "Shield absorbs incoming hit")
	game.step_action()
	expect(leon.shield == 0, "Shield expires at recipient action")

	game = encounter()
	game.order = [{"id": "mira"}, {"id": "ria"}, {"id": "leon"}, {"id": "enemy_0"}, {"id": "enemy_1"}]
	game.find_unit("leon").hp = 0
	game.find_unit("ria").hp = 5
	game.choose_card("mira", "heal")
	before_mp = game.find_unit("mira").mp
	game.begin_round()
	game.step_action()
	expect(game.find_unit("leon").hp == 0 and game.find_unit("ria").hp > 5, "Heal cannot revive; targets living ally")
	expect(game.find_unit("mira").mp == before_mp - 3, "Cost charged at cast")

	game = encounter()
	game.enemies[0].hp = 1
	game.order = [{"id": "leon"}, {"id": "ria"}, {"id": "mira"}, {"id": "enemy_0"}, {"id": "enemy_1"}]
	game.choose_card("ria", "shot")
	hp = game.enemies[1].hp
	game.begin_round()
	game.step_action()
	game.step_action()
	expect(game.enemies[0].hp == 0 and game.enemies[1].hp < hp, "Target updates after earlier death")

	# Reward, levels, local duplicate rule, event-only removal.
	game = encounter()
	game._victory()
	expect(game.wins == 1 and game.party[0].level == 2 and game.pending_drops.size() == 2, "XP and two skill offers")
	expect(game.gear_offers.is_empty() and game.shop_gear.is_empty(), "Monster reward has no equipment")
	game.pending_drops = ["spark", "spark"]
	game.pending_drop = "spark"
	var mira = game.find_unit("mira")
	var matk = mira.matk
	before_mp = mira.mp
	expect(game.learn_drop("mira"), "Immediate learning")
	expect(mira.matk == matk + 2 and mira.mp == before_mp, "Skill stat bonus without free refill")
	expect(not game.can_learn("mira") and game.can_learn("leon"), "Duplicate restricted to same hero")
	expect(not game.forget_skill("mira", "spark"), "Removal prohibited outside shrine")
	expect(game.learn_drop("leon") and game.phase == "rest", "Same skill allowed on different heroes")
	game.food = 0
	hp = mira.hp
	expect(not game.rest() and mira.hp == hp, "No food means no recovery")
	expect(game.apply_rest_event("mira") and not game.apply_rest_event("leon"), "Rest stat event once, independent of food")
	game.food = 1
	mira.hp = 0
	expect(game.rest() and mira.hp > 0 and game.food == 0 and not game.rest(), "Food revives once at rest")
	game.continue_run()
	game.routes[0].kind = "shrine"
	game.choose_route(0)
	var bonus = mira.matk
	expect(game.forget_skill("mira", "spark") and mira.matk == bonus - 2, "Shrine removes skill and bonus")
	expect(not game.forget_skill("mira", "heal"), "Only one removal per shrine")
	game.enter_battle()
	game._victory()
	var offers = game.pending_drops.duplicate()
	game.skip_drop()
	expect(not game.pending_drops.has(offers[0]), "Skipped offer discarded")
	game.skip_drop()
	expect(game.pending_drop.is_empty() and not game.learn_drop("mira"), "Skipped skills not stored")

	# Shop atomicity and equipment replacement.
	game.continue_run()
	game.routes[0].kind = "shop"
	game.choose_route(0)
	game.shop_skills = ["spark"]
	game.shop_gear = ["sword", "staff"]
	game.gold = 0
	var before_skills = mira.skills.duplicate()
	expect(not game.buy_skill("spark", "mira") and mira.skills == before_skills, "Insufficient gold causes no partial learn")
	expect(not game.equip("sword", "leon") and game.shop_gear.size() == 2, "Insufficient gold keeps stock")
	game.gold = 200
	var price = game.skill_price("spark")
	expect(game.buy_skill("spark", "mira") and game.gold == 200 - price, "Skill charged exactly once")
	expect(not game.buy_skill("spark", "leon"), "Purchased stock consumed")
	game.equip("sword", "leon")
	var attack = game.find_unit("leon").patk
	expect(game.equip("staff", "leon") and game.find_unit("leon").patk == attack - 3, "Replacing gear removes old bonuses")
	var food = game.food
	expect(game.buy_food() and game.food == food + 1 and not game.buy_food(), "One food purchase per shop")

	# Deck cycles conserve owner-specific cards and never duplicate in hand.
	game.enter_battle()
	for hero in game.party:
		hero.level = 4
		hero.skills = ["guard", "shot", "spark", "heal"]
		game._rebuild_stats(hero)
	game.draw_pile.clear()
	game.discard_pile.clear()
	game.hand.clear()
	for hero in game.party:
		for skill in hero.skills: game.draw_pile.append({"caster": hero.id, "skill": skill})
	for unused in range(20):
		game._draw_hand()
		expect(game.hand.size() == 5 and game.hand.size() + game.draw_pile.size() + game.discard_pile.size() == 12, "Deck conserves cards across shuffle")
		var unique = {}
		for card in game.hand: unique[card.caster + card.skill] = true
		expect(unique.size() == game.hand.size(), "No duplicates in hand")
	game.find_unit("mira").hp = 0
	game._draw_hand()
	expect(game.hand.all(func(card): return card.caster != "mira"), "Dead owner cards excluded")
	expect(not game.can_learn("leon", "nova"), "Four occupied slots block a fifth skill")

	# Skill families with effects not covered by the automated damage policy.
	game = encounter()
	leon = game.find_unit("leon")
	mira = game.find_unit("mira")
	leon.mp = 20
	game._cast(leon, "rally")
	expect(game.party.all(func(hero): return hero.shield == 7), "Party shield reaches every living ally")
	game._cast(mira, "barrier")
	expect(leon.shield == 7 + int(mira.matk * 2) and mira.shield == 7, "Magic shield targets living front")
	mira.hp = 5
	game.enemies[0].shield = 999
	game._cast(mira, "drain")
	expect(mira.hp == 5, "Absorbed damage cannot generate drain healing")
	game.enemies[0].shield = 0
	game.enemies[0].hp = 2
	game._cast(mira, "drain")
	expect(mira.hp == 6, "Drain based on actual HP lost, not overkill")
	game.hand.clear()
	game.draw_pile.clear()
	game.discard_pile.clear()
	game._draw_hand()
	expect(game.hand.is_empty() and game.choose_basic(), "An empty deck still allows basic attacks")

	game.reset(42)
	expect(game.phase == "camp" and game.gold == 40 and game.food == 3 and game.wins == 0, "Reset resources and progress")
	expect(game.party.all(func(hero): return hero.level == 1 and hero.skills.size() == 1 and hero.gear.is_empty() and hero.rest_bonus.is_empty()), "Reset all build growth")
	expect(game.toggle_companion("ria") and not game.explore(), "Exactly two companions required")
	expect(game.toggle_companion("sera") and game.set_front("sera") and game.party[0].id == "sera", "Choose companions and formation")
	game.explore()
	expect(not game.toggle_companion("mira"), "Party choice fixed after departure")

	# Six archetype pairings, several hundred seeded complete runs.
	var wins = 0
	var basic_wins = 0
	var risky_wins = 0
	var signatures = {}
	var best_seed = -1
	var progress = [0, 0, 0, 0, 0, 0, 0]
	var pairs = [["ria", "mira"], ["ria", "orin"], ["ria", "sera"], ["mira", "orin"], ["mira", "sera"], ["orin", "sera"]]
	for seed_value in range(120):
		game = Battle.new(seed_value)
		Policy.run(game)
		check_invariants(game)
		expect(game.phase in ["complete", "defeat"], "Run always terminates")
		progress[game.wins] += 1
		if game.phase == "complete":
			wins += 1
			if best_seed < 0: best_seed = seed_value
			expect(game.party.all(func(hero): return hero.level == 4) and game.floor_number == 3, "Final completion at level 4 floor 3")
		signatures[str(game.party.map(func(hero): return hero.skills))] = true
		peer = Battle.new(seed_value)
		Policy.run(peer)
		expect(peer.log_lines == game.log_lines and peer.party == game.party, "Same seed and decisions reproduce entire run")
		var basic = Battle.new(seed_value)
		Policy.run(basic, false)
		if basic.phase == "complete": basic_wins += 1
		var risky = Battle.new(seed_value)
		Policy.run(risky, true, true)
		check_invariants(risky)
		if risky.phase == "complete": risky_wins += 1
	for pair in pairs:
		var pair_wins = 0
		for seed_value in range(30):
			game = Battle.new(seed_value)
			game.companions = pair.duplicate()
			game.reset(seed_value)
			Policy.run(game)
			check_invariants(game)
			expect(game.phase in ["complete", "defeat"], "All party archetypes terminate")
			if game.phase == "complete": pair_wins += 1
		print("PARTY %s: %d/30" % [str(pair), pair_wins])
	expect(wins > 0 and signatures.size() > 20, "Playable completion and varied builds")
	expect(wins > basic_wins, "Build decisions improve this test policy")
	print("RUN CHECKS: %d checks, %d failures; built %d/120, basic %d/120, risky %d/120; builds %d; progress %s; UI seed %d" % [checks, failures, wins, basic_wins, risky_wins, signatures.size(), str(progress), best_seed])
	quit(0 if failures == 0 else 1)
