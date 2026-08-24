class_name ScenarioContract
extends RefCounted
## Declarative, versioned single-battle scenario contract (see
## docs/plans/2026-08-10-initial-campaign-and-automation/
## 05-battle-scenario-contract.md and the governing design's "Scenario
## contract" section). Every function here is pure data transformation:
## normalize()/validate() take and return plain, JSON-safe Dictionaries and
## never read or write GameSession.adventurers, GameSession.selected_
## encounter, GameConfig, or any other mutable global/campaign state. They
## only ever read GameSession's balance *constants* (WEAPONS, ARMORS, BASE_*,
## the enemy *_STATS consts) as the default baseline that a scenario's
## explicit `modifiers` layer on top of -- see the design's "Modifiers are
## explicit test inputs, never hidden mutations of global balance
## configuration. The normal game configuration remains the default
## baseline."
##
## Matrix expansion (a raw scenario's optional top-level `matrix` field) is
## NOT this file's job -- see scenario_expander.gd, which expands a matrix
## into many single-case raw Dictionaries and then calls normalize()/
## validate() on each one exactly the way a hand-authored single scenario
## would be processed.
##
## Battle construction from a normalized, validated scenario is also NOT
## this file's job -- see battle_state_factory.gd.

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")

const CONTRACT_VERSION := 1

# Mirror BattleController's own board/capacity constants rather than
# preload-referencing them in a const initializer (GDScript const
# expressions cannot call methods like Array.size() across script
# boundaries at parse time). Kept honest by the guard-rail tests in
# tests/unit/test_scenario_contract.gd, the same pattern
# test_battle_controller.gd already uses for PLAYER_START_POSITIONS/
# ENEMY_START_POSITIONS.
const DEFAULT_BOARD_WIDTH := 6
const DEFAULT_BOARD_HEIGHT := 6
const MAX_PLAYER_UNITS := 5
const MAX_ENEMY_UNITS := 8

const DEFAULT_ROUND_LIMIT := 30
const DEFAULT_VICTORY_CONDITION := "elimination"
const KNOWN_VICTORY_CONDITIONS: Array[String] = ["elimination"]

# The design's "first supplied policies" (see the governing design doc's
# "Policy contract" section). Real Policy implementations land in Step 6;
# this file only needs to know their names exist so validate() can reject a
# typo or a not-yet-implemented policy before construction.
const KNOWN_POLICIES: Array[String] = ["greedy_pursuit", "current_enemy_policy"]
const DEFAULT_PLAYER_POLICY := "greedy_pursuit"
const DEFAULT_ENEMY_POLICY := "current_enemy_policy"

# The three player archetypes the game currently ships (see GameSession.
# CLASS_DEFINITIONS -- warrior, scout, cleric). Enemy templates mirror
# GameSession's named *_ENEMY_STATS consts (see battle_state_factory.gd's
# read-only helpers, which resolve these same names to live stat data).
const KNOWN_PLAYER_TEMPLATES: Array[String] = ["warrior", "scout", "cleric", "mage"]
# The four original species plus the authored-ladder additions (see
# GameSession's *_ENEMY_STATS consts and docs/plans/2026-08-18-core-loop-
# and-engagement/05-authored-encounters-and-final-boss.md) -- every name here
# must resolve in BattleStateFactory._read_enemy_template_stats(). Sourced
# directly from ContentCatalog.KNOWN_ENEMY_TEMPLATE_IDS (Stage 6 Step 3,
# docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
# 03-authored-content-catalog.md's "validate enemy templates ... against
# ContentCatalog" requirement) rather than a hand-kept duplicate list, so a
# scenario-tooling template id and a catalog encounter's own
# enemy_composition.template_id vocabulary can never silently drift apart.
const KNOWN_ENEMY_TEMPLATES: Array[String] = ContentCatalogScript.KNOWN_ENEMY_TEMPLATE_IDS

# JSON-safe facing values a unit record may declare (see _normalize_side()'s
# per-side default and facing_from_string(), which BattleStateFactory uses to
# hydrate the real Unit.facing Vector2i).
const KNOWN_FACINGS: Array[String] = ["right", "left", "up", "down"]

