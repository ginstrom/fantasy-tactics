extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const EncampmentScene := preload("res://scenes/ui/encampment.tscn")
const UnitsScene := preload("res://scenes/ui/units.tscn")
const PartiesScene := preload("res://scenes/ui/parties.tscn")
const StartingSettlementScene := preload("res://scenes/local/starting_settlement.tscn")
const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")
const LevelUpScene := preload("res://scenes/ui/level_up.tscn")


func test_translation_keys_resolve_to_expected_english_copy() -> void:
	assert_eq(tr("menu.title"), "Fantasy Tactics")
	assert_eq(tr("menu.new_game"), "New Game")
	assert_eq(tr("menu.quit"), "Quit")
	assert_eq(tr("menu.continue"), "Continue")
	assert_eq(tr("menu.load"), "Load")
	assert_eq(tr("menu.return"), "Return")
	assert_eq(tr("menu.save"), "Save")
	assert_eq(tr("menu.save_success"), "Campaign saved.")
	assert_eq(tr("menu.save_failed"), "Save failed.")
	assert_eq(tr("menu.load_failed"), "Load failed.")
	assert_eq(tr("menu.load_confirm_message"), "Loading will discard your current unsaved progress. Continue?")
	assert_eq(tr("menu.load_confirm_cancel"), "Cancel")
	assert_eq(tr("menu.load_confirm_load"), "Load")
	assert_eq(tr("menu.enter_name"), "Enter your name:")
	assert_eq(tr("menu.random"), "🎲 Random")
	assert_eq(tr("menu.begin"), "Begin")
	assert_eq(tr("battle.end_turn"), "End Turn")
	assert_eq(tr("battle.end_turn.reminder"), "End Turn forfeits remaining AP.")
	assert_eq(tr("battle.action_points") % [3, 9], "AP: 3 / 9")
	assert_eq(tr("battle.title") % "Goblin Camp", "Goblin Camp Battle")
	assert_eq(tr("battle.title") % "Orc Outpost", "Orc Outpost Battle")
	assert_eq(tr("battle.round") % 1, "Round 1")
	assert_eq(tr("battle.side.player"), "Player")
	assert_eq(tr("battle.side.enemy"), "Enemy")
	assert_eq(
		tr("battle.hint.select_unit") % "Player",
		"Player's move. Click a unit to select it, or press 1-5. Esc: menu."
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
		"Player's move. Click a highlighted tile to move (or use WASD), or select another unit."
	)
	assert_eq(tr("battle.status.awaiting_action"), "No actions yet.")
	assert_eq(tr("battle.status.health") % ["Warrior", 3, 3], "Warrior: 3/3 HP")
	assert_eq(tr("battle.status.defeated") % "Goblin", "Goblin: defeated")
	assert_eq(tr("battle.status.hit") % ["Warrior", 2], "Warrior hits for 2 damage.")
	assert_eq(tr("battle.status.critical_hit") % ["Warrior", 6], "Critical Hit! Warrior hits for 6 damage.")
	assert_eq(tr("battle.status.miss") % "Goblin", "Goblin misses.")
	assert_eq(tr("battle.status.enemy_move") % "Goblin", "Goblin moves closer.")
	assert_eq(tr("battle.status.enemy_turn"), "Enemy turn.")
	assert_eq(
		tr("battle.log.hit") % ["Warrior 2", "Kobold 2", 3],
		"Warrior 2 attacks Kobold 2 — hits for 3 damage!"
	)
	assert_eq(
		tr("battle.log.miss") % ["Warrior", "Kobold 1"],
		"Warrior attacks Kobold 1 — misses."
	)
	assert_eq(
		tr("battle.log.critical_hit") % ["Warrior 2", "Kobold 2", 6],
		"Warrior 2 attacks Kobold 2 — Critical Hit! Hits for 6 damage!"
	)
	assert_eq(tr("battle.log.defeated") % "Kobold 2", "Kobold 2 is defeated!")
	assert_eq(
		tr("battle.log.flank.side") % ["Warrior", "Kobold 1", 3],
		"Warrior attacks Kobold 1 from the side — hits for 3 damage!"
	)
	assert_eq(
		tr("battle.log.flank.rear") % ["Warrior", "Kobold 1", 3],
		"Warrior attacks Kobold 1 from behind — hits for 3 damage!"
	)
	assert_eq(
		tr("battle.log.flank.side_crit") % ["Warrior", "Kobold 1", 6],
		"Warrior attacks Kobold 1 from the side — Critical Hit! Hits for 6 damage!"
	)
	assert_eq(
		tr("battle.log.flank.rear_crit") % ["Warrior", "Kobold 1", 6],
		"Warrior attacks Kobold 1 from behind — Critical Hit! Hits for 6 damage!"
	)
	assert_eq(tr("battle.unit_info.empty"), "Hover or click a unit to see its details.")
	assert_eq(tr("battle.unit_info.hp") % [3, 8], "HP: 3/8")
	assert_eq(tr("battle.unit_info.ap") % [3, 9], "AP: 3/9")
	assert_eq(tr("battle.unit_info.weapon") % "Longsword", "Weapon: Longsword")
	assert_eq(tr("battle.unit_info.healthy"), "Healthy")
	assert_eq(tr("battle.unit_info.wounded"), "Wounded")
	assert_eq(tr("battle.unit_info.badly_wounded"), "Badly Wounded")
	assert_eq(tr("battle.unit_info.facing") % "South", "Facing: South")
	assert_eq(tr("battle.facing.east"), "East")
	assert_eq(tr("battle.facing.west"), "West")
	assert_eq(tr("battle.facing.north"), "North")
	assert_eq(tr("battle.facing.south"), "South")
	assert_eq(tr("battle_result.title"), "Victory!")
	assert_eq(tr("battle_result.kills") % "Goblin x1", "Enemies defeated: Goblin x1")
	assert_eq(tr("battle_result.no_kills"), "No enemies defeated.")
	assert_eq(tr("battle_result.xp") % [15, 15], "XP gained: 15 total (15 each)")
	assert_eq(tr("battle_result.leveled_up") % "Warrior, Warrior 2", "Leveled up: Warrior, Warrior 2")
	assert_eq(tr("battle_result.gold") % 5, "Gold: 5")
	assert_eq(tr("battle_result.ok"), "OK")
	assert_eq(tr("battle.result.victory") % "Goblin Camp", "Victory! Goblin Camp is cleared.")
	assert_eq(tr("battle.result.defeat"), "Defeat. The party returns to the settlement.")
	assert_eq(tr("battle.feedback.out_of_range"), "Target is out of range.")
	assert_eq(
		tr("battle.feedback.not_enough_ap") % 3,
		"Not enough Action Points to attack (requires 3 AP)."
	)
	assert_eq(
		tr("battle.feedback.line_of_sight_blocked"),
		"Line of sight to target is blocked."
	)
	assert_eq(
		tr("battle.feedback.paralyzed") % "Warrior",
		"Warrior is paralyzed and cannot act."
	)
	assert_eq(tr("battle.action.move"), "Move")
	assert_eq(tr("battle.action.attack"), "Attack")
	assert_eq(tr("battle.action.retreat"), "Retreat")
	assert_eq(tr("battle.action.heal"), "Heal")
	assert_eq(tr("battle.action.bless"), "Bless")
	assert_eq(tr("battle.mp") % [2, 3], "MP: 2 / 3")
	assert_eq(tr("battle.status.spell_heal") % ["Cleric", "Warrior", 5], "Cleric heals Warrior for 5 HP.")
	assert_eq(tr("battle.status.spell_bless") % ["Cleric", "Warrior"], "Cleric blesses Warrior.")
	assert_eq(
		tr("battle.log.spell.heal") % ["Cleric", "Warrior", 5],
		"Cleric casts Heal on Warrior, restoring 5 HP."
	)
	assert_eq(tr("battle.log.spell.bless") % ["Cleric", "Warrior"], "Cleric casts Bless on Warrior.")
	assert_eq(tr("battle.feedback.spell_invalid_target"), "That target is not a legal spell target.")
	assert_eq(tr("class.cleric"), "Cleric")
	assert_eq(tr("item.mace_iron"), "Iron Mace")
	assert_eq(tr("information.encounter_danger") % "★★", "Danger: ★★")
	assert_eq(tr("information.encounter_enemies") % ["Goblin", 3], "Enemies: Goblin x3")
	assert_eq(tr("battle.result.retreat"), "The party retreats.")
	assert_eq(tr("battle.log.retreat.no_loss") % "Warrior", "Warrior slips away unscathed.")
	assert_eq(tr("battle.log.retreat.hp_loss") % ["Warrior", 3], "Warrior retreats, losing 3 HP.")
	assert_eq(tr("battle.log.retreat.death") % "Warrior", "Warrior does not survive the retreat.")
	assert_eq(
		tr("battle.feedback.move_mode"),
		"Move mode: click a highlighted tile to move."
	)
	assert_eq(
		tr("battle.feedback.attack_mode"),
		"Attack mode: click an enemy to attack."
	)
	assert_eq(tr("battle.status.thorn_trigger") % "Warrior", "Warrior is Paralyzed!")
	assert_eq(tr("battle.item.use_potion"), "Use Potion — 2 AP")
	assert_eq(tr("battle.item.transfer"), "Give Item — 2 AP")
	assert_eq(tr("battle.item.recipient"), "Give to")
	assert_eq(
		tr("battle.status.potion") % ["Warrior", "Healing Potion", 5],
		"Warrior uses Healing Potion and recovers 5 HP"
	)
	assert_eq(
		tr("battle.status.item_transfer") % ["Warrior", "Healing Potion", "Warrior 2"],
		"Warrior gives Healing Potion to Warrior 2"
	)
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
	assert_eq(tr("expedition.goblin_camp.name"), "Goblin Camp")
	assert_eq(tr("expedition.orc_outpost.name"), "Orc Outpost")
	assert_eq(tr("battle.enemy.goblin"), "Goblin")
	assert_eq(tr("battle.enemy.orc"), "Orc")
	assert_eq(tr("battle.enemy.goblin.attack"), "Short Sword")
	assert_eq(tr("battle.enemy.orc.attack"), "War Axe")
	assert_eq(tr("battle.enemy.kobold"), "Kobold")
	assert_eq(tr("battle.enemy.kobold.attack"), "Rusty Dagger")
	assert_eq(tr("battle.enemy.hobgoblin"), "Hobgoblin")
	assert_eq(tr("battle.enemy.hobgoblin.attack"), "Two-Handed Sword")
	assert_eq(tr("party.title"), "Party Manager")
	assert_eq(tr("party.warrior.summary"), "Warrior — warrior, sword")
	assert_eq(tr("party.status.empty"), "Your party has no adventurers.")
	assert_eq(tr("party.status.unassigned"), "Warrior is available to join a party.")
	assert_eq(tr("party.status.assigned"), "Warrior is assigned to the party.")
	assert_eq(tr("ui.back"), "Back")
	assert_eq(tr("encampment.title"), "Encampment")
	assert_eq(tr("encampment.units"), "Units")
	assert_eq(tr("encampment.buildings"), "Buildings")
	assert_eq(tr("encampment.trade"), "Trade")
	assert_eq(tr("encampment.deploy_party"), "Deploy Party")
	assert_eq(tr("units.title"), "Units")
	assert_eq(tr("units.parties"), "Parties")
	assert_eq(tr("units.roster"), "Roster")
	assert_eq(tr("units.recruitment"), "Recruitment")
	assert_eq(tr("units.parties_count") % 2, "Parties: 2")
	assert_eq(tr("units.roster_count") % 13, "Units in roster: 13")
	assert_eq(tr("units.recruitment_count") % 2, "Recruitable units: 2")
	assert_eq(tr("units.view"), "View")
	assert_eq(tr("parties.title"), "Parties")

	assert_eq(tr("parties.create"), "Create Party")
	assert_eq(tr("parties.enter_name"), "Name this party:")
	assert_eq(tr("parties.confirm_name"), "OK")
	assert_eq(tr("parties.empty"), "No parties yet.")
	assert_eq(tr("party_details.add_member"), "Add Member")
	assert_eq(tr("ui.tbd"), "TBD")
	assert_eq(tr("information.title"), "Information")
	assert_eq(tr("information.player") % "Aria", "Player: Aria")
	assert_eq(tr("information.party") % "Party 1", "Party: Party 1")
	assert_eq(tr("information.gold") % 25, "Gold: 25")
	assert_eq(tr("information.party_gold") % 15, "Party Gold: 15")
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
	assert_eq(tr("roster.title"), "Roster")
	assert_eq(tr("roster.empty"), "No adventurers yet.")
	assert_eq(tr("roster.column.name"), "Name")
	assert_eq(tr("roster.column.class"), "Class")
	assert_eq(tr("roster.column.level"), "Level")
	assert_eq(tr("roster.column.status"), "Status")
	assert_eq(tr("roster.column.party"), "Party")
	assert_eq(tr("roster.unassigned"), "Unassigned")
	assert_eq(tr("recruitment.title"), "Recruitment")
	assert_eq(tr("recruitment.empty"), "No adventurers are available to recruit.")
	assert_eq(tr("recruitment.column.name"), "Name")
	assert_eq(tr("recruitment.column.class"), "Class")
	assert_eq(tr("recruitment.column.level"), "Level")
	assert_eq(tr("recruitment.column.cost"), "Cost")
	assert_eq(tr("recruitment.column.cost_unit"), "gold")
	assert_eq(tr("information.recruitment_cost"), "Cost:")
	assert_eq(tr("information.recruit"), "Recruit")
	assert_eq(tr("unit_details.no_eligible_party"), "No encamped party is available to join.")
	assert_eq(tr("unit_details.add_to_party"), "Add to Party")
	assert_eq(tr("parties.column.party"), "Party")
	assert_eq(tr("parties.column.members"), "Members")
	assert_eq(tr("parties.column.status"), "Status")
	assert_eq(tr("availability.available"), "Healthy")
	assert_eq(tr("availability.unavailable"), "Unavailable")
	assert_eq(tr("party_status.encamped"), "Encamped")
	assert_eq(tr("party_status.deployed"), "Deployed")
	assert_eq(tr("deploy_party.column.party"), "Party")
	assert_eq(tr("deploy_party.column.members"), "Members")
	assert_eq(tr("deploy_party.column.status"), "Status")
	assert_eq(
		tr("deploy_party.hint"),
		"Double-click a row, or select it and press Enter, to deploy that party."
	)
	assert_eq(tr("party_details.column.name"), "Name")
	assert_eq(tr("party_details.column.class"), "Class")
	assert_eq(tr("party_details.column.level"), "Level")
	assert_eq(tr("party_details.gold") % 250, "Party Gold: 250")
	assert_eq(tr("add_member.column.name"), "Name")
	assert_eq(tr("add_member.column.class"), "Class")
	assert_eq(tr("add_member.column.level"), "Level")
	assert_eq(
		tr("add_member.hint"),
		"Double-click a row, or select it and press Enter, to add that adventurer to the party."
	)
	assert_eq(
		tr("unit_details.stats") % [25, 50, 64, 64, 4], "XP: 25 / 50 — Attack: 64 raw / 64% hit chance — Health: 4"
	)
	assert_eq(tr("unit_details.skills") % 10, "Unspent skill points: 10")
	assert_eq(
		tr("unit_details.perks") % tr("unit_details.perk_status.learned"), "Perks: Bonus Move learned"
	)
	assert_eq(
		tr("unit_details.perks") % tr("unit_details.perk_status.not_learned"),
		"Perks: Bonus Move not yet learned"
	)
	assert_eq(tr("level_up.title"), "Level Up!")
	assert_eq(tr("level_up.xp") % 20, "XP: 20")
	assert_eq(tr("level_up.level") % 2, "Level: 2")
	assert_eq(tr("level_up.health_gain") % [4, 1], "Max Health: 4 (+1)")
	assert_eq(tr("level_up.perk_pending"), "Choose a perk to continue.")
	assert_eq(tr("level_up.choose_bonus_move"), "Choose Bonus Move")
	assert_eq(tr("level_up.continue"), "Continue")
	assert_eq(tr("guild_hall.title"), "Guild Hall")
	assert_eq(tr("guild_hall.level") % 1, "Guild Hall — Level 1")
	assert_eq(tr("guild_hall.party_size") % 4, "Party size: 4")
	assert_eq(tr("guild_hall.upgrade") % 50, "Upgrade to Level 2 — 50 gold")
	assert_eq(tr("guild_hall.max_level"), "Max Level")
	assert_eq(tr("campaign.objective.label"), "Active Objective:")
	assert_eq(tr("campaign.victory.goal_label"), "Campaign Goal: Defeat the Borderlands Ogre")
	assert_eq(tr("campaign.obj.tier1_1.title"), "Scout the Perimeter")
	assert_eq(tr("campaign.obj.tier1_1.desc"), "Form a party and clear the Goblin Outpost.")
	assert_eq(tr("campaign.obj.tier1_1.reward"), "50 Gold, Iron Weapon")
	assert_eq(tr("campaign.free_play.active_label"), "Free Play Mode Active")

	# Step 5 (docs/plans/2026-08-18-core-loop-and-engagement/
	# 05-authored-encounters-and-final-boss.md): encounter names, boss
	# titles, and victory text for the 12-battle authored ladder.
	assert_eq(tr("battle.enemy.goblin_archer"), "Goblin Archer")
	assert_eq(tr("battle.enemy.kobold_slinger"), "Kobold Slinger")
	assert_eq(tr("battle.enemy.goblin_shaman"), "Goblin Shaman")
	assert_eq(tr("battle.enemy.orc_bruiser"), "Orc Bruiser")
	assert_eq(tr("battle.enemy.hobgoblin_elite"), "Hobgoblin Elite")
	assert_eq(tr("battle.enemy.hobgoblin_champion"), "Hobgoblin Champion")
	assert_eq(tr("battle.enemy.orc_warlord"), "Orc Warlord")
	assert_eq(tr("battle.enemy.ogre"), "Ogre")
	assert_eq(tr("expedition.obj_tier1_1_goblin_outpost.name"), "Goblin Outpost")
	assert_eq(tr("expedition.obj_preboss_1_borderlands_vanguard.name"), "The Gatehouse")
	assert_eq(tr("expedition.obj_preboss_2_borderlands_stronghold.name"), "Honor Guard")
	assert_eq(tr("expedition.obj_boss_borderlands_ogre.name"), "The Ogre's Lair")
	assert_eq(tr("campaign.obj.preboss_2.title"), "Defeat the Honor Guard")
	assert_eq(tr("campaign.obj.boss.title"), "Defeat the Borderlands Ogre")
	assert_eq(tr("campaign.obj.boss.desc"), "Defeat the Ogre and win the campaign.")
	assert_eq(tr("campaign.obj.boss.reward"), "Campaign Victory")
	assert_eq(tr("victory.title"), "Campaign Victory!")
	assert_eq(tr("victory.stat.turns") % 10, "World Turns Elapsed: 10")
	assert_eq(tr("victory.stat.battles_won") % 12, "Battles Won: 12")
	assert_eq(tr("victory.stat.casualties") % 0, "Casualties: 0")
	assert_eq(tr("victory.stat.gold_banked") % 500, "Gold Banked: 500")
	assert_eq(tr("victory.stat.upgrades") % 3, "Encampment Upgrades: 3")
	assert_eq(tr("victory.continue_free_play"), "Continue in Free Play")
	assert_eq(tr("debug.preboss_encounter"), "Jump to Pre-Boss Encounter")


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

	assert_eq(battlefield.get_node("%EndTurnButton").text, "battle.end_turn")
	assert_eq(battlefield.get_node("%Status").text, "battle.status.awaiting_action")


