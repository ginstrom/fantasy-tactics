extends GutTest
## Covers scripts/tools/campaign_sim.gd (CampaignSim) and scripts/tools/
## campaign_sim_metrics.gd (CampaignSimMetrics) -- the headless, scene-free
## campaign-level simulator and its telemetry aggregator (docs/plans/
## 2026-08-18-core-loop-and-engagement/06-campaign-simulation-and-balance-
## harness.md).

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const CampaignSimMetricsScript := preload("res://scripts/tools/campaign_sim_metrics.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")

## The representative seed set lives on CampaignSim itself now (CampaignSim.
## REPRESENTATIVE_VICTORY_SEEDS) -- see that constant's own doc comment for
## the full historical context (the post-fix sweep it was derived from, and
## the kill_xp lambda-capture-by-value bug that fix uncovered). Tests below
## read that single production-owned copy rather than keeping a second one
## here, so the CLI (campaign_sim_main.gd), the metrics/label layer
## (campaign_sim_metrics.gd), and this suite can never drift apart on what
## "representative" means.


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()


## --- Task 1: execution engine ----------------------------------------------

func test_run_campaign_initializes_a_fresh_session_and_advances_through_objectives() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(42)

	assert_gt(GameSession.world_turn, 1, "A campaign run must advance world turns from the fresh-session default of 1")
	assert_true(
		GameSession.completed_objectives.size() > 0 or GameSession.is_campaign_completed,
		"At least one campaign objective must be completed by the time run_campaign() returns"
	)
	assert_eq(record.seed, 42)


func test_run_campaign_handles_recruitment_movement_combat_and_returns_to_encampment() -> void:
	var sim := CampaignSimScript.new()

	sim.run_campaign(42)

	# Recruitment: the roster grew past the four starting Warriors (matches
	# is_campaign_guide_first_improvement_made's own "more than the starting
	# roster" convention -- see code-map.md).
	assert_gt(GameSession.adventurers.size(), GameSession.STARTING_ROSTER_SIZE, "The simulator must recruit beyond the starting roster")
	# Combat: at least one battle was actually fought and resolved.
	assert_gt(GameSession.completed_encounters.size(), 0, "At least one encounter must be cleared")
	# Returns to Encampment between attempts: the party is not left deployed
	# out on the World Map once run_campaign() returns control.
	assert_false(GameSession.has_deployed_party(), "The party must be back at the Encampment (undeployed) once the run loop yields control")


## Locks in the "Injectable seed parameter ... for 100% reproducible
## deterministic campaign runs" requirement: two independent runs of the
## same seed against a freshly reset session must reach byte-identical
## outcomes, not just the same win/loss verdict. Exercises every injectable
## roll _wire_deterministic_rolls() wires (loot, enemy composition/count,
## vacancy timers, recruitment class, minted instance ids) plus the
## per-battle seed derivation in _fight_objective().
func test_run_campaign_is_fully_deterministic_for_a_fixed_seed() -> void:
	var first := CampaignSimScript.new().run_campaign(7)
	GameSession.reset()
	var second := CampaignSimScript.new().run_campaign(7)

	assert_eq(first, second, "Identical seeds must produce byte-identical telemetry")


## Locks in the "reach victory on an explicitly listed representative seed
## set" requirement verbatim -- every seed here is expected to resolve
## (is_campaign_completed) via CampaignSim's own bot/gear/recruit/upgrade
## policy alone, deterministically. A regression that breaks the campaign's
## completability (a balance change, a policy bug) fails loudly here rather
## than only showing up as a lower make campaign-sim victory rate.
## Review Finding 3 (second part) USED to also require this same evidence set
## to field the full triad and cast a spell (see this file's own prior report)
## -- superseded by docs/plans/2026-08-21-stage-2-party-readiness/'s
## final-review fix wave's Fix 1, which wires class-owned perk effects
## (Juggernaut's +15% max_health chief among them) into BattleStateFactory
## for the first time. That fix intentionally makes a simulated party
## survive combat significantly better -- unit deaths across these five
## seeds dropped sharply once Juggernaut/Bulwark/Quickdraw/Devout actually
## apply -- which starves _refill_party()'s death-driven recruitment churn
## on precisely these five seeds, so none of them happen to field the full
## triad or cast a Cleric spell anymore even though every one still wins.
## This is the correct, intended effect of Fix 1 (perks now actually change
## outcomes), not a regression -- the Cleric loop itself is still proven
## end-to-end by the independent, dedicated CLERIC_TRIAD_SEED (42) test
## below, which is unaffected by this seed set's own recruitment pacing.
func test_run_campaign_reaches_victory_on_the_representative_seed_set() -> void:
	for seed in CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
		GameSession.reset_injectable_rolls()
		var sim := CampaignSimScript.new()
		var record := sim.run_campaign(seed)
		assert_true(
			record.victory,
			"seed %d: expected campaign victory but got reason=%s (world_turns=%d, battles=%d/%d won, wipes=%d)"
			% [seed, record.reason, record.world_turns, record.battles_won, record.battles_fought, record.party_wipes]
		)
		assert_eq(record.reason, "victory")
		assert_true(GameSession.is_campaign_completed)


## --- Step 4 (docs/plans/2026-08-22-stage-3-campaign-assembly/04-authored-
## arc-economy-and-boss-tuning.md), Task 1: checkpoint assertions for the
## bands docs/designs/campaign-loop.md's "Stage 3 approval bands" table
## locks (party level at Ogre entry) or leaves for this step to pin from
## Step 2's own measured baseline (meaningful upgrades, gold/recovery
## budget). Every assertion below reads a range/aggregate across the whole
## representative seed set from a real, deterministic run -- never a single
## seed's exact figure or one incidental roll -- per this step's own
## instruction to avoid asserting on a single accidental value. The measured
## Re-baselined after missile attacks became stationary and unit-transparent:
## `make campaign-sim` reports world_turns=50 and boss-entry averages
## 4.4-5.6 across 4/9/10/12/14, with all five campaigns still victorious.
## The 4-7 approval band below leaves headroom around that measured range.
## Every representative run still completes seven upgrades; gold_earned and
## hp_recovered_total remain within their separately asserted evidence bands.
## (mp_recovered_total=0 for every seed -- none of the five representative
## seeds happens to field a Cleric; see REPRESENTATIVE_VICTORY_SEEDS' own
## doc comment). Each band below keeps headroom around that measured range
## rather than pinning the exact figures, so a small, legitimate pacing
## shift does not spuriously fail this suite.
func _objective_record(record: Dictionary, objective_id: String) -> Dictionary:
	for entry in record.get("objective_records", []):
		if String(entry.get("objective_id", "")) == objective_id:
			return entry
	return {}


