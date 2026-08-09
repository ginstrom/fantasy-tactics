# Step 5: Encounter Bonus Gold

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `encounter-bonus-gold`

**Goal:** On top of the gold each individual kill already queues,
clearing an encounter now also queues a flat gold bonus of its own:
`randi_range(0, 5) * difficulty`, rolled once per encounter clear, where
`difficulty` is the expedition's existing 1-3 star `EXPEDITIONS[id].difficulty`
field (see `index.md`'s design reference for why "level" means this and not
adventurer level).

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

This step needs **no edits to any existing test**. Every existing test that
asserts an exact `pending_reward` value after `complete_current_encounter()`
stubs `session.loot_gold_roll = func(min_value, _max_value): return min_value`
— and this step reuses that same injectable `loot_gold_roll` for the bonus
roll, called as `loot_gold_roll.call(0, 5)`. Since `min_value` here is
always `0`, every existing stub returns `0` for the bonus call too, adding
nothing to those tests' expected totals. Tests that don't stub
`loot_gold_roll` at all don't assert an exact `pending_reward` either (they
test vacancy/refill timing, not gold amounts), so they're unaffected as
well. Confirm this stays true in Step 2 below — if any existing test goes
red, its stub or assertion differs from what's described here and needs a
closer look before proceeding, not a blind value bump.

## Step 1: Write the failing tests

Add to `tests/unit/test_game_session.gd`, near the other
`complete_current_encounter()` gold tests (search for
`test_completing_the_orc_outpost_applies_the_documented_gold_multiplier`):

```gdscript
func test_completing_an_encounter_adds_a_gold_bonus_scaled_by_star_difficulty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(_min_value: int, max_value: int) -> int: return max_value
	session.loot_gear_roll = func() -> float: return 1.0
	# Force a single-orc composition (rather than two goblins) so the kill
	# loot side of this total stays deterministic.
	session.enemy_composition_roll = func(_option_count: int) -> int: return 1
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	# Kill gold: one orc, randi_range(1, 5) stubbed to max (5) * multiplier 2 = 10.
	# Encounter bonus: randi_range(0, 5) stubbed to max (5) * difficulty 2 = 10.
	assert_eq(session.pending_reward, 20, "Kill gold (10) plus the encounter bonus (10) at 2-star difficulty")


func test_recompleting_an_already_completed_encounter_does_not_requeue_the_bonus() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(_min_value: int, max_value: int) -> int: return max_value
	session.loot_gear_roll = func() -> float: return 1.0
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

## Step 2: Run the tests to verify they fail (and the rest of the file still passes)

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
```

Expected: the two new tests FAIL (today's code queues no bonus, so
`pending_reward` comes out 10 short in the first test). Every other test in
the file still PASSES, confirming the "existing stubs already return 0 for
the bonus" reasoning above holds. If some other, unrelated test also fails,
stop and investigate before continuing — don't proceed on an assumption
that's just been contradicted.

## Step 3: Implement the bonus

In `scripts/autoload/game_session.gd`, find `complete_current_encounter()`:

```gdscript
func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
		_roll_and_queue_loot(expedition.get("enemy", {}))
		_clear_active_encounter(selected_encounter)
	selected_encounter = ""
```

Add the bonus roll right after `_roll_and_queue_loot`:

```gdscript
func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
		_roll_and_queue_loot(expedition.get("enemy", {}))
		pending_reward += loot_gold_roll.call(0, 5) * int(expedition.get("difficulty", 1))
		_clear_active_encounter(selected_encounter)
	selected_encounter = ""
```

Update the function's doc comment if it has one nearby (check the lines
immediately above it) to mention the bonus — search for any comment block
directly preceding `func complete_current_encounter()` and, if present, add
a sentence noting the added flat, difficulty-scaled gold bonus alongside
the per-kill loot roll.

## Step 4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
```

Expected: `N/N passed.`

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. Press **FN+F9**, choose the **Goblin Camp** scenario (party already
   deployed onto the 1-star Goblin Camp).
2. Defeat the Goblin. On the victory summary screen, note the gold amount
   (Step 6 turns this into a real itemized screen — for this step, the
   existing `battle_result.loot` label's gold figure is enough to confirm
   a bonus is being added; it should now run a little higher than a single
   Goblin's own 1-6 gold roll would explain on its own, up to +5 for a
   1-star site).
3. Repeat via **FN+F9 → Orc Outpost** — the visible gold swing should be
   noticeably larger (up to +10 from the bonus at 2-star difficulty, on top
   of the Orc's own kill gold).

## Commit

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add a difficulty-scaled gold bonus on encounter clear"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge encounter-bonus-gold
git branch -d encounter-bonus-gold
```
