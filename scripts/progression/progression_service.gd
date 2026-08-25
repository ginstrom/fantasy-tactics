extends RefCounted

## Stage 6 Step 5 domain service (docs/plans/2026-08-24-stage-6-content-and-
## domain-foundations/05-domain-extraction-and-stage-6-exit.md): pure
## progression domain logic extracted verbatim out of game_session.gd -- XP
## distribution, level-up thresholds, perk queries/choice, specialization
## promotion, and every effective-stat formula (hit chance, melee/missile,
## health/MP, weapon/armor-derived values, scouting/spell range).
##
## Owns NO state of its own. Every function here reads and writes GameSession's
## own durable `adventurers` array (and reads its config-driven balance vars)
## through the `_gs` reference below -- there is no private/duplicated copy of
## any dictionary here. GameSession keeps a thin one-line forwarding method
## for every function moved here, so every existing call site keeps working
## unchanged.
var _gs: Node


func _init(game_session: Node) -> void:
	_gs = game_session


## Divides amount evenly across party_id's members and adds each member's
## share to their stored (float) xp, applying as many level-ups as the new
## total crosses. Silently ignores an unknown or memberless party. Returns
## the ids of members who gained at least one level from this award.
func award_party_xp(party_id: String, amount: float) -> Array[String]:
	var leveled_up: Array[String] = []
	var party_index: int = _gs._get_party_index(party_id)
	if party_index == -1:
		return leveled_up

	var member_ids: Array = _gs.parties[party_index].member_ids
	if member_ids.is_empty():
		return leveled_up

	var share := amount / member_ids.size()
	for member_id in member_ids:
		if _award_adventurer_xp(member_id, share):
			leveled_up.append(member_id)
	return leveled_up


func _award_adventurer_xp(adventurer_id: String, amount: float) -> bool:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = _gs.adventurers[adventurer_index]
	adventurer.progression.xp += amount

	var leveled_up := false
	while adventurer.progression.xp >= get_level_xp_threshold(adventurer.level + 1):
		var old_max_health: int = adventurer.stats.max_health
		adventurer.level += 1
		var class_id: String = adventurer.get("class", "warrior")
		var class_def: Dictionary = _gs.CLASS_DEFINITIONS.get(class_id, _gs.CLASS_DEFINITIONS.warrior)
		var vitality: int = int(adventurer.stats.get("vitality", class_def.base_stats.get("vitality", 10)))
		adventurer.stats.max_health = vitality * adventurer.level
		var health_delta: int = adventurer.stats.max_health - old_max_health
		var current_hp: int = int(adventurer.get("health", old_max_health))
		adventurer["health"] = clampi(current_hp + health_delta, 1, adventurer.stats.max_health)
		var skills: Dictionary = class_def.get("skills", {})
		for skill_name in skills:
			var skill_info: Dictionary = skills[skill_name]
			var min_gain: int = int(skill_info.get("min_gain", 1))
			var max_gain: int = int(skill_info.get("max_gain", 2))
			var gain: int = _gs.skill_gain_roll.call(min_gain, max_gain)
			var current_val: int = int(adventurer.stats.get(skill_name, 0))
			adventurer.stats[skill_name] = current_val + gain
		leveled_up = true
	if leveled_up:
		_gs.append_journal_entry(
			"level_up",
			"journal.level_up.title",
			{
				"adventurer_id": adventurer_id,
				"name": str(adventurer.get("name", "")),
				"level": int(adventurer.get("level", 1)),
				"class": str(adventurer.get("class", "")),
			},
			_gs.JOURNAL_SECTION_LOG
		)
	return leveled_up


## The single source of truth for cumulative XP thresholds: level 1 costs 0,
## level 2 costs 20, level 3 costs 50, level 4 costs 90 -- each level costing
## 10 XP more than the previous step. Equivalent to 5*level*(level+1) - 10.
func get_level_xp_threshold(level: int) -> float:
	return float(5 * level * (level + 1) - 10)


