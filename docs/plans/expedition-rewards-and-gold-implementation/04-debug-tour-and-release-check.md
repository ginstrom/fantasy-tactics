# Step 4: Debug Tour and Release Check

**Milestone:** Developers can jump directly to either battle, screenshots cover the new strategy presentation, and the ordinary reward/defeat loop has evidence for both expeditions.

## Setup

```bash
git checkout main
git pull --ff-only
git checkout -b chore/verify-expedition-reward-loop
```

## Files

- Modify: `scripts/debug/debug_scenarios.gd`, `scripts/autoload/game_manager.gd`, `scripts/tools/screenshot_tour.gd`, `README.md`
- Modify: `tests/unit/test_debug_scenarios.gd`, `tests/unit/test_game_manager.gd`

## Red/green TDD

1. In `test_debug_scenarios.gd`, add assertions that ordered scenario IDs include `orc_outpost` after `goblin_camp`, and `DebugScenarios.apply("orc_outpost")` creates a staffed, deployed party at `GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position` without selecting an encounter. In `test_game_manager.gd`, assert the new target is `BATTLEFIELD` and `run_debug_scenario("orc_outpost")` selects the outpost before changing scene.

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_debug_scenarios.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_manager.gd -gexit
   ```

   Expected: FAIL because `orc_outpost` is unknown.

2. In `debug_scenarios.gd`, add `orc_outpost` after `goblin_camp` and deploy at the catalog-defined position; do not duplicate the coordinates. In `game_manager.gd`, map it to `BATTLEFIELD` and route it through `enter_battle(GameSession.ORC_OUTPOST_ID)`. Preserve the `OS.is_debug_build()` gate and public-API-only state setup. Re-run focused tests; expected: PASS.

3. In `screenshot_tour.gd`, add deterministic public-API-driven captures for: World Map with both expedition labels/panel; World Map after Goblin victory but before deposit; and Encampment after deposit showing `Gold: 10`. Do not directly mutate private state or invoke battle pacing. Update README’s F9 description to include Orc Outpost Battle and say the screenshot tour covers expedition/reward states.

4. Verify the developer additions:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: all exit `0`.

5. When a display or virtual display is available, run:

   ```bash
   make screenshots
   ```

   Expected: a PNG for every tour step, including the three additions. Inspect for legible labels, distinct encounters, panel placement, and no overlap with controls. Do not commit generated screenshots unless already tracked.

## Manual verification and merge

Run `make play` and record all paths:

1. New campaign → Encampment → create/assign party → Goblin Camp victory → Starting Settlement → Encampment: gold becomes 10 only at Encampment and stays 10 after reopening.
2. Depart again → Orc Outpost victory → return to Encampment: gold becomes 35 once; both sites reject entry.
3. New campaign/reset → Orc Outpost defeat: party returns home, outpost remains enterable, and gold is zero.

After user signoff:

```bash
git add scripts/debug/debug_scenarios.gd scripts/autoload/game_manager.gd scripts/tools/screenshot_tour.gd README.md tests/unit/test_debug_scenarios.gd tests/unit/test_game_manager.gd
git add scripts/debug/debug_scenarios.gd.uid tests/unit/test_debug_scenarios.gd.uid
git commit -m "chore: cover expedition reward loop"
git checkout main
git merge --ff-only chore/verify-expedition-reward-loop
git branch -d chore/verify-expedition-reward-loop
```

Do not push.
