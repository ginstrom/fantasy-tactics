# Encampment Roster and Recruitment Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Activate Roster and Recruitment so the player can spend gold on three fixed Warriors and assign an available roster unit to an encamped party from Unit Details.

**Architecture:** `GameSession` owns candidates, gold, units, parties, and validation. `GameManager` owns named transitions and short-lived detail-route origin; controllers map current session data to `TableView` rows and do not store state in `TreeItem` metadata.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7, `TableView`/`TableColumn`, English translations.

---

## Read first

- [Approved design](../2026-08-06-encampment-roster-recruitment-design.md)
- [Encampment text UI](../../party-screens.txt)
- [Campaign roadmap](../first-playable-campaign/game-design.md)
- `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, and `scripts/ui/add_member.gd`

## Branch and safety

Use the existing checkout and preserve unrelated local changes:

```bash
git status --short --branch
git checkout main
git pull --ff-only
git checkout -b feat/encampment-roster-recruitment
```

Do not modify unrelated deleted legacy plan files. Do not push. Commit each
milestone; merge locally only after manual verification and user approval.

## Milestones

1. [Recruitment domain and routes](01-recruitment-domain-and-routes.md)
2. [Roster and unit-first assignment](02-roster-and-unit-assignment.md)
3. [Recruitment screen and summary action](03-recruitment-screen.md)
4. [Migrate existing tabular screens](04-migrate-existing-tables.md)
5. [Localization, tour, and integration](05-localization-tour-and-integration.md)

## Acceptance route

1. Reach at least 10 banked gold, then open **Units → Recruitment**.
2. Select a Warrior and confirm the 10-gold cost; recruit it.
3. Confirm Roster opens, gold decreased once, and the hire is `Unassigned`.
4. Open the unit, choose an encamped party, press **Add to Party**, and verify
   that Roster now shows that party in the unit's Party column.
5. Confirm existing **Party Details → Add Member** and **Deploy Party** still
   work with their prior eligibility rules.
