class_name CampaignSnapshot
extends RefCounted
## Versioned, deep-copy-safe value object for GameSession's durable-state
## boundary (see docs/plans/2026-08-10-initial-campaign-and-automation/
## 01-campaign-snapshot-contract.md). Converts between GameSession's live,
## strongly-typed fields (Vector2i positions/routes) and a plain, JSON-safe
## Dictionary ({"x": int, "y": int} standing in for every Vector2i) that a
## later save-repository step can persist unchanged.
##
## GameSession.export_campaign_snapshot() populates a CampaignSnapshot's
## fields from itself and calls to_dictionary(); GameSession.
## import_campaign_snapshot(data) hands data straight to the static
## from_dictionary(data), which validates and normalizes the whole payload
## into a separate scratch Dictionary before returning it -- GameSession only
## assigns its own fields once from_dictionary() reports "ok": true, so a
## rejected import can never partially land. Contains no disk I/O and never
## triggers reward-banking side effects (merge_battle_loot_into_party(),
## deposit_pending_reward()) -- it only moves values, never settles them.

const FORMAT_VERSION := 2

## Same EXPEDITIONS template catalog GameSession exposes on its autoload
## singleton, reached here via preload of the script itself (a compile-time
## constant lookup) rather than the GameSession singleton reference, so this
## contract depends on the constant table, not on the autoload existing.
const _GameSessionScript := preload("res://scripts/autoload/game_session.gd")

var adventurers: Array[Dictionary] = []
var recruitment_candidates: Array[Dictionary] = []
var recruitment_vacancies: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var selected_party_id: String = ""
var selected_encounter: String = ""
# Durable campaign milestone progression (see GameSession.CAMPAIGN_OBJECTIVES
# and complete_campaign_objective()/set_campaign_victory()) -- introduced in
# format version 2. A version-1 payload has none of these keys; from_
# dictionary() normalizes it to the same starting-campaign defaults these
# vars themselves default to, rather than trying to infer progress from the
# legacy completed_encounters list (which names sandbox EXPEDITIONS ids, not
# CAMPAIGN_OBJECTIVES ids -- there is no reliable mapping between the two).
var campaign_objective_id: String = "obj_tier1_1_goblin_outpost"
var completed_objectives: Array[String] = []
var unlocked_authored_encounters: Array[String] = ["obj_tier1_1_goblin_outpost"]
var is_campaign_completed: bool = false
var is_free_play_active: bool = false
# Lifetime casualty count (see GameSession.total_casualties' own doc
# comment). Added after version one shipped -- an old payload normalizes to
# 0 rather than rejecting, same as temple_level below.
var total_casualties: int = 0
var completed_encounters: Array[String] = []
var active_encounters: Array[Dictionary] = []
var encounter_vacancies: Array[Dictionary] = []
# Mirrors GameSession._used_encounter_template_ids (see that field's own
# doc comment) -- private in GameSession, but still durable: without it a
# restored campaign's next vacancy refill could hand a reused template the
# exact tile its earlier instance was just cleared from.
var used_encounter_template_ids: Array[String] = []
var world_turn: int = 1
var gold: int = 0
var guild_hall_level: int = 1
# Temple hub level (see GameSession.temple_level's own doc comment): 0
# (unbuilt) or 1 (consecrated). Added after version one shipped, so a
# version-1 payload normalizes to the harmless unbuilt default rather than
# rejecting -- see the blacksmith_level/alchemy_workshop_level fields below
# for the same incremental-field-addition pattern.
var temple_level: int = 0
var blacksmith_level: int = 0
var blacksmith_craft_job: Dictionary = {}
var blacksmith_sharpening_job: Dictionary = {}
var alchemy_workshop_level: int = 0
var alchemy_craft_job: Dictionary = {}
var runic_workshop_level: int = 0
var runic_craft_job: Dictionary = {}
var pending_reward: int = 0
var mana_crystals: Dictionary = {}
var banked_gear: Dictionary = {}
var owned_item_instances: Dictionary = {}
var banked_item_instance_ids: Array[String] = []
var pending_mana_crystals: Dictionary = {}
var pending_gear: Dictionary = {}
var battle_reward: int = 0
var battle_mana_crystals: Dictionary = {}
var battle_gear: Dictionary = {}
var has_trading_post: bool = false
var shop_level: int = 1
var shop_gold: int = 100
var player_name: String = ""
# Compact durable record of which first-campaign guide messages have already
# been shown/dismissed (see docs/plans/2026-08-10-initial-campaign-and-
# automation/04-first-campaign-guidance.md's get_campaign_guide_state()) --
# an arbitrary id -> bool map, empty until that step starts writing to it.
var tutorial_progress: Dictionary = {}