## Locks docs/designs/campaign-loop.md's "Target party level at Ogre entry"
## band (4-7) against the party actually fielded for the
## Ogre fight itself (the boss's own objective_records entry's level_
## summary, snapshotted immediately before that battle) -- not an
## end-of-run or pre-final-tier snapshot, which could drift from what the
## player actually faces the Ogre with.
func test_representative_seeds_enter_the_ogre_fight_within_the_approved_level_band() -> void:
	for seed in CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
		GameSession.reset_injectable_rolls()
		var sim := CampaignSimScript.new()
		var record := sim.run_campaign(seed)
		var boss_entry := _objective_record(record, "obj_boss_borderlands_ogre")
		assert_false(boss_entry.is_empty(), "seed %d: the boss node must have been attempted on a representative victory seed" % seed)
		var average_level := float(boss_entry.get("level_summary", {}).get("average", -1.0))
		assert_true(
			average_level >= 4.0 and average_level <= 7.0,
			"seed %d: party average level at Ogre entry was %.2f, outside the approved 4-7 band" % [seed, average_level]
		)


## Locks the "required meaningful upgrades" checkpoint as the floor Step 2's
## baseline measured, not an invented target: docs/designs/campaign-loop.md's
## Encampment upgrade budget table deliberately leaves the exact count
## unspecified, but every one of the five representative seeds reached the
## Guild Hall level-1 cap upgrade, a built Temple, and a built Blacksmith by
## victory -- a regression that silently starves the economy below that
## floor (e.g. a building-cost change that leaves a representative seed
## unable to afford the Guild Hall cap) must fail here.
func test_representative_seeds_complete_the_measured_floor_of_encampment_upgrades() -> void:
	for seed in CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
		GameSession.reset_injectable_rolls()
		var sim := CampaignSimScript.new()
		var record := sim.run_campaign(seed)
		var upgrades: Dictionary = record.upgrade_progression_turns
		assert_true(
			upgrades.size() >= 6,
			"seed %d: expected at least 6 completed upgrades by victory (Step 2 baseline measured 7), got %d" % [seed, upgrades.size()]
		)
		for key in ["guild_hall_level_2", "guild_hall_level_3", "temple", "blacksmith"]:
			assert_true(upgrades.has(key), "seed %d: expected upgrade '%s' to have landed by victory" % [seed, key])


## Locks the "resource/recovery budget" checkpoint docs/designs/
## campaign-loop.md's approval-bands table left "not yet defined" pending
## Step 2's real telemetry: gold actually earned across a representative
## victory, and total HP actually recovered across the whole run (summed
## from every objective_records entry -- an aggregate, not one heal roll),
## both stay inside the range Step 2's baseline measured, with headroom on
## both sides.
func test_representative_seeds_earn_gold_and_recover_hp_within_the_measured_baseline_range() -> void:
	for seed in CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
		GameSession.reset_injectable_rolls()
		var sim := CampaignSimScript.new()
		var record := sim.run_campaign(seed)
		assert_true(
			int(record.gold_earned) >= 800 and int(record.gold_earned) <= 1500,
			"seed %d: gold_earned %d fell outside the measured baseline range [800, 1500]" % [seed, int(record.gold_earned)]
		)
		var hp_recovered_total := 0
		for entry in record.objective_records:
			hp_recovered_total += int(entry.get("hp_recovered", 0))
		assert_true(
			hp_recovered_total >= 150 and hp_recovered_total <= 400,
			"seed %d: total hp_recovered %d fell outside the measured baseline range [150, 400]" % [seed, hp_recovered_total]
		)


## --- Step 2 (docs/plans/2026-08-22-stage-3-campaign-assembly/02-campaign-
## telemetry-and-comparison.md), Task 1-3: ordered per-objective record ------

## Locks the new evidence contract: run_campaign()'s telemetry must expose an
## ordered `objective_records` array -- one entry per objective actually
## attempted (recruited, traveled to, and fought), each carrying enough
## detail for a reviewer to reconstruct "what happened at this node" without
## reading simulator source (see this step's own manual-check requirement).
## Existing top-level telemetry fields (record.victory, record.world_turns,
## etc. -- see test_run_campaign_initializes_a_fresh_session_and_advances_
## through_objectives() above) are untouched by this test on purpose: this is
## purely an additive field.
func test_run_campaign_records_an_ordered_per_objective_record_with_full_evidence() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS[0])

	assert_true(record.has("objective_records"), "Telemetry must expose an ordered objective_records array")
	var objective_records: Array = record.get("objective_records", [])
	assert_gt(objective_records.size(), 0, "At least one objective must have been attempted on a representative victory seed")

	# "Ordered" is checked, not assumed: world_turn_start must never regress
	# across the list, and every objective id in it must be a real, authored
	# CAMPAIGN_OBJECTIVES entry -- not an invented placeholder.
	var previous_turn := -1
	for entry in objective_records:
		assert_true(
			int(entry.get("world_turn_start", -1)) >= previous_turn,
			"objective_records must be in non-decreasing world-turn order"
		)
		previous_turn = int(entry.world_turn_start)
		assert_true(
			GameSession.CAMPAIGN_OBJECTIVES.has(String(entry.get("objective_id", ""))),
			"objective_id must be a real, authored campaign objective"
		)

	var first: Dictionary = objective_records[0]
	for key in [
		"objective_id", "outcome", "world_turn_start", "world_turn_end",
		"party_losses", "hp_recovered", "mp_recovered", "gold_before", "gold_after",
		"upgrades_purchased", "party_composition", "level_summary",
	]:
		assert_true(first.has(key), "objective_records entry must include '%s'" % key)

	assert_true(
		String(first.outcome) in ["victory", "defeat", "stalemate", "error"],
		"outcome must be a real battle-resolution verdict, not a placeholder"
	)
	assert_true(int(first.world_turn_end) >= int(first.world_turn_start), "world_turn_end must not precede world_turn_start")
	assert_false(bool(first.party_composition.is_empty()), "party_composition must record who was actually fielded for this objective")
	assert_true(
		first.level_summary.has("levels") and first.level_summary.has("average"),
		"level_summary must report both per-member levels and the party average"
	)

	# Byte-identical determinism must hold for the new field too, exactly
	# like every other telemetry field (see test_run_campaign_is_fully_
	# deterministic_for_a_fixed_seed() above) -- a per-objective record built
	# from anything but the run's own seeded RNG/state would break this.
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	var second := CampaignSimScript.new().run_campaign(CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS[0])
	assert_eq(objective_records, second.get("objective_records", []), "objective_records must be byte-identical for a repeated seed")


