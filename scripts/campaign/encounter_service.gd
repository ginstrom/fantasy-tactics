extends RefCounted

## Stage 6 Step 5 domain service (docs/plans/2026-08-24-stage-6-content-and-
## domain-foundations/05-domain-extraction-and-stage-6-exit.md): pure
## encounter/battle-context domain logic extracted verbatim out of
## game_session.gd -- active encounter instance management, vacancy
## countdowns, threat ratings, objective tracking, battle-context lifecycle
## (claim/victory/retreat/defeat), and catalog resolution.
##
## Owns NO state of its own. Every function here reads and writes GameSession's
## own durable fields (active_encounters, encounter_vacancies, _battle_context,
## completed_encounters, completed_objectives, campaign_objective_id,
## unlocked_authored_encounters, selected_encounter, ...) through the `_gs`
## reference below -- there is no private/duplicated copy of any dictionary
## here. GameSession keeps a thin one-line forwarding method for every
## function moved here, so every existing call site keeps working unchanged.
var _gs: Node


func _init(game_session: Node) -> void:
	_gs = game_session


func _resolve_enemy_composition(difficulty: int) -> Dictionary:
	var options: Array = _gs.STAR_ENEMY_COMPOSITIONS.get(difficulty, _gs.STAR_ENEMY_COMPOSITIONS[1])
	var option: Dictionary = options[0]
	if options.size() > 1:
		option = options[_gs.enemy_composition_roll.call(options.size())]
	var enemy: Dictionary = option.enemy.duplicate(true)
	enemy["count"] = _gs.enemy_count_roll.call(option.count_min, option.count_max)
	return enemy


## True for exactly the twelve authored campaign-ladder node ids -- the
## CAMPAIGN_OBJECTIVES keys, which double as their own EXPEDITIONS key and
## encounter id. False for every sandbox template id and every active-
## encounter instance id derived from one of them.
func is_authored_encounter(encounter_id: String) -> bool:
	return _gs.CAMPAIGN_OBJECTIVES.has(encounter_id)


## Gates enter_encounter(): a sandbox id is always enterable (matching prior
## behavior), but an authored id must be both currently unlocked and not
## already cleared -- authored objectives never respawn or reopen.
func can_enter_encounter(encounter_id: String) -> bool:
	if not is_authored_encounter(encounter_id):
		return true
	return _gs.unlocked_authored_encounters.has(encounter_id) and not _gs.completed_encounters.has(encounter_id)


## True when party_id may enter/continue the single active battle: no battle
## is currently claimed, the current battle context has already resolved
## (status is no longer "active"), or party_id itself already owns the live
## claim (re-entering its own claim is always legal). False for any other
## party while a different one holds an active claim.
func can_party_enter_battle(party_id: String) -> bool:
	var context := get_active_battle_context()
	return context.is_empty() or context.status != "active" or context.owner_party_id == party_id


## Claims the single active battle for party_id and mints a fresh BattleContext
## record (decision-ledger.md's PartyCarry/BattleContext target contract) --
## the canonical claim/attribution record for the battle about to start.
## Returns an empty Dictionary (no state change) if a different party already
## holds an active claim. Otherwise returns a duplicate of the newly-created
## context.
func create_battle_context(party_id: String, encounter_id: String, seed: int = 0) -> Dictionary:
	if not can_party_enter_battle(party_id):
		return {}
	_gs._battle_context = {
		"battle_id": _gs._new_instance_id(),
		"owner_party_id": party_id,
		"encounter_id": encounter_id,
		"reward": _gs._empty_carry(),
		"status": "active",
		"seed": seed,
	}
	return _gs._battle_context.duplicate(true)


## The current battle's own context record -- whatever its status, not only
## while a battle is still "active". Empty only when no battle has ever been
## created this session (or since the last reset()).
func get_active_battle_context() -> Dictionary:
	return _gs._battle_context.duplicate(true)