## Serializes this object's own fields into a plain, JSON-safe Dictionary
## tagged with FORMAT_VERSION. Every field is deep-duplicated (and every
## Vector2i converted to {"x": int, "y": int}) so the result shares no
## Array/Dictionary reference with this object.
func to_dictionary() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"adventurers": adventurers.duplicate(true),
		"recruitment_candidates": recruitment_candidates.duplicate(true),
		"recruitment_vacancies": recruitment_vacancies.duplicate(true),
		"parties": _parties_to_dictionary(parties),
		"selected_party_id": selected_party_id,
		"selected_encounter": selected_encounter,
		"campaign_objective_id": campaign_objective_id,
		"completed_objectives": completed_objectives.duplicate(true),
		"unlocked_authored_encounters": unlocked_authored_encounters.duplicate(true),
		"is_campaign_completed": is_campaign_completed,
		"is_free_play_active": is_free_play_active,
		"total_casualties": total_casualties,
		"completed_encounters": completed_encounters.duplicate(true),
		"active_encounters": _encounters_to_dictionary(active_encounters),
		"encounter_vacancies": encounter_vacancies.duplicate(true),
		"used_encounter_template_ids": used_encounter_template_ids.duplicate(true),
		"world_turn": world_turn,
		"gold": gold,
		"guild_hall_level": guild_hall_level,
		"temple_level": temple_level,
		"blacksmith_level": blacksmith_level,
		"blacksmith_craft_job": blacksmith_craft_job.duplicate(true),
		"blacksmith_sharpening_job": blacksmith_sharpening_job.duplicate(true),
		"alchemy_workshop_level": alchemy_workshop_level,
		"alchemy_craft_job": alchemy_craft_job.duplicate(true),
		"runic_workshop_level": runic_workshop_level,
		"runic_craft_job": runic_craft_job.duplicate(true),
		"pending_reward": pending_reward,
		"mana_crystals": mana_crystals.duplicate(true),
		"banked_gear": banked_gear.duplicate(true),
		"owned_item_instances": owned_item_instances.duplicate(true),
		"banked_item_instance_ids": banked_item_instance_ids.duplicate(),
		"pending_mana_crystals": pending_mana_crystals.duplicate(true),
		"pending_gear": pending_gear.duplicate(true),
		"battle_reward": battle_reward,
		"battle_mana_crystals": battle_mana_crystals.duplicate(true),
		"battle_gear": battle_gear.duplicate(true),
		"has_trading_post": has_trading_post,
		"shop_level": shop_level,
		"shop_gold": shop_gold,
		"player_name": player_name,
		"tutorial_progress": tutorial_progress.duplicate(true),
	}


