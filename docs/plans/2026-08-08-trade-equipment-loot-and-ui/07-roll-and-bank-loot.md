# Task 07: Roll loot on encounter completion and bank it on deposit

## Objective

Replace the flat `expedition.reward` gold payout with per-kill loot rolls
(gold, a mana crystal, and a chance of gear), queued as pending state on
victory and moved into permanent state on deposit — mirroring the existing
`pending_reward` → `deposit_pending_reward()` flow exactly.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_first_campaign_ui_flow.gd`

## Depends on

Task 06 (`GameSession.ENEMY_LOOT_TABLES`, `loot_gold_roll`, `loot_gear_roll`,
`GEAR_DROP_CHANCE`).

## Produces

`GameSession.mana_crystals: Dictionary` (tier `int` → count `int`,
permanent/banked), `GameSession.banked_gear: Dictionary` (item id `String`
→ count `int`, permanent/banked), `GameSession.pending_mana_crystals:
Dictionary`, `GameSession.pending_gear: Array[String]` (unbanked, cleared by
`deposit_pending_reward()`). `complete_current_encounter()` no longer reads
`expedition.reward`; `EXPEDITIONS`' `"reward"` keys are removed.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_completing_the_goblin_camp_queues_gold_a_mana_crystal_and_no_gear_when_the_gear_roll_misses() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	session.loot_gear_roll = func() -> float: return 1.0
   	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

   	session.complete_current_encounter()

   	assert_eq(session.pending_reward, 1, "One goblin kill: randi_range(1, 6) stubbed to the min (1) times multiplier 1")
   	assert_eq(session.pending_mana_crystals, {1: 1}, "One goblin kill grants one tier-1 mana crystal")
   	assert_eq(session.pending_gear, [], "A gear roll of 1.0 must never clear the 25% drop chance")


   func test_completing_the_goblin_camp_queues_gear_when_the_gear_roll_hits() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	session.loot_gear_roll = func() -> float: return 0.0
   	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

   	session.complete_current_encounter()

   	assert_eq(session.pending_gear, ["shortsword_iron"], "A gear roll of 0.0 must always clear the 25% drop chance")


   func test_completing_the_orc_outpost_applies_the_documented_gold_multiplier() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	session.loot_gear_roll = func() -> float: return 1.0
   	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

   	session.complete_current_encounter()

   	assert_eq(session.pending_reward, 2, "One orc kill: randi_range(1, 5) stubbed to the min (1) times multiplier 2")
   	assert_eq(session.pending_mana_crystals, {2: 1}, "One orc kill grants one tier-2 mana crystal")


   func test_completing_a_two_kill_encounter_rolls_loot_once_per_kill() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	session.loot_gear_roll = func() -> float: return 0.0
   	session.enemy_composition_roll = func(_option_count: int) -> int: return 0
   	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

   	session.complete_current_encounter()

   	assert_eq(session.pending_reward, 2, "Two goblin kills: 1 gold each, multiplier 1")
   	assert_eq(session.pending_mana_crystals, {1: 2}, "Two goblin kills grant two tier-1 mana crystals")
   	assert_eq(session.pending_gear, ["shortsword_iron", "shortsword_iron"], "A guaranteed-hit gear roll fires once per kill")


   func test_deposit_pending_reward_banks_gold_mana_crystals_and_gear() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	session.loot_gear_roll = func() -> float: return 0.0
   	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
   	session.complete_current_encounter()

   	session.deposit_pending_reward()

   	assert_eq(session.gold, 1)
   	assert_eq(session.mana_crystals, {1: 1})
   	assert_eq(session.banked_gear, {"shortsword_iron": 1})
   	assert_eq(session.pending_mana_crystals, {})
   	assert_eq(session.pending_gear, [])


   func test_reset_clears_loot_state() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)
   	session.mana_crystals = {1: 3}
   	session.banked_gear = {"shortsword_iron": 2}
   	session.pending_mana_crystals = {1: 1}
   	session.pending_gear = ["dagger_iron"]

   	session.reset()

   	assert_eq(session.mana_crystals, {})
   	assert_eq(session.banked_gear, {})
   	assert_eq(session.pending_mana_crystals, {})
   	assert_eq(session.pending_gear, [])
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=completing_the_goblin_camp_queues -gexit
   ```

   (and the other new test names above). Expected: FAIL — `Invalid access
   to property or key 'mana_crystals'`, and `pending_reward` still comes
   from the flat `reward` field.

