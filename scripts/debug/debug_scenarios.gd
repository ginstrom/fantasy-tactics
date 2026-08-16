class_name DebugScenarios
extends RefCounted

## --- Versioned debug manifest loader ---------------------------------------
##
## Loads config/debug_scenarios.json (see docs/plans/2026-08-16-debug-menu-
## json-config/index.md's "Manifest contract") into an ordered, validated
## cache. Metadata only: this loader does not apply campaign state or route
## scenes -- see apply() below, and GameManager.run_debug_scenario() for
## that. A manifest is parsed and fully validated into scratch values before
## replacing the cache, so a bad reload (malformed JSON, a missing file, or
## a single invalid entry) always leaves the last-known-good cache and its
## scenarios exactly as they were, with the new load's diagnostics available
## via the returned "errors" array.

const DEFAULT_MANIFEST_PATH := "res://config/debug_scenarios.json"
const SUPPORTED_MANIFEST_VERSION := 1
const ALLOWED_LAUNCH_SCENES: Array[String] = [
	"settlement", "encampment", "party_manager", "world_map", "battlefield", "stores",
]

static var _scenarios: Array[Dictionary] = []


## Parses and validates the manifest at `path`, replacing the cache only on
## success. Returns { "ok": bool, "errors": Array[String] }.
static func load_scenarios(path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "errors": ["debug manifest not found: %s" % path]}

	# The JSON class instance's parse() (unlike the static JSON.parse_string())
	# reports a malformed document via a return code instead of an ERROR print,
	# matching the approach SaveRepository._load_raw() uses for save files.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {
			"ok": false,
			"errors": [
				"debug manifest is not valid JSON: %s (%s at line %d)" % [
					path, json.get_error_message(), json.get_error_line()
				],
			],
		}
	if not json.data is Dictionary:
		return {"ok": false, "errors": ["debug manifest does not contain a JSON object: %s" % path]}

	var result := _validate_manifest(_normalize_json_value(json.data))
	if not result.ok:
		return {"ok": false, "errors": result.errors}

	_scenarios = result.scenarios
	return {"ok": true, "errors": []}


## Returns a deep copy of every cached scenario, in manifest source order.
static func get_all_scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scenario in _scenarios:
		result.append(_duplicate_scenario(scenario))
	return result


## Returns a deep copy of the cached scenario with the given id, or an empty
## Dictionary if no such scenario is loaded.
static func get_scenario(id: String) -> Dictionary:
	for scenario in _scenarios:
		if scenario.id == id:
			return _duplicate_scenario(scenario)
	return {}


## Groups the cached scenarios by category, preserving both each category's
## first-seen source order and each scenario's source order within it.
## Returns Array[{"category": String, "scenarios": Array[Dictionary]}].
static func get_scenarios_by_category() -> Array[Dictionary]:
	var category_order: Array[String] = []
	var by_category: Dictionary = {}
	for scenario in _scenarios:
		var category: String = scenario.category
		if not by_category.has(category):
			by_category[category] = [] as Array[Dictionary]
			category_order.append(category)
		by_category[category].append(_duplicate_scenario(scenario))

	var result: Array[Dictionary] = []
	for category in category_order:
		result.append({"category": category, "scenarios": by_category[category]})
	return result


