# Step 2: Add Atomic Current-Campaign Persistence

## Milestone

A repository writes one complete snapshot atomically to `user://campaign-save.json`, reports actionable errors, and never treats partial/corrupt input as a campaign.

## Setup and files

Work on `feature/initial-campaign-readiness` after Step 1. Read the JSON conventions in `scripts/autoload/game_config.gd`.

- Create: `scripts/save/save_repository.gd`
- Create: `tests/unit/test_save_repository.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `project.godot` only if an autoload is actually required.

## Red

Give the repository a test-injectable exact path. Test: first write is parseable; second write replaces rather than appends; success leaves no temporary file; absent/corrupt/wrong-envelope/snapshot-invalid files have distinct diagnostic codes; and a failed load never imports or changes a prepared `GameSession`. `has_valid_save()` must validate both envelope and snapshot.

Use one unique test filename under `user://`, removing only that exact path in cleanup:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_save_repository.gd -gexit
```

Expected: FAIL because `SaveRepository` is absent.

## Green

Write JSON to a sibling temporary file, flush/close it, and rename it over the target with `DirAccess`; never truncate the old save before replacement succeeds. Parse and validate on read before returning a typed result. Add test-injectable narrow manager wrappers; UI must not use `FileAccess`.

Run focused repository/manager tests, `make check`, editor scan, and `git diff --check`.

## Commit and handoff

```bash
git add scripts/save/save_repository.gd scripts/autoload/game_manager.gd tests/unit/test_save_repository.gd tests/unit/test_game_manager.gd
git commit -m "feat: persist the current campaign atomically"
```

Include `project.godot` only when changed. Do not merge until Step 8 user signoff.
