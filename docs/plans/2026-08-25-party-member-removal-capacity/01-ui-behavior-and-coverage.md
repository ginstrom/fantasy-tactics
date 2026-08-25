# Step 1: Party Details Removal and Capacity

**Goal:** Render current/max party occupancy and allow an encamped party to
remove its selected member back to Roster.

**Files:**

- Modify: `scenes/ui/party_details.tscn`
- Modify: `scripts/ui/party_details.gd`
- Modify: `scripts/campaign/party_service.gd`
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_party_details.gd`
- Modify: `tests/unit/test_game_session.gd`

## Red: write focused failing UI tests

Add scene-level tests that:

1. Create a party with two members and assert the new label reads `2/4` (using
   the current level-one max dynamically where appropriate).
2. Select a displayed member, press `Remove from Party`, then assert the
   member no longer appears in `member_ids`, remains in `GameSession`
   adventurers, the table is refreshed, and the action is disabled after the
   selection clears.
3. Assert the removal action is unavailable for a deployed party.
4. Add domain coverage proving removal targets the supplied party (not the
   global selected party) and rejects a deployed party.

Run the focused file:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details.gd -gexit
```

Expected result: the new tests fail because the scene nodes/handler do not yet
exist.

## Green: implement the minimum UI wiring

1. Add `PartySizeLabel` below `PartyNameLabel` in the scene.
2. Add `RemoveFromPartyButton` below the member list and connect it to
   `_on_remove_from_party_pressed`.
3. In `refresh()`, set capacity text from the current party member count and
   `GameSession.get_max_party_size()`. Show removal only when the party is
   encamped; enable it only for a selected current member.
4. Add `remove_adventurer_from_party(party_id, adventurer_id)` to the party
   service and GameSession facade. It must require an encamped existing party
   and a current member. Keep `remove_adventurer_from_selected_party` as its
   thin selected-party wrapper.
5. In the UI handler, call the new party-scoped facade, then refresh. This
   preserves the service ownership boundary and makes Party Details correct
   when it is viewing a party other than the globally selected one.

Re-run the focused test file; expected result: all tests pass.

## Verify and manually inspect

Run:

```bash
make check
git diff --check
make play
```

Manual check: at the Encampment, open Party Details, confirm the top occupancy
updates after selecting and removing a member, then open Roster and confirm
that adventurer is listed as unassigned. Deploy a party and confirm the
removal action is absent.

After user signoff, commit only the three implementation/test files (plus the
already committed plan documents if applicable), merge the feature branch
locally to `main`, then delete the branch. Do not push or open a PR.
