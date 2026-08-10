# Step 1: Specify and Implement the Campaign Snapshot Contract

## Milestone

`GameSession` can export and all-or-nothing import a versioned deep-copied snapshot of durable campaign data without touching disk.

## Setup

For implementation, branch normally from `main` (never use a worktree):

```bash
git checkout main && git pull
git checkout -b feature/initial-campaign-readiness
```

Read `docs/dev/testing.md` and the reset/population/reward methods in `scripts/autoload/game_session.gd`.

## Files

- Create: `scripts/save/campaign_snapshot.gd`
- Create: `tests/unit/test_campaign_snapshot.gd`
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Red

Create a `CampaignSnapshot` value object with `FORMAT_VERSION := 1`, `to_dictionary()`, and `from_dictionary(data) -> Dictionary`, returning `{ "ok": bool, "snapshot": Dictionary, "error": String }`.

Write round-trip coverage for all durable state: roster/progression/equipment, parties/routes, selected IDs, world turn, encounter instances/completions/vacancies, recruitment offers/vacancies, gold/buildings, every battle/pending/banked reward store, player name, and tutorial progress planned in Step 4. Assert deep-copy isolation and no reward banking.

```gdscript
func test_import_keeps_carried_rewards_unbanked() -> void:
    GameSession.pending_reward = 17
    var snapshot := GameSession.export_campaign_snapshot()
    GameSession.reset()
    assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
    assert_eq(GameSession.pending_reward, 17)
    assert_eq(GameSession.gold, 0)
```

Also reject missing/unknown version, malformed types, duplicate IDs, invalid selected-party/encounter references, and assert an invalid import leaves a prepared session unchanged. Do not serialize callables, scene references, modals, or test seams.

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_snapshot.gd -gexit
```

Expected: FAIL because the contract and `GameSession` APIs do not exist.

## Green

Add explicit `GameSession.export_campaign_snapshot()` and `import_campaign_snapshot(data)` methods. Export a declared field list only; convert `Vector2i` to `{ "x": int, "y": int }`. Normalize and validate the entire payload in a separate dictionary, then assign only on success. Never call `merge_battle_loot_into_party()` or `deposit_pending_reward()`.

Run focused tests, then:

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

## Commit and handoff

```bash
git add scripts/autoload/game_session.gd scripts/save/campaign_snapshot.gd tests/unit/test_game_session.gd tests/unit/test_campaign_snapshot.gd
git commit -m "feat: add validated campaign snapshot contract"
```

Completion: the snapshot is complete, versioned, deep-copy-safe, and all-or-nothing. Do not merge until Step 8 user signoff.
