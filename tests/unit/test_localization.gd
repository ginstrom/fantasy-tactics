extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const PartyManagerScene := preload("res://scenes/ui/party_manager.tscn")
const EncampmentScene := preload("res://scenes/ui/encampment.tscn")
const StartingSettlementScene := preload("res://scenes/local/starting_settlement.tscn")
const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")


func test_translation_keys_resolve_to_expected_english_copy() -> void:
	assert_eq(tr("menu.title"), "Fantasy Tactics")
	assert_eq(tr("menu.new_game"), "New Game")
	assert_eq(tr("menu.quit"), "Quit")
	assert_eq(tr("menu.continue"), "Continue")
	assert_eq(tr("menu.load"), "Load")
	assert_eq(tr("menu.return"), "Return")
	assert_eq(tr("menu.save"), "Save")
	assert_eq(tr("menu.not_implemented"), "Not implemented yet")
	assert_eq(tr("menu.enter_name"), "Enter your name:")
	assert_eq(tr("menu.begin"), "Begin")
	assert_eq(tr("battle.end_turn"), "End Turn")
	assert_eq(tr("battle.round") % 1, "Round 1")
	assert_eq(tr("battle.side.player"), "Player")
	assert_eq(tr("battle.side.enemy"), "Enemy")
	assert_eq(
		tr("battle.hint.select_unit") % "Player",
		"Player's move. Click a unit to select it. Esc: menu."
	)
	assert_eq(
		tr("battle.hint.already_moved") % "Player",
		"Player's move. This unit has already moved. Attack an adjacent enemy or select another unit."
	)
	assert_eq(
		tr("battle.hint.turn_complete") % "Player",
		"Player's move. This unit has moved and attacked. Select another unit."
	)
	assert_eq(
		tr("battle.hint.select_destination") % "Player",
		"Player's move. Click a highlighted tile to move, or select another unit."
	)
	assert_eq(tr("battle.status.awaiting_action"), "No actions yet.")
	assert_eq(tr("battle.status.health") % ["Warrior", 3, 3], "Warrior: 3/3 HP")
	assert_eq(tr("battle.status.defeated") % "Goblin", "Goblin: defeated")
	assert_eq(tr("battle.status.hit") % ["Warrior", 2], "Warrior hits for 2 damage.")
	assert_eq(tr("battle.status.miss") % "Goblin", "Goblin misses.")
	assert_eq(tr("battle.status.enemy_move") % "Goblin", "Goblin moves closer.")
	assert_eq(tr("battle.status.enemy_turn"), "Enemy turn.")
	assert_eq(tr("battle.result.victory") % "Goblin Camp", "Victory! Goblin Camp is cleared.")
	assert_eq(tr("battle.result.defeat"), "Defeat. The party returns to the settlement.")
	assert_eq(
		tr("world_map.hint"),
		(
			"World Map. Click the party to select it, then click a highlighted tile to move. "
			+ "Click a marked location to enter battle. Return to the settlement by clicking a selected party there. "
			+ "Esc: menu."
		)
	)
	assert_eq(tr("world_map.end_turn"), "End Turn")
	assert_eq(tr("world_map.turn") % 3, "Turn 3")
	assert_eq(tr("world_map.arrival_turns") % 8, "8 turns to arrival")
	assert_eq(
		tr("world_map.expedition.label") % ["Goblin Camp", "Low danger", 10],
		"Goblin Camp — Low danger — 10 gold"
	)
	assert_eq(tr("expedition.goblin_camp.name"), "Goblin Camp")
	assert_eq(tr("expedition.orc_outpost.name"), "Orc Outpost")
	assert_eq(tr("expedition.danger.low"), "Low danger")
	assert_eq(tr("expedition.danger.high"), "High danger")
	assert_eq(tr("battle.enemy.goblin"), "Goblin")
	assert_eq(tr("battle.enemy.orc"), "Orc")
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
	assert_eq(tr("encampment.status.no_party"), "Create a party before departing.")
	assert_eq(tr("encampment.status.ready"), "Your party is ready to depart.")
	assert_eq(tr("encampment.depart"), "Depart")
	assert_eq(tr("information.title"), "Information")
	assert_eq(tr("information.player") % "Aria", "Player: Aria")
	assert_eq(tr("information.party") % "Party 1", "Party: Party 1")
	assert_eq(tr("information.gold") % 25, "Gold: 25")
	assert_eq(tr("settlement.title"), "Starting Settlement")
	assert_eq(tr("settlement.description"), "Prepare your party before setting out.")
	assert_eq(tr("settlement.encampment"), "Enter Encampment")
	assert_eq(tr("debug.title"), "Developer Scenarios")
	assert_eq(tr("debug.close_hint"), "F9: close")
	assert_eq(tr("debug.new_campaign"), "New Campaign")
	assert_eq(tr("debug.encampment"), "Encampment")
	assert_eq(tr("debug.party_manager"), "Party Manager")
	assert_eq(tr("debug.party_ready"), "Party Ready to Depart")
	assert_eq(tr("debug.world_map"), "Party on World Map")
	assert_eq(tr("debug.goblin_camp"), "Goblin Camp Battle")
	assert_eq(tr("debug.super_power"), "Super Power")


