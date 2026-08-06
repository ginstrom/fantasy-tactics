# Guild Hall and Full-Party Battles Design

## Purpose

Two related gaps in the current prototype:

1. There is no building system at all — Encampment's Buildings button is a
   disabled stub, and nothing in `GameSession` enforces a party-size cap
   despite the design doc describing one.
2. Battle is hard-wired to exactly one player unit versus one enemy unit —
   `battle_controller.gd` only ever fields `party.member_ids[0]`, regardless
   of how many adventurers are actually in the party.

This spec adds the game's first building (Guild Hall, upgradeable to raise
the party-size cap) and reworks the battlefield to field every party member
at once, with a Baldur's Gate-style portrait panel, mouse/keyboard
selection, and incremental WASD movement.

## Section 1: Guild Hall and party size cap

### Party size cap

Nothing in the code enforces a party-size cap today —
`assign_adventurer_to_party()` accepts unlimited members. This spec
introduces the cap for the first time, driven by Guild Hall level:

- Level 1 (default): cap 4.
- Level 2: cap 5.
- Level 2 is the maximum for this slice; no further levels.

`GameSession`:

- New state: `guild_hall_level: int = 1`, reset to `1` in `reset()`
  alongside `gold`.
- New constants: `GUILD_HALL_LEVEL_1_PARTY_CAP := 4`,
  `GUILD_HALL_LEVEL_2_PARTY_CAP := 5`, `GUILD_HALL_UPGRADE_COST := 50`,
  `GUILD_HALL_MAX_LEVEL := 2`.
- New method `get_max_party_size() -> int`: returns the cap for the current
  `guild_hall_level`.
- New method `can_upgrade_guild_hall() -> bool`: true when
  `guild_hall_level < GUILD_HALL_MAX_LEVEL` and `gold >= GUILD_HALL_UPGRADE_COST`.
- New method `upgrade_guild_hall() -> bool`: if `can_upgrade_guild_hall()`,
  deducts the cost, increments the level, returns `true`; otherwise makes
  no change and returns `false`.
- `assign_adventurer_to_party()` gains one more rejection condition:
  `parties[party_index].member_ids.size() >= get_max_party_size()`. This is
  the single enforcement point; every UI assignment path funnels through it
  (directly or via `GameManager.assign_adventurer_to_party()`).

### UI call sites that need "party is full" awareness

Three existing screens assume assignment can never fail for capacity
reasons. Each needs a small update so the player never lands on a screen
where every action silently fails:

- `party_details.gd`: `add_member_button.disabled` currently checks only
  `GameSession.get_available_adventurers().is_empty()`. It must also
  disable when the party is at `get_max_party_size()`.
- `add_member.gd`: no change needed — `_on_row_activated()` already calls
  `refresh()` on a failed assignment rather than navigating, so a stale-full
  party fails safely already. (Reaching this screen at all is prevented by
  the `party_details.gd` fix above.)
- `unit_details.gd`'s `_refresh_assignment_section()`: the `party_picker`
  is populated from `GameSession.get_encamped_parties()`, which
  deliberately includes full-but-encamped parties (by original design,
  before "full" existed). It must now exclude parties at
  `get_max_party_size()`, matching how it already excludes non-encamped
  parties from `has_eligible_party`.

### Buildings UI

- Encampment's `BuildingsButton` (`scenes/ui/encampment.tscn`, currently
  `disabled = true`) becomes live and routes to a new **Buildings** list
  screen, following the existing list-screen pattern (e.g. `roster.tscn`/
  `parties.tscn`): a `TableView` (or equivalent) with one row, "Guild
  Hall". This is deliberately a list of one — the pattern supports adding
  more buildings later without a screen redesign, but no other building is
  in scope here.
- Activating the Guild Hall row opens a new **Guild Hall** detail screen:
  - Current level (e.g. "Guild Hall — Level 1").
  - Current party-size cap ("Party size: 4").
  - If `guild_hall_level < GUILD_HALL_MAX_LEVEL`: an "Upgrade to Level 2 —
    50 gold" button, disabled when `not can_upgrade_guild_hall()`. Pressing
    it calls `upgrade_guild_hall()` and refreshes the screen.
  - If already at `GUILD_HALL_MAX_LEVEL`: the upgrade button is replaced
    with a "Max Level" state (no action).
