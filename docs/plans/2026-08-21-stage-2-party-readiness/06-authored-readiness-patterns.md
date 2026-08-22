# Step 6 — Authored Readiness Patterns

**Branch:** `feat/stage-2-authored-readiness-patterns`
**Depends on:** Step 5 merged
**Milestone:** The authored Tier 1–3 objectives require the documented formation/loot, Scout/ranged/gear, and mixed-force priority decisions using only the smallest necessary variants and AI.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/tools/battle_scenarios/scenario_contract.gd`
- Modify: `scripts/tools/battle_scenarios/battle_state_factory.gd`
- Modify: `scripts/tools/campaign_sim.gd`
- Modify: `config/campaign_scenarios.json`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_ranged_enemy_ai.gd`
- Modify: `tests/unit/test_battle_state_factory.gd`
- Modify: `tests/unit/test_campaign_sim.gd`
- Modify: `docs/designs/monster-manual.md`

## Red/green tasks

1. Turn each roadmap pattern into a named acceptance fixture tied to the existing authored objective IDs:
   - Tier 1: formation and return/bank-loot decision;
   - Tier 2: Scout intel, ranged pressure, armour/resistance, and potion use;
   - Tier 3: mixed-force target priority.
2. Write failing tests first for exact composition, profile values, reward/aftermath boundary, and the minimum AI behavior each pattern needs. Reuse existing variants/AI where sufficient; add a new template/behavior only when a pattern’s test cannot be expressed otherwise.
3. Seed every battle through `ScenarioContract` and `BattleStateFactory`; configure campaign runs through the existing `CampaignSim`, not direct arrays or a new balance simulator.
4. Implement the smallest composition/AI/configuration adjustment that turns the red test green. Every intentional balance adjustment must update the Stage 2 approved table and Monster Manual comparison evidence.
5. Run the focused suites and `make campaign-sim`. Preserve the documented representative seed set; label any broader sweep exploratory only.
6. Finish with `make check`, editor scan, and `git diff --check`.

## Manual signoff and merge

Use `make play` from a fresh campaign to prepare for and play one objective in each tier. Explain which decision the formation, Scout, Cleric, gear/potion, and target priority changed. If an encounter is merely numerically harder without that decision being legible, return to this step rather than adding content. After user signoff, commit `feat(campaign): tune stage two readiness patterns`, merge locally, and delete the branch.
