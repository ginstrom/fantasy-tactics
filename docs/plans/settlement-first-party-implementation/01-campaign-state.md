# Step 01: Campaign State

## Milestone

`GameSession` starts with one unassigned Warrior and no party. It can create
the sole party, add or remove the Warrior, deploy a non-empty party at the
settlement tile, persist its movement position, and return it to settlement.

## Setup

This step has no feature prerequisite. Preserve any user-owned working-tree
changes, especially `AGENTS.md`.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/campaign-party-state
```

Do not continue if the intended files have unrelated edits.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_world_map.gd`

## Red/green implementation

### 1. Write failing session tests

Replace tests asserting `DEFAULT_PARTY` and a global `party_position` with
tests for the new public API:

```gdscript
func test_new_session_has_one_unassigned_warrior_and_no_party() -> void:
    var session: Node = GameSessionScript.new()
    autofree(session)
    assert_eq(session.adventurers, [GameSessionScript.DEFAULT_WARRIOR])
    assert_eq(session.parties, [])
    assert_eq(session.selected_party_id, "")

func test_create_party_then_add_and_remove_warrior() -> void:
    var session: Node = GameSessionScript.new()
    autofree(session)
    assert_true(session.create_party())
    assert_true(session.assign_adventurer_to_selected_party("warrior_001"))
    assert_eq(session.get_selected_party().member_ids, ["warrior_001"])
    assert_true(session.remove_adventurer_from_selected_party("warrior_001"))
    assert_false(session.can_depart_selected_party())

func test_deploy_and_return_change_only_the_selected_party_state() -> void:
    var session: Node = GameSessionScript.new()
    autofree(session)
    session.create_party()
    session.assign_adventurer_to_selected_party("warrior_001")
    assert_true(session.depart_selected_party())
    assert_true(session.has_deployed_party())
    assert_eq(session.get_deployed_party_position(), Vector2i(0, 0))
    session.set_deployed_party_position(Vector2i(1, 0))
    session.return_deployed_party_to_settlement()
    assert_false(session.has_deployed_party())
    assert_eq(session.get_selected_party().location_id, "starting_settlement")
```

Include negative tests: a second party cannot be created; unknown or assigned
adventurers cannot be assigned; an empty party cannot depart; and a position
cannot be written without a deployed party.

```bash
make test
```

Expected: FAIL because the old `party` array and global `party_position` API
remain.

### 2. Write the minimal state model

In `game_session.gd`, remove `DEFAULT_PARTY`, `party`, and `party_position`.
Keep encounter fields unchanged. Add constants:

```gdscript
const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(0, 0)
const WARRIOR_ID := "warrior_001"
const DEFAULT_WARRIOR := {
    "id": WARRIOR_ID, "name": "Warrior", "class": "warrior", "weapon": "sword"
}
const FIRST_PARTY_ID := "party_001"
```

Use `adventurers: Array[Dictionary]`, `parties: Array[Dictionary]`, and
`selected_party_id: String`. A party dictionary has `id`, `member_ids`,
`location_id`, `world_position`, and `deployed`. Provide the tested methods:
`create_party`, `get_selected_party`, `get_available_adventurers`,
`assign_adventurer_to_selected_party`, `remove_adventurer_from_selected_party`,
`can_depart_selected_party`, `depart_selected_party`, `has_deployed_party`,
`get_deployed_party_position`, `set_deployed_party_position`, and
`return_deployed_party_to_settlement`. Return `false` without mutation when a
precondition fails. Deep-duplicate defaults in `reset()`.

### 3. Adapt existing world-map tests

Change `test_world_map.gd` setup to create a party, assign `warrior_001`, and
deploy it before movement tests. Replace direct writes to
`GameSession.party_position` with `set_deployed_party_position`. Keep movement
and encounter tests; only their state setup changes.

### 4. Verify green

```bash
make test
make check
```

Expected: all GUT tests pass and no source references `DEFAULT_PARTY`,
`GameSession.party`, or `GameSession.party_position`.

## Commit and handoff

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd tests/unit/test_world_map.gd
git commit -m "feat: add campaign party state"
```

No manual play check is required for this state-only milestone. Ask for user
approval, then merge locally:

```bash
git checkout main && git merge --ff-only feat/campaign-party-state
git branch -d feat/campaign-party-state
git status --short
```

Do not push.
