extends GutTest
## Covers scripts/tools/campaign_sim.gd (CampaignSim) and scripts/tools/
## campaign_sim_metrics.gd (CampaignSimMetrics) -- the headless, scene-free
## campaign-level simulator and its telemetry aggregator (docs/plans/
## 2026-08-18-core-loop-and-engagement/06-campaign-simulation-and-balance-
## harness.md).

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const CampaignSimMetricsScript := preload("res://scripts/tools/campaign_sim_metrics.gd")

## The representative seed set CampaignSim's own bot/gear/upgrade policy is
## verified (below) to carry all the way to Final Boss victory. Per the step
## doc's own task-list wording ("reach victory on an explicitly listed
## representative seed set ... report failures for every other seed; do not
## claim a universal completion percentage from ten arbitrary samples"), this
## is a deliberately small, hand-verified set -- not a claim that every seed
## outside it fails, only that these are the ones this suite locks a victory
## guarantee to.
##
## A wider sweep (seeds 1-80, re-run after the Step 6 review's fix addendum
## -- see this step's report for the full table) shows the campaign is
## completable on nearly every seed (78/80 in that range; only seeds 3 and
## 25 fail). That's a sharp rise from the original report's 60-65%, and not
## from the two review findings' reorderings alone: fixing them surfaced a
## third, previously-undiscovered bug in the same code -- _fight_objective()'s
## `kill_xp` accumulator was a GDScript lambda closure over a plain float,
## which GDScript captures BY VALUE, so every battle's kill XP was silently
## discarded and only clear_xp was ever actually awarded (see the report's
## fix addendum for the full explanation and fix). Restoring the missing
## kill XP raises the leveling pace enough that the pre-Boss repeated-wipe
## spiral this suite originally locked seeds 1/2/5/7 out of essentially
## stops happening. Seeds 4, 9, 10, 12, and 14 are the first five winning
## seeds in the post-fix sweep, chosen in ascending order rather than
## cherry-picked for any other property.
const REPRESENTATIVE_VICTORY_SEEDS: Array[int] = [4, 9, 10, 12, 14]


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
func test_run_campaign_reaches_victory_on_the_representative_seed_set() -> void:
	for seed in REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
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


## --- Task 4: full Warrior/Scout/Cleric triad -------------------------------
## FIELDABLE_CLASSES now covers all three root classes (see campaign_sim.gd),
## and _refill_party() prioritizes recruiting one of each missing class
## before duplicates. This seed is hand-verified (a 60-seed sweep via a
## throwaway probe script, all landing on record.victory == true) to build a
## Temple, recruit a Cleric, field all three classes together, and actually
## cast at least one Cleric spell (Heal/Bless) via BattleBot during combat --
## not merely to recruit a Cleric and never use it.
##
## NOTE on party size at first-triad: _purchase_affordable_upgrades()'s
## unmodified priority order (Guild Hall upgrade before Temple, per its own
## doc comment quoting the technical design verbatim) means gold routes to
## Guild Hall upgrades well before a Temple gets built in nearly every run --
## across the same 60-seed sweep, the party had already grown past the
## initial 3-slot Guild-Hall-level-1 cap in 56 of the 58 seeds where the
## triad formed at all (most commonly landing at the level-3 cap of 5, one
## outlier at 4; only seed 39 stayed at 3). So "fields the triad at the
## three-slot cap" the way a hand-played early game might is not what this
## unmodified, out-of-scope-to-reorder upgrade-purchase policy actually
## produces -- this is flagged as a concern rather than forced by reordering
## that unrelated priority list. full_triad_party_size is still recorded and
## asserted to be a sane value (>= 3, the floor of get_max_party_size()).
const CLERIC_TRIAD_SEED := 42


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
	var records: Array = []
	for seed in [1, 2]:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records)

	assert_eq(report.runs, 2)
	assert_eq(report.victories, 2)
	assert_almost_eq(report.victory_rate, 1.0, 0.001)
	assert_true(report.failed_seeds.is_empty())
	assert_gt(report.mean_world_turns, 0.0)
	assert_has(report, "mean_party_level_curve")
	assert_has(report, "gold")


func test_metric_output_generates_formatted_json_and_summary_report() -> void:
	var sim := CampaignSimScript.new()
	var report := CampaignSimMetricsScript.aggregate([sim.run_campaign(42)])

	var json_text := CampaignSimMetricsScript.to_json(report)
	var parsed = JSON.parse_string(json_text)
	assert_not_null(parsed, "to_json() output must be valid, parseable JSON")
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed.runs), 1)

	var summary := CampaignSimMetricsScript.format_summary(report)
	assert_true(summary.begins_with("Campaign Simulation Summary"))
	assert_true(summary.contains("Victories:"))
	assert_true(summary.contains("Mean world turns"))
