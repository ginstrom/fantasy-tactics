# Stage 5 — Strategic and Roster Expansion

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contract:** [`docs/implementation-roadmap.md`](../../implementation-roadmap.md#stage-5--strategic-and-roster-expansion), [`docs/designs/intelligence.md`](../../designs/intelligence.md), [`docs/designs/world-map-and-encounters.md`](../../designs/world-map-and-encounters.md), [`docs/designs/combat-system.md`](../../designs/combat-system.md), [`docs/designs/class-system.md`](../../designs/class-system.md), and [`docs/designs/monster-manual.md`](../../designs/monster-manual.md).

**Goal:** Expand the proven Borderlands game with strategic intelligence, new tactical decisions, a Mage, meaningful specializations, and multi-party strategy without weakening the completed one-party campaign or determinism.

**Architecture:** Stage 5 is a serial sequence of independently balanced vertical slices. `GameSession` owns new durable campaign, roster, encounter, quest, and party state; `GameManager` remains routing-only; scenes render that state and submit player intent. Every slice starts with a small decision/evidence contract, then uses the production `ScenarioContract`/`BattleStateFactory` path and transactional `CampaignSnapshot` import/export—never a simulator-only parallel model.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, `GameConfig`, `GameSession`, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, `CampaignSim`, real `.tscn` UI tests, and `make play`.

---

## Live-checkout audit (2026-08-23)

- Stage 4 is signed off in `docs/plans/2026-08-23-stage-4-engagement-presentation/`; its exit record reports five representative campaign-sim victories, 1,833 passing tests, and no unresolved repeated finding. Step 1 re-ran the same protected baseline before touching any documentation and reproduced identical numbers (5/5 seeds, 1833/1833 tests, clean headless editor import, clean `git diff --check`) at commit `590da0b`.
- The durable seams required by this plan already exist: `GameSession` owns one party, live encounter instances, World Map turns, scouting preview, and snapshot state; `GameConfig` has typed fallbacks; `CampaignSim` uses the representative seeds `4, 9, 10, 12, 14`; and `ScenarioContract`/`BattleStateFactory` seed battle RNG per iteration.
- Some later mechanics are only partial precedents, not Stage 5 completion: ranged unit line-of-sight and one-party proximity scouting exist, while persistent encounter intelligence, Watchtowers, quests, battlefield fog/terrain/reactions, Mage combat, specialization choices, and independent multi-party travel do not.
- **Load-bearing finding for Step 4:** `CampaignSim`'s own telemetry shows the *existing* Cleric spell system (the only spellcasting in the game today) is not exercised by representative-seed play — the current baseline reports "Full triad fielded: 0/5 runs" and "Total spell casts: 0". A Mage slice cannot rely on representative-seed campaign play alone to prove spellcasting counterplay; it needs deterministic scenario fixtures that guarantee composition.
- Full file:line evidence per feature area, and the decision-gate rows required before each later step's branch may start, live in [decision-ledger.md](decision-ledger.md).

## Sequence

| Step | Document | Objective | Branch | Depends on | Status |
|---|---|---|---|---|---|
| 1 | [01-stage-5-readiness-and-decision-contract.md](01-stage-5-readiness-and-decision-contract.md) | Audit the completed baseline and lock the decision ledger, slice metrics, snapshot/version policy, and scenario evidence before any expansion code. | `docs/stage-5-readiness-contract` | clean `main`, Stage 4 signoff | Signed off 2026-08-23 — baseline reproduced, D1 (intelligence quest duration/reward/cadence, Watchtower balance) approved; D2-D5 explicitly blocked |
| 2 | [02-optional-intelligence-and-quests.md](02-optional-intelligence-and-quests.md) | Add Watchtowers, persistent accumulating intelligence, and optional Guild Hall quests while keeping authored objectives guaranteed. | `feat/stage-5-intelligence-quests` | Step 1 merged and its intelligence choices approved | Merged 2026-08-23 — reviewed (approve with follow-ups, both fixed: duplicate intel rows, un-configed Scouting constant) and manually signed off after fixing a marker-persistence bug found in `make play` (World Map star glyph now reads the persistent intel record, not the transient in-range check) |
| 3 | [03-tactical-depth-primitives.md](03-tactical-depth-primitives.md) | Add battlefield visibility, terrain defense, avoidance/reaction resolution, and only the content that demonstrates their counterplay. | `feat/stage-5-tactical-depth` | Step 2 merged and tactical-contract choices approved | Merged 2026-08-23 — reviewed (approve with follow-ups: opportunity attacks scoped to melee-only reactors confirmed with user and recorded in the ledger, missing death-mid-move test added) and manually signed off |
| 4 | [04-mage-and-magical-counterplay.md](04-mage-and-magical-counterplay.md) | Add one MP-backed Mage combat loop plus explicit resistant/control counters and deterministic scenarios. | `feat/stage-5-mage-counterplay` | Step 3 merged and Mage spell/counter choices approved | Merged 2026-08-23 — reviewed (approve with follow-up: opportunity attacks could still land from an incapacitated/sleeping reactor, fixed) and manually signed off |
| 5 | [05-specializations.md](05-specializations.md) | Deliver root specializations one balanced branch at a time, including the deferred Rogue only after its counterplay is accepted. | `feat/stage-5-specializations` | Step 4 merged and a specialization order is approved | In progress — D4 approved 2026-08-23 (order: Knight → Archer → Battle Mage → Paladin); starting with Knight |
| 6 | [06-multi-party-strategy.md](06-multi-party-strategy.md) | Audit and replace the one-active-party assumption with independently travelling, selectable parties and bounded time escalation. | `feat/stage-5-multi-party` | Step 5 merged and multi-party/time choices approved | Not started |
| 7 | [07-stage-5-exit-gate.md](07-stage-5-exit-gate.md) | Prove save-safe, deterministic, comprehensible interaction among all delivered Stage 5 slices and obtain user signoff. | `test/stage-5-exit-gate` | Steps 1–6 merged | Not started |

Steps are serial. Do not begin a step merely because a heading exists in a design document: its decision gate must name the player decision, counterplay, encounter use, persistence change, automated proof, and manual check.

## Non-negotiable invariants

- Preserve the completed authored Borderlands arc: `obj_*` ids stay stable; required objectives remain immediately discovered on unlock, clear once, and never become optional quest/fog outcomes; victory remains distinct from free play.
- `GameSession` is the sole durable-state/rules owner and may not touch the scene tree. `GameManager` may validate and route but may not become a second party/quest/battle-state store.
- Keep values subject to balance iteration in `GameConfig` and its fallback defaults, with a schema/fallback test. Do not manufacture values for unspecified quest duration, expected-value reward, posting cadence, terrain distribution, spell list, specialization thresholds, or time-escalation curve.
- Preserve `CampaignSnapshot`'s transactional validation and backward-compatible migration. A failed import must not partly mutate the live session.
- Preserve `ScenarioContract`/`BattleStateFactory` construction and seeded, per-iteration RNG. New stochastic checks must be injectable or driven from the same seeded RNG; a simulation report is regression evidence, not proof of player comprehension.
- Keep the Stage 4 UI contracts: 64px orthogonal logical grids, button-only Move/Attack modes, WASD movement (`A` remains move-left), and right-click-only free facing at no AP cost.
- Never commit player saves, generated reports, screenshots, downloaded archives, or third-party assets without an explicit provenance/evidence decision. Do not push or open a PR.

## Common setup and final checks

Every runtime step starts only after its predecessor is locally merged and the user has signed off its manual check:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Use red/green TDD: add a focused failing GUT test, run it with `-gselect` or `-gunit_test_name` and record the expected failure, implement the smallest production change, then rerun green. Complete every runtime step with its focused tests plus:

```bash
make campaign-sim
make check
godot --headless --path . --editor --quit
git diff --check
```

Run `make campaign-sim-sweep` only as explicitly labelled exploratory evidence. After the documented manual check and user signoff, commit only the step's listed files, merge locally to `main`, delete the branch, and record the decision/evidence/commit handoff before starting the next step.

## Exit evidence

Stage 5 is complete only when Step 7 demonstrates that:

1. Optional discovery, scouting details, Watchtowers, and quests add preparation choices without ever hiding or blocking the authored campaign route.
2. Each tactical primitive has a readable counterplay loop, a real encounter use, deterministic scenario proof, and no duplicate/contradictory resolution path.
3. Mage and every delivered specialization alter tactical or strategic choices rather than only applying a stat bonus; each has an explicit counter and encounter use.
4. Multiple parties can be selected, dispatched, travel independently, scout independently, save/load transactionally, and advance bounded strategic time without corrupting a battle or the original campaign.
5. The representative campaign seeds still pass their protected Stage 3 safety/budget assertions, new deterministic scenarios cover every delivered mechanic, and the user signs off after manual `make play` verification.

## Out of scope

This plan does not promise Guild Hall tier 4, unbounded/free-play content, pack AI, broad status-effect trees, penetration, arbitrary spell branches, every specialization, automatic time escalation values, new art/audio intake, a universal win rate, or remote Git operations. A proposed expansion not needed by an approved slice remains deferred.
