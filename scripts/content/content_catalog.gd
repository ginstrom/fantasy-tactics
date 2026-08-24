class_name ContentCatalog
extends RefCounted
## Pure, stateless loader/normalizer for authored encounter content (Stage 6
## Step 3, docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 03-authored-content-catalog.md; target contract in that plan's
## decision-ledger.md). Every function here re-reads config/content/*.json
## fresh off disk on every call and returns immutable, JSON-safe-plus-
## Vector2i-typed Dictionaries plus a flat list of "<category>: <detail>"
## validation error strings -- it never caches a parsed result and never
## touches GameSession or any other mutable global state. Re-parsing a
## couple of small JSON files on every call is cheap at this game's
## turn-based cadence, and it is exactly what lets a hand-edited encounter
## JSON take effect immediately with no restart (see this step's own manual
## check).
##
## Per G2's disposition (decision-ledger.md), the first schema version is
## static, pre-battle setup data only -- no scripted mid-battle event
## boundary.
##
## Field names below follow this step's own JSON schema block literally
## (not decision-ledger.md's contract-summary field list, which uses
## "title_key"/"reward_loot_table_id" where the step file uses "name_key"/
## "reward_bonus_multiplier"/"clear_xp" -- the step file is the more
## detailed, authoritative spec for this step; see 03-authored-content-
## catalog.md's own literal JSON block). One deliberate addition on top of
## that literal block: each `cover_tiles` entry also carries a "tier"
## ("low"/"high", see grid.gd's own COVER_LOW/COVER_HIGH) -- the step file's
## example omits it, but this codebase's existing Cover mechanic has always
## distinguished the two tiers (different Guard bonuses), so an
## authored-content schema that dropped that distinction would silently
## flatten real, already-shipped gameplay data. The other field, an
## `enemy_composition` entry's key is always "template_id" (the step file's
## own literal example has one entry typo'd as "kobold" instead of
## "template_id" -- treated as a typo, not a second valid key shape).

const DEFAULT_CATALOG_PATH := "res://config/content/catalog.json"

## Mirrors WorldMapScript's own GRID_WIDTH/GRID_HEIGHT (scripts/world/
## world_map.gd) -- an encounter's `world_position` places it on the World
## Map board, a different coordinate space from its own battle `grid_size`.
## Kept honest by a guard-rail test in tests/unit/test_content_catalog.gd,
## the same pattern scenario_contract.gd's own DEFAULT_BOARD_WIDTH/HEIGHT
## already uses against BattleController's board constants.
const WORLD_MAP_WIDTH := 7
const WORLD_MAP_HEIGHT := 7

## Mirrors grid.gd's COVER_LOW/COVER_HIGH.
const COVER_TIERS: Array[String] = ["low", "high"]

## Canonical enemy-template vocabulary this catalog resolves `template_id`
## against -- mirrors GameSession's own *_ENEMY_STATS consts (see
## resolve_enemy_template() below). scenario_contract.gd's own
## KNOWN_ENEMY_TEMPLATES is sourced from this exact list (not a hand-kept
## duplicate) so a scenario-tooling template and a ContentCatalog template
## can never silently drift apart -- this step's own "validate enemy
## templates ... against ContentCatalog" requirement.
const KNOWN_ENEMY_TEMPLATE_IDS: Array[String] = [
	"goblin", "orc", "kobold", "hobgoblin",
	"goblin_archer", "goblin_shaman", "kobold_slinger", "orc_bruiser",
	"hobgoblin_elite", "hobgoblin_champion", "orc_warlord", "ogre",
]


