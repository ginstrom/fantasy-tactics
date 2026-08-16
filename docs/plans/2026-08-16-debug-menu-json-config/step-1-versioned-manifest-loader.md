# Step 1: Versioned Debug Manifest Loader

## Objective

Replace the hard-coded scenario ID list with a validated, ordered debug-manifest cache. This step loads metadata only; it does not apply campaign state or route scenes.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/debug-scenario-manifest-loader
```

Read `docs/dev/testing.md`, `scripts/debug/debug_scenarios.gd`, `tests/unit/test_debug_scenarios.gd`, and `scripts/save/campaign_snapshot.gd` before editing.

## Red / green work

1. In `tests/unit/test_debug_scenarios.gd`, add failing tests that a valid manifest preserves source order; rejects unsupported `manifest_version`, duplicate/empty IDs, non-string names/categories, invalid launch scenes, and missing/non-Dictionary snapshots; and reports all validation errors.
2. Add failing reload tests: invalid JSON, a missing file, or one invalid entry returns a structured failure, preserves the previous cache exactly, and exposes diagnostics. No fallback defaults may silently mask an authoring error.
3. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_debug_scenarios.gd -gexit`; confirm the new tests fail because the loader and result surface do not exist.
4. Create `config/debug_scenarios.json` with `manifest_version`, ordered `scenarios`, metadata (`id`, `name_key`, `category`, `description`), `launch.scene`, and an opaque `campaign_snapshot` dictionary. Do not add a second `session` schema.
5. Update `scripts/debug/debug_scenarios.gd` with a `DEFAULT_MANIFEST_PATH`, ordered scenario storage, `load_scenarios(path)` returning `{ok, errors}`, `get_scenario()`, `get_all_scenarios()`, and ordered category grouping. Parse and fully validate into temporary values before replacing the cache; duplicate returned dictionaries so callers cannot mutate the cache.
6. Rerun the focused test, then `make check`.

## Milestone and manual check

`make check` passes, and `python3 -m json.tool config/debug_scenarios.json >/dev/null` succeeds. Temporarily introduce malformed JSON, reload via a focused test harness, and confirm the prior scenario IDs and diagnostics remain available.

## Handoff

After user sign-off, run `godot --headless --path . --editor --quit` and `git diff --check`, commit `feat: load validated debug scenario manifests`, merge `feat/debug-scenario-manifest-loader` locally into `main`, and delete the branch. Do not push.
