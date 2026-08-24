# Step 1 — Stage 6 Contract and Baseline

**Branch:** `docs/stage-6-foundations-contract`

**Depends on:** Stage 5 Step 7 locally merged and manually signed off.

**Milestone:** The refactor starts from recorded post-Stage-5 evidence, all carry-forward decisions have an explicit disposition, and engineers have one approved target data/ownership contract rather than making piecemeal structural choices.

## Files

- Create: `docs/plans/2026-08-24-stage-6-content-and-domain-foundations/decision-ledger.md`.
- Modify: this plan's `index.md` only to record approvals/evidence.
- Inspect only: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`, `scripts/battle/battle_controller.gd`, `scripts/tools/campaign_sim.gd`, `scripts/tools/battle_scenarios/*.gd`, and the Stage 5 ledger.

## Red/green tasks

1. Record a clean `main` commit, `git status --short`, Stage 5 exit evidence, and the output of `make campaign-sim`, `make check`, headless editor scan, and `git diff --check` in the new ledger. Do not treat old Stage 5 numbers as current evidence.
2. Add a failing documentation-contract checklist that cannot be marked complete until G1–G4 have an approved/deferred disposition, including the accepted global-loot limitation from the Stage 5 ledger.
3. Run the checklist manually and record its expected failure for each undecided gate; obtain the user decisions. A deferred item remains deferred and is not silently folded into implementation.
4. Write the target contracts in the ledger:
    - `PartyCarry`: `{ "gold": int, "gear": Dictionary[String, int], "mana_crystals": Dictionary[String, int], "item_instance_ids": Array[String] }`. Carried directly on each party dictionary in `GameSession.parties`.
    - `BattleContext`: `{ "battle_id": String, "owner_party_id": String, "encounter_id": String, "reward": { "gold": int, "gear": Dictionary[String, int], "mana_crystals": Dictionary[String, int], "item_instance_ids": Array[String] }, "status": String ("active"|"victory"|"defeat"|"retreat"|"discarded"), "seed": int }`.
    - `ContentCatalog`: catalog manifest version, encounter schema (`id`, `title_key`, `world_position`, `grid_size`, `player_spawns`, `enemy_spawns`, `cover_tiles`, `enemy_composition`, `prerequisite_objective_id`, `reward_loot_table_id`), validation diagnostics, and immutable runtime copies.
    - `PerkDefinition`: `{ "id": String, "class_id": String, "tier": int, "prerequisite_ids": Array[String], "mutually_exclusive_with": Array[String], "rank_cap": int, "name_key": String, "description_key": String, "effect_descriptor": Dictionary }`.
    - `DomainServices`: target boundaries for `PartyService` (`scripts/campaign/party_service.gd`), `EncounterService` (`scripts/campaign/encounter_service.gd`), `ProgressionService` (`scripts/progression/progression_service.gd`), and `ContentCatalog` (`scripts/content/content_catalog.gd`), defining pure domain interfaces behind the `GameSession` facade.
5. State the playtest reset policy precisely: the first Stage 6 runtime change may reject/delete old save formats; new-format import must still be validated into scratch state before assignment. Record the manual instruction for players to start a fresh campaign after the reset.
6. Re-run the baseline commands and update the ledger/index. This step changes no runtime behavior.

## Manual check

Open the ledger with the user. Confirm the intended first JSON encounter, the first branching perk decision, whether Rogue is in scope, the party carry and battle context contracts, and that fresh-save-only behavior is acceptable before any runtime branch starts.

## Commit and local merge

After user signoff, commit only the Stage 6 plan/ledger evidence as `docs(architecture): define Stage 6 foundation contracts`, merge locally to `main`, and delete the branch.