func enter_encounter(encounter_id: String) -> void:
	if not can_enter_encounter(encounter_id):
		return
	_gs.selected_encounter = encounter_id
	var instance_index := _get_active_encounter_index(encounter_id)
	# An authored node's active-encounter instance carries its own fixed
	# formation -- it must never be overwritten by the sandbox star-tier
	# reroll below, which only applies to a goblin_camp/orc_outpost/
	# ruined_fortress-derived instance.
	if instance_index != -1 and not is_authored_encounter(encounter_id):
		_gs.active_encounters[instance_index].enemy = _resolve_enemy_composition(
			_gs.active_encounters[instance_index].difficulty
		)


## Marks the current selection complete (once -- a re-completion of an
## already-completed id is a no-op) and, only when it names a still-live
## active instance, removes that instance and opens an encounter vacancy.
func complete_current_encounter() -> void:
	if _gs.selected_encounter == "":
		return
	_ensure_active_battle_context()
	var expedition := get_expedition(_gs.selected_encounter)
	if not _gs.completed_encounters.has(_gs.selected_encounter):
		_gs.completed_encounters.append(_gs.selected_encounter)
		# Mixed-formation authored nodes (see EXPEDITIONS' "enemies" field)
		# roll loot once per group, each with its own count merged in, rather
		# than the legacy single "enemy" + "count" template's one call.
		if expedition.has("enemies"):
			for group in expedition.enemies:
				var enemy_with_count: Dictionary = group.get("enemy", {}).duplicate(true)
				enemy_with_count["count"] = int(group.get("count", 1))
				_roll_and_queue_loot(enemy_with_count)
		else:
			_roll_and_queue_loot(expedition.get("enemy", {}))
		_gs._battle_context.reward.gold += _gs.loot_gold_roll.call(18, 22) * int(expedition.get("difficulty", 1))
		var reward_copy: Dictionary = _gs._battle_context.reward.duplicate(true)
		var loot_detail := {
			"encounter_id": _gs.selected_encounter,
			"gold": int(reward_copy.get("gold", 0)),
		}
		var gear: Dictionary = reward_copy.get("gear", {})
		if not gear.is_empty():
			loot_detail["gear"] = gear
		var crystals: Dictionary = reward_copy.get("mana_crystals", {})
		if not crystals.is_empty():
			loot_detail["mana_crystals"] = crystals
		_gs.append_journal_entry(
			"loot",
			"journal.loot.title",
			loot_detail,
			_gs.JOURNAL_SECTION_LOG
		)
		_gs._settle_encounter_intelligence(_gs.selected_encounter)
		_clear_active_encounter(_gs.selected_encounter)
		# An authored node's own encounter_id is exactly its CAMPAIGN_
		# OBJECTIVES key -- clearing it also completes the matching campaign
		# objective, unlocking the next node (or, for the final boss,
		# recording campaign victory).
		if is_authored_encounter(_gs.selected_encounter):
			complete_campaign_objective(_gs.selected_encounter)
	_gs.selected_encounter = ""


## Guarantees _battle_context is a fresh, "active" record before
## complete_current_encounter() rolls loot into it. A context left over from
## an already-resolved battle (or none at all) is replaced with a fresh one
## owned by whichever party is currently selected.
func _ensure_active_battle_context() -> void:
	if _gs._battle_context.get("status", "") == "active":
		return
	_gs._battle_context = {
		"battle_id": _gs._new_instance_id(),
		"owner_party_id": _gs.selected_party_id,
		"encounter_id": _gs.selected_encounter,
		"reward": _gs._empty_carry(),
		"status": "active",
		"seed": 0,
	}


## Rolls loot once per kill in the resolved enemy composition. A loot_id with
## no ENEMY_LOOT_TABLES row queues nothing rather than erroring. Accumulates
## into the active battle context's own reward.
func _roll_and_queue_loot(enemy: Dictionary) -> void:
	var loot_id: String = enemy.get("loot_id", "")
	if not _gs.ENEMY_LOOT_TABLES.has(loot_id):
		return
	var table: Dictionary = _gs.ENEMY_LOOT_TABLES[loot_id]
	var kill_count: int = enemy.get("count", 1)
	var reward: Dictionary = _gs._battle_context.reward
	for _kill in kill_count:
		reward.gold += _gs.loot_gold_roll.call(table.gold_min, table.gold_max) * table.gold_multiplier
		var crystal_tier: int = table.mana_crystal_tier
		reward.mana_crystals[crystal_tier] = reward.mana_crystals.get(crystal_tier, 0) + 1
		if _gs.loot_gear_roll.call() < _gs.GEAR_DROP_CHANCE:
			reward.gear[table.gear_item_id] = reward.gear.get(table.gear_item_id, 0) + 1


