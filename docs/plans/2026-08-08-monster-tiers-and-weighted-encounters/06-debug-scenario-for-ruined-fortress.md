# Step 6: Debug scenario for the Ruined Fortress

**Depends on:** Step 4 merged (`RUINED_FORTRESS_ID` must exist). Independent
of Step 5 — this scenario activates the site directly rather than going
through the weighted refill path, so it works whether or not Step 5 has
landed, but do it after Step 5 per index.md's ordering.

**Produces:** A "Ruined Fortress Battle" F9 debug-menu button that deploys a
staffed party directly onto the site and force-resolves its composition to
8 Kobolds (the largest fight the game can field), so the 8-enemy battlefield
built in Step 3 has a real, repeatable way to be played and screenshotted
instead of only being covered by an automated test.

The Ruined Fortress is never a starting active encounter and (even after
Step 5) only appears via a randomized vacancy refill — both awkward to force
from a menu click. This scenario instead activates it directly and pins its
random rolls, mirroring how `_stock_trading_post_and_stores()` already pokes
`GameSession` state directly for the same reason (see
`scripts/debug/debug_scenarios.gd`).

## Setup

```bash
git checkout main && git pull
git checkout -b debug-scenario-ruined-fortress
```

## Steps

- [ ] **Step 1: Write the failing tests (RED)**

  Add to `tests/unit/test_debug_scenarios.gd` if it exists, or
  `tests/unit/test_debug_menu.gd` otherwise — check which file already
  covers `"goblin_camp"`/`"orc_outpost"` scenario assertions with `grep -n
  "goblin_camp" tests/unit/test_debug_menu.gd tests/unit/test_game_manager.gd`
  and add these next to the matching existing test(s):

  ```gdscript
  func test_ruined_fortress_scenario_deploys_a_staffed_party_and_fields_eight_kobolds() -> void:
  	assert_eq(GameManager.run_debug_scenario("ruined_fortress"), OK)

  	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
  	add_child_autofree(battlefield)
  	var controller: Node2D = battlefield.grid

  	var enemy_units: Array = []
  	for unit in controller.units:
  		if unit.side == BattleControllerScript.Side.ENEMY:
  			enemy_units.append(unit)
  	assert_eq(enemy_units.size(), 8, "The forced Kobold roll should field the maximum count")
  	for unit in enemy_units:
  		assert_eq(unit.max_health, 6, "Every fielded unit should be a Kobold")


  func test_ruined_fortress_button_runs_the_ruined_fortress_debug_scenario() -> void:
  	var menu: CanvasLayer = DebugMenuScene.instantiate()
  	add_child_autofree(menu)
  	menu.visible = true

  	menu._on_ruined_fortress_pressed()

  	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")
  ```

  Adjust the preload/constant names in the second test to match whatever
  `DebugMenuScene` is already called in that test file (check the top of
  `tests/unit/test_debug_menu.gd` for its existing preload).

- [ ] **Step 2: Run the suite and confirm these fail**

  Run: `make test`
  Expected: FAIL — `"ruined_fortress"` isn't a recognized scenario id yet
  (`run_debug_scenario` returns `ERR_INVALID_DATA`), and
  `_on_ruined_fortress_pressed` doesn't exist on the debug menu script.

