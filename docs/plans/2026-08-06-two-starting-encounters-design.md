# Two Starting Encounters Design

## Goal

Give a new campaign an immediate, legible expedition choice without expanding
combat scope: start the World Map with the one-star Goblin Camp and two-star
Orc Outpost, and show difficulty with stars instead of text labels.

## Approved rules

- A new campaign starts with two active encounter instances: Goblin Camp at
  `(4, 4)` and Orc Outpost at `(4, 0)`. The existing two-site cap is unchanged.
- Goblin Camp has difficulty `1`; Orc Outpost has difficulty `2`. Difficulty
  is display-only in this slice. It does not alter enemy statistics, XP, gold,
  travel, spawning, or battle rules.
- The World Map keeps the existing orange encounter marker and replaces the
  current name, danger, and reward label with one to four filled star glyphs
  above the marker: `★`, `★★`, `★★★`, or `★★★★`.
- Clearing either site removes only that instance and begins its existing
  15-World-Map-turn vacancy clock. When the clock completes, one replacement
  appears if the active-instance count is below two. The other starting site
  remains available throughout.
- Selection-before-activation, persistent completion history, deterministic
  instance IDs/positions, and the current Goblin/Orc rewards and battle data
  remain unchanged.

## Scope boundary

This is not a combat rebalance, an encounter-content expansion, or multi-unit
battle work. Stars do not become a general threat-rating system, add a legend,
or expose a hover detail panel. The right-side Information Panel remains as-is.

## Ownership

`GameSession.EXPEDITIONS` owns each template's display difficulty and seeds
both active instances during `reset()`. `WorldMap` renders the star glyphs from
each active instance and owns their placement. `GameManager`, `BattleController`,
and `Battlefield` require no new behavior.

## Acceptance checks

- Reset produces exactly the Goblin Camp and Orc Outpost active instances at
  their documented positions, with difficulties one and two.
- The World Map renders only `★` over Goblin Camp and `★★` over Orc Outpost;
  it renders neither site name, danger text, nor gold text as map labels.
- Clearing one starting site leaves the other activatable, and its vacancy
  refills exactly once after 15 World Map turns without exceeding two sites.
- `make check`, Godot's headless editor scan, and `git diff --check` pass.
- Manual check: use `make play`, deploy a party, observe both stars, enter and
  clear one site, verify the other remains selectable, then advance 15 World
  Map turns and observe one replacement.
