# Task 04: Adventurer equipment readback in Unit Details

## Objective

Nothing in the game currently displays an adventurer's equipped weapon or
armor — the trade loop closes mechanically (buy → assign) but not
informationally: a player can never check who is wearing what. Add an
equipment row to the Unit Details screen, the natural home for it (it
already shows every other per-adventurer stat).

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/ui/unit_details.gd`,
  `scenes/ui/unit_details.tscn`, `translations/en.tres`
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_unit_details.gd`

## Depends on

Task 03 (this task's own tests don't hardcode a specific weapon name, but
manual verification will show the split Iron/Steel names from Task 03 —
land that one first so the screen reads correctly end to end).

## Produces

`GameSession.get_effective_armor_name(adventurer_id: String) -> String`
(mirrors `get_effective_weapon_name()`, the only equipment getter missing
a "name" counterpart), and a new always-visible `EquipmentLabel` row on
Unit Details showing `"Weapon: <name> (<min>-<max> damage) — Armor: <name>
(<defense>% defense / <resistance>% resistance)"`.

## Steps

1. **Write the failing `GameSession` test.** Add to
   `tests/unit/test_game_session.gd`, near
   `test_effective_weapon_damage_range_and_name_come_from_the_equipped_weapon`:

   ```gdscript
   func test_effective_armor_name_comes_from_the_equipped_armor() -> void:
   	assert_eq(GameSession.get_effective_armor_name(GameSession.WARRIOR_ID), "Leather Armor")


   func test_effective_armor_name_returns_empty_for_an_unknown_adventurer() -> void:
   	assert_eq(GameSession.get_effective_armor_name("no_such_id"), "")
   ```

2. **Run the test to verify it fails.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=effective_armor_name -gexit
   ```

   Expected: FAIL — `Invalid call. Nonexistent function 'get_effective_armor_name'`.

3. **Add `get_effective_armor_name()`.** In
   `scripts/autoload/game_session.gd`, add next to
   `get_effective_weapon_name()`:

   ```gdscript
   func get_effective_armor_name(adventurer_id: String) -> String:
   	var adventurer := get_adventurer(adventurer_id)
   	if adventurer.is_empty():
   		return ""
   	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
   	return "" if armor.is_empty() else tr(armor.name_key)
   ```

4. **Run the test to verify it passes.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=effective_armor_name -gexit
   ```

   Expected: PASS.

5. **Write the failing Unit Details tests.** Add to
   `tests/unit/test_unit_details.gd`, near
   `test_stats_label_shows_xp_raw_and_effective_attack_and_health`:

   ```gdscript
   func test_equipment_label_shows_the_equipped_weapon_and_armor() -> void:
   	var screen := _open_unit_details(GameSession.WARRIOR_ID)

   	assert_eq(
   		screen.get_node("Body/Center/VBox/EquipmentLabel").text,
   		tr("unit_details.equipment") % ["Iron Longsword", 1, 8, "Leather Armor", 10, 10],
   		"A fresh Warrior wears the default Iron Longsword (1-8 damage) and Leather Armor (10% defense / 10% resistance)"
   	)
   	assert_true(screen.get_node("Body/Center/VBox/EquipmentLabel").visible)


   func test_equipment_label_reflects_a_changed_weapon() -> void:
   	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
   	var screen := _open_unit_details(GameSession.WARRIOR_ID)

   	assert_eq(
   		screen.get_node("Body/Center/VBox/EquipmentLabel").text,
   		tr("unit_details.equipment") % ["Steel Dagger", 2, 5, "Leather Armor", 10, 10]
   	)
   ```

   `equip_item_from_bank()` returns `false` when the item isn't in
   `banked_gear` — this test needs the item banked first, so add
   `GameSession.banked_gear = {"dagger_steel": 1}` before the call:

   ```gdscript
   func test_equipment_label_reflects_a_changed_weapon() -> void:
   	GameSession.banked_gear = {"dagger_steel": 1}
   	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
   	var screen := _open_unit_details(GameSession.WARRIOR_ID)

   	assert_eq(
   		screen.get_node("Body/Center/VBox/EquipmentLabel").text,
   		tr("unit_details.equipment") % ["Steel Dagger", 2, 5, "Leather Armor", 10, 10]
   	)
   ```

   Then find `test_an_unknown_unit_id_shows_a_not_found_message_and_hides_detail_rows`
   (around line 183) and add the new row to its hidden-labels assertions:

   ```gdscript
   func test_an_unknown_unit_id_shows_a_not_found_message_and_hides_detail_rows() -> void:
   	var screen := _open_unit_details("no_such_adventurer")

   	assert_true(screen.get_node("Body/Center/VBox/NotFoundLabel").visible)
   	assert_eq(screen.get_node("Body/Center/VBox/NotFoundLabel").text, "unit_details.not_found")
   	assert_false(screen.get_node("Body/Center/VBox/NameLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/ClassLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/LevelLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/StatusLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/SkillsLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/PerksLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/StatsLabel").visible)
   	assert_false(screen.get_node("Body/Center/VBox/EquipmentLabel").visible)
   ```

6. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit
   ```

   Expected: FAIL — `Node not found: "Body/Center/VBox/EquipmentLabel"`.

7. **Add the translation key.** In `translations/en.tres`, add next to
   `"unit_details.stats": "XP: %d / %d — Attack: %d raw / %d%% hit chance — Health: %d",`:

   ```
   "unit_details.equipment": "Weapon: %s (%d-%d damage) — Armor: %s (%d%% defense / %d%% resistance)",
   ```

8. **Add the node.** In `scenes/ui/unit_details.tscn`, add a new node
   right after the `StatsLabel` node (before `SkillsLabel`):

   ```
   [node name="EquipmentLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   ```

9. **Implement in `scripts/ui/unit_details.gd`.** Add next to
   `@onready var stats_label: Label = $Body/Center/VBox/StatsLabel`:

   ```gdscript
   @onready var equipment_label: Label = $Body/Center/VBox/EquipmentLabel
   ```

   In `_show_adventurer()`, add right after the `stats_label.text = ...`
   assignment:

   ```gdscript
   	var weapon_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
   	equipment_label.text = (
   		tr("unit_details.equipment")
   		% [
   			GameSession.get_effective_weapon_name(adventurer_id), weapon_range.x, weapon_range.y,
   			GameSession.get_effective_armor_name(adventurer_id),
   			GameSession.get_effective_defense(adventurer_id), GameSession.get_effective_resistance(adventurer_id),
   		]
   	)
   ```

   Then add `equipment_label` to both label-visibility loops. The
   `_show_adventurer()` loop:

   ```gdscript
   	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
   		label.visible = true
   ```

   becomes:

   ```gdscript
   	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label, equipment_label]:
   		label.visible = true
   ```

   And the `_show_not_found()` loop:

   ```gdscript
   	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
   		label.visible = false
   ```

   becomes:

   ```gdscript
   	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label, equipment_label]:
   		label.visible = false
   ```

10. **Run the tests to verify they pass.**

    ```bash
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit
    ```

    Expected: PASS.

11. **Run the full suite.**

    ```bash
    make test
    ```

    Expected: `---- All tests passed! ----`, exit code 0.

12. **Commit** only this task's files:

    ```bash
    git add scripts/autoload/game_session.gd scripts/ui/unit_details.gd scenes/ui/unit_details.tscn translations/en.tres tests/unit/test_game_session.gd tests/unit/test_unit_details.gd
    git commit -m "feat: show an adventurer's equipped weapon and armor in Unit Details"
    ```

## Milestone

Opening any adventurer's Unit Details screen (from Roster, Party Details,
or Add Member) shows their equipped weapon's name and damage range and
their equipped armor's name and defense/resistance — the trade loop now
closes informationally, not just mechanically.
