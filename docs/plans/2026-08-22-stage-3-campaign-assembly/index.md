# Stage 3 — Complete Campaign Assembly and Proof

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contract:** [`docs/implementation-roadmap.md`](../../implementation-roadmap.md#stage-3--complete-campaign-assembly-and-proof) and [`docs/designs/campaign-loop.md`](../../designs/campaign-loop.md).

**Goal:** Deliver a reproducibly completable 60–90 minute Borderlands campaign from New Game through the Ogre victory, followed only by clearly labelled, objective-neutral free play.

**Architecture:** Keep `GameSession` the sole durable owner of authored progression, economy, victory, free-play, and snapshot state. `CampaignSim` must exercise those same public APIs and construct battles through `ScenarioContract` and `BattleStateFactory`; it is evidence, never a second rules model. UI scenes render durable state and request routes through `GameManager` without creating campaign state of their own.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, `GameConfig`, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, headless campaign simulation.

---

## Live-checkout audit (2026-08-22)

Already present and protected:

- `GameSession` owns the twelve-objective ladder, final-boss entry, idempotent campaign victory, free-play flag, non-respawning authored IDs, and the durable victory summary.
- The Victory Screen already reads the durable summary and routes Continue to the Encampment; a representative five-seed `make campaign-sim` command and a separate Cleric-triad seed are deterministic.
- The Shop, Guild Hall, Temple, Blacksmith, Alchemy Workshop, Runic Workshop, recruitment, recovery, banking, and snapshot mechanisms have focused unit coverage.

Gaps to close:

1. The canonical contract still defers the final-boss composition/reward/free-play presentation and does not lock an observable economy/level budget for the full arc.
2. Current simulator telemetry proves victory but does not record the complete objective transition history, recovery/resources, save/load checkpoints, or enough policy-independent evidence to compare a campaign-balance change.
3. Existing full-loop UI coverage stops at the early campaign; it does not prove final victory presentation, Continue semantics, or that later repeatable vacancies cannot reopen an authored objective.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-stage-3-balance-and-boundary-contract.md](01-stage-3-balance-and-boundary-contract.md) | Lock the full-arc economy/level budget, final-boss presentation, and objective-neutral free-play boundary. | `docs/stage-3-campaign-contract` | clean `main` |
| 2 | [02-campaign-telemetry-and-comparison.md](02-campaign-telemetry-and-comparison.md) | Record comparable full-arc transitions, losses, recovery, resources, and outcomes on the documented seed set. | `feat/stage-3-campaign-telemetry` | Step 1 merged |
| 3 | [03-final-victory-and-free-play-boundaries.md](03-final-victory-and-free-play-boundaries.md) | Prove and repair final-boss routing, victory presentation, Continue, and repeatable-free-play isolation. | `feat/stage-3-victory-free-play` | Step 2 merged |
| 4 | [04-authored-arc-economy-and-boss-tuning.md](04-authored-arc-economy-and-boss-tuning.md) | Apply only approved authored-arc, reward, upgrade, recruitment, Shop, workshop, recovery, and boss tuning. | `feat/stage-3-arc-tuning` | Steps 1–3 merged |
| 5 | [05-scripted-full-arc-save-load.md](05-scripted-full-arc-save-load.md) | Add a real public-API journey proving save/load at defined full-arc checkpoints preserves legal progression. | `test/stage-3-full-arc-save-load` | Step 4 merged |
| 6 | [06-stage-3-exit-gate.md](06-stage-3-exit-gate.md) | Collect deterministic comparison evidence and user manual signoff for the complete campaign. | `test/stage-3-campaign-assembly-exit-gate` | Step 5 merged |

Steps are serial. The balance contract defines the acceptance bands; telemetry makes the bands observable before any tuning; final-boundary rules and full-arc persistence must be stable before declaring a tuned campaign complete.

## Non-negotiable invariants

- Preserve the stable `obj_*` IDs and the single active party. Do not create a second authored catalog or a simulator-only economy/progression model.
- Required authored encounters remain guaranteed-discoverable, clear once, and never respawn or reopen. A repeatable vacancy may exist only after victory and must not mutate `completed_objectives`, `campaign_objective_id`, or replay Victory.
- Keep `GameSession` durable and scene-free; keep `GameManager` routing-only. Snapshot import is transactional and cannot bank transient rewards or fabricate victory/free-play state.
- Every campaign simulation battle continues through `ScenarioContract` and `BattleStateFactory`, with all randomness seeded per iteration. `make campaign-sim-sweep` is exploratory sample evidence, never a completion claim.
- Tuning may change only values explicitly approved in Step 1. Do not use a larger party, optional Intelligence, multi-party dispatch, new class branches, or broad monster families to make the boss pass.

## Common setup and final checks

Each runtime step begins only after its predecessor is locally merged and its manual check has user signoff:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Use red/green TDD: add the focused failing test, run it and record the expected failure, make the smallest repair, then rerun it green. Finish every runtime step with its focused GUT command, `make campaign-sim`, `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Preserve the comparison JSON and command output outside Git or under a user-approved evidence path; never commit player saves or generated reports by default. Do not push or open a PR. After the step’s documented manual check and user signoff, commit only its listed files, merge locally to `main`, and delete its branch.

## Exit evidence

Stage 3 is complete only when Step 6 records all of these:

1. Every documented representative seed reaches final victory, and its structured report names the exact seed list and outcome data.
2. The approved objective-by-objective resource/level/upgrade bands are met or a user-approved exception explains the divergence.
3. A scripted save/import journey at defined pre-boss and post-victory checkpoints preserves campaign, rewards, roster, recovery, upgrades, and free-play state without duplicate objectives or rewards.
4. Defeating the final boss displays one victory summary; Continue enters clearly labelled optional free play, whose repeatable encounters cannot reopen authored objectives or replay victory.
5. A user completes the arc in `make play`, can explain any setback from the UI/state, and signs off that victory is distinct from free play.

## Out of scope

Stage 4 engagement/presentation iteration, optional Intelligence/Watchtowers/quests, multi-party strategy, Rogue/Mage/specializations, advanced combat primitives, and broad post-victory content remain outside this plan.
