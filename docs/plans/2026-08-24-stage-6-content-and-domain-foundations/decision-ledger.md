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

## Step 5 final evidence (2026-08-25): domain extraction and Stage 6 exit gate

Recorded by Step 5
([05-domain-extraction-and-stage-6-exit.md](05-domain-extraction-and-stage-6-exit.md))
on branch `test/stage-6-foundations-exit`, base commit `140cc10` (Step 4,
`refactor(progression): support branching perk definitions`, merged).
`GameSession` (5926 LoC) is consolidated into a lean facade over three new
domain services; every pre-existing test's ORIGINAL assertions still pass
unchanged, and a new end-to-end journey test proves the full fresh-campaign
loop.

### Final schema version

No schema version changed in this step. `ContentCatalog`'s manifest version
stays `1` (`config/content/catalog.json`); `PartyCarry`/`BattleContext`/
`PerkDefinition` shapes are exactly the target contracts this ledger already
recorded above (Step 1) -- this step relocates the code that implements
them, it does not change any persisted shape.

### Domain services extracted

| Service | File | Moved |
|---|---|---|
| `PartyService` | `scripts/campaign/party_service.gd` | Party creation/capacity, member assignment, deployment, movement/route consumption, in-field carry equipping, carry deposit/forfeiture, dead-unit gear salvage into carry (37 functions). |
| `EncounterService` | `scripts/campaign/encounter_service.gd` | Active encounter instance management, vacancy countdowns, threat ratings, objective tracking, `BattleContext` claim/victory/retreat/defeat lifecycle, catalog resolution (`get_expedition`/overlay) (41 functions). |
| `ProgressionService` | `scripts/progression/progression_service.gd` | XP distribution, level-up thresholds, perk queries/choice, specialization promotion, every effective-stat formula (hit chance, melee/missile, health/MP, weapon/armor-derived values, scouting/spell range) (42 functions). |

Each service is a stateless `RefCounted` constructed once in
`GameSession._init()` and holds only a back-reference (`_gs`) to the owning
`GameSession` instance; every read/write goes through `_gs.parties`,
`_gs.adventurers`, `_gs.active_encounters`, `_gs._battle_context`, etc. --
GameSession's own durable dictionaries, never a private copy. `GameSession`
keeps a one-line forwarding method under the ORIGINAL name for every moved
function (public and underscore-prefixed alike, since several "private"
helpers -- `_grid_distance`, `_ensure_active_battle_context`,
`_roll_and_queue_loot`, `_pending_perk_slot_count`, `_overlay_content_
catalog_definition`, `_start_encounter_vacancy`/`_advance_encounter_
vacancies` -- turned out to have real external callers in
`scripts/battle/battle_controller.gd`, `scripts/battle/battlefield.gd`,
`scripts/tools/campaign_sim.gd`, `scripts/world/world_map.gd`, and
`scripts/progression/perk_catalog.gd`), so every pre-existing internal
self-call and every external `GameSession.foo(...)` call site keeps working
completely unchanged -- no caller outside `game_session.gd` needed to
change. Buildings/shop/blacksmith/alchemy/runic workshop, item/inventory,
campaign-guide, scouting-intel/quests, and `CampaignSnapshot`
export/import/validation stayed in `GameSession` itself -- none of these are
named in Step 5's own service-boundary list, and several (intel/quests,
healing) are cross-cutting in a way that did not cleanly fit any one of the
three named services (see "Judgment calls" below).

### Legacy seams: grep-verified zero references

```
$ grep -rn "pending_reward\|pending_gear\|pending_mana_crystals\|battle_reward\|battle_gear\|battle_mana_crystals" --include="*.gd" scripts/ tests/
```
Zero matches in live code -- every remaining hit is a historical doc
comment or a descriptive test function name (e.g.
`test_reset_clears_gold_and_any_in_flight_battle_reward`), not a real field
reference. Confirmed already eliminated by Steps 2-3; this step introduced
no regression.

```
$ grep -rn "_cover_tiles_for_encounter" --include="*.gd" scripts/ tests/
```
Zero function definitions or call sites -- the only hits are doc-comment/
assertion-message mentions of the retired name. `EXPEDITIONS` itself still
exists as the legacy skeleton `_overlay_content_catalog_definition()`
overlays authored `ContentCatalog` fields onto (Step 3's already-reviewed
design, unchanged by this step) -- only 2 encounter ids
(`obj_tier1_1_goblin_outpost`, `goblin_camp`) are migrated into
`config/content/encounters/`; every other id is untouched legacy data, not
a "fallback for a migrated encounter."

### Test-suite evidence

