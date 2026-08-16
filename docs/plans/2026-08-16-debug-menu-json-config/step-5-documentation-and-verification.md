# Step 5: Authoring Guide and End-to-End Verification

## Objective

Document the debug-manifest contract, establish regression evidence, and obtain manual sign-off for the complete debug flow.

## Setup

```bash
git checkout main && git pull
git checkout -b docs/debug-scenario-manifest-guide
```

Read `docs/dev/running-the-game.md`, `docs/dev/testing.md`, the manifest, and every preceding plan step.

## Red / green work

1. Add failing documentation-oriented tests where practical: the shipped manifest parses, all listed baseline IDs load, every `name_key` resolves, and every embedded fixture passes the canonical snapshot import validation.
2. Run those focused tests and confirm red if the final manifest/docs links or coverage are missing.
3. Update `docs/dev/running-the-game.md` with: opening F9, reload behavior, the manifest schema, how to generate a fixture with `export_campaign_snapshot()`, supported launch scenes, and the last-known-good failure rule.
4. Document boundaries: snapshot fixtures are debug data; saves are written by `SaveRepository`; locations/encounter templates are authored content; custom battle fixtures are a deferred `ScenarioContract` adapter.
5. Update relevant README debug-scenario references, add translation coverage, and rerun focused tests.
6. Run `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`.

## Milestone and manual check

Using `make play`, verify all ten baseline scenarios, a valid hot reload, an invalid hot reload retaining the prior menu, and no reward mutation while launching World Map or Encampment fixtures. Capture screenshots only if the developer documentation’s screenshot workflow requires them.

## Handoff

After the user explicitly confirms the manual check, commit `docs: document debug scenario manifests`, merge `docs/debug-scenario-manifest-guide` locally into `main`, and delete the branch. Do not push or open a PR.
