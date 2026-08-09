# Step 1: Battle Loot Store

**Branch:** `battle-loot-store`

Read `../2026-08-10-battle-loot-store/index.md` first — the design decisions
there aren't repeated in full here.

---

## Task 1: Add the battle store fields and the shared merge helper

Purely additive — nothing existing changes behavior yet. `make check` must
stay green with zero test edits beyond the two listed below.

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces produced (Task 2 depends on these):**
- `var battle_gear: Dictionary`, `var battle_mana_crystals: Dictionary`,
  `var battle_reward: int` — same shape as `pending_gear`/`pending_mana_
  crystals`/`pending_reward`.
- `func merge_battle_loot_into_party() -> void` — merges `battle_*` into
  `pending_*`, then clears `battle_*`.

- [ ] **Step 1: Add the three new fields**

In `scripts/autoload/game_session.gd`, find:

```gdscript
var pending_gear: Dictionary = {}
var has_trading_post: bool = false
```

Replace with:

```gdscript
var pending_gear: Dictionary = {}
var battle_reward: int = 0
var battle_mana_crystals: Dictionary = {}
var battle_gear: Dictionary = {}
var has_trading_post: bool = false
```

- [ ] **Step 2: Clear the new fields in `reset()`**

Find:

```gdscript
	pending_gear = {}
	has_trading_post = false
```

Replace with:

```gdscript
	pending_gear = {}
	battle_reward = 0
	battle_mana_crystals = {}
	battle_gear = {}
	has_trading_post = false
```

- [ ] **Step 3: Write the failing tests for `reset()` covering the new fields**

In `tests/unit/test_game_session.gd`, find `test_reset_clears_gold_and_
pending_reward`:

```gdscript
func test_reset_clears_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 5
	session.pending_reward = 5

	session.reset()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
```

Replace with:

```gdscript
func test_reset_clears_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 5
	session.pending_reward = 5
	session.battle_reward = 5

	session.reset()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_eq(session.battle_reward, 0)
```

Find `test_reset_clears_loot_state`:

```gdscript
func test_reset_clears_loot_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.mana_crystals = {1: 3}
	session.banked_gear = {"shortsword_iron": 2}
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"dagger_iron": 1}

	session.reset()

	assert_eq(session.mana_crystals, {})
	assert_eq(session.banked_gear, {})
	assert_eq(session.pending_mana_crystals, {})
	assert_eq(session.pending_gear, {})
```

Replace with:

```gdscript
func test_reset_clears_loot_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.mana_crystals = {1: 3}
	session.banked_gear = {"shortsword_iron": 2}
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"dagger_iron": 1}
	session.battle_mana_crystals = {1: 1}
	session.battle_gear = {"dagger_iron": 1}

	session.reset()

	assert_eq(session.mana_crystals, {})
	assert_eq(session.banked_gear, {})
	assert_eq(session.pending_mana_crystals, {})
	assert_eq(session.pending_gear, {})
	assert_eq(session.battle_mana_crystals, {})
	assert_eq(session.battle_gear, {})
```

- [ ] **Step 4: Run the tests to verify the reset assertions pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit`

Expected: PASS (the fields already exist from Steps 1-2, so this is a sanity
check, not a red/green cycle).

- [ ] **Step 5: Add the shared merge helper and `merge_battle_loot_into_party()`**

In `scripts/autoload/game_session.gd`, find:

```gdscript
func abandon_current_encounter() -> void:
	selected_encounter = ""


func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	for tier in pending_mana_crystals:
		mana_crystals[tier] = mana_crystals.get(tier, 0) + pending_mana_crystals[tier]
	pending_mana_crystals = {}
	for item_id in pending_gear:
		banked_gear[item_id] = banked_gear.get(item_id, 0) + pending_gear[item_id]
	pending_gear = {}
	return deposited
```

Replace with:

```gdscript
func abandon_current_encounter() -> void:
	selected_encounter = ""


## Adds every count in source into dest in place -- both id/tier -> count
## Dictionaries sharing the exact shape battle_gear/pending_gear/banked_gear
## (and their mana-crystal counterparts) all use. The one function shared by
## both loot-store merges: battle -> party (merge_battle_loot_into_party())
## and party -> encampment (deposit_pending_reward()).
func _merge_counts(source: Dictionary, dest: Dictionary) -> void:
	for key in source:
		dest[key] = dest.get(key, 0) + source[key]


