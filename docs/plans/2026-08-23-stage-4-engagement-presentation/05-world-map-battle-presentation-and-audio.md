# Step 5 — World Map, Battlefield, and Audio Presentation

**Branch:** `feat/stage-4-presentation`

**Depends on:** Step 4 merged; D9 acceptance observations approved; individual asset provenance approved before any asset intake

**Milestone:** The approved presentation standard is demonstrated on the actual World Map and Battlefield without changing the logical grid, tactical rules, or audio-bus topology.

## Files

- Create/Modify: `assets/art/placeholders/README.md` and only approved selected PNG assets beneath `assets/sprites/`.
- Modify: `scripts/presentation/sprite_catalog.gd`.
- Modify: `scripts/world/world_map.gd` and/or `scripts/battle/battle_controller.gd` only at existing drawing/feedback seams.
- Modify: `scenes/world/world_map.tscn`, `scenes/battle/battlefield.tscn`, `scenes/battle/floating_text.tscn`, and matching scene scripts only for an approved visual state/effect.
- Modify: `scripts/audio_manager.gd`, audio call sites, and `assets/audio/README.md` only for an approved event-to-cue gap; preserve `default_bus_layout.tres` topology.
- Modify: `tests/unit/test_sprite_catalog.gd`, `tests/unit/test_world_map_sprite_rendering.gd`, `tests/unit/test_battle_sprite_rendering.gd`, `tests/unit/test_world_map.gd`, `tests/unit/test_battlefield.gd`, `tests/unit/test_audio_manager.gd`, and/or `tests/unit/test_project_audio_contract.gd` according to the actual seam.

## Red/green tasks

1. Select only the approved D9 acceptance observations that still fail after Step 4. Separate visual identity/readability issues from feedback-timing/audio issues. Record the exact affected game state and expected persistent cue before modifying assets or draw code.
2. For every proposed raster asset, record in `assets/art/placeholders/README.md`: individual source-page URL, license, creator/package/version or date, original filename, destination path, and SHA-256. Verify the individual page license; do not treat “free” as CC0 and do not add ZIP archives.
3. Write the narrowest failing contract test first. For sprite work, test catalog lookup/fallback plus the renderer’s retained selection/facing/hover state; for feedback/audio, test the event-to-cue request and the existing Music/SFX bus contract. Run the relevant focused GUT file(s) and record red output.
4. Implement presentation-only changes: nearest-neighbour, bottom-anchored 3/4 sprites within the existing square cells; retain shadows, depth/order, text, selection/facing cues, click geometry, and 64px grid math. For audio, request the approved cue through `AudioManager` and preserve mute/volume behavior and required buses.
5. Add or retain a durable non-audio/non-colour-only indicator for hit/miss/critical/heal/retreat, target/mode, and wound results covered by the accepted observation. Do not make animation timing a prerequisite for a rule resolving.
6. Rerun focused tests, then execute:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: presentation contracts and all regression checks pass; campaign telemetry has no rules drift.
7. Capture the user-approved normal-scale screenshots/video/audio notes outside Git for the Encampment, World Map, and Battlefield states named in D9. Verify pointer targeting and movement manually; screenshot pixels alone do not prove interaction correctness.

## Manual check

In `make play`, verify the approved states in a real campaign: identify units/facing and selected/hovered target on both maps; switch Move/Attack only with the buttons; use right-click facing at no AP cost; observe hit/heal/retreat/wound feedback with audio on and off; and verify music transitions/volume/mute controls. Confirm the logical route/path and combat outcomes match the pre-presentation behavior.

## Commit and local merge

After user signoff, stage only licensed provenance, selected assets, their catalog/renderer/audio seams, and focused tests; commit `feat(presentation): meet Stage 4 readability standard`, merge locally to `main`, and delete `feat/stage-4-presentation`. Do not push or open a PR.
