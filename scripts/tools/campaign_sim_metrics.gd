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


## records: an Array of CampaignSim.run_campaign() result Dictionaries.
static func aggregate(records: Array) -> Dictionary:
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

	for record in records:
		if bool(record.get("victory", false)):
			victories += 1
		else:
			failed_seeds.append(record.get("seed", -1))
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

	var level_curve_avg := {}
	for key in level_curve_sums:
		level_curve_avg[key] = float(level_curve_sums[key]) / float(level_curve_counts[key])
	var upgrade_turn_avg := {}
	for key in upgrade_turn_sums:
		upgrade_turn_avg[key] = float(upgrade_turn_sums[key]) / float(upgrade_turn_counts[key])

	return {
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
	}


static func to_json(report: Dictionary) -> String:
	return JSON.stringify(report, "  ")


## A short, human-readable multi-line report -- what `make campaign-sim`
## prints to the terminal (see campaign_sim_main.gd).
static func format_summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Campaign Simulation Summary")
	lines.append("  Runs: %d" % int(report.get("runs", 0)))
	lines.append(
		"  Victories: %d/%d (%.0f%%)"
		% [int(report.get("victories", 0)), int(report.get("runs", 0)), float(report.get("victory_rate", 0.0)) * 100.0]
	)
	var failed_seeds: Array = report.get("failed_seeds", [])
	if not failed_seeds.is_empty():
		lines.append("  Failed seeds: %s" % str(failed_seeds))
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
	return "\n".join(lines)