## Review follow-up (Finding 2 fix verification): directly exercises
## _vitals_recovered()'s recruit-exclusion behavior with hand-built synthetic
## before/after snapshots -- not a real campaign run, mirroring how the
## aggregate/JSON tests above isolate CampaignSimMetrics from CampaignSim
## itself. Locks in the real bug the review caught from live `make
## campaign-sim` output: a member id present in `after`'s hp_by_member/
## mp_by_member but absent from `before` (exactly what a same-cycle recruit
## looks like, since _party_vitals_snapshot() only ever records currently
## fielded member ids) must never have their HP/MP counted toward the
## computed recovery delta -- or a reviewer reading hp_recovered/mp_recovered
## off a saved report would mistake roster growth for rest recovery.
func test_vitals_recovered_excludes_a_member_present_only_in_the_after_snapshot() -> void:
	var sim := CampaignSimScript.new()

	var before := {
		"hp_by_member": {"warrior_a": 10, "cleric_a": 4},
		"mp_by_member": {"cleric_a": 2},
	}
	var after := {
		# warrior_a and cleric_a rested (present in both snapshots): +8 HP,
		# +2 HP, +1 MP -- genuine recovery that must count. scout_b is a
		# brand-new id absent from `before` -- a same-cycle recruit joining
		# at full HP/MP -- and must be excluded entirely, from both totals.
		"hp_by_member": {"warrior_a": 18, "cleric_a": 6, "scout_b": 20},
		"mp_by_member": {"cleric_a": 3, "scout_b": 5},
	}

	var recovered := sim._vitals_recovered(before, after)

	assert_eq(
		int(recovered.hp), 10,
		"Only warrior_a's +8 and cleric_a's +2 (both present in both snapshots) may count -- scout_b's 20 starting HP must be excluded"
	)
	assert_eq(int(recovered.mp), 1, "Only cleric_a's +1 MP (present in both snapshots) may count -- scout_b's 5 starting MP must be excluded")


## --- Review Finding 1 fix: XP splits across the pre-death roster -----------

## award_party_xp() divides evenly across GameSession's party.member_ids at
## the instant it's called, so it must run BEFORE _persist_battle_state()
## resolves permadeath -- matching battlefield.gd's real ordering exactly
## (_apply_battle_outcome()'s _award_clear_xp() always runs before
## _finish_victory()'s _persist_battle_aftermath(); see battlefield.gd:377-
## 392,502-503) -- or a battle with partial player casualties inflates each
## survivor's per-capita XP share above what real play would produce.
## Subclasses CampaignSim to override only the two private scenario-building
## hooks (_build_player_units()/_build_enemy_units()) with a fixed, engineered
## matchup -- one full-health, level-6 "tank" and one 1-HP "fragile" ally
## planted adjacent to a single orc_bruiser -- so the enemy's own greedy
## nearest-target AI (_take_enemy_unit_actions()'s _nearest_living_unit(),
## Manhattan-distance) is virtually guaranteed to kill the fragile ally on
## its first landed hit (the fragile ally sits at Manhattan distance 1 from
## the enemy's default start; the tank starts distance 10 away) while the
## tank alone finishes the enemy off over the remaining rounds. Everything
## else -- _fight_objective() itself, _persist_battle_state(),
## _run_battle_to_resolution() -- is the real, unmodified production path.
class _FragileCasualtyCampaignSim extends CampaignSimScript:
	var tank_id: String = ""
	var fragile_id: String = ""

	func _build_player_units(_catalog_definition: Dictionary = {}) -> Array:
		return [
			_unit_spec(tank_id, {}),
			_unit_spec(fragile_id, {
				# vitality(10) * level(1) + (-9) == 1 HP (see _build_player_
				# unit()'s max_health formula).
				"modifiers": {"max_health": -9},
				# Chebyshev/8-neighbor-adjacent (melee attack range) to the
				# enemy's own default start position (5,5) -- see
				# BattleControllerScript.ENEMY_START_POSITIONS[0] -- and
				# Manhattan distance 1, far closer than the tank's default
				# (0,0) start (Manhattan distance 10), so
				# _nearest_living_unit() always prefers this unit as the
				# enemy's target while it's alive.
				"position": {"x": 4, "y": 5},
			}),
		]

	func _unit_spec(member_id: String, extra: Dictionary) -> Dictionary:
		var adventurer := GameSession.get_adventurer(member_id)
		var spec := {
			"id": member_id,
			"template_id": String(adventurer.get("class", "warrior")),
			"weapon_id": String(adventurer.equipment.get("weapon", GameSession.DEFAULT_WEAPON_ID)),
			"armor_id": String(adventurer.equipment.get("armor", GameSession.DEFAULT_ARMOR_ID)),
			"level": int(adventurer.get("level", 1)),
		}
		spec.merge(extra)
		return spec

	func _build_enemy_units(_expedition: Dictionary, _catalog_definition: Dictionary = {}) -> Array:
		return [{"id": "enemy_0", "template_id": "orc_bruiser"}]


