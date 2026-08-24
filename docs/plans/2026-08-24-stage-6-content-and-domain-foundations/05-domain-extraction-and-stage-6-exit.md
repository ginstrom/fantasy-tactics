# Step 5 — Domain Extraction and Stage 6 Exit Gate

**Branch:** `test/stage-6-foundations-exit`

**Depends on:** Steps 2–4 locally merged and manually signed off.

**Milestone:** `GameSession` is consolidated as a lean facade over extracted domain services, the complete fresh-campaign loop runs deterministically with multi-party carry and JSON content, and all legacy global loot and hardcoded encounter seams are eliminated.

## Files

- Create: `scripts/campaign/party_service.gd`, `scripts/campaign/encounter_service.gd`, `scripts/progression/progression_service.gd`.
- Modify: `scripts/autoload/game_session.gd`, `scripts/save/campaign_snapshot.gd`, and callers in `scripts/ui/`, `scripts/world/`, `scripts/battle/`, and `scripts/tools/` to use facade APIs.
- Test: create `tests/unit/test_stage_6_foundations.gd`; modify focused catalog, snapshot, campaign, World Map, battle, and scenario-runner tests.
- Modify: this plan's `index.md` and `decision-ledger.md` to record final evidence and deferred content.

## Red/green tasks

1. **Write failing end-to-end Stage 6 journey test (`tests/unit/test_stage_6_foundations.gd`):**
   - Start a fresh campaign.
   - Deploy two parties (`party_001`, `party_002`) to distinct locations.
   - Travel Party 1 to the JSON-authored encounter, initialize battle via `BattleContext` with catalog-defined spawns and cover.
   - Resolve victory, confirm loot enters `party_001.carry` while `party_002.carry` remains empty.
   - Level up an adventurer, select a branching perk from `PerkCatalog`, assert sibling exclusion, and verify combat effect via `PerkEffectResolver`.
   - Route Party 1 home and deposit carry to Encampment bank; verify Party 2 is still deployed with independent state.
   - Export and import a transactional `CampaignSnapshot` and assert zero state corruption.
2. **Run the journey test red:**
   - `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_stage_6_foundations.gd -gexit`
3. **Extract Pure Domain Services from `GameSession`:**
   - `PartyService` (`scripts/campaign/party_service.gd`):
     - Party creation, capacity limits, member assignment, deployment, movement consumption, in-field carry equipping, and carry deposit/forfeiture.
   - `EncounterService` (`scripts/campaign/encounter_service.gd`):
     - Active encounter instance management, vacancy countdowns, threat ratings, objective tracking, and catalog resolution.
   - `ProgressionService` (`scripts/progression/progression_service.gd`):
     - XP distribution, level-up thresholds, stat formulas, perk queries, and qualification checks.
4. **Refactor `GameSession` as a Lightweight Facade:**
   - Keep durable state dictionaries in `GameSession`.
   - Forward business logic calls to domain service singletons/helpers.
   - Remove redundant internal helpers and legacy constants.
5. **Verify Elimination of Legacy Seams:**
   - Confirm zero references to `pending_reward`, `pending_gear`, `pending_mana_crystals`, `battle_reward`, `battle_gear`, `battle_mana_crystals`.
   - Confirm migrated encounters no longer have fallbacks in `EXPEDITIONS` or `BattleController._cover_tiles_for_encounter()`.
6. **Run Full Verification Suite:**
   - Content lint test over all catalog files.
   - Fixed-seed scenario replay test.
   - `make campaign-sim`
   - `make check`
   - `godot --headless --path . --editor --quit`
   - `git diff --check`
7. **Update Decision Ledger:**
   - Record schema version, removed legacy seams, exact test output, and deferred Stage 7 items.

## Manual check

In `make play`:
1. Start a fresh game.
2. Form two separate parties and deploy both.
3. Complete an encounter with Party 1 and return to bank its carry.
4. Level up a party member and choose an exclusive branching perk.
5. Travel Party 2 to a different encounter and verify independent battle resolution.
6. Save the game, reload, and verify that all party inventories, world positions, objectives, and Encampment bank totals restore accurately.

## Commit and local merge

After user signoff, commit the domain service extractions, facade consolidation, and exit tests as `test(architecture): prove Stage 6 foundations`, merge locally to `main`, and delete the branch.
