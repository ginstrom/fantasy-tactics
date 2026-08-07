# Code Map

A reference for getting oriented before making a change. This is a map, not
a tutorial — see [running-the-game.md](running-the-game.md) and
[testing.md](testing.md) for task instructions.

## The two autoloads own everything

Two singletons (declared under `[autoload]` in `project.godot`) split the
codebase's responsibilities cleanly. Every scene script is a thin view over
one or both of them.

| Autoload | File | Owns | Never does |
|---|---|---|---|
| `GameManager` | `scripts/autoload/game_manager.gd` | Scene navigation (`go_to_*`, `_change_scene`), short-lived UI routing context (`route_context_id`), thin `Error`-returning wrappers around `GameSession` calls | Hold durable game state |
| `GameSession` | `scripts/autoload/game_session.gd` | All durable session state and game rules: parties, roster, encounters, world position/routing, progression (XP/levels/perks), gold, Guild Hall level | Touch the scene tree |

A scene's `_on_*_pressed()` handler almost always does one of two things:
call a `GameManager.go_to_*()`/action method (which may call into
`GameSession` itself), or call `GameSession` directly and then a
`GameManager` routing method. Read `GameManager`'s method bodies before a
scene's script if you're unsure which layer decides eligibility (e.g. "can
this party deploy?" — that's always `GameSession`; `GameManager.deploy_party()`
is just an `Error`-returning wrapper around `GameSession.deploy_party()`).

## Configuration: `GameConfig` is read-only and loads once

A third autoload, `GameConfig` (`scripts/autoload/game_config.gd`),
loads `config/game_config.json` once at startup and exposes typed
`get_int(section, key, default)`/`get_float(section, key, default)`
accessors. It owns no gameplay state and is never mutated at runtime.
`GameSession` reads sixteen balance constants from it in its own
`_ready()` (combat formula inputs, level-up growth, Guild Hall
caps/cost, population caps/timers — see
`docs/plans/2026-08-07-config-and-automation/02-migrate-balance-constants-to-config.md`
for the exact list and why those sixteen and not others). Every other
`GameSession` constant (ids, the `EXPEDITIONS`/`STAR_ENEMY_COMPOSITIONS`
content tables, grid dimensions) is still a plain code constant — only
genuinely tunable difficulty/balance numbers moved. `GameConfig` is
declared first in `project.godot`'s `[autoload]` list, before
`GameManager`/`GameSession`, specifically so it's fully constructed
before `GameSession._ready()` reads from it.

A missing or malformed `config/game_config.json` never crashes the
game — `GameConfig` falls back to its own built-in `DEFAULTS` (which
mirrors the shipped file exactly) and logs a `push_error`.

## Directory map

`scenes/` and `scripts/` mirror each other by domain:

```
scenes/                          scripts/
├── boot/                        ├── autoload/    GameManager, GameSession (see above)
├── ui/                          ├── battle/      BattleController (Grid node), Battlefield,
│   (encampment, parties,        │                GridScript, Unit, PortraitPanel
│    party_details, add_member,  ├── boot/        entry point → Start Menu
│    deploy_party, roster,       ├── debug/       F9 debug menu + scenario definitions
│    recruitment, units,         ├── local/       starting_settlement.gd (pre-Encampment intro screen)
│    unit_details, start_menu,   ├── tools/       screenshot_tour (non-test tooling)
│    game_menu, information_     ├── ui/          one script per scenes/ui/ scene, plus shared
│    panel, party_manager,       │                widgets (table_view.gd, table_column.gd) —
│    level_up, buildings,        │                note: portrait_panel.gd lives in scripts/battle/
│    guild_hall, camp_nav)       │                above, not here
├── world/                       └── world/       world_map.gd
├── local/
├── battle/
└── debug/
```

`tests/unit/` mirrors this near 1:1 — `test_<script_name>.gd` per script.
If you're looking for how something is meant to behave, its test file is
often more precise than its own source comments.

## Domain model (as tracked by `GameSession`)

- **`adventurers: Array[Dictionary]`** — the full roster, whether or not a
  member is assigned to a party. Each entry: `id`, `name`, `class`,
  `weapon`, `level`, `availability_status`, `stats` (`max_health`, `attack`,
  `move_range` — base values), `progression` (`xp: float`, `skill_points`,
  `perks: Array`).
