extends SceneTree

const Policy = preload("res://tests/play_policy.gd")
var app
var failures = 0
var captures = false
var output_dir = ""
var touch_mode = false

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(4): await process_frame

func click(node_name: String) -> void:
	await settle()
	if app.game.phase == "event" and app.game.route.kind == "shop":
		var tab = -1
		if node_name.begins_with("Gear_"): tab = 1
		elif node_name.begins_with("ShopSkill_"): tab = 0
		elif node_name == "BuyFood": tab = 2
		if tab >= 0 and tab != app.shop_tab: await click("ShopTab_%d" % tab)
	var button = app.find_child(node_name, true, false)
	if button == null:
		expect(false, "Missing button " + node_name)
		return
	expect(not button.disabled, "Enabled button " + node_name)
	var management_scroll = app.find_child("ManagementScroll", true, false)
	if app.manage_sheet.visible and management_scroll.is_ancestor_of(button):
		management_scroll.ensure_control_visible(button)
	if node_name.begins_with("Skill_"):
		app.find_child("HandTray", true, false).ensure_control_visible(button)
	await settle()
	var center = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = center
	button.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		if touch_mode:
			var event = InputEventScreenTouch.new()
			event.position = root.get_final_transform() * center
			if button.get_viewport() != root: event.position = center
			event.pressed = pressed
			if button.get_viewport() == root: Input.parse_input_event(event)
			else: button.get_viewport().push_input(event, true)
		else:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = center
			event.global_position = center
			event.pressed = pressed
			if button.get_viewport() != root:
				event.position += Vector2(button.get_viewport().position)
				event.global_position = event.position
			root.push_input(event, true)
		await process_frame
	await settle()