- [ ] **Step 3: Wire up the scenario (GREEN)**

  Edit `scripts/debug/debug_scenarios.gd`:

  Add `"ruined_fortress"` to `SCENARIO_IDS` (after `"orc_outpost"`):
  ```gdscript
  const SCENARIO_IDS := [
  	"new_campaign",
  	"encampment",
  	"party_manager",
  	"party_ready",
  	"party_empty",
  	"world_map",
  	"goblin_camp",
  	"orc_outpost",
  	"ruined_fortress",
  	"stocked_stores",
  ]
  ```

  Add a match arm in `apply()` (after the `"orc_outpost"` arm):
  ```gdscript
  		"ruined_fortress":
  			return _deploy_at_ruined_fortress()
  ```

  Add the new helper (after `_deploy_at()`):
  ```gdscript
  ## The Ruined Fortress is never a starting active encounter (see
  ## GameSession.reset()) and only otherwise appears via a power-weighted
  ## vacancy refill (see GameSession._choose_encounter_template()) -- both
  ## awkward to trigger from a menu click. This activates it directly at
  ## its documented position and pins both composition rolls to the Kobold
  ## option at its maximum count (8), so this scenario reliably exercises
  ## the largest battle the game can field.
  static func _deploy_at_ruined_fortress() -> bool:
  	if not _create_staffed_party():
  		return false
  	var position: Vector2i = GameSession.get_expedition(GameSession.RUINED_FORTRESS_ID).position
  	GameSession.active_encounters.append(
  		GameSession._make_encounter_instance(
  			GameSession.RUINED_FORTRESS_ID, GameSession.RUINED_FORTRESS_ID, position
  		)
  	)
  	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
  	GameSession.enemy_count_roll = func(_min_value: int, _max_value: int) -> int: return 8
  	return (
  		GameSession.depart_selected_party()
  		and GameSession.set_deployed_party_position(position)
  	)
  ```

  Edit `scripts/autoload/game_manager.gd` — add `"ruined_fortress"` to the
  `BATTLEFIELD` match arm in `debug_scenario_target()` (around line 319):
  ```gdscript
  		"goblin_camp", "orc_outpost", "ruined_fortress":
  			return DebugTarget.BATTLEFIELD
  ```

  Edit `scripts/debug/debug_menu.gd` — add a new handler (after
  `_on_orc_outpost_pressed()`):
  ```gdscript
  func _on_ruined_fortress_pressed() -> void:
  	_run("ruined_fortress")
  ```

  Edit `scenes/debug/debug_menu.tscn`:

  Add a new button node after `OrcOutpostButton`'s block:
  ```
  [node name="RuinedFortressButton" type="Button" parent="Panel/Rows"]
  layout_mode = 2
  text = "debug.ruined_fortress"
  ```

  Add its connection alongside the others:
  ```
  [connection signal="pressed" from="Panel/Rows/RuinedFortressButton" to="." method="_on_ruined_fortress_pressed"]
  ```

  The panel's height is a fixed offset rect (`offset_top = 24.0` /
  `offset_bottom = 500.0` today), not auto-sizing to its content — it
  already holds 13 rows in that space. Adding a 14th row needs a taller
  panel or the new button gets clipped. Bump the panel's height (around
  line 18):
  ```
  offset_bottom = 540.0
  ```

  Add the button's label string to `translations/en.tres`, right after
  `"debug.orc_outpost": "Orc Outpost Battle",` (line 171):
  ```
  "debug.ruined_fortress": "Ruined Fortress Battle",
  ```

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  Run `make play`, press F9, and click "Ruined Fortress Battle". Confirm:
  - The debug menu closes and a Battlefield screen appears.
  - Exactly 8 enemy units are visible, filling the 3x3 block in the
    bottom-right corner (minus its innermost tile), with no overlap with
    the player's Warrior in the top-left.
  - The enemy health list shows 8 entries, each at `6/6` (Kobold HP from
    Step 1/2's rebalance).
  - Play at least one full round (move, attack, End Turn) and confirm the
    turn resolves without errors, and that all 8 enemies take their AI
    turn without slowdown or a stuck game.

  Optionally capture a screenshot for the record:
  ```bash
  make screenshots
  ```
  and check `./screenshots` for the new Ruined Fortress battle state (only
  if the screenshot tour script already enumerates debug scenarios — if it
  doesn't, a manual screenshot from the running game is sufficient).

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/debug/debug_scenarios.gd scripts/autoload/game_manager.gd \
    scripts/debug/debug_menu.gd scenes/debug/debug_menu.tscn translations/en.tres \
    tests/unit/test_debug_menu.gd tests/unit/test_debug_scenarios.gd
  git commit -m "feat: add a debug scenario to battle-test the Ruined Fortress"
  ```

## Merge back to main

Get the user's signoff on Step 5's manual playtest, then:

```bash
git checkout main
git merge debug-scenario-ruined-fortress
git branch -d debug-scenario-ruined-fortress
```
