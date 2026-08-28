# Code Map

A reference for getting oriented before making a change. This is a map, not
a tutorial — see [running-the-game.md](running-the-game.md) and
[testing.md](testing.md) for task instructions.

## The autoloads have distinct responsibilities

Four singletons (declared under `[autoload]` in `project.godot`) split the
codebase's responsibilities cleanly. Every scene script is a thin view over
one or both gameplay autoloads; `GameConfig` supplies read-only configuration,
and `AudioManager` handles all audio routing and playback.

| Autoload | File | Owns | Never does |
|---|---|---|---|
| `GameConfig` | `scripts/autoload/game_config.gd` | Read-only, typed access to `config/game_config.json` with built-in fallback defaults | Hold gameplay state or mutate configuration at runtime |
| `GameManager` | `scripts/autoload/game_manager.gd` | Scene navigation (`go_to_*`, `_change_scene`), short-lived UI routing context (`route_context_id`), thin `Error`-returning wrappers around `GameSession` calls | Hold durable game state |
| `GameSession` | `scripts/autoload/game_session.gd` | All durable session state and game rules: parties, roster, encounters, world position/routing, progression (XP/levels/perks), stores/item ownership, journal, and building/workshop jobs | Touch the scene tree |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Master/Music/SFX bus routing, sound effect playback pool, background music crossfading, and user volume/mute preference persistence (`user://audio-settings.json`) | Hold gameplay state or campaign save data |

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
`project.godot`'s `[autoload]` list, before `GameManager`/`GameSession`/`AudioManager`,
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
├── boot/                        ├── autoload/    GameConfig, GameManager, GameSession, AudioManager
├── ui/                          ├── battle/      BattleController (Grid node), Battlefield,
│   (encampment, units,          │                GridScript, Unit, PortraitPanel, UnitInfoPanel,
│    buildings, trade,           │                FloatingText, PerkEffectResolver, WoundVisuals
│    journal, deploy_party,      ├── boot/        entry point → Start Menu
│    roster, parties,            ├── campaign/    EncounterService, PartyService (extracted domain services)
│    recruitment, guild_hall,    ├── content/     ContentCatalog (authored JSON content loader)
│    temple, blacksmith,         ├── debug/       F9 debug menu + scenario definitions
│    alchemy_workshop,           ├── local/       starting_settlement.gd (pre-Encampment intro screen)
│    runic_workshop, stores,     ├── presentation/ SpriteCatalog (texture and frame mapping)
│    trading_post, start_menu,   ├── progression/ PerkCatalog (DAG definitions), ProgressionService
│    game_menu, battle_result,   ├── save/        campaign_snapshot.gd, save_repository.gd
│    party_details, add_member,  ├── tools/       screenshot_tour, battle_bot.gd, battle_sim.gd,
│    unit_details, level_up,     │                campaign_sim.gd, battle_scenarios/ (runner & policy tools)
│    campaign_guide,             ├── ui/          one script per scenes/ui/ scene, plus shared
│    campaign_objective_banner,  │                widgets (table_view.gd, table_column.gd,
│    information_panel,          │                modal_dialog.gd, card_navigator.gd) —
│    modal_dialog, loot_table,   │                note: portrait_panel.gd lives in scripts/battle/
│    sell_quantity_dialog,       └── world/       world_map.gd
│    assign_equipment,
│    card_navigator,
│    unit_detail_card,
│    item_detail_card,
│    recruitment_card,
│    journal_entry_card,
│    victory_screen,
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

`GameSession` serves as a facade over three extracted domain services:
`EncounterService` (`scripts/campaign/encounter_service.gd`), `PartyService`
(`scripts/campaign/party_service.gd`), and `ProgressionService`
(`scripts/progression/progression_service.gd`). These services own no state
themselves; each operates directly on `GameSession`'s durable fields via a
passed `_gs` reference. `GameSession` exposes thin forwarding methods for all
extracted functions so all external call sites continue to work unchanged.

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
  `deployed: bool`, `travel_route: Array[Vector2i]`, `movement_spent: bool`,
  and `carry` (gold, gear, mana crystals, item instance IDs).
- **`CAMPAIGN_OBJECTIVES: Dictionary`** — the 12-node authored campaign ladder
  (Tiers 1-3, Pre-Boss, Final Boss). `campaign_objective_id` points to the
  current active objective; completing an authored encounter completes the
  matching objective, unlocks the next authored encounter in
  `unlocked_authored_encounters`, and emits `campaign_progress_changed`.
  Completing the final node triggers `campaign_victory` and enables free play.
- **`EXPEDITIONS: Dictionary`** & **`ContentCatalog`** — encounter *templates*
  (`goblin_camp`, `orc_outpost`, `ruined_fortress`, and authored campaign nodes):
  fixed `position`, `clear_xp`, `difficulty` (star tier), and default `enemy`/`enemies`
  compositions loaded from `config/content/encounters/` and `config/content/monsters/`.
  A live *active instance*'s `enemy` is re-resolved from
  `STAR_ENEMY_COMPOSITIONS[difficulty]` when entered for sandbox encounters, while
  authored encounters maintain their authored compositions.
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
- **`_battle_context` & loot lifecycle** — when combat begins, `create_battle_context()`
  creates an active battle context with an attributed party, encounter id, and empty reward carry.
  On victory, `resolve_battle_victory()` transfers the loot into the owning party's `carry`.
  On retreat, `resolve_battle_retreat()` discards the encounter loot. On defeat (wipe),
  `resolve_battle_defeat()` forfeits both the battle loot and the party's carried loot.
  Returning to the Encampment calls `deposit_pending_reward()` to deposit carried gold,
  crystals, and gear into permanent storage (`gold`, `mana_crystals`, `banked_gear`).
- **`journal_entries: Array[Dictionary]`** — durable log and quest history.
  Entries have an `id`, `type` (`"loot"`, `"battle"`, `"quest"`, etc.), `title_key`,
  `detail` dictionary, `section` (`JOURNAL_SECTION_LOG` or `JOURNAL_SECTION_QUESTS`),
  and `is_read: bool`. Appending an entry or marking one read emits `journal_updated`.
- **`mana_crystals` / `banked_gear`** — permanent, stackable loot storage, populated by
  `deposit_pending_reward()`. `shop_level` gates selling (`sell_item()`) and buying (`buy_item()`);
  `WEAPONS`/`ARMORS`/`ENEMY_LOOT_TABLES` are the backing content tables — see
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
- **Save system & Snapshot contract** — `CampaignSnapshot` (`scripts/save/campaign_snapshot.gd`,
  schema version 4) validates and serializes/deserializes durable session state.
  `SaveRepository` (`scripts/save/save_repository.gd`) handles atomic file saving and loading.

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
Guild Hall, Temple, Blacksmith, Alchemy Workshop, Runic Workshop, Trade,
Stores, Trading Post, Deploy Party, Roster, Parties, Recruitment, Party Details,
Unit Details, Add Member, Assign Equipment, and Journal — to give a persistent left-hand nav.
It renders top-level buttons and category submenus:

- **Encampment** — routes to `scenes/ui/encampment.tscn`.
- **Units** — routes to `scenes/ui/units.tscn`; displays category submenu: **Roster**, **Parties**, **Recruitment**.
- **Buildings** — routes to `scenes/ui/buildings.tscn`; displays category submenu: **Guild Hall**, **Temple**, **Blacksmith**, **Alchemy Workshop**, **Runic Workshop**.
- **Trade** — routes to `scenes/ui/trade.tscn`; displays category submenu: **Stores**, **Shop**.
- **Journal** — routes to `scenes/ui/journal.tscn`; displays a reactive badge when unread journal entries exist (`GameSession.has_unread_journal_entries()`), updating via `GameSession.journal_updated`.
- **Deploy Party** — routes to `scenes/ui/deploy_party.tscn`; visible when parties exist, disabled when none are deployable in camp.
- **World Map** — routes directly to `scenes/world/world_map.tscn` when a deployed party is in the field.

CampNav has no state of its own beyond submenu visibility (set by the parent screen's exported `category`) and button enablement/badges. It routes directly through `GameManager.go_to_*()` calls without requiring signals from parent screens.

## Audio system: AudioManager singleton and bus routing

`AudioManager` (`scripts/autoload/audio_manager.gd`) centralizes all sound effect and music playback:

- **Audio Bus Contract** — `project.godot`'s `[audio]` section points `buses/default_bus_layout` to `res://default_bus_layout.tres`, defining `Master`, `Music`, and `SFX` buses.
- **Playback APIs** — `play_sfx(id, pitch_scale, volume_db)` plays sounds through an internal pool of `AudioStreamPlayer` nodes, supporting pitch jitter (`pitch_jitter_roll`). `play_music(track_id, crossfade_duration)` smoothly crossfades between tracks.
- **Preferences Storage** — volume and mute preferences are stored in `user://audio-settings.json` (device preferences), surviving new games or save loads.
- **UI Settings** — `scenes/ui/audio_settings.tscn` (`scripts/ui/audio_settings.gd`) provides interactive volume sliders and mute checkboxes embedded in the game menu.

## Card navigation: CardNavigator is a reusable shell, not a domain view

`scenes/ui/card_navigator.tscn` (`scripts/ui/card_navigator.gd`) is a
full-screen blocking modal shell for browsing ordered detail cards. It owns
only an immutable snapshot of IDs (`open(ids, initial_id, return_target)`), index wraparound
arithmetic, previous/next/close button wiring, position indicators (`%d of %d`),
and focus management (restoring focus to the caller's target control on close).
It contains a generic `ContentContainer` for caller-owned card bodies and
emits `card_changed(id)` and `closed(last_id)`. It never mutates caller rows,
holds domain state, or touches `GameSession`/`GameManager`.

### Integrated Callers & Card Bodies

Every player-facing list that opens detailed entries integrates with `CardNavigator`:

- **Adventurer detail cards (`UnitDetailCard` / `unit_detail_card.tscn`):**
  - `Roster` (`scenes/ui/roster.tscn` / `scripts/ui/roster.gd`) — browses all adventurers in the roster.
  - `Add Member` (`scenes/ui/add_member.tscn` / `scripts/ui/add_member.gd`) — browses available unassigned candidates.
  - `Party Details` (`scenes/ui/party_details.tscn` / `scripts/ui/party_details.gd`) — browses current party members.
- **Recruitment cards (`RecruitmentCard` / `recruitment_card.tscn`):**
  - `Recruitment` (`scenes/ui/recruitment.tscn` / `scripts/ui/recruitment.gd`) — browses candidate offers with direct recruitment.
- **Item detail cards (`ItemDetailCard` / `item_detail_card.tscn`):**
  - `Shop / Trading Post` (`scenes/ui/trading_post.tscn` / `scripts/ui/trading_post.gd`) — browses shop catalogue weapons with purchase actions.
  - `Stores` (`scenes/ui/stores.tscn` / `scripts/ui/stores.gd`) — browses banked gear and mana crystals via shared `LootTable`.
  - `Party Details` (`scenes/ui/party_details.tscn`) — browses carried loot of deployed parties via shared `LootTable`.
  - `Battle Result` (`scenes/ui/battle_result.tscn` / `scripts/ui/battle_result.gd`) — browses battle victory loot via shared `LootTable`.
- **Journal entry cards (`JournalEntryCard` / `journal_entry_card.tscn`):**
  - `Journal` (`scenes/ui/journal.tscn` / `scripts/ui/journal.gd`) — browses chronological log and quest entries.
- **Level-up outcome cards (`LevelUp` / `level_up.tscn`):**
  - `Battle Result` (`scenes/ui/battle_result.tscn`) — browses leveled-up units and gates completion on pending perk choices.

### Excluded Lists (Non-Detailed Action Lists)

The following tables and selectors are action/routing lists rather than detailed-entry cards and are intentionally excluded from `CardNavigator`:

- `Buildings` (`buildings.gd`): encampment facility upgrade actions.
- `Trade` (`trade.gd`): trade route destinations and dispatch actions.
- `Deploy Party` (`deploy_party.gd`): party selection table for field deployment.
- `Parties` (`parties.gd`): party roster overview routing to Party Details.
- Facility recipe/assignment dropdowns (`assign_equipment.gd`, `blacksmith.gd`, `alchemy_workshop.gd`, `runic_workshop.gd`, `temple.gd`): targeted assignment pickers.

### Rule for Future Call Sites

Any new player-facing list or table that opens inspectable detailed entries MUST use `CardNavigator` and an appropriate card body component rather than creating bespoke detail overlays or screens.

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
