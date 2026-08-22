class_name CampaignSimMetrics
extends RefCounted
## Aggregates N CampaignSim.run_campaign() telemetry Dictionaries into one
## balance report -- the same "records in, one summary Dictionary out"
## shape scripts/tools/battle_scenarios/report_aggregator.gd already
## establishes for the single-battle scenario harness, extended with the
## campaign-level metrics docs/plans/2026-08-18-core-loop-and-engagement/
## 06-campaign-simulation-and-balance-harness.md's technical design calls
## for: mean turns to victory, gold velocity, upgrade-progression turns, and
## party level curve.
##
## Mode-aware, self-describing evidence (docs/plans/2026-08-19-core-loop-
## verification-remediation/02-representative-seed-command.md): the caller
## (campaign_sim_main.gd, which parsed the CLI args) tells aggregate() and
## format_summary() whether `records` came from MODE_REPRESENTATIVE (an
## explicit, named seed list) or MODE_SWEEP (an arbitrary contiguous numeric
## sample) so the report can never mislabel one as the other -- this module
## does not re-derive the mode from the seed values itself.

const MODE_REPRESENTATIVE := "representative"
const MODE_SWEEP := "sweep"


## records: an Array of CampaignSim.run_campaign() result Dictionaries.
## mode: MODE_REPRESENTATIVE or MODE_SWEEP -- see this file's header comment.
## seeds: the exact ordered seed list `records` was produced from.
static func aggregate(records: Array, mode: String, seeds: Array) -> Dictionary:
	var runs := records.size()
	var victories := 0
	var failed_seeds: Array = []
	var world_turns_total := 0
	var battles_fought_total := 0
	var battles_won_total := 0
	var battles_retreated_total := 0
	var stalemates_total := 0
	var party_wipes_total := 0
	var unit_deaths_total := 0
	var gold_earned_total := 0
	var gold_spent_upgrades_total := 0
	var gold_spent_recruits_total := 0
	var gold_spent_gear_total := 0
	var gold_lost_wipes_total := 0
	var level_curve_sums := {}
	var level_curve_counts := {}
	var upgrade_turn_sums := {}
	var upgrade_turn_counts := {}
	var total_spell_casts := 0
	var runs_with_full_triad := 0
	# Per-objective summary ranges (docs/plans/2026-08-22-stage-3-campaign-
	# assembly/02-campaign-telemetry-and-comparison.md, Task 4): objective_id
	# -> {attempts, victories, world_turn_span_min/_max, a running sum for
	# the mean computed below}. Sourced from each record's own CampaignSim.
	# objective_records (see that file's run_campaign() hook) -- a run
	# produced by an older telemetry shape with no objective_records key
	# simply contributes nothing here (record.get(..., []) below), not an
	# error, so this stays compatible with any pre-existing saved record.
	var per_objective: Dictionary = {}

	for record in records:
		if bool(record.get("victory", false)):
			victories += 1
		else:
			# A bare seed number tells a reviewer *which* run failed but not
			# *why* -- pairing it with the run's own reason/headline stats
			# (still available on `record` at this point) lets a reviewer
			# read a failure's shape straight off the aggregate report
			# without re-running that seed.
			failed_seeds.append({
				"seed": record.get("seed", -1),
				"reason": record.get("reason", ""),
				"world_turns": int(record.get("world_turns", 0)),
				"battles_fought": int(record.get("battles_fought", 0)),
				"battles_won": int(record.get("battles_won", 0)),
				"party_wipes": int(record.get("party_wipes", 0)),
			})
		total_spell_casts += int(record.get("spell_casts", 0))
		if bool(record.get("fielded_full_triad", false)):
			runs_with_full_triad += 1
		world_turns_total += int(record.get("world_turns", 0))
		battles_fought_total += int(record.get("battles_fought", 0))
		battles_won_total += int(record.get("battles_won", 0))
		battles_retreated_total += int(record.get("battles_retreated", 0))
		stalemates_total += int(record.get("stalemates", 0))
		party_wipes_total += int(record.get("party_wipes", 0))
		unit_deaths_total += int(record.get("unit_deaths", 0))
		gold_earned_total += int(record.get("gold_earned", 0))
		gold_spent_upgrades_total += int(record.get("gold_spent_upgrades", 0))
		gold_spent_recruits_total += int(record.get("gold_spent_recruits", 0))
		gold_spent_gear_total += int(record.get("gold_spent_gear", 0))
		gold_lost_wipes_total += int(record.get("gold_lost_wipes", 0))

		var level_curve: Dictionary = record.get("party_level_curve", {})
		for key in level_curve:
			level_curve_sums[key] = float(level_curve_sums.get(key, 0.0)) + float(level_curve[key])
			level_curve_counts[key] = int(level_curve_counts.get(key, 0)) + 1

		var upgrade_turns: Dictionary = record.get("upgrade_progression_turns", {})
		for key in upgrade_turns:
			upgrade_turn_sums[key] = int(upgrade_turn_sums.get(key, 0)) + int(upgrade_turns[key])
			upgrade_turn_counts[key] = int(upgrade_turn_counts.get(key, 0)) + 1

		var objective_records: Array = record.get("objective_records", [])
		for entry in objective_records:
			var objective_id := String(entry.get("objective_id", ""))
			if not per_objective.has(objective_id):
				per_objective[objective_id] = {
					"attempts": 0, "victories": 0,
					"world_turn_span_min": INF, "world_turn_span_max": -INF, "world_turn_span_sum": 0.0,
				}
			var bucket: Dictionary = per_objective[objective_id]
			bucket.attempts = int(bucket.attempts) + 1
			if String(entry.get("outcome", "")) == "victory":
				bucket.victories = int(bucket.victories) + 1
			var span := float(int(entry.get("world_turn_end", 0)) - int(entry.get("world_turn_start", 0)))
			bucket.world_turn_span_min = minf(float(bucket.world_turn_span_min), span)
			bucket.world_turn_span_max = maxf(float(bucket.world_turn_span_max), span)
			bucket.world_turn_span_sum = float(bucket.world_turn_span_sum) + span

	var level_curve_avg := {}
	for key in level_curve_sums:
		level_curve_avg[key] = float(level_curve_sums[key]) / float(level_curve_counts[key])
	var upgrade_turn_avg := {}
	for key in upgrade_turn_sums:
		upgrade_turn_avg[key] = float(upgrade_turn_sums[key]) / float(upgrade_turn_counts[key])

	# world_turn_span_mean added as a final pass (not accumulated inline
	# above) so the running sum stays a plain float the whole time, mirroring
	# level_curve_avg/upgrade_turn_avg's identical sum-then-divide shape.
	for objective_id in per_objective:
		var bucket: Dictionary = per_objective[objective_id]
		bucket.world_turn_span_mean = float(bucket.world_turn_span_sum) / float(maxi(1, int(bucket.attempts)))

	return {
		"mode": mode,
		"seeds": seeds,
		"runs": runs,
		"victories": victories,
		"victory_rate": float(victories) / float(maxi(1, runs)),
		"failed_seeds": failed_seeds,
		"mean_world_turns": float(world_turns_total) / float(maxi(1, runs)),
		"mean_battles_fought": float(battles_fought_total) / float(maxi(1, runs)),
		"mean_battles_won": float(battles_won_total) / float(maxi(1, runs)),
		"total_battles_retreated": battles_retreated_total,
		"total_stalemates": stalemates_total,
		"total_party_wipes": party_wipes_total,
		"total_unit_deaths": unit_deaths_total,
		"gold": {
			"earned_total": gold_earned_total,
			"spent_upgrades_total": gold_spent_upgrades_total,
			"spent_recruits_total": gold_spent_recruits_total,
			"spent_gear_total": gold_spent_gear_total,
			"lost_wipes_total": gold_lost_wipes_total,
		},
		"mean_party_level_curve": level_curve_avg,
		"mean_upgrade_progression_turns": upgrade_turn_avg,
		# Cleric-loop coverage (docs/plans/2026-08-19-core-loop-verification-
		# remediation/01-cleric-scenario-and-campaign-sim.md): how many of
		# these runs ever fielded the full Warrior/Scout/Cleric triad
		# together (CampaignSim._record_full_triad()), and how many total
		# spell casts (Heal/Bless) happened across all of them -- surfaced
		# here so `make campaign-sim` evidence actually reports on whether
		# the Cleric loop happened, not just whether the campaign was won.
		"runs_with_full_triad": runs_with_full_triad,
		"total_spell_casts": total_spell_casts,
		# Per-objective summary ranges (see this function's own comment
		# above): objective_id -> {attempts, victories, world_turn_span_min/
		# _mean/_max}. A reviewer uses this to see how much a single node's
		# pacing actually varies across the aggregated runs, not just one
		# hidden-variance averaged number.
		"per_objective_summary": per_objective,
	}