func test_battlefield_hint_is_built_from_translated_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	# Round one opens with the first party member already selected (see
	# battle_controller.gd's _ready()), so the hint reflects the
	# select-a-destination state rather than the no-selection one.
	assert_eq(
		battlefield.get_node("%Hint").text,
		"Player's move. Click a highlighted tile to move (or use WASD), or select another unit."
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

	assert_eq(battlefield.get_node("%RoundLabel").text, tr("battle.round") % 1)


## The header title interpolates the translated encounter name into the
## translated "%s Battle" template (matching RoundLabel's own pattern above),
## so -- like RoundLabel -- it can't rely on Godot's auto-translation alone
## and is set imperatively via tr() in battlefield.gd.
func test_battlefield_title_label_uses_translated_battle_title_copy() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.get_node("%BattleTitleLabel").text,
		tr("battle.title") % tr("expedition.goblin_camp.name")
	)


func test_world_map_hint_uses_translation_key_not_literal_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("%Hint").text, "world_map.hint")


func test_world_map_end_turn_button_uses_translation_key_not_literal_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("%EndTurnButton").text, "world_map.end_turn")


func test_world_map_turn_label_is_built_from_translated_copy() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("%TurnLabel").text, tr("world_map.turn") % 1)


func test_encampment_uses_translation_keys_not_literal_copy() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)

	assert_eq(encampment.get_node("Body/Center/VBox/Title").text, "encampment.title")
	assert_eq(encampment.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 4)
	assert_eq(encampment.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)
	assert_eq(encampment.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 4)


