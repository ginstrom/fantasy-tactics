class_name DebugScenarios
extends RefCounted

const WORLD_MAP_POSITION := Vector2i(1, 0)

const SCENARIO_IDS := [
	"new_campaign",
	"encampment",
	"party_manager",
	"party_ready",
	"party_empty",
	"world_map",
	"goblin_camp",
	"orc_outpost",
	"ruined_fortress",
	"stocked_stores",
]


static func scenario_ids() -> Array[String]:
	return SCENARIO_IDS.duplicate()


static func apply(scenario_id: String) -> bool:
	GameSession.start_new_game()
	GameSession.reset_injectable_rolls()
	match scenario_id:
		"new_campaign", "encampment", "party_manager":
			return true
		"party_ready":
			return _create_staffed_party()
		"party_empty":
			return GameSession.create_party()
		"world_map":
			return _deploy_at(WORLD_MAP_POSITION)
		"goblin_camp":
			return _deploy_at(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)
		"orc_outpost":
			return _deploy_at(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position)
		"ruined_fortress":
			return _deploy_at_ruined_fortress()
		"stocked_stores":
			return _stock_trading_post_and_stores()
	return false


static func _create_staffed_party() -> bool:
	return (
		GameSession.create_party()
		and GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	)


## A lone Warrior is not a representative test of the Ruined Fortress's up to
## 8 fielded enemies (see _deploy_at_ruined_fortress()), so that scenario
## stages three level-1 Warriors instead of the single-Warrior party every
## other scenario uses -- recruit_adventurer() mints a fresh level-1 Warrior
## for free, bypassing the gold cost and recruitment-offer flow, same as the
## debug menu's own "Recruit Adventurer" button. Three members is within the
## Guild Hall's level-1 cap (4), so no Guild Hall upgrade is needed here.
static func _create_three_warrior_party() -> bool:
	if not GameSession.create_party():
		return false
	if not GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID):
		return false
	for _extra_warrior in 2:
		GameSession.recruit_adventurer()
		var recruit_id: String = GameSession.adventurers[-1].id
		if not GameSession.assign_adventurer_to_selected_party(recruit_id):
			return false
	return true


## For testing the Trade loop directly: a staffed encamped party, a Trading
## Post already owned (so Stores' Sell button is enabled), and Stores
## pre-stocked with 2 tier-1 mana crystals and a banked Iron Shortsword.
static func _stock_trading_post_and_stores() -> bool:
	if not _create_staffed_party():
		return false
	GameSession.has_trading_post = true
	GameSession.mana_crystals = {1: 2}
	GameSession.banked_gear = {"shortsword_iron": 1}
	return true


static func _deploy_at(position: Vector2i) -> bool:
	return (
		_create_staffed_party()
		and GameSession.depart_selected_party()
		and GameSession.set_deployed_party_position(position)
	)


## The Ruined Fortress is never a starting active encounter (see
## GameSession.reset()) and only otherwise appears via a power-weighted
## vacancy refill (see GameSession._choose_encounter_template()) -- both
## awkward to trigger from a menu click. This activates it directly at
## its documented position and pins both composition rolls to the Kobold
## option at its maximum count (8), so this scenario reliably exercises
## the largest battle the game can field.
static func _deploy_at_ruined_fortress() -> bool:
	if not _create_three_warrior_party():
		return false
	var position: Vector2i = GameSession.get_expedition(GameSession.RUINED_FORTRESS_ID).position
	GameSession.active_encounters.append(
		GameSession._make_encounter_instance(
			GameSession.RUINED_FORTRESS_ID, GameSession.RUINED_FORTRESS_ID, position
		)
	)
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enemy_count_roll = func(_min_value: int, _max_value: int) -> int: return 8
	return (
		GameSession.depart_selected_party()
		and GameSession.set_deployed_party_position(position)
	)
