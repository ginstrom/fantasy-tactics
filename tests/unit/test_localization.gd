extends GutTest

const MainMenuScene := preload("res://scenes/ui/main_menu.tscn")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const PartyManagerScene := preload("res://scenes/ui/party_manager.tscn")
const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func test_translation_keys_resolve_to_expected_english_copy() -> void:
	assert_eq(tr("menu.title"), "Fantasy Tactics")
	assert_eq(tr("menu.new_game"), "New Game")
	assert_eq(tr("menu.quit"), "Quit")
	assert_eq(tr("battle.end_turn"), "End Turn")
	assert_eq(tr("battle.complete_battle"), "Complete Battle")
	assert_eq(tr("battle.side.player"), "Player")
	assert_eq(tr("battle.side.enemy"), "Enemy")
	assert_eq(
		tr("battle.hint.select_unit") % "Player",
		"Player turn. Click a unit to select it. Esc: main menu."
	)
	assert_eq(
		tr("battle.hint.already_moved") % "Player",
		"Player turn. This unit has already moved. Select another unit."
	)
	assert_eq(
		tr("battle.hint.select_destination") % "Player",
		"Player turn. Click a highlighted tile to move, or select another unit."
	)
	assert_eq(
		tr("world_map.hint"),
		(
			"World Map. Click the party to select it, then click a highlighted tile to move. "
			+ "Click the marked location to enter battle. Esc: main menu."
		)
	)
	assert_eq(tr("party.title"), "Party Manager")
	assert_eq(tr("party.warrior.summary"), "Warrior — warrior, sword")
	assert_eq(tr("party.status.empty"), "Your party has no adventurers.")
	assert_eq(tr("party.status.unassigned"), "Warrior is available to join a party.")
	assert_eq(tr("party.status.assigned"), "Warrior is assigned to the party.")
	assert_eq(tr("party.create"), "Create Party")
	assert_eq(tr("party.add_warrior"), "Add Warrior")
	assert_eq(tr("party.remove_warrior"), "Remove Warrior")
	assert_eq(tr("ui.back"), "Back")
	assert_eq(tr("encampment.title"), "Encampment")
	assert_eq(tr("encampment.manage_party"), "Manage Party")


func test_main_menu_uses_translation_keys_not_literal_copy() -> void:
	var main_menu: Control = MainMenuScene.instantiate()
	add_child_autofree(main_menu)

	assert_eq(main_menu.get_node("Center/VBox/Title").text, "menu.title")
	assert_eq(main_menu.get_node("Center/VBox/NewGameButton").text, "menu.new_game")
	assert_eq(main_menu.get_node("Center/VBox/QuitButton").text, "menu.quit")


func test_battlefield_hud_buttons_use_translation_keys_not_literal_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("HUD/EndTurnButton").text, "battle.end_turn")
	assert_eq(battlefield.get_node("HUD/CompleteBattleButton").text, "battle.complete_battle")


func test_battlefield_hint_is_built_from_translated_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.get_node("HUD/Hint").text, "Player turn. Click a unit to select it. Esc: main menu."
	)


func test_world_map_hint_uses_translation_key_not_literal_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("HUD/Hint").text, "world_map.hint")


func test_party_manager_uses_translation_keys_not_literal_copy() -> void:
	var party_manager: Control = PartyManagerScene.instantiate()
	add_child_autofree(party_manager)

	assert_eq(party_manager.get_node("Center/VBox/Title").text, "party.title")
	assert_eq(party_manager.get_node("Center/VBox/WarriorSummary").text, "party.warrior.summary")
	assert_eq(party_manager.get_node("Center/VBox/CreatePartyButton").text, "party.create")
	assert_eq(party_manager.get_node("Center/VBox/AddWarriorButton").text, "party.add_warrior")
	assert_eq(party_manager.get_node("Center/VBox/RemoveWarriorButton").text, "party.remove_warrior")
	assert_eq(party_manager.get_node("Center/VBox/BackButton").text, "ui.back")


func test_encampment_uses_translation_keys_not_literal_copy() -> void:
	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)

	assert_eq(encampment.get_node("Center/VBox/Title").text, "encampment.title")
	assert_eq(
		encampment.get_node("Center/VBox/ManagePartyButton").text, "encampment.manage_party"
	)