## Cover terrain (Stage 5 D2, decision-ledger.md's "Terrain representation/
## distribution" row): hand-authored per encounter, exactly like `blocked`
## above -- see grid.gd's own cover_tiles doc comment for why no procedural
## distribution exists anywhere in this pipeline.
const KNOWN_COVER_TIERS: Array[String] = ["low", "high"]

# Every modifier key BattleStateFactory._build_player_unit()/_build_enemy_
# unit() actually reads (docs/plans/2026-08-21-stage-2-party-readiness/
# 05-shared-tactical-profile-migration.md), covering both the shared
# tactical profile vocabulary (docs/designs/class-system.md's "Shared
# tactical attributes" section) and each side's own legacy aliases -- a
# player's "attack" (melee/missile shorthand) and an enemy's "defense"
# (Guard shorthand, see GameSession.get_enemy_profile_guard()'s own doc
# comment) and "hit_chance" (a direct delta on top of a legacy enemy
# template's resolved accuracy). Kept as two side-specific sets (not one
# shared list) because "attack"/"hit_chance" only ever mean something on
# their own side -- see _validate_side()'s own per-side known_templates
# parameter for the same pattern.
const KNOWN_PLAYER_MODIFIER_KEYS: Array[String] = [
	"max_health", "melee", "missile", "guard", "might", "spellcasting", "magic_resistance",
	"attack", "damage_min", "damage_max", "defense", "resistance", "action_points",
]
const KNOWN_ENEMY_MODIFIER_KEYS: Array[String] = [
	"max_health", "melee", "missile", "guard", "might", "spellcasting", "magic_resistance",
	"hit_chance", "damage_min", "damage_max", "defense", "resistance", "action_points",
]


## Fills every optional field with its documented default and expands each
## side's count/template_id shorthand into an explicit, positioned unit
## list. Never mutates `raw`; never fails -- structurally-invalid input
## (unknown templates, out-of-bounds positions, etc.) normalizes cleanly and
## is instead rejected by validate(). Idempotent: normalize(normalize(x))
## == normalize(x).
static func normalize(raw: Dictionary) -> Dictionary:
	var scenario := {}
	scenario["contract_version"] = int(raw.get("contract_version", CONTRACT_VERSION))
	scenario["scenario_id"] = String(raw.get("scenario_id", ""))

	var board: Dictionary = raw.get("board", {})
	var blocked: Array = board.get("blocked", [])
	var cover: Array = board.get("cover", [])
	var normalized_cover: Array = []
	for raw_cover_entry in cover:
		var cover_entry: Dictionary = raw_cover_entry if raw_cover_entry is Dictionary else {}
		normalized_cover.append({
			"position": (
				cover_entry.position.duplicate(true) if cover_entry.get("position", {}) is Dictionary
				else position_to_dict(position_from_dict(cover_entry.get("position", {})))
			),
			"tier": String(cover_entry.get("tier", "")),
		})
	scenario["board"] = {
		"width": int(board.get("width", DEFAULT_BOARD_WIDTH)),
		"height": int(board.get("height", DEFAULT_BOARD_HEIGHT)),
		"blocked": blocked.duplicate(true),
		"cover": normalized_cover,
	}

	scenario["player"] = _normalize_side(raw.get("player", {}), "player")
	scenario["enemy"] = _normalize_side(raw.get("enemy", {}), "enemy")

	var rules: Dictionary = raw.get("rules", {})
	scenario["rules"] = {
		"round_limit": int(rules.get("round_limit", DEFAULT_ROUND_LIMIT)),
		"victory_condition": String(rules.get("victory_condition", DEFAULT_VICTORY_CONDITION)),
	}

	var policies: Dictionary = raw.get("policies", {})
	var config: Dictionary = policies.get("config", {})
	scenario["policies"] = {
		"player": String(policies.get("player", DEFAULT_PLAYER_POLICY)),
		"enemy": String(policies.get("enemy", DEFAULT_ENEMY_POLICY)),
		"config": config.duplicate(true),
	}

	var randomness: Dictionary = raw.get("randomness", {})
	scenario["randomness"] = {
		"root_seed": int(randomness.get("root_seed", 0)),
		"iterations": int(randomness.get("iterations", 1)),
	}

	var labels: Array = raw.get("labels", [])
	scenario["labels"] = labels.duplicate()

	return scenario


