# Debug Scenario Manifest and JSON Configuration

## Goal

Enable programmatic F9 debug-menu scenarios through a validated JSON manifest without creating a second campaign-save format. A scenario declares display and launch metadata plus a canonical campaign snapshot fixture; it never directly mutates `GameSession` field-by-field.

## Architecture and scope

`config/debug_scenarios.json` is a debug-only **manifest**, versioned independently from its embedded `campaign_snapshot`. `DebugScenarios` loads and validates the complete manifest before replacing its last-known-good cache. Applying a scenario delegates durable state validation and all-or-nothing assignment to `GameSession.import_campaign_snapshot()`.

The manifest's `launch.scene` controls where the already-configured session is viewed. Debug launch routing must not invoke normal reward-banking or encounter-entry transitions. The menu is a presentation layer over the loaded manifest only.

This first slice deliberately does **not** add arbitrary custom enemy definitions, direct `GameSession` battle overrides, or a new battle JSON schema. A later battle-launch adapter must reuse `ScenarioContract` and `BattleStateFactory`; it must not duplicate their unit, board, randomness, or modifier contract.

For the long-term game-content model, authored locations and encounter templates remain content definitions, live encounter instances reference those definitions, and `CampaignSnapshot` persists the live instances. Debug manifests compose those existing contracts; they do not become game-world content or save files.

## Manifest contract

```json
{
  "manifest_version": 1,
  "scenarios": [{
    "id": "party_ready",
    "name_key": "debug.party_ready",
    "category": "Campaign",
    "description": "One staffed party at the Encampment.",
    "launch": { "scene": "encampment" },
    "campaign_snapshot": { "version": 1 }
  }]
}
```

`campaign_snapshot` must be a complete JSON-safe `CampaignSnapshot` document, including every required durable field and `version`; the abbreviated example is illustrative only. Scenario authors obtain and edit a fixture from `GameSession.export_campaign_snapshot()`. The loader validates manifest metadata, then delegates snapshot validity to the canonical import path at apply time. Scenario IDs and category order retain their source-array order.

## Ordered steps

| Step | Plan file | Milestone |
|---|---|---|
| 1 | [step-1-versioned-manifest-loader.md](step-1-versioned-manifest-loader.md) | A complete manifest validates atomically; failed loads preserve the last-known-good cache and diagnostics. |
| 2 | [step-2-campaign-snapshot-fixtures.md](step-2-campaign-snapshot-fixtures.md) | The ten baseline scenarios become canonical snapshot fixtures and apply without partial mutation. |
| 3 | [step-3-side-effect-free-debug-launch.md](step-3-side-effect-free-debug-launch.md) | Valid scenarios reach their requested screen without reward or encounter transition side effects. |
| 4 | [step-4-dynamic-debug-menu-ui.md](step-4-dynamic-debug-menu-ui.md) | F9 renders categorized manifest scenarios and safely reloads valid edits. |
| 5 | [step-5-documentation-and-verification.md](step-5-documentation-and-verification.md) | Authoring documentation, regression evidence, and user manual sign-off are complete. |

## Acceptance criteria

- Invalid manifests, malformed snapshots, and failed hot reloads neither mutate `GameSession` nor discard the active manifest.
- Every existing baseline scenario remains available in its established display order and produces its approved exported campaign snapshot.
- Debug navigation itself does not deposit pending rewards, merge battle loot, or call `enter_encounter()`.
- Debug-only UI and entry points remain unavailable in non-debug builds.
- `make check`, `godot --headless --path . --editor --quit`, and `git diff --check` pass before user manual verification and the local-only merge.

## Workflow

Each step is implemented on the branch named in its own file using red/green TDD. After automated checks, the user verifies the stated `make play` path. Only after that sign-off, merge locally into `main` and delete the branch; do not push or open a PR.
