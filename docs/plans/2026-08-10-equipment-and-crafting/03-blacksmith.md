# Step 3 — Blacksmith

## Milestone

The Blacksmith unlocks as a 50-gold level-1 building. It runs one 20-World
Map-Turn Sharpening job in parallel with one 5-World-Map-Turn normal weapon
craft job. Level 2 (50 gold) unlocks Iron weapon crafting; level 3 (100 gold)
unlocks Steel weapon crafting.

## Contract

- A craft costs `ceil(item sale price * 0.9)` gold and produces one normal
  base item. It must never make crafting and selling profitable.
- Sharpening costs twice the base weapon sale price, consumes one banked
  normal weapon when started, and creates a unique instance with
  `treatment_id: "sharpened"` on completion.
- Sharpened adds exactly +1 raw damage after the weapon roll and before
  future Might and Resistance modifiers.
- Both jobs are durable `GameSession` state. They complete only when
  `GameSession.end_world_turn()` advances the World Map Turn; unresolved
  battles already block that transition.
- Validate level, slot availability, inputs, and resources before mutation.
  Invalid starts leave every resource and job slot unchanged.
- Buildings routes to a Blacksmith screen. The screen renders level, jobs,
  remaining World Map Turns, and only eligible actions; it does not own
  campaign state.

## Red/green delivery

1. On `feat/blacksmith`, add failing `test_game_session.gd` coverage for
   purchase/upgrade gates, Iron/Steel level gates, craft price, atomic failed
   starts, one craft slot plus one parallel sharpening slot, completion after
   5/20 World Map Turns, and snapshot persistence. Add a deterministic
   `test_battle_controller.gd` assertion that a Sharpened instance deals one
   more raw damage than the same base weapon.
2. Implement recipe and job data plus Blacksmith level/job ownership in
   `GameSession`; wire advancement through `end_world_turn()` and snapshots.
   Run the focused tests red, then green.
3. Add `blacksmith.tscn`/`blacksmith.gd`, add the Buildings table row and
   `GameManager` route, and add translations plus scene/controller tests.
4. Run focused GUT tests, `make check`,
   `godot --headless --path . --editor --quit`, a seeded normal-versus-
   Sharpened scenario comparison, and `git diff --check`.
5. Run `make play`: build level 1, start a Sharpening job, confirm its
   countdown advances only through World Map Turns; upgrade to level 2, start
   an Iron craft alongside it, then equip and battle-test the completed item.
   After user signoff, commit, fast-forward merge locally into `main`, delete
   the branch, and do not push.