## Validates and normalizes a raw Dictionary (as produced by to_dictionary(),
## or later read back from a save file) into the exact set of typed values
## GameSession assigns on success. Never partially commits: every field is
## checked against a scratch Dictionary first, and the first failure returns
## immediately with an empty "snapshot" rather than a partially-normalized
## result a careless caller might assign anyway.
static func from_dictionary(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return _invalid("snapshot data is not a dictionary")
	if not data.get("version") is int:
		return _invalid("missing or unsupported snapshot version")
	# Version 1 predates campaign milestone progression (see
	# _normalize_campaign_progress()) and migrates gracefully; any other
	# version besides the current FORMAT_VERSION is unsupported.
	var version: int = int(data.version)
	if version != 1 and version != FORMAT_VERSION:
		return _invalid("missing or unsupported snapshot version")

	var normalized: Dictionary = {}

	var adventurers_result := _normalize_id_list(data.get("adventurers"), "adventurers")
	if not adventurers_result.ok:
		return _invalid(adventurers_result.error)
	normalized["adventurers"] = _normalize_roster_records(adventurers_result.list)
	var adventurer_perks_error := _validate_perks_field(normalized.adventurers, "adventurers")
	if not adventurer_perks_error.is_empty():
		return _invalid(adventurer_perks_error)

	var candidates_result := _normalize_id_list(data.get("recruitment_candidates"), "recruitment_candidates")
	if not candidates_result.ok:
		return _invalid(candidates_result.error)
	normalized["recruitment_candidates"] = _normalize_roster_records(candidates_result.list)
	var candidate_perks_error := _validate_perks_field(normalized.recruitment_candidates, "recruitment_candidates")
	if not candidate_perks_error.is_empty():
		return _invalid(candidate_perks_error)

	var recruitment_vacancies_result := _normalize_vacancy_list(data.get("recruitment_vacancies"), "recruitment_vacancies")
	if not recruitment_vacancies_result.ok:
		return _invalid(recruitment_vacancies_result.error)
	normalized["recruitment_vacancies"] = recruitment_vacancies_result.list

	var parties_result := _normalize_parties(data.get("parties"))
	if not parties_result.ok:
		return _invalid(parties_result.error)
	normalized["parties"] = parties_result.list

	var completed_result := _normalize_string_array(data.get("completed_encounters"), "completed_encounters")
	if not completed_result.ok:
		return _invalid(completed_result.error)
	normalized["completed_encounters"] = completed_result.list

	var active_encounters_result := _normalize_active_encounters(data.get("active_encounters"))
	if not active_encounters_result.ok:
		return _invalid(active_encounters_result.error)
	normalized["active_encounters"] = active_encounters_result.list

	var encounter_vacancies_result := _normalize_vacancy_list(data.get("encounter_vacancies"), "encounter_vacancies")
	if not encounter_vacancies_result.ok:
		return _invalid(encounter_vacancies_result.error)
	normalized["encounter_vacancies"] = encounter_vacancies_result.list

	var used_templates_result := _normalize_string_array(data.get("used_encounter_template_ids"), "used_encounter_template_ids")
	if not used_templates_result.ok:
		return _invalid(used_templates_result.error)
	normalized["used_encounter_template_ids"] = used_templates_result.list

	if not data.get("selected_party_id") is String:
		return _invalid("selected_party_id is not a string")
	normalized["selected_party_id"] = data.selected_party_id

	if not data.get("selected_encounter") is String:
		return _invalid("selected_encounter is not a string")
	normalized["selected_encounter"] = data.selected_encounter

	var campaign_progress_result := _normalize_campaign_progress(data, version)
	if not campaign_progress_result.ok:
		return _invalid(campaign_progress_result.error)
	var campaign_progress: Dictionary = campaign_progress_result.value
	normalized["campaign_objective_id"] = campaign_progress.campaign_objective_id
	normalized["completed_objectives"] = campaign_progress.completed_objectives
	normalized["unlocked_authored_encounters"] = campaign_progress.unlocked_authored_encounters
	normalized["is_campaign_completed"] = campaign_progress.is_campaign_completed
	normalized["is_free_play_active"] = campaign_progress.is_free_play_active

	# Mirrors the selected_encounter cross-reference check below: an empty
	# campaign_objective_id is valid (it means the campaign is complete, see
	# GameSession.complete_campaign_objective()'s final-node case), but a
	# non-empty one must name a real CAMPAIGN_OBJECTIVES node, and every
	# completed_objectives/unlocked_authored_encounters entry always must --
	# neither list is ever legitimately empty-string-valued.
	if (
		normalized.campaign_objective_id != ""
		and not _GameSessionScript.CAMPAIGN_OBJECTIVES.has(normalized.campaign_objective_id)
	):
		return _invalid("campaign_objective_id does not reference a known campaign objective")
	for objective_id in normalized.completed_objectives:
		if not _GameSessionScript.CAMPAIGN_OBJECTIVES.has(objective_id):
			return _invalid("completed_objectives contains an unknown campaign objective id: %s" % objective_id)
	for objective_id in normalized.unlocked_authored_encounters:
		if not _GameSessionScript.CAMPAIGN_OBJECTIVES.has(objective_id):
			return _invalid("unlocked_authored_encounters contains an unknown campaign objective id: %s" % objective_id)

	for scalar_key in ["world_turn", "gold", "guild_hall_level", "pending_reward", "battle_reward"]:
		if not data.get(scalar_key) is int:
			return _invalid("%s is not an int" % scalar_key)
		normalized[scalar_key] = int(data[scalar_key])

	# Added after version one shipped, so existing snapshots normalize to a
	# harmless zero casualty count.
	if data.has("total_casualties") and not data.total_casualties is int:
		return _invalid("total_casualties is not an int")
	normalized["total_casualties"] = int(data.get("total_casualties", 0))

	# Added after version one shipped, so existing snapshots normalize to the
	# harmless unbuilt state while new saves retain the Temple's real level.
	if data.has("temple_level") and not data.temple_level is int:
		return _invalid("temple_level is not an int")
	normalized["temple_level"] = int(data.get("temple_level", 0))
	if normalized.temple_level < 0 or normalized.temple_level > _GameSessionScript.TEMPLE_MAX_LEVEL:
		return _invalid("temple_level is out of range")

	# Added after version one shipped, so existing snapshots normalize to the
	# harmless unbuilt/no-job state while new saves retain active work.
	if data.has("blacksmith_level") and not data.blacksmith_level is int:
		return _invalid("blacksmith_level is not an int")
	normalized["blacksmith_level"] = int(data.get("blacksmith_level", 0))
	for job_key in ["blacksmith_craft_job", "blacksmith_sharpening_job"]:
		if data.has(job_key) and not data[job_key] is Dictionary:
			return _invalid("%s is not a dictionary" % job_key)
		normalized[job_key] = (data.get(job_key, {}) as Dictionary).duplicate(true)
	if data.has("alchemy_workshop_level") and not data.alchemy_workshop_level is int:
		return _invalid("alchemy_workshop_level is not an int")
	normalized["alchemy_workshop_level"] = int(data.get("alchemy_workshop_level", 0))
	if data.has("alchemy_craft_job") and not data.alchemy_craft_job is Dictionary:
		return _invalid("alchemy_craft_job is not a dictionary")
	normalized["alchemy_craft_job"] = (data.get("alchemy_craft_job", {}) as Dictionary).duplicate(true)
	if data.has("runic_workshop_level") and not data.runic_workshop_level is int:
		return _invalid("runic_workshop_level is not an int")
	normalized["runic_workshop_level"] = int(data.get("runic_workshop_level", 0))
	if data.has("runic_craft_job") and not data.runic_craft_job is Dictionary:
		return _invalid("runic_craft_job is not a dictionary")
	normalized["runic_craft_job"] = (data.get("runic_craft_job", {}) as Dictionary).duplicate(true)

	if not data.get("has_trading_post") is bool:
		return _invalid("has_trading_post is not a bool")
	normalized["has_trading_post"] = data.has_trading_post
	if data.has("shop_level") and not data.shop_level is int:
		return _invalid("shop_level is not an int")
	if data.has("shop_gold") and not data.shop_gold is int:
		return _invalid("shop_gold is not an int")
	# Version-one snapshots use their old building flag to infer the first
	# Shop tier and a safe cash pool.
	normalized["shop_level"] = int(data.get("shop_level", 1 if data.has_trading_post else 0))
	normalized["shop_gold"] = int(data.get("shop_gold", 100 if data.has_trading_post else 0))
	if normalized.shop_level < 0 or normalized.shop_level > 3 or normalized.shop_gold < 0:
		return _invalid("shop state is out of range")

	if not data.get("player_name") is String:
		return _invalid("player_name is not a string")
	normalized["player_name"] = data.player_name

	for dict_key in [
		"mana_crystals", "banked_gear", "pending_mana_crystals",
		"pending_gear", "battle_mana_crystals", "battle_gear",
	]:
		if not data.get(dict_key) is Dictionary:
			return _invalid("%s is not a dictionary" % dict_key)
		normalized[dict_key] = (data[dict_key] as Dictionary).duplicate(true)

	# Version-one saves predate owned instances; normalize their absent fields
	# to empty collections so loading an existing campaign remains safe.
	for dict_key in ["owned_item_instances"]:
		if data.has(dict_key) and not data[dict_key] is Dictionary:
			return _invalid("%s is not a dictionary" % dict_key)
		normalized[dict_key] = (data.get(dict_key, {}) as Dictionary).duplicate(true)
	if data.has("banked_item_instance_ids") and not data.banked_item_instance_ids is Array:
		return _invalid("banked_item_instance_ids is not an array")
	var instance_ids_result := _normalize_string_array(data.get("banked_item_instance_ids", []), "banked_item_instance_ids")
	if not instance_ids_result.ok:
		return _invalid(instance_ids_result.error)
	normalized["banked_item_instance_ids"] = instance_ids_result.list

	var tutorial_progress_result := _normalize_tutorial_progress(data.get("tutorial_progress"))
	if not tutorial_progress_result.ok:
		return _invalid(tutorial_progress_result.error)
	normalized["tutorial_progress"] = tutorial_progress_result.value

	if normalized.selected_party_id != "" and not _has_id(normalized.parties, normalized.selected_party_id):
		return _invalid("selected_party_id does not reference a known party")

	# Reaches into GameSession's EXPEDITIONS const table (a compile-time-
	# constant template catalog, not live session state) via preload rather
	# than the GameSession autoload singleton, so a raw template id entered
	# directly -- see get_expedition()'s own dual resolution -- still
	# validates as a legitimate selected_encounter.
	if (
		normalized.selected_encounter != ""
		and not _has_id(normalized.active_encounters, normalized.selected_encounter)
		and not _GameSessionScript.EXPEDITIONS.has(normalized.selected_encounter)
	):
		return _invalid("selected_encounter does not reference a known encounter")

	return {"ok": true, "snapshot": normalized, "error": ""}


static func _invalid(error: String) -> Dictionary:
	return {"ok": false, "snapshot": {}, "error": error}


static func _valid_list(list: Array) -> Dictionary:
	return {"ok": true, "error": "", "list": list}


static func _invalid_list(error: String) -> Dictionary:
	return {"ok": false, "error": error, "list": []}


static func _has_id(list: Array, id: String) -> bool:
	for entry in list:
		if entry.id == id:
			return true
	return false


## Rejects a non-Array field, a non-Dictionary element, an element with a
## missing/empty/non-string "id", or two elements sharing an id. Used for
## the two roster-shaped lists (adventurers, recruitment_candidates), whose
## nested equipment/stats/progression shape is not this contract's concern
## to police -- only the id every other lookup in GameSession keys on.
static func _normalize_id_list(raw: Variant, field_name: String) -> Dictionary:
	if not raw is Array:
		return _invalid_list("%s is not an array" % field_name)

	var seen_ids: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for entry in raw:
		if not entry is Dictionary:
			return _invalid_list("%s contains a non-dictionary entry" % field_name)
		if not entry.get("id") is String or String(entry.id).is_empty():
			return _invalid_list("%s contains an entry with an invalid id" % field_name)
		if seen_ids.has(entry.id):
			return _invalid_list("%s contains a duplicate id: %s" % [field_name, entry.id])
		seen_ids[entry.id] = true
		normalized.append((entry as Dictionary).duplicate(true))
	return _valid_list(normalized)


## The nested per-record normalization pass for roster-shaped lists
## (introduced by the onboarding step; later steps extend it). Today: a
## record without a template_id field infers it when the record's id matches
## a RECRUITMENT_CANDIDATE_TEMPLATES id — legacy saves used the template's
## id as the purchased recruit's / live offer's own id, and template
## claiming now keys on the explicit field. Records whose id matches no
## template keep the field absent; existing records keep their ids verbatim
## (no re-minting).
static func _normalize_roster_records(records: Array[Dictionary]) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for record in records:
		var copy := record.duplicate(true)
		if not copy.has("template_id"):
			var record_id := str(copy.id)
			if _is_recruitment_template_id(record_id):
				copy["template_id"] = record_id

		if copy.has("progression") and copy.progression is Dictionary:
			copy.progression.erase("skill_points")

		var class_id := str(copy.get("class", "warrior"))
		var class_def: Dictionary = _GameSessionScript.CLASS_DEFINITIONS.get(class_id, _GameSessionScript.CLASS_DEFINITIONS.warrior)
		var base_stats: Dictionary = class_def.get("base_stats", {})
		var skills_def: Dictionary = class_def.get("skills", {})
		var level := int(copy.get("level", 1))

		if not copy.has("stats") or not copy.stats is Dictionary:
			copy["stats"] = base_stats.duplicate(true)

		var stats: Dictionary = copy.stats
		var stored_attack: int = int(stats.get("attack", -1))

		# Melee
		var melee_base: int = int(base_stats.get("melee", 60))
		var melee_min_gain: int = int(skills_def.get("melee", {}).get("min_gain", 1))
		var melee_min_track := melee_base + (level - 1) * melee_min_gain
		if stats.has("melee"):
			stats["melee"] = max(int(stats.melee), melee_min_track)
		elif stored_attack != -1:
			stats["melee"] = max(stored_attack, melee_min_track)
		else:
			stats["melee"] = melee_min_track

		# Missile
		var missile_base: int = int(base_stats.get("missile", 60))
		var missile_min_gain: int = int(skills_def.get("missile", {}).get("min_gain", 1))
		var missile_min_track := missile_base + (level - 1) * missile_min_gain
		if stats.has("missile"):
			stats["missile"] = max(int(stats.missile), missile_min_track)
		elif stored_attack != -1:
			stats["missile"] = max(stored_attack, missile_min_track)
		else:
			stats["missile"] = missile_min_track

		stats.erase("attack")

		# Guard
		var guard_base: int = int(base_stats.get("guard", 0))
		var guard_min_gain: int = int(skills_def.get("guard", {}).get("min_gain", 1))
		var guard_min_track := guard_base + (level - 1) * guard_min_gain
		stats["guard"] = max(int(stats.get("guard", 0)), guard_min_track)

		# Might
		var might_base: int = int(base_stats.get("might", 0))
		var might_min_gain: int = int(skills_def.get("might", {}).get("min_gain", 1))
		var might_min_track := might_base + (level - 1) * might_min_gain
		stats["might"] = max(int(stats.get("might", 0)), might_min_track)

		# Vitality and Max Health
		var vitality: int = int(stats.get("vitality", base_stats.get("vitality", 10)))
		stats["vitality"] = vitality
		var calc_max_health := vitality * level
		stats["max_health"] = max(int(stats.get("max_health", 0)), calc_max_health)

		# Health
		var max_hp := int(stats.max_health)
		if copy.has("health"):
			copy["health"] = clampi(int(copy.health), 1, max_hp)
		else:
			copy["health"] = max_hp

		normalized.append(copy)
	return normalized


## Validates progression.perks on already-normalized roster records (see
## _normalize_roster_records()). Each element must be a String naming either
## GameSession.BONUS_MOVE_PERK_ID (the retired-but-still-valid legacy
## universal perk -- see GameSession.choose_perk()'s doc comment for why it
## is never migrated away from an existing holder) or one of the record's
## own class's perk ids (GameSession.CLASS_PERKS); a perk belonging to a
## different class, or any other unrecognized id, fails the *whole* snapshot
## atomically here rather than being silently dropped from just that record.
## A record with no progression field, or a progression with no perks field
## (legacy pre-progression saves), is left alone -- only a present perks
## array is checked. Returns "" when every record passes, or the first
## failure's error message.
static func _validate_perks_field(records: Array[Dictionary], field_name: String) -> String:
	for record in records:
		var progression: Variant = record.get("progression")
		if not progression is Dictionary or not (progression as Dictionary).has("perks"):
			continue
		var perks: Variant = (progression as Dictionary).perks
		if not perks is Array:
			return "%s entry %s has a non-array perks field" % [field_name, record.get("id", "?")]
		var class_id := str(record.get("class", "warrior"))
		var valid_ids: Array = _GameSessionScript.CLASS_PERKS.get(class_id, [])
		var seen: Dictionary = {}
		for perk_id in perks as Array:
			if not perk_id is String:
				return "%s entry %s has a non-string perk id" % [field_name, record.get("id", "?")]
			var id := String(perk_id)
			if id != _GameSessionScript.BONUS_MOVE_PERK_ID and not valid_ids.has(id):
				return "%s entry %s has an unknown or foreign perk id: %s" % [field_name, record.get("id", "?"), id]
			if seen.has(id):
				return "%s entry %s has a duplicate perk id: %s" % [field_name, record.get("id", "?"), id]
			seen[id] = true
	return ""


static func _is_recruitment_template_id(id: String) -> bool:
	for template in _GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		if template.id == id:
			return true
	return false


## Validates and normalizes the five durable campaign-milestone-progression
## fields (see GameSession.CAMPAIGN_OBJECTIVES). A version-1 payload (which
## predates this state) never carries these keys at all -- rather than
## reject it or guess at progress from the legacy completed_encounters list
## (a different id namespace entirely, see this field's own doc comment on
## the class), it normalizes to the same fresh-campaign defaults campaign_
## objective_id/completed_objectives/unlocked_authored_encounters/is_
## campaign_completed/is_free_play_active themselves default to. A current-
## format (version 2) payload is validated strictly: every field must be
## present with the correct type, or the whole import is rejected exactly
## like any other malformed field.
static func _normalize_campaign_progress(data: Dictionary, version: int) -> Dictionary:
	if version == 1:
		return {
			"ok": true,
			"error": "",
			"value": {
				"campaign_objective_id": "obj_tier1_1_goblin_outpost",
				"completed_objectives": [] as Array[String],
				"unlocked_authored_encounters": ["obj_tier1_1_goblin_outpost"] as Array[String],
				"is_campaign_completed": false,
				"is_free_play_active": false,
			},
		}

	if not data.get("campaign_objective_id") is String:
		return {"ok": false, "error": "campaign_objective_id is not a string", "value": {}}

	var completed_result := _normalize_string_array(data.get("completed_objectives"), "completed_objectives")
	if not completed_result.ok:
		return {"ok": false, "error": completed_result.error, "value": {}}

	var unlocked_result := _normalize_string_array(data.get("unlocked_authored_encounters"), "unlocked_authored_encounters")
	if not unlocked_result.ok:
		return {"ok": false, "error": unlocked_result.error, "value": {}}

	if not data.get("is_campaign_completed") is bool:
		return {"ok": false, "error": "is_campaign_completed is not a bool", "value": {}}
	if not data.get("is_free_play_active") is bool:
		return {"ok": false, "error": "is_free_play_active is not a bool", "value": {}}

	return {
		"ok": true,
		"error": "",
		"value": {
			"campaign_objective_id": data.campaign_objective_id,
			"completed_objectives": completed_result.list,
			"unlocked_authored_encounters": unlocked_result.list,
			"is_campaign_completed": data.is_campaign_completed,
			"is_free_play_active": data.is_free_play_active,
		},
	}


## Array[String] fields (completed_encounters, used_encounter_template_ids).
static func _normalize_string_array(raw: Variant, field_name: String) -> Dictionary:
	if not raw is Array:
		return _invalid_list("%s is not an array" % field_name)
	var normalized: Array[String] = []
	for entry in raw:
		if not entry is String:
			return _invalid_list("%s contains a non-string entry" % field_name)
		normalized.append(entry)
	return _valid_list(normalized)


## {"turns_remaining": int} lists (recruitment_vacancies, encounter_vacancies).
static func _normalize_vacancy_list(raw: Variant, field_name: String) -> Dictionary:
	if not raw is Array:
		return _invalid_list("%s is not an array" % field_name)
	var normalized: Array[Dictionary] = []
	for entry in raw:
		if not entry is Dictionary or not entry.get("turns_remaining") is int:
			return _invalid_list("%s contains an invalid vacancy entry" % field_name)
		normalized.append({"turns_remaining": int(entry.turns_remaining)})
	return _valid_list(normalized)


## Rejects a non-Dictionary field, a non-String key, or a non-bool value --
## tighter than the shared "is it a Dictionary" check the other id -> count
## reward stores get, since tutorial_progress's own shape (an arbitrary
## message id -> shown/dismissed bool map, see the field's doc comment
## above) is simple enough to fully police here.
static func _normalize_tutorial_progress(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "tutorial_progress is not a dictionary", "value": {}}
	var normalized: Dictionary = {}
	for key in (raw as Dictionary).keys():
		if not key is String:
			return {"ok": false, "error": "tutorial_progress contains a non-string key", "value": {}}
		var entry_value = raw[key]
		if not entry_value is bool:
			return {"ok": false, "error": "tutorial_progress contains a non-bool value", "value": {}}
		normalized[key] = entry_value
	return {"ok": true, "error": "", "value": normalized}


static func _is_vector2i_dict(value: Variant) -> bool:
	return value is Dictionary and value.get("x") is int and value.get("y") is int


static func _to_vector2i(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.x), int(value.y))