## Merges this battle's own loot store into the party's carried store. Called
## once the player leaves the victory summary screen for the World Map (see
## GameManager.go_to_world_map()) -- a no-op if the battle store is already
## empty, e.g. when go_to_world_map() is reached from anywhere other than
## straight out of a battle.
func merge_battle_loot_into_party() -> void:
	pending_reward += battle_reward
	battle_reward = 0
	_merge_counts(battle_gear, pending_gear)
	_merge_counts(battle_mana_crystals, pending_mana_crystals)
	battle_gear = {}
	battle_mana_crystals = {}


## Merges the party's carried store into the Encampment's bank -- the other
## half of the shared _merge_counts() pair (see merge_battle_loot_into_
## party() for the battle -> party merge).
func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	_merge_counts(pending_gear, banked_gear)
	_merge_counts(pending_mana_crystals, mana_crystals)
	pending_gear = {}
	pending_mana_crystals = {}
	return deposited
```

- [ ] **Step 6: Run the existing deposit tests to verify the refactor is behavior-preserving**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit`

Expected: PASS — `test_deposit_pending_reward_pays_once_then_returns_zero_
on_a_second_call`, `test_depositing_after_chained_victories_banks_the_
combined_reward`, and `test_deposit_pending_reward_banks_gold_mana_
crystals_and_gear` must all still pass unchanged, since `_merge_counts()`
is behaviorally identical to the loops it replaced.

- [ ] **Step 7: Write the failing tests for `merge_battle_loot_into_party()`**

In `tests/unit/test_game_session.gd`, find `test_deposit_pending_reward_
banks_gold_mana_crystals_and_gear` (ends with `assert_eq(session.pending_
gear, {})`) and insert these two new tests immediately after it, before
`test_reset_clears_loot_state`:

```gdscript
func test_merge_battle_loot_into_party_moves_the_battle_store_into_the_partys_own() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_reward = 5
	session.battle_mana_crystals = {1: 2}
	session.battle_gear = {"dagger_iron": 1}
	session.pending_reward = 10
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"buckler_wood": 1}

	session.merge_battle_loot_into_party()

	assert_eq(session.pending_reward, 15)
	assert_eq(session.pending_mana_crystals, {1: 3})
	assert_eq(session.pending_gear, {"dagger_iron": 1, "buckler_wood": 1})
	assert_eq(session.battle_reward, 0)
	assert_eq(session.battle_mana_crystals, {})
	assert_eq(session.battle_gear, {})


func test_merge_battle_loot_into_party_is_a_no_op_when_the_battle_store_is_empty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.pending_reward = 10
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"buckler_wood": 1}

	session.merge_battle_loot_into_party()

	assert_eq(session.pending_reward, 10)
	assert_eq(session.pending_mana_crystals, {1: 1})
	assert_eq(session.pending_gear, {"buckler_wood": 1})
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit`

Expected: PASS (the implementation already exists from Step 5).

- [ ] **Step 9: Run the full suite and commit**

Run: `make check`

Expected: all green, no regressions anywhere (Task 1 changed no existing
behavior).

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add the battle loot store and a shared store-merge helper"
```

---

## Task 2: Rewire loot-rolling into the battle store, merge it at `go_to_world_map()`

This is the one atomic behavior change: loot now lands in `battle_*`
instead of `pending_*`, and moves to `pending_*` only when the player
leaves the victory summary for the World Map. Every file below must land
together — `make check` will not be green until all of them do.

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/ui/battle_result.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_first_campaign_ui_flow.gd`

### Production code

- [ ] **Step 1: Point loot-rolling at the battle store**

In `scripts/autoload/game_session.gd`, find:

```gdscript
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
			pending_gear[table.gear_item_id] = pending_gear.get(table.gear_item_id, 0) + 1
```

Replace with:

