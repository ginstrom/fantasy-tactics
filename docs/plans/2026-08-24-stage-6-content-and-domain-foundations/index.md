# Stage 6 — Content and Domain Foundations

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contracts:** [Stage 5 index](../2026-08-23-stage-5-strategic-roster-expansion/index.md), [Stage 5 decision ledger](../2026-08-23-stage-5-strategic-roster-expansion/decision-ledger.md), [campaign loop](../../designs/campaign-loop.md), [world map and encounters](../../designs/world-map-and-encounters.md), [class system](../../designs/class-system.md), [combat system](../../designs/combat-system.md), and [movement/AP](../../designs/movement-and-action-points.md).

**Goal:** Replace the current one-party reward globals and code-authored expansion seams with party-owned state, validated authored content, and prerequisite-capable perk definitions, while keeping `GameSession` a durable-state facade instead of a growing god object.

**Architecture:** Stage 6 is a serial refactor after the Stage 5 exit gate. Content is loaded from a versioned, human-readable JSON catalog into immutable normalized definitions; live encounters, production battle construction, deterministic scenarios, and CampaignSim consume that same definition rather than parallel representations. Party-owned carried inventory and an explicit battle context remove attribution from global `pending_*`/`battle_*` buckets. Perks become declarative nodes with prerequisites and typed effect/action metadata; a bounded resolver preserves unusual mechanics without a new controller mode for every perk.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, JSON, `GameSession`, `GameManager`, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, `CampaignSim`, and `make play`.

## Scope and explicit non-goals

- Stage 5 must be locally merged and manually signed off first. Do not start this plan while its Step 6 or Step 7 is active.
- Existing player saves are **unsupported during this playtesting refactor**. A format reset/replacement is allowed. Fresh saves must still validate transactionally and a rejected fresh-format payload must not mutate live state.
- Do not import a general scripting language, mod loader, procedural map generator, arbitrary status-effect DSL, or unbounded perk editor.
- Do not change Stage 4 controls: 64px logical grids, button-only Move/Attack, WASD (`A` moves left), or right-click free facing with no AP cost.
- Keep durable rules/state in `GameSession`; scenes render and submit intents; `GameManager` routes/validates only.

## Stage 5 carry-forward decision gates

Step 1 must copy the final disposition of every unresolved Stage 5 ledger row into this plan's decision record. In particular, do not begin the named implementation step until the user has approved:

| Gate | Needed decision | Blocks |
|---|---|---|
| G1 | Whether Rogue is delivered now, and its player choice, counterplay, encounter use, persistence, deterministic proof, and manual check | Step 4, if Rogue is included |
| G2 | The first authored-content schema's supported encounter hooks: objective unlocks, reward types, terrain, and scripted event boundary | Step 3 |
| G3 | The first branching perk tree's branch count, respec policy (default: none), and approved effect/action vocabulary | Step 4 |
| G4 | Any remaining Stage 5 multi-party acceptance finding, especially simultaneous-arrival behavior, after Step 7 | Step 2 |

No gate authorizes invented balance values. Put tunable approved values in `GameConfig` plus `config/game_config.json`; authored identity/layout data belongs in the content catalog.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-stage-6-contract-and-baseline.md](01-stage-6-contract-and-baseline.md) | Establish the post-Stage-5 baseline, reset policy, decision record, and target boundaries. | `docs/stage-6-foundations-contract` | Stage 5 exit gate signed off |
| 2 | [02-party-owned-rewards-and-battle-context.md](02-party-owned-rewards-and-battle-context.md) | Move carried/battle rewards and encounter ownership to the owning party/battle context. | `refactor/party-owned-rewards` | Step 1 merged; G4 closed |
| 3 | [03-authored-content-catalog.md](03-authored-content-catalog.md) | Ship one validated JSON catalog and migrate one production authored encounter through it. | `refactor/authored-content-catalog` | Step 2 merged; G2 approved |
| 4 | [04-branching-perk-definitions.md](04-branching-perk-definitions.md) | Replace flat perk lists with prerequisite-capable definitions and bounded effect/action resolution. | `refactor/branching-perks` | Step 3 merged; G1/G3 approved as applicable |
| 5 | [05-domain-extraction-and-stage-6-exit.md](05-domain-extraction-and-stage-6-exit.md) | Extract catalog/inventory/progression/encounter domains behind `GameSession` and prove the integrated route. | `test/stage-6-foundations-exit` | Steps 2–4 merged |

## Invariants

- A party's carried gold, gear, crystals, and unique item instance ids are visible, equipped, forfeited, and deposited only through that party. Encampment stores remain campaign-owned.
- A battle context has exactly one owner party and encounter; it cannot be overwritten by a UI selection change, route update, or second party arrival.
- Every content reference is a stable string id. The catalog loader rejects duplicate ids, missing references, invalid positions, unknown template ids, and invalid terrain/reward shapes before a play session starts.
- Production encounter construction, `ScenarioContract` fixtures, and `CampaignSim` derive from the same normalized content definition. Test fixtures may override explicit fields but may not duplicate production encounter data.
- Perk availability is derived from declarative prerequisites and mutually exclusive choices. UI never decides eligibility, and a perk effect must have deterministic scenario coverage before it is shipped.
- `CampaignSnapshot` remains all-or-nothing for the current fresh format. It need not import prior formats.

## Common setup and final checks

For every runtime step, after its predecessor has been locally merged and signed off:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Use focused GUT red/green work with `-gselect` or `-gunit_test_name`, never `TEST=...`. Complete a runtime step with:

```bash
make campaign-sim
make check
godot --headless --path . --editor --quit
git diff --check
```

Keep generated reports, saves, and screenshots outside Git. Each step receives an independent read-only review before its documented `make play` check; user signoff authorizes that step's local commit/merge only. Never push or open a PR.

