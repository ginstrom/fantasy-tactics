# Task 1: `GameConfig` autoload

## Objective

Add a third autoload, `GameConfig`, that loads `config/game_config.json`
once at startup and exposes typed `get_int`/`get_float` accessors, falling
back to a built-in `DEFAULTS` dictionary if the file is missing or invalid.
Nothing reads from it yet — that's Task 2.

## Files

- Create: `config/game_config.json`
- Create: `scripts/autoload/game_config.gd`
- Create: `tests/unit/test_game_config.gd`
- Modify: `project.godot`

## Steps

1. Create `config/game_config.json`:

   ```json
   {
   	"combat": {
   		"base_attack": 60,
   		"base_max_health": 3,
   		"base_move_range": 3,
   		"effective_hit_chance_cap": 0.95,
   		"attack_to_hit_chance_divisor": 100.0
   	},
   	"progression": {
   		"level_up_max_health_bonus": 1,
   		"level_up_skill_points": 10,
   		"perk_level_interval": 3
   	},
   	"guild_hall": {
   		"level_1_party_cap": 4,
   		"level_2_party_cap": 5,
   		"upgrade_cost": 50,
   		"max_level": 2
   	},
   	"population": {
   		"encounter_instance_cap": 2,
   		"recruitment_offer_cap": 4,
   		"encounter_vacancy_turns": 15,
   		"recruitment_vacancy_turns": 30
   	}
   }
   ```

   These are exactly `GameSession`'s current hardcoded values (see
   `scripts/autoload/game_session.gd:85-108`) — this task only adds the
   loader; Task 2 is what makes `GameSession` actually read them.

2. Write `tests/unit/test_game_config.gd` (failing — `GameConfig` doesn't
   exist yet):

   ```gdscript
   extends GutTest

   const GameConfigScript := preload("res://scripts/autoload/game_config.gd")


   func test_loads_int_values_from_the_real_config_file() -> void:
   	assert_eq(GameConfig.get_int("guild_hall", "upgrade_cost", -1), 50)
   	assert_eq(GameConfig.get_int("population", "encounter_vacancy_turns", -1), 15)


   func test_loads_float_values_from_the_real_config_file() -> void:
   	assert_eq(GameConfig.get_float("combat", "effective_hit_chance_cap", -1.0), 0.95)


   func test_missing_key_returns_the_provided_default() -> void:
   	assert_eq(GameConfig.get_int("guild_hall", "no_such_key", 999), 999)


   func test_missing_section_returns_the_provided_default() -> void:
   	assert_eq(GameConfig.get_int("no_such_section", "upgrade_cost", 999), 999)


   func test_malformed_json_falls_back_to_defaults() -> void:
   	var config = GameConfigScript.new()
   	autofree(config)

   	var parsed: Dictionary = config._parse_or_default("{not valid json")

   	assert_eq(parsed, GameConfigScript.DEFAULTS)


   func test_valid_json_text_is_parsed_as_is() -> void:
   	var config = GameConfigScript.new()
   	autofree(config)

   	var parsed: Dictionary = config._parse_or_default('{"combat": {"base_attack": 99}}')

   	assert_eq(parsed, {"combat": {"base_attack": 99}})
   ```

3. Run the focused suite and confirm it fails because `GameConfig` (the
   autoload singleton) doesn't exist:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_config.gd -gexit
   ```

   Expected: parser/compile errors referencing an undefined `GameConfig`
   identifier.

4. Create `scripts/autoload/game_config.gd`:

   ```gdscript
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
   	return _parse_or_default(file.get_as_text())


   func _parse_or_default(text: String) -> Dictionary:
   	var parsed = JSON.parse_string(text)
   	if typeof(parsed) != TYPE_DICTIONARY:
   		push_error("GameConfig: %s is not valid JSON, using built-in defaults" % CONFIG_PATH)
   		return DEFAULTS.duplicate(true)
   	return parsed
   ```

5. Register the autoload in `project.godot`, **before** `GameManager`/
   `GameSession` (Task 2 needs `GameConfig` fully constructed by the time
   `GameSession` reads from it):

   ```
   [autoload]

   GameConfig="*res://scripts/autoload/game_config.gd"
   GameManager="*res://scripts/autoload/game_manager.gd"
   GameSession="*res://scripts/autoload/game_session.gd"
   ```

6. Rerun the focused suite; expect all six tests green:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_config.gd -gexit
   ```

7. Run the full suite to confirm adding a third autoload didn't disturb
   anything else:

   ```bash
   make check
   ```

8. Commit:

   ```bash
   git add config/game_config.json scripts/autoload/game_config.gd tests/unit/test_game_config.gd project.godot
   git commit -m "feat: add GameConfig autoload for JSON-backed balance values"
   ```

## Milestone

`GameConfig.get_int(...)`/`GameConfig.get_float(...)` reliably return the
shipped config file's values anywhere in the game, with a tested fallback
for a missing or broken file. Nothing consumes it yet — `make check` is
green with the exact same behavior as before this task.
