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
	"settlement", "encampment", "party_manager", "parties", "world_map", "battlefield", "stores",
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


## Applies a manifest scenario by importing a deep copy of its embedded
## campaign_snapshot fixture through GameSession.import_campaign_snapshot()
## exactly once -- the same all-or-nothing seam the save system uses (see
## CampaignSnapshot). Never resets GameSession first and never assigns a
## durable field directly: the fixture is already a complete snapshot, and
## a successful import already replaces every durable field GameSession
## owns. Returns { "ok": bool, "errors": Array[String] }, matching
## load_scenarios()'s result shape; a failed import (invalid embedded
## snapshot) or an unknown scenario id leaves GameSession's current state
## untouched.
static func apply(scenario_id: String) -> Dictionary:
	var scenario := get_scenario(scenario_id)
	if scenario.is_empty():
		return {"ok": false, "errors": ["unknown debug scenario: %s" % scenario_id]}

	var snapshot: Dictionary = (scenario.campaign_snapshot as Dictionary).duplicate(true)
	var import_result: Dictionary = GameSession.import_campaign_snapshot(snapshot)
	if not import_result.ok:
		return {"ok": false, "errors": [String(import_result.error)]}
	return {"ok": true, "errors": []}

