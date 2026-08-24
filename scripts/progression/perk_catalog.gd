class_name PerkCatalog
extends RefCounted

## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 04-branching-perk-definitions.md): the single authored source of every
## class/specialization's `PerkDefinition` entries (decision-ledger.md's
## "PerkDefinition" contract), replacing GameSession's hand-duplicated flat
## `CLASS_PERKS`/`SPECIALIZATION_PERKS`/`PERK_DEFINITIONS` arrays. Every
## function here is pure/static: it takes an adventurer-shaped Dictionary (or
## a chosen-perk-id list) and the catalog data, and never reads or writes
## GameSession's mutable session state -- the same "pure domain function"
## convention GameSession.compute_effective_max_health()/compute_effective_
## defense() already established for perk-driven math.
##
## Per G3 (decision-ledger.md): only Knight's "knight_shield_bash"/
## "knight_chain_blow" carry a real prerequisite/mutual-exclusion
## relationship in Stage 6 -- gated behind the new "knight_discipline" tier-1
## node this step adds (a purely structural gate; no new numeric balance
## value is invented for it, per the ledger's own gate rule). Every other
## class/specialization's perks migrate with empty `prerequisite_ids`/
## `mutually_exclusive_with`, so get_available_perks()/can_choose_perk() are
## behaviorally identical to the old flat-array lookup for them.

## Root class ids and specialization ids a PerkDefinition's own `class_id`
## may legally name (GameSession.CLASS_DEFINITIONS' root ids plus GameSession.
## SPECIALIZATION_ROOT_CLASS' specialization ids) -- used only by
## validate_definitions()'s "invalid class id" check. "legacy" is a deliberate
## addition: it is never a real adventurer's `class`/`specialization` field
## (see BONUS_MOVE_PERK_ID's own entry below), so it can never be offered by
## get_available_perks(), but it keeps the retired-but-still-effective Bonus
## Move perk a valid catalog entry for PerkEffectResolver to still apply.
const KNOWN_SCOPES: Array[String] = [
	"warrior", "scout", "cleric", "mage",
	"knight", "archer", "battle_mage", "paladin",
	"legacy",
]

## effect_descriptor.type values PerkEffectResolver knows how to interpret.
## "none" is a purely structural gate node with no mechanical effect of its
## own (Knight's new "knight_discipline" tier-1 root).
const KNOWN_EFFECT_TYPES: Array[String] = ["stat_modifier", "granted_action", "action_modifier", "none"]

## The legacy universal perk id (GameSession.BONUS_MOVE_PERK_ID's own value,
## duplicated here as a plain string constant rather than a cross-reference
## to the GameSession autoload -- see this file's own doc comment on why
## every function here stays a pure function of its own inputs, never the
## live GameSession singleton). Retired from new choices (see GameSession.
## choose_perk()'s doc comment) but never migrated away from an existing
## holder, so it still needs a catalog entry for PerkEffectResolver's AP-bonus
## math -- see get_definitions()' own "legacy" entry below.
const BONUS_MOVE_PERK_ID := "bonus_move"


## Builds and returns the full id -> PerkDefinition catalog, keyed exactly
## per decision-ledger.md's `PerkDefinition` schema. Numeric magnitudes are
## read straight from GameConfig (never a live GameSession var) -- the same
## "every call site independently reads the same GameConfig key" convention
## GameSession's own ARCHER_LOCK_ON_HIT_CHANCE_BONUS doc comment already
## documents for BattleController, extended here to a third independent
## reader. Rebuilt fresh on every call (cheap: a dozen small Dictionaries) --
## deliberately not memoized, so a GameConfig hot-reload is always reflected
## rather than needing an explicit cache-invalidation call no other reader of
## this file has to remember.
static func get_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	for definition in _build_definitions():
		definitions[String(definition.id)] = definition
	return definitions


