class_name DebugScenarios
extends RefCounted

const WORLD_MAP_POSITION := Vector2i(1, 0)
const GOBLIN_CAMP_POSITION := Vector2i(4, 4)

const SCENARIO_IDS := [
	"new_campaign",
	"encampment",
	"party_manager",
	"party_ready",
	"world_map",
	"goblin_camp",
	"orc_outpost",
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
		"world_map":
			return _deploy_at(WORLD_MAP_POSITION)
		"goblin_camp":
			return _deploy_at(GOBLIN_CAMP_POSITION)
		"orc_outpost":
			return _deploy_at(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position)
	return false


static func _create_staffed_party() -> bool:
	return (
		GameSession.create_party()
		and GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	)


static func _deploy_at(position: Vector2i) -> bool:
	return (
		_create_staffed_party()
		and GameSession.depart_selected_party()
		and GameSession.set_deployed_party_position(position)
	)
