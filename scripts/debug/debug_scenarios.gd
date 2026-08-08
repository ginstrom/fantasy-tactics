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
	"stocked_stores",
]


static func scenario_ids() -> Array[String]:
	return SCENARIO_IDS.duplicate()


static func apply(scenario_id: String) -> bool:
	GameSession.start_new_game()
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
		"stocked_stores":
			return _stock_trading_post_and_stores()
	return false


static func _create_staffed_party() -> bool:
	return (
		GameSession.create_party()
		and GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	)


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
