class_name PerkEffectResolver
extends RefCounted

## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 04-branching-perk-definitions.md): bounded, pure rule evaluation over
## PerkCatalog's PerkDefinition catalog for combat and strategic
## calculations -- the single place a perk id's effect_descriptor is turned
## into a number/flag, replacing the scattered per-perk-id boolean branches
## GameSession's compute_effective_max_health()/compute_effective_defense()/
## compute_effective_action_points() and BattleController's granted-action
## gates (_unit_has_perk() call sites) used to each hardcode independently.
## Every function here is static and side-effect-free: it takes a perk id
## list (never the live GameSession/Unit object) and returns a plain value,
## mirroring PerkCatalog's own "pure domain function" convention.

const PerkCatalogScript := preload("res://scripts/progression/perk_catalog.gd")


## Sums every "stat_modifier" perk in perks whose `stat` matches stat_name,
## applies the combined percent bonus (rounded once against base_stat, same
## rounding GameSession.compute_effective_max_health() always used), then
## adds the combined flat bonus on top. Unknown perk ids and non-matching
## perks contribute nothing -- callers never need to pre-filter perks
## themselves. Order-independent: percent bonuses are summed BEFORE rounding
## once (so two 10% holders on the same stat combine as one 20% bonus, not
## two independently-rounded 10% steps), matching the only case that already
## existed (Bonus Move + Quickdraw both add flat_bonus, never percent).
static func compute_stat_modifier(base_stat: int, perks: Array, stat_name: String) -> int:
	var percent_bonus := 0
	var flat_bonus := 0
	var definitions := PerkCatalogScript.get_definitions()
	for perk_id in perks:
		var definition: Dictionary = definitions.get(String(perk_id), {})
		if definition.is_empty():
			continue
		var descriptor: Dictionary = definition.get("effect_descriptor", {})
		if String(descriptor.get("type", "")) != "stat_modifier":
			continue
		if String(descriptor.get("stat", "")) != stat_name:
			continue
		percent_bonus += int(descriptor.get("percent_bonus", 0))
		flat_bonus += int(descriptor.get("flat_bonus", 0))
	var with_percent := base_stat + int(round(base_stat * percent_bonus / 100.0))
	return with_percent + flat_bonus


## Every {perk_id, action_id} pair perks grants (effect_descriptor.type ==
## "granted_action") -- e.g. Knight's Shield Bash/Chain Blow, Archer's Lock
## On/Called Shot, Battle Mage's Temporary Guard. A perk with no catalog
## entry, or whose own descriptor is not a granted_action, is silently
## omitted rather than erroring -- mirrors PerkCatalog.get_available_perks()'
## own "unknown/non-matching entries contribute nothing" convention.
static func get_granted_actions(perks: Array) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var definitions := PerkCatalogScript.get_definitions()
	for perk_id in perks:
		var definition: Dictionary = definitions.get(String(perk_id), {})
		if definition.is_empty():
			continue
		var descriptor: Dictionary = definition.get("effect_descriptor", {})
		if String(descriptor.get("type", "")) == "granted_action":
			actions.append({"perk_id": String(perk_id), "action_id": String(descriptor.get("action_id", ""))})
	return actions


## True iff any perk in perks grants action_id -- the direct replacement for
## BattleController's old `_unit_has_perk(unit, GameSession.SOME_PERK_ID)`
## gate checks: the caller now names the ACTION it needs (e.g. "shield_bash"),
## not which specific perk id currently happens to grant it.
static func has_granted_action(perks: Array, action_id: String) -> bool:
	for action in get_granted_actions(perks):
		if String(action.action_id) == action_id:
			return true
	return false


## Applies every "action_modifier" perk in perks whose descriptor's own
## `action_id` matches base_action's `id` on top of base_action, returning a
## NEW Dictionary (base_action itself is never mutated). No perk in the
## current shipped catalog uses this effect type yet (Lock On/Called Shot's
## own numeric bonuses stay inline in BattleController's existing formula,
## gated by has_granted_action() instead -- see that file's own doc comment)
## -- this exists so a future perk can express a flat action-level modifier
## data-declaratively instead of adding another bespoke branch.
static func resolve_action_modifier(base_action: Dictionary, perks: Array) -> Dictionary:
	var result: Dictionary = base_action.duplicate(true)
	var action_id := String(base_action.get("id", ""))
	var definitions := PerkCatalogScript.get_definitions()
	for perk_id in perks:
		var definition: Dictionary = definitions.get(String(perk_id), {})
		if definition.is_empty():
			continue
		var descriptor: Dictionary = definition.get("effect_descriptor", {})
		if String(descriptor.get("type", "")) != "action_modifier":
			continue
		if String(descriptor.get("action_id", "")) != action_id:
			continue
		for key in descriptor.keys():
			if key == "type" or key == "action_id":
				continue
			result[key] = descriptor[key]
	return result