```gdscript
func _roll_and_queue_loot(enemy: Dictionary) -> void:
	var loot_id: String = enemy.get("loot_id", "")
	if not ENEMY_LOOT_TABLES.has(loot_id):
		return
	var table: Dictionary = ENEMY_LOOT_TABLES[loot_id]
	var kill_count: int = enemy.get("count", 1)
	for _kill in kill_count:
		battle_reward += loot_gold_roll.call(table.gold_min, table.gold_max) * table.gold_multiplier
		var crystal_tier: int = table.mana_crystal_tier
		battle_mana_crystals[crystal_tier] = battle_mana_crystals.get(crystal_tier, 0) + 1
		if loot_gear_roll.call() < GEAR_DROP_CHANCE:
			battle_gear[table.gear_item_id] = battle_gear.get(table.gear_item_id, 0) + 1
```

Find, in `complete_current_encounter()`:

```gdscript
		_roll_and_queue_loot(expedition.get("enemy", {}))
		pending_reward += loot_gold_roll.call(0, 5) * int(expedition.get("difficulty", 1))
```

Replace with:

```gdscript
		_roll_and_queue_loot(expedition.get("enemy", {}))
		battle_reward += loot_gold_roll.call(0, 5) * int(expedition.get("difficulty", 1))
```

- [ ] **Step 2: Update the stale `build_loot_rows()` docstring**

Find:

```gdscript
## The shared loot-row shape (id/name/type/count/price) every loot-listing
## screen renders through LootTable — Stores (banked_gear/mana_crystals),
## the victory summary, and the World Map's Party Details screen
## (pending_gear/pending_mana_crystals), each backed by a different pair of
## GameSession fields but sharing this exact row shape and this exact
## pricing/naming logic.
```

Replace with:

```gdscript
## The shared loot-row shape (id/name/type/count/price) every loot-listing
## screen renders through LootTable — Stores (banked_gear/mana_crystals),
## the victory summary (battle_gear/battle_mana_crystals), and the World
## Map's Party Details screen (pending_gear/pending_mana_crystals), each
## backed by a different pair of GameSession fields but sharing this exact
## row shape and this exact pricing/naming logic.
```

- [ ] **Step 3: Merge the battle store into the party store on the way to the World Map**

In `scripts/autoload/game_manager.gd`, find:

```gdscript
func go_to_world_map() -> Error:
	_clear_detail_context()
	return _change_scene(WORLD_MAP_SCENE)
```

Replace with:

```gdscript
## Merges the battle store into the party's own store before ever showing
## the World Map -- see GameSession.merge_battle_loot_into_party(). This is
## the single call site both the real "leave the victory summary" path
## (battle_result.gd's OK button) and the screenshot-tour shortcut
## (complete_battle()) route through, so the merge lives here rather than
## in battle_result.gd itself.
func go_to_world_map() -> Error:
	GameSession.merge_battle_loot_into_party()
	_clear_detail_context()
	return _change_scene(WORLD_MAP_SCENE)
```

- [ ] **Step 4: Read the battle store directly in `_finish_victory()`, delete the delta helper**

In `scripts/battle/battlefield.gd`, find:

```gdscript
## Rolls this battle's loot into GameSession's pending_* fields (see
## GameSession.complete_current_encounter() -> _roll_and_queue_loot()) and
## routes to the victory summary screen with everything this battle
## accumulated. Unlike GameManager.complete_battle() (still used by
## scripts/tools/screenshot_tour.gd to skip straight to the World Map),
## this is the real gameplay path -- it shows the summary before the
## player ever reaches the World Map.
func _finish_victory() -> void:
	var gold_before: int = GameSession.pending_reward
	var mana_crystal_counts_before: Dictionary = GameSession.pending_mana_crystals.duplicate()
	var gear_counts_before: Dictionary = GameSession.pending_gear.duplicate()

	GameSession.complete_current_encounter()

	var party := GameSession.get_party(GameSession.selected_party_id)
	var summary := {
		"kills_by_type": _kills_by_type,
		"total_xp": _total_xp_awarded,
		"party_member_count": maxi(party.get("member_ids", []).size(), 1),
		"leveled_up_ids": _leveled_up_ids,
		# This battle's own loot only, not the party's full pending_* totals --
		# those accumulate across every encounter cleared before returning to
		# the settlement, but this summary screen is titled for just this
		# battle (see battle_result.gd).
		"loot_gold": GameSession.pending_reward - gold_before,
		"loot_mana_crystal_counts": _dict_counts_delta(mana_crystal_counts_before, GameSession.pending_mana_crystals),
		"loot_gear_counts": _dict_counts_delta(gear_counts_before, GameSession.pending_gear),
	}
	GameManager.go_to_battle_result(summary)


## Computes this battle's own additions to a pending_* counts dict as a
## before/after delta. pending_mana_crystals (tier -> count) and
## pending_gear (item id -> count) now share this exact shape, so one
## helper covers both -- see GameSession.pending_gear's docstring for why
## it moved from an Array to this Dictionary shape.
func _dict_counts_delta(counts_before: Dictionary, counts_after: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for key in counts_after:
		var gained: int = counts_after[key] - counts_before.get(key, 0)
		if gained > 0:
			delta[key] = gained
	return delta
```

