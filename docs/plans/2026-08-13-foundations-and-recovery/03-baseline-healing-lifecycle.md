# Step 3 — Baseline healing lifecycle (persistent damage + natural recovery)

**Branch:** `baseline-healing-lifecycle`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("add the baseline healing lifecycle")
and §2.3 item 1 ("Baseline natural/rest recovery"), per
`docs/designs/vision.md` → "Healing": *"Units heal naturally over time, more
if they don't move, and more if they are in the encampment."*

## Goal

Today every battle starts at full health and battle damage is discarded on
exit (player units are created from `get_effective_max_health()`; nothing
writes health back). This step makes damage durable and adds the baseline
recovery rule. Potion/Temple/Cleric healing modifiers and any
injury/permadeath states are explicitly later work (gap analysis §2.3
items 2–3).

## Design

### Persistent health

- Add `"health": <max_health>` to the adventurer records built by
  `get_default_warrior()` / `get_default_scout()` (recruits inherit via
  `_seed_adventurer_baseline_stats()`). Invariant maintained everywhere:
  outside battle, `1 <= health <= get_effective_max_health(id)` — a unit is
  never durably at 0.
- New `GameSession` API (validated, following the existing getter/setter
  style):
  - `get_current_health(adventurer_id) -> int` (0 for unknown id, matching
    the other `get_effective_*` fallback style).
  - `set_adventurer_health(adventurer_id, amount) -> bool` — rejects unknown
    ids, clamps to `[1, effective max health]`.
  - `apply_battle_aftermath(health_by_id: Dictionary) -> void` — batch
    write-back used by the battlefield after both outcomes: for each entry,
    store `max(1, reported)` clamped to max health. (Party members absent
    from the dict are left untouched.)

### Battle integration

- **Start:** `battle_controller.gd`'s player-unit creation uses the stored
  health (floored at 1) with `get_effective_max_health()` as the max.
- **Victory:** `battlefield.gd`'s `_finish_victory()` collects every player
  `unit.health` and calls `apply_battle_aftermath()` — after clear-XP
  level-ups resolve, so final values include level-up health gains. Downed
  player units report 0 → persisted as 1 ("battered"; see decision below).
- **Defeat:** `_apply_battle_outcome(false)` does the same collection before
  `GameManager.fail_battle()` (an all-down party persists everyone at 1).
- **Level-up:** `_award_adventurer_xp()` raises current health by the same
  vitality-derived delta it applies to max health (per step 2,
  `max_health = vitality × level`, so the delta is the class's vitality;
  this mirrors the existing mid-battle `_refresh_unit_health()` behavior);
  never above the new max.

**Decision — no permadeath in this slice.** Downed units survive at 1
health. Permadeath/injury rules are a separate approved rule (the vision's
"losing a unit is painful" direction) and are out of scope here; record this
in the commit body. Deployment rules are unchanged: any unit at ≥1 health is
deployable; fighting wounded is the player's gamble.

### Natural recovery (world turns)

`end_world_turn()` applies recovery after the job/income advances and
**before** it resets `movement_spent` (that flag is the moved-this-turn
signal; `take_next_route_step()` — manual or auto — sets it):

| Adventurer state | Rate per world turn |
|---|---|
| In the Encampment (unassigned, or in a party that is not deployed) | `HEAL_RATE_ENCAMPED` |
| Deployed, party did **not** move this turn | `HEAL_RATE_RESTING` |
| Deployed, party moved this turn | `HEAL_RATE_MOVING` |

