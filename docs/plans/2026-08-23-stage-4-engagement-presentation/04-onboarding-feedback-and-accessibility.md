# Step 4 — Onboarding, Feedback, and Accessibility

**Branch:** `feat/stage-4-clarity-feedback`

**Depends on:** Step 2 finding(s) approved; Step 3 merged when the issue affects a tuned player decision

**Milestone:** The highest-priority recorded comprehension or accessibility defect is repaired at its real UI/routing boundary and covered by a test that exercises actual scene signal wiring where relevant.

## Files

- Modify: `scenes/ui/party_manager.tscn`, `scenes/world/world_map.tscn`, `scenes/battle/battlefield.tscn`, or the relevant Encampment/Victory scene selected by the finding.
- Modify: matching `scripts/ui/*.gd`, `scripts/world/world_map.gd`, `scripts/battle/battlefield.gd`, `scripts/battle/battle_controller.gd`, or `scripts/battle/unit_info_panel.gd` selected by the finding.
- Modify: `translations/en.tres` for approved player-facing terminology.
- Modify: matching `tests/unit/test_*.gd`; use `tests/unit/test_first_campaign_ui_flow.gd` for an end-to-end New Game/objective/victory route.
- Modify: `docs/designs/campaign-loop.md`, `docs/designs/combat-system.md`, or `docs/dev/running-the-game.md` only when the user-approved observable contract changes.

## Red/green tasks

1. Turn the selected finding into one observable acceptance statement. It must name the screen, initial state, player action, visible/non-audio cue, and durable consequence. Examples are objective/next-unlock clarity, threat/recovery/retreat explanation, target/mode state, wound readability, or victory/free-play distinction.
2. Identify the owner from the existing code map and write a failing test at that boundary. Instantiate the real `.tscn` when validating a scene-wired signal or route; reset `GameSession`/touched `GameManager` state in `before_each`. Run only the owning test file first.
3. Implement the smallest UI, translation, or feedback repair. Keep durable state in `GameSession`, routing in `GameManager`, and rendering/intent in the scene script. Do not add keyboard shortcuts for Move/Attack; preserve WASD and right-click facing contracts.
4. Add a non-colour-only or non-audio-only cue when the selected result is gameplay-critical. Preserve existing labels/icons/logs rather than replacing the only cue with a transient effect.
5. Rerun the focused tests green, then run:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: all pass; deterministic campaign results are unchanged unless Step 3 explicitly changed a documented pacing value.
6. Use `make play` to capture before/after evidence at the selected checkpoint. Have a fresh observer or the user describe the state before being told the expected answer; record the result in the finding ledger.

## Manual check

Start from New Game and navigate to the affected screen without debug shortcuts. Confirm that the specified state and its consequence are understandable at normal play scale, including with the relevant audio/colour assistance disabled.

## Commit and local merge

After user signoff, stage only files for the selected finding and its tests/docs; commit `feat(ui): clarify Stage 4 finding <id>`, merge locally to `main`, and delete `feat/stage-4-clarity-feedback`. Do not push or open a PR.