## Resolves a named enemy template to GameSession's own *_ENEMY_STATS const.
## BattleStateFactory._read_enemy_template_stats() delegates here rather
## than keeping its own duplicate match statement, so this is genuinely the
## single source of truth both ContentCatalog's own validation and
## battle-scenario tooling read from. Returns {} for an unrecognized id.
static func resolve_enemy_template(template_id: String) -> Dictionary:
	match template_id:
		"goblin":
			return GameSession.GOBLIN_ENEMY_STATS
		"orc":
			return GameSession.ORC_ENEMY_STATS
		"kobold":
			return GameSession.KOBOLD_ENEMY_STATS
		"hobgoblin":
			return GameSession.HOBGOBLIN_ENEMY_STATS
		"goblin_archer":
			return GameSession.GOBLIN_ARCHER_ENEMY_STATS
		"goblin_shaman":
			return GameSession.GOBLIN_SHAMAN_ENEMY_STATS
		"kobold_slinger":
			return GameSession.KOBOLD_SLINGER_ENEMY_STATS
		"orc_bruiser":
			return GameSession.ORC_BRUISER_ENEMY_STATS
		"hobgoblin_elite":
			return GameSession.HOBGOBLIN_ELITE_ENEMY_STATS
		"hobgoblin_champion":
			return GameSession.HOBGOBLIN_CHAMPION_ENEMY_STATS
		"orc_warlord":
			return GameSession.ORC_WARLORD_ENEMY_STATS
		"ogre":
			return GameSession.OGRE_ENEMY_STATS
		_:
			return {}


## Loads and validates the whole catalog: the manifest at `catalog_path`
## plus every encounter file it references. Returns:
## {
##   "valid": bool,        -- true iff `errors` is empty
##   "version": int,        -- the manifest's own "version" field (0 if unreadable)
##   "errors": Array[String], -- every problem found, "<category>: <detail>"
##   "encounters": Dictionary[String, Dictionary], -- id -> normalized definition,
##       containing only encounters that parsed AND individually validated
##       cleanly (a broken encounter file is excluded, not partially merged)
## }
## Never partially valid in the sense of raising/crashing: a missing or
## malformed manifest/encounter file always yields errors plus a safe
## (possibly empty) `encounters` dict, mirroring GameConfig's own
## never-crash-on-bad-config contract.
static func load_catalog(catalog_path: String = DEFAULT_CATALOG_PATH) -> Dictionary:
	var errors: Array[String] = []
	var manifest := _read_json_dict(catalog_path)
	if manifest.is_empty():
		errors.append("catalog_manifest: %s is missing or not valid JSON" % catalog_path)
		return {"valid": false, "version": 0, "errors": errors, "encounters": {}}

	var version := int(manifest.get("version", 0))
	var encounter_paths: Array = manifest.get("encounters", [])
	var encounters: Dictionary = {}
	var seen_ids: Dictionary = {}

	for raw_path in encounter_paths:
		var encounter_path := String(raw_path)
		if not FileAccess.file_exists(encounter_path):
			errors.append("missing_file: %s" % encounter_path)
			continue
		var raw_encounter := _read_json_dict(encounter_path)
		if raw_encounter.is_empty():
			errors.append("invalid_json: %s is not valid JSON" % encounter_path)
			continue

		var result := _normalize_and_validate_encounter(raw_encounter)
		var encounter_errors: Array[String] = result.errors
		if not encounter_errors.is_empty():
			for detail in encounter_errors:
				errors.append("%s (%s)" % [detail, encounter_path])
			continue

		var definition: Dictionary = result.definition
		var id: String = definition.id
		if seen_ids.has(id):
			errors.append("duplicate_id: %s is declared by both %s and %s" % [id, seen_ids[id], encounter_path])
			continue
		seen_ids[id] = encounter_path
		encounters[id] = definition

	errors.append_array(_validate_no_circular_prerequisites(encounters))

	return {"valid": errors.is_empty(), "version": version, "errors": errors, "encounters": encounters}


## Convenience accessor: the single normalized definition for `encounter_id`,
## or {} if the catalog has none for it (whether because no encounter file
## declares that id, or because the one that does failed validation -- see
## load_catalog()'s own doc comment). WorldMap/BattleController/CampaignSim
## all read encounter geometry (spawns/cover/grid_size) through this.
static func get_encounter_definition(encounter_id: String, catalog_path: String = DEFAULT_CATALOG_PATH) -> Dictionary:
	var catalog := load_catalog(catalog_path)
	return (catalog.encounters as Dictionary).get(encounter_id, {})


## --- JSON I/O ---------------------------------------------------------

static func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## --- Per-encounter normalization + validation --------------------------

