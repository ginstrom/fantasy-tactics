# Step 5: Player-power-weighted encounter tier selection

**Depends on:** Step 4 merged (needs `RUINED_FORTRESS_ID` and its
difficulty-3 template to exist, so there are three templates to weight
between).

**Produces:** `_choose_encounter_template()` — called only when a vacancy
timer fires (see `_advance_encounter_vacancies()`), never for the two
starting encounters `reset()` seeds directly — picks a star tier using
`_player_power()`/`_star_tier_weight()` instead of the old "prefer a
template never seen before" rule. See index.md's "Why this formula"
section for the weight table and the reasoning for dropping the old
guarantee.

## Setup

```bash
git checkout main && git pull
git checkout -b power-weighted-encounter-tiers
```

## Steps

- [ ] **Step 1: Write the failing tests (RED)**

  Add to `tests/unit/test_game_session.gd`:

  ```gdscript
  func test_player_power_is_adventurer_count_plus_guild_hall_level() -> void:
  	GameSession.reset()
  	assert_eq(GameSession._player_power(), 2, "One starting adventurer plus Guild Hall level 1")
  	GameSession.recruit_adventurer()
  	assert_eq(GameSession._player_power(), 3)
  	GameSession.guild_hall_level = 2
  	assert_eq(GameSession._player_power(), 4)


  func test_star_tier_weight_matches_the_documented_table_at_starting_power() -> void:
  	var session: Node = GameSessionScript.new()
  	autofree(session)
  	assert_eq(session._star_tier_weight(1, 2), 4)
  	assert_eq(session._star_tier_weight(2, 2), 4)
  	assert_eq(session._star_tier_weight(3, 2), 1)


  func test_star_tier_weight_shifts_toward_higher_tiers_as_power_grows() -> void:
  	var session: Node = GameSessionScript.new()
  	autofree(session)
  	assert_eq(session._star_tier_weight(1, 6), 1)
  	assert_eq(session._star_tier_weight(2, 6), 8)
  	assert_eq(session._star_tier_weight(3, 6), 4)


  func test_star_tier_weight_never_drops_to_zero_no_matter_how_high_power_gets() -> void:
  	var session: Node = GameSessionScript.new()
  	autofree(session)
  	assert_eq(session._star_tier_weight(1, 1000), 1)


  ## At starting power (2), candidates [goblin_camp, ruined_fortress] (orc_outpost
  ## stays active) weight to [4, 1] -- a total of 5. Rolls 0-3 land on
  ## goblin_camp's bucket, roll 4 lands on ruined_fortress's.
  func test_choose_encounter_template_maps_the_weighted_roll_onto_the_right_candidate() -> void:
  	GameSession.reset()
  	GameSession.active_encounters = [GameSession.active_encounters[1]]

  	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 0
  	assert_eq(GameSession._choose_encounter_template(), GameSession.GOBLIN_CAMP_ID)

  	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 4
  	assert_eq(GameSession._choose_encounter_template(), GameSession.RUINED_FORTRESS_ID)


  func test_choose_encounter_template_never_offers_a_currently_active_template() -> void:
  	GameSession.reset()
  	# Both starting templates are active; only the Ruined Fortress can be chosen.
  	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 0
  	assert_eq(GameSession._choose_encounter_template(), GameSession.RUINED_FORTRESS_ID)


  func test_a_vacancy_refill_can_produce_the_ruined_fortress() -> void:
  	GameSession.reset()
  	GameSession.active_encounters = [GameSession.active_encounters[1]]
  	GameSession.encounter_vacancies = [{"turns_remaining": 1}]
  	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 4

  	GameSession._advance_encounter_vacancies()

  	var template_ids: Array = []
  	for instance in GameSession.active_encounters:
  		template_ids.append(instance.template_id)
  	assert_true(template_ids.has(GameSession.RUINED_FORTRESS_ID))
  ```

- [ ] **Step 2: Run the suite and confirm these fail**

  Run: `make test`
  Expected: FAIL — `_player_power`, `_star_tier_weight`, and
  `star_weight_roll` don't exist yet, and `_choose_encounter_template()`
  still runs its old deterministic-cycle logic.

