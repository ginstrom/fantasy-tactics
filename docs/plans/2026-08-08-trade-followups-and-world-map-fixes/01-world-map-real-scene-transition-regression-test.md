# Task 01: Real scene-transition regression test for post-victory World Map

## Objective

Close a genuine testing gap found while investigating the user's reported
World Map symptoms: **no existing test inspects the live scene produced by
a real `GameManager` scene transition.** Every existing test — including
`test_first_campaign_ui_flow.gd`'s `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`,
which does drive a real battle to a real victory — either checks
`GameSession` state directly or manually instantiates a fresh copy of the
next screen as a child, rather than inspecting `get_tree().current_scene`
after `GameManager.complete_battle()`'s real `get_tree().change_scene_to_file()`
call actually runs. This task adds that missing coverage.

This was verified to pass during this plan's own investigation (see
`docs/plans/2026-08-08-trade-followups-and-world-map-fixes/index.md`'s
Phase A note) — the point of this task is to bank that verification as
permanent regression coverage, not to fix a bug (none was found here).

## Files

- Modify: `tests/unit/test_first_campaign_ui_flow.gd`

## Depends on

None.

## Produces

A new test,
`test_the_real_post_victory_scene_change_produces_a_selectable_world_map`,
appended to `tests/unit/test_first_campaign_ui_flow.gd`.

## Steps

1. **Write the test.** Add to `tests/unit/test_first_campaign_ui_flow.gd`,
   after the existing
   `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`:

   ```gdscript
   ## Every other test in this file either checks GameSession state directly
   ## or manually instantiates the next screen as a child, sidestepping the
   ## real GameManager.complete_battle() -> go_to_world_map() ->
   ## get_tree().change_scene_to_file() transition entirely. This test
   ## inspects the actual live scene that real transition produces, since
   ## that's the exact path a real player's post-victory click lands on.
   func test_the_real_post_victory_scene_change_produces_a_selectable_world_map() -> void:
   	GameSession.create_party()
   	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
   	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)

   	var goblin_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
   	GameSession.set_deployed_party_position(goblin_position)
   	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

   	var battlefield: Node2D = BattlefieldScene.instantiate()
   	battlefield.enemy_turn_beat_seconds = 0.0
   	add_child_autofree(battlefield)
   	battlefield.grid.hit_roll = func() -> float: return 0.0
   	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	GameSession.loot_gear_roll = func() -> float: return 1.0
   	battlefield.grid.apply_super_power()

   	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
   	var goblin_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
   	var adjacent_to_goblin: Vector2i = goblin_start + Vector2i.UP
   	battlefield.grid._handle_tile_click(warrior_start)
   	battlefield.grid._handle_tile_click(adjacent_to_goblin)
   	battlefield.grid._handle_tile_click(goblin_start)

   	var settle_frames := 0
   	while GameSession.selected_encounter != "" and settle_frames < 30:
   		if battlefield.level_up.visible:
   			battlefield.level_up.continue_button.emit_signal("pressed")
   		await get_tree().process_frame
   		settle_frames += 1
   	assert_eq(GameSession.selected_encounter, "", "Victory should have resolved before the frame budget ran out")

   	# GameManager.complete_battle() just called go_to_world_map(), which
   	# calls the REAL get_tree().change_scene_to_file() -- that's deferred to
   	# the end of the frame, so give it a few frames to actually take effect.
   	var scene_settle_frames := 0
   	while (get_tree().current_scene == null or get_tree().current_scene.name != "WorldMap") and scene_settle_frames < 10:
   		await get_tree().process_frame
   		scene_settle_frames += 1

   	var live_world_map: Node = get_tree().current_scene
   	assert_not_null(live_world_map, "a real scene should be live after the post-victory transition")
   	assert_eq(live_world_map.name, "WorldMap")
   	assert_eq(live_world_map.party_position, goblin_position)
   	assert_true(GameSession.has_deployed_party())

   	assert_false(live_world_map.party_selected)
   	live_world_map._handle_tile_click(live_world_map.party_position)
   	assert_true(
   		live_world_map.party_selected,
   		"clicking the party tile on the REAL post-victory world map must select it"
   	)
   ```

2. **Run the test to verify it passes** (this test is not expected to fail
   — it's banking an already-verified-working path as permanent coverage,
   not TDD-ing a new behavior):

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow.gd -gunit_test_name=real_post_victory -gexit
   ```

   Expected: PASS.

3. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

4. **Commit** only this task's file:

   ```bash
   git add tests/unit/test_first_campaign_ui_flow.gd
   git commit -m "test: add a real scene-transition regression test for post-victory World Map"
   ```

## Milestone

The suite now has one test that exercises a genuinely real
`GameManager`-driven scene transition end to end and inspects the actual
resulting live scene — closing the specific coverage gap this plan's
investigation found, independent of Phase A's ultimate outcome.
