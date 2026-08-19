# Step 1: Canonical Cleric Scenarios and Full-Triad Campaign Simulation

**Branch:** `fix/campaign-sim-cleric-coverage`  
**Depends on:** `main`  
**Milestone:** A deterministic headless campaign recruits and fields Warrior, Scout, and Cleric through `ScenarioContract` and `BattleStateFactory`; Cleric MP and spell actions are asserted.

## Setup

Read `docs/dev/README.md` and `docs/dev/testing.md`, then use the regular checkout (never a worktree):

```bash
git status --short --branch
git checkout main && git pull
git checkout -b fix/campaign-sim-cleric-coverage
make check
```

Preserve unrelated generated `.uid` files and the pre-existing `project.godot` edit; stage only files named in this step.

## Files

- Modify: `scripts/tools/battle_scenarios/scenario_contract.gd`
- Modify: `scripts/tools/battle_scenarios/battle_state_factory.gd`
- Modify: `scripts/tools/battle_bot.gd`
- Modify: `scripts/tools/campaign_sim.gd`
- Modify: `tests/unit/test_scenario_contract.gd`
- Modify: `tests/unit/test_battle_state_factory.gd`
- Modify: `tests/unit/test_battle_bot.gd`
- Modify: `tests/unit/test_campaign_sim.gd`

## TDD tasks

### Task 1: Permit Cleric in the scenario contract

1. Add a valid raw Cleric player scenario to `test_scenario_contract.gd`; assert normalization preserves `template_id: "cleric"` and validation succeeds. Keep an unknown-player-template rejection test.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_scenario_contract.gd -gexit
   ```

   Expected: the Cleric case fails because `KNOWN_PLAYER_TEMPLATES` omits it.
3. Add `"cleric"` to `ScenarioContract.KNOWN_PLAYER_TEMPLATES`; update its stale two-class comment.
4. Re-run the focused command. Expected: all selected tests pass.

### Task 2: Hydrate runtime-equivalent Cleric battle state

1. Add a factory test that builds a normalized Cleric scenario and asserts:
   - `spells` comes from `GameSession.CLASS_DEFINITIONS.cleric`;
   - `mp_max == 3` and `mp_remaining == 3`;
   - stats/equipment derive from the class/catalogue, not duplicated literals.
2. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_state_factory.gd -gexit`.

   Expected: failure because `_build_player_unit()` returns no spells or MP.
3. In `BattleStateFactory._build_player_unit()`, read spells and MP from the class definition. Non-spell classes retain empty spells/zero MP. Preserve existing per-iteration hit/crit/damage seed wiring.
4. Re-run the focused command. Expected: pass.

### Task 3: Give BattleBot a deterministic Cleric spell priority

1. Add bot tests with a wounded legal ally and an eligible unblessed legal ally. Assert the bot calls public `try_cast_spell("heal", target)` first when needed, otherwise `try_cast_spell("bless", target)`; assert 3 AP and 1 MP are consumed.
2. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_bot.gd -gexit`.

   Expected: failure because the bot only moves/attacks.
3. Before normal movement/attack, implement deterministic priority: lowest-health injured ally for Heal; otherwise highest-damage eligible ally for Bless; otherwise existing behavior. Return spell action records; never mutate health/status/AP/MP directly.
4. Re-run the focused command. Expected: pass.

### Task 4: Field and measure the full triad in CampaignSim

1. Add a campaign-sim test asserting a representative run fields one Warrior, Scout, and Cleric at three slots, records at least one Cleric spell action, and stays byte-identical for the same seed.
2. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit`.

   Expected: failure because `FIELDABLE_CLASSES` excludes Cleric.
3. Replace the two-class gate with the three root classes. Prioritize one of each before duplicate recruits while observing party capacity, offers, roster cap, and gold. Build player specs from actual party members via normalized `ScenarioContract` → `BattleStateFactory`; derive spell telemetry from bot action records.
4. Run all focused tests:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_scenario_contract.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_state_factory.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_bot.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit
   ```

### Task 5: Verify, sign off, commit, merge

1. Run `make check`, `git diff --check`, and `godot --headless --path . --editor --quit`.
2. Manual check with `make play`: build Temple, form the triad, verify Heal/Bless consume 1 MP/3 AP, and inspect simulation spell telemetry.
3. Stage only the files above, run `git diff --cached --check`, and commit:

   ```bash
   git add scripts/tools/battle_scenarios/scenario_contract.gd scripts/tools/battle_scenarios/battle_state_factory.gd scripts/tools/battle_bot.gd scripts/tools/campaign_sim.gd tests/unit/test_scenario_contract.gd tests/unit/test_battle_state_factory.gd tests/unit/test_battle_bot.gd tests/unit/test_campaign_sim.gd
   git diff --cached --check
   git commit -m "fix(sim): cover cleric in deterministic campaigns"
   ```

4. After user sign-off, merge locally and delete only this branch:

   ```bash
   git checkout main
   git merge fix/campaign-sim-cleric-coverage
   git branch -d fix/campaign-sim-cleric-coverage
   ```