static func _build_definitions() -> Array[Dictionary]:
	var config := GameConfig
	return [
		_definition(
			"warrior_juggernaut", "warrior", 1, [], [],
			"perk.warrior_juggernaut.name", "perk.warrior_juggernaut.effect",
			{
				"type": "stat_modifier", "stat": "max_health",
				"percent_bonus": config.get_int("progression", "warrior_juggernaut_hp_percent", 15),
			}
		),
		_definition(
			"warrior_bulwark", "warrior", 1, [], [],
			"perk.warrior_bulwark.name", "perk.warrior_bulwark.effect",
			{"type": "stat_modifier", "stat": "defense", "flat_bonus": config.get_int("progression", "warrior_bulwark_guard", 10)}
		),
		_definition(
			"scout_quickdraw", "scout", 1, [], [],
			"perk.scout_quickdraw.name", "perk.scout_quickdraw.effect",
			{
				"type": "stat_modifier", "stat": "action_points",
				"flat_bonus": config.get_int("progression", "scout_quickdraw_action_points", 1),
			}
		),
		_definition(
			"scout_keen_eyes", "scout", 1, [], [],
			"perk.scout_keen_eyes.name", "perk.scout_keen_eyes.effect",
			{
				"type": "stat_modifier", "stat": "scout_intel_range",
				"flat_bonus": config.get_int("progression", "scout_keen_eyes_intel_range_bonus", 1),
			}
		),
		_definition(
			"cleric_meditation", "cleric", 1, [], [],
			"perk.cleric_meditation.name", "perk.cleric_meditation.effect",
			{
				"type": "stat_modifier", "stat": "spell_range",
				"flat_bonus": config.get_int("progression", "cleric_meditation_spell_range_bonus", 1),
			}
		),
		_definition(
			"cleric_devout", "cleric", 1, [], [],
			"perk.cleric_devout.name", "perk.cleric_devout.effect",
			{
				"type": "stat_modifier", "stat": "max_health",
				"percent_bonus": config.get_int("progression", "cleric_devout_hp_percent", 10),
			}
		),
		# --- Knight (G3's first branching pair) ---------------------------
		# A purely structural tier-1 gate: no numeric effect of its own (per
		# the ledger's "no new numeric balance value" rule), so the branch
		# choice below it is meaningful without inventing new Knight content.
		_definition(
			"knight_discipline", "knight", 1, [], [],
			"perk.knight_discipline.name", "perk.knight_discipline.effect",
			{"type": "none"}
		),
		_definition(
			"knight_shield_bash", "knight", 2, ["knight_discipline"], ["knight_chain_blow"],
			"perk.knight_shield_bash.name", "perk.knight_shield_bash.effect",
			{"type": "granted_action", "action_id": "shield_bash"}
		),
		_definition(
			"knight_chain_blow", "knight", 2, ["knight_discipline"], ["knight_shield_bash"],
			"perk.knight_chain_blow.name", "perk.knight_chain_blow.effect",
			{"type": "granted_action", "action_id": "chain_blow"}
		),
		# --- Archer (Stage 5 D4, migrated unchanged) -----------------------
		_definition(
			"archer_lock_on", "archer", 1, [], [],
			"perk.archer_lock_on.name", "perk.archer_lock_on.effect",
			{"type": "granted_action", "action_id": "lock_on"}
		),
		_definition(
			"archer_called_shot", "archer", 1, [], [],
			"perk.archer_called_shot.name", "perk.archer_called_shot.effect",
			{"type": "granted_action", "action_id": "called_shot"}
		),
		# --- Battle Mage (Stage 5 D4, migrated unchanged) ------------------
		_definition(
			"battle_mage_temporary_guard", "battle_mage", 1, [], [],
			"perk.battle_mage_temporary_guard.name", "perk.battle_mage_temporary_guard.effect",
			{"type": "granted_action", "action_id": "temporary_guard"}
		),
		# --- Legacy (see BONUS_MOVE_PERK_ID's own doc comment) -------------
		_definition(
			BONUS_MOVE_PERK_ID, "legacy", 0, [], [],
			"perk.bonus_move.name", "perk.bonus_move.effect",
			{"type": "stat_modifier", "stat": "action_points", "flat_bonus": 1}
		),
	]