func test_start_menu_uses_translation_keys_not_literal_copy() -> void:
	var start_menu: Control = StartMenuScene.instantiate()
	add_child_autofree(start_menu)

	assert_eq(start_menu.get_node("Center/VBox/Title").text, "menu.title")
	assert_eq(start_menu.get_node("Center/VBox/ContinueButton").text, "menu.continue")
	assert_eq(start_menu.get_node("Center/VBox/NewGameButton").text, "menu.new_game")
	assert_eq(start_menu.get_node("Center/VBox/LoadButton").text, "menu.load")
	assert_eq(start_menu.get_node("Center/VBox/QuitButton").text, "menu.quit")
	assert_eq(start_menu.get_node("Center/VBox/NameEntry/Prompt").text, "menu.enter_name")
	assert_eq(start_menu.get_node("Center/VBox/NameEntry/BeginButton").text, "menu.begin")


func test_battlefield_hud_buttons_use_translation_keys_not_literal_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("HUD/EndTurnButton").text, "battle.end_turn")
	assert_eq(battlefield.get_node("HUD/Status").text, "battle.status.awaiting_action")


func test_battlefield_hint_is_built_from_translated_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.get_node("HUD/Hint").text, "Player's move. Click a unit to select it. Esc: menu."
	)


func test_battle_hints_no_longer_call_the_action_cycle_a_turn() -> void:
	var hint_keys := [
		"battle.hint.select_unit",
		"battle.hint.already_moved",
		"battle.hint.turn_complete",
		"battle.hint.select_destination",
	]
	for key in hint_keys:
		assert_false(
			(tr(key) % "Player").to_lower().contains("turn"),
			"%s must not call the player/enemy action cycle a turn" % key
		)


func test_battlefield_round_label_uses_translation_key_not_literal_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("HUD/RoundLabel").text, tr("battle.round") % 1)


func test_world_map_hint_uses_translation_key_not_literal_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("HUD/Hint").text, "world_map.hint")


func test_world_map_end_turn_button_uses_translation_key_not_literal_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("HUD/EndTurnButton").text, "world_map.end_turn")


func test_world_map_turn_label_is_built_from_translated_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("HUD/TurnLabel").text, tr("world_map.turn") % 1)


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
	assert_eq(encampment.get_node("Center/VBox/DepartButton").text, "encampment.depart")


func test_information_panel_uses_translation_keys_not_literal_copy() -> void:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	assert_eq(panel.get_node("Content/Title").text, "information.title")


func test_starting_settlement_uses_translation_keys_not_literal_copy() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)

	assert_eq(settlement.get_node("Center/VBox/Title").text, "settlement.title")
	assert_eq(settlement.get_node("Center/VBox/Description").text, "settlement.description")
	assert_eq(
		settlement.get_node("Center/VBox/EncampmentButton").text,
		"settlement.encampment"
	)
