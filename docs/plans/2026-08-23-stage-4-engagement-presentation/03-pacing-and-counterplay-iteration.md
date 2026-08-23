# Step 3 — Pacing and Counterplay Iteration

**Status (2026-08-23): closed, no-op.** Step 2's baseline study (5/5
representative-seed victories, 1825/1825 tests, three-plus manual sessions)
surfaced zero pacing or dominant-strategy findings — the user reported "all
looks good" with nothing to prioritize. Per this step's own dependency
("Step 2 findings ranked and the user has approved the specific
finding(s)..."), there is no approved finding to act on, so no branch was
opened and no code changed. Re-open this step the moment a future baseline
or manual session surfaces a qualifying finding.

**Branch:** `feat/stage-4-pacing-iteration`

**Depends on:** Step 2 findings ranked and the user has approved the specific finding(s), success measure, and allowed values to change

**Milestone:** One bounded, evidence-backed pacing or dominant-strategy problem is corrected without weakening the complete-campaign proof or smuggling in Stage 5 systems.

## Files

- Modify: `config/game_config.json` for approved globally tunable values only.
- Modify: `scripts/game_config.gd` only if a new approved configuration key needs typed fallback access.
- Modify: `scripts/game_session.gd` only for an approved authored encounter/reward/progression rule that cannot be represented in existing config.
- Modify: `scripts/tools/campaign_sim.gd` or `scripts/tools/campaign_sim_metrics.gd` only when the approved success measure needs an existing-rules observation.
- Modify: `tests/unit/test_game_config.gd`, `tests/unit/test_game_session.gd`, and/or `tests/unit/test_campaign_sim.gd` to match the actual changed owner.
- Modify: `docs/designs/campaign-loop.md` when the user approves a durable balance contract change.

## Red/green tasks

1. Copy the selected Step 2 finding into the branch handoff with its record IDs, baseline values, player interpretation, exact expected improvement, and explicit non-goals. Reject the step if it requires an unapproved numeric value, new class/system, or a change to the representative seed set.
2. Choose the narrowest durable owner: `GameConfig` for a reusable tunable; the existing authored-objective data only for a node-specific composition/reward; `GameSession` only for an actual campaign rule. Do not compensate for a UI comprehension issue with hidden balance changes.
3. Write a focused failing test that demonstrates the selected defect and expected boundary. Examples: a config fallback/schema test, an authored objective’s exact composition/reward test, or a campaign-report threshold test derived from the approved measure. Run its owning GUT file and record the red result.
4. Make the minimal implementation. If configuration changes, update both `config/game_config.json` and the typed fallback in `GameConfig`; do not hard-code the new value in the simulator. If authored composition changes, preserve the stable objective ID, prerequisite, guaranteed discovery, and expected counterplay documentation.
5. Rerun the focused test green. Then execute:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: the selected approved measure improves or remains within its stated band; representative seeds remain 5/5; no unrelated contract changes.
6. Re-run one fresh manual campaign or the approved affected arc segment without developer intervention. Record the same checkpoints, compare it directly to the baseline record, and ask the user to accept/reject the observed trade-off.
7. If the finding persists, return to the recorded root cause and open a new bounded iteration; do not stack speculative balance changes onto this branch.

## Manual check

In `make play`, reproduce the original decision point, then play through its stated downstream consequence. Confirm the player can explain the changed choice and that no previously clear role/counterplay became opaque.

## Commit and local merge

After user signoff, stage only the selected owner, focused tests, and contract docs; commit `feat(campaign): address Stage 4 pacing finding <id>`, merge locally to `main`, and delete `feat/stage-4-pacing-iteration`. Do not push or open a PR.
