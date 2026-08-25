# Code Map

A reference for getting oriented before making a change. This is a map, not
a tutorial — see [running-the-game.md](running-the-game.md) and
[testing.md](testing.md) for task instructions.

## The autoloads have distinct responsibilities

Three singletons (declared under `[autoload]` in `project.godot`) split the
codebase's responsibilities cleanly. Every scene script is a thin view over
one or both gameplay autoloads; `GameConfig` supplies read-only configuration.

| Autoload | File | Owns | Never does |
|---|---|---|---|
| `GameConfig` | `scripts/autoload/game_config.gd` | Read-only, typed access to `config/game_config.json` with built-in fallback defaults | Hold gameplay state or mutate configuration at runtime |
| `GameManager` | `scripts/autoload/game_manager.gd` | Scene navigation (`go_to_*`, `_change_scene`), short-lived UI routing context (`route_context_id`), thin `Error`-returning wrappers around `GameSession` calls | Hold durable game state |
| `GameSession` | `scripts/autoload/game_session.gd` | All durable session state and game rules: parties, roster, encounters, world position/routing, progression (XP/levels/perks), stores/item ownership, and building/workshop jobs | Touch the scene tree |

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
`GameSession._load_balance_config()` reads every tunable balance constant
from it in `_ready()` — combat formula inputs, level-up growth, Guild Hall
and Shop caps/costs, population caps/timers (see that function for
the exact list). Every other `GameSession` constant (ids, the `EXPEDITIONS`/
`STAR_ENEMY_COMPOSITIONS`/`WEAPONS`/`ARMORS`/`ENEMY_LOOT_TABLES` content
tables, grid dimensions) is still a plain code constant — only genuinely
tunable difficulty/balance numbers moved. `GameConfig` is declared first in
`project.godot`'s `[autoload]` list, before `GameManager`/`GameSession`,
specifically so it's fully constructed before `GameSession._ready()` reads
from it.

A missing or malformed `config/game_config.json` never crashes the
game — `GameConfig` falls back to its own built-in `DEFAULTS` (which
mirrors the shipped file exactly) and logs a `push_error`. Every failure
mode (absent file, unopenable file, unparseable text) funnels through the
single `_parse_or_default()` fallback, and `tests/unit/test_game_config.gd`
locks `DEFAULTS` to the shipped file key by key so the two cannot drift.

## Directory map

`scenes/` and `scripts/` mirror each other by domain:

```
scenes/                          scripts/
├── boot/                        ├── autoload/    GameConfig, GameManager, GameSession (see above)
├── ui/                          ├── battle/      BattleController (Grid node), Battlefield,
│   (encampment, parties,        │                GridScript, Unit, PortraitPanel,
│    party_details, add_member,  │                UnitInfoPanel
│    deploy_party, roster,       ├── boot/        entry point → Start Menu
│    recruitment, units,         ├── debug/       F9 debug menu + scenario definitions
│    unit_details, start_menu,   ├── local/       starting_settlement.gd (pre-Encampment intro screen)
│    game_menu, battle_result,   ├── save/        campaign_snapshot.gd, save_repository.gd
│    campaign_guide,             ├── tools/       screenshot_tour, battle_bot.gd, battle_sim.gd,
│    information_panel,          │                battle_scenarios/ (runner & policy tools)
│    loot_detail_panel,          ├── ui/          one script per scenes/ui/ scene, plus shared
│    loot_table, party_manager,  │                widgets (table_view.gd, table_column.gd) —
│    level_up, buildings,        │                note: portrait_panel.gd lives in scripts/battle/
│    guild_hall, blacksmith,     │                above, not here
│    alchemy_workshop,           └── world/       world_map.gd
│    runic_workshop, trade,
│    stores, trading_post,
│    sell_quantity_dialog,
│    assign_equipment,
│    card_navigator,
│    camp_nav)
├── world/
├── local/
├── battle/
└── debug/
```

