# Campaign Progression and Population Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Add immediate XP/level/skill/perk progression and bounded,
vacancy-timed encounter and recruitment population to the first campaign.

**Architecture:** Durable rules and all fractional arithmetic live in
`GameSession`. Battle code asks it for the selected adventurer's derived
combat values and reports kill/clear events. A modal `LevelUp` UI is owned by
the battlefield, so it can suspend input safely while never owning campaign
data. Available encounter instances and recruitment offers are explicit
session collections, replacing the current always-visible static catalogues.

**Tech Stack:** Godot 4, GDScript, GUT, semantic translation keys in
`translations/en.tres`.

---

## Scope and sequencing

Read [design.md](design.md) first. Deliver the tasks in order:

1. [01-progression-domain.md](01-progression-domain.md) — durable stats and
   exact XP/level/skill/perk rules.
2. [02-battle-xp-and-derived-stats.md](02-battle-xp-and-derived-stats.md) —
   award kill/clear XP once and apply derived health, hit chance, and movement.
3. [03-level-up-ui-and-unit-details.md](03-level-up-ui-and-unit-details.md)
   — immediate modal level-up flow and readable progression screens.
4. [04-vacancy-timed-population.md](04-vacancy-timed-population.md) — active
   two-site/four-offer caps and the 15/30-turn refill clocks.
5. [05-integration-and-campaign-document.md](05-integration-and-campaign-document.md)
   — regression sweep, manual route, screenshots, and design-record update.

## Shared delivery protocol

1. Work on a regular branch from current `main`; do not create a worktree.
   Preserve the existing unrelated edit to
   `docs/plans/first-playable-campaign/game-design.md`.
2. For every behavior change, add the named GUT test, run it red, implement
   the smallest code path, and rerun it green. Commit each completed task.
3. Run `make check`, `godot --headless --path . --editor --quit`, and
   `git diff --check` before requesting manual verification.
4. Run `make play` for the manual route in Task 5. Do not merge until the user
   signs off. Then merge locally into `main`, delete the branch, and do not
   push unless asked.

## Definition of done

- A normal battle immediately awards fractional shared XP, levels units at the
  stated thresholds, and cannot award a kill or clear twice.
- A player can spend Attack points, choose Bonus Move on level 3, and see the
  actual derived values in battle and Unit Details.
- The map starts with one active encounter; no more than two are active.
  Recruitment starts with one offer; no more than four are active. Each vacant
  category refills only after its own 15- or 30-turn cooldown.
- The planned multi-unit battle work is absent: no new formation, AI, or
  encounter rebalance is hidden in this change.
