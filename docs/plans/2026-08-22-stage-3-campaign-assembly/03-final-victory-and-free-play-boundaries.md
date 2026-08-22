# Step 3 — Final Victory and Free-Play Boundaries

**Branch:** `feat/stage-3-victory-free-play`

**Depends on:** Step 2 merged

**Milestone:** The final boss produces one durable victory presentation, and post-victory repeatable play cannot alter or replay the authored campaign.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_manager.gd` only for routing a final victory
- Modify: `scripts/battle/battlefield.gd` only for the final-battle route
- Modify: `scripts/ui/victory_screen.gd`
- Modify: `scenes/ui/victory_screen.tscn`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_victory_screen.gd`
- Modify: `tests/unit/test_first_campaign_ui_flow.gd`
- Modify: `tests/unit/test_campaign_snapshot.gd` if a new durable field is approved

## Red/green tasks

1. Add a failing domain test that completes the final objective once, asserts the approved durable victory/free-play state and summary, then attempts duplicate completion and repeatable vacancy activity. Assert stable completed IDs, empty current objective, no re-unlock, and no second victory signal.
2. Add a failing snapshot round-trip test at post-victory state. Assert import preserves the boundary but cannot turn an incomplete campaign into free play or settle transient loot.
3. Make the smallest `GameSession` repair permitted by Step 1. Keep objective completion, victory, and vacancy policies in `GameSession`; do not place persistence rules in the screen.
4. Add scene-instantiated UI tests: final-boss completion routes exactly once to Victory; all approved durable summary fields render; Continue routes to Encampment/free play with the approved label. Test the `.tscn` signal wiring, not a bare script.
5. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_victory_screen.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=campaign_victory -gexit
   ```

   Expected: one victory route and no authored-objective reopening after free-play activity.

## Manual check

Use the existing pre-boss debug scenario only to shorten navigation. Defeat the Ogre, inspect the Victory Screen, choose Continue, and verify the Encampment/World Map visibly says optional free play while the completed objective list stays unchanged.

## Commit and local merge

After user signoff, commit `feat(campaign): finalize victory and free-play boundary`, merge locally to `main`, and delete `feat/stage-3-victory-free-play`. Do not push or open a PR.
