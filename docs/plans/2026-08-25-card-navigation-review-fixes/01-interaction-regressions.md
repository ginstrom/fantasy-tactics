# Step 1 — Restore Escape ownership and Add Member assignment

**Milestone:** Escape closes a pending level-up card through the real scene input path, and Add Member's unit card can assign its current candidate to the route-context party.

**Files:**

- Modify: `scripts/ui/level_up.gd`
- Modify: `scripts/ui/add_member.gd`
- Modify: `tests/unit/test_battle_result.gd`
- Modify: `tests/unit/test_add_member.gd`

## Red/green tasks

1. Add a Battle Outcome test that calls `screen.level_up._unhandled_input(_escape_event())` while a perk is pending. Assert the event is not marked handled by the card body, then dispatch it to `screen.card_navigator._unhandled_input(event)` and assert the navigator closes while the battle outcome remains visible and the perk is still pending. Run its focused GUT selection; it must fail because `LevelUp` currently handles the event.
2. Remove the embedded card body's `ui_cancel` handling so its parent `CardNavigator` owns Close/Escape. Keep `Continue` and pending-perk rules unchanged. Re-run the focused Battle Outcome selection; it must pass.
3. Add an Add Member test that opens a candidate card, asserts the card exposes the assignment action, activates it, and verifies the candidate is assigned to the `route_context_id` party, the navigator closes safely, and the caller routes to that party’s details. Run its focused GUT selection; it must fail because the caller suppresses and does not map the intent.
4. Set the card to show assignment, connect `add_to_party_requested`, and implement the caller handler using the existing `GameManager.assign_adventurer_to_party(party_id, unit_id)` validation and `GameManager.go_to_party_details(party_id)` route. Ignore any card-supplied party ID so Add Member cannot assign to an unrelated party. Re-run the focused Add Member selection; it must pass.
5. Run the two complete focused test files with `-gselect=test_battle_result.gd` and `-gselect=test_add_member.gd`.

## Manual verification

Run `make play`. At Battle Outcome with a pending perk, press Escape on the level-up card: it must return to the outcome with final OK disabled. In Add Member, View a candidate, use Add to Party, and confirm return to that exact party’s details with the member present.
