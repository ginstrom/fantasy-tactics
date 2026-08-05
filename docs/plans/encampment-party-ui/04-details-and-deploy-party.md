# Step 04: Details and explicit party deployment

## Milestone

The player can inspect a party member and choose an eligible encamped party to
deploy directly onto the World Map.

## Setup

1. Start from merged `main` after Step 03 and create
   `feat/encampment-party-details-deployment`.
2. Review the route context created in Step 02 and deployment contract from
   Step 01. Do not make detail screens mutate party membership in this slice.

## Files

- Create: `scenes/ui/party_details.tscn`, `scripts/ui/party_details.gd`,
  `tests/unit/test_party_details.gd`
- Create: `scenes/ui/unit_details.tscn`, `scripts/ui/unit_details.gd`,
  `tests/unit/test_unit_details.gd`
- Create: `scenes/ui/deploy_party.tscn`, `scripts/ui/deploy_party.gd`,
  `tests/unit/test_deploy_party.gd`
- Modify: `scripts/autoload/game_manager.gd`,
  `tests/unit/test_game_manager.gd`, `translations/en.tres`

## Red: add focused failing tests

1. Party Details reads its party ID from route context, lists each member’s
   name/class/level row, and selecting a row refreshes unit context in the
   panel; panel View opens Unit Details for that exact ID.
2. Unit Details renders name, class, level, availability status, and only
   labelled `TBD` placeholders for skills/perks/stats; an invalid unit ID has
   a safe Back path.
3. Deploy Party lists exactly `get_deployable_encamped_parties()`—not all
   parties—and displays name/member count needed to choose.
4. Selecting an entry calls `GameManager.deploy_party(party_id)`; on success
   it transitions to World Map with that party deployed. An invalidated
   selection leaves the screen in place and refreshes the list.
5. The world map’s `has_deployed_party()` path still receives the selected
   party; cover position, selection, and marker rendering regression paths.

Run the new scene tests plus relevant GameManager/WorldMap tests; expect red
failures before scenes/actions exist.

## Green: minimal implementation

1. Build Party Details in the reference shape: title, Members table, and Back.
   Do not add functional Add Member; any placeholder is disabled and labelled
   TBD.
2. Build Unit Details from the introduced data contract. Use plain labels for
   name/class/level/status and render empty placeholders as `TBD` rather than
   inventing values.
3. Build Deploy Party with only eligible party rows and Back. A row is the
   intentional confirmation: it invokes manager deployment immediately, which
   changes scene only after `GameSession.deploy_party(id)` succeeds.
4. Every Back clears only UI route context; it must not change active party.

Run focused tests, then:

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

## Manual check and commit

Verify both conditions:

1. Fresh campaign: Deploy Party is disabled because no eligible party exists.
2. Create Party 1 and assign Warrior: choose Units -> Parties -> Party 1 ->
   member -> View; then choose Deploy Party -> Party 1 and verify the World
   Map opens with it deployed.

Set Warrior status non-available through test/debug setup and verify Party 1
disappears from Deploy Party. After user signoff:

```bash
git add scenes/ui/party_details.tscn scripts/ui/party_details.gd scenes/ui/unit_details.tscn scripts/ui/unit_details.gd scenes/ui/deploy_party.tscn scripts/ui/deploy_party.gd scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_party_details.gd tests/unit/test_unit_details.gd tests/unit/test_deploy_party.gd tests/unit/test_game_manager.gd
git commit -m "feat: add party details and deployment selection"
git checkout main && git merge --ff-only feat/encampment-party-details-deployment
git branch -d feat/encampment-party-details-deployment
```

Do not push.