`tests/unit/` mirrors this near 1:1 — `test_<script_name>.gd` per script.
If you're looking for how something is meant to behave, its test file is
often more precise than its own source comments.

## Domain model (as tracked by `GameSession`)

- **`adventurers: Array[Dictionary]`** — the full roster, whether or not a
  member is assigned to a party. Each entry: `id`, `name`, `class`, and
  `equipment` (active `weapon`/`armor` ids plus their inventories and
  `potion_inventory`; item ids resolve through `GameSession.get_item_definition()`),
  along with `level`, `availability_status`, `health` (durable current health, `1 <= health <= max_health`),
  `stats` (`max_health`, `vitality`, `melee`, `missile`, `guard`, `might`, `move_range` — base and class-growth values),
  and progression (`xp: float`, `perks: Array`). Natural recovery occurs during `end_world_turn()`
  (encamped: 4, resting: 2, moving: 1). Identity is generated: every newly minted unit gets a
  collision-free GUID-style id from `_new_instance_id()` (injectable via
  `instance_id_roll`); names are cosmetic per-class counter strings, and
  records minted from a recruitment template carry its `template_id`
  (legacy sequential ids like `warrior_001` persist as opaque strings).
  See "Trade, equipment, and loot" in
  [`docs/designs/weapon-armor-inventory.md`](../designs/weapon-armor-inventory.md) and
  [`docs/designs/equipment-handbook.md`](../designs/equipment-handbook.md)
  for the catalog and combat formulas.
- **`parties: Array[Dictionary]`** — capped at `get_max_party_count()`
  (currently 1; the first party is `FIRST_PARTY_ID = "party_001"`), with a
  per-party size cap from `get_max_party_size()` (Guild Hall level). Each
  entry: `id`, `member_ids`, `location_id`, `world_position: Vector2i`,
  `deployed: bool`, `travel_route: Array[Vector2i]`, `movement_spent: bool`.
- **`EXPEDITIONS: Dictionary`** (constant) — the three encounter *templates*
  (`goblin_camp`, `orc_outpost`, `ruined_fortress`): fixed `position`,
  `clear_xp`, `difficulty` (star tier), and a documented-default `enemy`.
  (Per-monster kill XP lives on each enemy's own `*_ENEMY_STATS` const).
  A live *active instance*'s `enemy` is re-resolved from
  `STAR_ENEMY_COMPOSITIONS[difficulty]` every time it's entered (see
  `enter_encounter()`/`_resolve_enemy_composition()`/
  `enemy_composition_roll`) — 1 star is a fixed single goblin; 2 stars
  randomly pick between goblins or an orc; 3 stars randomly pick among
  kobolds, goblins, orcs, or hobgoblins.
- **`active_encounters: Array[Dictionary]`** — the *live instances* on the
  World Map right now, each an expedition-shaped dict plus `id` and
  `template_id`. A cleared instance is removed here (not marked complete in
  place) and its id is recorded in `completed_encounters` instead.
- **`recruitment_candidates` / `encounter_vacancies` / `recruitment_vacancies`**
  — the vacancy-timed population system: a cleared encounter or purchased
  recruit starts a countdown, resolved once via `vacancy_delay_roll`/
  `_resolve_vacancy_delay()` to a random value within
  `ENCOUNTER_VACANCY_TURNS`/`RECRUITMENT_VACANCY_TURNS` +/-
  `ENCOUNTER_VACANCY_JITTER_TURNS`/`RECRUITMENT_VACANCY_JITTER_TURNS` world
  turns, that refills the slot once it expires, capped at
  `ENCOUNTER_INSTANCE_CAP` / `RECRUITMENT_OFFER_CAP`. A fresh campaign
  seeds all four `RECRUITMENT_CANDIDATE_TEMPLATES` as live offers; every
  offer is a fresh record with a generated `id` plus a `template_id` when it
  claims a fixed-pool template (overflow refills carry none), and a template
  is claimed iff any roster member or live offer carries its `template_id`
  (`_is_recruitment_template_claimed`).