## True once an adventurer has earned a class-owned perk slot it has not yet
## resolved. Capped at PERK_TREE_SIZE slots total.
func is_perk_choice_pending(adventurer_id: String) -> bool:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	return _pending_perk_slot_count(_gs.adventurers[adventurer_index]) > 0


## earned_slots is level-derived, capped at PERK_TREE_SIZE -- and also at the
## adventurer's own class's actual perk count, so a class with fewer than
## PERK_TREE_SIZE defined perks never reports a slot pending with nothing to
## choose from. A promoted adventurer adds its specialization's own perk
## count on top.
func _perk_catalog_perk_cap(adventurer: Dictionary) -> int:
	var class_id: String = str(adventurer.get("class", ""))
	var cap: int = mini(_gs.PERK_TREE_SIZE, (_gs.CLASS_PERKS.get(class_id, []) as Array).size())
	var specialization_id := str(adventurer.get("specialization", ""))
	if not specialization_id.is_empty():
		cap += mini(_gs.PERK_TREE_SIZE, (_gs.SPECIALIZATION_PERKS.get(specialization_id, []) as Array).size())
	return cap


func _pending_perk_slot_count(adventurer: Dictionary) -> int:
	var perk_cap: int = _perk_catalog_perk_cap(adventurer)
	var earned_slots: int = mini(adventurer.level / _gs.PERK_LEVEL_INTERVAL, perk_cap)
	var spent_slots := 0
	for perk_id in adventurer.progression.perks:
		if perk_id != _gs.BONUS_MOVE_PERK_ID:
			spent_slots += 1
	return earned_slots - spent_slots


## Returns the still-choosable perk ids for adventurer_id -- its class's
## CLASS_PERKS entries, PLUS (once promoted) its specialization's own
## SPECIALIZATION_PERKS entries, that are not already in progression.perks.
## Delegates to PerkCatalog.get_available_perks(), which additionally
## enforces prerequisite/mutual-exclusion legality.
func get_available_perks(adventurer_id: String) -> Array[String]:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	var available: Array[String] = []
	if adventurer.is_empty():
		return available
	for definition in _gs.PerkCatalogScript.get_available_perks(adventurer):
		available.append(String(definition.id))
	return available


## The full per-perk DAG state across adventurer_id's ENTIRE class +
## (once promoted) specialization scope -- not just the still-choosable ids
## get_available_perks() returns. Returns [] for an unknown adventurer.
func get_perk_tree_status(adventurer_id: String) -> Array[Dictionary]:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	var result: Array[Dictionary] = []
	if adventurer.is_empty():
		return result
	var class_id := str(adventurer.get("class", ""))
	var scope_ids: Array[String] = _gs.PerkCatalogScript.get_scope_ids(class_id)
	var specialization_id := str(adventurer.get("specialization", ""))
	if not specialization_id.is_empty():
		scope_ids.append_array(_gs.PerkCatalogScript.get_scope_ids(specialization_id))
	for perk_id in scope_ids:
		result.append({"id": perk_id, "state": _gs.PerkCatalogScript.get_perk_status(adventurer, perk_id)})
	return result


## A safe copy of the perk catalog's own entry for perk_id, or {} for an
## unknown id.
func get_perk_definition(perk_id: String) -> Dictionary:
	return _gs.PerkCatalogScript.get_definition(perk_id)


## Localized display name for perk_id -- BONUS_MOVE_PERK_ID resolves through
## its own dedicated key, any other unrecognized id falls back to its raw id.
func get_perk_display_name(perk_id: String) -> String:
	if perk_id == _gs.BONUS_MOVE_PERK_ID:
		return tr("perk.bonus_move.name")
	var definition := get_perk_definition(perk_id)
	if definition.is_empty():
		return perk_id.capitalize()
	return tr(str(definition.name_key))


