# Step 4 — Scout Ranged Role and Tier-Two Pattern

**Branch:** `test/stage-2-scout-tier-two`
**Depends on:** Step 3 merged
**Milestone:** The existing Scout implementation is demonstrated as a readable Tier 2 preparation choice: reconnaissance exposes only useful encounter information, and ranged pressure is constrained by real range/LoS and equipment.

## Files

- Modify: `scripts/autoload/game_session.gd` only if a failing public-contract test exposes a defect
- Modify: `scripts/world/world_map.gd` only if a failing real scene test exposes a defect
- Modify: `scripts/battle/battle_controller.gd` only if a failing shared-rule test exposes a defect
- Modify: `scripts/tools/battle_scenarios/scenario_contract.gd` only if explicit tier-two fixtures require a contract extension
- Modify: `scripts/tools/battle_scenarios/battle_state_factory.gd` only if a failing hydration test exposes a defect
- Create: `tests/unit/test_stage_2_scout_tier_two.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battle_state_factory.gd`

## Red/green tasks

1. Write the new focused test around public APIs, not a second scout model. It must prove no Scout/no range reveals only location; a deployed Scout within Manhattan three reveals danger and exact types/count but never rewards/placements; moving out of range removes the view; and authored objective ids work as well as sandbox instances.
2. Add a real `world_map.tscn` test that drives the existing selection/hover path and asserts the rendered star/composition visibility, not merely the helper’s return value.
3. Add scene-free scenario tests for shortbow/longbow equipment hydration, occupied-endpoint LoS, blockers, range limits, and a Scout that can pressure a protected enemy but cannot substitute for a front line. Seed every random roll through the factory.
4. Run the focused test file and relevant existing files. Expected: pass if the live contract already satisfies the assertion; if a test fails, repair only the shared implementation that caused it.
5. Add a documented tier-two fixture named for its intended decision (Scout intel → bow positioning → armour/resistance/potion preparation), using `ScenarioContract` and `BattleStateFactory`. Do not create bespoke scene setup or random global state.
6. Run `make check`, editor scan, and `git diff --check`.

## Manual signoff and merge

In `make play`, take a Warrior/Scout/Cleric party near but not onto the Tier 2 objective, observe the Scout-only information, equip/use a bow and potion, and fight the pattern. Confirm the information changes preparation rather than revealing loot or battlefield placement. After user signoff, commit `test(scout): prove tier two readiness pattern`, merge locally, and delete the branch.