func abandon_current_encounter() -> void:
	_gs.selected_encounter = ""


## Pre-battle Withdraw: a nonlethal alternative to entering encounter_id,
## available only before Battlefield is ever reached. Returns an empty array
## (no mutation at all) unless the deployed party is standing on encounter_id,
## encounter_id is currently enterable, and no battle is already selected.
func withdraw_from_encounter(encounter_id: String, roll: Callable) -> Array[Dictionary]:
	if not _gs.has_deployed_party() or _gs.selected_encounter != "":
		return []
	if not can_enter_encounter(encounter_id):
		return []
	var expedition := get_expedition(encounter_id)
	if not expedition.has("position") or expedition.position != _gs.get_deployed_party_position():
		return []

	var results: Array[Dictionary] = []
	for member_id in _gs.get_selected_party().member_ids:
		var previous_health: int = _gs.get_current_health(member_id)
		var new_health := previous_health
		if roll.call() >= 0.90:
			var max_health: int = _gs.get_effective_max_health(member_id)
			_gs.set_adventurer_health(member_id, previous_health - ceili(max_health * 0.10))
			new_health = _gs.get_current_health(member_id)
		results.append({"id": member_id, "previous_health": previous_health, "new_health": new_health})

	_gs.set_deployed_party_route(_build_route_to_settlement())
	return results


## Manhattan-step route builder mirroring world_map.gd's build_route(): pure
## grid-agnostic path construction is duplicated here rather than reused
## because GameSession owns no Grid instance.
func _build_route_to_settlement() -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var current: Vector2i = _gs.get_deployed_party_position()
	var destination: Vector2i = _gs.STARTING_SETTLEMENT_WORLD_POSITION
	while current.x != destination.x:
		current.x += 1 if destination.x > current.x else -1
		route.append(current)
	while current.y != destination.y:
		current.y += 1 if destination.y > current.y else -1
		route.append(current)
	return route


## A duplicate of the current node's CAMPAIGN_OBJECTIVES entry, or {} once
## the campaign is complete (campaign_objective_id is "" from that point on).
func get_current_campaign_objective() -> Dictionary:
	return _gs.CAMPAIGN_OBJECTIVES.get(_gs.campaign_objective_id, {}).duplicate(true)


func is_objective_completed(id: String) -> bool:
	return _gs.completed_objectives.has(id)


## Marks id complete, unlocks its successor objective/encounter, and advances
## campaign_objective_id to it. A no-op for an unknown id or one already in
## completed_objectives. Completing the final node instead atomically records
## campaign victory.
func complete_campaign_objective(id: String) -> void:
	if not _gs.CAMPAIGN_OBJECTIVES.has(id) or is_objective_completed(id):
		return
	_gs.completed_objectives.append(id)
	var next_id: String = _gs.CAMPAIGN_OBJECTIVES[id].get("next_objective_id", "")
	if next_id.is_empty():
		_gs.campaign_objective_id = ""
		_gs.set_campaign_victory()
		return
	if not _gs.unlocked_authored_encounters.has(next_id):
		_gs.unlocked_authored_encounters.append(next_id)
	_gs._ensure_authored_intel_record(next_id)
	_gs.campaign_objective_id = next_id
	_gs.campaign_progress_changed.emit()


## True whenever the current battle context's reward still holds anything
## resolve_battle_victory()/resolve_battle_retreat()/resolve_battle_defeat()
## has not yet resolved.
func has_unsettled_battle_loot() -> bool:
	return _gs._battle_context.get("status", "") == "active"


