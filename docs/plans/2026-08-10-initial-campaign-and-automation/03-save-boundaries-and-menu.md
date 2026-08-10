# Step 3: Connect Save and Load at Safe Boundaries

## Milestone

Players can save at supported campaign surfaces, Continue resumes real state, and rejected/failed operations are visible without corruption.

## Setup and files

Work after Step 2. Read `docs/dev/code-map.md`, `scenes/ui/game_menu.tscn`, `scripts/ui/game_menu.gd`, and `scripts/ui/start_menu.gd`.

- Modify: `scripts/autoload/game_manager.gd`, `scripts/ui/game_menu.gd`, `scripts/ui/start_menu.gd`, `translations/en.tres`
- Modify: `scenes/ui/game_menu.tscn` only if its existing status label is insufficient
- Modify: `tests/unit/test_game_manager.gd`, `tests/unit/test_start_menu.gd`
- Create: `tests/unit/test_game_menu.gd`

## Red

Use a fake repository to prove that manager save works only at Encampment/World Map with `selected_encounter == ""`; an active encounter makes no write; successful save does not change reward buckets; Continue/Load validates/imports before routing (World Map for a deployed party, Encampment otherwise); and missing/corrupt/incompatible saves leave Start Menu/reset state intact. Assert menu scripts emit manager intents, never direct file/session operations.

Run focused start/pause-menu tests; expected: FAIL because Save is placeholder-only and Load is unwired.

## Green

Implement `GameManager.can_save_current_campaign()`, save/load wrappers, and one `go_to_loaded_campaign()` decision. Reject active encounters before snapshot export; do not infer safety from scene names. Replace `menu.not_implemented` with localized success/error feedback, wire pause-menu Load, and set enablement from actual repository validity. Add stable translation keys and run the localization suite.

Run focused tests, `make check`, editor scan, and `git diff --check`.

## Manual verification and commit

With `make play`, save at Encampment and with carried World Map rewards; quit/relaunch/Continue after each; confirm state/rewards remain unchanged. Enter battle and confirm save is unavailable/rejected.

```bash
git add scripts/autoload/game_manager.gd scripts/ui/game_menu.gd scripts/ui/start_menu.gd scenes/ui/game_menu.tscn translations/en.tres tests/unit/test_game_manager.gd tests/unit/test_start_menu.gd tests/unit/test_game_menu.gd
git commit -m "feat: save and resume stable campaigns"
```

Omit unchanged scene files. Record results for Step 8; do not merge before signoff.
