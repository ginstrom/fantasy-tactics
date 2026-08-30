# Catalog-owned authored encounters

**Status:** Discovery complete; the concrete-blocker gate is not met because
no new authored-content feature has been selected. No implementation plan is
authorized.

## Decision

If a new authored campaign encounter is approved, the bounded continuation
should make `ContentCatalog` the source of truth for the complete existing
linear authored-campaign definition. That would unblock adding the approved
encounter as JSON content, without a parallel `GameSession.EXPEDITIONS` or
`GameSession.CAMPAIGN_OBJECTIVES` edit.

This is deliberately a catalog-ownership slice, not a general content-system
rewrite. It leaves sandbox vacancy selection, enemy-template stat definitions,
rewards, persistence format, and Battlefield rendering ownership unchanged.

## Demonstrated blocker

The shipped catalog already validates and normalizes an authored encounter's
identity, board, formation, reward multiplier, and
`prerequisite_objective_id` (`scripts/content/content_catalog.gd`). Production
Battlefield construction reads its geometry from that definition
(`scripts/battle/battle_controller.gd`).

But the live campaign cannot recognize a catalog-only authored encounter:

- `EncounterService.is_authored_encounter()` checks
  `GameSession.CAMPAIGN_OBJECTIVES`.
- `get_expedition()` returns `{}` unless the id exists in
  `GameSession.EXPEDITIONS`; catalog data is only overlaid onto that legacy
  record.
- `complete_campaign_objective()` reads the next id from the static campaign
  table, and fresh-session startup seeds active encounters from `EXPEDITIONS`.

Consequently, an approved new authored node, or a decision to make an existing
node fully JSON-owned, would require coordinated edits to JSON plus two static
GameSession tables. No such product feature is currently selected: existing
nodes can still be added by using the legacy tables. This is therefore an
evidence-backed migration direction, not a demonstrated current blocker; the
Step 10 gate remains closed.

## Candidate comparison

| Candidate | State owner and public API | Migration and focused proof | Rollback boundary | Why it is bounded |
| --- | --- | --- | --- | --- |
| **Catalog-owned authored encounters (recommended when a new node is approved)** | `GameSession` retains durable progress, active instances, and battle context. `ContentCatalog` owns normalized authored definitions; `EncounterService` exposes the existing query/lifecycle API (`get_expedition`, `is_authored_encounter`, `can_enter_encounter`, `complete_campaign_objective`). | Extend the schema with `title_key`, `desc_key`, and `reward_summary_key`; `encounter_id` is the definition's stable `id`. Migrate the 12 current authored nodes from the two static tables into catalog files; derive one validated linear campaign graph from their prerequisites. Add complete-field parity, catalog-only node lookup, root/one-successor/acyclic validation, banner/World Map progression, clear-XP/loot/gold, and real Battlefield + CampaignSim parity tests. | Keep legacy sandbox `EXPEDITIONS`, vacancy template order, and existing public `GameSession` forwarders. Revert the catalog-owned graph adapter and files as one slice; snapshots remain untouched. | Changes one definition boundary while preserving the durable owner and existing callers. It proves an approved authored-content path without moving equipment, classes, or generic event scripting. |
| One additional durable `GameSession` service (workshop/inventory) | Durable state would remain in `GameSession` and a new service would expose existing workshop or inventory calls. | Would need a selected feature such as concurrent crafting jobs or item-instance transfer, then service-level and snapshot regressions. No such feature/regression is currently demonstrated. | The service and its forwarders could be reverted, but its broad call-site surface makes a speculative slice costly. | Smaller than a rewrite, but not yet justified by a concrete blocked change. Defer. |
| Battlefield presentation seam | `Battlefield` owns scene rendering/input; `BattleController` owns battle rules/state. A seam could consume already-projected playback frames. | The per-step playback correction already supplies immutable frames and has Battlefield-level coverage. No current presentation feature is blocked by its remaining size. | A renderer adapter could be isolated, but it would duplicate a currently working projection path unless a new visual regression appears. | Do not extract for code-size alone. Defer. |

## Target contract

`ContentCatalog.load_catalog()` would remain fresh-read and stateless: there is
no cache, invalidation protocol, or live mutable catalog. Before the adapter
could be implemented, the JSON schema must add and validate the complete
objective presentation fields `title_key`, `desc_key`, and `reward_summary_key`.
The definition `id` remains its `encounter_id`. The adapter would derive a
**validated authored-campaign graph** only from definitions whose `category` is
`authored_objective`:

- exactly one root has an empty `prerequisite_objective_id`;
- every non-root prerequisite exists in the authored subset;
- no cycles or forks are accepted for the current linear first campaign;
- an authored definition supplies the complete public objective record consumed
  by Campaign Objective Banner and World Map, plus the public encounter record
  consumed by battle construction and intelligence;
- `GameSession` remains the sole owner of progress arrays, selection, active
  instances, and save/import orchestration.

The public `GameSession` and `EncounterService` method names stay stable.
Sandbox `EXPEDITIONS` remain static until a separate, evidence-backed feature
requires their migration. `BattleController` keeps consuming a normalized
definition for board/spawn/cover data, rather than acquiring campaign logic.
The future parity scope is actual current behavior only: clear XP, enemy-loot
rolls, and gold. `reward_bonus_multiplier` is validated by the catalog today
but has no runtime consumer, so this discovery does not promise to preserve or
activate it.

## Explicit exclusions

- No broad domain-signal framework: no stale-view regression was found.
- No full-screen/embedded detail-view unification: route and focus ownership
  remain materially different.
- No `ContentCatalog` cache: fresh parsing is intentional for hand-edited
  content, and no reproducible performance/stale-state issue exists.
- No general event scripting, procedural generation, inventory/equipment
  migration, or BattleController rewrite.

## Proposed follow-up plan shape (not yet authorized)

If the user first selects a new authored encounter and approves this direction,
create a separate folderized plan with an `index.md` and serial steps:

1. Add pure complete-objective-schema/catalog-graph red tests and validation;
   migrate no runtime caller.
2. Make `EncounterService` resolve authored definitions and progression through
   that graph while keeping its public API and legacy sandbox path intact.
3. Migrate the 12 existing authored nodes; prove complete-field, Banner/World
   Map, final-node, clear-XP/loot/gold, Battlefield, and CampaignSim parity;
   run the full suite, independent review, and the documented first-campaign
   manual check.

Each runtime step will use a regular branch, red/green focused GUT evidence,
`make check`, headless editor parsing, `git diff --check`, independent review,
and user signoff before local merge. It will not push or open a PR.

## Approval requested

Select a concrete new authored encounter (or another source-confirmed blocked
feature) and approve this bounded direction to authorize writing the separate
implementation plan. Approval of that plan will still be required before any
extraction code is started.
