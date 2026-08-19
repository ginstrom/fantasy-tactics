# Core Loop Verification Remediation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Close the three verification findings by proving the full Warrior/Scout/Cleric campaign loop, making simulator evidence representative and honest, and restoring the audio-bus runtime contract.

**Architecture:** Extend the canonical `ScenarioContract` → `BattleStateFactory` boundary so it hydrates the same Cleric battle-local state used by runtime combat. Keep `CampaignSim` as the macro-loop driver, but give it explicit seed-list modes. Keep the Godot bus layout project-owned and testable.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, Make.

---

## Scope

- A scenario can name a Cleric; its factory-built unit has class-owned spells and 3 battle-local MP.
- Campaign simulation recruits and fields the Warrior/Scout/Cleric triad, with deterministic spell policy and telemetry.
- `make campaign-sim` runs an explicit representative seed list. Numeric sweeps remain opt-in and visibly labelled as samples.
- `project.godot` references `default_bus_layout.tres`; that layout supplies Music and SFX routed to Master.
- Do not retune campaign balance, redesign Cleric spells, add a parallel battle model, or replace audio assets.

## Execution order

| Step | Document | Branch | Depends on | Outcome |
|---|---|---|---|---|
| 1 | [Cleric scenarios and simulation](01-cleric-scenario-and-campaign-sim.md) | `fix/campaign-sim-cleric-coverage` | main | Full-triad, deterministic campaign simulations exercise Cleric spells. |
| 2 | [Representative seed command](02-representative-seed-command.md) | `fix/campaign-sim-representative-seeds` | Step 1 | Default evidence runs named representative seeds. |
| 3 | [Audio bus contract](03-audio-bus-contract.md) | `fix/audio-bus-contract` | Step 2 | Music/SFX routing is restored and structurally tested. |

## Shared setup and merge contract

Read `docs/dev/README.md` and `docs/dev/testing.md` first. Use the existing checkout, not a worktree:

```bash
git status --short --branch
git checkout main && git pull
git checkout -b <step-branch>
```

Do not discard or stage unrelated generated `.uid` files or pre-existing `project.godot` edits. Use focused GUT checks with `-gselect`, then `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`.

After the manual verification listed in each step and user sign-off, merge locally only:

```bash
git checkout main
git merge <step-branch>
git branch -d <step-branch>
```

Never push or open a PR unless separately requested.

## Final evidence

```bash
make check
make campaign-sim
godot --headless --path . --editor --quit
git diff --check
git status --short --branch
```

Manual final check: recruit/deploy the three-class party, use Heal and Bless in battle, inspect representative-simulation output, and confirm independent Master/Music/SFX controls.
