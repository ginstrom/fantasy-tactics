extends Node
## Walks every known scene/state in the game and saves a screenshot of each.
##
## Add a new step to _build_steps() whenever a new scene or UI state is added
## to the game — no other changes are needed. Each step's action is called,
## then the tree is given a couple of frames to render before the shot is
## taken, so actions can be anything from a scene change to a state mutation
## that only changes what's already on screen (e.g. opening a submenu).

const ENCOUNTER_ID := "goblin_camp"

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
		{"name": "starting_settlement", "action": func() -> void:
			GameManager.go_to_game()},
		{"name": "encampment", "action": func() -> void:
			GameManager.go_to_encampment()},
		{"name": "party_manager_empty", "action": func() -> void:
			GameManager.open_party_manager()},
		{"name": "party_manager_party_created", "action": func() -> void:
			GameSession.create_party()
			GameManager.open_party_manager()},
		{"name": "party_manager_warrior_assigned", "action": func() -> void:
			GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
			GameManager.open_party_manager()},
		{"name": "encampment_ready_to_depart", "action": func() -> void:
			GameManager.go_to_encampment()},
		{"name": "world_map", "action": func() -> void:
			GameManager.depart_selected_party()},
		{"name": "battlefield", "action": func() -> void:
			GameManager.enter_battle(ENCOUNTER_ID)},
		{"name": "game_menu_overlay", "action": func() -> void:
			GameManager.open_game_menu()},
		{"name": "world_map_encounter_complete", "action": func() -> void:
			GameManager.close_game_menu()
			GameManager.complete_battle()},
		{"name": "starting_settlement_revisit", "action": func() -> void:
			GameManager.enter_starting_settlement()},
	]


func _settle() -> void:
	for i in FRAMES_TO_SETTLE:
		await get_tree().process_frame


func _capture(index: int, name: String) -> void:
	var path := _out_dir.path_join("%02d_%s.png" % [index + 1, name])
	var image := get_tree().root.get_texture().get_image()
	image.save_png(path)
