# Step 2: Warrior Hit Points

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `warrior-hit-points`

**Goal:** Warriors already start with 10 hit points
(`GameSession.BASE_MAX_HEALTH`, unchanged). The per-level gain is currently
1 (`GameSession.LEVEL_UP_MAX_HEALTH_BONUS`, sourced from
`config/game_config.json`'s `progression.level_up_max_health_bonus`); this
step raises it to 10, so a level-2 Warrior has 20 max health instead of 11.

**Files:**
- Modify: `config/game_config.json`
- Modify: `scripts/autoload/game_config.gd` (`DEFAULTS`)
- Test: `tests/unit/test_game_session.gd`
- Test: `tests/unit/test_battlefield.gd`
- Test: `tests/unit/test_level_up.gd`

`tests/unit/test_game_config.gd` needs no manual edit — its
`test_defaults_mirror_the_shipped_config_file_exactly` test compares
`GameConfigScript.DEFAULTS` against the shipped JSON key-by-key
automatically, so it stays green as long as Steps 1 and 2 below change both
files to the same value.

## Step 1: Update the three tests that hardcode the old value

These three tests currently assert the *old* 1-point-per-level behavior
(a level-1 Warrior has `BASE_MAX_HEALTH` 10, so leveling once with the old
bonus of 1 makes 11). Change each to expect the new 10-point bonus (10 + 10
= 20) — this is the red step; they'll fail against today's code until
Step 2 lands.

In `tests/unit/test_game_session.gd`, find
`test_each_level_gained_adds_one_max_health_and_ten_skill_points` and
change:

```gdscript
	assert_eq(warrior.stats.max_health, 11, "Leveling once should add exactly one max health")
```

to:

```gdscript
	assert_eq(warrior.stats.max_health, 20, "Leveling once should add exactly ten max health")
```

(Leave the function name as-is — renaming it is optional polish, not
required for this step; if you do rename it, rename it to
`test_each_level_gained_adds_ten_max_health_and_ten_skill_points` and grep
the file for any other reference to the old name before committing.)

In `tests/unit/test_battlefield.gd`, find
`test_a_level_up_from_kill_xp_raises_the_active_units_max_and_current_health`
and change:

```gdscript
	assert_eq(units.warrior.max_health, 11, "The active unit's max health must rise immediately on a mid-battle level-up")
	assert_eq(units.warrior.health, 11, "The active unit's current health must rise by the same amount as max health")
```

to:

```gdscript
	assert_eq(units.warrior.max_health, 20, "The active unit's max health must rise immediately on a mid-battle level-up")
	assert_eq(units.warrior.health, 20, "The active unit's current health must rise by the same amount as max health")
```

In `tests/unit/test_level_up.gd`, find
`test_shows_xp_level_health_gain_attack_and_skill_points_after_a_level_up`
and change:

```gdscript
	assert_eq(level_up.health_gain_label.text, tr("level_up.health_gain") % [11, 1])
```

to:

```gdscript
	assert_eq(level_up.health_gain_label.text, tr("level_up.health_gain") % [20, 10])
```

## Step 2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_level_up.gd -gexit
```

Expected: the three edited tests FAIL (everything else in those files
still passes).

## Step 3: Change the config default

In `config/game_config.json`, find `"level_up_max_health_bonus": 1` under
`"progression"` and change it:

```json
		"level_up_max_health_bonus": 10,
```

In `scripts/autoload/game_config.gd`, find the matching line in `DEFAULTS`
(`"level_up_max_health_bonus": 1,` under `"progression": {`) and change it
identically:

```gdscript
		"level_up_max_health_bonus": 10,
```

Both must change together — `test_defaults_mirror_the_shipped_config_file_exactly`
fails loudly if they drift.

## Step 4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_level_up.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_config.gd -gexit
```

Expected: `N/N passed.` for all four files.

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. Press **FN+F9**, choose the **Party Ready** scenario (a staffed,
   encamped Warrior).
2. Open Units → the Warrior → confirm Max Health reads 10 at level 1.
3. Deploy the party, enter the Goblin Camp, defeat it (or use FN+F9 →
   **Goblin Camp** to jump straight into the fight, then attack until the
   Goblin dies) — clearing it awards 15 XP total (5 kill + 10 clear),
   crossing the level-2 threshold (20 XP total needed, but check
   `docs/plans/first-playable-campaign/game-design.md`'s XP table if the
   single-kill total doesn't cross it — Orc Outpost's kill+clear XP (30)
   reliably does).
4. The Level-Up overlay should show `+10` health gained. After it closes,
   Unit Details should show 20 max health.

## Commit

```bash
git add config/game_config.json scripts/autoload/game_config.gd \
  tests/unit/test_game_session.gd tests/unit/test_battlefield.gd tests/unit/test_level_up.gd
git commit -m "feat: raise Warrior per-level health gain to 10"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge warrior-hit-points
git branch -d warrior-hit-points
```