## Moves the active battle context's own reward into its owning party's carry
## and marks it "victory". Returns false (no state change) unless battle_id
## names the current, still-"active" battle context.
func resolve_battle_victory(battle_id: String) -> bool:
	if _gs._battle_context.get("battle_id", "") != battle_id or _gs._battle_context.get("status", "") != "active":
		return false
	var party_index: int = _gs._get_party_index(_gs._battle_context.owner_party_id)
	if party_index != -1:
		var carry: Dictionary = _gs.parties[party_index].carry
		var reward: Dictionary = _gs._battle_context.reward
		carry.gold += int(reward.get("gold", 0))
		_gs._merge_counts(reward.get("gear", {}), carry.gear)
		_gs._merge_counts(reward.get("mana_crystals", {}), carry.mana_crystals)
		for raw_instance_id in reward.get("item_instance_ids", []):
			var instance_id := str(raw_instance_id)
			if not carry.item_instance_ids.has(instance_id):
				carry.item_instance_ids.append(instance_id)
	_gs._battle_context.status = "victory"
	var victory_encounter_id: String = str(_gs._battle_context.get("encounter_id", ""))
	_gs.append_journal_entry(
		"battle",
		"journal.battle.victory.title",
		{
			"outcome": "victory",
			"encounter_id": victory_encounter_id,
		},
		_gs.JOURNAL_SECTION_LOG
	)
	return true


## Discards the active battle context's own not-yet-banked reward outright --
## the Retreat outcome -- and marks it "retreat". Returns false (no state
## change) unless battle_id names the current, still-"active" battle context.
func resolve_battle_retreat(battle_id: String) -> bool:
	if _gs._battle_context.get("battle_id", "") != battle_id or _gs._battle_context.get("status", "") != "active":
		return false
	var retreat_encounter_id: String = str(_gs._battle_context.get("encounter_id", ""))
	_gs._battle_context.reward = _gs._empty_carry()
	_gs._battle_context.status = "retreat"
	_gs.append_journal_entry(
		"battle",
		"journal.battle.retreat.title",
		{
			"outcome": "retreat",
			"encounter_id": retreat_encounter_id,
		},
		_gs.JOURNAL_SECTION_LOG
	)
	return true


## A full party wipe: discards the active battle context's own not-yet-banked
## reward and forfeits the owning party's own already-carried loot alike, then
## marks the context "defeat". Returns false (no state change) unless
## battle_id names the current, still-"active" battle context.
func resolve_battle_defeat(battle_id: String) -> bool:
	if _gs._battle_context.get("battle_id", "") != battle_id or _gs._battle_context.get("status", "") != "active":
		return false
	var defeat_encounter_id: String = str(_gs._battle_context.get("encounter_id", ""))
	_gs.forfeit_party_carry(_gs._battle_context.owner_party_id)
	_gs._battle_context.reward = _gs._empty_carry()
	_gs._battle_context.status = "defeat"
	_gs.append_journal_entry(
		"battle",
		"journal.battle.defeat.title",
		{
			"outcome": "defeat",
			"encounter_id": defeat_encounter_id,
		},
		_gs.JOURNAL_SECTION_LOG
	)
	return true


func is_encounter_complete(encounter_id: String) -> bool:
	return _gs.completed_encounters.has(encounter_id)


## Resolves either a live active-encounter-instance id or a raw template id
## from EXPEDITIONS (checked in that order), returning a safe copy either way.
func get_expedition(encounter_id: String) -> Dictionary:
	var instance_index := _get_active_encounter_index(encounter_id)
	if instance_index != -1:
		return _gs.active_encounters[instance_index].duplicate(true)
	if not _gs.EXPEDITIONS.has(encounter_id):
		return {}
	return _overlay_content_catalog_definition(encounter_id, _gs.EXPEDITIONS[encounter_id].duplicate(true))