Replace with:

```gdscript
## Rolls this battle's loot into GameSession's battle_* store (see
## GameSession.complete_current_encounter() -> _roll_and_queue_loot()) and
## routes to the victory summary screen with everything this battle
## accumulated. The battle store stays separate from the party's own
## pending_* store until the player leaves this summary screen for the
## World Map (see GameManager.go_to_world_map() -> GameSession.merge_
## battle_loot_into_party()) -- including via GameManager.complete_battle()
## (still used by scripts/tools/screenshot_tour.gd to skip straight to the
## World Map), which also routes through go_to_world_map() and so also
## merges correctly.
func _finish_victory() -> void:
	GameSession.complete_current_encounter()

	var party := GameSession.get_party(GameSession.selected_party_id)
	var summary := {
		"kills_by_type": _kills_by_type,
		"total_xp": _total_xp_awarded,
		"party_member_count": maxi(party.get("member_ids", []).size(), 1),
		"leveled_up_ids": _leveled_up_ids,
		# Read straight from the battle store -- this battle's own loot only,
		# never merged into the party's full running totals until the player
		# leaves this screen (see the docstring above).
		"loot_gold": GameSession.battle_reward,
		"loot_mana_crystal_counts": GameSession.battle_mana_crystals.duplicate(),
		"loot_gear_counts": GameSession.battle_gear.duplicate(),
	}
	GameManager.go_to_battle_result(summary)
```

- [ ] **Step 5: Update the stale docstring in `battle_result.gd`**

In `scripts/ui/battle_result.gd`, find:

```gdscript
## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is part of
## that summary dict ("loot_gold" plus the itemized
## "loot_gear_counts"/"loot_mana_crystal_counts") -- reading
## GameSession.pending_reward/pending_mana_crystals/pending_gear directly
## would show every encounter a deployed party has cleared so far this
## deployment, not just this battle's own loot (see _finish_victory()'s
## before/after delta). The gear/mana-crystal table reuses LootTable, but
## purely as a read-only record: no [Sell] (loot only sells once banked
## at the Encampment) and no [Equip] either -- this is a frozen snapshot
## of what this battle dropped, taken once and never re-read, so letting
## the player mutate live state (GameSession.pending_gear) through it
## would silently desync the two. Equipping happens once the party is
## back on the World Map (Party Details, which reads pending_gear live).
```

Replace with:

```gdscript
## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is part of
## that summary dict ("loot_gold" plus the itemized
## "loot_gear_counts"/"loot_mana_crystal_counts") -- reading
## GameSession.pending_reward/pending_mana_crystals/pending_gear directly
## would show the party's full running totals for the deployment, not just
## this battle's own loot; the summary instead carries a snapshot of
## GameSession's battle_reward/battle_mana_crystals/battle_gear (the battle
## store -- see GameSession.merge_battle_loot_into_party()), which holds
## only this battle's own drops until the player leaves this screen. The
## gear/mana-crystal table reuses LootTable, but purely as a read-only
## record: no [Sell] (loot only sells once banked at the Encampment) and no
## [Equip] either -- this is a frozen snapshot, taken once and never
## re-read, so letting the player mutate live state through it would
## silently desync the two. Equipping happens once the party is back on the
## World Map (Party Details, which reads pending_gear live, after the
## battle store has already merged into it).
```

