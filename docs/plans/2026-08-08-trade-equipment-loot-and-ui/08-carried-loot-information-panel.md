# Task 08: Show carried (unbanked) mana crystals and gear in the party's `InformationPanel`

## Objective

Surface what the party is carrying but hasn't banked yet, so the loot the
player just won is visible in the party view before they walk it home — the
design doc's "when a party wins an encounter, the loot they carry appears in
the party view."

## Files

- Modify: `scripts/ui/information_panel.gd`, `scenes/ui/information_panel.tscn`
- Test: `tests/unit/test_information_panel.gd`

## Depends on

Task 07 (`GameSession.pending_mana_crystals`, `GameSession.pending_gear`).

## Produces

A new always-refreshed row, `InformationPanel`'s `Content/CarriedLoot`
`Label`, visible only when `pending_mana_crystals` or `pending_gear` is
non-empty.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_information_panel.gd`:

   ```gdscript
   func test_refresh_party_shows_carried_loot_when_pending_loot_exists() -> void:
   	GameSession.create_party()
   	GameSession.pending_mana_crystals = {1: 2, 2: 1}
   	GameSession.pending_gear = ["shortsword_iron", "shortsword_iron", "dagger_iron"]
   	var panel: PanelContainer = InformationPanelScene.instantiate()
   	add_child_autofree(panel)

   	panel.refresh_party(GameSession.FIRST_PARTY_ID)

   	var label: Label = panel.get_node("Content/CarriedLoot")
   	assert_true(label.visible)
   	assert_eq(label.text, tr("information.carried_loot") % [3, 3], "3 mana crystals (2+1) and 3 gear pieces")


   func test_refresh_party_hides_carried_loot_when_there_is_none() -> void:
   	GameSession.create_party()
   	var panel: PanelContainer = InformationPanelScene.instantiate()
   	add_child_autofree(panel)

   	panel.refresh_party(GameSession.FIRST_PARTY_ID)

   	assert_false(panel.get_node("Content/CarriedLoot").visible)


   func test_a_bare_refresh_hides_carried_loot_too() -> void:
   	GameSession.pending_gear = ["dagger_iron"]
   	var panel: PanelContainer = InformationPanelScene.instantiate()
   	add_child_autofree(panel)

   	panel.refresh()

   	assert_false(panel.get_node("Content/CarriedLoot").visible)
   ```

   Check the top of `tests/unit/test_information_panel.gd` for the existing
   scene preload constant name (it is very likely already named
   `InformationPanelScene` — match whatever name the file already uses
   instead of introducing a second one).

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_information_panel.gd -gunit_test_name=carried_loot -gexit
   ```

   Expected: FAIL — `Node not found: "Content/CarriedLoot"`.

3. **Add the translation key.** In `translations/en.tres`, add next to
   `"information.pending_reward": "Unbanked reward: %d gold",`:

   ```
   "information.carried_loot": "Carried loot: %d mana crystals, %d gear",
   ```

4. **Add the node.** In `scenes/ui/information_panel.tscn`, add a new node
   after the `PendingReward` label node (before `PartyViewButton`):

   ```
   [node name="CarriedLoot" type="Label" parent="Content"]
   layout_mode = 2
   visible = false
   ```

5. **Implement in `scripts/ui/information_panel.gd`.** Add next to
   `@onready var pending_reward_label: Label = $Content/PendingReward`:

   ```gdscript
   @onready var carried_loot_label: Label = $Content/CarriedLoot
   ```

   In `refresh_party()`, add right before the final
   `pending_reward_label.text = ...` block (still inside the function, after
   `pending_reward_label.visible = pending_reward > 0`):

   ```gdscript
   	_refresh_carried_loot()
   ```

   In `refresh()`, add a call to the same helper so a bare refresh also
   hides it — add `_refresh_carried_loot()` right after
   `_clear_party_section()`.

   In `_clear_party_section()`, add:

   ```gdscript
   	carried_loot_label.visible = false
   ```

   Add this new method near `_refresh_permanent_rows()`:

   ```gdscript
   ## Shown whenever the player is carrying unbanked loot (see GameSession.
   ## pending_mana_crystals/pending_gear), independent of which party is
   ## selected — loot is a session-wide unbanked total, not per-party. Reads
   ## GameSession directly rather than taking a parameter, unlike pending_reward
   ## above, since there is no existing caller-supplied value to thread through.
   func _refresh_carried_loot() -> void:
   	var mana_crystal_count := 0
   	for tier in GameSession.pending_mana_crystals:
   		mana_crystal_count += GameSession.pending_mana_crystals[tier]
   	var gear_count: int = GameSession.pending_gear.size()
   	carried_loot_label.visible = mana_crystal_count > 0 or gear_count > 0
   	if carried_loot_label.visible:
   		carried_loot_label.text = tr("information.carried_loot") % [mana_crystal_count, gear_count]
   ```

6. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_information_panel.gd -gexit
   ```

   Expected: PASS.

7. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

8. **Commit** only this task's files:

   ```bash
   git add scripts/ui/information_panel.gd scenes/ui/information_panel.tscn tests/unit/test_information_panel.gd translations/en.tres
   git commit -m "feat: show carried mana crystals and gear in the party information panel"
   ```

## Milestone

Any screen that shows a party's `InformationPanel` now surfaces unbanked
mana crystals and gear the moment an encounter is won, hidden again once
nothing is pending — closing out Phase B.
