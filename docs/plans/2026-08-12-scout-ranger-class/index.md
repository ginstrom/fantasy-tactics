# Scout/Ranger Class & Ranged Combat Implementation Plan

> **For Agents & Developers:** Follow this plan step-by-step. Each step is contained in its own document with concrete TDD milestones, setup, implementation details, and manual verification instructions.

**Goal:** Implement **Slice 2** of the Class System roadmap ([`docs/designs/class-system.md`](file:///home/ryan/play/fantasy-tactics/docs/designs/class-system.md)), introducing ranged combat primitives, Line-of-Sight (LoS) calculations on the tactical grid, the **Scout/Ranger** playable class with bow weapons, ranged enemy skirmishers (`goblin_archer`), and World Map expedition scouting previews.

**Architecture:**
- `GridScript` (`scripts/battle/grid.gd`): Tactical grid geometry, range checks, and Line-of-Sight (LoS) raycasting.
- `BattleController` (`scripts/battle/battle_controller.gd`): Ranged targeting, range validation, LoS checks, and AI ranged attack decisions.
- `GameSession` (`scripts/autoload/game_session.gd`): Ranged weapon content definitions (`WEAPONS`), Scout class definition, class equipment permissions, recruitment candidate generation, and party scouting capabilities.
- `scenes/ui/` & `scenes/world/`: Recruitment UI displays, Unit details, and World Map encounter preview tooltips/popups.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, headless battle simulator (`make simulate`), `make check`.

---

## Scope and Invariants

- **Generic AP Model Preserved**: Basic ranged attacks cost 3 AP (same as melee attacks). Movement costs 1 AP per tile.
- **Line of Sight (LoS)**: Ranged attacks require a clear line of sight. Occupied tiles or blocking obstacles break LoS.
- **Weapon Range**: Range is specified on weapons as `min_range` (default 1) and `max_range` (default 1 for melee, 3-4 for bows).
- **Backward Compatibility**: Melee combat, existing Warrior adventurers, and standard monsters remain 100% operational without regression.
- **Deterministic AI**: Enemy ranged units use deterministic targeting (prioritizing closest target in line-of-sight and range).

---

## Step Roadmap

1. [`01-ranged-attack-primitives-and-los.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/01-ranged-attack-primitives-and-los.md) — Grid Line-of-Sight (LoS) and ranged targeting in `GridScript` and `BattleController`.
2. [`02-ranged-weapons-and-class-permissions.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/02-ranged-weapons-and-class-permissions.md) — Bow weapon catalog, Scout class statistics, and equipment slot permissions.
3. [`03-scout-recruitment-and-roster.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/03-scout-recruitment-and-roster.md) — Recruitment candidate pool generation, Guild Hall recruitment UI, and roster management for Scouts.
4. [`04-ranged-monster-skirmisher.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/04-ranged-monster-skirmisher.md) — `goblin_archer` enemy template, AI ranged attack decision loop, and tier encounter compositions.
5. [`05-expedition-scouting-preview.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/05-expedition-scouting-preview.md) — World Map expedition scouting preview when a party contains a Scout.
6. [`06-verification-and-signoff.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-scout-ranger-class/06-verification-and-signoff.md) — Full verification (`make check`, battle simulations, manual `make play` testing), user signoff, local branch merge, and cleanup.