### Test updates

- [ ] **Step 6: Update `tests/unit/test_game_session.gd`'s direct loot-roll assertions**

Each edit below targets one existing test by name. Apply them all, then run
the suite once at the end (Step 9) rather than after each one.

`test_completing_the_entered_goblin_camp_queues_its_reward_without_paying_gold`:

```gdscript
	session.complete_current_encounter()

	assert_eq(session.pending_reward, 1, "Victory should queue the goblin camp's rolled reward")
	assert_eq(session.gold, 0, "Completing an encounter must not bank gold directly")
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))
```

becomes:

```gdscript
	session.complete_current_encounter()

	assert_eq(session.battle_reward, 1, "Victory should queue the goblin camp's rolled reward in the battle store")
	assert_eq(session.gold, 0, "Completing an encounter must not bank gold directly")
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))
```

`test_deposit_pending_reward_pays_once_then_returns_zero_on_a_second_call`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	var deposited: int = session.deposit_pending_reward()
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	var deposited: int = session.deposit_pending_reward()
```

(the rest of that test is unchanged)

`test_chaining_two_victories_without_depositing_accumulates_both_rewards`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	assert_eq(
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	assert_eq(
```

`test_depositing_after_chained_victories_banks_the_combined_reward`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)
	session.complete_current_encounter()

	var deposited: int = session.deposit_pending_reward()
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	var deposited: int = session.deposit_pending_reward()
```

`test_completing_an_already_completed_encounter_does_not_requeue_its_reward`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.pending_reward,
		0,
		"Re-completing an already-completed site must not requeue its reward"
	)
	assert_eq(session.gold, 1, "Gold already banked must be unaffected by re-completing a finished site")
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.battle_reward,
		0,
		"Re-completing an already-completed site must not requeue its reward"
	)
	assert_eq(session.gold, 1, "Gold already banked must be unaffected by re-completing a finished site")
```

`test_completing_the_goblin_camp_queues_gold_a_mana_crystal_and_no_gear_when_the_gear_roll_misses`:

```gdscript
	session.complete_current_encounter()

	assert_eq(session.pending_reward, 1, "One goblin kill: randi_range(1, 6) stubbed to the min (1) times multiplier 1")
	assert_eq(session.pending_mana_crystals, {1: 1}, "One goblin kill grants one tier-1 mana crystal")
	assert_eq(session.pending_gear, {}, "A gear roll of 1.0 must never clear the 25% drop chance")
```

becomes:

```gdscript
	session.complete_current_encounter()

	assert_eq(session.battle_reward, 1, "One goblin kill: randi_range(1, 6) stubbed to the min (1) times multiplier 1")
	assert_eq(session.battle_mana_crystals, {1: 1}, "One goblin kill grants one tier-1 mana crystal")
	assert_eq(session.battle_gear, {}, "A gear roll of 1.0 must never clear the 25% drop chance")
```

`test_completing_the_goblin_camp_queues_gear_when_the_gear_roll_hits`:

```gdscript
	assert_eq(session.pending_gear, {"shortsword_iron": 1}, "A gear roll of 0.0 must always clear the 25% drop chance")
```

becomes:

```gdscript
	assert_eq(session.battle_gear, {"shortsword_iron": 1}, "A gear roll of 0.0 must always clear the 25% drop chance")
```

`test_completing_the_orc_outpost_applies_the_documented_gold_multiplier`:

```gdscript
	assert_eq(session.pending_reward, 2, "One orc kill: randi_range(1, 5) stubbed to the min (1) times multiplier 2")
	assert_eq(session.pending_mana_crystals, {2: 1}, "One orc kill grants one tier-2 mana crystal")
```

becomes:

```gdscript
	assert_eq(session.battle_reward, 2, "One orc kill: randi_range(1, 5) stubbed to the min (1) times multiplier 2")
	assert_eq(session.battle_mana_crystals, {2: 1}, "One orc kill grants one tier-2 mana crystal")
```

`test_completing_a_two_kill_encounter_rolls_loot_once_per_kill`:

