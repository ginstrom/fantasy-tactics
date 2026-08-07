extends Node
## Loads config/game_config.json once at startup and exposes typed
## accessors. Falls back to DEFAULTS (which mirrors the shipped JSON
## exactly) if the file is missing or fails to parse, so a corrupted or
## hand-edited config can never crash the game — only silently revert to
## the built-in balance numbers, logged via push_error.

const CONFIG_PATH := "res://config/game_config.json"

const DEFAULTS: Dictionary = {
	"combat": {
		"base_attack": 60,
		"base_max_health": 3,
		"base_move_range": 3,
		"effective_hit_chance_cap": 0.95,
		"attack_to_hit_chance_divisor": 100.0,
	},
	"progression": {
		"level_up_max_health_bonus": 1,
		"level_up_skill_points": 10,
		"perk_level_interval": 3,
	},
	"guild_hall": {
		"level_1_party_cap": 4,
		"level_2_party_cap": 5,
		"upgrade_cost": 50,
		"max_level": 2,
	},
	"population": {
		"encounter_instance_cap": 2,
		"recruitment_offer_cap": 4,
		"encounter_vacancy_turns": 15,
		"recruitment_vacancy_turns": 30,
	},
}

var _data: Dictionary = {}


func _init() -> void:
	_data = _load_from_disk()


func get_int(section: String, key: String, default: int) -> int:
	return int(_data.get(section, {}).get(key, default))


func get_float(section: String, key: String, default: float) -> float:
	return float(_data.get(section, {}).get(key, default))


func _load_from_disk() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("GameConfig: %s not found, using built-in defaults" % CONFIG_PATH)
		return DEFAULTS.duplicate(true)
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("GameConfig: %s is not valid JSON, using built-in defaults" % CONFIG_PATH)
		return DEFAULTS.duplicate(true)
	return json.data


func _parse_or_default(text: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return DEFAULTS.duplicate(true)
	return json.data