static func _definition(
	id: String, class_id: String, tier: int, prerequisite_ids: Array, mutually_exclusive_with: Array,
	name_key: String, description_key: String, effect_descriptor: Dictionary
) -> Dictionary:
	var typed_prereqs: Array[String] = []
	for prereq_id in prerequisite_ids:
		typed_prereqs.append(String(prereq_id))
	var typed_exclusions: Array[String] = []
	for excluded_id in mutually_exclusive_with:
		typed_exclusions.append(String(excluded_id))
	return {
		"id": id,
		"class_id": class_id,
		"tier": tier,
		"prerequisite_ids": typed_prereqs,
		"mutually_exclusive_with": typed_exclusions,
		"rank_cap": 1,
		"name_key": name_key,
		"description_key": description_key,
		"effect_descriptor": effect_descriptor,
	}


## A safe duplicated copy of perk_id's own PerkDefinition, or {} for an
## unknown id.
static func get_definition(perk_id: String) -> Dictionary:
	return (get_definitions().get(perk_id, {}) as Dictionary).duplicate(true)


## Ordered perk ids whose `class_id` equals scope_id (a root class id or a
## specialization id), in the catalog's own authoring order -- mirrors
## CLASS_PERKS/SPECIALIZATION_PERKS' existing per-scope ordering convention.
static func get_scope_ids(scope_id: String) -> Array[String]:
	var ids: Array[String] = []
	for definition in _build_definitions():
		if String(definition.class_id) == scope_id:
			ids.append(String(definition.id))
	return ids


## adventurer's own currently-chosen perk ids (progression.perks), or [] for
## a record with no progression/perks field yet.
static func _chosen_perks(adventurer: Dictionary) -> Array:
	var progression: Variant = adventurer.get("progression", {})
	if not progression is Dictionary:
		return []
	var perks: Variant = (progression as Dictionary).get("perks", [])
	return perks if perks is Array else []


## The full ordered scope (root class perks, then -- once promoted -- the
## specialization's own perks) adventurer_id may ever choose from, regardless
## of what is already chosen -- mirrors GameSession.get_available_perks()'s
## existing "root perks first, then specialization perks" catalog-order
## convention.
static func _eligible_scope_ids(adventurer: Dictionary) -> Array[String]:
	var ids: Array[String] = get_scope_ids(String(adventurer.get("class", "")))
	var specialization_id := String(adventurer.get("specialization", ""))
	if not specialization_id.is_empty():
		ids.append_array(get_scope_ids(specialization_id))
	return ids


static func _prerequisites_met(definition: Dictionary, chosen: Array) -> bool:
	for prereq_id in (definition.get("prerequisite_ids", []) as Array):
		if not chosen.has(String(prereq_id)):
			return false
	return true


static func _excluded_by_chosen(definition: Dictionary, chosen: Array) -> bool:
	for excluded_id in (definition.get("mutually_exclusive_with", []) as Array):
		if chosen.has(String(excluded_id)):
			return true
	return false