```gdscript
	assert_eq(session.pending_reward, 2, "Two goblin kills: 1 gold each, multiplier 1")
	assert_eq(session.pending_mana_crystals, {1: 2}, "Two goblin kills grant two tier-1 mana crystals")
	assert_eq(session.pending_gear, {"shortsword_iron": 2}, "A guaranteed-hit gear roll fires once per kill")
```

becomes:

```gdscript
	assert_eq(session.battle_reward, 2, "Two goblin kills: 1 gold each, multiplier 1")
	assert_eq(session.battle_mana_crystals, {1: 2}, "Two goblin kills grant two tier-1 mana crystals")
	assert_eq(session.battle_gear, {"shortsword_iron": 2}, "A guaranteed-hit gear roll fires once per kill")
```

`test_completing_an_encounter_adds_a_gold_bonus_scaled_by_star_difficulty`:

```gdscript
	assert_eq(session.pending_reward, 20, "Kill gold (10) plus the encounter bonus (10) at 2-star difficulty")
```

becomes:

```gdscript
	assert_eq(session.battle_reward, 20, "Kill gold (10) plus the encounter bonus (10) at 2-star difficulty")
```

`test_recompleting_an_already_completed_encounter_does_not_requeue_the_bonus`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.pending_reward, 0,
		"Re-completing an already-completed site must not requeue its gold bonus either"
	)
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.battle_reward, 0,
		"Re-completing an already-completed site must not requeue its gold bonus either"
	)
```

`test_deposit_pending_reward_banks_gold_mana_crystals_and_gear`:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	session.deposit_pending_reward()
```

becomes:

```gdscript
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	session.deposit_pending_reward()
```

(the rest of that test, including its assertions, is unchanged)

`test_abandoning_the_entered_orc_outpost_leaves_zero_gold_and_pending_reward`:

```gdscript
	session.abandon_current_encounter()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_false(session.is_encounter_complete(GameSessionScript.ORC_OUTPOST_ID), "Abandoning must leave the site retryable")
```

becomes:

```gdscript
	session.abandon_current_encounter()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_eq(session.battle_reward, 0)
	assert_false(session.is_encounter_complete(GameSessionScript.ORC_OUTPOST_ID), "Abandoning must leave the site retryable")
```

- [ ] **Step 7: Update `tests/unit/test_game_manager.gd`**

Find `test_return_party_to_encampment_returns_party_and_deposits_reward`
(ends `assert_eq(GameSession.gold, 15, ...)`) and insert this new test
immediately after it:

```gdscript
func test_go_to_world_map_merges_the_battle_store_into_the_party_store() -> void:
	GameSession.reset()
	GameSession.battle_reward = 5
	GameSession.battle_mana_crystals = {1: 1}
	GameSession.battle_gear = {"dagger_iron": 1}
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_world_map()

	assert_eq(GameSession.pending_reward, 5)
	assert_eq(GameSession.pending_mana_crystals, {1: 1})
	assert_eq(GameSession.pending_gear, {"dagger_iron": 1})
	assert_eq(GameSession.battle_reward, 0)
	assert_eq(GameSession.battle_mana_crystals, {})
	assert_eq(GameSession.battle_gear, {})
```

Find `test_go_to_encampment_deposits_pending_gold_once`:

```gdscript
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()
```

becomes:

```gdscript
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.go_to_world_map()

	manager.go_to_encampment()
```

(the rest of that test, including its assertions, is unchanged — they were
already checking post-merge state)

Find `test_go_to_encampment_does_not_bank_the_reward_while_the_party_is_still_deployed`:

```gdscript
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var queued_reward: int = GameSession.pending_reward
	assert_true(queued_reward > 0, "Test setup must actually queue a reward")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 0, "Gold must not be banked while the party is still deployed away from home")
	assert_eq(
		GameSession.pending_reward, queued_reward,
		"The queued reward must remain untouched until the party actually returns"
	)
```

becomes:

```gdscript
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var queued_reward: int = GameSession.battle_reward
	assert_true(queued_reward > 0, "Test setup must actually queue a reward")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 0, "Gold must not be banked while the party is still deployed away from home")
	assert_eq(
		GameSession.battle_reward, queued_reward,
		"The queued reward must remain untouched until the party actually returns"
	)
```