func test_victory_xp_is_split_across_the_pre_death_roster_not_just_survivors() -> void:
	GameSession.create_party()
	var tank_id := String(GameSession.adventurers[0].id)
	var fragile_id := String(GameSession.adventurers[1].id)
	GameSession.assign_adventurer_to_selected_party(tank_id)
	GameSession.assign_adventurer_to_selected_party(fragile_id)
	for adventurer in GameSession.adventurers:
		if String(adventurer.id) == tank_id:
			adventurer.level = 6

	var sim := _FragileCasualtyCampaignSim.new()
	sim.sim_seed = 4242
	sim.tank_id = tank_id
	sim.fragile_id = fragile_id
	var telemetry := sim._new_telemetry(4242)

	var xp_before: float = float(GameSession.get_adventurer(tank_id).progression.xp)
	var outcome := sim._fight_objective(GameSession.GOBLIN_CAMP_ID, telemetry)

	assert_eq(
		outcome, "victory",
		"The engineered matchup (full-health level-6 tank + 1-HP fragile ally vs. one orc_bruiser) must resolve as a win"
	)
	assert_eq(telemetry.unit_deaths, 1, "Exactly the 1-HP fragile ally must have died -- this is the partial-casualty case Finding 1 covers")
	assert_true(GameSession.get_adventurer(fragile_id).is_empty(), "The dead member must be gone from the roster (permadeath)")
	assert_false(GameSession.get_adventurer(tank_id).is_empty(), "The tank must have survived")

	var expected_total_xp := float(GameSession.ORC_BRUISER_ENEMY_STATS.kill_xp) + float(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).clear_xp)
	var expected_share := expected_total_xp / 2.0  # split across BOTH pre-death members, not just the 1 survivor
	var xp_after: float = float(GameSession.get_adventurer(tank_id).progression.xp)
	assert_almost_eq(
		xp_after - xp_before, expected_share, 0.01,
		(
			"The surviving tank's XP gain must equal total_xp (%.1f) split across the pre-death roster (2 members) == %.1f -- "
			+ "a regression to the old (award-after-permadeath) ordering would instead award the full %.1f to the sole survivor"
		) % [expected_total_xp, expected_share, expected_total_xp]
	)


## --- Stage 6 Step 2 fix: a wipe through _fight_objective() must forfeit the
## party's own already-carried loot, not just this battle's own reward -------

## Solo variant of _FragileCasualtyCampaignSim above: a single 1-HP unit at
## the same guaranteed-target adjacency (Manhattan distance 1 from the
## enemy's default start) with no tank counterpart to finish the enemy off,
## so the party wipes outright instead of losing only that one member.
class _SoloWipeCampaignSim extends CampaignSimScript:
	var solo_id: String = ""

	func _build_player_units(_catalog_definition: Dictionary = {}) -> Array:
		var adventurer := GameSession.get_adventurer(solo_id)
		return [{
			"id": solo_id,
			"template_id": String(adventurer.get("class", "warrior")),
			"weapon_id": String(adventurer.equipment.get("weapon", GameSession.DEFAULT_WEAPON_ID)),
			"armor_id": String(adventurer.equipment.get("armor", GameSession.DEFAULT_ARMOR_ID)),
			"level": int(adventurer.get("level", 1)),
			"modifiers": {"max_health": -9},
			"position": {"x": 4, "y": 5},
		}]

	func _build_enemy_units(_expedition: Dictionary, _catalog_definition: Dictionary = {}) -> Array:
		return [{"id": "enemy_0", "template_id": "orc_bruiser"}]


## Regression test for a bug this review found: complete_current_encounter()
## only auto-vivifies an "active" BattleContext on the victory path (see its
## own _ensure_active_battle_context() doc comment) -- _fight_objective()'s
## defeat/stalemate branches called abandon_current_encounter() instead and
## never created one at all, so resolve_battle_defeat()'s battle_id/status
## guard always failed and forfeit_party_carry() silently never ran. A wiped
## party's own already-carried gold from earlier victories this deployment
## would then survive to be banked by _return_to_encampment()'s unconditional
## deposit_party_carry() call -- exactly the cross-battle carry leak this
## step's own isolation invariant forbids. Fixed by _fight_objective() calling
## GameSession.create_battle_context() explicitly before the battle starts,
## mirroring GameManager.enter_battle()'s real-flow ordering.
func test_a_full_party_wipe_through_fight_objective_forfeits_the_partys_own_already_carried_loot() -> void:
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	var solo_id := String(GameSession.adventurers[0].id)
	GameSession.assign_adventurer_to_selected_party(solo_id)
	GameSession.parties[0].carry.gold = 500

	var sim := _SoloWipeCampaignSim.new()
	sim.sim_seed = 4242
	sim.solo_id = solo_id
	var telemetry := sim._new_telemetry(4242)

	var outcome := sim._fight_objective(GameSession.GOBLIN_CAMP_ID, telemetry)

	assert_eq(outcome, "defeat", "The engineered 1-HP solo unit vs. one orc_bruiser, with no tank to finish it off, must resolve as a wipe")
	assert_eq(
		GameSession.get_party_carry(party_id).gold, 0,
		"A full-party wipe must forfeit the party's own already-carried gold from earlier victories, not just discard this battle's own not-yet-banked reward"
	)


## --- Stage 5 exit-gate fix: _build_player_units() must thread a promoted
## specialization, not just its perks --------------------------------------