static func _normalize_and_validate_encounter(raw: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var id := String(raw.get("id", ""))
	if id.is_empty():
		errors.append("invalid_id: encounter is missing a non-empty \"id\"")

	var raw_grid_size: Dictionary = raw.get("grid_size", {}) if typeof(raw.get("grid_size", {})) == TYPE_DICTIONARY else {}
	var grid_size := {
		"width": int(raw_grid_size.get("width", 0)),
		"height": int(raw_grid_size.get("height", 0)),
	}
	if grid_size.width <= 0 or grid_size.height <= 0:
		errors.append("invalid_grid_size: %s must declare a positive grid_size.width/height" % id)

	var world_position := _parse_and_validate_position(
		raw.get("world_position", {}), errors, id, "world_position", WORLD_MAP_WIDTH, WORLD_MAP_HEIGHT
	)

	var player_spawns := _parse_and_validate_position_list(
		_as_array(raw.get("player_spawns", [])), errors, id, "player_spawns", grid_size.width, grid_size.height
	)
	var enemy_spawns := _parse_and_validate_position_list(
		_as_array(raw.get("enemy_spawns", [])), errors, id, "enemy_spawns", grid_size.width, grid_size.height
	)
	errors.append_array(_validate_no_duplicate_positions(player_spawns, "player_spawns", id))
	errors.append_array(_validate_no_duplicate_positions(enemy_spawns, "enemy_spawns", id))
	errors.append_array(_validate_no_shared_positions(player_spawns, enemy_spawns, "player_spawns/enemy_spawns", id))

	var cover_tiles := _parse_and_validate_cover_tiles(
		_as_array(raw.get("cover_tiles", [])), errors, id, grid_size.width, grid_size.height
	)
	var all_spawns: Array[Vector2i] = []
	all_spawns.append_array(player_spawns)
	all_spawns.append_array(enemy_spawns)
	for cover_pos in cover_tiles:
		if all_spawns.has(cover_pos):
			errors.append("overlapping_cover_and_spawn: %s has a cover tile at %s that coincides with a spawn tile" % [id, cover_pos])

	var enemy_composition := _parse_and_validate_enemy_composition(_as_array(raw.get("enemy_composition", [])), errors, id)

	var clear_xp := int(raw.get("clear_xp", 0))
	if clear_xp < 0:
		errors.append("invalid_clear_xp: %s clear_xp must not be negative" % id)

	var reward_bonus_multiplier := float(raw.get("reward_bonus_multiplier", 1.0))
	if reward_bonus_multiplier <= 0.0:
		errors.append("invalid_reward_bonus_multiplier: %s reward_bonus_multiplier must be positive" % id)

	var definition := {
		"id": id,
		"name_key": String(raw.get("name_key", "")),
		"tier": int(raw.get("tier", 0)),
		"category": String(raw.get("category", "")),
		"world_position": world_position,
		"grid_size": grid_size,
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
		"cover_tiles": cover_tiles,
		"enemy_composition": enemy_composition,
		"clear_xp": clear_xp,
		"reward_bonus_multiplier": reward_bonus_multiplier,
		"prerequisite_objective_id": String(raw.get("prerequisite_objective_id", "")),
	}
	return {"definition": definition, "errors": errors}


## Defensively coerces a raw JSON value that is supposed to be a list into an
## actual Array, so a malformed encounter file (e.g. a string where an array
## was expected) is rejected by field-level validation below instead of
## crashing this loader outright -- mirrors ScenarioContract.normalize()'s
## own "never fails, structurally-invalid input normalizes cleanly" contract.
static func _as_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


## Godot's JSON parser always hands numeric JSON values back as float (never
## int -- verified directly: JSON.new().parse('{"x": 3}') yields a
## TYPE_FLOAT, not TYPE_INT), so "integer coordinate" cannot be a typeof()
## check. A JSON number is accepted here iff it carries zero fractional part
## ("3" and "3.0" both pass; "3.5" is rejected) -- this is what the task's
## own "non-integer... coordinates" rejection case means in practice.
static func _is_integer_coordinate(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return value == floor(value)
	return false


static func _parse_and_validate_position(
	raw_position, errors: Array[String], id: String, field: String, width: int, height: int
) -> Vector2i:
	if typeof(raw_position) != TYPE_DICTIONARY:
		errors.append("invalid_coordinate: %s.%s must be an {x,y} object" % [id, field])
		return Vector2i.ZERO
	var x = raw_position.get("x")
	var y = raw_position.get("y")
	if not _is_integer_coordinate(x) or not _is_integer_coordinate(y):
		errors.append("invalid_coordinate: %s.%s must have integer x/y" % [id, field])
		return Vector2i.ZERO
	if x < 0 or x >= width or y < 0 or y >= height:
		errors.append("out_of_bounds: %s.%s (%s, %s) is outside the %dx%d grid" % [id, field, x, y, width, height])
		return Vector2i(int(x), int(y))
	return Vector2i(int(x), int(y))


static func _parse_and_validate_position_list(
	raw_list: Array, errors: Array[String], id: String, field: String, width: int, height: int
) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for raw_position in raw_list:
		positions.append(_parse_and_validate_position(raw_position, errors, id, field, width, height))
	return positions


static func _validate_no_duplicate_positions(positions: Array[Vector2i], field: String, id: String) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for position in positions:
		if seen.has(position):
			errors.append("duplicate_spawn_point: %s.%s has %s more than once" % [id, field, position])
		seen[position] = true
	return errors


static func _validate_no_shared_positions(a: Array[Vector2i], b: Array[Vector2i], field: String, id: String) -> Array[String]:
	var errors: Array[String] = []
	for position in a:
		if b.has(position):
			errors.append("duplicate_spawn_point: %s.%s share tile %s" % [id, field, position])
	return errors


static func _parse_and_validate_cover_tiles(
	raw_list: Array, errors: Array[String], id: String, width: int, height: int
) -> Dictionary:
	var cover_tiles: Dictionary = {}
	for raw_entry in raw_list:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			errors.append("invalid_coordinate: %s.cover_tiles must be {x,y,tier} objects" % id)
			continue
		var position := _parse_and_validate_position(raw_entry, errors, id, "cover_tiles", width, height)
		var tier := String(raw_entry.get("tier", ""))
		if not COVER_TIERS.has(tier):
			errors.append("invalid_cover_tier: %s.cover_tiles at %s has unknown tier \"%s\"" % [id, position, tier])
			continue
		if cover_tiles.has(position):
			errors.append("duplicate_cover_tile: %s.cover_tiles has %s more than once" % [id, position])
			continue
		cover_tiles[position] = tier
	return cover_tiles


static func _parse_and_validate_enemy_composition(raw_list: Array, errors: Array[String], id: String) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	for raw_entry in raw_list:
		var entry: Dictionary = raw_entry if typeof(raw_entry) == TYPE_DICTIONARY else {}
		var template_id := String(entry.get("template_id", ""))
		var count := int(entry.get("count", 0))
		if template_id.is_empty() or not KNOWN_ENEMY_TEMPLATE_IDS.has(template_id):
			errors.append("unknown_enemy_template: %s.enemy_composition references unknown template_id \"%s\"" % [id, template_id])
			continue
		if count <= 0:
			errors.append("invalid_enemy_count: %s.enemy_composition's %s count must be positive" % [id, template_id])
			continue
		composition.append({"template_id": template_id, "count": count})
	return composition


## Walks each encounter's prerequisite_objective_id chain (limited to ids
## also present in `encounters`, since a prerequisite may legitimately name
## a not-yet-migrated legacy campaign-objective id outside this catalog) and
## reports any cycle. Only meaningful once more than one encounter shares
## prerequisite links; a lone encounter (Step 3's own scope) can never cycle
## with itself unless it names its own id, which this also catches.
static func _validate_no_circular_prerequisites(encounters: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for start_id in encounters.keys():
		var visited: Array[String] = []
		var current_id: String = start_id
		while encounters.has(current_id):
			var prerequisite_id: String = String(encounters[current_id].prerequisite_objective_id)
			if prerequisite_id.is_empty():
				break
			if visited.has(prerequisite_id) or prerequisite_id == start_id:
				errors.append("circular_prerequisite: %s's prerequisite chain revisits %s" % [start_id, prerequisite_id])
				break
			visited.append(current_id)
			current_id = prerequisite_id
	return errors
