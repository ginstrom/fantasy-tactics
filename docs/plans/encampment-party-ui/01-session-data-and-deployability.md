# Step 01: Durable party data and deployability

## Milestone

`GameSession` can look up records by ID and can identify/deploy an encamped
party with an available member without hard-coding the Warrior or a UI scene.

## Setup

1. Start from up-to-date `main`: `git checkout main && git pull --ff-only`.
2. Create `feat/encampment-session-data`.
3. Read `scripts/autoload/game_session.gd` and
   `tests/unit/test_game_session.gd`; preserve existing public behavior during
   this compatibility-focused change.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `translations/en.tres` only if a state label is needed by a tested
  public presentation helper; otherwise keep state keys out of this step.

## Red: add focused failing tests

Add tests that begin from `reset()` and establish:

1. the default Warrior has `name`, `class`, `level == 1`, and
   `availability_status == "available"` while its stats/progression placeholders
   are present but do not affect combat;
2. a newly created party has `name == "Party 1"`, an encampment location, and
   placeholder party metadata without breaking its existing route fields;
3. `get_party(party_id)` and `get_adventurer(adventurer_id)` return copies or
   safe records for valid IDs and `{}` for unknown IDs;
4. `get_deployable_encamped_parties()` excludes an empty party, a deployed
   party, a party outside the starting encampment, and a party whose members
   are all non-`available`, but includes one with at least one available
   member;
5. `deploy_party(party_id)` rejects an ineligible/unknown ID and, for an
   eligible party, selects it, marks it deployed at the starting location, and
   leaves other parties untouched.

Run:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
```

Expected: the new assertions fail because the fields and named APIs do not
exist yet; existing tests remain the regression baseline.

## Green: minimal implementation

1. Extend the default adventurer contract with only these introduced fields:
   `level: 1`, `availability_status: "available"`, `stats: {}`, and
   `progression: {}`. Document the two dictionaries as TBD, not as gameplay
   rules.
2. Extend created party records with `name: "Party 1"`, `progression: {}`, and
   `metadata: {}`. Keep current deployment, location, route, and turn fields.
3. Add lookup helpers and a private membership/status check. Do not expose
   scene controls to mutate records directly.
4. Define eligibility as: party exists, `location_id == STARTING_SETTLEMENT_ID`,
   `deployed == false`, and at least one referenced adventurer has
   `availability_status == "available"`.
5. Add `deploy_party(party_id) -> bool`; it must perform the validation before
   setting `selected_party_id` and deployment state. Keep
   `depart_selected_party()` temporarily as a compatibility wrapper or update
   all callers in a later coordinated step—do not create two divergent
   validation rules.

Re-run the focused test, then:

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

Expected: all checks pass; include any intended Godot `.uid` sidecars and
remove unrelated generated files.

## Manual check and commit

Use the debug Party Ready scenario, then confirm the existing World Map still
shows and moves the deployed Warrior. After the user confirms that check:

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd translations/en.tres
git commit -m "feat: add deployable party session queries"
git checkout main && git merge --ff-only feat/encampment-session-data
git branch -d feat/encampment-session-data
```

Do not push.