## Reproduces a real bug the Stage 5 exit-gate journey test surfaced: once any
## fieldable-root adventurer (Warrior -> Knight/Archer, Cleric -> Paladin) is
## promoted, ScenarioContract._validate_side() only accepts that
## specialization's own perk ids (e.g. Knight's "knight_shield_bash") when
## the scenario unit's own "specialization" field names it -- see that
## function's own doc comment. _build_player_units() already threaded chosen
## perks (the exact fix this same file's own header comment describes for
## Juggernaut/Bulwark/Quickdraw/Devout) but never threaded "specialization"
## itself, so a fielded promoted Knight's own Shield Bash/Chain Blow perks
## would fail validate() as "unknown perk", turning _fight_objective() into a
## hard "error" outcome the instant any fieldable root ever promotes -- not
## reachable by campaign_sim's own automated runs (which never call
## promote_adventurer()), but reachable by any real save/tool that hands a
## promoted roster to CampaignSim's scene-free battle path, exactly what this
## step's exit-gate journey does.
func test_build_player_units_threads_a_promoted_specialization_so_its_perks_validate() -> void:
	GameSession.create_party()
	var knight_id := String(GameSession.adventurers[0].id)
	GameSession.assign_adventurer_to_selected_party(knight_id)
	for adventurer in GameSession.adventurers:
		if String(adventurer.id) == knight_id:
			adventurer.level = 8  # enough earned perk slots for both root perks plus one specialization perk
	GameSession.choose_perk(knight_id, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(knight_id, GameSession.WARRIOR_BULWARK_PERK_ID)
	assert_true(GameSession.promote_adventurer(knight_id, "knight"), "Setup: both root perks are chosen, so promotion must succeed")
	assert_true(
		GameSession.choose_perk(knight_id, GameSession.KNIGHT_DISCIPLINE_PERK_ID),
		"Setup: promotion must open a Knight perk slot"
	)
	assert_true(
		GameSession.choose_perk(knight_id, GameSession.KNIGHT_SHIELD_BASH_PERK_ID),
		"Setup: Shield Bash is available once Discipline is chosen"
	)

	var sim := CampaignSimScript.new()
	var units := sim._build_player_units()

	var knight_spec: Dictionary = {}
	for unit_spec in units:
		if String(unit_spec.id) == knight_id:
			knight_spec = unit_spec
	assert_false(knight_spec.is_empty(), "Setup: the promoted Knight must still be fielded (its root class, warrior, stays fieldable)")
	assert_eq(knight_spec.get("specialization", ""), "knight", "The scenario unit must name its promoted specialization")
	assert_true(
		(knight_spec.get("perks", []) as Array).has(GameSession.KNIGHT_SHIELD_BASH_PERK_ID),
		"Setup: the chosen specialization perk must still be threaded"
	)

	var errors := ScenarioContractScript.validate(
		ScenarioContractScript.normalize({
			"scenario_id": "specialization_threading_regression",
			"player": {"units": [knight_spec]},
			"enemy": {"units": [{"id": "goblin_0", "template_id": "goblin"}]},
		})
	)
	assert_eq(errors, [] as Array[String], "A promoted Knight's own perks must validate now that specialization is threaded")


## --- Review Finding 2 fix: existing-roster assignment also prefers a
## missing class, not just new recruitment purchases -------------------------

## Reproduces the exact composition gap Finding 2 identified: a fresh
## GameSession.reset() always seeds 4 starting Warriors (STARTING_ROSTER_SIZE),
## so after 3 of them fill the Guild Hall level-1 3-slot party cap, the 4th
## starting Warrior sits unassigned in the roster alongside any Scout/Cleric
## also recruited-but-unassigned. Before this fix, _refill_party()'s phase-1
## "assign already-owned fieldable adventurers" loop had no missing-class
## preference and walked GameSession.get_available_adventurers() in roster
## (array) order, so a Guild Hall upgrade to a 4th slot got filled by that
## leftover 4th Warrior -- never giving the missing-class preference
## (_missing_fieldable_classes(), already used for new recruitment purchases)
## a chance to seat the roster's own unassigned Scout before a duplicate
## Warrior. This was suspected (not confirmed) to be why representative seed
## 12 never fields a Cleric; verifying after the fix showed seed 12's actual
## cause is unrelated (its RNG stream never rolls an affordable Cleric
## recruitment offer at all -- see REPRESENTATIVE_VICTORY_SEEDS' doc comment
## and this fix's report) -- this fix is still correct and necessary on its
## own terms (a real composition-gap bug, reproduced directly below), it
## just isn't what was gating seed 12 specifically.
func test_refill_party_prefers_an_already_owned_missing_class_member_over_a_duplicate_warrior() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameSession.create_party()

	var warrior_ids: Array = []
	for adventurer in GameSession.adventurers:
		warrior_ids.append(String(adventurer.id))
	GameSession.adventurers.append(GameSession.get_default_scout(GameSession._new_instance_id(), "Scout Test"))
	var scout_id := String(GameSession.adventurers[GameSession.adventurers.size() - 1].id)

	for i in 3:
		GameSession.assign_adventurer_to_selected_party(warrior_ids[i])
	assert_eq(GameSession.get_selected_party().member_ids.size(), 3, "Setup: party must start full at the Guild Hall level-1 cap")

	# Simulate a Guild Hall upgrade opening a 4th slot, without spending gold.
	GameSession.guild_hall_level = 2

	var sim := CampaignSimScript.new()
	sim._refill_party()

	var member_ids: Array = GameSession.get_selected_party().member_ids
	assert_true(
		scout_id in member_ids,
		"The newly opened 4th slot must go to the roster's already-owned missing-class Scout, not a duplicate Warrior"
	)
	assert_false(
		String(warrior_ids[3]) in member_ids,
		"The leftover 4th starting Warrior must not fill a slot ahead of an already-owned missing-class member"
	)


## --- Task 4: full Warrior/Scout/Cleric triad -------------------------------
## FIELDABLE_CLASSES now covers all three root classes (see campaign_sim.gd),
## and _refill_party() prioritizes recruiting one of each missing class
## before duplicates. This seed was originally 42, hand-verified by a 60-seed
## sweep to build a Temple, recruit a Cleric, field all three classes
## together, and actually cast at least one Cleric spell (Heal/Bless) via
## BattleBot during combat -- not merely to recruit a Cleric and never use
## it.
##
## Re-pinned to 2 by docs/plans/2026-08-21-stage-2-party-readiness/'s
## final-review fix wave: that wave's Fix 1 (wiring class-owned perk effects
## into BattleStateFactory for the first time) plus Fix 5 (lowering
## PERK_LEVEL_INTERVAL 3 -> 2, so both perk slots land earlier) together make
## a simulated party survive combat substantially better -- seed 42 stopped
## fielding the triad or casting a spell at all once perks actually apply,
## because far fewer deaths starve _refill_party()'s death-driven
## recruitment churn (see test_run_campaign_reaches_victory_on_the_
## representative_seed_set's own doc comment for the identical effect on
## REPRESENTATIVE_VICTORY_SEEDS). Seed 2 is the first hit (ascending order,
## not cherry-picked) of a fresh 120-seed throwaway-probe sweep re-run
## against the corrected mechanics; 20/120 seeds in that sweep still
## satisfy victory + triad + spell-cast.
##
## NOTE on party size at first-triad: _purchase_affordable_upgrades()'s
## unmodified priority order (Guild Hall upgrade before Temple, per its own
## doc comment quoting the technical design verbatim) means gold routes to
## Guild Hall upgrades well before a Temple gets built in nearly every run.
## full_triad_party_size is recorded and asserted to be a sane value (>= 3,
## the floor of get_max_party_size()) rather than hardcoded to a single
## observed number.
##
## Re-probed for Stage 5 D2 (docs/plans/2026-08-23-stage-5-strategic-roster-
## expansion/03-tactical-depth-primitives.md): Dodge, Parry, and Attacks of
## Opportunity are new possibilities in every simulated battle (Battle
## StateFactory.build() now seeds dodge_roll/parry_roll from the same per-
## iteration RNG hit_roll/crit_roll/damage_roll already draw from), which
## shifts individual battle outcomes (damage/rounds/deaths) enough to change
## _refill_party()'s death-driven recruitment pacing on a per-seed basis --
## seed 2 stopped fielding the triad or casting a spell once these
## mechanics actually apply, the same class of effect this constant's own
## history above already documents twice for earlier balance changes. Seed 9
## is the first hit (ascending order, not cherry-picked) of the fresh 1-59
## sweep after stationary, unit-transparent missile targeting; 17 of the
## first 59 seeds satisfy victory + triad + spell-cast.
const CLERIC_TRIAD_SEED := 9


func test_run_campaign_fields_the_full_triad_and_records_a_cleric_spell_cast() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(CLERIC_TRIAD_SEED)

	assert_true(
		record.fielded_full_triad,
		"The party must contain one Warrior, one Scout, and one Cleric together at some point in the run"
	)
	assert_true(
		int(record.full_triad_party_size) >= 3,
		"The triad can only form once the party has at least 3 slots (the Guild Hall level-1 floor)"
	)
	assert_gt(record.spell_casts, 0, "At least one Cleric spell (Heal/Bless) must be cast via BattleBot during the run")

	GameSession.reset()
	GameSession.reset_injectable_rolls()
	var second := CampaignSimScript.new().run_campaign(CLERIC_TRIAD_SEED)
	assert_eq(record, second, "Identical seeds must still produce byte-identical telemetry with Cleric fielded")


## --- Task 2: metrics collection and verification ---------------------------

func test_telemetry_records_accurate_battle_counts_gold_income_and_level_curves() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(42)

	assert_eq(record.battles_fought, record.battles_won + record.party_wipes + record.stalemates)
	assert_true(record.battles_won >= GameSession.completed_encounters.size())
	assert_gt(record.gold_earned, 0, "A multi-battle campaign must have earned some gold")
	assert_false(record.party_level_curve.is_empty(), "At least one tier's average party level must be recorded")
	for key in record.party_level_curve:
		assert_gt(float(record.party_level_curve[key]), 0.0, "A recorded tier level must be a real average, not the empty-party sentinel 0.0")


func test_metrics_aggregate_reports_victory_rate_and_failed_seeds_across_runs() -> void:
	var sim := CampaignSimScript.new()
	var seeds: Array[int] = [1, 2]
	var records: Array = []
	for seed in seeds:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records, "sweep", seeds)

	assert_eq(report.runs, 2)
	assert_eq(report.victories, 2)
	assert_almost_eq(report.victory_rate, 1.0, 0.001)
	assert_true(report.failed_seeds.is_empty())
	assert_gt(report.mean_world_turns, 0.0)
	assert_has(report, "mean_party_level_curve")
	assert_has(report, "gold")
	assert_eq(report.mode, "sweep")
	assert_eq(report.seeds, seeds)


