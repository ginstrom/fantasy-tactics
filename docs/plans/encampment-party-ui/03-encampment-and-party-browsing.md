# Step 03: Encampment hub, Units, and Parties

## Milestone

The player reaches the new encampment hub, can open Units and Parties, select
a party, see its contextual summary, and use View to open details.

## Setup

1. Start from merged `main` after Step 02 and create
   `feat/encampment-party-browsing`.
2. Review existing `encampment` and `party_manager` scenes/tests. Replace the
   old party-manager flow deliberately; do not leave a second management UI
   reachable from the encampment.

## Files

- Create: `scenes/ui/units.tscn`, `scripts/ui/units.gd`,
  `tests/unit/test_units.gd`
- Create: `scenes/ui/parties.tscn`, `scripts/ui/parties.gd`,
  `tests/unit/test_parties.gd`
- Modify: `scenes/ui/encampment.tscn`, `scripts/ui/encampment.gd`,
  `tests/unit/test_encampment.gd`, `scripts/autoload/game_manager.gd`
- Modify only when needed: `scenes/ui/party_manager.tscn`,
  `scripts/ui/party_manager.gd`, `tests/unit/test_party_manager.gd`

## Red: add focused failing tests

1. Encampment exposes Units, Buildings (TBD), Trade (TBD), and Deploy Party;
   Buildings/Trade cannot route to unimplemented systems.
2. The old Depart control is absent. Deploy Party is disabled when
   `get_deployable_encamped_parties()` is empty and enabled when one exists.
3. Units presents Parties as the working choice and marks Roster/Recruitment
   unavailable in this slice; Back returns to Encampment.
4. Parties renders every party as a selectable row, stores the selected party
   ID locally, calls panel party refresh, and panel View opens that party’s
   details via `GameManager`.
5. Empty party lists and stale route-context IDs render a safe empty state
   rather than causing node/path errors.

Run each new test file plus `test_encampment.gd`; expect red failures.

## Green: minimal implementation

1. Redraw Encampment with a left/center navigation column and the shared panel
   anchored on the right. Use `docs/party-screens.txt` as the structural
   reference, not as a runtime asset.
2. Create Units with Parties as the only active branch; Roster and Recruitment
   use disabled controls with a concise `TBD` label. Create Parties with a
   programmatic list/container sized for future multiple party records.
3. Retain `party_manager` only if it is a testable redirect to Parties; remove
   its direct management action from the Encampment.
4. Keep party selection as `var selected_party_id: String` in `parties.gd`;
   clear it when list refresh invalidates the ID.

Run focused GUT tests, then:

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

## Manual check and commit

From a fresh campaign, enter Encampment, open Units then Parties, select Party
1, confirm `Members: 0` appears in the right panel, and press View to reach
its details screen (the detailed member list lands in Step 04). After user
signoff:

```bash
git add scenes/ui/encampment.tscn scripts/ui/encampment.gd scenes/ui/units.tscn scripts/ui/units.gd scenes/ui/parties.tscn scripts/ui/parties.gd scripts/autoload/game_manager.gd tests/unit/test_encampment.gd tests/unit/test_units.gd tests/unit/test_parties.gd scenes/ui/party_manager.tscn scripts/ui/party_manager.gd tests/unit/test_party_manager.gd
git commit -m "feat: add encampment party browsing"
git checkout main && git merge --ff-only feat/encampment-party-browsing
git branch -d feat/encampment-party-browsing
```

Stage only files actually changed; do not add `docs/party-screens.txt` unless
the user explicitly asks to track that reference.