- [ ] **Step 8: Update `tests/unit/test_battlefield.gd`**

Find `test_apply_battle_outcome_true_completes_the_encounter`:

```gdscript
	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_encounter_complete("goblin_camp"))
	assert_eq(GameSession.pending_reward, 1, "Victory should queue the goblin camp's rolled reward")
	assert_eq(GameSession.gold, 0, "Victory alone must not bank the reward")
```

becomes:

```gdscript
	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_encounter_complete("goblin_camp"))
	assert_eq(GameSession.battle_reward, 1, "Victory should queue the goblin camp's rolled reward in the battle store")
	assert_eq(GameSession.gold, 0, "Victory alone must not bank the reward")
```

Find the comment block and test `test_a_second_victory_in_one_deployment_
reports_only_its_own_loot` (the whole thing, comment included):

```gdscript
## Regression test: GameSession.pending_reward/pending_mana_crystals/
## pending_gear accumulate across every encounter a deployed party clears
## before returning to the settlement (see GameSession.deposit_pending_
## reward()), so a party's second victory in one deployment must not report
## the first battle's already-carried loot alongside its own in the summary
## -- only what this battle itself dropped.
func test_a_second_victory_in_one_deployment_reports_only_its_own_loot() -> void:
	var battlefield := _setup_goblin_camp_battle()
	# Simulate an earlier battle's loot already carried in pending_* this same
	# deployment, not yet deposited back at the settlement.
	GameSession.pending_reward = 50
	GameSession.pending_mana_crystals = {1: 3}
	GameSession.pending_gear = {"dagger_iron": 1, "buckler_wood": 1}
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 0.0

	battlefield._apply_battle_outcome(true)

	# Goblin camp's single goblin: gold_min 1 * multiplier 1, one mana
	# crystal, and (since loot_gear_roll always rolls below GEAR_DROP_CHANCE
	# here) one gear drop -- this battle's own loot only.
	assert_eq(
		GameManager.battle_result_summary.loot_gold, 1,
		"Only this battle's own gold, not the 50 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_mana_crystal_counts, {1: 1},
		"Only this battle's own mana crystal, not the 3 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_gear_counts, {"shortsword_iron": 1},
		"Only this battle's own gear, not the 2 pieces already carried over"
	)
	# Sanity check: the combined totals really did accumulate underneath --
	# the summary is deliberately reporting less than GameSession's own totals.
	assert_eq(GameSession.pending_reward, 51)
	assert_eq(GameSession.pending_mana_crystals[1], 4)
	var total_gear_pieces := 0
	for item_id in GameSession.pending_gear:
		total_gear_pieces += GameSession.pending_gear[item_id]
	assert_eq(total_gear_pieces, 3)
```

Replace with:

```gdscript
## Regression test: the battle store (GameSession.battle_reward/battle_
## mana_crystals/battle_gear) holds only the current battle's own loot,
## separate from the party's own running totals (pending_reward/pending_
## mana_crystals/pending_gear) until the player leaves the summary screen
## (see GameSession.merge_battle_loot_into_party()) -- so a party's second
## victory in one deployment must not report the first battle's already-
## carried loot alongside its own in the summary, and must not touch the
## party's own totals at all until that merge happens.
func test_a_second_victory_in_one_deployment_reports_only_its_own_loot() -> void:
	var battlefield := _setup_goblin_camp_battle()
	# Simulate an earlier battle's loot already merged into the party's own
	# store this deployment (see GameManager.go_to_world_map() ->
	# GameSession.merge_battle_loot_into_party()), not yet deposited back at
	# the settlement.
	GameSession.pending_reward = 50
	GameSession.pending_mana_crystals = {1: 3}
	GameSession.pending_gear = {"dagger_iron": 1, "buckler_wood": 1}
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 0.0

	battlefield._apply_battle_outcome(true)

	# Goblin camp's single goblin: gold_min 1 * multiplier 1, one mana
	# crystal, and (since loot_gear_roll always rolls below GEAR_DROP_CHANCE
	# here) one gear drop -- this battle's own loot, freshly rolled into the
	# battle store and reported straight from there.
	assert_eq(
		GameManager.battle_result_summary.loot_gold, 1,
		"Only this battle's own gold, not the 50 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_mana_crystal_counts, {1: 1},
		"Only this battle's own mana crystal, not the 3 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_gear_counts, {"shortsword_iron": 1},
		"Only this battle's own gear, not the 2 pieces already carried over"
	)
	# The battle store and the party's own store stay separate until the
	# player leaves the summary screen for the World Map -- so the
	# pre-seeded party totals above must still read exactly as seeded.
	assert_eq(GameSession.pending_reward, 50)
	assert_eq(GameSession.pending_mana_crystals, {1: 3})
	assert_eq(GameSession.pending_gear, {"dagger_iron": 1, "buckler_wood": 1})
```