- **`parties: Array[Dictionary]`** — currently always at most one
  (`FIRST_PARTY_ID = "party_001"`). Each entry: `id`, `member_ids`,
  `location_id`, `world_position: Vector2i`, `deployed: bool`,
  `travel_route: Array[Vector2i]`, `movement_spent: bool`.
- **`EXPEDITIONS: Dictionary`** (constant) — the two encounter *templates*
  (`goblin_camp`, `orc_outpost`): fixed `position`, `reward`, `kill_xp`,
  `clear_xp`, `difficulty` (star tier), and a documented-default `enemy`.
  A live *active instance*'s `enemy` is re-resolved from
  `STAR_ENEMY_COMPOSITIONS[difficulty]` every time it's entered (see
  `enter_encounter()`/`_resolve_enemy_composition()`/
  `enemy_composition_roll`) — 1 star is a fixed single goblin; 2-3 stars
  randomly pick between two goblins-vs-fewer-orcs options.
- **`active_encounters: Array[Dictionary]`** — the *live instances* on the
  World Map right now, each an expedition-shaped dict plus `id` and
  `template_id`. A cleared instance is removed here (not marked complete in
  place) and its id is recorded in `completed_encounters` instead.
- **`recruitment_candidates` / `encounter_vacancies` / `recruitment_vacancies`**
  — the vacancy-timed population system: a cleared encounter or purchased
  recruit starts a countdown (`ENCOUNTER_VACANCY_TURNS` / `RECRUITMENT_VACANCY_TURNS`
  world turns) that refills the slot once it expires, capped at
  `ENCOUNTER_INSTANCE_CAP` / `RECRUITMENT_OFFER_CAP`. See
  `docs/plans/2026-08-06-campaign-progression-and-population/design.md` for
  the rules this implements.
- **`gold` / `pending_reward`** — a battle win adds to `pending_reward`
  immediately; it only moves to `gold` when the party reaches the
  Encampment (`deposit_pending_reward()`, called from
  `GameManager.go_to_encampment()`).

**Effective vs. base stats**: `adventurers[i].stats` holds base values.
Always read combat/display stats through `GameSession.get_effective_*()`
(`get_effective_hit_chance`, `get_effective_max_health`,
`get_effective_move_range`) — these apply the attack→hit-chance formula and
perk bonuses (e.g. the `bonus_move` perk) that the raw stats dict doesn't
reflect on its own.

## The battle scene: two "grid" objects, not one

This is the single most common source of confusion reading battle code —
**there are two distinct things called "grid":**

1. **`BattleController`** (`scripts/battle/battle_controller.gd`) — attached
   to the `Grid` *node* inside `battlefield.tscn`. Owns `units: Array`,
   `selected_unit`, `active_side`, turn/action state, and all the
   `try_move_selected_unit` / `try_attack_selected_unit` / `_handle_tile_click`
   input-handling logic. `Battlefield.gd`'s `@onready var grid: Node2D = $Grid`
   refers to *this*.