3. **Implement.** In `scripts/autoload/game_session.gd`, remove the
   `"reward": 10,` line from the `"goblin_camp"` entry and `"reward": 25,`
   from the `"orc_outpost"` entry in `EXPEDITIONS`.

   Add these vars next to `var pending_reward: int = 0:`

   ```gdscript
   var mana_crystals: Dictionary = {}
   var banked_gear: Dictionary = {}
   var pending_mana_crystals: Dictionary = {}
   var pending_gear: Array[String] = []
   ```

   In `reset()`, add next to `pending_reward = 0`:

   ```gdscript
   	mana_crystals = {}
   	banked_gear = {}
   	pending_mana_crystals = {}
   	pending_gear = []
   ```

   `complete_current_encounter()`'s own body is unchanged — it already calls
   a `_roll_and_queue_loot(expedition.get("enemy", {}))` helper; add that
   helper below it:

   ```gdscript
   ## Rolls loot once per kill in the resolved enemy composition (a battle can
   # only complete once every fielded enemy is dead, so "once per kill" and
   # "kill_count times at completion" are equivalent). A loot_id with no
   # ENEMY_LOOT_TABLES row (should not happen for a real expedition's enemy)
   # queues nothing rather than erroring.
   func _roll_and_queue_loot(enemy: Dictionary) -> void:
   	var loot_id: String = enemy.get("loot_id", "")
   	if not ENEMY_LOOT_TABLES.has(loot_id):
   		return
   	var table: Dictionary = ENEMY_LOOT_TABLES[loot_id]
   	var kill_count: int = enemy.get("count", 1)
   	for _kill in kill_count:
   		pending_reward += loot_gold_roll.call(table.gold_min, table.gold_max) * table.gold_multiplier
   		var crystal_tier: int = table.mana_crystal_tier
   		pending_mana_crystals[crystal_tier] = pending_mana_crystals.get(crystal_tier, 0) + 1
   		if loot_gear_roll.call() < GEAR_DROP_CHANCE:
   			pending_gear.append(table.gear_item_id)
   ```

   Replace `deposit_pending_reward()`:

   ```gdscript
   func deposit_pending_reward() -> int:
   	var deposited := pending_reward
   	gold += deposited
   	pending_reward = 0
   	return deposited
   ```

   with:

   ```gdscript
   func deposit_pending_reward() -> int:
   	var deposited := pending_reward
   	gold += deposited
   	pending_reward = 0
   	for tier in pending_mana_crystals:
   		mana_crystals[tier] = mana_crystals.get(tier, 0) + pending_mana_crystals[tier]
   	pending_mana_crystals = {}
   	for item_id in pending_gear:
   		banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
   	pending_gear = []
   	return deposited
   ```

