# Step 4: Dynamic Debug Menu and Safe Reload

## Objective

Render F9 scenario buttons from the active validated manifest, retain utility actions, and make reload safe: only a valid manifest replaces the displayed configuration.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/dynamic-debug-menu
```

Read `scenes/debug/debug_menu.tscn`, `scripts/debug/debug_menu.gd`, and `tests/unit/test_debug_menu.gd`.

## Red / green work

1. Add failing UI tests that instantiate the menu and verify one button per manifest entry, source-order category headers, localized `name_key` labels, and preserved Super Power/Recruit utility actions.
2. Add a failing reload test: a valid edited test manifest rebuilds the buttons; an invalid reload preserves the current buttons and surfaces concise error text rather than clearing the menu.
3. Add a failing test that pressing a scenario invokes `GameManager.run_debug_scenario(id)` and hides the menu only when it returns `OK`.
4. Run the focused test and confirm red.
5. Replace the hard-coded scenario buttons in `scenes/debug/debug_menu.tscn` with a scrollable scenario container, status/error label, Reload button, and a separate utilities footer.
6. Update `scripts/debug/debug_menu.gd` to rebuild from `DebugScenarios.get_scenarios_by_category()`, create buttons with bound stable IDs, and call `load_scenarios()` for reload. Rebuild only on a successful load; otherwise retain the prior view and show the loader diagnostics.
7. Add required translation keys, rerun focused tests, then `make check`.

## Milestone and manual check

Run `make play`, press F9, verify categorized scrolling buttons and utilities, then modify a non-structural label in `config/debug_scenarios.json` and reload. Introduce a syntax error, reload, and confirm the current menu remains intact with an error visible.

## Handoff

After user sign-off, run `godot --headless --path . --editor --quit` and `git diff --check`, commit `feat: render debug scenarios from manifest`, merge `feat/dynamic-debug-menu` locally into `main`, and delete the branch. Do not push.
