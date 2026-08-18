# Step 6: Headless Campaign Simulation and Balance Proof Harness

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/campaign-simulation-harness`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Build a comprehensive headless campaign-level simulation harness (`scripts/tools/campaign_sim.gd` and `campaign_sim_main.gd`) that drives entire campaign runs from a fresh save through the 12-battle authored ladder to Final Boss victory. Collect and validate progression telemetry (turns to victory, gold velocity, casualty rates, Encampment upgrade curves, and level curves). Add automated stress tests verifying recovery from worst-case setback states (such as zero-gold party wipes) to prove the campaign cannot be soft-locked.

---

## Technical Design

### 1. Headless Campaign Simulator (`scripts/tools/campaign_sim.gd`)
- Create `CampaignSim` extending `RefCounted`:
  - Drives full campaigns autonomously through `GameSession` and the same `ScenarioContract`/`BattleStateFactory` construction boundary used by authored battle coverage; `BattleBot` supplies only tactical policy.
  - Simulates the macro campaign loop:
    1. Recruit starter party (Warrior, Scout, Cleric).
    2. Deploy party on World Map and path to the active campaign objective encounter.
    3. Run tactical combat via `BattleBot` policy.
    4. Settle aftermath (loot banking, unit recovery, level-ups/perks, permadeath replacement if casualties occurred).
    5. Prioritize and purchase Encampment upgrades (Guild Hall, Temple, Shop, Blacksmith) as gold permits.
    6. Advance to the next objective until Final Boss victory or max turns exceeded.
- Injectable seed parameter `var sim_seed: int = 12345` for 100% reproducible deterministic campaign runs.

### 2. Campaign Telemetry & Metrics Aggregator (`scripts/tools/campaign_sim_metrics.gd`)
- Record key balance metrics across N simulated campaigns:
  - `total_world_turns`: Mean turns to victory (target: 40–60 turns).
  - `gold_velocity`: Cumulative gold earned, spent on upgrades, spent on recruits, and lost in wipes.
  - `upgrade_progression_turns`: World turn at which Guild Hall Tier 2/3, Temple, and Shop Tier 2/3 are acquired.
  - `party_level_curve`: Average party member level at Tier 1, Tier 2, Tier 3, and Boss (target: Level ~6 at Boss).
  - `battles_fought`, `battles_won`, `battles_retreated`, `party_wipes`, `unit_deaths`.

### 3. Rebuilding / Anti-Soft-Lock Automated Stress Tests (`tests/unit/test_campaign_recovery.gd`)
- Test worst-case setback scenarios:
  - **Zero-Gold Full Wipe at Tier 2:** Force all party units to die, empty gold and pending rewards to 0, advance world turns, confirm Shop passive income accrues, recruit affordable level 1 replacement, and prove path to victory remains open.
  - **Repeated Retreats:** Force 3 consecutive retreats with HP penalties, prove party recovers in Encampment without economic death spiral.

### 4. Makefile Target (`Makefile`)
- Add `make campaign-sim` target:
  ```makefile
  campaign-sim:
	$(GODOT) --headless -s scripts/tools/campaign_sim_main.gd --seed=42 --runs=10
  ```

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/campaign-simulation-harness
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **CampaignSim Execution Engine ([`tests/unit/test_campaign_sim.gd`](../../../tests/unit/test_campaign_sim.gd)):**
   - Test `CampaignSim.run_campaign(seed)` initializes a fresh session and advances through objectives.
   - Test `CampaignSim` handles party recruitment, movement, combat resolution, and returns to Encampment.
   - Test `CampaignSim` reaches victory on an explicitly listed representative seed set and reports failures for every other seed; do not claim a universal completion percentage from ten arbitrary samples.

2. **Metrics Collection & Verification ([`tests/unit/test_campaign_sim.gd`](../../../tests/unit/test_campaign_sim.gd)):**
   - Test telemetry records accurate battle counts, gold income, and level curves.
   - Test metric output generates formatted JSON and summary report.

3. **Anti-Soft-Lock Stress Scenarios ([`tests/unit/test_campaign_recovery.gd`](../../../tests/unit/test_campaign_recovery.gd)):**
   - Test recovery from 0 gold + 0 roster members: passive shop gold produces affordable recruit within 5 turns.
   - Test party rebuild reaches required combat power to clear Tier 1/2 objectives.

4. **Makefile Integration:**
   - Verify `make campaign-sim` runs headless without GUI errors and writes summary report.

---

## Verification

```bash
make check
make campaign-sim
```

Expected output: All unit tests pass. The simulator prints results for its documented representative seed set, every seed is reproducible from the report, and no run reaches a soft lock.

---

## Manual Verification (User Sign-off)

1. Run `make campaign-sim` from the terminal.
2. Review the printed simulation report:
   - Verify average victory turns fall within the 40–60 turn range.
   - Verify average party level at Final Boss is ~6.
   - Verify Guild Hall and Shop upgrades are attained before Boss engagement.
3. Perform a full manual playthrough from `make play` from a fresh game to the final victory screen, verifying smooth progression pacing.

---

## Commit and Merge

```bash
git status --short
git add scripts/tools/campaign_sim.gd scripts/tools/campaign_sim_main.gd scripts/tools/campaign_sim_metrics.gd Makefile tests/unit/test_campaign_sim.gd tests/unit/test_campaign_recovery.gd
git diff --cached --check
git commit -m "feat(tools): implement headless campaign simulation harness, telemetry, and anti-soft-lock proof tests"

# After user sign-off:
git checkout main
git merge feat/campaign-simulation-harness
git branch -d feat/campaign-simulation-harness
```

---

## Milestone (Concretely Verifiable)

- Headless campaign simulator completes full campaign runs from start to victory headlessly and deterministically.
- Anti-soft-lock test suite mathematically proves recovery from zero-gold wipes.
- `make check` and `make campaign-sim` pass 100% green.
