# Add Member Design

## Goal

Make the Party Details "Add Member" action functional: a player viewing an
encamped party can assign an available adventurer to it. Includes the debug
tooling needed to reach and test the feature, since no other system can yet
produce an unstaffed party or a second roster adventurer.

## Navigation

```text
Party Details (encamped party)
└─ Add Member
   └─ available adventurer
      └─ back to Party Details (member added)
```

Add Member is enabled only for an encamped party with at least one available
adventurer; it stays hidden for a deployed party, unchanged from the current
slice. Roster and Recruitment remain non-functional and out of scope.

## Presentation and interaction

Add Member is a dedicated screen, reached from Party Details, following the
same list-and-immediate-action pattern Deploy Party already uses: it lists
`GameSession.get_available_adventurers()` and treats selecting a row as the
action itself — no separate confirm step. A successful assignment returns to
Party Details showing the updated roster; a row that has gone stale (its
adventurer got assigned elsewhere while this screen was open) fails safely and
the screen just refreshes its list in place. An empty list shows a dedicated
empty-state label rather than an empty screen.

## State boundaries

`GameSession` gains `assign_adventurer_to_party(party_id, adventurer_id)`,
matching the explicit-id convention `get_party`/`deploy_party` already use
rather than the existing selected-party-only version. The existing
`assign_adventurer_to_selected_party()` becomes a thin wrapper over the new
method (one implementation, two entry points), the same pattern
`can_depart_selected_party()` already follows for eligibility.
`get_available_adventurers()` is unchanged — it is already id-agnostic.
`GameManager` gains `go_to_add_member(party_id)`, validated the same way
`go_to_party_details`/`go_to_unit_details` validate their ids, and a thin
`assign_adventurer_to_party(party_id, adventurer_id)` passthrough for the new
screen to call.

## Debug tooling

Two gaps block reaching or testing this feature today, since Recruitment is
still deferred and the only scenario that creates a party (`party_ready`)
staffs it immediately:

- A new debug scenario, `party_empty`, calls `GameSession.create_party()`
  without staffing it — an encamped party that actually needs a member.
- A new debug action, `Recruit Adventurer`, mirrors the existing `Super Power`
  action (an immediate effect, not a scene-navigating scenario): it calls a
  new `GameSession.recruit_adventurer()`, which appends a new adventurer to
  the roster built from the same template as `DEFAULT_WARRIOR` with a fresh
  id/name derived from roster size. This is a real (if currently
  debug-only-reachable) roster primitive, the same status `create_party()`
  already has.

The manual test path: F9 → `party_empty` → F9 → `Recruit Adventurer` →
navigate to the party's details → Add Member now lists the recruited
adventurer.

## Verification boundary

Every state/API change starts with a focused GUT regression test:
`assign_adventurer_to_party` and `recruit_adventurer` on `GameSession`, the
`party_empty` scenario and `go_to_add_member`/`assign_adventurer_to_party` on
`GameManager`, and the new Add Member scene script (list population,
assign-and-navigate-back, stale-row refresh, empty state) — the same shape as
the existing Deploy Party tests. Final automated checks are `make check`, a
headless Godot editor scan, and `git diff --check`; manual signoff covers the
full debug-recruit-then-add-member path plus the disabled/hidden Add Member
states (party with no available adventurers, deployed party).
