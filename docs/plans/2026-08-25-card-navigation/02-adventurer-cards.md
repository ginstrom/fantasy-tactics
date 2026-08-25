# Step 2 — Adventurer and party-member cards

**Milestone:** Roster, Add Member, and Party Details open the same unit card
and cycle only through the visible units in the originating list.

**Depends on:** Step 1 merged and its `CardNavigator` API handoff.

**Branch:** `feat/card-navigator-adventurers` from updated `main`.

**Files:**

- Create: `scenes/ui/unit_detail_card.tscn`
- Create: `scripts/ui/unit_detail_card.gd`
- Modify: `scenes/ui/roster.tscn`, `scripts/ui/roster.gd`
- Modify: `scenes/ui/add_member.tscn`, `scripts/ui/add_member.gd`
- Modify: `scenes/ui/party_details.tscn`, `scripts/ui/party_details.gd`
- Modify: `scripts/ui/unit_details.gd`, `scenes/ui/unit_details.tscn`
- Modify: `tests/unit/test_roster.gd`, `tests/unit/test_add_member.gd`,
  `tests/unit/test_party_details.gd`
- Create: `tests/unit/test_unit_detail_card.gd`
- Modify: `translations/en.tres`

## Red/green tasks

1. Write `test_unit_detail_card.gd` against live session data for a Warrior,
   Scout, and Cleric. Assert existing read-only fields remain fresh and that
   the card emits intents rather than changing routing/state itself. Port the
   existing Unit Details assertions before removing legacy presentation.
2. Add screen tests that sort/filter a roster (when applicable), open the
   selected entry, cycle in the resulting displayed order, wrap, close via
   Escape, and assert the original `TableView` regains the last ID selection.
   Add equivalent Party Details and Add Member tests, including a member
   removed while its card is open.
3. Run the four focused files with `-gselect`; expect failures for missing
   card/navigator integration.
4. Extract the reusable content from `Unit Details` into `UnitDetailCard`.
   Preserve progression, equipment, healing, promotion, and assignment
   eligibility through the existing `GameSession` APIs. Keep any legitimate
   standalone route only if an active caller still needs it; otherwise remove
   stale route-only UI and tests rather than maintaining two divergent
   presentations.
5. Have each list construct its own displayed ID snapshot, install the card
   body in its own navigator, and map card intents back to existing handlers.
   After an action can change membership/availability, refresh then either
   restore the still-valid ID or close safely. Do not route to a new scene for
   browsing adjacent units.
6. Re-run focused tests green, then run `make check` before manual review.

## Manual check and handoff

Use `make play`: visit Roster, Party Details, and Add Member; open any unit;
wrap both directions; verify Close/Escape returns to the same list and last
unit; confirm Add to Party, Heal, promotion, and equipment controls retain
their existing eligibility. Reviewer checks no duplicate unit-detail data
model was created and no old `GameManager` route remains accidentally active.
After signoff, commit/merge only this step's files and record any retained
standalone Unit Details route for the next step.