## Stage 4 evidence contract (docs/designs/campaign-loop.md § Stage 4
## evidence and presentation contract) pins mean_upgrade_progression_turns as
## a report field a manual-session review must be able to read -- lock its
## presence and shape here so a future metrics refactor can't silently drop
## it the way only format_summary()'s string interpolation would otherwise
## notice.
func test_metrics_aggregate_reports_upgrade_progression_turns() -> void:
	var sim := CampaignSimScript.new()
	var seeds: Array[int] = [1, 2]
	var records: Array = []
	for seed in seeds:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records, "sweep", seeds)

	assert_has(report, "mean_upgrade_progression_turns")
	var upgrade_turns: Dictionary = report.mean_upgrade_progression_turns
	assert_false(upgrade_turns.is_empty(), "A multi-run aggregate must record at least one upgrade's mean completion turn")
	for key in upgrade_turns:
		assert_gt(float(upgrade_turns[key]), 0.0, "A recorded upgrade's mean progression turn must be a real world-turn value, not the empty-run sentinel 0.0")


## Locks in the mode-aware, self-describing evidence requirement (docs/plans/
## 2026-08-19-core-loop-verification-remediation/
## 02-representative-seed-command.md, Task 2): representative-mode evidence
## must name its exact seed list and never print an unqualified "Victories:"
## claim -- it must say "Representative seeds: N/N victories" instead.
func test_metric_output_labels_representative_mode_by_name_not_an_unqualified_victory_claim() -> void:
	var sim := CampaignSimScript.new()
	var seeds: Array[int] = CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS
	var records: Array = []
	for seed in seeds:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records, "representative", seeds)

	var json_text := CampaignSimMetricsScript.to_json(report)
	var parsed = JSON.parse_string(json_text)
	assert_not_null(parsed, "to_json() output must be valid, parseable JSON")
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed.runs), seeds.size())
	assert_eq(String(parsed.mode), "representative")
	assert_eq(int(parsed.seeds.size()), seeds.size())
	assert_true(parsed.has("failed_seeds"))

	var summary := CampaignSimMetricsScript.format_summary(report)
	assert_true(summary.begins_with("Campaign Simulation Summary"))
	assert_true(summary.contains("Representative seeds: %s" % str(seeds)), "Summary must name the exact seed list")
	assert_true(
		summary.contains("Representative seeds: %d/%d victories" % [report.victories, report.runs]),
		"Summary must label its result as representative-set victories, not an unqualified rate"
	)
	assert_false(summary.contains("Victories:"), "The old unqualified 'Victories:' label must be gone")
	assert_false(summary.contains("Sample victory rate"), "Representative mode must not use the sweep-mode label")
	assert_true(summary.contains("Mean world turns"))


