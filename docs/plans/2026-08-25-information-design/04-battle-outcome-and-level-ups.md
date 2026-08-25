# Step 4: Battle Outcome and Selected Level-Up Flow

**Milestone:** A completed battle shows one centered outcome modal; level-ups
are listed there and open only after player chooses View, then return to it.

**Depends on:** Step 3 merged.

**Source contracts:** `docs/plans/2026-08-25-information-design.md`,
`scripts/battle/battlefield.gd`, `scripts/ui/battle_result.gd`,
`scripts/ui/level_up.gd`, `scripts/autoload/game_manager.gd`, and
`tests/unit/test_battlefield.gd`.

**Files:** modify `scenes/battle/battlefield.tscn`,
`scripts/battle/battlefield.gd`, `scenes/ui/battle_result.tscn`,
`scripts/ui/battle_result.gd`, `scenes/ui/level_up.tscn`,
`scripts/ui/level_up.gd`, `scripts/autoload/game_manager.gd`,
`tests/unit/test_battlefield.gd`, and `translations/en.tres`; create
`tests/unit/test_battle_result.gd`.

1. Branch `feat/information-design-battle-modal`. Add a failing Battlefield
   test for two members leveling in one victory: board locks, one outcome modal
   appears, no level-up appears automatically, and summary names both. Run
   `-gselect=test_battlefield.gd` red.
2. Change only the post-victory state machine: XP/health remain applied once,
   but level-up presentation data enters the summary instead of the immediate
   queue. Keep input locked until outcome dismissal. Re-run focused test green.
3. Add failing result-modal tests for View per leveled adventurer, opening the
   selected level-up modal, required perk selection, and return to outcome.
   Run `-gselect=test_battle_result.gd` red.
4. Reuse Step 3's modal shell in Battlefield, make LevelUp owner-neutral, and
   retire the dedicated result route only after ordinary defeat and campaign
   victory branches are covered. Update simulator modal-driving assumptions if
   necessary. Re-run both focused files green.
5. Review, then manual `make play`: win with multiple level-ups, View one,
   resolve it, return to outcome, dismiss. After signoff commit, merge locally,
   delete branch, and hand off routing/tooling changes.