func capture(label: String, _from_top = true) -> void:

	await settle()
	expect(app.page.size.x <= root.get_visible_rect().size.x, "No horizontal overflow at " + label)
	expect(app.page.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Entire page fits without scrolling at " + label)
	if app.game.phase == "combat":
		var action = app.find_child("ResolveRound", true, false)
		if action != null:
			expect(action.get_global_rect().end.y <= root.get_visible_rect().size.y, "Battle action fits without vertical scrolling at " + label)
	if captures:
		await RenderingServer.frame_post_draw
		var error = root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
		expect(error == OK, "Screenshot saved " + label)

func confirm(accept: bool) -> void:
	var dialog = app.get_node_or_null("ChoiceConfirmation")
	expect(dialog != null and dialog.visible, "Confirmation visible")
	if dialog == null: return
	if accept: dialog.confirmed.emit()
	else: dialog.canceled.emit()
	await settle()

func event_ui() -> void:
	if app.game.route.kind == "cache":
		var choice = Policy.gear_choice(app.game, app.game.gear_offers)
		if not choice.is_empty():
			await click("Gear_" + choice.gear)
			await capture("gear-recipient")
			await click("CancelItem")
			expect(app.game.gear_offers.has(choice.gear), "Cancel retains equipment offer")
			await click("Gear_" + choice.gear)
			await click("Equip_" + choice.hero)
			expect(app.game.find_unit(choice.hero).gear.values().has(choice.gear), "Equipment assigned by actual click")
	elif app.game.route.kind == "shop":
		await capture("shop-floor-%d" % app.game.floor_number)
		if app.game.food < 2: await click("BuyFood")
		for unused in range(2):
			var affordable = app.game.shop_gear.filter(func(key): return app.game.GEAR[key].price <= app.game.gold)
			var choice = Policy.gear_choice(app.game, affordable)
			if not choice.is_empty():
				await click("Gear_" + choice.gear)
				await click("Equip_" + choice.hero)
		for key in app.game.shop_skills.duplicate():
			var hero = Policy.recipient(app.game, key)
			if not hero.is_empty() and app.game.gold >= app.game.skill_price(key):
				await click("ShopSkill_" + key)
				var gold = app.game.gold
				await click("CancelItem")
				expect(app.game.gold == gold and app.game.shop_skills.has(key), "Cancel does not charge or consume skill")
				await click("ShopSkill_" + key)
				await click("BuySkill_" + hero)
				expect(app.game.find_unit(hero).skills.has(key), "Shop skill learned immediately")

func fight_ui() -> void:
	var rounds = 0
	while app.game.phase == "combat" and rounds < 100:
		if app.game.cursor >= app.game.order.size(): await click("NextRound")
		var choice = Policy.card(app.game)
		if choice.is_empty(): await click("SelectBasic")
		else: await click("Skill_" + choice.caster + "_" + choice.skill)
		if rounds == 0:
			await capture("battle-%d-%d-hand" % [app.game.floor_number, app.game.room], false)
		await click("ResolveRound")
		for frame in range(150):
			if not app.animating: break
			await process_frame
		expect(not app.animating, "Round animation terminates")
		rounds += 1
	expect(app.game.phase != "combat", "Combat terminates")

func _run() -> void:
	captures = OS.get_cmdline_user_args().has("--capture")
	touch_mode = OS.get_cmdline_user_args().has("--touch")
	output_dir = OS.get_environment("TAPTOP_QA_DIR")
	if output_dir.is_empty(): output_dir = ProjectSettings.globalize_path("res://.qa/mobile-depth")
	if not OS.has_feature("editor"): output_dir = OS.get_executable_path().get_base_dir().path_join(".qa/three-floors")
	if OS.get_cmdline_user_args().has("--phone"):
		root.size = Vector2i(360, 640)
		output_dir = output_dir.path_join("phone")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var dimensions = arg.trim_prefix("--size=").split("x")
			root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
			output_dir = output_dir.path_join(arg.trim_prefix("--size="))
	DirAccess.make_dir_recursive_absolute(output_dir)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.action_delay = 0.001
	app.game.reset(0)
	app._render()
	await capture("01-camp")
	await click("Hero_leon")
	expect(app.sheet.visible and app.sheet_text.text.contains("속도"), "Character details open")
	await capture("character-detail")
	app.sheet.hide()
	await click("Formation")
	await capture("management")
	await click("Companion_ria")
	expect(app.find_child("StartExpedition", true, false).disabled, "Incomplete party cannot depart")
	await click("Companion_sera")
	expect(app.game.find_unit("sera").skills == ["spark"], "Companion archetype initialized")
	await click("Companion_sera")
	await click("Companion_ria")
	# Restore the default ordering after testing selection.
	await click("Front_ria")
	expect(app.game.party[0].id == "ria", "Formation changes")
	await click("Front_leon")
	app.manage_sheet.hide()
	app.game.reset(0)
	app._render()
	await click("ViewBuild")
	expect(app.sheet.visible and app.sheet_text.text.contains("카드"), "Build view opens")
	app.sheet.hide()
	await click("ChooseRelic")
	var initial_relic = app.game.relic_id
	var other_relic = app.game.relic_offers[1]
	await click("Relic_" + other_relic)
	expect(app.game.relic_id == other_relic, "Relic selection by input")
	await click("Relic_" + initial_relic)
	await click("CloseManagement")
	expect(not app.manage_sheet.visible, "Management closes by input")
	await click("StartExpedition")
	expect(app.game.phase == "exploration", "Start enters exploration")
	for encounter in range(6):
		expect(app.game.floor_number == 1 + int(encounter / 2), "Correct floor progression")
		if encounter == 5: expect(app.game.party.all(func(hero): return hero.level == 4), "Level 4 before boss")
		await capture("routes-%d" % encounter)
		await click("Route_0")
		await event_ui()
		await click("EnterBattle")
		await capture("battle-%d-%d" % [app.game.floor_number, app.game.room])
		for target_index in [1, 0]:
			var target_id = app.game.enemies[target_index].id
			var point = app.combat_arena.global_position + app.combat_arena.unit_position(target_id)
			for pressed in [true, false]:
				if touch_mode:
					var touch = InputEventScreenTouch.new()
					touch.position = root.get_final_transform() * point
					touch.pressed = pressed
					Input.parse_input_event(touch)
				else:
					var tap = InputEventMouseButton.new()
					tap.position = point
					tap.button_index = MOUSE_BUTTON_LEFT
					tap.pressed = pressed
					root.push_input(tap, true)
				await process_frame
			await settle()
			expect(app.game.target_id == target_id, "Enemy targeting by actual input")
		await fight_ui()
		expect(app.game.phase == "reward", "Button path wins encounter %d" % encounter)
		if app.game.phase != "reward": break
		await capture("reward-%d" % encounter)
		while app.game.phase == "reward":
			var hero = Policy.recipient(app.game, app.game.pending_drop)
			if hero.is_empty():
				var offer = app.game.pending_drop
				await click("SkipReward")
				await confirm(false)
				expect(app.game.pending_drop == offer, "Cancel preserves pending skill")
				await click("SkipReward")
				await confirm(true)
			else:
				await click("Learn_" + hero)
		if app.game.phase == "rest":
			await capture("rest-%d" % encounter)
			if encounter == 0:
				var original_size = root.size
				root.size = Vector2i(412, 915)
				await settle()
				root.size = Vector2i(360, 560)
				await capture("rest-after-resize")
				root.size = original_size
				await settle()
			await click("RestRecover")
			expect(app.game.rested, "Rest recovers once")
			await click("RestEvent_" + app.game.party[0].id)
			expect(app.game.rest_event_used, "Rest event applied")
			await click("ContinueRun")
	expect(app.game.phase == "complete" and app.game.wins == 6, "Complete all six encounters")
	await capture("complete")
	if app.game.phase == "complete":
		await click("Hero_mira")
		await capture("level-4-detail")
		app.sheet.hide()
		await click("FullLog")
		expect(app.log_sheet.visible and app.log_text.text.contains("3층 원정 완료"), "Full expedition log")
		app.log_sheet.hide()
		await click("ReplaySeed")
		expect(app.game.run_seed == 0 and app.game.phase == "camp" and app.game.wins == 0, "Same seed retry clears progress")

	# Directly prepare rare event fixtures; exercise their controls.
	app.game.reset(8)
	app.game.explore()
	app.game.routes[0].kind = "shrine"
	app.game.choose_route(0)
	app._render(true)
	await click("OpenShrine")
	await click("Forget_leon_guard")
	await confirm(false)
	expect(app.game.party[0].skills == ["guard"], "Cancel shrine removal")
	await click("Forget_leon_guard")
	await confirm(true)
	expect(app.game.party[0].skills.is_empty() and app.game.event_used, "Special event removes skill")
	app.manage_sheet.hide()
	await capture("shrine-used")
	app.game.enter_battle()
	app.game._victory()
	while app.game.phase == "reward": app.game.skip_drop()
	app.game.food = 0
	app._render(true)
	await capture("rest-no-food")
	expect(app.find_child("RestRecover", true, false).disabled, "No resource disables recovery")
	await click("RestEvent_leon")
	await click("ContinueRun")
	await click("Route_0")
	await click("EnterBattle")
	for enemy in app.game.enemies:
		enemy.hp = 999
		enemy.patk = 999
		enemy.matk = 999
	await fight_ui()
	expect(app.game.phase == "defeat", "Lethal encounter reaches defeat")
	await capture("defeat")
	if app.game.phase == "defeat": await click("Restart")
	expect(app.game.phase == "camp" and app.game.party[0].skills == ["guard"], "Defeat restart clears build")
	print("UI CHECKS: %d failures; six encounters, level 4, floor 3, companions, gear, shops, skills, shrine, rest, defeat, same-seed retry; touch=%s" % [failures, touch_mode])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
