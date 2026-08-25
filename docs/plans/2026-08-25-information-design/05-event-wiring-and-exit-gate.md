# Step 5: Event Wiring and Exit Gate

**Milestone:** Journal records live discovery, battle outcomes, queued loot,
and level-ups; the complete loop remains deterministic and visually clear.

**Depends on:** Steps 1-4 merged.

**Source contracts:** `docs/plans/2026-08-25-information-design.md`,
`scripts/autoload/game_session.gd`, `scripts/world/world_map.gd`,
`scripts/battle/battlefield.gd`, `scripts/ui/journal.gd`,
`scripts/tools/campaign_sim.gd`, `scripts/tools/battle_sim.gd`, and matching
unit tests.

**Files:** modify `scripts/autoload/game_session.gd`, `scripts/world/world_map.gd`,
`scripts/battle/battlefield.gd`, `tests/unit/test_game_session.gd`,
`tests/unit/test_world_map.gd`, `tests/unit/test_battlefield.gd`, and
`translations/en.tres`; modify `scripts/tools/battle_sim.gd` or
`scripts/tools/campaign_sim.gd` only if their modal-driving assumptions change.

1. Branch `feat/information-design-event-wiring`. Add failing tests proving
   each owner emits one correct record: durable encounter discovery, resolved
   battle, finalized queued loot, and a level-up. Assert a multi-level battle
   gives one battle record and one level-up record per member, never duplicates.
   Run affected focused GUT files red.
2. Append records at source-of-truth mutations: intelligence discovery, final
   battle result, reward queueing, and progression. Do not infer history in a
   view or append on refresh. Re-run focused tests green.
3. Add regression coverage that repeated signal delivery/refresh cannot create
   duplicate entries. Run `make campaign-sim` plus any targeted battle simulator
   route required by the modal flow; minimally update tooling to dismiss outcome
   and explicitly resolve selected level-ups.
4. Run `make check`, `godot --headless --path . --editor --quit`, `git diff
   --check`, and `make screenshots`. Inspect generated World Map and battle images.
5. Request review, then final manual `make play`: verify panels, one outcome
   modal, optional View level-ups, and chronological Log plus per-item/parent
   `!` acknowledgement. After signoff commit, merge locally, delete branch,
   and report evidence and the still-deferred accepted-quest behavior.