## Localized, numerically-filled effect description for perk_id (e.g.
## "+15% Max HP") -- the single place that formats a perk's effect_key
## against GameSession's own config-driven balance vars.
func get_perk_effect_description(perk_id: String) -> String:
	match perk_id:
		_gs.WARRIOR_JUGGERNAUT_PERK_ID:
			return tr("perk.warrior_juggernaut.effect") % _gs.WARRIOR_JUGGERNAUT_HP_PERCENT
		_gs.WARRIOR_BULWARK_PERK_ID:
			return tr("perk.warrior_bulwark.effect") % _gs.WARRIOR_BULWARK_GUARD
		_gs.SCOUT_QUICKDRAW_PERK_ID:
			return tr("perk.scout_quickdraw.effect") % _gs.SCOUT_QUICKDRAW_ACTION_POINTS
		_gs.SCOUT_KEEN_EYES_PERK_ID:
			return tr("perk.scout_keen_eyes.effect") % _gs.SCOUT_KEEN_EYES_INTEL_RANGE_BONUS
		_gs.CLERIC_MEDITATION_PERK_ID:
			return tr("perk.cleric_meditation.effect") % _gs.CLERIC_MEDITATION_SPELL_RANGE_BONUS
		_gs.CLERIC_DEVOUT_PERK_ID:
			return tr("perk.cleric_devout.effect") % _gs.CLERIC_DEVOUT_HP_PERCENT
		_gs.KNIGHT_DISCIPLINE_PERK_ID:
			return tr("perk.knight_discipline.effect")
		_gs.KNIGHT_SHIELD_BASH_PERK_ID:
			# Reuses the exact same off-balance magnitude Dodge/Parry already
			# apply. No new balance value invented for this description.
			return tr("perk.knight_shield_bash.effect") % _gs.OFF_BALANCE_GUARD_PENALTY
		_gs.KNIGHT_CHAIN_BLOW_PERK_ID:
			return tr("perk.knight_chain_blow.effect")
		_gs.ARCHER_LOCK_ON_PERK_ID:
			return tr("perk.archer_lock_on.effect") % int(round(_gs.ARCHER_LOCK_ON_HIT_CHANCE_BONUS * 100))
		_gs.ARCHER_CALLED_SHOT_PERK_ID:
			return tr("perk.archer_called_shot.effect") % int(round(_gs.ARCHER_CALLED_SHOT_TO_HIT_PENALTY * 100))
		_gs.BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID:
			# Reuses Bulwark's exact +10 Guard magnitude -- no new balance
			# value invented for this description.
			return tr("perk.battle_mage_temporary_guard.effect") % _gs.WARRIOR_BULWARK_GUARD
		_gs.BONUS_MOVE_PERK_ID:
			return tr("perk.bonus_move.effect")
		_:
			return ""


## Accepts only an id in adventurer_id's own class's CLASS_PERKS, OR (once
## promoted) its own specialization's SPECIALIZATION_PERKS. Only while
## is_perk_choice_pending() is true for adventurer_id, and only once per
## adventurer. PerkCatalog.can_choose_perk() owns eligibility/already-chosen/
## prerequisite/mutual-exclusion legality; this function keeps owning the
## level-derived slot-economy concern on top.
func choose_perk(adventurer_id: String, perk_id: String) -> bool:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = _gs.adventurers[adventurer_index]
	if not _gs.PerkCatalogScript.can_choose_perk(adventurer, perk_id):
		return false
	if _pending_perk_slot_count(adventurer) <= 0:
		return false

	adventurer.progression.perks.append(perk_id)
	return true


## --- Specializations (Stage 5 D4) -------------------------------------------