## The still-choosable PerkDefinitions for adventurer (its class's own root
## perks, plus -- once promoted -- its specialization's own perks): not
## already chosen, every prerequisite already chosen, and not excluded by a
## chosen mutually-exclusive sibling. Empty prerequisite_ids/mutually_
## exclusive_with (every non-Knight perk today) make the last two checks a
## no-op, so this is behaviorally identical to the old flat "not already
## chosen" filter for them.
static func get_available_perks(adventurer: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var chosen := _chosen_perks(adventurer)
	var definitions := get_definitions()
	for perk_id in _eligible_scope_ids(adventurer):
		if chosen.has(perk_id):
			continue
		var definition: Dictionary = definitions.get(perk_id, {})
		if definition.is_empty():
			continue
		if not _prerequisites_met(definition, chosen):
			continue
		if _excluded_by_chosen(definition, chosen):
			continue
		available.append(definition.duplicate(true))
	return available


## True iff perk_id is one of adventurer's currently legal DAG choices (see
## get_available_perks()). Does NOT check GameSession's own level-derived
## slot economy (_pending_perk_slot_count()) -- that stays GameSession's own
## concern, composed on top of this pure DAG check by GameSession.choose_
## perk(), exactly the separation of concerns this step's milestone asks for
## ("without introducing bespoke controller flags").
static func can_choose_perk(adventurer: Dictionary, perk_id: String) -> bool:
	for definition in get_available_perks(adventurer):
		if String(definition.id) == perk_id:
			return true
	return false


## One of "owned", "excluded", "locked", "available", or "unknown" for
## perk_id against adventurer's current progression.perks -- the single
## source both level_up.gd's choice-card rendering and unit_details.gd's
## perk-tree rendering read for locked/available/active/excluded visual
## state (this step's own milestone). "unknown" only for an id with no
## catalog entry at all; every id actually in adventurer's own class/
## specialization scope always resolves to one of the other four.
static func get_perk_status(adventurer: Dictionary, perk_id: String) -> String:
	var definition := get_definition(perk_id)
	if definition.is_empty():
		return "unknown"
	var chosen := _chosen_perks(adventurer)
	if chosen.has(perk_id):
		return "owned"
	if _excluded_by_chosen(definition, chosen):
		return "excluded"
	if not _prerequisites_met(definition, chosen):
		return "locked"
	return "available"


## Returns a NEW adventurer-shaped Dictionary with perk_id appended to
## progression.perks -- the input Dictionary is never mutated (duplicate(true)
## up front), matching this file's own "pure function" convention. A no-op
## (returns an unmodified duplicate) for an illegal choice -- mirrors
## GameSession.choose_perk()'s existing "every check runs before any
## mutation" contract.
static func apply_perk(adventurer: Dictionary, perk_id: String) -> Dictionary:
	var updated: Dictionary = adventurer.duplicate(true)
	if not can_choose_perk(adventurer, perk_id):
		return updated
	if not updated.get("progression") is Dictionary:
		updated["progression"] = {}
	var progression: Dictionary = updated["progression"]
	if not progression.get("perks") is Array:
		progression["perks"] = []
	var perks: Array = progression["perks"]
	perks.append(perk_id)
	progression["perks"] = perks
	updated["progression"] = progression
	return updated


## --- Catalog-data validation (task 1) ---------------------------------------

## Diagnostics for an arbitrary PerkDefinition list (not necessarily the real
## shipped catalog -- see test_perk_catalog.gd's synthetic-fixture tests):
## invalid class ids, circular prerequisites, unrecognized effect descriptor
## types, and "duplicate rank" (two separate entries in the authored list
## claiming the identical `id` -- an authoring collision: get_definitions()'
## own id-keyed Dictionary conversion would silently let the later entry
## overwrite the earlier one, so this is caught here instead). Returns []
## when definitions is fully valid. Two independent, non-exclusive perks
## legitimately sharing one {class_id, tier} (e.g. Warrior's own Juggernaut/
## Bulwark, both tier 1) is NOT an error -- tier only orders a real
## prerequisite chain (Knight's Discipline/Shield-Bash-or-Chain-Blow), it is
## never a "one pick per tier" slot constraint on its own.
static func validate_definitions(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	var by_id: Dictionary = {}
	var claimed_ids: Dictionary = {}
	for definition in definitions:
		var perk_id := String(definition.get("id", ""))
		if claimed_ids.has(perk_id):
			errors.append("duplicate_rank: %s is defined more than once" % perk_id)
		claimed_ids[perk_id] = true
		by_id[perk_id] = definition

	for definition in definitions:
		var perk_id := String(definition.get("id", ""))
		var class_id := String(definition.get("class_id", ""))
		if not KNOWN_SCOPES.has(class_id):
			errors.append("invalid_class_id: %s (perk %s)" % [class_id, perk_id])

		var descriptor: Dictionary = definition.get("effect_descriptor", {})
		var descriptor_type := String(descriptor.get("type", ""))
		if not KNOWN_EFFECT_TYPES.has(descriptor_type):
			errors.append("unrecognized_effect_descriptor: %s type %s" % [perk_id, descriptor_type])

		if _has_cycle(perk_id, by_id, []):
			errors.append("circular_prerequisite: %s" % perk_id)
	return errors


static func _has_cycle(perk_id: String, by_id: Dictionary, path: Array) -> bool:
	if path.has(perk_id):
		return true
	if not by_id.has(perk_id):
		return false
	var next_path: Array = path.duplicate()
	next_path.append(perk_id)
	for prereq_id in (by_id[perk_id].get("prerequisite_ids", []) as Array):
		if _has_cycle(String(prereq_id), by_id, next_path):
			return true
	return false


## --- Deterministic serialization/deserialization (task 1) ------------------

## A canonical (sorted) copy of chosen_perk_ids -- the order a chosen perk
## graph was picked in is never itself meaningful (DAG reachability is), so
## two adventurers who chose the identical set in a different order still
## serialize identically for save data / equality assertions.
static func serialize_chosen_perks(chosen_perk_ids: Array) -> Array[String]:
	var ids: Array[String] = []
	for perk_id in chosen_perk_ids:
		ids.append(String(perk_id))
	ids.sort()
	return ids


## True iff chosen_perk_ids is a legally reachable perk graph against the
## real shipped catalog: no duplicate id, no two mutually-exclusive ids both
## present, and every id's prerequisite_ids chain resolves within the set --
## checked order-independently (a fixed-point resolution, not a strict replay
## of the array's own order), so a deterministically re-sorted save (see
## serialize_chosen_perks()) validates identically to the order it was
## originally chosen in. This is the DAG-integrity/mutual-exclusion check
## CampaignSnapshot's own perk validation (task 7) delegates to -- it does
## NOT check class/specialization ownership (ordinary unknown-or-foreign-id
## rejection stays CampaignSnapshot._validate_perks_field()'s own job, unlike
## this DAG-only check).
static func is_valid_perk_graph(chosen_perk_ids: Array) -> bool:
	var target_ids: Array[String] = []
	for perk_id in chosen_perk_ids:
		target_ids.append(String(perk_id))
	var unique_ids: Dictionary = {}
	for perk_id in target_ids:
		if unique_ids.has(perk_id):
			return false
		unique_ids[perk_id] = true

	var definitions := get_definitions()
	for perk_id in target_ids:
		var definition: Dictionary = definitions.get(perk_id, {})
		if definition.is_empty():
			continue  # Unknown ids are CampaignSnapshot's own ownership check's job, not this one's.
		for excluded_id in (definition.get("mutually_exclusive_with", []) as Array):
			if target_ids.has(String(excluded_id)):
				return false

	var resolved: Dictionary = {}
	var made_progress := true
	while made_progress and resolved.size() < target_ids.size():
		made_progress = false
		for perk_id in target_ids:
			if resolved.has(perk_id):
				continue
			var definition: Dictionary = definitions.get(perk_id, {})
			var prerequisites: Array = definition.get("prerequisite_ids", []) if not definition.is_empty() else []
			var satisfied := true
			for prereq_id in prerequisites:
				if not resolved.has(String(prereq_id)):
					satisfied = false
					break
			if satisfied:
				resolved[perk_id] = true
				made_progress = true
	return resolved.size() == target_ids.size()
