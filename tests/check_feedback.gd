extends SceneTree

var app
var failures = 0
var output_dir = ""

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func prepare() -> void:
	app.game.reset(42)
	app.game.explore()
	app.game.choose_route(0)
	app.game.enter_battle()
	app._render(true)
	for frame in range(4): await process_frame

func capture(name: String) -> void:
	if OS.has_feature("headless"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func finish() -> void:
	for frame in range(240):
		if not app.animating: return
		await process_frame
	expect(false, "Animation finishes within time limit")

func _run() -> void:
	root.size = Vector2i(360, 640)
	output_dir = ProjectSettings.globalize_path("res://.qa/visual-upgrade/feedback")
	DirAccess.make_dir_recursive_absolute(output_dir)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.action_delay = 0.9
	await prepare()
	# A five-card hand must scroll horizontally from touch, without selecting a card.
	app.game.hand.append({"caster": "leon", "skill": "quick"})
	app.game.hand.append({"caster": "mira", "skill": "nova"})
	app._render()
	for frame in range(4): await process_frame
	var tray = app.find_child("HandTray", true, false)
	var point = tray.get_global_rect().get_center()
	var finger = InputEventScreenTouch.new()
	finger.position = root.get_final_transform() * point
	finger.pressed = true
	Input.parse_input_event(finger)
	await process_frame
	for i in range(6):
		var drag = InputEventScreenDrag.new()
		point.x -= 22
		drag.position = root.get_final_transform() * point
		drag.relative = root.get_final_transform().basis_xform(Vector2(-22, 0))
		Input.parse_input_event(drag)
		await process_frame
	finger = InputEventScreenTouch.new()
	finger.position = root.get_final_transform() * point
	finger.pressed = false
	Input.parse_input_event(finger)
	for frame in range(4): await process_frame
	expect(tray.scroll_horizontal > 0, "Hand supports horizontal touch drag")
	expect(app.game.selected_skill.is_empty(), "Dragging a card does not select it")
	await capture("five-card-hand-swiped")
	await prepare()
	app.game.order = [{"id": "ria", "priority": 12}]
	app.game.choose_card("ria", "shot")
	app.game.enemies[0].hp = 1
	app.game.enemies[1].hp = 0
	app._render()
	app._resolve_round()
	var arena = app.combat_arena
	expect(app.game.phase == "reward" and app.animating, "Final blow resolves but reward waits for animation")
	expect(app.game.last_action.actor == "ria" and app.game.last_action.effects[0].target == "enemy_0", "Exact actor and actual damage recipient exposed")
	expect(app.game.last_action.effects[0].amount == 1 and app.game.last_action.effects[0].down, "Actual damage and death, not overkill")
	await create_timer(0.52).timeout
	expect(app.combat_arena == arena and is_instance_valid(arena), "Battlefield preserved during impact")
	expect(app.action_banner.text.contains("리아") and app.action_banner.text.contains(app.game.enemies[0].name), "Banner names attacker and target")
	await capture("physical-final-blow")
	await finish()
	expect(app.find_child("SkipReward", true, false) != null, "Reward appears after final impact")

	await prepare()
	app.game.order = [{"id": "enemy_0", "priority": 12}]
	app.game.enemies[0].move = "wave"
	app.game.enemies[0].intent = "마법 파동 · 아군 전체"
	app.game.enemies[0].matk = 12
	app.game.party[0].shield = 5
	app._render()
	app._resolve_round()
	expect(app.game.last_action.effects.size() == 3, "Area attack records all three targets")
	expect(app.game.last_action.effects[0].absorbed == 5, "Absorption separate from HP damage")
	await create_timer(0.52).timeout
	await capture("enemy-area-hit")
	await finish()

	await prepare()
	app.game.order = [{"id": "mira", "priority": 12}]
	app.game.party[0].hp = 5
	app.game.choose_card("mira", "heal")
	app._render()
	app._resolve_round()
	expect(app.game.last_action.effects[0].kind == "heal" and app.game.last_action.effects[0].target == "leon", "Healing event identifies recipient")
	await create_timer(0.52).timeout
	await capture("healing")
	await finish()
	expect(app.find_child("NextRound", true, false) != null, "Controls restored after presentation")
	print("FEEDBACK CHECKS: %d failures; persistent arena, actual targets, final blow, area damage, absorption, healing" % failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