## Returns the specialization ids adventurer_id may promote into right now: a
## specialization is offered once (a) it is keyed to the adventurer's own
## current class in SPECIALIZATION_ROOT_CLASS, (b) that root class's own
## CLASS_PERKS are ALL already chosen, and (c) the adventurer has not already
## promoted. Returns [] for an unknown adventurer. Paladin additionally
## requires temple_level >= 1.
func get_available_specializations(adventurer_id: String) -> Array[String]:
	var available: Array[String] = []
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return available
	if not str(adventurer.get("specialization", "")).is_empty():
		return available
	var class_id := str(adventurer.get("class", ""))
	var root_perks: Array = _gs.CLASS_PERKS.get(class_id, [])
	var chosen: Array = adventurer.progression.get("perks", [])
	for perk_id in root_perks:
		if not chosen.has(perk_id):
			return available
	for specialization_id in _gs.SPECIALIZATION_ROOT_CLASS:
		if _gs.SPECIALIZATION_ROOT_CLASS[specialization_id] != class_id:
			continue
		if specialization_id == "paladin" and _gs.temple_level < 1:
			continue
		available.append(specialization_id)
	return available


## True iff specialization_id is one of adventurer_id's currently legal
## promotion choices.
func is_promotion_eligible(adventurer_id: String, specialization_id: String) -> bool:
	return get_available_specializations(adventurer_id).has(specialization_id)


## Promotes adventurer_id into specialization_id, unlocking that
## specialization's own SPECIALIZATION_PERKS on the existing perk-tree
## mechanism. Rejects an ineligible adventurer/specialization pair
## atomically.
func promote_adventurer(adventurer_id: String, specialization_id: String) -> bool:
	if not is_promotion_eligible(adventurer_id, specialization_id):
		return false
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	_gs.adventurers[adventurer_index]["specialization"] = specialization_id
	return true


## Empty string for an unpromoted (or unknown) adventurer.
func get_adventurer_specialization(adventurer_id: String) -> String:
	return str(_gs.get_adventurer(adventurer_id).get("specialization", ""))


## Centralized effective-hit-chance formula: min(raw skill / 100.0, 0.95).
## Skill used depends on weapon category: "bow" -> missile, others -> melee.
## Returns 0.0 for an unknown adventurer.
func get_effective_hit_chance(adventurer_id: String) -> float:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0.0
	var weapon_id := str(adventurer.equipment.weapon)
	var weapon: Dictionary = _gs.get_item_definition(weapon_id)
	var category := str(weapon.get("category", ""))
	var raw_stat: float = float(
		get_effective_missile(adventurer_id) if category == "bow" else get_effective_melee(adventurer_id)
	)
	return minf(raw_stat / _gs.ATTACK_TO_HIT_CHANCE_DIVISOR, _gs.EFFECTIVE_HIT_CHANCE_CAP)