Starting values (tunable, see config below): encamped 4, resting 2,
moving 1 — strictly ordered per the vision ("more if they don't move, and
more if they are in the encampment"). Recovery clamps at effective max
health; a unit already at max is a no-op (this keeps every existing
`end_world_turn` test passing unchanged — assert that property).

### Configuration

New `"healing"` section in `config/game_config.json` with
`encamped_rate` / `resting_rate` / `moving_rate`; matching `GameConfig`
`DEFAULTS` entries, `test_game_config.gd` lockstep rows, and
`HEAL_RATE_*` vars loaded in `_load_balance_config()` — exactly the pattern
of the existing `progression` section.

### Save migration

Extend the nested per-adventurer normalization pass introduced in step 1
and extended in step 2 — which by then already handles recruitment
`template_id` inference, the skill-track split, guard/might defaults, and
vitality-derived max health (or read both steps' migration designs and add
it, if the ordering changed): an absent `health` key normalizes to that
adventurer's `stats.max_health`. Legacy
saves therefore load once at full health — deliberate, documented in the
normalizer comment; `FORMAT_VERSION` stays `1` (established post-v1-field
pattern).

### UI

- **Unit Details** (`scripts/ui/unit_details.gd`): the stats row shows
  current/max health (extend the `unit_details.stats` translation format).
- **Party Details** (`scripts/ui/party_details.gd`): member rows show
  current/max health so a deployed party's attrition is visible at a glance.
- Follow the README localization process for reworked/new keys; update
  `tests/unit/test_localization.gd` where it pins exact strings.
- Audit `scripts/tools/screenshot_tour.gd`: if a Unit Details or Party
  Details state is already toured, make sure the new row renders in it; add
  a wounded-state step only if the tour already covers these screens.

### Not in this step

- Out-of-battle potion use (`consume_carried_potion()` is currently
  battle-only). Optional extension below; gap analysis §2.3 sequences potion
  modifiers after the baseline.
- Temple/Cleric modifiers, injury statuses, permadeath, deployment gates on
  low health.
- `battle_state_factory.gd` scenario units stay full-health (their default);
  no scenario schema change.

## Setup

```bash
git checkout main && git pull
git checkout -b baseline-healing-lifecycle
make check   # green baseline (step 2 already merged)
```

Capture baseline evidence (fresh parties always start at full health, so
these must be **identical** after the change):

```bash
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
make simulate RUNS=20
```

## TDD task list (red → green, in this order)

1. **Persistent health record** (`tests/unit/test_game_session.gd`): fresh
   Warrior/Scout/recruits have `health == max_health`;
   `get_current_health()`; `set_adventurer_health()` clamps to `[1, max]`
   and rejects unknown ids.
2. **Battle start from stored health** (`tests/unit/test_battle_controller.gd`
   or `test_battlefield.gd`): set the Warrior's health to 4, enter a real
   battle via the instantiated `.tscn`, assert the player unit starts at
   4/10 (per testing.md: jump state directly, don't replay earlier
   mechanics).
3. **Victory write-back** (`tests/unit/test_battlefield.gd`): drive a
   deterministic win (testing.md's `hit_roll`/`apply_super_power` recipe)
   where the player unit took damage, and assert the adventurer's stored
   health equals the unit's surviving health after the battle resolves.
4. **Defeat write-back**: force a loss, assert every member persists at 1.
5. **Level-up health coupling**: `_award_adventurer_xp()` crossing a level
   raises current health by the vitality-derived max-health delta, capped at
   the new max (test at partial health).
6. **Natural recovery** (`tests/unit/test_game_session.gd`): three rate
   tests (encamped / deployed-resting / deployed-moved) driven through
   `end_world_turn()` with the `HEAL_RATE_*` vars set to distinctive values;
   clamping at max; and the no-op property for full-health adventurers
   (protects existing turn tests).
7. **Save migration** (`tests/unit/test_campaign_snapshot.gd`): legacy
   adventurer without `health` loads at `stats.max_health`; current saves
   round-trip the field.
8. **Config**: `"healing"` section + DEFAULTS + lockstep rows
   (`tests/unit/test_game_config.gd`).
9. **UI + translations**: Unit Details and Party Details rows, their tests
   (`test_unit_details.gd`, `test_party_details.gd`), and localization
   updates.
10. **Docs:** `docs/dev/code-map.md` — add persistent health to the
    adventurer-record bullet and one line to the domain notes (recovery
    happens in `end_world_turn()`).

## Verification

```bash
make check
```

Green. Balance gate:

- Re-run both Setup evidence commands; outputs must match the pre-change
  baseline (sim/scenario battles start from `GameSession.reset()` state —
  full health — so any difference indicates a regression in the battle-start
  path).
- Attrition sanity (manual, below) is the new behavior's evidence; there is
  no automated multi-battle persistence harness yet and this step does not
  build one.

## Manual verification (user sign-off)

1. `make play`, **FN+F9** → **Goblin Camp Battle**. Fight without Super
   Power and let the Warrior take some hits; win.
2. On the World Map, open Unit Details: health is below max (screenshot).
3. End the world turn **without moving**: health rises by the resting rate.
   Then move one tile and end the turn: health rises by the (smaller) moving
   rate. Note both numbers against `config/game_config.json`.
4. Route back to the settlement tile, enter the Encampment, end turns:
   health rises by the (largest) encamped rate until full (screenshot at
   partial health).
5. **FN+F9** → **Orc Outpost Battle**, win while wounded: the level-up
   overlay's health-gain applies to current health too (current rises with
   the max).
6. Lose on purpose once (Goblin Camp with a weakened party, or just let the
   enemy win): everyone should be back at 1 health afterward, deployable
   again.
7. Save → Load → health values persist exactly.

## Optional extension (non-blocking)

Out-of-battle potion use on Unit Details: a "Use potion" action when
`health < max` and a potion is carried — `GameSession` heals
`randi_range(healing_min, healing_max)` (injectable roll, matching
`battle_controller.healing_roll` style) and consumes via the existing
`consume_carried_potion()`. If implemented, it gets its own red/green cycle
and translation keys; if not, note it in the commit body as deferred to the
§2.3 healing-modifiers slice.

## Commit and merge

```bash
git add -A && git status   # confirm only intended paths are staged
git commit -m "feat: persist battle damage and add baseline natural healing"
# after user sign-off:
git checkout main && git merge baseline-healing-lifecycle && git branch -d baseline-healing-lifecycle
```

## Milestone (concretely verifiable)

- `make check` green; new recovery/healing tests present in
  `test_game_session.gd`, `test_battlefield.gd`, `test_campaign_snapshot.gd`.
- `make simulate` / baseline scenario outputs identical to the pre-change
  capture.
- Signed-off evidence of the attrition loop: post-battle wounded screenshot,
  world-turn recovery numbers matching config, encamped recovery to full,
  defeat → everyone at 1 health, save/load persistence.