- `GameManager` gains `go_to_buildings() -> Error` and
  `go_to_guild_hall() -> Error`, following the existing `_change_scene()`
  pattern used by `go_to_units()`, `go_to_roster()`, etc.
- New translation keys under `buildings.*` and `guild_hall.*` in
  `translations/en.tres`, following the existing `encampment.*` /
  `roster.*` key-naming pattern.

## Section 2: Fielding the full party and enemy scaling

### Fielding

`battle_controller.gd`'s `_ready()` currently spawns exactly one player
`Unit` (via `_get_player_adventurer_id()`, which returns only
`party.member_ids[0]`) and one enemy `Unit` (via `_get_enemy_stats()`,
which returns a single stats `Dictionary`). This becomes:

- One `Unit` per entry in `party.member_ids` (in party order), not just the
  first.
- One `Unit` per enemy the encounter's `count` defines (see below), all
  sharing that encounter's single enemy stats block — Goblins are
  identical to each other today, and stay identical to each other after
  this change; only the quantity changes.

### Starting positions

The grid is 6×6 (`GRID_WIDTH`/`GRID_HEIGHT`). Fixed, non-overlapping
clusters replace the single `WARRIOR_START`/`GOBLIN_START` constants:

- Player start positions (bottom-left cluster, used in party order, up to
  5): `(0,0), (1,0), (0,1), (1,1), (2,0)`.
- Enemy start positions (top-right cluster, mirrored, up to 3):
  `(5,5), (4,5), (5,4)`.

A party smaller than the full cap (e.g. 2 members deployed) simply uses
the first 2 slots; unused slots stay empty. There is no minimum
party-size requirement.

### Enemy count data

`EXPEDITIONS[id].enemy` is currently one stats `Dictionary` used for the
single spawned enemy. It gains a `count` field:

- `GOBLIN_CAMP_ID`: `enemy.count = 2`.
- `ORC_OUTPOST_ID`: `enemy.count = 3`.

Enemy count is fixed per encounter template, independent of how many party
members are fielded (explicit product decision: a full 5-member party
against 2 Goblins is expected to be an easier fight than today's 1v1 — that
tradeoff is accepted, not a bug).

### What does not need to change

`run_enemy_turn()`, `_nearest_living_unit()`, `_take_enemy_unit_actions()`,
`end_turn()`'s per-unit flag reset, `is_battle_won()`, and
`is_battle_lost()` are already written generically over `units: Array` and
already loop per-unit-per-side. They correctly support N-vs-M without
modification — the only real change in this section is spawning and start
positions.

XP awarding (`_award_kill_xp()`/`_award_clear_xp()` in `battlefield.gd`)
already splits evenly across `party.member_ids` regardless of battlefield
unit count, so multi-kill, multi-member battles need no change there.

## Section 3: Battle UI — portrait panel, selection, and movement

### Left portrait panel