## Raw melee accuracy skill (percentage points, pre-guard-subtraction,
## pre-weapon-category selection). Returns 0 for an unknown adventurer.
func get_effective_melee(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return int(adventurer.stats.get("melee", adventurer.stats.get("attack", 60)))


## Raw missile accuracy skill -- see get_effective_melee()'s own doc comment.
func get_effective_missile(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return int(adventurer.stats.get("missile", adventurer.stats.get("attack", 60)))


## Raw spellcasting skill (Cleric today). 0 for any class whose base_stats
## carries no "spellcasting" key. Returns 0 for an unknown adventurer.
func get_effective_spellcasting(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return int(adventurer.stats.get("spellcasting", 0))


## No adventurer stat or armor field grants magic resistance yet, so every
## class's effective value is 0.
func get_effective_magic_resistance(_adventurer_id: String) -> int:
	return 0


## Normalizes a monster template's attack accuracy into the shared melee/
## missile-vs-guard hit-chance formula. `stats` either authors the explicit
## "melee"/"missile" profile fields directly or a flat legacy "hit_chance".
func get_enemy_profile_hit_chance(stats: Dictionary) -> float:
	if stats.has("melee") or stats.has("missile"):
		var is_ranged: bool = int(stats.get("attack_max_range", 1)) > 1
		var raw: float = float(stats.get("missile", 0)) if is_ranged else float(stats.get("melee", 0))
		return minf(raw / _gs.ATTACK_TO_HIT_CHANCE_DIVISOR, _gs.EFFECTIVE_HIT_CHANCE_CAP)
	return float(stats.get("hit_chance", 0.0))


## A monster template's Guard: the explicit-profile "guard" key for a
## migrated template, or the legacy "defense" key otherwise.
func get_enemy_profile_guard(stats: Dictionary) -> int:
	return int(stats.get("guard", stats.get("defense", 0)))


## The shared melee/missile pair for a monster template's raw accuracy -- the
## mirror image of get_enemy_profile_hit_chance()'s hit_chance normalization.
func get_enemy_profile_melee(stats: Dictionary) -> int:
	if stats.has("melee") or stats.has("missile"):
		return int(stats.get("melee", 0))
	return int(round(float(stats.get("hit_chance", 0.0)) * _gs.ATTACK_TO_HIT_CHANCE_DIVISOR))


## See get_enemy_profile_melee()'s own doc comment.
func get_enemy_profile_missile(stats: Dictionary) -> int:
	if stats.has("melee") or stats.has("missile"):
		return int(stats.get("missile", 0))
	return int(round(float(stats.get("hit_chance", 0.0)) * _gs.ATTACK_TO_HIT_CHANCE_DIVISOR))


## Centralized effective max health: the adventurer's stored max_health plus
## the Juggernaut/Devout perk's percentage bonus, rounded to the nearest
## whole point. Returns 0 for an unknown adventurer.
func get_effective_max_health(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var perks: Array = adventurer.progression.get("perks", [])
	return _gs.compute_effective_max_health(int(adventurer.stats.max_health), perks)


## Returns current persistent health for adventurer_id (clamped in
## [1, max_health]), or 0 for an unknown adventurer.
func get_current_health(adventurer_id: String) -> int:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return 0
	var adventurer: Dictionary = _gs.adventurers[adventurer_index]
	var max_hp := get_effective_max_health(adventurer_id)
	return clampi(int(adventurer.get("health", max_hp)), 1, max_hp)


## Sets persistent health for adventurer_id, clamped to [1, max_health].
## Returns false for an unknown adventurer.
func set_adventurer_health(adventurer_id: String, amount: int) -> bool:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var max_hp := get_effective_max_health(adventurer_id)
	_gs.adventurers[adventurer_index]["health"] = clampi(amount, 1, max_hp)
	return true


## Durable MP: a class's mp_max is a config-driven balance value (CLERIC_MP_MAX/
## MAGE_MP_MAX), not a perk-derived effective stat. Returns 0 for an unknown
## adventurer or a class with no "mp_max" entry at all (Warrior/Scout).
func get_effective_max_mp(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var class_id: String = str(adventurer.get("class", ""))
	var class_def: Dictionary = _gs.CLASS_DEFINITIONS.get(class_id, {})
	if not class_def.has("mp_max"):
		return 0
	if class_id == "mage":
		return _gs.MAGE_MP_MAX
	return _gs.CLERIC_MP_MAX


## Returns current persistent MP for adventurer_id (clamped in [0, max_mp]),
## or 0 for an unknown adventurer or one whose class carries no MP resource.
func get_current_mp(adventurer_id: String) -> int:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return 0
	var max_mp := get_effective_max_mp(adventurer_id)
	if max_mp <= 0:
		return 0
	var adventurer: Dictionary = _gs.adventurers[adventurer_index]
	return clampi(int(adventurer.get("mp_current", max_mp)), 0, max_mp)


## Sets persistent MP for adventurer_id, clamped to [0, max_mp]. Returns false
## (a no-op) for an unknown adventurer or one whose class carries no MP
## resource.
func set_adventurer_mp(adventurer_id: String, amount: int) -> bool:
	var adventurer_index: int = _gs._get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var max_mp := get_effective_max_mp(adventurer_id)
	if max_mp <= 0:
		return false
	_gs.adventurers[adventurer_index]["mp_current"] = clampi(amount, 0, max_mp)
	return true


## Centralized effective battle AP: every unit starts with the battle
## baseline, plus one flexible AP per legacy Bonus Move holder and Scout
## Quickdraw's own configured bonus. Returns 0 for an unknown adventurer.
func get_effective_action_points(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var perks: Array = adventurer.progression.get("perks", [])
	return _gs.compute_effective_action_points(6, perks)


## Returns (damage_min, damage_max) from the adventurer's equipped weapon, or
## Vector2i.ZERO for an unknown adventurer or an equipped weapon id that has
## fallen out of WEAPONS.
func get_effective_weapon_damage_range(adventurer_id: String) -> Vector2i:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return Vector2i.ZERO
	var weapon: Dictionary = _gs.get_item_definition(adventurer.equipment.weapon)
	if weapon.is_empty():
		return Vector2i.ZERO
	return Vector2i(weapon.damage_min, weapon.damage_max)


## Ranged weapon data is optional while the catalog contains only melee
## weapons. Missing or invalid records remain safely adjacent-only.
func get_effective_weapon_attack_range(adventurer_id: String) -> Vector2i:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return Vector2i.ONE
	var weapon: Dictionary = _gs.get_item_definition(adventurer.equipment.weapon)
	if weapon.is_empty():
		return Vector2i.ONE
	var min_range: int = maxi(int(weapon.get("min_range", 1)), 1)
	var max_range: int = maxi(int(weapon.get("max_range", 1)), min_range)
	return Vector2i(min_range, max_range)


func get_effective_weapon_raw_damage_bonus(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var weapon_id := str(adventurer.equipment.weapon)
	if not _gs.owned_item_instances.has(weapon_id):
		return 0
	return 1 if _gs.owned_item_instances[weapon_id].get("treatment_id", "") == _gs.SHARPENED_TREATMENT_ID else 0


func get_effective_weapon_name(adventurer_id: String) -> String:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var weapon: Dictionary = _gs.get_item_definition(adventurer.equipment.weapon)
	return "" if weapon.is_empty() else tr(weapon.name_key)


func get_effective_armor_name(adventurer_id: String) -> String:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var armor: Dictionary = _gs.get_item_definition(adventurer.equipment.armor)
	return "" if armor.is_empty() else tr(armor.name_key)


## Armor defense plus the adventurer's own guard stat, plus Bulwark's flat
## configured Guard bonus once a Warrior has chosen it.
func get_effective_defense(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = _gs.get_item_definition(adventurer.equipment.armor)
	var armor_def: int = 0 if armor.is_empty() else int(armor.defense)
	var guard_stat: int = int(adventurer.stats.get("guard", 0))
	var perks: Array = adventurer.progression.get("perks", [])
	return _gs.compute_effective_defense(armor_def + guard_stat, perks)


## Scout strategic reconnaissance detection range: BASE_SCOUT_INTEL_RANGE,
## plus Keen Eyes' configured bonus once a Scout has chosen it. Returns the
## base range for an unknown adventurer.
func get_effective_scout_intel_range(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return _gs.BASE_SCOUT_INTEL_RANGE
	var perks: Array = adventurer.progression.get("perks", [])
	return _gs.PerkEffectResolverScript.compute_stat_modifier(_gs.BASE_SCOUT_INTEL_RANGE, perks, "scout_intel_range")


## Cleric Heal/Bless spell range: BASE_CLERIC_SPELL_RANGE, plus Meditation's
## configured bonus once a Cleric has chosen it. Returns the base range for
## an unknown adventurer.
func get_effective_spell_range(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return _gs.BASE_CLERIC_SPELL_RANGE
	var perks: Array = adventurer.progression.get("perks", [])
	return _gs.PerkEffectResolverScript.compute_stat_modifier(_gs.BASE_CLERIC_SPELL_RANGE, perks, "spell_range")


func get_effective_might(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return int(adventurer.stats.get("might", 0))


func get_effective_resistance(adventurer_id: String) -> int:
	var adventurer: Dictionary = _gs.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = _gs.get_item_definition(adventurer.equipment.armor)
	return 0 if armor.is_empty() else int(armor.resistance)