- [ ] **Step 9: Update `tests/unit/test_first_campaign_ui_flow.gd`**

Find, in `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`:

```gdscript
	assert_true(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID))
	assert_eq(GameSession.selected_encounter, "", "Victory should clear the encounter selection")
	assert_eq(GameSession.pending_reward, 1, "The goblin camp's rolled reward should be queued but not yet banked")
	assert_eq(GameSession.gold, 0, "Winning the battle alone must not bank the reward")

	# Move party back to encampment, bank reward: walk the party home (again
	# jumping position, per this test's routing note above) and click the
	# settlement tile to return it, the same single action that also banks
	# the queued reward.
	GameSession.set_deployed_party_position(GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
```

Replace with:

```gdscript
	assert_true(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID))
	assert_eq(GameSession.selected_encounter, "", "Victory should clear the encounter selection")
	assert_eq(GameSession.battle_reward, 1, "The goblin camp's rolled reward should be queued in the battle store")
	assert_eq(GameSession.pending_reward, 0, "The battle store only merges into the party's own once the player leaves the summary screen")
	assert_eq(GameSession.gold, 0, "Winning the battle alone must not bank the reward")

	# A real player always leaves the victory summary screen via its OK
	# button before the World Map is reachable at all -- see GameManager.
	# go_to_world_map(), which is what merges the battle store into the
	# party's own. This test jumps position instead of driving the real
	# scene transition (see the routing note above), so it calls the same
	# merge go_to_world_map() would trigger directly.
	GameSession.merge_battle_loot_into_party()
	assert_eq(GameSession.pending_reward, 1, "Leaving the summary screen merges the battle store into the party's own")

	# Move party back to encampment, bank reward: walk the party home (again
	# jumping position, per this test's routing note above) and click the
	# settlement tile to return it, the same single action that also banks
	# the queued reward.
	GameSession.set_deployed_party_position(GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
```

(the rest of that test — the world-map click, encampment check — is
unchanged; it was already correct once `pending_reward` reaches 1)

- [ ] **Step 10: Run the full suite**

Run: `make check`

Expected: all green. If anything else fails, it's a call site this plan
missed — grep the failing test's file for `pending_reward`/`pending_gear`/
`pending_mana_crystals` near a `complete_current_encounter()` call, since
those are the only places the cutover changes behavior.

- [ ] **Step 11: Manual verification**

Run `make play`. Deploy a party, clear the Goblin Camp:
- The victory summary must show this battle's own gold and any loot,
  exactly as before this plan (no visible change expected).
- Click OK. On the World Map, open Party Details for the deployed party —
  its loot table must now include what the summary just showed.
- Return to the Encampment. Stores must reflect that loot banked correctly,
  and Party Details (now not deployed) must show no loot table.

- [ ] **Step 12: Commit**

```bash
git add scripts/autoload/game_session.gd scripts/autoload/game_manager.gd \
  scripts/battle/battlefield.gd scripts/ui/battle_result.gd \
  tests/unit/test_game_session.gd tests/unit/test_game_manager.gd \
  tests/unit/test_battlefield.gd tests/unit/test_first_campaign_ui_flow.gd
git commit -m "feat: roll battle loot into a real battle store, merge it into the party store"
```

---

## Finishing up

Once both tasks are committed and `make check` is green on the branch:

```bash
git checkout main
git merge battle-loot-store
git branch -d battle-loot-store
```

Then run the full-suite regression check in `index.md`.