## Overlays a ContentCatalog encounter definition's authored fields onto a
## legacy EXPEDITIONS entry, for whichever encounter id has migrated into
## config/content/ (Stage 6 Step 3). Every other still-legacy EXPEDITIONS
## entry (no catalog file for its id) is returned completely unchanged.
func _overlay_content_catalog_definition(encounter_id: String, expedition: Dictionary) -> Dictionary:
	var definition: Dictionary = _gs.ContentCatalogScript.get_encounter_definition(encounter_id)
	if definition.is_empty():
		return expedition
	expedition["position"] = definition.world_position
	expedition["clear_xp"] = definition.clear_xp
	expedition["difficulty"] = definition.tier
	expedition["name_key"] = definition.name_key
	var enemies: Array = []
	for group in (definition.enemy_composition as Array):
		var stats: Dictionary = _gs.ContentCatalogScript.resolve_enemy_template(String(group.template_id))
		enemies.append({"enemy": stats, "count": int(group.count)})
	expedition["enemies"] = enemies
	return expedition


## Every THREAT_TURN_INTERVAL world turns elapsed adds one star on top of an
## encounter's own base "difficulty", clamped to the 1-5 range World Map
## markers render. Returns 1 for an unknown encounter id.
func get_threat_stars(encounter_id: String) -> int:
	var expedition := get_expedition(encounter_id)
	var base_difficulty: int = int(expedition.get("difficulty", 1))
	return clampi(base_difficulty + int(_gs.world_turn / _gs.THREAT_TURN_INTERVAL), 1, 5)


## World Map/information-panel "turns until next threat star" counter: how
## many more World Map Turns until get_threat_stars(encounter_id) would rise
## by one more star. Returns -1 once the encounter's stars are already
## clamped at 5.
func get_turns_until_next_threat_star(encounter_id: String) -> int:
	if get_threat_stars(encounter_id) >= 5:
		return -1
	var next_interval_turn: int = (int(_gs.world_turn / _gs.THREAT_TURN_INTERVAL) + 1) * int(_gs.THREAT_TURN_INTERVAL)
	return next_interval_turn - _gs.world_turn


## Expected gold value for a given star tier -- see decision-ledger.md D1.
func get_encounter_expected_gold_value(tier: int) -> int:
	return int(round(20.0 * tier))


func get_active_encounters() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	for instance in _gs.active_encounters:
		instances.append(instance.duplicate(true))
	return instances


func _make_encounter_instance(instance_id: String, template_id: String, position: Vector2i) -> Dictionary:
	var instance: Dictionary = _gs.EXPEDITIONS[template_id].duplicate(true)
	instance["id"] = instance_id
	instance["template_id"] = template_id
	instance["position"] = position
	return instance


func _get_active_encounter_index(instance_id: String) -> int:
	for index in _gs.active_encounters.size():
		if _gs.active_encounters[index].id == instance_id:
			return index
	return -1


## No-ops for an id that does not name a live active instance (e.g. a raw
## template id entered via the debug menu).
func _clear_active_encounter(instance_id: String) -> void:
	var index := _get_active_encounter_index(instance_id)
	if index == -1:
		return
	_gs.active_encounters.remove_at(index)
	_start_encounter_vacancy()


## Resolves a single bounded delay for a newly opened vacancy via
## vacancy_delay_roll, called once per vacancy (never rerolled while
## ticking).
func _resolve_vacancy_delay(base_turns: int, jitter_turns: int) -> int:
	var minimum := maxi(1, base_turns - jitter_turns)
	var maximum := base_turns + jitter_turns
	return _gs.vacancy_delay_roll.call(minimum, maximum)


## Distinguishes "no new cooldown starts if already at capacity" (this guard,
## evaluated once at vacancy-open time) from "a clock exists but is capped
## from firing" (the symmetric guard inside _advance_encounter_vacancies).
func _start_encounter_vacancy() -> void:
	if _gs.active_encounters.size() >= _gs.ENCOUNTER_INSTANCE_CAP:
		return
	var turns_remaining := _resolve_vacancy_delay(_gs.ENCOUNTER_VACANCY_TURNS, _gs.ENCOUNTER_VACANCY_JITTER_TURNS)
	_gs.encounter_vacancies.append({"turns_remaining": turns_remaining})


