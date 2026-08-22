extends GutTest
## Covers scripts/tools/campaign_sim.gd (CampaignSim) and scripts/tools/
## campaign_sim_metrics.gd (CampaignSimMetrics) -- the headless, scene-free
## campaign-level simulator and its telemetry aggregator (docs/plans/
## 2026-08-18-core-loop-and-engagement/06-campaign-simulation-and-balance-
## harness.md).

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const CampaignSimMetricsScript := preload("res://scripts/tools/campaign_sim_metrics.gd")

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

	func _build_player_units() -> Array:
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

	func _build_enemy_units(_expedition: Dictionary) -> Array:
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
## Guild Hall upgrades well before a Temple gets built in nearly every run --
## seed 2 itself lands at the level-3 cap of 5. full_triad_party_size is
## still recorded and asserted to be a sane value (>= 3, the floor of
## get_max_party_size()) rather than hardcoded to a single observed number.
const CLERIC_TRIAD_SEED := 2


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
