# HUD Layout Containers Implementation Plan

**Goal:** Bring the Battlefield and World Map HUDs into compliance with
[UI-Layout-Design-Guidelines.md](../../UI-Layout-Design-Guidelines.md) by
replacing their hand-offset `CanvasLayer` children with a real container
hierarchy, the same pattern the Encampment screens (`Body` HBoxContainer →
`CampNav` + `Center`) already use.

**Why now:** while fixing the world-map `BOARD_OFFSET` bug (a magic pixel
offset in `world_map.gd` that shifted the board to dodge the old CampNav
panel), it became clear the offset was a symptom, not a one-off: both
in-game HUDs position every label and button with hardcoded
`offset_left/top/right/bottom` rects directly under a `CanvasLayer`, which
is exactly the "Avoid: Hardcoded pixel positions" case the design doc calls
out. The Encampment screens don't have this problem — they're built from
nested `HBoxContainer`/`VBoxContainer`/`CenterContainer` all the way down.

**Architecture:** For each HUD, replace the flat list of manually-offset
`CanvasLayer` children with:

```
HUD (CanvasLayer)
├── Margin (MarginContainer, full-rect anchors, screen-edge padding)
│    └── VBox (VBoxContainer, fills Margin)
│         ├── TopRow (HBoxContainer)
│         │    ├── TopLeft (VBoxContainer, expand-fill)   — battlefield only
│         │    └── TopRight (VBoxContainer, shrink-to-end)
│         └── BodyRow (HBoxContainer, expand-fill vertical)
│              └── PortraitPanel                          — battlefield only
└── LevelUp (unchanged — a floating modal; Rule 6 explicitly allows
    absolute positioning for "floating windows")
```

World Map has no `TopLeft`/`PortraitPanel` content, but adds a bottom hint
bar (`BottomPanel`, a `PanelContainer` replacing today's `Panel` +
manually-offset `Label` pair) below a vertical spacer.

Every leaf node a script or test currently reaches via a hardcoded path
(`$HUD/Hint`, `get_node("HUD/EndTurnButton")`, etc.) gets
`unique_name_in_owner = true` and is referenced via `%NodeName` instead.
This means the node's position in the tree — which container, how deeply
nested — can change freely without breaking every caller, matching Rule 3
("A component should never depend on where it is placed"). It also keeps
this refactor's blast radius mechanical: scripts and tests change their
*access syntax*, not their logic.

**Tech stack:** Godot 4 GDScript, GUT tests, no new runtime dependencies.

---

## Scope and sequencing

Read [UI-Layout-Design-Guidelines.md](../../UI-Layout-Design-Guidelines.md)
first — it's the spec this plan implements. Deliver the tasks in order:

1. [01-battlefield-hud-containers.md](01-battlefield-hud-containers.md) —
   restructure `battlefield.tscn`'s HUD.
2. [02-world-map-hud-containers.md](02-world-map-hud-containers.md) —
   restructure `world_map.tscn`'s HUD.
3. [03-regression-sweep-and-merge.md](03-regression-sweep-and-merge.md) —
   full-suite regression pass, screenshot diff, manual `make play`
   verification (real mouse clicks — headless GUT cannot simulate these
   reliably, see note in Task 3), merge back to `main`.

All three tasks are complete and merged to `main`, along with an unplanned
fix for a missing `CampNav` panel on the Guild Hall screen found right
after (same root cause class: a screen never brought in line with the
container-based pattern). See
[04-outstanding-followups.md](04-outstanding-followups.md) for gaps and
loose ends noticed along the way that aren't fixed yet and aren't blocking.

Tasks 1 and 2 are independent of each other (different scenes) but follow
the identical pattern — do 1 first since it's the more complex of the two
(it has the `TopLeft` stack and the portrait panel), and reuse whatever
falls out of it (naming conventions, margin/spacing constants) in Task 2 for
consistency.

**Prerequisite:** this plan touches `world_map.gd`/`world_map.tscn` and
`battlefield.tscn`, both already modified on the in-flight
`fix/ui-selection-bugs` branch (the `BOARD_OFFSET` removal and the
`PortraitPanel/Rows` anchor fix). Get that branch committed and merged to
`main` first, then branch this plan's work off the updated `main`, so this
refactor isn't stacked on uncommitted, unrelated changes.

## Shared delivery protocol

1. `git checkout main && git pull`, then `git checkout -b
   refactor/hud-layout-containers`. Do not use a worktree.
2. For every structural change, update the failing test(s) first, confirm
   they fail for the expected reason (missing node / broken path), then
   change the scene/script, then confirm green. This is a refactor, not new
   behavior, so "red" here mostly means "the old path 404s" rather than "the
   new feature doesn't exist yet" — that's still a legitimate red/green
   cycle and still catches real mistakes (typoed unique names, wrong
   nesting).
3. Run `make check` (`godot --headless -s addons/gut/gut_cmdln.gd -gexit`)
   before moving to the next task. Focus a single file with:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield -gexit
   ```
4. Regenerate screenshots after each task
   (`godot --path . --rendering-driver opengl3 --position=-3000,-3000 -s
   scripts/tools/screenshot_tour_main.gd -- --outdir=<dir>`, or `make
   screenshots` if that target exists) and visually compare the affected
   frames (`17_battlefield.png`, `16_world_map.png`, and any level-up /
   game-menu-overlay frames) against a baseline captured before Task 1
   starts. Layout should look the same or better — same regions, same
   content, no overlap, no collapsed-to-zero elements.
5. Do not merge until manual `make play` verification passes (Task 3). Then
   merge locally into `main`, delete the branch, and don't push unless
   asked.

## Definition of done

- Neither `battlefield.tscn` nor `world_map.tscn` has a HUD child positioned
  by hardcoded `offset_left/top/right/bottom`, except `LevelUp` (an explicit,
  documented Rule 6 exception for floating/modal windows).
- Both HUDs are built from nested `MarginContainer`/`HBoxContainer`/
  `VBoxContainer`, matching the Encampment screens' existing pattern.
- All existing behavior is unchanged: hint/status text, round/turn labels,
  end-turn button, enemy health list, portrait panel (selection, click,
  dimming), world map hint bar, information panel — all still work and are
  still reachable from scripts/tests via `%UniqueName` lookups.
- Full test suite green under `make check`.
- Manual `make play` pass confirms real mouse clicks still reach the board
  (nothing in the new container tree silently eats input meant for tile
  clicks) and the visual layout matches the pre-refactor screenshots.
