# Battle Screen Improvements — Plan Index

**Goal:** Make the battlefield readable and informative (a scrolling combat
log, hover/click detail on any unit, an HP overlay on portraits, a victory
summary screen) and close a small gap on the campaign side (Party Details
shows gold/loot).

**Design reference:** this plan implements the design agreed in
conversation on 2026-08-09 (no separate spec doc was written — the user
asked to go straight to an AGENTS.md-style plan). The decisions below are
locked in; don't re-litigate them mid-implementation:

- Enemies always get an indexed display name (`"Kobold 1"` even when
  solo), because a single battle only ever fields one enemy species (see
  `GameSession.STAR_ENEMY_COMPOSITIONS`) — so "index" is always just
  `"<TypeName> <fielded-order-index>"`.
- Combat log lines cover attacks only (hit/miss/defeat), not movement.
- Click-to-attack is **unchanged**. Hover shows detail live; the only new
  click behavior is that clicking an enemy that's *not* a legal attack
  target (today a silent no-op) now pins that enemy's detail in the panel
  instead of doing nothing.
- Enemies show only Healthy (>66% HP) / Wounded (34–66%) / Badly Wounded
  (≤33%) — never exact numbers. Player units show exact HP plus
  name/class/level.
- The victory summary is a **separate scene** (`battle_result.tscn`), not
  an in-battlefield overlay, reached after any level-ups finish resolving.
  It shows enemies killed (by type × count), total/each XP, which members
  leveled up, and loot. `[OK]` returns to the World Map.
- Party Details gets gold + loot labels only — its Back/View navigation
  already works and is not touched.

## Steps

Do these **in order** — later steps depend on fields earlier steps add
(`Unit.display_name`/`enemy_type_name` from Step 2 is read by Steps 3 and
5).

1. [Party Details: gold and loot](01-party-details-gold-and-loot.md) —
   independent, smallest, do first to warm up on this codebase's
   conventions.
2. [Enemy display names and the combat log](02-enemy-display-names-and-combat-log.md)
   — adds `Unit.display_name`/`enemy_type_name` and the scrolling,
   auto-append combat log.
3. [Unit hover/click detail panel](03-unit-hover-click-detail-panel.md) —
   depends on Step 2's `display_name`.
4. [Portrait HP overlay](04-portrait-hp-overlay.md) — independent visual
   tweak, no dependency on the other steps.
5. [Victory summary screen](05-victory-summary-screen.md) — depends on
   Step 2's `enemy_type_name` (kills-by-type grouping).

## Shared workflow (every step)

Per `AGENTS.md`:

1. `git checkout main && git pull`
2. `git checkout -b <branch-name>` (branch name given in each step)
3. Implement with TDD (red/green), verify with `make check`.
4. Manual verification via `make play` (each step lists what to look at;
   the debug menu — **FN+F9** from any campaign screen — has scenario
   shortcuts, called out per step).
5. Commit.
6. `git checkout main && git merge <branch-name>`, then delete the branch.
   Only push to `origin` or open a PR if the user asks.

Do not start a step's branch until the previous step is merged to `main`
(Steps 3 and 5 will not compile against `main` until Step 2 is merged).

## Full-suite regression check

After all five steps are merged, run `make check` once more from `main` to
confirm nothing regressed end-to-end (in particular
`tests/unit/test_first_campaign_ui_flow.gd`, which Step 5 modifies).
