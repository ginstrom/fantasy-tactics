# Stage 6 Decision & Evidence Ledger

Dated 2026-08-24. Created by Step 1
([01-stage-6-contract-and-baseline.md](01-stage-6-contract-and-baseline.md)).
This is the durable record of the post-Stage-5 baseline, the disposition of
every carry-forward gate (G1-G4), and the target contracts every later
Stage 6 step must implement against. Update this file in place as later
steps' decisions are approved; do not delete earlier rows.

## Protected baseline evidence (2026-08-24, before any runtime change)

Run from a clean `main` at commit `b69a0b6` (a Stage 6 plan-doc revision
commit; no runtime code has changed since Stage 5's exit gate).

| Command | Result |
|---|---|
| `make campaign-sim` | 5/5 representative-seed victories (seeds 4, 9, 10, 12, 14); 0 wipes, 0 stalemates, 12/12 battles won per run |
| `make check` | 79 scripts, 2149/2149 tests passing, 1 pre-existing known orphan (`test_owned_item_instances_also_respect_the_total_carried_item_capacity` / `test_clicking_the_other_partys_tile_while_its_arrival_panel_is_open_refreshes_the_panel_to_its_own_encounter`), exit 0 |
| `godot --headless --path . --editor --quit` | exit 0, no import/scan errors |
| `git diff --check` | clean (no changes yet) |

## Stage 5 carry-forward context

The Stage 5 plan directory (`docs/plans/2026-08-23-stage-5-strategic-roster-expansion/`)
was deleted from the working tree in a prior "clean slate" restructuring
commit (`5ef567e`). Its content is still recoverable from git history
(`git show 5ef567e~1:docs/plans/2026-08-23-stage-5-strategic-roster-expansion/decision-ledger.md`)
and was used to source the dispositions below.

**Accepted global-loot limitation (Stage 5, 2026-08-24):** `pending_reward`/
`pending_gear`/`pending_mana_crystals` in `game_session.gd` remained
single campaign-wide "loot in transit" buckets rather than per-party
attributes. The Stage 5 ledger explicitly named the fix as "make these
three fields attributes of each entry in `parties`" and scoped it out of
Stage 5 because it touched ~10 files outside that stage's declared list.
This is precisely Stage 6 Step 2's `PartyCarry` migration.

**Battle-claim/arrival mechanism already shipped (Stage 5 Step 6,
commit `0ae1f0d`/`aba8e49`):** `active_battle_party_id` plus
`GameSession.release_battle_claim()` give exactly one party a battle
claim at a time; a click-order tie-break decides which party's Enter wins
when both are staged; `world_map.gd`'s End Turn arrival check
auto-selects a non-selected party that arrives at a live encounter, and a
position-match guard in `GameManager.enter_battle()` plus a panel-close
step prevent a stale `pending_arrival_encounter_id` from leaking across a
selection switch when both parties have simultaneous arrivals. Four
independent review passes verified this, including the
both-parties-simultaneous-arrival edge case.

## Decision-contract checklist

This checklist cannot be marked complete until every gate below has an
approved or deferred disposition recorded with the user. Expected failure
state before user review: all four rows below read "Pending" — recorded
here for the record, then immediately closed in the same step per the
manual check.

| Gate | Status before user review | Status after user review |
|---|---|---|
| G1 | Pending | Approved |
| G2 | Pending | Approved |
| G3 | Pending | Approved |
| G4 | Pending | Approved (pre-existing, carried forward) |

## Gate dispositions

### G1 — Rogue scope

**Status: Approved 2026-08-24 (user, this step). Rogue remains deferred.**

Stage 6 Step 4 covers only the branching-perk mechanism (DAG prerequisites,
mutual exclusivity, `PerkEffectResolver`) for classes already shipped
(Knight, Archer, Mage, Battle Mage, Paladin, Ranger). Rogue's player
choice, counterplay, encounter use, persistence, deterministic proof, and
manual check are explicitly out of scope for Stage 6 and remain deferred
to a future stage, consistent with the Stage 5 disposition.

### G2 — First authored-content schema's supported encounter hooks

**Status: Approved 2026-08-24 (user, this step). Static setup only.**

The first `ContentCatalog` encounter schema version supports only
static, pre-battle setup data — no scripted mid-battle event boundary
(no reinforcement waves, no timed triggers). The schema fields from this
step's target contract already cover every approved hook:

| Hook | Field(s) |
|---|---|
| Objective unlocks | `prerequisite_objective_id` |
| Reward types | `reward_loot_table_id` |
| Terrain / layout | `world_position`, `grid_size` |
| Cover layout | `cover_tiles` |
| Spawn points / composition | `player_spawns`, `enemy_spawns`, `enemy_composition` |

Scripted mid-battle events are explicitly deferred; adding one now would
require inventing a bounded trigger vocabulary this step has not designed
and would risk drifting toward the "arbitrary status-effect DSL" this
plan's non-goals rule out.

### G3 — First branching perk tree's branch count, respec policy, effect/action vocabulary

**Status: Approved 2026-08-24 (user, this step). Knight's Shield Bash /
Chain Blow become the first branching pair.**

| Parameter | Value | Basis |
|---|---|---|
| First branching class | Knight | Already ships exactly two independent perks (Shield Bash, Chain Blow) from Stage 5 Step 5, an ideal proof case for a shared tier-1 root gating an exclusive tier-2 choice, with no new perk content to invent |
| Branch count | 2 (Shield Bash vs. Chain Blow), mutually exclusive at tier 2, gated behind one shared tier-1 prerequisite node | Reuses Knight's exact two existing perks and their existing effect values; only the prerequisite/exclusivity relationship is new |
| Respec policy | None (default) | Matches this plan's stated default; no product request to change it |
| Effect/action vocabulary | Reuse Shield Bash's and Chain Blow's existing effect values verbatim (off-balance application; adjacent-enemy chained strike) inside `effect_descriptor` | No new numeric balance value is invented, per this plan's gate rule |

Every other shipped class's existing flat perk list is migrated into the
new `PerkDefinition` schema with empty `prerequisite_ids`/
`mutually_exclusive_with` (structurally valid DAG nodes, behaviorally
unchanged) — only Knight gets a real branching relationship in Stage 6.

### G4 — Multi-party simultaneous arrival and encounter lock resolution

**Status: Approved 2026-08-24 (user, this step). Already closed by Stage 5
Step 6; carried forward unchanged.**

Stage 6 Step 2 must preserve the existing `active_battle_party_id` claim/
release and click-order tie-break, and the existing simultaneous-arrival
auto-selection/position-match guard, when it introduces `BattleContext`.
`BattleContext.owner_party_id` replaces `active_battle_party_id` as the
canonical claim record; no new lock semantics are designed in Stage 6.

## Target contracts

### `PartyCarry`

Carried directly on each party dictionary in `GameSession.parties`,
replacing the campaign-wide `pending_reward`/`pending_gear`/
`pending_mana_crystals`/`battle_reward`/`battle_gear`/
`battle_mana_crystals` globals named in the accepted Stage 5 limitation
above.

```
{
  "gold": int,
  "gear": Dictionary[String, int],
  "mana_crystals": Dictionary[String, int],
  "item_instance_ids": Array[String]
}
```

### `BattleContext`

Immutable per-battle record; `owner_party_id` is the canonical claim,
replacing `active_battle_party_id`.

```
{
  "battle_id": String,
  "owner_party_id": String,
  "encounter_id": String,
  "reward": {
    "gold": int,
    "gear": Dictionary[String, int],
    "mana_crystals": Dictionary[String, int],
    "item_instance_ids": Array[String]
  },
  "status": String,  // "active" | "victory" | "defeat" | "retreat" | "discarded"
  "seed": int
}
```

### `ContentCatalog`

Catalog manifest version, encounter schema, validation diagnostics, and
immutable runtime copies. Encounter schema fields (per G2's static-only
disposition):

`id`, `title_key`, `world_position`, `grid_size`, `player_spawns`,
`enemy_spawns`, `cover_tiles`, `enemy_composition`,
`prerequisite_objective_id`, `reward_loot_table_id`.

Replaces `GameSession.EXPEDITIONS` and
`BattleController._cover_tiles_for_encounter()` as the single source of
authored encounter data for production gameplay, `ScenarioContract`, and
`CampaignSim`.

### `PerkDefinition`

```
{
  "id": String,
  "class_id": String,
  "tier": int,
  "prerequisite_ids": Array[String],
  "mutually_exclusive_with": Array[String],
  "rank_cap": int,
  "name_key": String,
  "description_key": String,
  "effect_descriptor": Dictionary
}
```

Replaces flat `CLASS_PERKS` arrays and static `PERK_TREE_SIZE` caps.
Per G3's disposition, only Knight's Shield Bash/Chain Blow pair carries a
non-empty `prerequisite_ids`/`mutually_exclusive_with` relationship in
Stage 6; every other class's existing perks migrate with those fields
empty.

### `DomainServices`

Pure domain interfaces behind the `GameSession` facade:

| Service | File |
|---|---|
| `PartyService` | `scripts/campaign/party_service.gd` |
| `EncounterService` | `scripts/campaign/encounter_service.gd` |
| `ProgressionService` | `scripts/progression/progression_service.gd` |
| `ContentCatalog` | `scripts/content/content_catalog.gd` |

## Playtest reset policy

The first Stage 6 runtime change (Step 2) may reject/delete old save
formats without a migration path. A new-format `CampaignSnapshot` payload
must still be validated transactionally into scratch state before it is
assigned to live session state — a malformed new-format payload must
never mutate live state, even though old-format payloads are simply
rejected rather than migrated. **Manual instruction for players:** after
Step 2 merges, delete any existing save and start a fresh campaign; old
saves will not load.

## Manual check record

Reviewed with the user 2026-08-24. All four gates (G1-G4) approved as
recorded above: Rogue stays deferred; the first `ContentCatalog` schema
is static-setup-only; Knight's Shield Bash/Chain Blow become the first
branching perk pair with no respec; the Stage 5 multi-party arrival/lock
mechanism carries forward unchanged into `BattleContext`. The `PartyCarry`,
`BattleContext`, `ContentCatalog`, `PerkDefinition`, and `DomainServices`
contracts above, and the fresh-save-only reset policy, are approved as the
baseline for Step 2.

This step changes no runtime behavior. Baseline commands were re-run after
writing this ledger with no changes in outcome (see Protected baseline
evidence above, which is the post-write reading).