## Returns every pre-construction problem found in an already-normalized
## `scenario` (see normalize()), as a list of "<category>: <detail>"
## strings. Empty means the scenario is safe to hand to
## BattleStateFactory.build(). Never partially valid: every check runs and
## every failure is reported, so a caller sees every problem at once rather
## than fixing them one at a time.
static func validate(scenario: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if int(scenario.get("contract_version", -1)) != CONTRACT_VERSION:
		errors.append("unsupported_version: contract_version %s is not %d" % [scenario.get("contract_version"), CONTRACT_VERSION])
	if String(scenario.get("scenario_id", "")).is_empty():
		errors.append("invalid_limit: scenario_id must not be empty")

	var board: Dictionary = scenario.get("board", {})
	errors.append_array(_validate_board(board))

	var player_units: Array = scenario.get("player", {}).get("units", [])
	var enemy_units: Array = scenario.get("enemy", {}).get("units", [])
	errors.append_array(_validate_side(player_units, "player", board, MAX_PLAYER_UNITS, KNOWN_PLAYER_TEMPLATES))
	errors.append_array(_validate_side(enemy_units, "enemy", board, MAX_ENEMY_UNITS, KNOWN_ENEMY_TEMPLATES))
	errors.append_array(_validate_no_duplicate_ids(player_units, enemy_units))
	errors.append_array(_validate_no_position_overlap(player_units, enemy_units, board))

	errors.append_array(_validate_rules(scenario.get("rules", {})))
	errors.append_array(_validate_policies(scenario.get("policies", {})))
	errors.append_array(_validate_randomness(scenario.get("randomness", {})))

	return errors


## Derives a stable per-iteration seed from the case's root seed, its stable
## case id, and the iteration index -- never pulled from global randomness
## (see the design's "Randomness" contract field). Pure and deterministic
## for a fixed engine version: identical inputs always produce the identical
## output, which is what lets a recorded iteration seed reproduce its run.
static func derive_iteration_seed(root_seed: int, case_id: String, iteration_index: int) -> int:
	return hash("%d|%s|%d" % [root_seed, case_id, iteration_index])


## Converts a board-relative grid position to its JSON-safe Dictionary form.
static func position_to_dict(pos: Vector2i) -> Dictionary:
	return {"x": pos.x, "y": pos.y}


## Reads a JSON-safe position back into a Vector2i. Accepts either the
## {"x":,"y":} shape position_to_dict() produces or a two-element [x, y]
## array, so hand-authored scenario JSON can use whichever is more readable.
static func position_from_dict(raw) -> Vector2i:
	if raw is Dictionary:
		return Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO


## Reads a normalized unit's JSON-safe "facing" string (see KNOWN_FACINGS)
## back into the Vector2i Unit.facing expects. An unrecognized value falls
## back to RIGHT -- validate() is what actually rejects one before
## construction, so this is never reached with anything outside
## KNOWN_FACINGS on a validated scenario.
static func facing_from_string(value: String) -> Vector2i:
	match value:
		"left":
			return Vector2i.LEFT
		"up":
			return Vector2i.UP
		"down":
			return Vector2i.DOWN
		_:
			return Vector2i.RIGHT


static func _normalize_side(raw_side: Dictionary, side_label: String) -> Dictionary:
	var default_positions: Array = (
		BattleControllerScript.PLAYER_START_POSITIONS if side_label == "player" else BattleControllerScript.ENEMY_START_POSITIONS
	)
	var default_template: String = "warrior" if side_label == "player" else "goblin"
	# Mirrors BattleController._ready()'s own production side defaults (player
	# RIGHT, enemy LEFT -- see battle_controller.gd's explicit post-construction
	# assignment), kept as a JSON-safe string here since this contract never
	# touches Vector2i (see facing_from_string(), which BattleStateFactory uses
	# to hydrate the real Unit.facing value).
	var default_facing: String = "right" if side_label == "player" else "left"

	var raw_units: Array = raw_side.get("units", [])
	if raw_units.is_empty() and raw_side.has("template_id"):
		raw_units = []
		var count: int = int(raw_side.get("count", 1))
		for _index in count:
			var generated := {"template_id": raw_side.get("template_id")}
			for key in ["weapon_id", "armor_id", "level", "modifiers"]:
				if raw_side.has(key):
					generated[key] = raw_side[key]
			raw_units.append(generated)

	var units: Array[Dictionary] = []
	for index in raw_units.size():
		var raw_unit: Dictionary = raw_units[index]
		var unit := {}
		unit["id"] = String(raw_unit.get("id", "%s_%d" % [side_label, index + 1]))
		unit["template_id"] = String(raw_unit.get("template_id", default_template))
		if side_label == "player":
			unit["weapon_id"] = String(raw_unit.get("weapon_id", GameSession.DEFAULT_WEAPON_ID))
			unit["armor_id"] = String(raw_unit.get("armor_id", GameSession.DEFAULT_ARMOR_ID))
			unit["level"] = int(raw_unit.get("level", 1))
			# Explicit optional MP field (see the governing design's own note
			# that deterministic scenarios must never rely on ambient
			# GameSession session state): -1 means "not specified" -- a
			# spellcasting template (Cleric today) then hydrates at full MP,
			# same as it always has -- see BattleStateFactory._build_player_
			# unit(). Meaningless for a non-spellcasting template, but still
			# normalized/validated uniformly rather than special-cased per
			# template_id.
			unit["mp_current"] = int(raw_unit.get("mp_current", -1))
			# Explicit optional perks field (docs/plans/2026-08-21-stage-2-
			# party-readiness/ final-review fix wave's Fix 1): mirrors mp_
			# current's own precedent above -- a deterministic scenario must
			# never rely on ambient GameSession.get_adventurer(...).progression.
			# perks state, so a scenario-built unit only ever gets Juggernaut/
			# Bulwark/Quickdraw/Devout's mechanical effect when this field
			# names them explicitly. Defaults to [] (no perks), same as a
			# fresh adventurer's own progression.perks. See battle_state_
			# factory.gd's _build_player_unit() for where this is consumed.
			var raw_perks: Array = raw_unit.get("perks", [])
			unit["perks"] = raw_perks.duplicate(true)
			# Explicit optional specialization field (Stage 5 D4, mirrors perks'
			# own precedent immediately above): a deterministic scenario must
			# never rely on ambient GameSession adventurer.specialization state
			# either. Defaults to "" (not promoted). Only meaningful together
			# with a "perks" entry naming one of that specialization's own
			# SPECIALIZATION_PERKS ids -- see _validate_side()'s perk-ownership
			# check just below, which is what actually gives it mechanical
			# effect (a Knight's Shield Bash/Chain Blow perks only validate,
			# and therefore only mechanically apply, when this field names
			# "knight").
			unit["specialization"] = String(raw_unit.get("specialization", ""))
		var default_position: Vector2i = (
			default_positions[index] if index < default_positions.size() else Vector2i(-1, -1)
		)
		var raw_position = raw_unit.get("position", position_to_dict(default_position))
		unit["position"] = (
			raw_position.duplicate(true) if raw_position is Dictionary else position_to_dict(position_from_dict(raw_position))
		)
		var modifiers: Dictionary = raw_unit.get("modifiers", {})
		unit["modifiers"] = modifiers.duplicate(true)
		unit["facing"] = String(raw_unit.get("facing", default_facing))
		units.append(unit)

	return {"units": units}


static func _validate_board(board: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var width := int(board.get("width", 0))
	var height := int(board.get("height", 0))
	if width <= 0 or height <= 0:
		errors.append("invalid_limit: board width/height must be positive (got %dx%d)" % [width, height])
		return errors
	for raw_blocked in board.get("blocked", []):
		var pos := position_from_dict(raw_blocked)
		if not _in_bounds(pos, width, height):
			errors.append("out_of_bounds: blocked tile %s is outside the %dx%d board" % [pos, width, height])
	for cover_entry in board.get("cover", []):
		var cover_pos := position_from_dict(cover_entry.get("position", {}))
		if not _in_bounds(cover_pos, width, height):
			errors.append("out_of_bounds: cover tile %s is outside the %dx%d board" % [cover_pos, width, height])
		var tier: String = String(cover_entry.get("tier", ""))
		if not tier in KNOWN_COVER_TIERS:
			errors.append("invalid_cover_tier: cover tile %s has unknown tier \"%s\"" % [cover_pos, tier])
	return errors


static func _validate_side(
	units: Array, side_label: String, board: Dictionary, max_units: int, known_templates: Array
) -> Array[String]:
	var errors: Array[String] = []
	if units.is_empty():
		errors.append("invalid_limit: %s side must field at least one unit" % side_label)
	if units.size() > max_units:
		errors.append(
			"unsupported_count: %s side fields %d units but only %d start positions are supported"
			% [side_label, units.size(), max_units]
		)

	var width := int(board.get("width", 0))
	var height := int(board.get("height", 0))
	for unit in units:
		var unit_id: String = String(unit.get("id", "?"))
		var template_id: String = String(unit.get("template_id", ""))
		if not template_id in known_templates:
			errors.append("unknown_template: %s unit %s has unknown template_id \"%s\"" % [side_label, unit_id, template_id])

		if side_label == "player":
			var weapon_id: String = String(unit.get("weapon_id", ""))
			if not GameSession.WEAPONS.has(weapon_id):
				errors.append("unknown_template: %s unit %s has unknown weapon_id \"%s\"" % [side_label, unit_id, weapon_id])
			var armor_id: String = String(unit.get("armor_id", ""))
			if not GameSession.ARMORS.has(armor_id):
				errors.append("unknown_template: %s unit %s has unknown armor_id \"%s\"" % [side_label, unit_id, armor_id])
			var level: int = int(unit.get("level", 1))
			if level < 1:
				errors.append("invalid_limit: %s unit %s has non-positive level %d" % [side_label, unit_id, level])

			var mp_current: int = int(unit.get("mp_current", -1))
			if mp_current != -1:
				var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(template_id, {})
				var class_mp_max := int(class_def.get("mp_max", 0))
				if mp_current < 0 or mp_current > class_mp_max:
					errors.append(
						"invalid_limit: %s unit %s has out-of-range mp_current %d (class mp_max %d)"
						% [side_label, unit_id, mp_current, class_mp_max]
					)

			# Each named perk must be a real id belonging to this unit's own
			# template_id's class (GameSession.CLASS_PERKS), OR -- once
			# promoted, Stage 5 D4 -- its own "specialization" field's
			# SPECIALIZATION_PERKS (e.g. Knight's Shield Bash/Chain Blow).
			# Mirrors choose_perk()'s own class/specialization-gating so an
			# authoring typo or a perk from the wrong class/specialization
			# fails fast at validate() time instead of silently having zero
			# effect in BattleStateFactory._build_player_unit().
			var specialization_id := String(unit.get("specialization", ""))
			if not specialization_id.is_empty() and not GameSession.SPECIALIZATION_ROOT_CLASS.has(specialization_id):
				errors.append(
					"unknown_specialization: %s unit %s has unknown specialization \"%s\""
					% [side_label, unit_id, specialization_id]
				)
			elif not specialization_id.is_empty() and GameSession.SPECIALIZATION_ROOT_CLASS[specialization_id] != template_id:
				errors.append(
					"unknown_specialization: %s unit %s has specialization \"%s\" which requires root class \"%s\", not \"%s\""
					% [side_label, unit_id, specialization_id, GameSession.SPECIALIZATION_ROOT_CLASS[specialization_id], template_id]
				)
			var class_perks: Array = (GameSession.CLASS_PERKS.get(template_id, []) as Array).duplicate()
			if not specialization_id.is_empty():
				class_perks.append_array(GameSession.SPECIALIZATION_PERKS.get(specialization_id, []))
			for perk_id in unit.get("perks", []):
				if not class_perks.has(String(perk_id)):
					errors.append(
						"unknown_perk: %s unit %s has perk \"%s\" not owned by class \"%s\""
						% [side_label, unit_id, perk_id, template_id]
					)

		var pos := position_from_dict(unit.get("position", {}))
		if not _in_bounds(pos, width, height):
			errors.append(
				"out_of_bounds: %s unit %s position %s is outside the %dx%d board" % [side_label, unit_id, pos, width, height]
			)

		var facing: String = String(unit.get("facing", ""))
		if not facing in KNOWN_FACINGS:
			errors.append("invalid_facing: %s unit %s has unknown facing \"%s\"" % [side_label, unit_id, facing])

		var known_modifier_keys: Array[String] = (
			KNOWN_PLAYER_MODIFIER_KEYS if side_label == "player" else KNOWN_ENEMY_MODIFIER_KEYS
		)
		errors.append_array(_validate_modifiers(unit.get("modifiers", {}), side_label, unit_id, known_modifier_keys))
	return errors


## Rejects a unit's `modifiers` dict if it names an unrecognized profile
## field, or gives a recognized one a non-numeric value (e.g. a String or
## bool) -- BattleStateFactory always folds these values into `int(...)`/
## `float(...)` arithmetic (see _build_player_unit()/_build_enemy_unit()),
## so a malformed modifier would otherwise silently coerce (a String costs
## 0, a bool becomes 0/1) instead of failing fast here at validate() time.
static func _validate_modifiers(
	modifiers: Dictionary, side_label: String, unit_id: String, known_keys: Array[String]
) -> Array[String]:
	var errors: Array[String] = []
	for key in modifiers:
		var value = modifiers[key]
		if not String(key) in known_keys:
			errors.append("unknown_modifier: %s unit %s has unknown modifier \"%s\"" % [side_label, unit_id, key])
		elif not (value is int or value is float):
			errors.append(
				"invalid_modifier_type: %s unit %s modifier \"%s\" must be numeric, got %s"
				% [side_label, unit_id, key, typeof(value)]
			)
	return errors


static func _validate_no_duplicate_ids(player_units: Array, enemy_units: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for unit in player_units + enemy_units:
		var unit_id: String = String(unit.get("id", ""))
		if seen.has(unit_id):
			errors.append("duplicate_id: unit id \"%s\" is used more than once" % unit_id)
		seen[unit_id] = true
	return errors


static func _validate_no_position_overlap(player_units: Array, enemy_units: Array, board: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var blocked := {}
	for raw_blocked in board.get("blocked", []):
		blocked[position_from_dict(raw_blocked)] = true

	var occupied := {}
	for unit in player_units + enemy_units:
		var unit_id: String = String(unit.get("id", "?"))
		var pos := position_from_dict(unit.get("position", {}))
		if occupied.has(pos):
			errors.append("position_overlap: unit \"%s\" and unit \"%s\" both occupy %s" % [occupied[pos], unit_id, pos])
		elif blocked.has(pos):
			errors.append("position_overlap: unit \"%s\" occupies blocked tile %s" % [unit_id, pos])
		occupied[pos] = unit_id
	return errors


static func _validate_rules(rules: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var round_limit := int(rules.get("round_limit", 0))
	if round_limit <= 0:
		errors.append("invalid_limit: rules.round_limit must be positive (got %d)" % round_limit)
	var victory_condition: String = String(rules.get("victory_condition", ""))
	if not victory_condition in KNOWN_VICTORY_CONDITIONS:
		errors.append("unsupported_rule: unknown victory_condition \"%s\"" % victory_condition)
	return errors


static func _validate_policies(policies: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var player_policy: String = String(policies.get("player", ""))
	if not player_policy in KNOWN_POLICIES:
		errors.append("unknown_policy: player policy \"%s\" is not registered" % player_policy)
	var enemy_policy: String = String(policies.get("enemy", ""))
	if not enemy_policy in KNOWN_POLICIES:
		errors.append("unknown_policy: enemy policy \"%s\" is not registered" % enemy_policy)
	return errors


static func _validate_randomness(randomness: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var iterations := int(randomness.get("iterations", 0))
	if iterations <= 0:
		errors.append("invalid_limit: randomness.iterations must be positive (got %d)" % iterations)
	return errors


static func _in_bounds(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height
