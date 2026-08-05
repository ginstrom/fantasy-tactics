# 02 — Roster and Unit-First Assignment

## Milestone

Roster uses `TableView`; an available unassigned unit can join a selected encamped party from Unit Details, then returns to Roster with its Party column updated.

## Files

- Create: `scenes/ui/roster.tscn`, `scripts/ui/roster.gd`, `scripts/ui/roster.gd.uid`, `tests/unit/test_roster.gd`, `tests/unit/test_roster.gd.uid`
- Modify: `scenes/ui/units.tscn`, `scripts/ui/units.gd`, `scenes/ui/unit_details.tscn`, `scripts/ui/unit_details.gd`
- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`
- Modify: `tests/unit/test_units.gd`, `tests/unit/test_unit_details.gd`, `tests/unit/test_game_session.gd`, `tests/unit/test_game_manager.gd`

## Steps

1. **Red:** replace Units' disabled-Roster test with enabled/routed expectations. Create `test_roster.gd` requiring `RosterTable: TableView` with Name/Class/Level/Status/Party columns, Warrior shown as `Unassigned`, assigned Warrior shown as `Party 1`, selection summary, activation/View route, empty/stale refresh, Back, and Escape coverage.
2. **Red:** require `GameSession.get_encamped_parties()` and that assignment rejects a deployed/non-encamped party. Require Unit Details opened from Roster to show a party picker plus disabled Add action until a valid party is chosen; test success, invalid/stale selection, no eligible party, assigned/unavailable hiding, and Back → Roster. Preserve existing Party Details origin/Back behavior.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_units,test_roster,test_unit_details,test_game_session,test_game_manager -gexit
   ```

   Expected: missing scene/control/origin failures.
4. **Green:** add `get_encamped_parties()` (settlement, not deployed) and reject other parties in `assign_adventurer_to_party()`. Create the centered Roster scene with `RosterTable`, empty label, Back, and InformationPanel. Configure `TableColumn`s and rows using stable adventurer IDs; resolve Party names from session data; wire selection/activation and panel View.
5. **Green:** enable/connect Roster in Units. Add `unit_details_origin` to `GameManager`, separate from `route_context_id`; retain `go_to_unit_details(id)` compatibility and add `go_to_unit_details_from_roster(id)`. Clear both on invalid/destination routes.
6. **Green:** add hidden Unit Details assignment controls: explanation, `OptionButton`, and `AddToPartyButton`. Show them only for Roster origin + available unassigned unit. Store party IDs as picker metadata, enable only valid choices, assign through `GameManager`, and route to Roster only after `OK`; otherwise refresh in place.
7. Re-run focused tests. Commit:

   ```bash
   git add scenes/ui/roster.tscn scripts/ui/roster.gd scripts/ui/roster.gd.uid scenes/ui/units.tscn scripts/ui/units.gd scenes/ui/unit_details.tscn scripts/ui/unit_details.gd scripts/autoload/game_session.gd scripts/autoload/game_manager.gd tests/unit/test_roster.gd tests/unit/test_roster.gd.uid tests/unit/test_units.gd tests/unit/test_unit_details.gd tests/unit/test_game_session.gd tests/unit/test_game_manager.gd
   git commit -m "feat: add roster assignment flow"
   ```