## Review Finding 1: Step 1's Cleric telemetry (fielded_full_triad,
## spell_casts) must actually reach aggregate()'s report dict and format_
## summary()'s printed output -- previously it was recorded per-run by
## CampaignSim but silently dropped once campaign_sim_main.gd discarded
## individual records after aggregating, so `make campaign-sim` gave zero
## visibility into whether the Cleric loop ever actually happened.
func test_metrics_aggregate_reports_cleric_triad_and_spell_cast_totals() -> void:
	var sim := CampaignSimScript.new()
	var seeds: Array[int] = CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS
	var records: Array = []
	for seed in seeds:
		GameSession.reset()
		GameSession.reset_injectable_rolls()
		records.append(sim.run_campaign(seed))

	var expected_spell_casts := 0
	var expected_triad_runs := 0
	for record in records:
		expected_spell_casts += int(record.spell_casts)
		if bool(record.fielded_full_triad):
			expected_triad_runs += 1

	var report := CampaignSimMetricsScript.aggregate(records, "representative", seeds)

	assert_eq(int(report.get("total_spell_casts", -1)), expected_spell_casts, "aggregate() must sum spell_casts across records")
	assert_eq(
		int(report.get("runs_with_full_triad", -1)), expected_triad_runs,
		"aggregate() must count how many records have fielded_full_triad == true"
	)

	var summary := CampaignSimMetricsScript.format_summary(report)
	assert_true(
		summary.contains("Full triad fielded: %d/%d runs" % [expected_triad_runs, records.size()]),
		"format_summary() must print the full-triad run count"
	)
	assert_true(
		summary.contains("Total spell casts: %d" % expected_spell_casts),
		"format_summary() must print the total spell-cast count"
	)


## Review Finding 1 (folded-in cleanup): format_summary()'s mode branch was
## an unguarded `else` that silently labeled anything not MODE_SWEEP as
## "Representative", including an unrecognized/empty mode string. It must
## instead explicitly check MODE_REPRESENTATIVE and fall back safely (never
## silently mislabeling) for anything else.
func test_metric_output_does_not_silently_mislabel_an_unrecognized_mode_as_representative() -> void:
	var report := CampaignSimMetricsScript.aggregate([], "bogus_mode", [])

	var summary := CampaignSimMetricsScript.format_summary(report)

	assert_false(summary.contains("Representative seeds:"), "An unrecognized mode must not be silently labeled Representative")
	assert_false(summary.contains("Sweep seeds:"), "An unrecognized mode must not be silently labeled Sweep either")


## Sweep mode is an arbitrary numeric sample, never evidence of universal
## completability -- its percentage must be labelled "Sample victory rate"
## and its seed range must be visible, not disguised as the representative
## set.
func test_metric_output_labels_sweep_mode_as_a_sample_not_a_universal_claim() -> void:
	var sim := CampaignSimScript.new()
	var seeds: Array[int] = [100, 101, 102]
	var records: Array = []
	for seed in seeds:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records, "sweep", seeds)

	var json_text := CampaignSimMetricsScript.to_json(report)
	var parsed = JSON.parse_string(json_text)
	assert_eq(String(parsed.mode), "sweep")
	assert_true(parsed.has("seeds"))
	assert_true(parsed.has("failed_seeds"))

	var summary := CampaignSimMetricsScript.format_summary(report)
	assert_true(summary.contains("Sweep seeds: 100-102"), "Summary must identify the contiguous sweep range")
	assert_true(summary.contains("Sample victory rate:"), "Summary must label the percentage as a sample, not a universal rate")
	assert_false(summary.contains("Representative seeds:"), "Sweep mode must not claim to be the representative set")


## --- Step 2, Task 4: failed-seed details and per-objective summary ranges --

## aggregate() must report more than a bare failing seed *number* -- a
## reviewer comparing seeds needs the reason and headline stats of each
## failure without re-running the sim. Uses hand-built synthetic records
## (not real run_campaign() calls) so this test is fast, deterministic, and
## isolated to aggregate()'s own field-shaping logic -- exactly the same
## "records in, one summary Dictionary out" contract campaign_sim_metrics.gd's
## own header comment describes, independent of what the sim itself produces
## (that end-to-end wiring is covered by test_run_campaign_records_an_
## ordered_per_objective_record_with_full_evidence() above).
func test_metrics_aggregate_reports_failed_seed_details_and_per_objective_summary_ranges() -> void:
	var records: Array = [
		{
			"seed": 1, "victory": true, "reason": "victory", "world_turns": 10,
			"battles_fought": 2, "battles_won": 2, "party_wipes": 0,
			"objective_records": [
				{"objective_id": "obj_tier1_1_goblin_outpost", "outcome": "victory", "world_turn_start": 1, "world_turn_end": 4, "hp_recovered": 2, "mp_recovered": 0},
				{"objective_id": "obj_tier1_2_kobold_warren", "outcome": "victory", "world_turn_start": 4, "world_turn_end": 10, "hp_recovered": 6, "mp_recovered": 1},
			],
		},
		{
			"seed": 2, "victory": false, "reason": "max_attempts_exceeded", "world_turns": 55,
			"battles_fought": 3, "battles_won": 1, "party_wipes": 2,
			"objective_records": [
				{"objective_id": "obj_tier1_1_goblin_outpost", "outcome": "defeat", "world_turn_start": 1, "world_turn_end": 8, "hp_recovered": 0, "mp_recovered": 0},
			],
		},
	]

	var report := CampaignSimMetricsScript.aggregate(records, CampaignSimMetricsScript.MODE_SWEEP, [1, 2])

	# Failed-seed details: a Dictionary per failure, not a bare seed int.
	assert_eq(report.failed_seeds.size(), 1)
	var failure: Dictionary = report.failed_seeds[0]
	assert_true(failure is Dictionary, "failed_seeds entries must be detail dictionaries, not bare seed ints")
	assert_eq(int(failure.seed), 2)
	assert_eq(String(failure.reason), "max_attempts_exceeded")
	assert_eq(int(failure.world_turns), 55)
	assert_eq(int(failure.battles_fought), 3)
	assert_eq(int(failure.battles_won), 1)
	assert_eq(int(failure.party_wipes), 2)

	# Per-objective summary ranges: attempts/victories plus a world-turn-span
	# min/mean/max range per objective across every run, not a single
	# averaged number that hides how much a node's pacing actually varies.
	assert_true(report.has("per_objective_summary"), "aggregate() must report a per-objective summary")
	var per_objective: Dictionary = report.per_objective_summary
	assert_true(per_objective.has("obj_tier1_1_goblin_outpost"))
	var outpost: Dictionary = per_objective.obj_tier1_1_goblin_outpost
	assert_eq(int(outpost.attempts), 2, "obj_tier1_1_goblin_outpost was attempted in both records")
	assert_eq(int(outpost.victories), 1, "obj_tier1_1_goblin_outpost was only won in the seed-1 record")
	assert_almost_eq(float(outpost.world_turn_span_min), 3.0, 0.001, "min(4-1, 8-1) == 3")
	assert_almost_eq(float(outpost.world_turn_span_max), 7.0, 0.001, "max(3, 7) == 7")
	assert_almost_eq(float(outpost.world_turn_span_mean), 5.0, 0.001, "(3+7)/2 == 5")

	assert_true(per_objective.has("obj_tier1_2_kobold_warren"))
	var warren: Dictionary = per_objective.obj_tier1_2_kobold_warren
	assert_eq(int(warren.attempts), 1)
	assert_eq(int(warren.victories), 1)

	# Both new fields must survive JSON round-tripping and the mode label
	# must stay correct alongside them -- the new fields must never come at
	# the cost of the existing mode-aware, self-describing contract.
	var json_text := CampaignSimMetricsScript.to_json(report)
	var parsed = JSON.parse_string(json_text)
	assert_not_null(parsed, "to_json() output must still be valid, parseable JSON with the new fields present")
	assert_true(parsed.has("per_objective_summary"), "JSON report must include per_objective_summary")
	assert_true(parsed.has("failed_seeds"))
	assert_eq(String(parsed.mode), CampaignSimMetricsScript.MODE_SWEEP)