A new panel, positioned on the left side of the battlefield scene
alongside the existing right-side information HUD (mirroring the
Baldur's Gate 1/2 layout referenced in the request). One square per
fielded party member, in party order:

- A color swatch matching the unit's on-map rendering color.
- Current health.
- A selection ring when that member is `selected_unit`.
- A dimmed "defeated" state once that member's `Unit` has been removed
  from `units` (matched via the existing `unit.adventurer_id` field back
  to `party.member_ids`).

### Selection

Three equivalent ways to select a *living, player-side* unit during the
player's turn — all resolve to the same `_select_unit()` call used today:

- Click its map tile (unchanged).
- Click its portrait.
- Press its number key: **1–5** (not just 1–4), so a 5th party member is
  reachable by keyboard once Guild Hall level 2 raises the cap. Pressing a
  number with no living unit in that slot, or during the enemy's turn, or
  while `input_locked`, is a no-op.

### Movement — shared points budget

`Unit.has_moved: bool` becomes `Unit.moves_remaining: int`:

- Reset to `move_range` at the start of that unit's side's turn (in the
  existing per-unit reset loop inside `end_turn()`).
- `get_legal_moves()` computes reachable tiles from `moves_remaining`
  instead of the full `move_range`, so the highlighted legal-move set
  shrinks as the budget is spent within the same turn.
- **WASD**: each press attempts one step in that direction for the
  currently `selected_unit`. Legal when the target tile is in bounds,
  unoccupied, and `moves_remaining > 0`; consumes 1 point per step.
- **Mouse click** on a highlighted tile still moves there in one action, as
  today, but now costs that tile's real path distance from
  `moves_remaining` rather than consuming an all-or-nothing flag. Multiple
  clicks are legal in the same turn as long as points remain — e.g. click 1
  tile away, then click 2 more tiles away, then attack.
- WASD and clicks share the same `moves_remaining` budget and can be
  freely interleaved (step with WASD, then click a highlighted tile, then
  step again) within one unit's turn.
- Moving onto an enemy-occupied tile — via WASD or click — attacks instead
  of moving, using the existing adjacency and `has_acted` rules unchanged.
  `has_acted` remains a separate, independent gate from `moves_remaining`:
  a unit can spend movement points before or after its one attack, in any
  order, interleaved.

Both input methods are gated identically to today's mouse-only rules:
active only during the player's turn, only for the `active_side`'s units,
and ignored entirely while `input_locked` (enemy turn or a level-up modal
in progress).

### HUD adjustments

- `PlayerHealth` label is removed — the portrait panel already shows each
  member's health individually, making the aggregate label redundant.
- `EnemyHealth` becomes a short stacked list, one line per living enemy,
  since encounters can now field more than one.
- `Hint`, `Status`, `RoundLabel`, and `EndTurnButton` are unchanged.

## Section 4: Edge cases and testing

### Edge cases

- A party smaller than the full cap fields fewer units; no minimum size is
  required.
- A full 5-member party against a fixed-count encounter is expected to be
  easier than today's 1v1 — accepted tradeoff of the fixed-enemy-count
  decision in Section 2.
- No path exists to shrink `guild_hall_level` once upgraded, so no need to
  handle a party that is over a newly-lowered cap.
- `is_battle_won()`/`is_battle_lost()` need no change — already generic
  over "any living unit of side X."
- `guild_hall_level` follows the same lifecycle as `gold`: resets to `1` on
  `GameSession.reset()`, no persistence (no save/load exists yet).

### Testing

`GameSession`:
- `get_max_party_size()` at level 1 and level 2.
- `upgrade_guild_hall()`: success path, insufficient-gold rejection,
  already-max-level rejection.
- `assign_adventurer_to_party()`: accepts up to the cap, rejects at the
  cap.

`battle_controller.gd`:
- Spawns exactly `party.member_ids.size()` player units and
  `enemy.count` enemies, at non-overlapping start positions.
- `moves_remaining` decrements correctly across a WASD step and a
  multi-tile click within the same unit turn, and resets correctly at
  `end_turn()`.
- Moving onto an enemy tile (WASD or click) attacks rather than moves.
- Existing single-unit battle tests are rewritten against the new
  multi-unit model — this is real, nontrivial test-suite cost, not an
  afterthought, since the current suite assumes exactly one unit per side.

`battlefield.gd` / portrait panel:
- Health, selection ring, and defeated state per portrait track the
  underlying `Unit` correctly.
- Number-key selection (1–5) respects `active_side` and `input_locked`.
- WASD respects the same gating as number-key selection.

New UI screens:
- Buildings list shows the Guild Hall row.
- Guild Hall screen's upgrade button gates correctly on gold and level,
  and shows the "Max Level" state at level 2.
- `party_details.gd`'s Add Member button disables when the party is full.
- `unit_details.gd`'s party picker excludes full parties.

## Implementation ordering note

These two pieces are only loosely coupled (the battle portrait panel's
key range depends on the party cap Guild Hall can raise), but they differ
enormously in size and risk: Guild Hall is a small, self-contained
addition to an existing UI pattern, while the full-party battlefield
rework touches core battle mechanics and a large share of the existing
battle test suite. The implementation plan should sequence Guild Hall
first (establishing `get_max_party_size()`, which the battlefield work
then reads), and treat the full-party battlefield rework as the larger,
riskier second phase.