- [ ] **Step 3: Implement the weighted picker (GREEN)**

  Edit `scripts/autoload/game_session.gd`.

  Add the weight table and helper functions (a good home is right after
  `STAR_ENEMY_COMPOSITIONS`'s closing `}`):

  ```gdscript
  ## Star-tier selection weight for a refill candidate at a given player
  ## power (see docs/plans/first-playable-campaign/game-design.md's
  ## "Vacancy-timed encounter and recruitment population" section for the
  ## worked example table). Floors at STAR_WEIGHT_MIN so no tier's odds
  ## ever reach exactly zero.
  const STAR_WEIGHT_BASE: Dictionary = {1: 6, 2: 2, 3: -2}
  const STAR_WEIGHT_PER_POWER: Dictionary = {1: -1, 2: 1, 3: 1}
  const STAR_WEIGHT_MIN: int = 1


  func _player_power() -> int:
  	return adventurers.size() + guild_hall_level


  func _star_tier_weight(tier: int, power: int) -> int:
  	return maxi(STAR_WEIGHT_MIN, STAR_WEIGHT_BASE[tier] + STAR_WEIGHT_PER_POWER[tier] * power)
  ```

  Add the injectable roll next to `enemy_composition_roll` (around line
  251):

  ```gdscript
  ## Injectable so tests can force a specific weighted-tier outcome instead
  ## of depending on real randomness (see enemy_composition_roll for the
  ## same pattern). Takes the candidates' total weight and returns a value
  ## in [0, total_weight) -- _choose_encounter_template() maps it onto each
  ## candidate's weight bucket via a cumulative sum.
  var star_weight_roll: Callable = func(total_weight: int) -> int: return randi() % total_weight
  ```

  Replace `_choose_encounter_template()` and its docstring (around line
  1010-1027):

  ```gdscript
  ## Weighted-random by star tier, favoring higher tiers as the player's
  ## power (adventurer count plus Guild Hall level -- see _player_power())
  ## grows. Only a template with no currently-active instance is eligible,
  ## so a refill never activates a second live instance of an
  ## already-active template. Deliberately replaces the old "show every
  ## template once before reuse" guarantee: at a fresh campaign's first
  ## refill the Ruined Fortress would otherwise be the only unseen
  ## template and would always be forced in regardless of power, defeating
  ## the point of weighting it down for a weak party.
  func _choose_encounter_template() -> String:
  	var candidates: Array[String] = []
  	for template_id in ENCOUNTER_TEMPLATE_ORDER:
  		if not _is_encounter_template_active(template_id):
  			candidates.append(template_id)
  	if candidates.is_empty():
  		return ENCOUNTER_TEMPLATE_ORDER[0]

  	var power := _player_power()
  	var weights: Array[int] = []
  	var total_weight := 0
  	for template_id in candidates:
  		var weight := _star_tier_weight(EXPEDITIONS[template_id].difficulty, power)
  		weights.append(weight)
  		total_weight += weight

  	var roll: int = star_weight_roll.call(total_weight)
  	var cumulative := 0
  	for index in candidates.size():
  		cumulative += weights[index]
  		if roll < cumulative:
  			return candidates[index]
  	return candidates[-1]
  ```

  Update `ENCOUNTER_TEMPLATE_ORDER` to include the new template (around
  line 160) — this should already be done if Step 4 was merged first, but
  confirm it reads:

  ```gdscript
  const ENCOUNTER_TEMPLATE_ORDER := ["goblin_camp", "orc_outpost", "ruined_fortress"]
  ```

  Finally, update the now-stale comment on `_used_encounter_template_ids`
  (around line 269-274), which currently claims it drives template
  *choice* — it no longer does (only tile choice, via
  `_choose_encounter_position()`):

  ```gdscript
  # Every template id ever spawned as an active instance (initial seed plus
  # every refill). _choose_encounter_position() uses this to avoid handing a
  # refill the exact tile a template's earlier instance was just cleared
  # from (see that function's docstring) -- it no longer influences which
  # template a refill chooses; see _choose_encounter_template() for that.
  ```

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  This is inherently probabilistic in real play, so verify it two ways:

  1. Automated confidence: run `make simulate RUNS=50` (or the project's
     existing headless battle runner) and confirm it still completes
     cleanly — this doesn't exercise the weighting directly but proves nothing
     else broke.
  2. Direct confidence: run `make editor`, open the Script tab, and drive
     `_choose_encounter_template()` a few hundred times at a low and a high
     power to eyeball the distribution:
     ```gdscript
     GameSession.reset()
     GameSession.active_encounters = [GameSession.active_encounters[1]]
     var counts := {}
     for i in 1000:
     	var chosen: String = GameSession._choose_encounter_template()
     	counts[chosen] = counts.get(chosen, 0) + 1
     print(counts)  # expect roughly goblin_camp:800, ruined_fortress:200 (4:1)
     ```
     Then repeat after `GameSession.guild_hall_level = 2` and recruiting a
     few adventurers to raise power, and confirm `ruined_fortress`'s share
     grows. Remove the scratch script before committing.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
  git commit -m "feat: weight encounter refill tier selection by player power"
  ```

## Merge back to main

Get the user's signoff on Step 5's distribution check, then:

```bash
git checkout main
git merge power-weighted-encounter-tiers
git branch -d power-weighted-encounter-tiers
```
