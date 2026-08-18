extends Node
## Walks every known scene/state in the game and saves a screenshot of each.
##
## Add a new step to _build_steps() whenever a new scene or UI state is added
## to the game — no other changes are needed. Each step's action is called,
## then the tree is given a couple of frames to render before the shot is
## taken, so actions can be anything from a scene change to a state mutation
## that only changes what's already on screen (e.g. opening a submenu).

const FRAMES_TO_SETTLE := 2

var _out_dir: String


func run(out_dir: String) -> void:
	_out_dir = out_dir
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var steps := _build_steps()
	for index in steps.size():
		var step: Dictionary = steps[index]
		print("[screenshot_tour] %d/%d %s" % [index + 1, steps.size(), step.name])
		step.action.call()
		await _settle()
		_capture(index, step.name)

	print("[screenshot_tour] done: %d screenshots in %s" % [steps.size(), _out_dir])
	get_tree().quit()


## Ordered tour of the game's scenes and notable UI states. Extend this list
## as new scenes, menus, or states are added — each entry just needs a unique
## name and a Callable that leaves the game showing what you want captured.
func _build_steps() -> Array[Dictionary]:
	return [
		{"name": "start_menu", "action": func() -> void:
			GameManager.go_to_start_menu()},
		{"name": "new_game_party_formation", "action": func() -> void:
			GameManager.go_to_game()},
		{"name": "encampment", "action": func() -> void:
			GameManager.go_to_encampment()},
		{"name": "units", "action": func() -> void:
			GameManager.go_to_units()},
		{"name": "guild_hall", "action": func() -> void:
			GameManager.go_to_guild_hall()},
		{"name": "trade", "action": func() -> void:
			GameManager.go_to_trade()},
		{"name": "stores", "action": func() -> void:
			GameSession.banked_gear = {"shortsword_iron": 1}
			GameSession.mana_crystals = {1: 2}
			GameSession.shop_level = 1
			GameSession.shop_gold = 100
			GameManager.go_to_stores()},
		{"name": "shop", "action": func() -> void:
			GameSession.shop_level = 1
			GameSession.shop_gold = 100
			GameManager.go_to_shop()},
		{"name": "roster", "action": func() -> void:
			GameManager.go_to_roster()},
		{"name": "recruitment", "action": func() -> void:
			GameManager.go_to_recruitment()},
		{"name": "parties", "action": func() -> void:
			GameManager.go_to_parties()},
		{"name": "party_details", "action": func() -> void:
			GameManager.create_party()
			GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
			GameManager.go_to_party_details(GameSession.FIRST_PARTY_ID)},
		{"name": "add_member", "action": func() -> void:
			GameSession.recruit_adventurer()
			GameManager.go_to_add_member(GameSession.FIRST_PARTY_ID)},
		{"name": "recruitment_affordable", "action": func() -> void:
			GameSession.gold = 10
			GameManager.go_to_recruitment()
			call_deferred("_queue_recruitment_candidate_selection")},
		{"name": "recruitment_unaffordable", "action": func() -> void:
			GameSession.gold = 0
			GameManager.go_to_recruitment()
			call_deferred("_queue_recruitment_candidate_selection")},
		{"name": "unit_details_from_roster", "action": func() -> void:
			# Only WARRIOR_ID has been assigned to party_001 (in "parties"),
			# so the rest of the starting roster stays available; the party is
			# still encamped, so the assignment section renders with a real,
			# selectable eligible party rather than the disabled explanation.
			var available := GameSession.get_available_adventurers()
			GameManager.go_to_unit_details_from_roster(available[0].id)},
		{"name": "unit_details", "action": func() -> void:
			GameManager.go_to_unit_details(GameSession.WARRIOR_ID)},
		{"name": "deploy_party", "action": func() -> void:
			GameManager.go_to_deploy_party()},
		{"name": "encampment_ready_to_depart", "action": func() -> void:
			GameManager.go_to_encampment()},
		{"name": "world_map", "action": func() -> void:
			GameManager.depart_selected_party()},
		{"name": "battlefield", "action": func() -> void:
			GameManager.enter_battle(GameSession.GOBLIN_CAMP_ID)},
		{"name": "debug_menu", "action": func() -> void:
			GameManager.toggle_debug_menu()},
		{"name": "game_menu_overlay", "action": func() -> void:
			GameManager.toggle_debug_menu()
			GameManager.open_game_menu()},
		{"name": "world_map_encounter_complete", "action": func() -> void:
			GameManager.close_game_menu()
			GameManager.complete_battle()},
		{"name": "encampment_reward_deposited", "action": func() -> void:
			GameManager.go_to_encampment()},
		{"name": "encampment_revisit", "action": func() -> void:
			GameManager.return_party_to_encampment()},
	]


func _settle() -> void:
	for i in FRAMES_TO_SETTLE:
		await get_tree().process_frame


func _select_first_recruitment_candidate() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var tree: Tree = scene.get_node_or_null("Body/Center/VBox/RecruitmentTable/Tree")
	if tree == null or tree.get_root() == null or tree.get_root().get_first_child() == null:
		return
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")


func _queue_recruitment_candidate_selection() -> void:
	get_tree().process_frame.connect(_select_first_recruitment_candidate, CONNECT_ONE_SHOT)


func _capture(index: int, name: String) -> void:
	var path := _out_dir.path_join("%02d_%s.png" % [index + 1, name])
	var image := get_tree().root.get_texture().get_image()
	image.save_png(path)
