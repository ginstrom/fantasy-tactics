# Encampment & UI Polish Implementation Plan

> **For Agents & Developers:** Follow this plan step-by-step. Each step is contained in its own document with concrete TDD milestones, setup, implementation details, and manual verification instructions.

**Goal:** Implement the UI and flow polish items defined in [`docs/polish.md`](file:///home/ryan/play/fantasy-tactics/docs/polish.md), streamlining party creation, sub-menu encampment navigation, starting buildings (Guild Hall + Shop), recruitment loop, and direct Stores table actions.

**Architecture:**
- `GameSession` owns durable Shop level/gold, catalogue gates, atomic player↔Shop transactions, targeted recruitment, and snapshot migration; it also keeps passive Shop income flowing into player gold.
- `GameManager` owns named routes and transient, validated recruitment-target context. `CampNav` receives an explicit category from each scene rather than guessing from the scene tree.
- UI owns only selection, dialog-dismissal, rendering, and intent signals. Stores alone opts into the three-button action bar; the shared `LootTable` keeps its existing caller-configurable behavior elsewhere.

**Tech Stack:** Godot 4.7.1, GDScript, GUT test framework, `make check`, `make play`.

---

## Scope and Invariants

- **Red/Green TDD**: Write failing GUT tests before implementing code for each step.
- **Workflow Compliance**: Each step begins from updated local `main` on its named branch; after explicit user signoff it commits, merges locally, and deletes that branch. Step 6 does not create a competing final feature branch.
- **Compatibility**: New snapshots persist `shop_level` and `shop_gold`; old snapshots map their legacy `has_trading_post` value safely, while a new campaign always starts with the level-1 Shop.
- **Required checks per code step**: focused GUT red/green run, `godot --headless --path . --editor --quit`, `make check`, and `git diff --check`.

---

## Step Roadmap

1. [`01-starting-buildings-and-shop-rename.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/01-starting-buildings-and-shop-rename.md) — Set Guild Hall + Shop as default starting buildings and rename "Trading Post" to "Shop" game-wide.
2. [`02-camp-nav-submenus-and-visibility.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/02-camp-nav-submenus-and-visibility.md) — Implement left-aligned indented sub-navigation for `Units`, `Buildings`, and `Trade`, and conditional `Deploy Party` button visibility.
3. [`03-party-creation-and-details-recruitment.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/03-party-creation-and-details-recruitment.md) — Add first-party creation prompt on Encampment, direct routing from creation to Party Details, and `[Add from Roster]` / `[Recruit]` action buttons in Party Details.
4. [`04-recruitment-flow-and-roster-link.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/04-recruitment-flow-and-roster-link.md) — Retain player on Recruitment screen upon candidate purchase and add bottom link to Roster.
5. [`05-stores-interface-direct-actions.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/05-stores-interface-direct-actions.md) — Update `LootTable` to present direct `[View]`, `[Sell]`, and `[Equip]` buttons with dynamic grayed/disabled validation.
6. [`06-verification-and-signoff.md`](file:///home/ryan/play/fantasy-tactics/docs/plans/2026-08-12-encampment-and-ui-polish/06-verification-and-signoff.md) — Full automated test suite verification (`make check`), end-to-end manual testing (`make play`), user signoff, and branch merge.