## --- Stage 6 Step 2 (decision-ledger.md PartyCarry/BattleContext) ---------

## Proves party-owned carry isolation through CampaignSim's own scene-free
## battle path, not just GameSession's direct unit tests: Party A fights and
## banks its own loot while Party B, independently deployed via the same
## select_party()-then-call pattern _fight_objective()/deposit_party_carry()
## already support (both take/imply an explicit party_id -- see game_
## session.gd's create_battle_context()/get_party_carry()/deposit_party_
## carry()), keeps its own untouched carry throughout. Two parties require
## GUILD_HALL_MAX_LEVEL (see get_max_party_count()), exactly like GameSession's
## own test_forfeit_party_carry_never_touches_a_different_partys_carry().
func test_two_deployed_parties_carry_and_bank_loot_independently() -> void:
	GameSession.create_party()
	var party_a_id: String = GameSession.selected_party_id
	for adventurer in GameSession.adventurers.duplicate():
		GameSession.assign_adventurer_to_selected_party(String(adventurer.id))
	GameSession.deploy_party(party_a_id)

	GameSession.guild_hall_level = GameSession.GUILD_HALL_MAX_LEVEL
	GameSession.recruit_adventurer()
	GameSession.create_party()
	var party_b_id: String = GameSession.selected_party_id
	var recruit_id: String = String(GameSession.adventurers[GameSession.adventurers.size() - 1].id)
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	GameSession.deploy_party(party_b_id)
	GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position, party_b_id)

	GameSession.select_party(party_a_id)
	var sim := CampaignSimScript.new()
	var telemetry := sim._new_telemetry(4242)
	var outcome := sim._fight_objective(GameSession.GOBLIN_CAMP_ID, telemetry)
	assert_eq(outcome, "victory", "The full starting 4-Warrior party must win the first tier-1 sandbox objective")

	assert_gt(GameSession.get_party_carry(party_a_id).gold, 0, "Party A's carry must hold its own battle reward gold")
	assert_eq(GameSession.get_party_carry(party_b_id).gold, 0, "Party B's carry must be untouched by Party A's battle")

	var bank_before: int = GameSession.gold
	GameSession.deposit_party_carry(party_a_id)
	assert_gt(GameSession.gold, bank_before, "Party A's banked gold must reach the shared Encampment bank")
	assert_eq(GameSession.get_party_carry(party_a_id).gold, 0, "Party A's own carry must be empty once banked")

	assert_true(GameSession.has_deployed_party(party_b_id), "Party B must remain deployed in the field, undisturbed by Party A's return")
	assert_eq(GameSession.get_party_carry(party_b_id).gold, 0, "Party B's carry must remain independently empty after Party A's own carry is banked")


## --- Stage 6 Step 3: CampaignSim parity against ContentCatalog ------------
## (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 03-authored-content-catalog.md, task 6). CampaignSim is a wholly separate
## battle-construction path from BattleController._ready() -- see that
## file's own sibling test in test_battle_controller.gd -- so a catalog
## change reflected in one but not the other is exactly the drift class this
## step's own task brief calls out by name (the same class of bug Step 2's
## review found: a green suite that never actually exercised the second
## caller). This proves _build_scenario() derives board/cover/spawn tiles
## from the SAME catalog definition BattleController reads, not still from
## ScenarioContract's generic DEFAULT_BOARD_WIDTH/HEIGHT/PLAYER_START_
## POSITIONS/ENEMY_START_POSITIONS fallback.
func test_campaign_sims_scenario_for_the_migrated_encounter_matches_its_catalog_definition_exactly() -> void:
	var definition := ContentCatalogScript.get_encounter_definition("obj_tier1_1_goblin_outpost")
	assert_false(definition.is_empty(), "Setup: obj_tier1_1_goblin_outpost must be a real catalog entry")

	GameSession.create_party()
	for adventurer in GameSession.adventurers.slice(0, 3):
		GameSession.assign_adventurer_to_selected_party(String(adventurer.id))

	var sim := CampaignSimScript.new()
	var expedition := GameSession.get_expedition("obj_tier1_1_goblin_outpost")
	var scenario: Dictionary = sim._build_scenario("obj_tier1_1_goblin_outpost", expedition)

	assert_eq(scenario.board.width, definition.grid_size.width)
	assert_eq(scenario.board.height, definition.grid_size.height)
	var cover_by_position: Dictionary = {}
	for cover_entry in (scenario.board.cover as Array):
		cover_by_position[ScenarioContractScript.position_from_dict(cover_entry.position)] = cover_entry.tier
	assert_eq(cover_by_position, definition.cover_tiles)

	var player_positions: Array[Vector2i] = []
	for unit_spec in (scenario.player.units as Array):
		player_positions.append(ScenarioContractScript.position_from_dict(unit_spec.position))
	assert_eq(player_positions, definition.player_spawns.slice(0, player_positions.size()))

	var enemy_positions: Array[Vector2i] = []
	for unit_spec in (scenario.enemy.units as Array):
		enemy_positions.append(ScenarioContractScript.position_from_dict(unit_spec.position))
	assert_eq(enemy_positions, definition.enemy_spawns.slice(0, enemy_positions.size()))
	assert_eq(enemy_positions.size(), 3, "goblin x1 + kobold x2, per the catalog's own enemy_composition")