4. **Run the new tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```

   Expected: the 6 new tests PASS; several pre-existing tests now FAIL
   (fixed in step 5-6 below) because they assert on the old flat-reward
   numbers (10/25/35), which the new roll-based system can no longer
   produce exactly (the old orc-outpost reward of 25 exceeds the new
   formula's max possible single-kill value of 5×2=10).

5. **Update the pre-existing reward-value tests in
   `tests/unit/test_game_session.gd`.** Each test below currently calls
   `complete_current_encounter()` without stubbing `loot_gold_roll`/
   `loot_gear_roll`, so its gold outcome is non-deterministic under the new
   system. Add the same two-line deterministic stub used in step 1
   (`loot_gold_roll` returns `min_value`, `loot_gear_roll` returns `1.0`)
   right after each test's `session.enter_encounter(...)` call (or, for the
   two tests without a `session` var, right after
   `var session: Node = GameSessionScript.new()` / before the first
   `enter_encounter`), and update the numeric assertions as shown:

   | Test function | Old assertion | New assertion (with the deterministic stub) |
   |---|---|---|
   | `test_get_expedition_returns_the_documented_goblin_camp_record` (~line 384) | `assert_eq(record.reward, 10)` | delete this line — `reward` no longer exists on the record |
   | `test_get_expedition_returns_the_documented_orc_outpost_record` (~line 398) | `assert_eq(record.reward, 25)` | delete this line |
   | `test_get_expedition_returns_a_record_that_can_be_mutated_without_affecting_the_catalog` (~line 511, 515) | `record.reward = 999` / `assert_eq(second_record.reward, 10, ...)` | replace both with `record.position = Vector2i(99, 99)` and `assert_eq(second_record.position, Vector2i(4, 4), "Mutating a returned record must not affect the catalog")` — same mutation-safety intent, using a field that still exists |
   | `test_completing_the_entered_goblin_camp_queues_its_reward_without_paying_gold` (~line 543-552) | `assert_eq(session.pending_reward, 10, "Victory should queue the goblin camp's fixed reward")` | stub the two rolls, then `assert_eq(session.pending_reward, 1, "Victory should queue the goblin camp's rolled reward")` |
   | `test_deposit_pending_reward_pays_once_then_returns_zero_on_a_second_call` (~line 555-570) | `assert_eq(deposited, 10)` / `assert_eq(session.gold, 10)` (twice) | stub the two rolls; `assert_eq(deposited, 1)` / `assert_eq(session.gold, 1)` (both occurrences) |
   | `test_chaining_two_victories_without_depositing_accumulates_both_rewards` (~line 573-588) | `assert_eq(session.pending_reward, 35, ...)` | stub the two rolls before the first `enter_encounter`; goblin (1) + orc (1×2=2) = `assert_eq(session.pending_reward, 3, "Both rewards should accumulate when banking happens after both victories")` |
   | `test_depositing_after_chained_victories_banks_the_combined_reward` (~line 591-603) | `assert_eq(deposited, 35)` / `assert_eq(session.gold, 35)` | stub the two rolls; `assert_eq(deposited, 3)` / `assert_eq(session.gold, 3)` |
   | `test_completing_an_already_completed_encounter_does_not_requeue_its_reward` (~line 606-621) | `assert_eq(session.gold, 10, ...)` | stub the two rolls; `assert_eq(session.gold, 1, "Gold already banked must be unaffected by re-completing a finished site")` |

   The remaining `complete_current_encounter()` calls in the file (the
   encounter-vacancy-timing block, roughly lines 1484-1810) assert only on
   encounter/vacancy mechanics, never on gold — leave those untouched; they
   will keep passing with the default (non-deterministic) loot rolls exactly
   as they do today with real `randf()`/`randi()`.

6. **Update `tests/unit/test_first_campaign_ui_flow.gd`.** This integration
   test drives a real battle through to completion and asserts exact gold
   values. Around line 98 (right after
   `battlefield.grid.hit_roll = func() -> float: return 0.0`), add:

   ```gdscript
   	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
   	GameSession.loot_gear_roll = func() -> float: return 1.0
   ```

   Then update the three affected assertions:

   ```gdscript
   # Line 121:
   	assert_eq(GameSession.pending_reward, 10, "The goblin camp's reward should be queued but not yet banked")
   # becomes:
   	assert_eq(GameSession.pending_reward, 1, "The goblin camp's rolled reward should be queued but not yet banked")

   # Line 138:
   	assert_eq(GameSession.gold, 10, "Returning to the encampment must bank the queued reward")
   # becomes:
   	assert_eq(GameSession.gold, 1, "Returning to the encampment must bank the queued reward")

   # Line 144:
   	assert_eq(information_panel.get_node("Content/Gold").text, tr("information.gold") % 10)
   # becomes:
   	assert_eq(information_panel.get_node("Content/Gold").text, tr("information.gold") % 1)
   ```

7. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

8. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd tests/unit/test_first_campaign_ui_flow.gd
   git commit -m "feat: roll per-kill loot on encounter completion instead of a flat reward"
   ```

## Milestone

Winning the Goblin Camp or Orc Outpost queues rolled gold, one mana crystal
per kill, and a 25%-per-kill chance of the enemy's Iron-tier weapon;
returning to the Encampment banks all three into permanent state; and the
whole suite (including the full click-through integration test) is green
under the new roll-based numbers.
