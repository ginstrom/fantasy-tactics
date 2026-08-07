# Task 2: Migrate `GameSession`'s balance constants onto `GameConfig`

## Objective

Make `GameSession`'s sixteen tunable balance constants read from
`GameConfig` instead of being hardcoded literals, with **zero** change to
their actual values or to any existing external call site's syntax
(`GameSession.GUILD_HALL_UPGRADE_COST` etc. keeps working unchanged).

## Why this task's "red" step looks different

This is a refactor, not new behavior — the numbers don't change, so a naive
"assert the value is still 50" test would pass before you've written any
code and proves nothing. The real risk here is mechanical: GDScript
`const`s are accessible either through the singleton instance
(`GameSession.GUILD_HALL_UPGRADE_COST`, used by `scripts/ui/guild_hall.gd`
and most tests) **or** through the preloaded script class
(`GameSessionScript.DEFAULT_WARRIOR`, used by several tests in
`test_game_session.gd`) — but once a `const` becomes an instance `var`,
only the singleton-instance form still resolves; `GameSessionScript.X`
becomes a compile error. So the genuine "red" signal for this task is: make
the conversion, run the full suite, and watch it fail at exactly those
`GameSessionScript.X` call sites — then fix them. Steps 1-2 below do the
conversion; step 3 is where you'll see the real failures; steps 4-5 fix
them.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_unit_details.gd` (one comment only)

## Steps

1. In `scripts/autoload/game_session.gd`, replace the constant block at
   lines 85-97 (`const BASE_ATTACK := 60` through
   `const ATTACK_TO_HIT_CHANCE_DIVISOR := 100.0`) with:

   ```gdscript
   # Balance values below default to GameConfig's own DEFAULTS and are
   # overwritten from config/game_config.json in _ready() (see
   # docs/plans/2026-08-07-config-and-automation). They stay UPPER_SNAKE_CASE
   # vars, not real consts, specifically so every existing
   # GameSession.SOME_CONSTANT call site keeps working unchanged — GDScript
   # exposes both consts and vars the same way through a singleton instance.
   var BASE_ATTACK: int = 60
   var BASE_MAX_HEALTH: int = 3
   var BASE_MOVE_RANGE: int = 3
   var LEVEL_UP_MAX_HEALTH_BONUS: int = 1
   var LEVEL_UP_SKILL_POINTS: int = 10
   var PERK_LEVEL_INTERVAL: int = 3
   const BONUS_MOVE_PERK_ID := "bonus_move"
   var GUILD_HALL_LEVEL_1_PARTY_CAP: int = 4
   var GUILD_HALL_LEVEL_2_PARTY_CAP: int = 5
   var GUILD_HALL_UPGRADE_COST: int = 50
   var GUILD_HALL_MAX_LEVEL: int = 2
   var EFFECTIVE_HIT_CHANCE_CAP: float = 0.95
   var ATTACK_TO_HIT_CHANCE_DIVISOR: float = 100.0
   ```

   And the population block at lines 105-108 with:

   ```gdscript
   var ENCOUNTER_INSTANCE_CAP: int = 2
   var RECRUITMENT_OFFER_CAP: int = 4
   var ENCOUNTER_VACANCY_TURNS: int = 15
   var RECRUITMENT_VACANCY_TURNS: int = 30
   ```

   Leave `ENCOUNTER_TEMPLATE_ORDER`, `WORLD_GRID_WIDTH`/`HEIGHT`,
   `WARRIOR_ID`, and everything else untouched — only these sixteen values
   move (see index.md's "Design decisions" for why).

2. Replace the `const DEFAULT_WARRIOR := { ... }` block (lines 119-140) with
   a function — it can no longer be a `const` because it now references
   instance vars (`BASE_MAX_HEALTH` etc.), and GDScript `const` values must
   be resolvable at compile time:

   ```gdscript
   func get_default_warrior() -> Dictionary:
   	return {
   		"id": WARRIOR_ID,
   		"name": "Warrior",
   		"class": "warrior",
   		"weapon": "sword",
   		"level": 1,
   		"availability_status": "available",
   		# Authored base combat values; effective values (hit chance, max health,
   		# move range) are derived from these plus progression by GameSession.
   		"stats": {
   			"max_health": BASE_MAX_HEALTH,
   			"attack": BASE_ATTACK,
   			"move_range": BASE_MOVE_RANGE,
   		},
   		# Durable leveling state. xp is a float so fractional party XP awards are
   		# never truncated; display-facing rounding is a UI concern.
   		"progression": {
   			"xp": 0.0,
   			"skill_points": 0,
   			"perks": [],
   		},
   	}
   ```

   Update its three call sites to call the function instead of duplicating
   the const:
   - `reset()`: `adventurers = [DEFAULT_WARRIOR.duplicate(true)]` →
     `adventurers = [get_default_warrior()]` (the function already returns a
     fresh dict every call, so `.duplicate(true)` is redundant here).
   - `recruit_adventurer()` (line 393):
     `var adventurer: Dictionary = DEFAULT_WARRIOR.duplicate(true)` →
     `var adventurer: Dictionary = get_default_warrior()`.
   - `_seed_adventurer_baseline_stats()` (lines 411-412):
     `record["stats"] = DEFAULT_WARRIOR.stats.duplicate(true)` →
     `record["stats"] = get_default_warrior().stats.duplicate(true)`, and
     `record["progression"] = DEFAULT_WARRIOR.progression.duplicate(true)` →
     `record["progression"] = get_default_warrior().progression.duplicate(true)`.

3. Add a new `_ready()` right after the existing `_init()` (which still
   just calls `reset()` — leave it alone) that overwrites every migrated
   var from `GameConfig`, then re-runs `reset()` so the very first real
   campaign state (not just the `_init()`-time placeholder one) uses the
   config-sourced values:

   ```gdscript
   func _ready() -> void:
   	_load_balance_config()
   	reset()


   func _load_balance_config() -> void:
   	BASE_ATTACK = GameConfig.get_int("combat", "base_attack", BASE_ATTACK)
   	BASE_MAX_HEALTH = GameConfig.get_int("combat", "base_max_health", BASE_MAX_HEALTH)
   	BASE_MOVE_RANGE = GameConfig.get_int("combat", "base_move_range", BASE_MOVE_RANGE)
   	EFFECTIVE_HIT_CHANCE_CAP = GameConfig.get_float("combat", "effective_hit_chance_cap", EFFECTIVE_HIT_CHANCE_CAP)
   	ATTACK_TO_HIT_CHANCE_DIVISOR = GameConfig.get_float("combat", "attack_to_hit_chance_divisor", ATTACK_TO_HIT_CHANCE_DIVISOR)
   	LEVEL_UP_MAX_HEALTH_BONUS = GameConfig.get_int("progression", "level_up_max_health_bonus", LEVEL_UP_MAX_HEALTH_BONUS)
   	LEVEL_UP_SKILL_POINTS = GameConfig.get_int("progression", "level_up_skill_points", LEVEL_UP_SKILL_POINTS)
   	PERK_LEVEL_INTERVAL = GameConfig.get_int("progression", "perk_level_interval", PERK_LEVEL_INTERVAL)
   	GUILD_HALL_LEVEL_1_PARTY_CAP = GameConfig.get_int("guild_hall", "level_1_party_cap", GUILD_HALL_LEVEL_1_PARTY_CAP)
   	GUILD_HALL_LEVEL_2_PARTY_CAP = GameConfig.get_int("guild_hall", "level_2_party_cap", GUILD_HALL_LEVEL_2_PARTY_CAP)
   	GUILD_HALL_UPGRADE_COST = GameConfig.get_int("guild_hall", "upgrade_cost", GUILD_HALL_UPGRADE_COST)
   	GUILD_HALL_MAX_LEVEL = GameConfig.get_int("guild_hall", "max_level", GUILD_HALL_MAX_LEVEL)
   	ENCOUNTER_INSTANCE_CAP = GameConfig.get_int("population", "encounter_instance_cap", ENCOUNTER_INSTANCE_CAP)
   	RECRUITMENT_OFFER_CAP = GameConfig.get_int("population", "recruitment_offer_cap", RECRUITMENT_OFFER_CAP)
   	ENCOUNTER_VACANCY_TURNS = GameConfig.get_int("population", "encounter_vacancy_turns", ENCOUNTER_VACANCY_TURNS)
   	RECRUITMENT_VACANCY_TURNS = GameConfig.get_int("population", "recruitment_vacancy_turns", RECRUITMENT_VACANCY_TURNS)
   ```

   `_ready()` (not `_init()`) is deliberate: reading another autoload from
   `_init()` would be a new pattern for this codebase and depends on
   cross-autoload construction ordering that's easy to get subtly wrong.
   `_ready()` only relies on autoload *declaration order* (`GameConfig`
   before `GameSession` in `project.godot`, done in Task 1), which
   `GameManager._ready()` already relies on today for its own children.

4. Run the full suite and read the failures — expect compile/reference
   errors, not assertion failures, at every remaining
   `GameSessionScript.DEFAULT_WARRIOR`, `GameSessionScript.ENCOUNTER_VACANCY_TURNS`,
   and `GameSessionScript.RECRUITMENT_VACANCY_TURNS` reference:

   ```bash
   make check
   ```

5. Fix every failure by switching from the preloaded-script form to the
   singleton-instance form, and from the const to the new function where
   applicable. In `tests/unit/test_game_session.gd`:
   - `GameSessionScript.DEFAULT_WARRIOR` → `GameSession.get_default_warrior()`
     (appears at the assertions that were at lines 38, 138, 370, and the
     `.stats.max_health`/`.stats.attack`/`.progression.skill_points` reads
     around line 1158-1169).
   - `GameSessionScript.ENCOUNTER_VACANCY_TURNS` → `GameSession.ENCOUNTER_VACANCY_TURNS`
     (the loop bounds and assertions around lines 1495-1805).
   - `GameSessionScript.RECRUITMENT_VACANCY_TURNS` → `GameSession.RECRUITMENT_VACANCY_TURNS`
     (around lines 1707-1738).

   In `tests/unit/test_unit_details.gd`, line 123 is a comment referencing
   `GameSession.DEFAULT_WARRIOR` — update the wording to
   `GameSession.get_default_warrior()` so it doesn't describe a symbol that
   no longer exists.

6. Rerun the full suite; expect green with no other changes:

   ```bash
   make check
   ```

7. Add one genuinely new regression test per migrated cluster, proving the
   value really is config-sourced rather than a coincidental duplicate
   literal. Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_balance_constants_match_the_loaded_config() -> void:
   	assert_eq(GameSession.BASE_ATTACK, GameConfig.get_int("combat", "base_attack", -1))
   	assert_eq(GameSession.GUILD_HALL_UPGRADE_COST, GameConfig.get_int("guild_hall", "upgrade_cost", -1))
   	assert_eq(GameSession.ENCOUNTER_VACANCY_TURNS, GameConfig.get_int("population", "encounter_vacancy_turns", -1))
   ```

   Run it (`-gselect=test_game_session.gd`) and confirm it passes.

8. Manually verify no balance number visibly changed: run `make play`,
   start a New Campaign, open Unit Details for the starting Warrior (Attack
   60, Max Health 3), and open Buildings → Guild Hall (upgrade cost 50
   gold). These must match the existing screenshots in `./screenshots/`
   (`12_unit_details_from_roster.png`, `03_encampment.png` and friends).

9. Commit:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd tests/unit/test_unit_details.gd
   git commit -m "refactor: source GameSession balance constants from GameConfig"
   ```

## Milestone

Every one of the sixteen balance constants is read from
`config/game_config.json` through `GameConfig`, with identical runtime
values to before this task, no broken external call sites, and a
regression test that would catch future drift between `GameSession`'s
default and the shipped config file.