Pre-refactor baseline (re-confirmed before this step's changes): 82 scripts,
2221/2221 tests passing, 9446 asserts, 1 pre-existing known orphan.

Journey test red (`test_stage_6_foundations.gd` did not yet exist / did not
yet correctly drive the real two-party, catalog-battle, carry-isolation,
branching-perk, snapshot-round-trip arc):
```
[Failed]: ["party_001"] expected to not equal ["party_001"]: Setup: the two parties must have distinct ids
[Failed]: [VECTOR2I(4, 3)] expected to equal [VECTOR2I(3, 4)]: Party 1 must have arrived at the encounter's own catalog position
[Failed]: A second party must not be able to claim a battle while another party's battle is active
SCRIPT ERROR: Invalid access to property or key 'cover_tiles' on a base object of type 'Node2D (battle_controller.gd)'.
0/1 passed.
```
(Second red iteration, after fixing the missing Guild-Hall-upgrade
precondition for a second party, surfaced a real API-shape bug in the test
itself -- `battlefield.gd`'s own `grid` property is the child
`BattleController` node, not the board -- fixed to `controller.grid.
cover_tiles`/`controller.get_unit_at(...)`.)

Journey test green:
```
Scripts   1
Tests     1
Passing Tests   1
Asserts   76
---- All tests passed! ----
```

Full suite after extraction, journey test included:
```
Scripts              83
Tests              2222
Passing Tests      2222
Asserts            9522
Orphans               1
---- All tests passed! ----
```
2221 of those 2222 are the exact pre-existing tests with their ORIGINAL
assertions unchanged (verified by diff review of every touched file); the
2222nd is the new journey test. The one pre-existing test that needed a
change was not a behavioral assertion but a reflection-based meta-test
(`test_every_durable_field_is_carried_by_the_snapshot_contract` in
`tests/unit/test_game_session.gd`), which enumerates every `GameSession`
instance var and asserts it is either snapshot-carried or on an explicit,
reasoned exclusion allowlist -- it correctly flagged the three new service
fields as looking durable, and was extended with a documented allowlist
entry explaining they hold no state of their own (exactly the mechanism
that test's own doc comment says to use).

### Other final-check commands

- `make campaign-sim`: 5/5 representative-seed victories (seeds 4, 9, 10,
  12, 14), 12/12 battles won per run, 0 wipes, 0 stalemates -- identical to
  the protected baseline above.
- `make check` (`godot --headless -s addons/gut/gut_cmdln.gd -gexit`): exit
  0, all 2222 tests passing.
- `godot --headless --path . --editor --quit`: exit 0, no import/scan
  errors.
- `git diff --check`: clean.
- Content lint (`test_content_catalog.gd`, all catalog files): 20/20
  passing.
- Fixed-seed scenario replay (`test_scenario_runner.gd`): 19/19 passing,
  including its own byte-identical-same-seed reproduction assertions.
- Fixed-seed campaign replay (`test_campaign_sim.gd`): 24/24 passing,
  including `test_run_campaign_is_fully_deterministic_for_a_fixed_seed` and
  the representative-victory-seed-set test.

### Judgment calls / scope not moved

- Scouting/intel and Guild Hall quest-posting (`_register_encounter_intel_
  and_quest`, `_advance_intelligence_and_quests`, `get_encounter_intel`,
  `get_quests`/`accept_quest`, etc.) stayed in `GameSession` -- not named in
  any of the three services' task-3 bullet lists, and it is a genuinely
  separate subsystem from encounter-instance lifecycle proper.
- Healing/permadeath aftermath (`resolve_battle_deaths`, `apply_battle_
  aftermath`, `apply_battle_mp_aftermath`, `heal_party_member`,
  `_apply_natural_recovery`) stayed in `GameSession` -- cross-cutting
  between roster, party membership, and health state; no single named
  service was a clean home for it without inventing a fourth service this
  plan does not authorize.
- Recruitment-offer vacancy machinery (`_start_recruitment_vacancy`,
  `_spawn_next_recruitment_offer`, etc.) stayed in `GameSession` -- a
  roster/recruitment concern, not named under `PartyService` or
  `EncounterService`.
- `compute_effective_max_health`/`compute_effective_action_points`/
  `compute_effective_defense` (the three `static func`s `battle_state_
  factory.gd`/`campaign_snapshot.gd` call via the preloaded script
  constant) were left in `GameSession` unmoved -- they take every input
  explicitly and touch no instance state, so moving them would have risked
  breaking their existing external static call sites for no behavioral
  gain.

These are scope decisions made to keep the extraction's correctness
provable within this step's own verification budget, not gaps discovered
and left unfixed -- each subsystem above is internally cohesive and was
left completely alone (no line inside it changed), so none of them carry
extraction risk.

### Deferred beyond Stage 6

No new deferrals. Carried forward from Steps 1/4 (dispositions unchanged,
not re-litigated here):
- **Rogue** (G1): stays deferred, per the Stage 5/Stage 6 gate disposition
  above.
- **Scripted mid-battle content events** (G2): out of scope for the first
  `ContentCatalog` schema version, per the gate disposition above.
- **Respec mechanic** (G3): no respec policy shipped, per the gate
  disposition above.

### Manual check (pending human signoff)

Not yet performed -- no display available in this environment. See this
plan's [05-domain-extraction-and-stage-6-exit.md](05-domain-extraction-and-stage-6-exit.md#manual-check)
for the exact steps to relay to the user via `make play`.