static func _validate_manifest(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if not data.get("manifest_version") is int or int(data.manifest_version) != SUPPORTED_MANIFEST_VERSION:
		errors.append("manifest_version must be %d" % SUPPORTED_MANIFEST_VERSION)
	if not data.get("scenarios") is Array:
		errors.append("scenarios is not an array")
		return {"ok": false, "errors": errors}

	var seen_ids: Dictionary = {}
	var scenarios: Array[Dictionary] = []
	var index := 0
	for raw_entry in data.scenarios:
		var entry_result := _validate_scenario_entry(raw_entry, seen_ids, index)
		if entry_result.ok:
			seen_ids[entry_result.scenario.id] = true
			scenarios.append(entry_result.scenario)
		else:
			errors.append(entry_result.error)
		index += 1

	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {"ok": true, "errors": [], "scenarios": scenarios}


static func _validate_scenario_entry(raw: Variant, seen_ids: Dictionary, index: int) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "scenarios[%d] is not an object" % index}
	var entry: Dictionary = raw

	if not entry.get("id") is String or String(entry.id).is_empty():
		return {"ok": false, "error": "scenarios[%d] has an invalid id" % index}
	var id := String(entry.id)
	if seen_ids.has(id):
		return {"ok": false, "error": "scenarios[%d] has a duplicate id: %s" % [index, id]}

	if not entry.get("name_key") is String or String(entry.name_key).is_empty():
		return {"ok": false, "error": "scenario %s has an invalid name_key" % id}
	if not entry.get("category") is String or String(entry.category).is_empty():
		return {"ok": false, "error": "scenario %s has an invalid category" % id}
	if not entry.get("description") is String:
		return {"ok": false, "error": "scenario %s has an invalid description" % id}

	var launch: Variant = entry.get("launch")
	if (
		not launch is Dictionary
		or not (launch as Dictionary).get("scene") is String
		or not ALLOWED_LAUNCH_SCENES.has(String((launch as Dictionary).scene))
	):
		return {"ok": false, "error": "scenario %s has an invalid launch.scene" % id}

	var snapshot: Variant = entry.get("campaign_snapshot")
	if not snapshot is Dictionary:
		return {"ok": false, "error": "scenario %s has a missing or invalid campaign_snapshot" % id}

	return {
		"ok": true,
		"scenario": {
			"id": id,
			"name_key": String(entry.name_key),
			"category": String(entry.category),
			"description": String(entry.description),
			"launch": {"scene": String((launch as Dictionary).scene)},
			"campaign_snapshot": (snapshot as Dictionary).duplicate(true),
		},
	}


## Undoes JSON's lossy number/key conversions (same gotcha SaveRepository.
## _normalize_json_value() fixes for save files -- Godot's JSON parser hands
## back float for every number and stringifies every Dictionary key), so
## "manifest_version": 1 parses back as an int and an embedded
## campaign_snapshot's int-keyed dictionaries (e.g. mana_crystals) round-trip
## intact for the canonical snapshot import path Step 2 feeds them into.
static func _normalize_json_value(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value:
		return int(value)
	if value is Dictionary:
		var normalized_dict: Dictionary = {}
		for key in (value as Dictionary).keys():
			normalized_dict[_normalize_json_key(key)] = _normalize_json_value(value[key])
		return normalized_dict
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize_json_value(item))
		return normalized_array
	return value


static func _normalize_json_key(key: Variant) -> Variant:
	if key is String and key.is_valid_int():
		return int(key)
	return key


static func _duplicate_scenario(scenario: Dictionary) -> Dictionary:
	var copy: Dictionary = scenario.duplicate(true)
	copy["launch"] = (scenario.launch as Dictionary).duplicate(true)
	copy["campaign_snapshot"] = (scenario.campaign_snapshot as Dictionary).duplicate(true)
	return copy


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
			return _deploy_at_orc_outpost()

		"ruined_fortress":
			return _deploy_at_ruined_fortress()
		"stocked_stores":
			return _stock_shop_and_stores()
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


## For testing the Shop loop directly: a staffed encamped party with a Shop
## (so Stores' Sell button is enabled), Stores
## pre-stocked with 2 tier-1 mana crystals and a banked Iron Shortsword,
## and 500 gold so the Shop Buy tab is actually usable rather
## than every purchase being unaffordable.
static func _stock_shop_and_stores() -> bool:
	if not _create_staffed_party():
		return false
	GameSession.shop_level = 1
	GameSession.mana_crystals = {1: 2}
	GameSession.banked_gear = {"shortsword_iron": 1}
	GameSession.gold = 500
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


static func _create_four_warrior_party() -> bool:
	if not GameSession.create_party():
		return false
	if not GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID):
		return false
	for _extra_warrior in 3:
		GameSession.recruit_adventurer()
		var recruit_id: String = GameSession.adventurers[-1].id
		if not GameSession.assign_adventurer_to_selected_party(recruit_id):
			return false
	return true


static func _deploy_at_orc_outpost() -> bool:
	if not _create_four_warrior_party():
		return false
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enemy_count_roll = func(_min_value: int, _max_value: int) -> int: return 2
	var position: Vector2i = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	return (
		GameSession.depart_selected_party()
		and GameSession.set_deployed_party_position(position)
	)