- **`gold` / `pending_reward` / `battle_reward`** — a battle win adds to
  `battle_reward` (the current battle's own, not-yet-shared loot); it moves
  to `pending_reward` when the player leaves the victory summary for the
  World Map (`merge_battle_loot_into_party()`, called from
  `GameManager.go_to_world_map()`), and from there to `gold` only once the
  party reaches the Encampment (`deposit_pending_reward()`, called from
  `GameManager.go_to_encampment()`).
- **`mana_crystals` / `banked_gear`** — permanent, stackable loot storage, populated by
  `deposit_pending_reward()` from the matching `pending_mana_crystals` /
  `pending_gear` fields queued on encounter victory (see
  `_roll_and_queue_loot()`). `shop_level` gates selling
  (`sell_item()`) and buying (`buy_item()`); `WEAPONS`/`ARMORS`/
  `ENEMY_LOOT_TABLES` are the backing content tables — see
  [`docs/designs/weapon-armor-inventory.md`](../designs/weapon-armor-inventory.md).
- **`owned_item_instances` / `banked_item_instance_ids`** — unique records
  for modified gear. Each instance identifies an immutable base item and its
  treatment, enhancement, and rune modifiers; instance ids are generated by
  the same `_new_instance_id()` helper (callers never supply ids —
  `materialize_banked_item_instance(base_item_id)` mints and returns one).
  An owned instance has exactly one durable location: banked or in the
  matching adventurer inventory.
- **Workshop state** — `blacksmith_level` plus independent craft/sharpening
  jobs, `alchemy_workshop_level` plus one potion-craft job, and
  `runic_workshop_level` plus one rune job. `end_world_turn()` advances their
  absolute completion-turn records; scenes only render and request the
  `GameSession` operations.

**Effective vs. base stats**: `adventurers[i].stats` holds base values.
Always read combat/display stats through `GameSession.get_effective_*()`
(`get_effective_hit_chance`, `get_effective_max_health`,
`get_effective_move_range`, `get_effective_weapon_damage_range`,
`get_effective_weapon_name`, `get_effective_defense`,
`get_effective_resistance`, `get_effective_armor_name`) — these apply the
attack→hit-chance formula and perk bonuses (e.g. the `bonus_move` perk) that
the raw stats dict doesn't reflect on its own.

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
   for tile geometry only: `is_in_bounds`, `get_adjacent`,
   `get_tiles_in_range`, `get_shortest_path` (a deterministic BFS route from
   start to target, retaining predecessors so callers that need the actual
   route, not just its cost, can walk it), and `is_attack_adjacent`
   (eight-directional, combat-only adjacency for range-1 melee weapons —
   movement/pathing itself stays cardinal-only via `get_adjacent`).
   `BattleController` holds one of these as its own `grid` member variable
   (`battle_controller.gd`'s `var grid`); `get_tile_distances` runs the
   identical BFS but also records distance-from-start, and is what
   `battle_controller.gd`'s `_move_distances()` uses for
   `get_legal_moves()`'s reachable/highlight set. `try_move_selected_unit()`,
   however, bypasses `_move_distances()` and calls `grid.get_shortest_path()`
   directly, using it both to validate that the destination is reachable
   within the unit's remaining AP and to derive the unit's final facing from
   the route's last step.

So `battlefield.grid` (the controller) and `battlefield.grid.grid` (the
tile-geometry helper) are two different objects. `scripts/world/world_map.gd`
reuses the same `GridScript` for its own 7×7 board, independently of battle.

**Battle flow**: a click resolves through `BattleController._handle_tile_click`
→ `try_move_selected_unit`/`try_attack_selected_unit` → `board_changed` signal
→ `Battlefield._on_board_changed()` (wired in the `.tscn`) → checks
`grid.is_battle_won()`/`is_battle_lost()` → `_resolve_battle()` (awaits a
short timer for the result banner) → `_apply_battle_outcome()` → XP award,
then `GameManager.complete_battle()` or `GameManager.fail_battle()`. Player
units can also be moved with WASD and selected with the 1-5 number keys
(`battle_controller.gd`'s `MOVE_KEY_DIRECTIONS`/`NUMBER_KEYS`), independent
of the click path described above.

**Battle screen layout** (`scenes/battle/battlefield.tscn`'s
`HUD/Margin/VBox`): a Baldur's Gate 1/2 inspired arrangement of `TopRow` /
`BodyRow` / `BottomPanel`, each rendered by `battlefield.gd` reacting to
`BattleController` signals rather than owning any battle rules itself.

- `TopRow` — `BattleTitleLabel` (`tr("battle.title") % <expedition name>`,
  e.g. "Goblin Camp Battle") plus round/AP indicators.
- `BodyRow` — `PortraitPanel` (`scripts/battle/portrait_panel.gd`) on the
  left, one portrait per party member with HP overlaid, click-to-select; the
  `Grid` node (`BattleController`) centered; `UnitInfoPanel`
  (`scripts/battle/unit_info_panel.gd`) on the right, split into a
  `HoveredSection` (unit under the mouse cursor: name, facing, wound tier)
  and a `SelectedSection` (the active unit: name, facing, class, level, HP,
  AP, weapon) that stays pinned even when nothing is hovered — see
  `UnitInfoPanel.update_panel(hovered_unit, selected_unit)`.
- `BottomPanel` — a full-width `LogScroll` combat log that auto-scrolls to
  `max_value` on every new line (`Battlefield._append_log_line()`), sitting
  directly above the `ActionBar` (`MoveButton`/`AttackButton`, wired to
  `BattleController.set_action_mode()`), the existing Item actions
  (`PotionOption`/`TransferItemOption`), and `EndTurnButton`.

`BattleController.action_mode` (`ActionMode { CONTEXTUAL, MOVE, ATTACK }`)
gates how `_handle_tile_click()` interprets a click — see
`set_action_mode()`'s own comment for why no keyboard shortcut ever changes
it: `MOVE_KEY_DIRECTIONS`/`NUMBER_KEYS` cover every bound key, and neither
table (nor any other key handling) references `ActionMode`. Selecting a
unit, returning from the enemy turn, or resolving a move/attack all reset
`action_mode` back to `CONTEXTUAL`.

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

### Gotcha: a bare `Control` defaults to blocking clicks under it

A two-week bug (party unselectable on the World Map after a battle) traced
back to `scenes/world/world_map.tscn`'s `Spacer` node: `type="Control"`, a
bare `Control` rather than a layout container. Every *container* type
(`VBoxContainer`, `HBoxContainer`, `MarginContainer`, ...) defaults its
`mouse_filter` to `MOUSE_FILTER_PASS`, but a bare `Control`'s default is
`MOUSE_FILTER_STOP` — it silently absorbs the click before
`_unhandled_input()` ever sees it. `Spacer` covered most of the board
underneath the HUD's top row, so every tile except the one nearest the
settlement was unclickable. Fixed with one line, `mouse_filter = 2`
(`MOUSE_FILTER_IGNORE`), on the offending node. If a click-driven scene
stops responding under part of its layout, check for a bare `type="Control"`
node placed there for spacing rather than a `Control`-derived layout
container, and check `gui_get_hovered_control()` to confirm which node is
actually eating the input before assuming the bug is in the handler logic.
Regression coverage uses `Viewport.push_input(event, true)` — the real GUI
input pipeline — rather than calling `_unhandled_input()` directly, which is
what let this bug hide from every earlier test in the same area (see
`test_a_pushed_click_event_selects_the_party_through_the_real_gui_pipeline`
in `tests/unit/test_world_map.gd`).

## Camp navigation: CampNav is a reusable shell, not a router

`scenes/ui/camp_nav.tscn` (`scripts/ui/camp_nav.gd`) is instanced
identically into every Encampment screen — Encampment, Units, Buildings,
Guild Hall, Blacksmith, Alchemy Workshop, Runic Workshop, Trade, Stores,
Trading Post, Deploy Party, Roster, Parties, Recruitment, Party Details,
Unit Details, and Add Member — to give a persistent left-hand nav. It is deliberately absent
from the World Map: that screen isn't part of the Encampment, and a party
returns home by clicking the settlement tile instead. It renders six
buttons, all enabled and routing through `GameManager` — Trade opens
`scenes/ui/trade.tscn`, which lists Stores and (once purchased) Trading
Post (see [`docs/designs/weapon-armor-inventory.md`](../designs/weapon-armor-inventory.md)).
CampNav has no state of its own
beyond the Deploy Party button's disabled flag (set in `refresh()` from
`GameSession.get_deployable_encamped_parties().is_empty()`) and never
receives a signal from its parent screen — every wired button calls a
`GameManager.go_to_*()` directly. That's the opposite of
`InformationPanel`'s pattern, whose buttons forward a signal
(`party_selected`, `adventurer_selected`, `recruit_selected`) up to the
parent screen instead of routing themselves, since its "View" destination
depends on the parent screen's own selection.

## Card navigation: CardNavigator is a reusable shell, not a domain view

`scenes/ui/card_navigator.tscn` (`scripts/ui/card_navigator.gd`) is a
full-screen blocking modal shell for browsing ordered detail cards. It owns
only an immutable snapshot of IDs (`open(ids, initial_id)`), index wraparound
arithmetic, previous/next/close button wiring, position indicators (`%d of %d`),
and focus management (restoring focus to the caller's target control on close).
It contains a generic `ContentContainer` for caller-owned card bodies and
emits `card_changed(id)` and `closed(last_id)`. It never mutates caller rows,
holds domain state, or touches `GameSession`/`GameManager`.

## Progression formulas

Defined once, in `GameSession`, and read everywhere else through its
getters — never re-derive these:

- **XP threshold for level N**: `get_level_xp_threshold(level)` =
  `5 * level * (level + 1) - 10` (level 1 costs 0, level 2 costs 20, each
  step 10 XP more than the last).
- **Hit chance**: `get_effective_hit_chance(id)` = `min(raw_skill / 100.0, 0.95)`,
  where raw skill is `missile` for bows and `melee` for other weapon categories
  (falling back to `attack`). Skill stats themselves are never capped.
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
same "move toward nearest living opponent, attack any legal target" policy
`BattleController._take_enemy_unit_actions()` already uses for the enemy
side — legality per `get_legal_attack_targets()`, which for range-1 melee
weapons includes diagonals (`Grid.is_attack_adjacent()`'s eight-directional
adjacency), not just the four cardinal neighbors — down to its
reading-order tie-break and its "relocate to some
legal tile whenever one exists, even a non-improving one" move rule,
both re-implemented in `battle_bot.gd` because `battle_controller.gd`
is never modified — and `battle_sim.gd` drives a real `battlefield.tscn` instance
through to `GameManager.complete_battle()`/`fail_battle()`, including
auto-resolving any level-up modal a battle's XP award queues (necessary
because Orc Outpost's kill+clear XP always crosses the level-2 threshold).
Run via `make simulate`; see
[running-the-game.md](running-the-game.md#run-the-headless-battle-simulator).
This exists for balance/AI-tuning data (damage/kills/gold per battle),
not for testing — `tests/unit/test_battle_bot.gd` already covers
`BattleBot`'s decision logic in isolation without needing a real battle.

## Deterministic battle scenarios

`scripts/tools/battle_scenarios/` is the scene-free runner for reproducible
combat-policy experiments. `scenario_runner_main.gd` defers loading the
autoload-dependent runner until the SceneTree is ready, then normalizes and
validates the JSON scenario, expands its cases, and writes a JSONL record set
plus summary report. Run it with `make scenario`; see
[running-the-game.md](running-the-game.md#run-reproducible-battle-scenarios).
These reports are local evidence, not repository content.