2. **`GridScript`** (`scripts/battle/grid.gd`) — a plain `RefCounted` helper
   for tile geometry only (`is_in_bounds`, `get_adjacent`,
   `get_tiles_in_range`). `BattleController` holds one of these as its own
   `grid` member variable (`battle_controller.gd`'s `var grid`);
   `get_tile_distances` runs the identical BFS but also records
   distance-from-start, and is what `battle_controller.gd`'s
   `_move_distances()` uses for both `get_legal_moves()` and
   `try_move_selected_unit()`.

So `battlefield.grid` (the controller) and `battlefield.grid.grid` (the
tile-geometry helper) are two different objects. `scripts/world/world_map.gd`
reuses the same `GridScript` for its own 5×5 board, independently of battle.

**Battle flow**: a click resolves through `BattleController._handle_tile_click`
→ `try_move_selected_unit`/`try_attack_selected_unit` → `board_changed` signal
→ `Battlefield._on_board_changed()` (wired in the `.tscn`) → checks
`grid.is_battle_won()`/`is_battle_lost()` → `_resolve_battle()` (awaits a
short timer for the result banner) → `_apply_battle_outcome()` → XP award,
then `GameManager.complete_battle()` or `GameManager.fail_battle()`. Player
units can also be moved with WASD and selected with the 1-5 number keys
(`battle_controller.gd`'s `MOVE_KEY_DIRECTIONS`/`NUMBER_KEYS`), independent
of the click path described above.

## World Map: routing is turn-based, not real-time

`world_map.gd` maintains its own `party_position`/`hover_route` mirroring
`GameSession`'s stored `world_position`/`travel_route`. A route is built by
clicking a destination (staged as a preview), committed by clicking it
again, and consumed one tile per World Map turn
(`GameSession.take_next_route_step()`, called automatically by
`end_world_turn()` if a step hasn't been manually taken yet that turn).
Standing on an encounter tile and clicking it again activates it
(`try_activate_current_tile()` → `encounter_activated` signal → `.tscn`-wired
`_on_encounter_activated()` → `GameManager.enter_battle()`). The settlement
tile works the same way for returning home.

## Camp navigation: CampNav is a reusable shell, not a router

`scenes/ui/camp_nav.tscn` (`scripts/ui/camp_nav.gd`) is instanced
identically into five top-level camp screens — Encampment, Units,
Buildings, Deploy Party, World Map — to give a persistent left-hand nav.
It renders six buttons, but the Trade button is permanently `disabled` in
the `.tscn` and has no `_on_trade_button_pressed()` handler; there's no
Trade screen yet for it to route to. CampNav has no state of its own
beyond the Deploy Party button's disabled flag (set in `refresh()` from
`GameSession.get_deployable_encamped_parties().is_empty()`) and never
receives a signal from its parent screen — every wired button calls a
`GameManager.go_to_*()` directly. That's the opposite of
`InformationPanel`'s pattern, whose buttons forward a signal
(`party_selected`, `adventurer_selected`, `recruit_selected`) up to the
parent screen instead of routing themselves, since its "View" destination
depends on the parent screen's own selection.

## Progression formulas

Defined once, in `GameSession`, and read everywhere else through its
getters — never re-derive these:

- **XP threshold for level N**: `get_level_xp_threshold(level)` =
  `5 * level * (level + 1) - 10` (level 1 costs 0, level 2 costs 20, each
  step 10 XP more than the last).
- **Hit chance**: `get_effective_hit_chance(id)` = `min(raw_attack / 100.0, 0.95)`.
  Raw Attack itself is never capped.
- **Perks**: one pending choice every `PERK_LEVEL_INTERVAL` (3) levels;
  `is_perk_choice_pending()` / `choose_perk()`.

## Localization

Player-facing strings are never literals in scenes or scripts — they're
stable keys (`menu.new_game`, `battle.end_turn`, ...) resolved through
Godot's `tr()` at render time, defined in `translations/en.tres`. See the
root [`README.md`](../../README.md#localization) for how to add a key; see
`tests/unit/test_localization.gd` for the pattern that verifies every key in
use actually resolves.

## Headless battle simulation

`scripts/tools/battle_bot.gd` (`BattleBot`) and
`scripts/tools/battle_sim.gd`/`battle_sim_main.gd` play full, real
battles with no human input — `BattleBot` picks player actions with the
same "move toward nearest living opponent, attack if adjacent" policy
`BattleController._take_enemy_unit_actions()` already uses for the enemy
side, and `battle_sim.gd` drives a real `battlefield.tscn` instance
through to `GameManager.complete_battle()`/`fail_battle()`, including
auto-resolving any level-up modal a battle's XP award queues (see
`docs/plans/2026-08-07-config-and-automation/04-headless-battle-sim-and-logging.md`
for why that's necessary — Orc Outpost's kill+clear XP always crosses
the level-2 threshold). Run via `make simulate`; see
[running-the-game.md](running-the-game.md#run-the-headless-battle-simulator).
This exists for balance/AI-tuning data (damage/kills/gold per battle),
not for testing — `tests/unit/test_battle_bot.gd` already covers
`BattleBot`'s decision logic in isolation without needing a real battle.
