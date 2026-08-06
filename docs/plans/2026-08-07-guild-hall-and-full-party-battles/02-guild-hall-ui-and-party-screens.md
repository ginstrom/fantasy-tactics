# Task 2: Guild Hall UI and full-party awareness

## Objective

Make the Buildings button live, add the Buildings and Guild Hall screens,
and make the two existing screens that assumed assignment can never fail for
capacity reasons stay honest once a party can actually be full (design.md
§1 "UI call sites that need 'party is full' awareness" and "Buildings UI").

## Files

- Modify: `scripts/ui/party_details.gd`, `tests/unit/test_party_details.gd`
- Modify: `scripts/ui/unit_details.gd`, `tests/unit/test_unit_details.gd`
- Modify: `scripts/autoload/game_manager.gd`, `tests/unit/test_game_manager.gd`
- Modify: `scenes/ui/encampment.tscn`, `tests/unit/test_encampment.gd`
- Create: `scripts/ui/buildings.gd`, `scenes/ui/buildings.tscn`,
  `tests/unit/test_buildings.gd`
- Create: `scripts/ui/guild_hall.gd`, `scenes/ui/guild_hall.tscn`,
  `tests/unit/test_guild_hall.gd`
- Modify: `translations/en.tres`

## Steps

### Existing screens

1. Add a failing test to `test_party_details.gd`: with a party at the
   level-1 cap (4 members — mirror
   `test_add_member_is_disabled_when_no_adventurer_is_available`'s setup but
   append three more available test adventurers and assign all four), the
   `AddMemberButton` is `visible` but `disabled`.
2. Implement: in `party_details.gd`'s `refresh()`, change
   `add_member_button.disabled` to also be `true` when
   `party.get("member_ids", []).size() >= GameSession.get_max_party_size()`.
   Rerun `test_party_details` green.
3. Add a failing test to `test_unit_details.gd`: open Unit Details from
   Roster for the (unassigned) seeded Warrior while a *different* party is
   already at the level-1 cap (create the party, append and assign 4 other
   test adventurers to it) — the `PartyPicker` must not be `visible`, and
   `AssignmentExplanationLabel` must be, exactly like the existing
   "no encamped party" case.
4. Implement: in `unit_details.gd`'s `_refresh_assignment_section()`, filter
   `GameSession.get_encamped_parties()` down to parties where
   `party.member_ids.size() < GameSession.get_max_party_size()` before
   building `encamped_parties`. Rerun `test_unit_details` green.

### Buildings and Guild Hall screens

5. Add `translations/en.tres` keys (alongside the `encampment.*` block):
   `buildings.title` = "Buildings", `buildings.column.name` = "Name",
   `buildings.guild_hall` = "Guild Hall"; and (a new block near the end):
   `guild_hall.title` = "Guild Hall", `guild_hall.level` = "Guild Hall — Level
   %d", `guild_hall.party_size` = "Party size: %d", `guild_hall.upgrade` =
   "Upgrade to Level 2 — %d gold", `guild_hall.max_level` = "Max Level".
6. Add `go_to_buildings()` and `go_to_guild_hall()` to `game_manager.gd`,
   following the exact shape of `go_to_units()`: a new `BUILDINGS_SCENE`/
   `GUILD_HALL_SCENE` constant each, `_clear_detail_context()` (neither
   screen uses `route_context_id`), then `_change_scene(...)`. Add matching
   tests to `test_game_manager.gd` mirroring
   `test_entering_units_clears_a_stale_route_context_id` and the
   `assert_string_contains(source, "func go_to_units()")`-style source check
   used for `go_to_roster()`.
7. In `encampment.tscn`, set `BuildingsButton`'s `disabled` to `false` and
   add `[connection signal="pressed" from="Center/VBox/BuildingsButton"
   to="." method="_on_buildings_button_pressed"]`; add
   `_on_buildings_button_pressed()` to `encampment.gd` calling
   `GameManager.go_to_buildings()`. Update
   `test_buildings_and_trade_are_present_but_cannot_route_to_unimplemented_systems`
   in `test_encampment.gd`: split it so Buildings is asserted enabled/wired
   (new test, mirroring `test_units_button_routes_via_game_manager`) while
   Trade stays asserted disabled.
8. Create `scripts/ui/buildings.gd` and `scenes/ui/buildings.tscn` following
   the `roster.tscn`/`roster.gd` list-screen pattern (`Center/VBox/Title`,
   a `TableView` node named `BuildingTable`, a `BackButton`) but with no
   `InformationPanel` — this list has nothing to summarize. `_build_columns()`
   returns one expanding `name` column (`tr("buildings.column.name")`).
   `_build_rows()` returns exactly one row:
   `{"id": "guild_hall", "name": tr("buildings.guild_hall")}`. Wire
   `row_activated` to route to `GameManager.go_to_guild_hall()` when the
   activated row's id is `"guild_hall"`. `_on_back_pressed()` calls
   `GameManager.go_to_buildings()`'s counterpart, `GameManager.go_to_encampment()`.
   Add `test_buildings.gd` mirroring `test_roster.gd`'s title/back-button and
   "table has the documented columns and one row" tests (use
   `UiTestHelpers.tree_row_values`), plus a row-activation-routes test.
9. Create `scripts/ui/guild_hall.gd` and `scenes/ui/guild_hall.tscn`: labels
   `LevelLabel` (`tr("guild_hall.level") % GameSession.guild_hall_level`) and
   `PartySizeLabel` (`tr("guild_hall.party_size") % GameSession.get_max_party_size()`);
   an `UpgradeButton` visible only while `guild_hall_level <
   GameSession.GUILD_HALL_MAX_LEVEL`, its `disabled` bound to `not
   GameSession.can_upgrade_guild_hall()`, its text
   `tr("guild_hall.upgrade") % GameSession.GUILD_HALL_UPGRADE_COST`; a
   `MaxLevelLabel` (text `guild_hall.max_level`) visible only at max level.
   Pressing `UpgradeButton` calls `GameSession.upgrade_guild_hall()` then
   `refresh()`. `_on_back_pressed()` calls `GameManager.go_to_buildings()`.
   Add `test_guild_hall.gd` covering: level-1 default display (upgrade button
   enabled once `GameSession.gold = 50`, disabled below that), a successful
   upgrade via the button leaving `guild_hall_level == 2` and refreshing the
   screen to show the max-level state (upgrade button hidden, `MaxLevelLabel`
   visible), and the back button routing to Buildings.
10. Run:

    ```bash
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details -gexit
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details -gexit
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager -gexit
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_encampment -gexit
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_buildings -gexit
    godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_guild_hall -gexit
    ```

    Expected: all green.
11. Commit:

    ```bash
    git add scripts/ui/party_details.gd tests/unit/test_party_details.gd \
      scripts/ui/unit_details.gd tests/unit/test_unit_details.gd \
      scripts/ui/game_manager.gd tests/unit/test_game_manager.gd \
      scenes/ui/encampment.tscn scripts/ui/encampment.gd tests/unit/test_encampment.gd \
      scripts/ui/buildings.gd scenes/ui/buildings.tscn tests/unit/test_buildings.gd \
      scripts/ui/guild_hall.gd scenes/ui/guild_hall.tscn tests/unit/test_guild_hall.gd \
      translations/en.tres
    git commit -m "feat: add the Buildings and Guild Hall screens"
    ```

## Milestone

From the Encampment, a player can open Buildings, open Guild Hall, and spend
50 gold to raise the party cap to 5 — and Party Details / Unit Details never
let the player land on a dead-end "assignment silently fails" state once a
party is full.
