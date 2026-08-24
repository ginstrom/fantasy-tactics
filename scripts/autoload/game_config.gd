extends Node
## Loads config/game_config.json once at startup and exposes typed
## accessors. Falls back to DEFAULTS (which mirrors the shipped JSON
## exactly) if the file is missing or fails to parse, so a corrupted or
## hand-edited config can never crash the game — only silently revert to
## the built-in balance numbers, logged via push_error.

const CONFIG_PATH := "res://config/game_config.json"

const DEFAULTS: Dictionary = {
	"combat": {
		"base_move_range": 3,
		"effective_hit_chance_cap": 0.95,
		"attack_to_hit_chance_divisor": 100.0,
		"base_critical_chance": 0.05,
		"critical_damage_multiplier": 1.5,
		"critical_resistance_reduction": 20,
		"side_flank_guard_penalty": 20,
		"side_flank_crit_bonus": 0.20,
		"rear_flank_guard_penalty": 50,
		"rear_flank_crit_bonus": 0.50,
		"cover_low_missile_guard_bonus": 25,
		"cover_high_missile_guard_bonus": 50,
		"dodge_chance": 0.10,
		"parry_chance": 0.10,
		"off_balance_guard_penalty": 10,
		"parry_counter_melee_hit_bonus": 0.10,
		"opportunity_attack_melee_hit_penalty": 0.10,
		"lock_on_hit_chance_bonus": 0.10,
		"called_shot_to_hit_penalty": 0.10,
	},
	"progression": {
		"perk_level_interval": 2,
		"perk_tree_size": 2,
		"warrior_juggernaut_hp_percent": 15,
		"warrior_bulwark_guard": 10,
		"scout_quickdraw_action_points": 1,
		"scout_keen_eyes_intel_range_bonus": 1,
		"cleric_meditation_spell_range_bonus": 1,
		"cleric_devout_hp_percent": 10,
	},
	"healing": {
		"encamped_rate": 3,
		"resting_rate": 2,
		"moving_rate": 1,
		"encamped_mp_rate": 6,
		"resting_mp_rate": 4,
		"moving_mp_rate": 2,
		"temple_hp_bonus_per_tier": 1,
	},
	"guild_hall": {
		"level_1_party_cap": 3,
		"level_2_party_cap": 4,
		"level_3_party_cap": 5,
		"upgrade_cost": 50,
		"level_3_upgrade_cost": 100,
		"max_level": 3,
		"level_1_roster_cap": 10,
		"level_2_roster_cap": 15,
		"level_3_roster_cap": 20,
		"level_2_offer_cap": 8,
		"level_3_offer_cap": 10,
	},
	"population": {
		"encounter_instance_cap": 2,
		"recruitment_offer_cap": 4,
		"encounter_vacancy_turns": 15,
		"recruitment_vacancy_turns": 30,
		"encounter_vacancy_jitter_turns": 5,
		"recruitment_vacancy_jitter_turns": 5,
	},
	"shop": {
		"level_1_income": 2,
		"level_2_income": 5,
		"level_3_income": 10,
		"level_2_upgrade_cost": 150,
		"level_3_upgrade_cost": 300,
	},
	"temple": {
		"build_cost": 100,
	},
	"cleric": {
		"mp_max": 3,
		"details_heal_mp_cost": 1,
		"details_heal_min": 2,
		"details_heal_max": 8,
	},
	# Mage's own mp_max (Stage 5 D3): a second, independent config-driven
	# spellcasting resource pool, same magnitude as Cleric's but never sharing
	# CLERIC_MP_MAX's var -- see GameSession.MAGE_MP_MAX/get_effective_max_mp().
	"mage": {
		"mp_max": 3,
	},
	"intelligence": {
		"watchtower_tier_1_cost": 50,
		"watchtower_tier_2_cost": 100,
		"watchtower_tier_3_cost": 200,
		"watchtower_tier_1_detection": 50,
		"watchtower_tier_2_detection": 65,
		"watchtower_tier_3_detection": 75,
		"base_encampment_detection": 25,
		"quest_duration_turns_per_tier": 10,
		"quest_posting_block_turns_per_tier": 5,
		"quest_reward_percent": 50,
		"quest_posting_chance_percent": 50,
		"quest_tier_cap_level_1": 1,
		"quest_tier_cap_level_2": 2,
		"quest_tier_cap_level_3": 4,
		"quest_tier_cap_level_4": 5,
		"scout_scouting_skill": 20,
	},
	# Stage 5 D5 (decision-ledger.md, Step 6): the pre-existing threat-star
	# escalation interval (see GameSession.get_threat_stars()), finally
	# GameConfig-backed rather than a plain constant -- the value itself is
	# unchanged, only its home moves. See GameSession.THREAT_TURN_INTERVAL.
	"world_map": {
		"threat_turn_interval": 15,
	},
}

var _data: Dictionary = {}


func _init() -> void:
	_data = _load_from_disk()


func get_int(section: String, key: String, default: int) -> int:
	return int(_data.get(section, {}).get(key, default))


func get_float(section: String, key: String, default: float) -> float:
	return float(_data.get(section, {}).get(key, default))


## Reads the config file's raw text and hands it to _parse_or_default, which
## owns the single copy of the parse-or-fall-back-to-DEFAULTS logic. Every
## failure mode here (absent file, unreadable file, unparseable text) lands on
## the same DEFAULTS.duplicate(true), so booting can never crash on config.
func _load_from_disk() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("GameConfig: %s not found, using built-in defaults" % CONFIG_PATH)
		return DEFAULTS.duplicate(true)
	# file_exists() passing does not guarantee open() succeeds — permissions or
	# a deletion racing this read still hand back null, and calling
	# get_as_text() on that would crash the autoload during boot.
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error(
			(
				"GameConfig: %s could not be opened (error %d), using built-in defaults"
				% [CONFIG_PATH, FileAccess.get_open_error()]
			)
		)
		return DEFAULTS.duplicate(true)
	return _parse_or_default(file.get_as_text())


func _parse_or_default(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("GameConfig: %s is not valid JSON, using built-in defaults" % CONFIG_PATH)
		return DEFAULTS.duplicate(true)
	return json.data