func test_units_and_parties_use_translation_keys_not_literal_copy() -> void:
	var units: Control = UnitsScene.instantiate()
	add_child_autofree(units)
	var parties: Control = PartiesScene.instantiate()
	add_child_autofree(parties)

	assert_eq(units.get_node("Body/Center/VBox/Title").text, "units.title")
	assert_eq(units.get_node("Body/Center/VBox/PartiesRow/PartiesViewButton").text, tr("units.view"))
	assert_eq(units.get_node("Body/Center/VBox/RosterRow/RosterViewButton").text, tr("units.view"))
	assert_eq(units.get_node("Body/Center/VBox/RecruitmentRow/RecruitmentViewButton").text, tr("units.view"))
	assert_eq(parties.get_node("Body/Center/VBox/Title").text, "parties.title")
	assert_eq(parties.get_node("Body/Center/VBox/EmptyLabel").text, "parties.empty")



func test_information_panel_uses_translation_keys_not_literal_copy() -> void:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	assert_eq(panel.get_node("Content/Title").text, "information.title")


func test_level_up_uses_translation_keys_not_literal_copy() -> void:
	var level_up: Control = LevelUpScene.instantiate()
	add_child_autofree(level_up)

	assert_eq(level_up.continue_button.text, "level_up.continue")
	assert_eq(level_up.choose_bonus_move_button.text, "level_up.choose_bonus_move")


func test_starting_settlement_uses_translation_keys_not_literal_copy() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)

	assert_eq(settlement.get_node("Center/VBox/Title").text, "settlement.title")
	assert_eq(settlement.get_node("Center/VBox/Description").text, "settlement.description")
	assert_eq(
		settlement.get_node("Center/VBox/EncampmentButton").text,
		"settlement.encampment"
	)