static func to_json(report: Dictionary) -> String:
	return JSON.stringify(report, "  ")


## A short, human-readable multi-line report -- what `make campaign-sim`
## prints to the terminal (see campaign_sim_main.gd). Mode-aware: never
## prints an unqualified "Victories: N (X%)" claim -- representative mode
## names its exact seed list and reports "Representative seeds: N/N
## victories"; sweep mode identifies its contiguous seed range and reports
## "Sample victory rate", making clear it is an arbitrary sample, not
## evidence of universal completability.
static func format_summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Campaign Simulation Summary")
	lines.append("  Runs: %d" % int(report.get("runs", 0)))
	var mode: String = String(report.get("mode", ""))
	var seeds: Array = report.get("seeds", [])
	var victories := int(report.get("victories", 0))
	var runs := int(report.get("runs", 0))
	if mode == MODE_SWEEP:
		if seeds.is_empty():
			lines.append("  Sweep seeds: (none)")
		else:
			lines.append("  Sweep seeds: %s-%s (%d runs)" % [str(seeds[0]), str(seeds[seeds.size() - 1]), runs])
		lines.append(
			"  Sample victory rate: %d/%d (%.0f%%)"
			% [victories, runs, float(report.get("victory_rate", 0.0)) * 100.0]
		)
	elif mode == MODE_REPRESENTATIVE:
		lines.append("  Representative seeds: %s" % str(seeds))
		lines.append("  Representative seeds: %d/%d victories" % [victories, runs])
	else:
		# Explicit fallback, not a silent "anything not sweep is
		# Representative" -- an unrecognized/empty mode string must never
		# be mislabeled as the hand-verified representative set.
		lines.append("  Unrecognized mode '%s' -- seeds: %s  %d/%d victories" % [mode, str(seeds), victories, runs])
	lines.append(
		"  Full triad fielded: %d/%d runs  Total spell casts: %d"
		% [int(report.get("runs_with_full_triad", 0)), runs, int(report.get("total_spell_casts", 0))]
	)
	var failed_seeds: Array = report.get("failed_seeds", [])
	if not failed_seeds.is_empty():
		lines.append("  Failed seeds:")
		for failure in failed_seeds:
			var detail: Dictionary = failure
			lines.append(
				"    seed=%s reason=%s (world_turns=%s, battles=%s/%s won, wipes=%s)"
				% [
					str(detail.get("seed", "?")), str(detail.get("reason", "")),
					str(detail.get("world_turns", 0)), str(detail.get("battles_won", 0)),
					str(detail.get("battles_fought", 0)), str(detail.get("party_wipes", 0)),
				]
			)
	lines.append("  Mean world turns to resolution: %.1f" % float(report.get("mean_world_turns", 0.0)))
	lines.append(
		"  Mean battles fought / won: %.1f / %.1f"
		% [float(report.get("mean_battles_fought", 0.0)), float(report.get("mean_battles_won", 0.0))]
	)
	lines.append("  Total battles retreated: %d" % int(report.get("total_battles_retreated", 0)))
	lines.append("  Total stalemates: %d" % int(report.get("total_stalemates", 0)))
	lines.append("  Total party wipes: %d" % int(report.get("total_party_wipes", 0)))
	lines.append("  Total unit deaths: %d" % int(report.get("total_unit_deaths", 0)))
	var gold: Dictionary = report.get("gold", {})
	lines.append(
		"  Gold earned: %d  spent upgrades: %d  spent recruits: %d  spent gear: %d  lost to wipes: %d"
		% [
			int(gold.get("earned_total", 0)), int(gold.get("spent_upgrades_total", 0)),
			int(gold.get("spent_recruits_total", 0)), int(gold.get("spent_gear_total", 0)),
			int(gold.get("lost_wipes_total", 0)),
		]
	)
	lines.append("  Mean party level curve: %s" % str(report.get("mean_party_level_curve", {})))
	lines.append("  Mean upgrade progression turns: %s" % str(report.get("mean_upgrade_progression_turns", {})))
	var per_objective: Dictionary = report.get("per_objective_summary", {})
	if not per_objective.is_empty():
		lines.append("  Per-objective world-turn span (min/mean/max), attempts, victories:")
		for objective_id in per_objective:
			var bucket: Dictionary = per_objective[objective_id]
			lines.append(
				"    %s: %.0f/%.1f/%.0f turns, %d/%d victories"
				% [
					String(objective_id), float(bucket.get("world_turn_span_min", 0.0)),
					float(bucket.get("world_turn_span_mean", 0.0)), float(bucket.get("world_turn_span_max", 0.0)),
					int(bucket.get("victories", 0)), int(bucket.get("attempts", 0)),
				]
			)
	return "\n".join(lines)
