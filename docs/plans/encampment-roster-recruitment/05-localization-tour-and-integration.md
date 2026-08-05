# 05 — Localization, Tour, and Integration

## Milestone

All new copy is localized, each new screen/state is captured, the full suite passes, the player has manually approved the route, and the feature is locally merged after approval.

## Files

- Modify: `translations/en.tres`
- Modify: `tests/unit/test_localization.gd`
- Modify: `scripts/tools/screenshot_tour.gd`
- Modify: `README.md` only if its debug-tour description needs the new routes

## Steps

1. **Red:** add localization tests for every new text key: roster/recruitment titles and empty states, Party/Unassigned, cost/gold formatting, Add to Party, no eligible party, and Recruit action. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization -gexit
   ```

   Expected: unresolved keys.
2. **Green:** add English values to `translations/en.tres`; scenes retain keys and scripts use `tr()` for parameterized values. Re-run focused localization tests.
3. Extend `screenshot_tour.gd` with deterministic Roster, Unit Details from Roster, and Recruitment states. Seed only via public `GameSession` APIs; keep the tour ordering valid after candidates are purchased. Run `make screenshots` where a display is available and inspect the new PNGs.
4. Run final automated and editor checks:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   git status --short --branch
   ```

   Expected: full test suite passes, editor scan succeeds (and intended `.uid` files are tracked), whitespace check is clean.
5. Ask the user to run `make play` and verify the acceptance route from `index.md`. Do not merge before explicit approval.
6. After approval, commit final files, update `main`, merge locally, re-run `make check`, editor scan, and whitespace check, then delete the feature branch. Do not push:

   ```bash
   git add translations/en.tres tests/unit/test_localization.gd scripts/tools/screenshot_tour.gd README.md
   git commit -m "chore: document encampment roster flow"
   git checkout main
   git pull --ff-only
   git merge feat/encampment-roster-recruitment
   make check
   godot --headless --path . --editor --quit
   git diff --check HEAD^ HEAD
   git branch -d feat/encampment-roster-recruitment
   ```