## Ticks every pending encounter vacancy clock down by one World Map turn. A
## clock that reaches zero fires exactly once: if the cap still has room it
## spawns a new instance; either way the clock is then discarded.
func _advance_encounter_vacancies() -> void:
	var still_pending: Array[Dictionary] = []
	for vacancy in _gs.encounter_vacancies:
		vacancy.turns_remaining -= 1
		if vacancy.turns_remaining > 0:
			still_pending.append(vacancy)
			continue
		if _gs.active_encounters.size() < _gs.ENCOUNTER_INSTANCE_CAP:
			_gs.active_encounters.append(_spawn_next_encounter_instance())
	_gs.encounter_vacancies = still_pending


func _spawn_next_encounter_instance() -> Dictionary:
	var template_id := _choose_encounter_template()
	var position := _choose_encounter_position(template_id)
	if not _gs._used_encounter_template_ids.has(template_id):
		_gs._used_encounter_template_ids.append(template_id)
	var instance := _make_encounter_instance(_mint_encounter_instance_id(), template_id, position)
	_gs._register_encounter_intel_and_quest(instance)
	return instance


## Weighted-random by star tier, favoring higher tiers as the player's power
## grows. Only a template with no currently-active instance is eligible.
func _player_power() -> int:
	return _gs.adventurers.size() + _gs.guild_hall_level


func _star_tier_weight(tier: int, power: int) -> int:
	var clamped_tier: int = clampi(tier, 1, 3)
	return maxi(_gs.STAR_WEIGHT_MIN, _gs.STAR_WEIGHT_BASE[clamped_tier] + _gs.STAR_WEIGHT_PER_POWER[clamped_tier] * power)


func _choose_encounter_template() -> String:
	var candidates: Array[String] = []
	for template_id in _gs.ENCOUNTER_TEMPLATE_ORDER:
		if not _is_encounter_template_active(template_id):
			candidates.append(template_id)
	if candidates.is_empty():
		return _gs.ENCOUNTER_TEMPLATE_ORDER[0]

	var power := _player_power()
	var weights: Array[int] = []
	var total_weight := 0
	for template_id in candidates:
		var weight := _star_tier_weight(_gs.EXPEDITIONS[template_id].difficulty, power)
		weights.append(weight)
		total_weight += weight

	var roll: int = _gs.star_weight_roll.call(total_weight)
	var cumulative := 0
	for index in candidates.size():
		cumulative += weights[index]
		if roll < cumulative:
			return candidates[index]
	return candidates[-1]


func _is_encounter_template_active(template_id: String) -> bool:
	for instance in _gs.active_encounters:
		if instance.template_id == template_id:
			return true
	return false


## Prefers the template's own documented position; only scans for another
## in-bounds, unoccupied, non-settlement tile if that position is already
## occupied by another active instance, OR if template_id has ever been
## spawned before (tracked by _used_encounter_template_ids). See
## game_session.gd's own former copy of this doc comment (git history) for
## the full far-corner-first scan rationale -- unchanged by this move.
func _choose_encounter_position(template_id: String) -> Vector2i:
	var documented_position: Vector2i = _gs.EXPEDITIONS[template_id].position
	var template_previously_spawned: bool = _gs._used_encounter_template_ids.has(template_id)
	if not _is_position_occupied(documented_position) and not template_previously_spawned:
		return documented_position
	for y in range(_gs.WORLD_GRID_HEIGHT - 1, -1, -1):
		for x in range(_gs.WORLD_GRID_WIDTH - 1, -1, -1):
			var candidate := Vector2i(x, y)
			if candidate == documented_position:
				continue
			if candidate != _gs.STARTING_SETTLEMENT_WORLD_POSITION and not _is_position_occupied(candidate):
				return candidate
	return documented_position


func _is_position_occupied(position: Vector2i) -> bool:
	for instance in _gs.active_encounters:
		if instance.position == position:
			return true
	return false


## Mints an "encounter_NNN" id that collides with neither a currently-active
## instance nor a historically-completed one, so a cleared site's old id is
## never reused by an unrelated later spawn.
func _mint_encounter_instance_id() -> String:
	var instance_number := 1
	var instance_id := "encounter_%03d" % instance_number
	while _get_active_encounter_index(instance_id) != -1 or _gs.completed_encounters.has(instance_id):
		instance_number += 1
		instance_id = "encounter_%03d" % instance_number
	return instance_id
