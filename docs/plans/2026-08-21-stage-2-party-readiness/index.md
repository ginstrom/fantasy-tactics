# Stage 2 — Party Readiness for the Full Campaign

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contract:** [`docs/implementation-roadmap.md`](../../implementation-roadmap.md#stage-2--party-readiness-for-the-full-campaign), [`docs/designs/class-system.md`](../../designs/class-system.md), [`docs/designs/campaign-loop.md`](../../designs/campaign-loop.md), and [`docs/designs/monster-manual.md`](../../designs/monster-manual.md).

**Goal:** Make Warrior, Scout, and Cleric preparation choices legible, persistent, deterministic, and useful across the tier-1-to-tier-3 authored encounter patterns.

**Architecture:** Preserve `GameSession` as the sole durable owner of adventurer progression, HP/MP, recovery, party membership, and balance data; `GameManager` remains routing-only. Battle construction must continue to flow through `ScenarioContract` and `BattleStateFactory`, with `BattleController` owning battle-local action legality. The live checkout already has automatic class skill gains, ranged attacks/LoS, proximity Scout intel, Temple-gated Cleric offers, and battle-local Cleric spells; this plan closes the remaining contract gaps rather than creating parallel systems.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, `GameConfig`, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, headless campaign simulation.

---

## Live-checkout audit (2026-08-21)

Already present and protected:

- `CLASS_DEFINITIONS` drives automatic Warrior, Scout, and Cleric skill gains; new records do not carry the former `skill_points` field, and snapshot normalization removes the legacy field.
- Bows already hydrate range and occupied-endpoint line of sight into live battles and scenario battles. A deployed Scout within Manhattan distance three exposes only authored enemy count/type and danger; rewards and placement remain hidden.
- Temple construction creates an immediately recruitable Cleric; Cleric battle units begin with 3 battle-local MP and can use Heal/Bless through the existing action bar.
- The existing authored twelve-node ladder, enemy variants, equipment, potion action, wounds, retreat transaction, and representative-seed `make campaign-sim` route are the baseline.

Gaps this stage must close:

1. The only perk is hard-coded `bonus_move`; it cannot form data-backed, class-owned choices or resolve a second every-third-level slot.
2. MP is battle-local only. Natural recovery currently changes only HP (4/2/1), ignores Temple recovery, and Unit Details has no **Heal party member** action.
3. The runtime `Unit` has only the combat fields it currently needs; initial monsters are not represented as the complete shared tactical profile, and scenario hydration separately re-derives player stats.
4. Existing class and encounter tests prove individual slices, not the Stage 2 cross-role preparation choices, authored tier patterns, persistence, and representative deterministic evidence together.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-readiness-balance-contract.md](01-readiness-balance-contract.md) | Lock the previously deferred perk and campaign-healing numbers in canonical design/config data. | `docs/stage-2-readiness-contract` | clean `main` |
| 2 | [02-class-progression-and-perks.md](02-class-progression-and-perks.md) | Replace the one-off perk flow with class-owned, data-backed choices and recalibrated Warrior/monster baselines. | `feat/stage-2-progression-perks` | Step 1 merged |
| 3 | [03-persistent-mp-temple-and-details-healing.md](03-persistent-mp-temple-and-details-healing.md) | Add durable MP, capped recovery, and the validated Cleric details-view healing transaction. | `feat/stage-2-cleric-recovery` | Step 2 merged |
| 4 | [04-scout-ranged-and-tier-two-pattern.md](04-scout-ranged-and-tier-two-pattern.md) | Prove and complete the Scout's existing ranged/reconnaissance role against the tier-2 pattern. | `test/stage-2-scout-tier-two` | Step 3 merged |
| 5 | [05-shared-tactical-profile-migration.md](05-shared-tactical-profile-migration.md) | Migrate authored combatants and starter roster onto one profile without a stealth rebalance. | `feat/stage-2-shared-tactical-profile` | Step 4 merged |
| 6 | [06-authored-readiness-patterns.md](06-authored-readiness-patterns.md) | Tune/prove the tier-1, tier-2, and tier-3 authored patterns and their minimum variants/AI. | `feat/stage-2-authored-readiness-patterns` | Step 5 merged |
| 7 | [07-stage-2-exit-gate.md](07-stage-2-exit-gate.md) | Record deterministic and manual evidence for the full Stage 2 exit gate. | `test/stage-2-party-readiness-exit-gate` | Step 6 merged |

Steps are serial. Progression data defines the durable fields that MP/recovery and scenario hydration consume; profile migration must precede final encounter tuning. Do not parallelize them in this shared checkout.

## Non-negotiable invariants

- Do not reintroduce generic Attack/skill-point spending, a universal skill list, or an additional party model. A class displays and advances only skills it owns.
- Every third level produces exactly one pending class-eligible perk choice. Choosing a perk must validate class, eligibility, prerequisites, duplicate rules, and effect before mutating durable state.
- Step 1 must select and document the exact perk IDs/effects/prerequisites plus campaign-heal and MP values before any runtime implementation. It is the approval gate for intentionally deferred balance decisions, not permission to invent values while coding.
- Cleric current MP is durable; battle start hydrates from durable current/max MP, battle aftermath writes the surviving Cleric's MP back, and all recovery/healing clamps to maximum. A dead adventurer owns no persisted MP record.
- The details-view heal targets only a living party member of the same deployed party, or an Encampment adventurer when the Cleric is encamped. `GameSession` validates and mutates; UI only renders/requests it.
- Retain current cardinal movement, diagonal range-one melee, ranged occupied-endpoint LoS, button-only Move/Attack modes, seeded per-iteration RNG, and the real item/equipment hydration path.
- A profile migration preserves the documented current starter and monster combat outputs before intentional Step 6 tuning. Never introduce a simulator-only stat model.

## Common setup and final checks

Each step begins only after its predecessor is locally merged and the user has signed off on the preceding manual check:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Every runtime step follows red/green TDD: add the focused failing test, run it and record the expected failure, make the smallest implementation, then rerun it green. Finish each step with `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Do not push or open a PR. After its documented manual check and user signoff, commit only listed changed files, merge locally to `main`, and delete the branch.

## Exit evidence

Stage 2 is complete only when Step 7 records:

1. A party of up to five can field meaningful Warrior, Scout, and Cleric choices across all three authored tiers.
2. Deterministic scenarios prove class resources, class-compatible equipment hydration, capped HP/MP recovery, details healing, retreat aftermath, and progression/perk values.
3. Tier 1 demonstrates formation and banked-loot preparation; Tier 2 demonstrates Scout intel/ranged pressure plus armour/resistance/potions; Tier 3 demonstrates mixed-force target priority.
4. `make campaign-sim` succeeds on the documented representative seeds, and a user confirms the role readability in `make play`.

## Out of scope

The optional full Intelligence System, Watchtowers, Guild Hall quests, Rogue/Ranger specialization branches, Mage, broad new monster families, advanced perk primitives that lack supporting combat rules, multi-party play, and Stage 3 campaign assembly remain outside this plan.