static func _vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _parties_to_dictionary(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for party in source:
		var copy: Dictionary = party.duplicate(true)
		copy["world_position"] = _vector2i_to_dict(party.world_position)
		var route: Array = []
		for step in party.travel_route:
			route.append(_vector2i_to_dict(step))
		copy["travel_route"] = route
		result.append(copy)
	return result


static func _encounters_to_dictionary(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in source:
		var copy: Dictionary = instance.duplicate(true)
		copy["position"] = _vector2i_to_dict(instance.position)
		result.append(copy)
	return result


## Validates and restores each party dict's Vector2i-bearing fields
## (world_position, travel_route). Requires a party's "id" to be a
## non-empty, unique-within-the-list string -- the same shape
## _normalize_id_list() enforces for the roster lists, but parties also
## carry Vector2i-shaped fields those lists never do, so it is validated
## separately rather than reusing that helper. Like _normalize_active_
## encounters(), starts from a duplicate of the raw dict and overwrites only
## the fields it validates/converts, so an unknown/future party key still
## survives an export -> import round trip instead of being silently
## dropped.
static func _normalize_parties(raw: Variant) -> Dictionary:
	if not raw is Array:
		return _invalid_list("parties is not an array")

	var seen_ids: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for raw_party in raw:
		var party_result := _normalize_party(raw_party)
		if not party_result.ok:
			return _invalid_list(party_result.error)
		var party: Dictionary = party_result.value
		if seen_ids.has(party.id):
			return _invalid_list("parties contains a duplicate id: %s" % party.id)
		seen_ids[party.id] = true
		normalized.append(party)
	return _valid_list(normalized)


static func _normalize_party(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "parties contains a non-dictionary entry"}
	var party: Dictionary = raw

	if not party.get("id") is String or String(party.id).is_empty():
		return {"ok": false, "error": "a party entry has an invalid id"}
	if not party.get("member_ids") is Array:
		return {"ok": false, "error": "party %s has an invalid member_ids list" % party.id}
	var member_ids: Array[String] = []
	for member_id in party.member_ids:
		if not member_id is String:
			return {"ok": false, "error": "party %s has a non-string member id" % party.id}
		member_ids.append(member_id)
	if not party.get("location_id") is String:
		return {"ok": false, "error": "party %s has an invalid location_id" % party.id}
	if not _is_vector2i_dict(party.get("world_position")):
		return {"ok": false, "error": "party %s has an invalid world_position" % party.id}
	if not party.get("deployed") is bool:
		return {"ok": false, "error": "party %s has an invalid deployed flag" % party.id}
	if not party.get("travel_route") is Array:
		return {"ok": false, "error": "party %s has an invalid travel_route" % party.id}
	var travel_route: Array[Vector2i] = []
	for step in party.travel_route:
		if not _is_vector2i_dict(step):
			return {"ok": false, "error": "party %s has an invalid travel_route step" % party.id}
		travel_route.append(_to_vector2i(step))
	if not party.get("movement_spent") is bool:
		return {"ok": false, "error": "party %s has an invalid movement_spent flag" % party.id}
	if not party.get("name") is String:
		return {"ok": false, "error": "party %s has an invalid name" % party.id}
	if not party.get("progression") is Dictionary:
		return {"ok": false, "error": "party %s has an invalid progression" % party.id}
	if not party.get("metadata") is Dictionary:
		return {"ok": false, "error": "party %s has an invalid metadata" % party.id}

	var normalized: Dictionary = party.duplicate(true)
	normalized["id"] = String(party.id)
	normalized["member_ids"] = member_ids
	normalized["location_id"] = String(party.location_id)
	normalized["world_position"] = _to_vector2i(party.world_position)
	normalized["deployed"] = bool(party.deployed)
	normalized["travel_route"] = travel_route
	normalized["movement_spent"] = bool(party.movement_spent)
	normalized["name"] = String(party.name)
	normalized["progression"] = (party.progression as Dictionary).duplicate(true)
	normalized["metadata"] = (party.metadata as Dictionary).duplicate(true)

	return {"ok": true, "error": "", "value": normalized}


## Validates and restores each active-encounter instance's Vector2i "position"
## field. Every other key (template_id, name_key, difficulty, enemy, ...)
## mirrors EXPEDITIONS' own template shape, which this contract does not
## police beyond copying it through untouched.
static func _normalize_active_encounters(raw: Variant) -> Dictionary:
	if not raw is Array:
		return _invalid_list("active_encounters is not an array")

	var seen_ids: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for raw_instance in raw:
		if not raw_instance is Dictionary:
			return _invalid_list("active_encounters contains a non-dictionary entry")
		var instance: Dictionary = raw_instance
		if not instance.get("id") is String or String(instance.id).is_empty():
			return _invalid_list("an active encounter entry has an invalid id")
		if seen_ids.has(instance.id):
			return _invalid_list("active_encounters contains a duplicate id: %s" % instance.id)
		if not _is_vector2i_dict(instance.get("position")):
			return _invalid_list("active encounter %s has an invalid position" % instance.id)
		seen_ids[instance.id] = true

		var copy: Dictionary = instance.duplicate(true)
		copy["position"] = _to_vector2i(instance.position)
		normalized.append(copy)
	return _valid_list(normalized)
