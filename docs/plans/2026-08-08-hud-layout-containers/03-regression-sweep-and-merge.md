# Task 3: Regression sweep, manual verification, and merge

## Objective

Confirm the two HUD restructures (Tasks 1-2) didn't regress anything a
human needs to check by hand — especially real mouse-click hit-testing,
which headless GUT cannot simulate reliably — then merge the branch back to
`main`.

## Why manual verification matters here specifically

This session already established that headless Godot cannot simulate real
mouse clicks reliably: a synthetic click via `Input.parse_input_event()` /
`viewport.push_input()` failed to register even against the
definitely-working `EndTurnButton`. Every automated test in Tasks 1-2 that
touches the new container tree does so via `%UniqueName` lookups and direct
method/property assertions — none of them prove a real click still lands on
the right widget, or that the new full-rect `MarginContainer`/
`HBoxContainer` chain doesn't accidentally intercept a click meant for a
board tile underneath. That gap can only be closed by a human playing the
game.

## Steps

### 1. Full automated suite

1. Run `make check`. All tests green, including the structural regression
   tests added in Tasks 1 and 2.

### 2. Screenshot diff

2. Regenerate the full screenshot tour and compare every frame that touches
   either HUD against the pre-Task-1 baseline captured at the start of this
   plan:
   - `battlefield` — hint, status, enemy health list, portrait panel, round
     label, end turn button all present, same regions, no overlap.
   - `game_menu_overlay` — confirm the pause/menu overlay (triggered from
     the battlefield) still renders correctly over the new HUD.
   - `world_map`, `world_map_encounter_complete` — turn label, end turn
     button, information panel, bottom hint bar all present, same regions.
   - `encampment_reward_deposited`, `encampment_revisit` — confirm nothing
     about the world map → encampment transition broke (these follow
     immediately after a world-map screenshot in the tour).
3. Note any visual drift (wrong spacing, misaligned text, clipped labels)
   and fix it by tuning the `MarginContainer`/theme constants from Tasks
   1-2 — don't reintroduce hardcoded offsets to patch it.

### 3. Manual `make play` pass

4. Launch `make play` and manually verify, on the real battlefield:
   - Clicking each portrait in the left panel selects that unit (the bug
     this session originally fixed under `fix/ui-selection-bugs` — confirm
     the HUD restructure didn't regress it).
   - Clicking a board tile (not a portrait) still moves/targets a unit —
     this is the specific "did a wrapping container eat the click" risk
     called out in Task 1.
   - The End Turn button still works and visibly disables during the enemy
     turn.
   - Triggering a level-up still shows the modal centered, and it still
     blocks board/end-turn input while visible.
5. On the World Map:
   - The End Turn button still works.
   - The bottom hint bar text is still fully visible (not clipped by the
     `PanelContainer`'s theme padding).
   - The information panel (gold/player info) still displays correctly.
   - Clicking a settlement/encounter tile still works (same "did a
     container eat the click" concern as the battlefield).
6. Report the manual pass results before merging. Do not merge on the
   strength of the automated suite alone — the click-hit-testing gap above
   means the automated suite cannot prove this task's core risk is clear.

### 4. Merge

7. Once manual verification passes:
   ```bash
   git checkout main
   git merge refactor/hud-layout-containers
   git branch -d refactor/hud-layout-containers
   ```
   Do not push to `origin` or open a PR unless asked.

## Milestone

Full suite green, screenshots visually match the pre-refactor baseline for
every affected frame, a human has clicked through both the battlefield
(portrait select, tile click, end turn, level-up modal) and the world map
(end turn, hint bar, information panel, tile click) on the restructured
HUDs with no regressions, and the branch is merged into `main`.
