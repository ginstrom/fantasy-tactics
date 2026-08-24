# Stage 6 — Content and Domain Foundations

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contracts:** [Stage 5 index](../2026-08-23-stage-5-strategic-roster-expansion/index.md), [Stage 5 decision ledger](../2026-08-23-stage-5-strategic-roster-expansion/decision-ledger.md), [campaign loop](../../designs/campaign-loop.md), [world map and encounters](../../designs/world-map-and-encounters.md), [weapon and armor inventory](../../designs/weapon-armor-inventory.md), [class system](../../designs/class-system.md), [combat system](../../designs/combat-system.md), and [movement/AP](../../designs/movement-and-action-points.md).

**Goal:** Replace legacy single-party reward globals, monolithic `GameSession` state accumulation, and hardcoded content seams with party-owned carried state, an explicit battle context, validated JSON-authored content, and prerequisite-capable branching perk definitions, leaving `GameSession` a lean durable-state facade over modular domain services.

**Architecture:** Stage 6 is a serial foundational refactor executed after the Stage 5 exit gate:
1. **Party-Owned Carried State:** Every party dictionary in `GameSession.parties` owns its own carried loot (`gold`, `gear`, `mana_crystals`, and `item_instance_ids`). Campaign-wide globals (`pending_reward`, `pending_gear`, `pending_mana_crystals`, `battle_reward`, `battle_gear`, `battle_mana_crystals`) are eliminated.
2. **Explicit Battle Context:** Combat lifecycle is governed by an immutable `BattleContext` (battle ID, owner party ID, encounter ID, local reward buffer, and lifecycle status), preventing race conditions or cross-party state leakage during multi-party campaign operations.
3. **Validated Authored Content Catalog:** Encounters, formations, spawn points, cover coordinates, and reward tables migrate from hardcoded script constants (e.g. `GameSession.EXPEDITIONS`, `BattleController._cover_tiles_for_encounter()`) into versioned JSON files validated by `ContentCatalog`. Production gameplay, `ScenarioContract`, and `CampaignSim` consume this single source of truth.
4. **Declarative Branching Perks:** Flat `CLASS_PERKS` arrays and static `PERK_TREE_SIZE` caps are replaced with prerequisite-gated perk DAGs and a bounded `PerkEffectResolver`, eliminating bespoke `ActionMode` branching in `BattleController`.
5. **Domain Decomposition Facade:** Pure business logic is extracted from `GameSession` (5,700+ LoC) into focused domain services (`PartyService`, `EncounterService`, `ProgressionService`, `ContentCatalog`), keeping `GameSession` as a lightweight durable facade.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, JSON, `GameSession`, `GameManager`, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, `CampaignSim`, and `make play`.

## Scope and explicit non-goals

- Stage 5 must be locally merged and manually signed off first. Do not start this plan while its Step 6 or Step 7 is active.
- Existing player saves are **unsupported during this playtesting refactor**. A clean format reset/replacement is performed. Fresh saves must validate transactionally into scratch state before applying to live session state.
- Do not import a general scripting language, external mod loader, procedural map generator, arbitrary status-effect DSL, or unbounded visual perk editor.
- Do not change Stage 4 controls: 64px logical grids, button-only Move/Attack, WASD (`A` moves left), or right-click free facing with no AP cost.
- Keep durable rules/state in `GameSession` and domain services; scenes render and submit player intents; `GameManager` routes and validates scene transitions only.

## Stage 5 carry-forward decision gates

Step 1 must copy the final disposition of every unresolved Stage 5 ledger row into this plan's decision record. In particular, do not begin the named implementation step until the user has approved:

| Gate | Needed decision | Blocks |
|---|---|---|
| G1 | Whether Rogue is delivered now, and its player choice, counterplay, encounter use, persistence, deterministic proof, and manual check | Step 4, if Rogue is included |
| G2 | The first authored-content schema's supported encounter hooks: objective unlocks, reward types, terrain, cover layout, and scripted event boundary | Step 3 |
| G3 | The first branching perk tree's branch count, respec policy (default: none), and approved effect/action vocabulary | Step 4 |
| G4 | Multi-party simultaneous arrival and encounter lock resolution rules after Stage 5 Step 7 | Step 2 |

No gate authorizes invented balance values. Put tunable approved values in `GameConfig` plus `config/game_config.json`; authored identity/layout data belongs in the content catalog.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-stage-6-contract-and-baseline.md](01-stage-6-contract-and-baseline.md) | Establish post-Stage-5 baseline, reset policy, decision record, target contracts, and domain service boundaries. | `docs/stage-6-foundations-contract` | Stage 5 exit gate signed off |
| 2 | [02-party-owned-rewards-and-battle-context.md](02-party-owned-rewards-and-battle-context.md) | Migrate carried/battle rewards, field equipping, dead unit salvage, and battle ownership to `party.carry` and `BattleContext`. | `refactor/party-owned-rewards` | Step 1 merged; G4 closed |
| 3 | [03-authored-content-catalog.md](03-authored-content-catalog.md) | Ship validated JSON content catalog, migrate authored encounters & cover coordinates, unify production & simulator consumers. | `refactor/authored-content-catalog` | Step 2 merged; G2 approved |
| 4 | [04-branching-perk-definitions.md](04-branching-perk-definitions.md) | Replace flat perk lists with prerequisite DAGs, exclusive choices, and bounded `PerkEffectResolver`. | `refactor/branching-perks` | Step 3 merged; G1/G3 approved |
| 5 | [05-domain-extraction-and-stage-6-exit.md](05-domain-extraction-and-stage-6-exit.md) | Consolidate domain services behind `GameSession` facade, prove deterministic multi-party campaign loop and exit gate. | `test/stage-6-foundations-exit` | Steps 2–4 merged |

## Invariants

- **Party Carry Isolation:** A party's carried gold, gear, crystals, and unique item instances exist solely in that party's `carry` record. Multi-party operations (travel, retreat, wipe, encampment banking, field equip) never leak state between parties.
- **Battle Context Integrity:** A live battle is owned by exactly one `BattleContext` bound to a specific party and encounter. Scene navigation, route updates, UI selection changes, or secondary party movements cannot alter or overwrite the active battle's context.
- **Single Source of Content:** Every encounter (authored and sandbox template), cover layout, spawn coordinate, and loot table is loaded from the JSON `ContentCatalog`. No parallel hardcoded tables remain in `EXPEDITIONS`, `BattleController`, or test runners.
- **Declarative Progression Rules:** Perk eligibility and prerequisites are resolved by declarative rules in `PerkCatalog`. UI never computes prerequisite trees; combat effects execute via `PerkEffectResolver` rather than ad-hoc controller flags.
- **Transactional Save Validation:** `CampaignSnapshot` validates all party carry records, battle contexts, and progression trees in a scratch copy. Malformed or legacy format payloads reject cleanly without mutating live session state.

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

