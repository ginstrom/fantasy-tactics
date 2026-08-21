extends Node

## Emitted whenever campaign_objective_id, completed_objectives,
## unlocked_authored_encounters, is_campaign_completed, or
## is_free_play_active changes (see complete_campaign_objective() and
## set_campaign_victory()) so a UI component (e.g. CampaignObjectiveBanner)
## can refresh itself without polling.
signal campaign_progress_changed
## Emitted exactly once per campaign -- the moment set_campaign_victory()
## first flips is_campaign_completed/is_free_play_active true. Its early-
## return guard is what keeps this to a single emission even if complete_
## campaign_objective() is ever called again for the final node (already
## a no-op past the first call -- see is_objective_completed()'s guard).
## Battlefield routes to the Campaign Victory screen off the same is_
## campaign_completed flip (see _finish_victory()), not this signal
## directly, but it exists as the single unambiguous "the campaign was
## just won" event for any other listener/test.
signal campaign_victory

const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(3, 3)
const STARTING_GOLD := 200
const GOBLIN_CAMP_ID := "goblin_camp"
const ORC_OUTPOST_ID := "orc_outpost"
const RUINED_FORTRESS_ID := "ruined_fortress"

# First-campaign guide message ids (see get_campaign_guide_state() near the
# bottom of this file and docs/plans/2026-08-10-initial-campaign-and-
# automation/04-first-campaign-guidance.md). Order matters: it's the
# priority scan order get_campaign_guide_state() walks.
const CAMPAIGN_GUIDE_FORM_PARTY := "form_party"
const CAMPAIGN_GUIDE_DEPLOY := "deploy"
const CAMPAIGN_GUIDE_SELECT_ROUTE := "select_route"
const CAMPAIGN_GUIDE_ENTER_SITE := "enter_site"
const CAMPAIGN_GUIDE_RETURN_BANK := "return_bank"
const CAMPAIGN_GUIDE_FIRST_IMPROVEMENT := "first_improvement"
const CAMPAIGN_GUIDE_SEQUENCE: Array[String] = [
	CAMPAIGN_GUIDE_FORM_PARTY,
	CAMPAIGN_GUIDE_DEPLOY,
	CAMPAIGN_GUIDE_SELECT_ROUTE,
	CAMPAIGN_GUIDE_ENTER_SITE,
	CAMPAIGN_GUIDE_RETURN_BANK,
	CAMPAIGN_GUIDE_FIRST_IMPROVEMENT,
]

## The complete, immutable authored-node catalog for the first campaign (see
## docs/designs/campaign-loop.md and docs/plans/2026-08-18-core-loop-and-
## engagement/01-campaign-state-and-onboarding.md). This step is the sole
## owner of every objective id and encounter id below -- later steps (the
## authored-encounter-ladder and final-boss step in particular) fill in each
## node's exact enemy composition, balance numbers, and narrative copy, but
## must never rename or renumber a node, since campaign_objective_id/
## completed_objectives/unlocked_authored_encounters persist these ids
## directly in save data.
##
## Twelve nodes total: three tiers of three (tier 1-3), a two-battle
## pre-boss sequence (tier 4), and the final boss (tier 5). Each node's own
## "encounter_id" mirrors its own key -- a later step's authored battle
## reads this id to know which objective it completes. "prerequisite_id" is
## the id of the node that must be completed first ("" only for the very
## first node); "next_objective_id" is its forward link, mirrored so
## complete_campaign_objective() never has to search the table. Only
## obj_tier1_1_goblin_outpost's title/desc/reward keys are translated this
## step (see translations/en.tres) -- the rest are stable keys reserved for
## the content a later step adds.
const CAMPAIGN_OBJECTIVES: Dictionary = {
	"obj_tier1_1_goblin_outpost": {
		"title_key": "campaign.obj.tier1_1.title",
		"desc_key": "campaign.obj.tier1_1.desc",
		"tier": 1,
		"encounter_id": "obj_tier1_1_goblin_outpost",
		"prerequisite_id": "",
		"next_objective_id": "obj_tier1_2_kobold_warren",
		"reward_summary_key": "campaign.obj.tier1_1.reward",
	},
	"obj_tier1_2_kobold_warren": {
		"title_key": "campaign.obj.tier1_2.title",
		"desc_key": "campaign.obj.tier1_2.desc",
		"tier": 1,
		"encounter_id": "obj_tier1_2_kobold_warren",
		"prerequisite_id": "obj_tier1_1_goblin_outpost",
		"next_objective_id": "obj_tier1_3_goblin_warcamp",
		"reward_summary_key": "campaign.obj.tier1_2.reward",
	},
	"obj_tier1_3_goblin_warcamp": {
		"title_key": "campaign.obj.tier1_3.title",
		"desc_key": "campaign.obj.tier1_3.desc",
		"tier": 1,
		"encounter_id": "obj_tier1_3_goblin_warcamp",
		"prerequisite_id": "obj_tier1_2_kobold_warren",
		"next_objective_id": "obj_tier2_1_orc_outpost",
		"reward_summary_key": "campaign.obj.tier1_3.reward",
	},
	"obj_tier2_1_orc_outpost": {
		"title_key": "campaign.obj.tier2_1.title",
		"desc_key": "campaign.obj.tier2_1.desc",
		"tier": 2,
		"encounter_id": "obj_tier2_1_orc_outpost",
		"prerequisite_id": "obj_tier1_3_goblin_warcamp",
		"next_objective_id": "obj_tier2_2_orc_warband",
		"reward_summary_key": "campaign.obj.tier2_1.reward",
	},
	"obj_tier2_2_orc_warband": {
		"title_key": "campaign.obj.tier2_2.title",
		"desc_key": "campaign.obj.tier2_2.desc",
		"tier": 2,
		"encounter_id": "obj_tier2_2_orc_warband",
		"prerequisite_id": "obj_tier2_1_orc_outpost",
		"next_objective_id": "obj_tier2_3_brute_stronghold",
		"reward_summary_key": "campaign.obj.tier2_2.reward",
	},
	"obj_tier2_3_brute_stronghold": {
		"title_key": "campaign.obj.tier2_3.title",
		"desc_key": "campaign.obj.tier2_3.desc",
		"tier": 2,
		"encounter_id": "obj_tier2_3_brute_stronghold",
		"prerequisite_id": "obj_tier2_2_orc_warband",
		"next_objective_id": "obj_tier3_1_hobgoblin_command",
		"reward_summary_key": "campaign.obj.tier2_3.reward",
	},
	"obj_tier3_1_hobgoblin_command": {
		"title_key": "campaign.obj.tier3_1.title",
		"desc_key": "campaign.obj.tier3_1.desc",
		"tier": 3,
		"encounter_id": "obj_tier3_1_hobgoblin_command",
		"prerequisite_id": "obj_tier2_3_brute_stronghold",
		"next_objective_id": "obj_tier3_2_mixed_forces_ambush",
		"reward_summary_key": "campaign.obj.tier3_1.reward",
	},
	"obj_tier3_2_mixed_forces_ambush": {
		"title_key": "campaign.obj.tier3_2.title",
		"desc_key": "campaign.obj.tier3_2.desc",
		"tier": 3,
		"encounter_id": "obj_tier3_2_mixed_forces_ambush",
		"prerequisite_id": "obj_tier3_1_hobgoblin_command",
		"next_objective_id": "obj_tier3_3_ruined_fortress",
		"reward_summary_key": "campaign.obj.tier3_2.reward",
	},
	"obj_tier3_3_ruined_fortress": {
		"title_key": "campaign.obj.tier3_3.title",
		"desc_key": "campaign.obj.tier3_3.desc",
		"tier": 3,
		"encounter_id": "obj_tier3_3_ruined_fortress",
		"prerequisite_id": "obj_tier3_2_mixed_forces_ambush",
		"next_objective_id": "obj_preboss_1_borderlands_vanguard",
		"reward_summary_key": "campaign.obj.tier3_3.reward",
	},
	"obj_preboss_1_borderlands_vanguard": {
		"title_key": "campaign.obj.preboss_1.title",
		"desc_key": "campaign.obj.preboss_1.desc",
		"tier": 4,
		"encounter_id": "obj_preboss_1_borderlands_vanguard",
		"prerequisite_id": "obj_tier3_3_ruined_fortress",
		"next_objective_id": "obj_preboss_2_borderlands_stronghold",
		"reward_summary_key": "campaign.obj.preboss_1.reward",
	},
	"obj_preboss_2_borderlands_stronghold": {
		"title_key": "campaign.obj.preboss_2.title",
		"desc_key": "campaign.obj.preboss_2.desc",
		"tier": 4,
		"encounter_id": "obj_preboss_2_borderlands_stronghold",
		"prerequisite_id": "obj_preboss_1_borderlands_vanguard",
		"next_objective_id": "obj_boss_borderlands_ogre",
		"reward_summary_key": "campaign.obj.preboss_2.reward",
	},
	"obj_boss_borderlands_ogre": {
		"title_key": "campaign.obj.boss.title",
		"desc_key": "campaign.obj.boss.desc",
		"tier": 5,
		"encounter_id": "obj_boss_borderlands_ogre",
		"prerequisite_id": "obj_preboss_2_borderlands_stronghold",
		"next_objective_id": "",
		"reward_summary_key": "campaign.obj.boss.reward",
	},
}

const EXPEDITIONS: Dictionary = {
	"goblin_camp": {
		"position": Vector2i(4, 4),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		# Clear XP: 10 for clearing its site (see the campaign progression
		# design doc). Kill XP now lives on each enemy's own *_ENEMY_STATS
		# const instead — see GOBLIN_ENEMY_STATS.kill_xp.
		"clear_xp": 10,
		"enemy": {
			"name_key": "battle.enemy.goblin",
			"attack_name_key": "battle.enemy.goblin.attack",
			"max_health": 13,
			"attack_damage": 2,
			"hit_chance": 0.3,
			"count": 1,
		},
	},
	"orc_outpost": {
		"position": Vector2i(4, 0),
		"name_key": "expedition.orc_outpost.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 2,
		# Clear XP: 20 for clearing its site. Kill XP lives on
		# GOBLIN_ENEMY_STATS/ORC_ENEMY_STATS depending on which composition
		# resolves.
		"clear_xp": 20,
		"enemy": {
			"name_key": "battle.enemy.orc",
			"attack_name_key": "battle.enemy.orc.attack",
			"max_health": 22,
			"attack_damage": 3,
			"hit_chance": 0.5,
			"count": 1,
		},
	},
	"ruined_fortress": {
		"position": Vector2i(0, 4),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 3,
		# Clear XP: 30 for clearing the site. Kill XP lives on each
		# composition option's own enemy stats — see the reward table in
		# docs/plans/2026-08-08-monster-tiers-and-weighted-encounters/08-per-monster-kill-xp.md.
		"clear_xp": 30,
		"enemy": {
			"name_key": "battle.enemy.kobold",
			"attack_name_key": "battle.enemy.kobold.attack",
			"max_health": 6,
			"attack_damage": 1,
			"hit_chance": 0.25,
			"count": 4,
		},
	},
	# The twelve authored campaign-ladder nodes below (docs/plans/2026-08-18-
	# core-loop-and-engagement/05-authored-encounters-and-final-boss.md).
	# Each key is exactly one of CAMPAIGN_OBJECTIVES' own keys -- that step's
	# own doc comment names it "sole owner of every objective id and
	# encounter id," so these keys and each entry's "encounter_id" (mirrored
	# by CAMPAIGN_OBJECTIVES' own field of the same name) are never
	# renamed/renumbered here. Every entry sets "is_authored" (read by
	# is_authored_encounter()/can_enter_encounter()/complete_current_
	# encounter()) and an ordered "enemies" array -- {"enemy": <*_ENEMY_
	# STATS const>, "count": n} groups, expanded in declaration order by
	# BattleController._build_enemy_specs() -- instead of the legacy single
	# "enemy" + "count" template the three sandbox expeditions above still
	# use; the two shapes coexist rather than the new one overloading the
	# old one. "difficulty" doubles as get_threat_stars()'s base star and
	# mirrors CAMPAIGN_OBJECTIVES' own "tier" (pre-boss nodes are tier 4,
	# the final boss is tier 5, both one star higher than tier 3's 3 stars).
	"obj_tier1_1_goblin_outpost": {
		"position": Vector2i(2, 2),
		"name_key": "expedition.obj_tier1_1_goblin_outpost.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		"clear_xp": 15,
		"is_authored": true,
		"enemies": [
			{"enemy": GOBLIN_ENEMY_STATS, "count": 1},
			{"enemy": KOBOLD_ENEMY_STATS, "count": 2},
		],
	},
	"obj_tier1_2_kobold_warren": {
		"position": Vector2i(2, 4),
		"name_key": "expedition.obj_tier1_2_kobold_warren.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		"clear_xp": 18,
		"is_authored": true,
		"enemies": [
			{"enemy": KOBOLD_ENEMY_STATS, "count": 4},
			{"enemy": KOBOLD_SLINGER_ENEMY_STATS, "count": 1},
		],
	},
	"obj_tier1_3_goblin_warcamp": {
		"position": Vector2i(4, 2),
		"name_key": "expedition.obj_tier1_3_goblin_warcamp.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		"clear_xp": 20,
		"is_authored": true,
		"enemies": [
			{"enemy": GOBLIN_ENEMY_STATS, "count": 2},
			{"enemy": GOBLIN_ARCHER_ENEMY_STATS, "count": 1},
		],
	},
	"obj_tier2_1_orc_outpost": {
		"position": Vector2i(1, 1),
		"name_key": "expedition.obj_tier2_1_orc_outpost.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 2,
		"clear_xp": 30,
		"is_authored": true,
		"enemies": [
			{"enemy": ORC_BRUISER_ENEMY_STATS, "count": 1},
			{"enemy": GOBLIN_ARCHER_ENEMY_STATS, "count": 1},
		],
	},
	"obj_tier2_2_orc_warband": {
		"position": Vector2i(5, 1),
		"name_key": "expedition.obj_tier2_2_orc_warband.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 2,
		"clear_xp": 35,
		"is_authored": true,
		"enemies": [
			{"enemy": ORC_BRUISER_ENEMY_STATS, "count": 2},
		],
	},
	"obj_tier2_3_brute_stronghold": {
		"position": Vector2i(1, 5),
		"name_key": "expedition.obj_tier2_3_brute_stronghold.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 2,
		"clear_xp": 40,
		"is_authored": true,
		"enemies": [
			{"enemy": ORC_BRUISER_ENEMY_STATS, "count": 2},
			{"enemy": GOBLIN_ARCHER_ENEMY_STATS, "count": 2},
		],
	},
	"obj_tier3_1_hobgoblin_command": {
		"position": Vector2i(0, 0),
		"name_key": "expedition.obj_tier3_1_hobgoblin_command.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 3,
		"clear_xp": 55,
		"is_authored": true,
		"enemies": [
			{"enemy": HOBGOBLIN_ELITE_ENEMY_STATS, "count": 1},
			{"enemy": KOBOLD_SLINGER_ENEMY_STATS, "count": 2},
		],
	},
	"obj_tier3_2_mixed_forces_ambush": {
		"position": Vector2i(6, 0),
		"name_key": "expedition.obj_tier3_2_mixed_forces_ambush.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 3,
		"clear_xp": 60,
		"is_authored": true,
		"enemies": [
			{"enemy": HOBGOBLIN_ELITE_ENEMY_STATS, "count": 1},
			{"enemy": ORC_BRUISER_ENEMY_STATS, "count": 1},
			{"enemy": GOBLIN_SHAMAN_ENEMY_STATS, "count": 1},
		],
	},
	"obj_tier3_3_ruined_fortress": {
		"position": Vector2i(0, 6),
		"name_key": "expedition.obj_tier3_3_ruined_fortress.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 3,
		"clear_xp": 65,
		"is_authored": true,
		"enemies": [
			{"enemy": HOBGOBLIN_ELITE_ENEMY_STATS, "count": 2},
			{"enemy": ORC_BRUISER_ENEMY_STATS, "count": 2},
		],
	},
	"obj_preboss_1_borderlands_vanguard": {
		"position": Vector2i(6, 2),
		"name_key": "expedition.obj_preboss_1_borderlands_vanguard.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 4,
		"clear_xp": 90,
		"is_authored": true,
		"enemies": [
			{"enemy": HOBGOBLIN_ELITE_ENEMY_STATS, "count": 2},
			{"enemy": GOBLIN_ARCHER_ENEMY_STATS, "count": 2},
			{"enemy": KOBOLD_ENEMY_STATS, "count": 1},
		],
	},
	"obj_preboss_2_borderlands_stronghold": {
		"position": Vector2i(6, 4),
		"name_key": "expedition.obj_preboss_2_borderlands_stronghold.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 4,
		"clear_xp": 100,
		"is_authored": true,
		"enemies": [
			{"enemy": HOBGOBLIN_CHAMPION_ENEMY_STATS, "count": 3},
			{"enemy": ORC_WARLORD_ENEMY_STATS, "count": 1},
		],
	},
	"obj_boss_borderlands_ogre": {
		"position": Vector2i(6, 6),
		"name_key": "expedition.obj_boss_borderlands_ogre.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 5,
		"clear_xp": 200,
		"is_authored": true,
		"enemies": [
			{"enemy": OGRE_ENEMY_STATS, "count": 1},
		],
	},
}
const GOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.goblin",
	"attack_name_key": "battle.enemy.goblin.attack",
	"max_health": 13,
	"attack_damage": 2,
	"hit_chance": 0.3,
	"kill_xp": 5,
	"loot_id": "goblin",
}
const GOBLIN_ARCHER_ENEMY_STATS: Dictionary = {
	"id": "goblin_archer",
	"tier": 2,
	"name_key": "battle.enemy.goblin_archer",
	"attack_name_key": "battle.enemy.goblin_archer.attack",
	"max_health": 10,
	"attack_damage": 1,
	"damage_min": 1,
	"damage_max": 4,
	"hit_chance": 0.4,
	"move_range": 3,
	"attack_min_range": 1,
	"attack_max_range": 3,
	"kill_xp": 6,
	"role": "ranged_skirmisher",
	"loot_id": "goblin",
}
const ORC_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.orc",
	"attack_name_key": "battle.enemy.orc.attack",
	"max_health": 22,
	"attack_damage": 3,
	"hit_chance": 0.5,
	"kill_xp": 10,
	"loot_id": "orc",
}
const KOBOLD_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.kobold",
	"attack_name_key": "battle.enemy.kobold.attack",
	"max_health": 6,
	"attack_damage": 1,
	"hit_chance": 0.25,
	"kill_xp": 3,
	"loot_id": "kobold",
}
const HOBGOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.hobgoblin",
	"attack_name_key": "battle.enemy.hobgoblin.attack",
	"max_health": 30,
	"attack_damage": 4,
	"hit_chance": 0.6,
	"kill_xp": 20,
	"loot_id": "hobgoblin",
}
# The remaining stat blocks below back the 12-node authored campaign ladder
# (see EXPEDITIONS' "obj_*" entries and docs/plans/2026-08-18-core-loop-and-
# engagement/05-authored-encounters-and-final-boss.md). Where the plan's
# named monster is functionally identical to an existing const under a more
# flavorful name -- "Goblin Skirmisher" and "Kobold Swarmer" -- the existing
# GOBLIN_ENEMY_STATS/KOBOLD_ENEMY_STATS consts are reused directly rather
# than duplicated. Every monster below is a genuinely new variant and gets
# its own const, following GOBLIN_ARCHER_ENEMY_STATS' ranged-unit field set
# (damage_min/damage_max/move_range/attack_min_range/attack_max_range/role)
# for the two ranged additions, and adding "defense"/"resistance" (read by
# BattleController._build_enemy_specs() same as a player's armor -- see
# EXPEDITIONS' own WEAPONS/ARMORS doc comment for what each stat does) for
# the four armored/elite melee additions. Every entry still resolves through
# only the shared, standard monster action-resolution path -- none of these
# (including the Ogre) declares a bespoke ability, cleave, or phase.
const KOBOLD_SLINGER_ENEMY_STATS: Dictionary = {
	"id": "kobold_slinger",
	"tier": 1,
	"name_key": "battle.enemy.kobold_slinger",
	"attack_name_key": "battle.enemy.kobold_slinger.attack",
	"max_health": 5,
	"attack_damage": 1,
	"damage_min": 1,
	"damage_max": 3,
	"hit_chance": 0.35,
	"move_range": 3,
	"attack_min_range": 1,
	"attack_max_range": 3,
	"kill_xp": 4,
	"role": "ranged_skirmisher",
	"loot_id": "kobold",
}
const GOBLIN_SHAMAN_ENEMY_STATS: Dictionary = {
	"id": "goblin_shaman",
	"tier": 3,
	"name_key": "battle.enemy.goblin_shaman",
	"attack_name_key": "battle.enemy.goblin_shaman.attack",
	"max_health": 9,
	"attack_damage": 2,
	"damage_min": 2,
	"damage_max": 5,
	"hit_chance": 0.45,
	"move_range": 3,
	"attack_min_range": 1,
	"attack_max_range": 3,
	"kill_xp": 8,
	"role": "ranged_support",
	"loot_id": "goblin",
}
const ORC_BRUISER_ENEMY_STATS: Dictionary = {
	"id": "orc_bruiser",
	"tier": 2,
	"name_key": "battle.enemy.orc_bruiser",
	"attack_name_key": "battle.enemy.orc_bruiser.attack",
	"max_health": 28,
	"attack_damage": 4,
	"hit_chance": 0.5,
	"defense": 10,
	"resistance": 15,
	"kill_xp": 12,
	"role": "armored_bruiser",
	"loot_id": "orc",
}
const HOBGOBLIN_ELITE_ENEMY_STATS: Dictionary = {
	"id": "hobgoblin_elite",
	"tier": 3,
	"name_key": "battle.enemy.hobgoblin_elite",
	"attack_name_key": "battle.enemy.hobgoblin_elite.attack",
	"max_health": 38,
	"attack_damage": 5,
	"hit_chance": 0.6,
	"defense": 5,
	"resistance": 10,
	"kill_xp": 24,
	"role": "elite",
	"loot_id": "hobgoblin",
}
const HOBGOBLIN_CHAMPION_ENEMY_STATS: Dictionary = {
	"id": "hobgoblin_champion",
	"tier": 4,
	"name_key": "battle.enemy.hobgoblin_champion",
	"attack_name_key": "battle.enemy.hobgoblin_champion.attack",
	"max_health": 46,
	"attack_damage": 6,
	"hit_chance": 0.62,
	"defense": 8,
	"resistance": 15,
	"kill_xp": 30,
	"role": "elite",
	"loot_id": "hobgoblin",
}
const ORC_WARLORD_ENEMY_STATS: Dictionary = {
	"id": "orc_warlord",
	"tier": 4,
	"name_key": "battle.enemy.orc_warlord",
	"attack_name_key": "battle.enemy.orc_warlord.attack",
	"max_health": 50,
	"attack_damage": 7,
	"hit_chance": 0.55,
	"defense": 12,
	"resistance": 20,
	"kill_xp": 35,
	"role": "armored_bruiser",
	"loot_id": "orc",
}
## Final boss (see the plan doc's "Tune its ordinary HP, hit chance, damage,
## guard, and resistance against a deterministic benchmark of approximately
## four level-1 Warriors" requirement). Derivation: a level-1 Warrior's
## default Iron Longsword (1-8, mean 4.5) and Leather Armor (10 defense, 10%
## resistance) against these numbers gives effective_hit_chance = 0.60 -
## 0.15 = 0.45 and mean post-resistance damage = 4.5 * 0.80 = 3.6, i.e. an
## expected ~1.62 damage per Warrior swing -- roughly HP/1.62 swings to
## fell it. The reverse check (Ogre vs. a Warrior's 10 defense/10%
## resistance) gives effective_hit_chance = 0.55 - 0.10 = 0.45 and mean
## post-resistance damage = 8.5 * 0.90 = 7.65, i.e. ~3.44 expected damage
## per Ogre swing against a 10-HP level-1 Warrior -- lethal in two or three
## landed hits, same "genuinely dangerous alone, beatable in numbers" curve
## the Monster Manual's Hobgoblin row already establishes one tier down.
## See test_battle_controller.gd's seeded four-Warrior benchmark for the
## resulting multi-round power-band evidence; Step 6's simulation/balance
## harness owns any further tuning.
const OGRE_ENEMY_STATS: Dictionary = {
	"id": "ogre",
	"tier": 5,
	"name_key": "battle.enemy.ogre",
	"attack_name_key": "battle.enemy.ogre.attack",
	"max_health": 90,
	"attack_damage": 8,
	"damage_min": 5,
	"damage_max": 12,
	"hit_chance": 0.55,
	"defense": 15,
	"resistance": 20,
	"kill_xp": 150,
	"role": "boss",
	"loot_id": "ogre",
}
# Star tier -> possible enemy compositions for an active instance at that
# tier (see docs/plans/campaign-loop-follow-up.md's battle balancing
# section). Tier 1 has one option, tier 2 has two, and tier 3 has four;
# whenever a tier has more than one option, entering an instance at that
# tier randomly resolves to one of them (see
# enemy_composition_roll/_resolve_enemy_composition/enter_encounter) so
# three orcs can no longer gang up on a level-1 party. Ordering within each
# tier's option list follows the design doc's phrasing for that tier: tiers
# 1-2 are Goblin-first, while tier 3 is Kobold-first, ascending danger.
const STAR_ENEMY_COMPOSITIONS: Dictionary = {
	1: [
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 1},
	],
	2: [
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 2, "count_max": 2},
		{"enemy": ORC_ENEMY_STATS, "count_min": 1, "count_max": 1},
	],
	3: [
		{"enemy": KOBOLD_ENEMY_STATS, "count_min": 4, "count_max": 8},
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 3, "count_max": 6},
		{"enemy": ORC_ENEMY_STATS, "count_min": 2, "count_max": 4},
		{"enemy": HOBGOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 3},
	],
}
## Star-tier selection weight for a refill candidate at a given player
## power. Floors at STAR_WEIGHT_MIN so no tier's odds
## ever reach exactly zero.
const STAR_WEIGHT_BASE: Dictionary = {1: 6, 2: 2, 3: -2}
const STAR_WEIGHT_PER_POWER: Dictionary = {1: -1, 2: 1, 3: 1}
const STAR_WEIGHT_MIN: int = 1
# Equipment catalog (see docs/designs/weapon-armor-inventory.md). Steel is
# +1 damage over Iron on both ends of the range. Armor's defense reduces an
# attacker's effective hit chance; resistance reduces incoming damage by that
# percent, rounded to the nearest integer when applied (see BattleController).
const WEAPONS: Dictionary = {
	"dagger_iron": {"name_key": "item.dagger_iron", "slot": "weapon", "category": "dagger", "damage_min": 1, "damage_max": 4, "min_range": 1, "max_range": 1, "price": 10},
	"dagger_steel": {"name_key": "item.dagger_steel", "slot": "weapon", "category": "dagger", "damage_min": 2, "damage_max": 5, "min_range": 1, "max_range": 1, "price": 30},
	"shortsword_iron": {"name_key": "item.shortsword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 6, "min_range": 1, "max_range": 1, "price": 20},
	"shortsword_steel": {"name_key": "item.shortsword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 7, "min_range": 1, "max_range": 1, "price": 60},
	"longsword_iron": {"name_key": "item.longsword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 8, "min_range": 1, "max_range": 1, "price": 30},
	"longsword_steel": {"name_key": "item.longsword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 9, "min_range": 1, "max_range": 1, "price": 90},
	"two_handed_sword_iron": {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 10, "min_range": 1, "max_range": 1, "price": 35},
	"two_handed_sword_steel": {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 11, "min_range": 1, "max_range": 1, "price": 105},
	"shortbow_iron": {"name_key": "item.shortbow_iron", "slot": "weapon", "category": "bow", "damage_min": 1, "damage_max": 6, "min_range": 1, "max_range": 8, "price": 30},
	"shortbow_steel": {"name_key": "item.shortbow_steel", "slot": "weapon", "category": "bow", "damage_min": 2, "damage_max": 7, "min_range": 1, "max_range": 10, "price": 90},
	"hunting_bow_steel": {"name_key": "item.hunting_bow_steel", "slot": "weapon", "category": "bow", "damage_min": 2, "damage_max": 7, "min_range": 1, "max_range": 10, "price": 75},
	"longbow_iron": {"name_key": "item.longbow_iron", "slot": "weapon", "category": "bow", "damage_min": 1, "damage_max": 8, "min_range": 1, "max_range": 12, "price": 45},
	"longbow_steel": {"name_key": "item.longbow_steel", "slot": "weapon", "category": "bow", "damage_min": 2, "damage_max": 9, "min_range": 1, "max_range": 15, "price": 135},
	# Cleric's blunt weapon category (see CLASS_DEFINITIONS.cleric below). Same
	# damage range and price tier as shortsword_iron -- mace/hammer/staff are
	# distinct weapon *categories* (for allowed_weapon_categories gating) but
	# not yet a distinct damage tier of their own.
	"mace_iron": {"name_key": "item.mace_iron", "slot": "weapon", "category": "mace", "damage_min": 1, "damage_max": 6, "min_range": 1, "max_range": 1, "price": 20},
}
const CLASS_DEFINITIONS: Dictionary = {
	"warrior": {
		"allowed_weapon_categories": ["sword", "dagger", "axe"],
		"base_stats": {"max_health": 10, "vitality": 10, "melee": 60, "missile": 60, "guard": 0, "might": 0, "move_range": 3},
		"primary_attribute_ranges": {"strength": Vector2i(6, 8), "agility": Vector2i(6, 8), "vitality": Vector2i(6, 8), "intelligence": Vector2i(1, 4), "piety": Vector2i(1, 4), "luck": Vector2i(1, 10)},
		"class_multiplier": 1.5,
		"skills": {
			"melee": {"tier": "med", "min_gain": 3, "max_gain": 4},
			"missile": {"tier": "med", "min_gain": 3, "max_gain": 4},
			"guard": {"tier": "low", "min_gain": 1, "max_gain": 2},
			"might": {"tier": "med", "min_gain": 3, "max_gain": 4},
		},
	},
	"scout": {
		"allowed_weapon_categories": ["dagger", "bow"],
		"base_stats": {"max_health": 12, "vitality": 12, "melee": 65, "missile": 65, "guard": 0, "might": 0, "move_range": 3},
		"primary_attribute_ranges": {"strength": Vector2i(4, 6), "agility": Vector2i(6, 8), "vitality": Vector2i(4, 6), "intelligence": Vector2i(3, 5), "piety": Vector2i(1, 4), "luck": Vector2i(1, 10)},
		"class_multiplier": 1.0,
		"skills": {
			"melee": {"tier": "low", "min_gain": 1, "max_gain": 2},
			"missile": {"tier": "hi", "min_gain": 4, "max_gain": 5},
			"guard": {"tier": "low", "min_gain": 1, "max_gain": 2},
			"might": {"tier": "low", "min_gain": 1, "max_gain": 2},
		},
	},
	# Full Cleric (see docs/plans/2026-08-18-core-loop-and-engagement/
	# 04-cleric-class-and-scout-reconnaissance.md): replaces Step 3's minimal
	# stub (same "cleric" key -- GDScript dict literals can't have a
	# duplicate key -- see that step's own doc comment, which explicitly
	# deferred MP/Heal/Bless to this step). Sustain/support role: moderate
	# melee, real spellcasting, blunt weapons (mace/hammer/staff -- see
	# WEAPONS.mace_iron). "spellcasting" is a new base_stats key nothing else
	# reads yet outside spell-flavor text; it exists on no other class, and
	# every reader treats a missing spellcasting stat as 0 rather than
	# requiring every class to carry a dead field. "missile" stays in
	# base_stats for schema parity with warrior/scout (get_effective_hit_
	# chance() falls back to it for a bow-category weapon, which a Cleric can
	# never equip) but is deliberately absent from "skills" below -- it never
	# needs to grow. mp_max (this class's only spellcasting resource) is a
	# flat 3, hydrated onto the battle-local Unit by BattleController, never
	# a persistent adventurer stat (see unit.gd's mp_max/mp_remaining).
	"cleric": {
		"allowed_weapon_categories": ["mace", "hammer", "staff"],
		"base_stats": {"max_health": 12, "vitality": 12, "melee": 45, "missile": 30, "guard": 10, "might": 1, "spellcasting": 55, "move_range": 3},
		"primary_attribute_ranges": {"strength": Vector2i(4, 6), "agility": Vector2i(4, 6), "vitality": Vector2i(6, 8), "intelligence": Vector2i(3, 5), "piety": Vector2i(6, 8), "luck": Vector2i(1, 10)},
		"class_multiplier": 1.0,
		"skills": {
			"melee": {"tier": "low", "min_gain": 1, "max_gain": 2},
			"guard": {"tier": "med", "min_gain": 3, "max_gain": 4},
			"spellcasting": {"tier": "hi", "min_gain": 4, "max_gain": 5},
			"might": {"tier": "low", "min_gain": 1, "max_gain": 2},
		},
		"mp_max": 3,
		"spells": ["heal", "bless"],
	},
}
const BLACKSMITH_BUILD_COST := 50
const BLACKSMITH_UPGRADE_COSTS := {2: 50, 3: 100}
const BLACKSMITH_MAX_LEVEL := 3
const BLACKSMITH_CRAFT_DURATION_TURNS := 5
const BLACKSMITH_SHARPENING_DURATION_TURNS := 20
const SHARPENED_TREATMENT_ID := "sharpened"
const ALCHEMY_WORKSHOP_BUILD_COST := 50
const ALCHEMY_WORKSHOP_UPGRADE_COST := 50
const ALCHEMY_WORKSHOP_MAX_LEVEL := 2
const ALCHEMY_CRAFT_DURATION_TURNS := 7
const RUNIC_WORKSHOP_BUILD_COST := 50
const RUNIC_WORKSHOP_UPGRADE_COST := 50
const RUNIC_WORKSHOP_MAX_LEVEL := 2
const RUNIC_CRAFT_DURATION_TURNS := 7
const THORN_RUNE_ID := "thorn"
const THORN_RUNE_GOLD_COST := 20
const THORN_RUNE_MINIMUM_CRYSTAL_TIER := 1
const CARRIED_ITEM_CAPACITY := 10
const ARMORS: Dictionary = {
	"leather_armor": {"name_key": "item.leather_armor", "slot": "armor", "defense": 10, "resistance": 10, "price": 10},
	"chainmail_armor": {"name_key": "item.chainmail_armor", "slot": "armor", "defense": 15, "resistance": 20, "price": 30},
	"split_armor": {"name_key": "item.split_armor", "slot": "armor", "defense": 15, "resistance": 25, "price": 50},
	"platemail_armor": {"name_key": "item.platemail_armor", "slot": "armor", "defense": 15, "resistance": 30, "price": 200},
	"full_plate_armor": {"name_key": "item.full_plate_armor", "slot": "armor", "defense": 15, "resistance": 35, "price": 500},
}
const POTIONS: Dictionary = {
	"healing_potion": {"name_key": "item.healing_potion", "slot": "potion", "healing_min": 1, "healing_max": 6, "price": 0, "required_level": 1, "gold_cost": 10, "minimum_crystal_tier": 1},
	"greater_healing_potion": {"name_key": "item.greater_healing_potion", "slot": "potion", "healing_min": 2, "healing_max": 8, "price": 0, "required_level": 2, "gold_cost": 20, "minimum_crystal_tier": 2},
}
# Loot tables (see docs/designs/weapon-armor-inventory.md). Gold per kill is
# randi_range(gold_min, gold_max) * gold_multiplier. gear_item_id is always
# the enemy's documented Iron-tier weapon (see WEAPONS above); it drops with
# GEAR_DROP_CHANCE probability, independent of the (always-granted) mana
# crystal. Kobold and hobgoblin are both fightable via the Ruined Fortress
# (see STAR_ENEMY_COMPOSITIONS[3]), so their rows resolve for real loot
# whenever either is killed there, same as goblin/orc elsewhere.
const ENEMY_LOOT_TABLES: Dictionary = {
	"kobold": {"gold_min": 0, "gold_max": 5, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "dagger_iron"},
	"goblin": {"gold_min": 1, "gold_max": 6, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "shortsword_iron"},
	"orc": {"gold_min": 1, "gold_max": 5, "gold_multiplier": 2, "mana_crystal_tier": 2, "gear_item_id": "longsword_iron"},
	"hobgoblin": {"gold_min": 1, "gold_max": 4, "gold_multiplier": 3, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_iron"},
	# Final boss loot (see OGRE_ENEMY_STATS): the best fixed drop rate/value
	# in the table, gated behind a fight that only ever happens once per
	# campaign.
	"ogre": {"gold_min": 20, "gold_max": 40, "gold_multiplier": 5, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_steel"},
}
const MANA_CRYSTAL_VALUES: Dictionary = {1: 5, 2: 15}
const GEAR_DROP_CHANCE := 0.25
const DEFAULT_WEAPON_ID := "longsword_iron"
const DEFAULT_ARMOR_ID := "leather_armor"
# Progression domain constants (see docs/plans/2026-08-06-campaign-progression-and-population).
# Cumulative XP threshold for level N is 5*N*(N+1) - 10: level 1 costs 0, level
# 2 costs 20, level 3 costs 50, level 4 costs 90, each step costing 10 XP more
# than the previous one. See get_level_xp_threshold().
# Balance values below default to GameConfig's own DEFAULTS and are
# overwritten from config/game_config.json in _ready() (see
# docs/plans/2026-08-07-config-and-automation). They stay UPPER_SNAKE_CASE
# vars, not real consts, specifically so every existing
# GameSession.SOME_CONSTANT call site keeps working unchanged — GDScript
# exposes both consts and vars the same way through a singleton instance.
var BASE_MOVE_RANGE: int = 3
var PERK_LEVEL_INTERVAL: int = 3
const BONUS_MOVE_PERK_ID := "bonus_move"
# Guild Hall tier model (see docs/plans/2026-08-18-core-loop-and-engagement/
# 03-encampment-buildings-and-tier-model.md): three tiers scaling deployable
# party size (3/4/5), roster capacity (10/15/20), and recruitment offer
# capacity (4/8/10). GUILD_HALL_LEVEL_2_PARTY_CAP predates this step (it used
# to be the final/max cap, valued 5); it now names the level-2 cap (4)
# specifically, with GUILD_HALL_LEVEL_3_PARTY_CAP naming the new final cap.
var GUILD_HALL_LEVEL_1_PARTY_CAP: int = 3
var GUILD_HALL_LEVEL_2_PARTY_CAP: int = 4
var GUILD_HALL_LEVEL_3_PARTY_CAP: int = 5
var GUILD_HALL_UPGRADE_COST: int = 50
var GUILD_HALL_LEVEL_3_UPGRADE_COST: int = 100
var GUILD_HALL_MAX_LEVEL: int = 3
var GUILD_HALL_LEVEL_1_ROSTER_CAP: int = 10
var GUILD_HALL_LEVEL_2_ROSTER_CAP: int = 15
var GUILD_HALL_LEVEL_3_ROSTER_CAP: int = 20
var GUILD_HALL_LEVEL_2_OFFER_CAP: int = 8
var GUILD_HALL_LEVEL_3_OFFER_CAP: int = 10
# Temple build cost (see docs/plans/2026-08-18-core-loop-and-engagement/03-
# encampment-buildings-and-tier-model.md): Level 1 ("consecrated") unlocks
# Cleric recruitment candidate generation only. Temple level 2
# ("sanctified") and any blessing state are explicitly out of scope.
var TEMPLE_BUILD_COST: int = 100
const TEMPLE_MAX_LEVEL := 1
# Shop tier upgrade costs (see docs/plans/2026-08-18-core-loop-and-engagement/
# 03-encampment-buildings-and-tier-model.md): SHOP_UPGRADE_COST predates this
# step (it used to be the Shop's only upgrade, a flat one-time cost of 50);
# it now specifically names the level 1 -> 2 cost (150), with
# SHOP_LEVEL_3_UPGRADE_COST naming the new level 2 -> 3 cost (300).
var SHOP_UPGRADE_COST: int = 150
var SHOP_LEVEL_3_UPGRADE_COST: int = 300
const SHOP_LEVEL_ONE_GOLD_CAP := 100
const SHOP_LEVEL_TWO_GOLD_CAP := 200
# Passive per-turn gold income by Shop level (docs/designs/campaign-loop.md's
# economy floor: 2/5/10 gold/turn at tiers 1/2/3). SHOP_INCOME_PER_TURN keeps
# its established name for tier 1 -- every existing call site already reads
# it as "the Shop's passive income" -- while LEVEL_2/LEVEL_3 are new tiers
# read by _shop_income_per_turn(). A Shop level 3 upgrade path does not exist
# yet (upgrade_shop() only reaches level 2); this tier is forward-looking for
# when it does.
var SHOP_INCOME_PER_TURN: int = 2
var SHOP_INCOME_LEVEL_2: int = 5
var SHOP_INCOME_LEVEL_3: int = 10
# Legacy save compatibility only. New games always have a level-one Shop.
var TRADING_POST_PURCHASE_COST: int = 50
var TRADING_POST_INCOME_PER_TURN: int = 1
var EFFECTIVE_HIT_CHANCE_CAP: float = 0.95
var ATTACK_TO_HIT_CHANCE_DIVISOR: float = 100.0
var HEAL_RATE_ENCAMPED: int = 4
var HEAL_RATE_RESTING: int = 2
var HEAL_RATE_MOVING: int = 1

# Vacancy-timed population (see docs/plans/2026-08-06-campaign-progression-and-population).
# A campaign starts sparse (two active encounters, one active recruitment
# offer) and refills each cleared/hired slot only after its own category's
# wait, and only while under that category's cap. See EXPEDITIONS/
# RECRUITMENT_CANDIDATE_TEMPLATES for the template pools these instances/
# offers are spawned from.
var ENCOUNTER_INSTANCE_CAP: int = 2
var RECRUITMENT_OFFER_CAP: int = 4
var ENCOUNTER_VACANCY_TURNS: int = 15
var RECRUITMENT_VACANCY_TURNS: int = 30
var ENCOUNTER_VACANCY_JITTER_TURNS: int = 5
var RECRUITMENT_VACANCY_JITTER_TURNS: int = 5
# The pool of candidate templates a refill's power-weighted picker chooses
# among (see _choose_encounter_template()) -- order no longer determines
# which template gets picked, only which is enumerated first when weights
# tie. Must mirror EXPEDITIONS' keys exactly.
const ENCOUNTER_TEMPLATE_ORDER := ["goblin_camp", "orc_outpost", "ruined_fortress"]
# Mirrors world_map.gd's GRID_WIDTH/GRID_HEIGHT. Duplicated here (rather than
# cross-referenced) because GameSession is an autoload with no dependency on
# the world scene script; keep both in sync if the map grid ever resizes.
const WORLD_GRID_WIDTH := 7
const WORLD_GRID_HEIGHT := 7

const WARRIOR_ID := "warrior_001"
## The roster a fresh campaign starts with (see reset()): four Warriors.
## Kept as a named constant so rules phrased against "more than the starting
## roster" (see _campaign_guide_first_improvement_made) do not hardcode 4.
const STARTING_ROSTER_SIZE := 4


func get_default_warrior(adventurer_id: String = WARRIOR_ID, adventurer_name: String = "Warrior") -> Dictionary:
	return {
		"id": adventurer_id,
		"name": adventurer_name,
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"stats": CLASS_DEFINITIONS.warrior.base_stats.duplicate(true),
		"health": CLASS_DEFINITIONS.warrior.base_stats.max_health,
		"progression": {
			"xp": 0.0,
			"perks": [],
		},
	}


func get_default_scout(adventurer_id: String, adventurer_name: String) -> Dictionary:
	return {
		"id": adventurer_id,
		"name": adventurer_name,
		"class": "scout",
		"equipment": {
			"weapon": "shortbow_iron", "weapon_inventory": ["shortbow_iron"],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"stats": CLASS_DEFINITIONS.scout.base_stats.duplicate(true),
		"health": CLASS_DEFINITIONS.scout.base_stats.max_health,
		"progression": {
			"xp": 0.0,
			"perks": [],
		},
	}


## Cleric factory: starting gear is mace_iron (the Cleric's own blunt
## category) plus the shared default leather armor.
func get_default_cleric(adventurer_id: String, adventurer_name: String) -> Dictionary:
	return {
		"id": adventurer_id,
		"name": adventurer_name,
		"class": "cleric",
		"equipment": {
			"weapon": "mace_iron", "weapon_inventory": ["mace_iron"],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"stats": CLASS_DEFINITIONS.cleric.base_stats.duplicate(true),
		"health": CLASS_DEFINITIONS.cleric.base_stats.max_health,
		"progression": {
			"xp": 0.0,
			"perks": [],
		},
	}


const FIRST_PARTY_ID := "party_001"
const DEFAULT_PLAYER_NAME := "Player"
# The pool of recruitment templates a fresh campaign seeds as live offers
# (see reset()) and that vacancy-timed refills draw from (see
# _spawn_next_recruitment_offer): a refill claims an unclaimed template
# matching the rolled class before falling back to minting an overflow
# candidate of that class. Since the fresh start seeds every template,
# refills are overflow offers in practice. Templates intentionally omit
# stats/progression; _make_recruitment_offer() seeds them from the matching
# class baseline (see _seed_adventurer_baseline_stats) rather than storing
# (and risking stale) copies here.
const RECRUITMENT_CANDIDATE_TEMPLATES: Array[Dictionary] = [
	{
		"id": "warrior_002",
		"name": "Warrior 2",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
	{
		"id": "scout_002",
		"name": "Scout 2",
		"class": "scout",
		"equipment": {
			"weapon": "shortbow_iron", "weapon_inventory": ["shortbow_iron"],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
	{
		"id": "warrior_003",
		"name": "Warrior 3",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
	{
		"id": "warrior_004",
		"name": "Warrior 4",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
]

var adventurers: Array[Dictionary] = []
# Active recruitment OFFERS (not the template pool — see
# RECRUITMENT_CANDIDATE_TEMPLATES). A fresh campaign seeds all four
# templates (3 warriors, 1 scout), each as a fresh record with a generated
# id plus the claimed template_id; purchasing one starts a
# RECRUITMENT_VACANCY_TURNS clock that may add another later, capped at
# RECRUITMENT_OFFER_CAP.
var recruitment_candidates: Array[Dictionary] = []
# One pending clock per open recruitment vacancy: {"turns_remaining": int}.
var recruitment_vacancies: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var selected_party_id: String = ""
var selected_encounter: String = ""
# Injectable so tests can force a specific composition (see hit_roll on
# BattleController for the same pattern) instead of depending on real
# randomness. Never reset by reset() — every call site that needs a specific
# outcome sets this immediately before its own enter_encounter() call.
var enemy_composition_roll: Callable = func(option_count: int) -> int: return randi() % option_count
## Injectable so tests can force a specific weighted-tier outcome instead
## of depending on real randomness (see enemy_composition_roll for the
## same pattern). Takes the candidates' total weight and returns a value
## in [0, total_weight) -- _choose_encounter_template() maps it onto each
## candidate's weight bucket via a cumulative sum.
var star_weight_roll: Callable = func(total_weight: int) -> int: return randi() % total_weight
## Injectable so tests can force a specific enemy count instead of
## depending on real randomness (see enemy_composition_roll for the same
## pattern). Called with the resolved composition option's
## (count_min, count_max).
var enemy_count_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
## Injectable so tests can force a specific vacancy delay instead of
## depending on real randomness (see enemy_composition_roll for the same
## pattern). Called by _resolve_vacancy_delay() with an inclusive
## [minimum, maximum] jitter range and expected to return a value in that
## range once per newly opened vacancy.
var vacancy_delay_roll: Callable = func(minimum: int, maximum: int) -> int: return randi_range(minimum, maximum)
## Injectable class policy for recruitment refills. Production picks Warrior
## or Scout with equal probability; tests may force either outcome without
## waiting through unrelated offers.
var recruitment_class_roll: Callable = func() -> String: return "scout" if randi() % 2 == 0 else "warrior"
## Injectable so tests can force whether a recruitment refill becomes a
## Cleric offer instead of the warrior/scout pool (see recruitment_class_
## roll above for the same pattern). Only ever consulted from
## _spawn_next_recruitment_offer() while temple_level >= 1 -- structurally,
## not just probabilistically, a Cleric candidate can never appear before
## the Temple is built (see docs/plans/2026-08-18-core-loop-and-engagement/
## 03-encampment-buildings-and-tier-model.md). Production rolls a flat 25%
## chance once eligible.
var cleric_offer_roll: Callable = func() -> bool: return randf() < 0.25
## Injectable entropy source for generated instance ids (see
## _new_instance_id()). Production composes a GUID-style id from randi()
## blocks mixed with a unix-time fragment; tests may pin it to make every
## minted id deterministic. Same convention as vacancy_delay_roll /
## recruitment_class_roll: never touched by reset().
var skill_gain_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var instance_id_roll: Callable = func() -> String:
	var time_fragment := int(Time.get_unix_time_from_system())
	return "%08x-%04x-%08x-%04x%08x" % [
		randi(),
		time_fragment & 0xFFFF,
		randi(),
		(time_fragment >> 16) & 0xFFFF,
		randi(),
	]


## Restores injectable rolls to their real-random default implementations.
## Deliberately NOT called by reset() -- these Callables are intentionally
## never touched by reset() (see each var's own doc comment) so a test can
## pin one, then call reset() for unrelated setup, without losing its pin.
## Call sites that need a guaranteed clean slate (a fresh debug scenario, a
## test's after_each) call this explicitly instead.
func reset_injectable_rolls() -> void:
	enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
	enemy_count_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	star_weight_roll = func(total_weight: int) -> int: return randi() % total_weight
	vacancy_delay_roll = func(minimum: int, maximum: int) -> int: return randi_range(minimum, maximum)
	recruitment_class_roll = func() -> String: return "scout" if randi() % 2 == 0 else "warrior"
	cleric_offer_roll = func() -> bool: return randf() < 0.25
	skill_gain_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	instance_id_roll = func() -> String:
		var time_fragment := int(Time.get_unix_time_from_system())
		return "%08x-%04x-%08x-%04x%08x" % [
			randi(),
			time_fragment & 0xFFFF,
			randi(),
			(time_fragment >> 16) & 0xFFFF,
			randi(),
		]


# Injectable so tests can force deterministic loot instead of depending on
# real randomness (see enemy_composition_roll/hit_roll for the same
# pattern). Never reset by reset() — a test sets these immediately before
# its own complete_current_encounter() call, same as enemy_composition_roll.
var loot_gold_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var loot_gear_roll: Callable = func() -> float: return randf()

# Durable campaign milestone progression -- separate from the repeatable
# sandbox encounter/vacancy state below (completed_encounters, active_
# encounters, encounter_vacancies), which tracks the free-roam EXPEDITIONS
# pool, not the authored 12-node campaign arc. See CAMPAIGN_OBJECTIVES for
# the catalog these ids reference and complete_campaign_objective()/
# set_campaign_victory() for the only ways this state ever changes.
var campaign_objective_id: String = "obj_tier1_1_goblin_outpost"
var completed_objectives: Array[String] = []
var unlocked_authored_encounters: Array[String] = ["obj_tier1_1_goblin_outpost"]
var is_campaign_completed: bool = false
var is_free_play_active: bool = false
# Lifetime count of permanently-removed adventurers (see resolve_battle_
# deaths(), the only place this increments), read by get_campaign_victory_
# summary() for the Campaign Victory screen's casualties stat. Covers both
# an ordinary mid-battle kill and a full party wipe alike -- a wipe reports
# its deaths through the exact same resolve_battle_deaths() call as any
# other battle-ending kill (see Battlefield._persist_battle_aftermath()).
var total_casualties: int = 0

var completed_encounters: Array[String] = []
# Active encounter INSTANCES (not the template pool — see EXPEDITIONS). Each
# instance is a spawned record: {id, template_id, position, ...copied
# template fields}. A fresh campaign seeds exactly two (the Goblin Camp, id
# "goblin_camp", and the Orc Outpost, id "orc_outpost", each at its
# documented position). Clearing one starts a vacancy clock (see
# _resolve_vacancy_delay) that may add another later, capped at
# ENCOUNTER_INSTANCE_CAP. A cleared instance is never reopened; it is only
# ever recorded (by its own id) in completed_encounters.
var active_encounters: Array[Dictionary] = []
# One pending clock per open encounter vacancy: {"turns_remaining": int}.
var encounter_vacancies: Array[Dictionary] = []
# Every template id ever spawned as an active instance (initial seed plus
# every refill). _choose_encounter_position() uses this to avoid handing a
# refill the exact tile a template's earlier instance was just cleared
# from (see that function's docstring) -- it no longer influences which
# template a refill chooses; see _choose_encounter_template() for that.
# Recruitment offers do not need an equivalent: a claimed template's
# template_id lives on in the roster (or a live offer) forever, so
# _is_recruitment_template_claimed already answers "has this template been
# used" for that category.
var _used_encounter_template_ids: Array[String] = []
var world_turn: int = 1
var gold: int = 0
var guild_hall_level: int = 1
# Temple hub level: 0 (unbuilt), 1 (consecrated -- unlocks Cleric recruitment
# candidate generation). Level 2 ("sanctified") and any blessing state are
# out of scope for this step (see TEMPLE_BUILD_COST/TEMPLE_MAX_LEVEL above).
var temple_level: int = 0
var blacksmith_level: int = 0
# Each job stores only catalog input and its absolute World Map completion
# turn. The two slots deliberately remain independent so crafting and
# sharpening can progress in parallel.
var blacksmith_craft_job: Dictionary = {}
var blacksmith_sharpening_job: Dictionary = {}
var alchemy_workshop_level: int = 0
var alchemy_craft_job: Dictionary = {}
var runic_workshop_level: int = 0
var runic_craft_job: Dictionary = {}
var pending_reward: int = 0
var mana_crystals: Dictionary = {}
var banked_gear: Dictionary = {}
# Permanent improvements materialize a normal stack entry into one of these
# unique records.  Normal gear deliberately remains in banked_gear so Stores
# can retain its compact stack-based representation.
var owned_item_instances: Dictionary = {}
var banked_item_instance_ids: Array[String] = []
var pending_mana_crystals: Dictionary = {}
var pending_gear: Dictionary = {}
var battle_reward: int = 0
var battle_mana_crystals: Dictionary = {}
var battle_gear: Dictionary = {}
var has_trading_post: bool = false
var shop_level: int = 1
var shop_gold: int = SHOP_LEVEL_ONE_GOLD_CAP
var player_name: String = DEFAULT_PLAYER_NAME
# Compact durable record of which first-campaign guide messages have already
# been shown/dismissed (see docs/plans/2026-08-10-initial-campaign-and-
# automation/04-first-campaign-guidance.md's get_campaign_guide_state()). An
# arbitrary id -> bool map, empty until that step starts writing to it.
var tutorial_progress: Dictionary = {}


func _init() -> void:
	reset()


func _ready() -> void:
	_load_balance_config()
	reset()


func _load_balance_config() -> void:
	BASE_MOVE_RANGE = GameConfig.get_int("combat", "base_move_range", BASE_MOVE_RANGE)
	EFFECTIVE_HIT_CHANCE_CAP = GameConfig.get_float("combat", "effective_hit_chance_cap", EFFECTIVE_HIT_CHANCE_CAP)
	ATTACK_TO_HIT_CHANCE_DIVISOR = GameConfig.get_float("combat", "attack_to_hit_chance_divisor", ATTACK_TO_HIT_CHANCE_DIVISOR)
	PERK_LEVEL_INTERVAL = GameConfig.get_int("progression", "perk_level_interval", PERK_LEVEL_INTERVAL)
	GUILD_HALL_LEVEL_1_PARTY_CAP = GameConfig.get_int("guild_hall", "level_1_party_cap", GUILD_HALL_LEVEL_1_PARTY_CAP)
	GUILD_HALL_LEVEL_2_PARTY_CAP = GameConfig.get_int("guild_hall", "level_2_party_cap", GUILD_HALL_LEVEL_2_PARTY_CAP)
	GUILD_HALL_LEVEL_3_PARTY_CAP = GameConfig.get_int("guild_hall", "level_3_party_cap", GUILD_HALL_LEVEL_3_PARTY_CAP)
	GUILD_HALL_UPGRADE_COST = GameConfig.get_int("guild_hall", "upgrade_cost", GUILD_HALL_UPGRADE_COST)
	GUILD_HALL_LEVEL_3_UPGRADE_COST = GameConfig.get_int("guild_hall", "level_3_upgrade_cost", GUILD_HALL_LEVEL_3_UPGRADE_COST)
	GUILD_HALL_MAX_LEVEL = GameConfig.get_int("guild_hall", "max_level", GUILD_HALL_MAX_LEVEL)
	GUILD_HALL_LEVEL_1_ROSTER_CAP = GameConfig.get_int("guild_hall", "level_1_roster_cap", GUILD_HALL_LEVEL_1_ROSTER_CAP)
	GUILD_HALL_LEVEL_2_ROSTER_CAP = GameConfig.get_int("guild_hall", "level_2_roster_cap", GUILD_HALL_LEVEL_2_ROSTER_CAP)
	GUILD_HALL_LEVEL_3_ROSTER_CAP = GameConfig.get_int("guild_hall", "level_3_roster_cap", GUILD_HALL_LEVEL_3_ROSTER_CAP)
	GUILD_HALL_LEVEL_2_OFFER_CAP = GameConfig.get_int("guild_hall", "level_2_offer_cap", GUILD_HALL_LEVEL_2_OFFER_CAP)
	GUILD_HALL_LEVEL_3_OFFER_CAP = GameConfig.get_int("guild_hall", "level_3_offer_cap", GUILD_HALL_LEVEL_3_OFFER_CAP)
	TEMPLE_BUILD_COST = GameConfig.get_int("temple", "build_cost", TEMPLE_BUILD_COST)
	SHOP_INCOME_PER_TURN = GameConfig.get_int("shop", "level_1_income", SHOP_INCOME_PER_TURN)
	SHOP_INCOME_LEVEL_2 = GameConfig.get_int("shop", "level_2_income", SHOP_INCOME_LEVEL_2)
	SHOP_INCOME_LEVEL_3 = GameConfig.get_int("shop", "level_3_income", SHOP_INCOME_LEVEL_3)
	SHOP_UPGRADE_COST = GameConfig.get_int("shop", "level_2_upgrade_cost", SHOP_UPGRADE_COST)
	SHOP_LEVEL_3_UPGRADE_COST = GameConfig.get_int("shop", "level_3_upgrade_cost", SHOP_LEVEL_3_UPGRADE_COST)
	TRADING_POST_INCOME_PER_TURN = SHOP_INCOME_PER_TURN
	ENCOUNTER_INSTANCE_CAP = GameConfig.get_int("population", "encounter_instance_cap", ENCOUNTER_INSTANCE_CAP)
	RECRUITMENT_OFFER_CAP = GameConfig.get_int("population", "recruitment_offer_cap", RECRUITMENT_OFFER_CAP)
	ENCOUNTER_VACANCY_TURNS = GameConfig.get_int("population", "encounter_vacancy_turns", ENCOUNTER_VACANCY_TURNS)
	RECRUITMENT_VACANCY_TURNS = GameConfig.get_int("population", "recruitment_vacancy_turns", RECRUITMENT_VACANCY_TURNS)
	ENCOUNTER_VACANCY_JITTER_TURNS = GameConfig.get_int("population", "encounter_vacancy_jitter_turns", ENCOUNTER_VACANCY_JITTER_TURNS)
	RECRUITMENT_VACANCY_JITTER_TURNS = GameConfig.get_int("population", "recruitment_vacancy_jitter_turns", RECRUITMENT_VACANCY_JITTER_TURNS)
	HEAL_RATE_ENCAMPED = GameConfig.get_int("healing", "encamped_rate", HEAL_RATE_ENCAMPED)
	HEAL_RATE_RESTING = GameConfig.get_int("healing", "resting_rate", HEAL_RATE_RESTING)
	HEAL_RATE_MOVING = GameConfig.get_int("healing", "moving_rate", HEAL_RATE_MOVING)


func start_new_game(new_player_name: String = DEFAULT_PLAYER_NAME) -> void:
	reset()
	gold = STARTING_GOLD
	player_name = new_player_name


func reset() -> void:
	# The roster owns copies so a session cannot mutate the shared default
	# data. The onboarding decision (2026-08-13): the campaign opens with a
	# four-warrior roster — warrior_001 keeps its legacy id, the other three
	# get generated ids, exactly like every later mint (see _new_instance_id).
	adventurers = [get_default_warrior()]
	for warrior_number in range(2, STARTING_ROSTER_SIZE + 1):
		adventurers.append(get_default_warrior(_new_instance_id(), "Warrior %d" % warrior_number))
	# Every template starts as a live offer (the decided 3 warriors + 1 scout
	# composition), each claimed through its own generated-id record.
	recruitment_candidates = []
	for template in RECRUITMENT_CANDIDATE_TEMPLATES:
		recruitment_candidates.append(_make_recruitment_offer(template))
	recruitment_vacancies = []
	parties = []
	selected_party_id = ""
	selected_encounter = ""
	campaign_objective_id = "obj_tier1_1_goblin_outpost"
	completed_objectives = []
	unlocked_authored_encounters = ["obj_tier1_1_goblin_outpost"]
	is_campaign_completed = false
	is_free_play_active = false
	total_casualties = 0
	completed_encounters = []
	active_encounters = [
		_make_encounter_instance(GOBLIN_CAMP_ID, GOBLIN_CAMP_ID, EXPEDITIONS[GOBLIN_CAMP_ID].position),
		_make_encounter_instance(ORC_OUTPOST_ID, ORC_OUTPOST_ID, EXPEDITIONS[ORC_OUTPOST_ID].position),
	]
	encounter_vacancies = []
	_used_encounter_template_ids = [GOBLIN_CAMP_ID, ORC_OUTPOST_ID]
	world_turn = 1
	gold = 0
	guild_hall_level = 1
	temple_level = 0
	blacksmith_level = 0
	blacksmith_craft_job = {}
	blacksmith_sharpening_job = {}
	alchemy_workshop_level = 0
	alchemy_craft_job = {}
	runic_workshop_level = 0
	runic_craft_job = {}
	pending_reward = 0
	mana_crystals = {}
	banked_gear = {}
	owned_item_instances = {}
	banked_item_instance_ids = []
	pending_mana_crystals = {}
	pending_gear = {}
	battle_reward = 0
	battle_mana_crystals = {}
	battle_gear = {}
	has_trading_post = true
	shop_level = 1
	shop_gold = SHOP_LEVEL_ONE_GOLD_CAP
	player_name = DEFAULT_PLAYER_NAME
	tutorial_progress = {}


## Maximum number of parties a campaign may have at once. The Guild Hall
## level 2 -> 3 upgrade raising this from 1 to 2 is a recorded progression
## rule, but its implementation is deferred to roadmap part 4 (multi-party
## play) — see the onboarding decision recorded in docs/gap-analysis.md.
func get_max_party_count() -> int:
	return 1


func create_party(party_name: String = "Party 1") -> bool:
	if parties.size() >= get_max_party_count():
		return false

	parties.append({
		"id": FIRST_PARTY_ID,
		"member_ids": [] as Array[String],
		"location_id": STARTING_SETTLEMENT_ID,
		"world_position": STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": false,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
		"name": party_name,
		# TBD: party-level progression data. Placeholder only.
		"progression": {},
		# TBD: free-form party metadata. Placeholder only.
		"metadata": {},
	})
	selected_party_id = FIRST_PARTY_ID
	return true


func get_selected_party() -> Dictionary:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return {}
	return parties[party_index]


func get_party(party_id: String) -> Dictionary:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return {}
	return parties[party_index].duplicate(true)


func get_adventurer(adventurer_id: String) -> Dictionary:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return {}
	return adventurers[adventurer_index].duplicate(true)


func get_deployable_encamped_parties() -> Array[Dictionary]:
	var deployable: Array[Dictionary] = []
	for party in parties:
		if _is_party_eligible_for_deployment(party):
			deployable.append(party.duplicate(true))
	return deployable


## Every encamped party (settlement, not deployed), regardless of whether it
## has room or an available member — unlike get_deployable_encamped_parties(),
## a full-but-encamped party is still a valid unit-assignment target. Shares
## the encamped half of that same "ready" concept via _is_party_encamped so
## the two queries cannot silently drift apart.
func get_encamped_parties() -> Array[Dictionary]:
	var encamped: Array[Dictionary] = []
	for party in parties:
		if _is_party_encamped(party):
			encamped.append(party.duplicate(true))
	return encamped


func deploy_party(party_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1 or not _is_party_eligible_for_deployment(parties[party_index]):
		return false

	selected_party_id = party_id
	parties[party_index].deployed = true
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func get_available_adventurers() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for adventurer in adventurers:
		if is_adventurer_available(adventurer.id):
			available.append(adventurer)
	return available


func is_adventurer_available(adventurer_id: String) -> bool:
	var adventurer := get_adventurer(adventurer_id)
	return not adventurer.is_empty() and adventurer.availability_status == "available" and not _is_adventurer_assigned(adventurer_id)


func has_recruitment_candidate(candidate_id: String) -> bool:
	return _get_recruitment_candidate_index(candidate_id) != -1


func is_party_deployable(party_id: String) -> bool:
	var party := get_party(party_id)
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


## Rejects a target party that is not encamped (deployed, or outside the
## starting settlement) in addition to the existing unknown-party/unknown-
## adventurer/already-assigned checks — a party that is out in the field has
## nowhere to receive a new member. Also rejects if the party is at its size cap.
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if (
		party_index == -1
		or not _is_party_encamped(parties[party_index])
		or not _has_adventurer(adventurer_id)
		or _is_adventurer_assigned(adventurer_id)
		or parties[party_index].member_ids.size() >= get_max_party_size()
	):
		return false

	var member_ids: Array = parties[party_index].member_ids
	member_ids.append(adventurer_id)
	return true


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	return assign_adventurer_to_party(selected_party_id, adventurer_id)


## Debug-only convenience for populating the roster (see the debug menu).
## Mints a generated id (see _new_instance_id) and a cosmetic per-class
## counter name — identity never depends on sequential numbering, so no
## collision machinery is needed.
func recruit_adventurer() -> void:
	adventurers.append(get_default_warrior(_new_instance_id(), _next_cosmetic_adventurer_name("warrior")))


## Seeds a template-derived record's stats/progression with the authored
## baseline for its class. RECRUITMENT_CANDIDATE_TEMPLATES intentionally omits
## those mutable fields, so purchase_recruit() and
## _spawn_next_recruitment_offer() both call this before a template-derived
## record can be purchased into the roster.
func _seed_adventurer_baseline_stats(record: Dictionary) -> Dictionary:
	var class_id: String = record.get("class", "warrior")
	var baseline: Dictionary
	if class_id == "scout":
		baseline = get_default_scout(str(record.id), str(record.name))
	elif class_id == "cleric":
		baseline = get_default_cleric(str(record.id), str(record.name))
	else:
		baseline = get_default_warrior()
	record["stats"] = baseline.stats.duplicate(true)
	record["health"] = baseline.health
	record["progression"] = baseline.progression.duplicate(true)
	return record


## A recruitment template is claimed once any roster adventurer or live
## offer carries its template_id — the explicit replacement for the old
## id-collision inference (generated ids can never collide, so identity and
## claiming are now separate concerns).
func _is_recruitment_template_claimed(template_id: String) -> bool:
	for adventurer in adventurers:
		if adventurer.get("template_id", "") == template_id:
			return true
	for candidate in recruitment_candidates:
		if candidate.get("template_id", "") == template_id:
			return true
	return false


## The one shared mint for every newly created unit or item instance: a
## hidden, generated, collision-free GUID-style id from instance_id_roll.
## Identity never depends on the display name or on class-derived sequential
## numbering; ids are opaque and never shown in the UI.
func _new_instance_id() -> String:
	return instance_id_roll.call()


## Cosmetic per-class display name for a freshly minted unit: a plain class
## name for a class's first ever unit, "<Class> N" afterwards, where N
## counts every roster adventurer and live offer of that class. Names are
## purely cosmetic — a duplicated name carries no correctness risk.
func _next_cosmetic_adventurer_name(class_id: String) -> String:
	var display_class := "Warrior"
	if class_id == "scout":
		display_class = "Scout"
	elif class_id == "cleric":
		display_class = "Cleric"
	var count := 0
	for adventurer in adventurers:
		if adventurer.get("class", "") == class_id:
			count += 1
	for candidate in recruitment_candidates:
		if candidate.get("class", "") == class_id:
			count += 1
	var number := count + 1
	return display_class if number == 1 else "%s %d" % [display_class, number]


func get_recruitment_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for candidate in recruitment_candidates:
		candidates.append(candidate.duplicate(true))
	return candidates


## The only normal (non-debug) path onto the roster: validates the candidate
## is still on offer and affordable, deducts its cost exactly once, removes
## it from the catalog, and appends the purchased adventurer (its "cost"
## field dropped, since that is a recruitment-only concern). Purchasing is
## by candidate id; ids are generated and opaque, so no collision guard is
## needed.
func purchase_recruit(candidate_id: String) -> bool:
	var candidate_index := _get_recruitment_candidate_index(candidate_id)
	if (
		candidate_index == -1
		or gold < recruitment_candidates[candidate_index].cost
		or adventurers.size() >= get_roster_cap()
	):
		return false

	var candidate: Dictionary = recruitment_candidates[candidate_index].duplicate(true)
	gold -= candidate.cost
	recruitment_candidates.remove_at(candidate_index)
	candidate.erase("cost")
	adventurers.append(_seed_adventurer_baseline_stats(candidate))
	_start_recruitment_vacancy()
	return true


## Purchases an active offer directly into one specific encamped party. All
## guards run before state changes, so a rejected request is fully inert.
func purchase_recruit_for_party(candidate_id: String, party_id: String) -> bool:
	var candidate_index := _get_recruitment_candidate_index(candidate_id)
	var party_index := _get_party_index(party_id)
	if (
		candidate_index == -1
		or party_index == -1
		or gold < recruitment_candidates[candidate_index].cost
		or not _is_party_encamped(parties[party_index])
		or parties[party_index].member_ids.size() >= get_max_party_size()
		or adventurers.size() >= get_roster_cap()
	):
		return false
	var candidate: Dictionary = recruitment_candidates[candidate_index].duplicate(true)
	gold -= candidate.cost
	recruitment_candidates.remove_at(candidate_index)
	candidate.erase("cost")
	adventurers.append(_seed_adventurer_baseline_stats(candidate))
	parties[party_index].member_ids.append(candidate_id)
	_start_recruitment_vacancy()
	return true


func remove_adventurer_from_selected_party(adventurer_id: String) -> bool:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return false

	var member_ids: Array = parties[party_index].member_ids
	var member_index := member_ids.find(adventurer_id)
	if member_index == -1:
		return false

	member_ids.remove_at(member_index)
	return true


## Shares its eligibility rule with deploy_party()/get_deployable_encamped_parties()
## (see _is_party_eligible_for_deployment) so there is exactly one definition
## of "ready to depart" rather than two that can silently drift apart.
func can_depart_selected_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


func depart_selected_party() -> bool:
	if not can_depart_selected_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = true
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func has_deployed_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and party.deployed


func get_deployed_party_position() -> Vector2i:
	if not has_deployed_party():
		return STARTING_SETTLEMENT_WORLD_POSITION
	return get_selected_party().world_position


func set_deployed_party_position(position: Vector2i) -> bool:
	if not has_deployed_party():
		return false

	parties[_get_selected_party_index()].world_position = position
	return true


func get_deployed_party_route() -> Array[Vector2i]:
	if not has_deployed_party():
		return []
	return get_selected_party().travel_route


func set_deployed_party_route(route: Array[Vector2i]) -> bool:
	if not has_deployed_party() or route.is_empty():
		return false

	var previous: Vector2i = get_selected_party().world_position
	for step in route:
		if _grid_distance(previous, step) != 1:
			return false
		previous = step

	parties[_get_selected_party_index()].travel_route = route
	return true


func clear_deployed_party_route() -> void:
	if not has_deployed_party():
		return
	parties[_get_selected_party_index()].travel_route = [] as Array[Vector2i]


func take_next_route_step() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	var party: Dictionary = parties[party_index]
	if party.movement_spent or party.travel_route.is_empty():
		return false

	var route: Array = party.travel_route
	party.world_position = route[0]
	route.remove_at(0)
	party.movement_spent = true
	return true


func end_world_turn() -> bool:
	# A selected encounter is the durable marker for an unresolved battle. The
	# World Map may be opened to inspect it, but time cannot pass until the
	# player resumes and resolves (or loses) that battle.
	if selected_encounter != "":
		return false

	var auto_moved := false
	if has_deployed_party() and not get_selected_party().movement_spent:
		auto_moved = take_next_route_step()

	world_turn += 1
	_advance_blacksmith_jobs()
	_advance_alchemy_craft_job()
	_advance_runic_craft_job()
	if shop_level >= 1:
		gold += _shop_income_per_turn()
	if shop_level >= 1 and world_turn % 10 == 0:
		shop_gold = max(shop_gold, shop_gold_cap())
	_apply_natural_recovery()
	if has_deployed_party():
		parties[_get_selected_party_index()].movement_spent = false
	_advance_encounter_vacancies()
	_advance_recruitment_vacancies()
	return auto_moved


## Economy floor (docs/designs/campaign-loop.md): 2/5/10 gold per World Map
## Turn at Shop tiers 1/2/3, gated by shop_level in end_world_turn() (level 0
## -- the legacy "no Shop" state -- grants nothing there, so this never needs
## its own zero case).
func _shop_income_per_turn() -> int:
	if shop_level >= 3:
		return SHOP_INCOME_LEVEL_3
	if shop_level >= 2:
		return SHOP_INCOME_LEVEL_2
	return SHOP_INCOME_PER_TURN


func return_deployed_party_to_settlement() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = false
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	parties[party_index].travel_route = [] as Array[Vector2i]
	parties[party_index].movement_spent = false
	return true


func _get_selected_party_index() -> int:
	return _get_party_index(selected_party_id)


func _get_party_index(party_id: String) -> int:
	for party_index in parties.size():
		if parties[party_index].id == party_id:
			return party_index
	return -1


func _get_adventurer_index(adventurer_id: String) -> int:
	for adventurer_index in adventurers.size():
		if adventurers[adventurer_index].id == adventurer_id:
			return adventurer_index
	return -1


func _has_adventurer(adventurer_id: String) -> bool:
	return _get_adventurer_index(adventurer_id) != -1


func _get_recruitment_candidate_index(candidate_id: String) -> int:
	for candidate_index in recruitment_candidates.size():
		if recruitment_candidates[candidate_index].id == candidate_id:
			return candidate_index
	return -1


func _party_has_available_member(party: Dictionary) -> bool:
	for adventurer in adventurers:
		if adventurer.id in party.member_ids and adventurer.availability_status == "available":
			return true
	return false


func _is_party_eligible_for_deployment(party: Dictionary) -> bool:
	return _is_party_encamped(party) and _party_has_available_member(party)


## The shared "encamped" half of both deployment eligibility and unit
## assignment: in the starting settlement and not out in the field. Neither
## caller should duplicate this boolean expression on its own.
func _is_party_encamped(party: Dictionary) -> bool:
	return party.location_id == STARTING_SETTLEMENT_ID and not party.deployed


func _is_adventurer_assigned(adventurer_id: String) -> bool:
	for party in parties:
		if adventurer_id in party.member_ids:
			return true
	return false


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _resolve_enemy_composition(difficulty: int) -> Dictionary:
	var options: Array = STAR_ENEMY_COMPOSITIONS.get(difficulty, STAR_ENEMY_COMPOSITIONS[1])
	var option: Dictionary = options[0]
	if options.size() > 1:
		option = options[enemy_composition_roll.call(options.size())]
	var enemy: Dictionary = option.enemy.duplicate(true)
	enemy["count"] = enemy_count_roll.call(option.count_min, option.count_max)
	return enemy


## True for exactly the twelve authored campaign-ladder node ids -- the
## CAMPAIGN_OBJECTIVES keys, which double as their own EXPEDITIONS key and
## encounter id (see CAMPAIGN_OBJECTIVES' own doc comment). False for every
## sandbox template id (goblin_camp/orc_outpost/ruined_fortress) and every
## active-encounter instance id derived from one of them.
func is_authored_encounter(encounter_id: String) -> bool:
	return CAMPAIGN_OBJECTIVES.has(encounter_id)


## Gates enter_encounter(): a sandbox id is always enterable (matching prior
## behavior), but an authored id must be both currently unlocked and not
## already cleared -- authored objectives never respawn or reopen (see
## docs/designs/campaign-loop.md's "Objectives, gates, and encounter
## threat" contract).
func can_enter_encounter(encounter_id: String) -> bool:
	if not is_authored_encounter(encounter_id):
		return true
	return unlocked_authored_encounters.has(encounter_id) and not completed_encounters.has(encounter_id)


func enter_encounter(encounter_id: String) -> void:
	if not can_enter_encounter(encounter_id):
		return
	selected_encounter = encounter_id
	var instance_index := _get_active_encounter_index(encounter_id)
	# An authored node's active-encounter instance (see the debug menu's
	# "Jump to Pre-Boss Encounter" scenario) carries its own fixed formation
	# -- it must never be overwritten by the sandbox star-tier reroll below,
	# which only applies to a goblin_camp/orc_outpost/ruined_fortress-derived
	# instance.
	if instance_index != -1 and not is_authored_encounter(encounter_id):
		active_encounters[instance_index].enemy = _resolve_enemy_composition(
			active_encounters[instance_index].difficulty
		)


## Marks the current selection complete (once — a re-completion of an
## already-completed id is a no-op) and, only when it names a still-live
## active instance, removes that instance and opens an encounter vacancy.
## Ids that name a template directly rather than a live instance (e.g. the
## debug menu's raw battlefield shortcuts) still record history and queue
## their reward, but never touch active_encounters/encounter_vacancies since
## there was no real instance to clear. On first completion, a flat gold
## bonus is queued: randi_range(0, 5) * difficulty, scaled by the
## expedition's star difficulty.
func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
		# Mixed-formation authored nodes (see EXPEDITIONS' "enemies" field)
		# roll loot once per group, each with its own count merged in, rather
		# than the legacy single "enemy" + "count" template's one call.
		if expedition.has("enemies"):
			for group in expedition.enemies:
				var enemy_with_count: Dictionary = group.get("enemy", {}).duplicate(true)
				enemy_with_count["count"] = int(group.get("count", 1))
				_roll_and_queue_loot(enemy_with_count)
		else:
			_roll_and_queue_loot(expedition.get("enemy", {}))
		battle_reward += loot_gold_roll.call(18, 22) * int(expedition.get("difficulty", 1))
		_clear_active_encounter(selected_encounter)
		# An authored node's own encounter_id is exactly its CAMPAIGN_
		# OBJECTIVES key (see that catalog's own doc comment) -- clearing it
		# also completes the matching campaign objective, unlocking the next
		# node (or, for the final boss, recording campaign victory -- see
		# complete_campaign_objective()/set_campaign_victory()).
		if is_authored_encounter(selected_encounter):
			complete_campaign_objective(selected_encounter)
	selected_encounter = ""



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
		battle_reward += loot_gold_roll.call(table.gold_min, table.gold_max) * table.gold_multiplier
		var crystal_tier: int = table.mana_crystal_tier
		battle_mana_crystals[crystal_tier] = battle_mana_crystals.get(crystal_tier, 0) + 1
		if loot_gear_roll.call() < GEAR_DROP_CHANCE:
			battle_gear[table.gear_item_id] = battle_gear.get(table.gear_item_id, 0) + 1


func abandon_current_encounter() -> void:
	selected_encounter = ""


## Pre-battle Withdraw (docs/plans/2026-08-21-stage-1-campaign-spine/
## 01-pre-battle-withdraw.md): a nonlethal alternative to entering
## encounter_id, available only before Battlefield is ever reached. Returns
## an empty array (no mutation at all) unless the deployed party is standing
## on encounter_id, encounter_id is currently enterable, and no battle is
## already selected. Otherwise rolls once per living deployed member via
## roll.call(): a result below 0.90 leaves health untouched; 0.90 or above
## subtracts ceili(max_health * 0.10), clamped to a minimum of 1 HP by
## set_adventurer_health()'s own clamp, so Withdraw can never kill. Clears no
## campaign/objective/reward state and leaves encounter_id itself untouched
## (still enterable afterward); only records a route home so the party must
## still walk it back one World Map Turn at a time, exactly like a
## player-planned route -- unlike return_deployed_party_to_settlement()'s
## instant teleport, which this deliberately does not call. Returns one
## {id, previous_health, new_health} Dictionary per rolled member for UI
## feedback.
func withdraw_from_encounter(encounter_id: String, roll: Callable) -> Array[Dictionary]:
	if not has_deployed_party() or selected_encounter != "":
		return []
	if not can_enter_encounter(encounter_id):
		return []
	var expedition := get_expedition(encounter_id)
	if not expedition.has("position") or expedition.position != get_deployed_party_position():
		return []

	var results: Array[Dictionary] = []
	for member_id in get_selected_party().member_ids:
		var previous_health := get_current_health(member_id)
		var new_health := previous_health
		if roll.call() >= 0.90:
			var max_health := get_effective_max_health(member_id)
			set_adventurer_health(member_id, previous_health - ceili(max_health * 0.10))
			new_health = get_current_health(member_id)
		results.append({"id": member_id, "previous_health": previous_health, "new_health": new_health})

	set_deployed_party_route(_build_route_to_settlement())
	return results


## Manhattan-step route builder mirroring world_map.gd's build_route(): pure
## grid-agnostic path construction (see WORLD_GRID_WIDTH/HEIGHT above) is
## duplicated here rather than reused because GameSession owns no Grid
## instance -- only World Map's own script holds one, for on-screen bounds
## validation this call site never needs (both endpoints are always
## in-bounds authored/settlement positions).
func _build_route_to_settlement() -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var current := get_deployed_party_position()
	var destination := STARTING_SETTLEMENT_WORLD_POSITION
	while current.x != destination.x:
		current.x += 1 if destination.x > current.x else -1
		route.append(current)
	while current.y != destination.y:
		current.y += 1 if destination.y > current.y else -1
		route.append(current)
	return route


## A duplicate of the current node's CAMPAIGN_OBJECTIVES entry, or {} once
## the campaign is complete (campaign_objective_id is "" from that point on
## -- see complete_campaign_objective()).
func get_current_campaign_objective() -> Dictionary:
	return CAMPAIGN_OBJECTIVES.get(campaign_objective_id, {}).duplicate(true)


func is_objective_completed(id: String) -> bool:
	return completed_objectives.has(id)


## Marks id complete, unlocks its successor objective/encounter, and
## advances campaign_objective_id to it. A no-op for an unknown id or one
## already in completed_objectives, so a repeated call can never double-
## append or re-unlock. Completing the final node (an empty
## next_objective_id) instead atomically records campaign victory via
## set_campaign_victory() rather than advancing to a next id that doesn't
## exist.
func complete_campaign_objective(id: String) -> void:
	if not CAMPAIGN_OBJECTIVES.has(id) or is_objective_completed(id):
		return
	completed_objectives.append(id)
	var next_id: String = CAMPAIGN_OBJECTIVES[id].get("next_objective_id", "")
	if next_id.is_empty():
		campaign_objective_id = ""
		set_campaign_victory()
		return
	if not unlocked_authored_encounters.has(next_id):
		unlocked_authored_encounters.append(next_id)
	campaign_objective_id = next_id
	campaign_progress_changed.emit()


## Atomically flags final-boss victory and unlocks free play. Idempotent
## (calling it again once both flags are already set changes nothing and
## emits nothing further).
func set_campaign_victory() -> void:
	if is_campaign_completed and is_free_play_active:
		return
	is_campaign_completed = true
	is_free_play_active = true
	campaign_progress_changed.emit()
	campaign_victory.emit()


## Read once by the Campaign Victory screen (see scripts/ui/victory_screen.gd)
## right after set_campaign_victory() flips is_campaign_completed -- every
## value here is a plain durable-state read, never itself mutated. "Upgrades
## completed" sums every building's level above its unbuilt/base floor:
## Guild Hall and Shop start at level 1, so their contribution is level - 1;
## Temple/Blacksmith/Alchemy Workshop/Runic Workshop start at 0 (unbuilt), so
## their own level already is their upgrade count.
func get_campaign_victory_summary() -> Dictionary:
	return {
		"world_turns": world_turn,
		"battles_won": completed_encounters.size(),
		"casualties": total_casualties,
		"gold_banked": gold,
		"upgrades_completed": (
			(guild_hall_level - 1) + temple_level + blacksmith_level
			+ alchemy_workshop_level + runic_workshop_level + (shop_level - 1)
		),
	}


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


## Discards this battle's own not-yet-shared loot store outright, the other
## way a battle can end besides merge_battle_loot_into_party() -- see
## BattleController.try_retreat(), which calls this instead of ever letting
## a Retreat's loot reach the party's own pending_* store.
func discard_battle_loot() -> void:
	battle_reward = 0
	battle_mana_crystals = {}
	battle_gear = {}


## True whenever this battle's own loot store (battle_reward/battle_gear/
## battle_mana_crystals) still holds anything merge_battle_loot_into_party()
## has not yet folded into the party's carried store -- i.e. the window
## between complete_current_encounter() clearing selected_encounter and the
## player leaving the Battle Result screen for the World Map. See
## GameManager.can_save_current_campaign(), which ANDs this in alongside the
## "no active encounter" guard so a save can never freeze loot in this
## transient, not-yet-settled bucket.
func has_unsettled_battle_loot() -> bool:
	return battle_reward != 0 or not battle_gear.is_empty() or not battle_mana_crystals.is_empty()


## Merges the party's carried store into the Encampment's bank -- the other
## half of the shared _merge_counts() pair (see merge_battle_loot_into_
## party() for the battle -> party merge). pending_gear holds two different
## kinds of key with the same id->count shape banked_gear/pending_gear
## always used: an ordinary stackable item id (banked into banked_gear, same
## as always) and -- since resolve_battle_deaths() -- a unique owned-item
## instance id recovered from a slain adventurer's equipment (see that
## function). An instance id must bank into banked_item_instance_ids
## instead, preserving its one-of-a-kind modifier record rather than
## folding it into a fungible count; _merge_counts() alone cannot tell the
## two apart, so this walks pending_gear itself rather than reusing it.
func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	for item_id in pending_gear:
		var count: int = int(pending_gear[item_id])
		if count <= 0:
			continue
		if owned_item_instances.has(item_id):
			if not banked_item_instance_ids.has(item_id):
				banked_item_instance_ids.append(item_id)
		else:
			banked_gear[item_id] = banked_gear.get(item_id, 0) + count
	pending_gear = {}
	_merge_counts(pending_mana_crystals, mana_crystals)
	pending_mana_crystals = {}
	return deposited


## Party-wipe forfeiture (docs/designs/campaign-loop.md's loss rule): every
## pending pickup this run -- ordinary gear counts and any unique item
## instances recovered from a fallen party member alike (see
## resolve_battle_deaths()) -- plus this run's own unbanked reward and gold
## already on hand are lost outright ("a wipe loses all gold and loot").
## Preserved: completed campaign objectives, building levels, and anything
## already banked before this run (banked_gear/mana_crystals/
## banked_item_instance_ids are never touched here). A pending instance id's
## owned_item_instances record is erased too -- it was never banked, so
## nothing else still references it once this forfeits it.
func resolve_party_wipe() -> void:
	for item_id in pending_gear:
		if owned_item_instances.has(item_id):
			owned_item_instances.erase(item_id)
	pending_reward = 0
	pending_mana_crystals = {}
	pending_gear = {}
	gold = 0


func get_max_party_size() -> int:
	if guild_hall_level >= 3:
		return GUILD_HALL_LEVEL_3_PARTY_CAP
	if guild_hall_level >= 2:
		return GUILD_HALL_LEVEL_2_PARTY_CAP
	return GUILD_HALL_LEVEL_1_PARTY_CAP


## Maximum roster size (see purchase_recruit()/purchase_recruit_for_party()):
## 10/15/20 at Guild Hall levels 1/2/3.
func get_roster_cap() -> int:
	if guild_hall_level >= 3:
		return GUILD_HALL_LEVEL_3_ROSTER_CAP
	if guild_hall_level >= 2:
		return GUILD_HALL_LEVEL_2_ROSTER_CAP
	return GUILD_HALL_LEVEL_1_ROSTER_CAP


## Maximum simultaneous recruitment offers (see _start_recruitment_vacancy()/
## _advance_recruitment_vacancies()): 4/8/10 at Guild Hall levels 1/2/3.
func get_recruitment_offer_cap() -> int:
	if guild_hall_level >= 3:
		return GUILD_HALL_LEVEL_3_OFFER_CAP
	if guild_hall_level >= 2:
		return GUILD_HALL_LEVEL_2_OFFER_CAP
	return RECRUITMENT_OFFER_CAP


func _guild_hall_upgrade_cost() -> int:
	return GUILD_HALL_LEVEL_3_UPGRADE_COST if guild_hall_level == 2 else GUILD_HALL_UPGRADE_COST


func can_upgrade_guild_hall() -> bool:
	return guild_hall_level < GUILD_HALL_MAX_LEVEL and gold >= _guild_hall_upgrade_cost()


func upgrade_guild_hall() -> bool:
	if not can_upgrade_guild_hall():
		return false
	gold -= _guild_hall_upgrade_cost()
	guild_hall_level += 1
	return true


func can_build_temple() -> bool:
	return temple_level == 0 and gold >= TEMPLE_BUILD_COST


## Guarantees a real, immediately recruitable Cleric offer the moment the
## Temple is built -- a one-time grant distinct from cleric_offer_roll's
## ongoing 25% chance on later recruitment-vacancy refills (see that
## Callable's doc comment). Reuses _advance_recruitment_vacancies()'s
## established overflow policy: evict the oldest (FIFO head) offer first
## when the pool is already at get_recruitment_offer_cap(), otherwise just
## append.
func build_temple() -> bool:
	if not can_build_temple():
		return false
	gold -= TEMPLE_BUILD_COST
	temple_level = 1
	if recruitment_candidates.size() >= get_recruitment_offer_cap():
		recruitment_candidates.remove_at(0)
	var offer := _make_overflow_recruitment_offer("cleric")
	offer["cost"] = 10
	recruitment_candidates.append(offer)
	return true


func can_build_blacksmith() -> bool:
	return blacksmith_level == 0 and gold >= BLACKSMITH_BUILD_COST


func build_blacksmith() -> bool:
	if not can_build_blacksmith():
		return false
	gold -= BLACKSMITH_BUILD_COST
	blacksmith_level = 1
	return true


func get_blacksmith_upgrade_cost() -> int:
	return int(BLACKSMITH_UPGRADE_COSTS.get(blacksmith_level + 1, 0))


func can_upgrade_blacksmith() -> bool:
	var cost := get_blacksmith_upgrade_cost()
	return blacksmith_level > 0 and cost > 0 and gold >= cost


func upgrade_blacksmith() -> bool:
	if not can_upgrade_blacksmith():
		return false
	gold -= get_blacksmith_upgrade_cost()
	blacksmith_level += 1
	return true


func get_blacksmith_craft_cost(item_id: String) -> int:
	if not WEAPONS.has(item_id):
		return 0
	return int(ceil(get_item_sale_price(item_id) * 0.9))


func start_blacksmith_craft(item_id: String) -> bool:
	if not blacksmith_craft_job.is_empty() or not WEAPONS.has(item_id):
		return false
	var required_level := _blacksmith_required_level_for_weapon(item_id)
	var cost := get_blacksmith_craft_cost(item_id)
	if blacksmith_level < required_level or gold < cost:
		return false
	gold -= cost
	blacksmith_craft_job = {"item_id": item_id, "completion_turn": world_turn + BLACKSMITH_CRAFT_DURATION_TURNS}
	return true


func start_sharpening(item_id: String) -> bool:
	if blacksmith_level < 1 or not blacksmith_sharpening_job.is_empty() or not WEAPONS.has(item_id):
		return false
	if banked_gear.get(item_id, 0) <= 0:
		return false
	var cost := get_item_sale_price(item_id) * 2
	if gold < cost:
		return false
	gold -= cost
	banked_gear[item_id] -= 1
	blacksmith_sharpening_job = {"item_id": item_id, "completion_turn": world_turn + BLACKSMITH_SHARPENING_DURATION_TURNS}
	return true


func get_blacksmith_job_turns_remaining(job: Dictionary) -> int:
	return max(0, int(job.get("completion_turn", world_turn)) - world_turn)


func _blacksmith_required_level_for_weapon(item_id: String) -> int:
	if item_id.ends_with("_iron"):
		return 2
	if item_id.ends_with("_steel"):
		return 3
	return BLACKSMITH_MAX_LEVEL + 1


func _advance_blacksmith_jobs() -> void:
	if not blacksmith_craft_job.is_empty() and get_blacksmith_job_turns_remaining(blacksmith_craft_job) == 0:
		var crafted_item_id := str(blacksmith_craft_job.item_id)
		banked_gear[crafted_item_id] = banked_gear.get(crafted_item_id, 0) + 1
		blacksmith_craft_job = {}
	if not blacksmith_sharpening_job.is_empty() and get_blacksmith_job_turns_remaining(blacksmith_sharpening_job) == 0:
		var base_item_id := str(blacksmith_sharpening_job.item_id)
		var instance_id := _new_instance_id()
		# The input was consumed at job start, so this completion needs no
		# second bank transfer. Materialize the unique record directly.
		owned_item_instances[instance_id] = {
			"id": instance_id,
			"base_item_id": base_item_id,
			"treatment_id": SHARPENED_TREATMENT_ID,
			"enhancement_id": "",
			"rune_id": "",
			"modifier_tiers": {"treatment": 1},
		}
		banked_item_instance_ids.append(instance_id)
		blacksmith_sharpening_job = {}


func can_build_alchemy_workshop() -> bool:
	return alchemy_workshop_level == 0 and gold >= ALCHEMY_WORKSHOP_BUILD_COST


func build_alchemy_workshop() -> bool:
	if not can_build_alchemy_workshop():
		return false
	gold -= ALCHEMY_WORKSHOP_BUILD_COST
	alchemy_workshop_level = 1
	return true


func can_upgrade_alchemy_workshop() -> bool:
	return alchemy_workshop_level == 1 and gold >= ALCHEMY_WORKSHOP_UPGRADE_COST


func upgrade_alchemy_workshop() -> bool:
	if not can_upgrade_alchemy_workshop():
		return false
	gold -= ALCHEMY_WORKSHOP_UPGRADE_COST
	alchemy_workshop_level = 2
	return true


func start_alchemy_craft(item_id: String) -> bool:
	if not alchemy_craft_job.is_empty() or not POTIONS.has(item_id):
		return false
	var potion: Dictionary = POTIONS[item_id]
	if alchemy_workshop_level < int(potion.required_level) or gold < int(potion.gold_cost):
		return false
	var crystal_tier := _first_available_mana_crystal_tier(int(potion.minimum_crystal_tier))
	if crystal_tier == 0:
		return false
	gold -= int(potion.gold_cost)
	mana_crystals[crystal_tier] -= 1
	if mana_crystals[crystal_tier] == 0:
		mana_crystals.erase(crystal_tier)
	alchemy_craft_job = {"item_id": item_id, "completion_turn": world_turn + ALCHEMY_CRAFT_DURATION_TURNS}
	return true


func _first_available_mana_crystal_tier(minimum_tier: int) -> int:
	var matching_tiers: Array[int] = []
	for raw_tier in mana_crystals:
		var tier := int(raw_tier)
		if tier >= minimum_tier and int(mana_crystals[raw_tier]) > 0:
			matching_tiers.append(tier)
	matching_tiers.sort()
	return 0 if matching_tiers.is_empty() else matching_tiers[0]


func get_alchemy_job_turns_remaining() -> int:
	return max(0, int(alchemy_craft_job.get("completion_turn", world_turn)) - world_turn)


func _advance_alchemy_craft_job() -> void:
	if alchemy_craft_job.is_empty() or get_alchemy_job_turns_remaining() != 0:
		return
	var crafted_item_id := str(alchemy_craft_job.item_id)
	banked_gear[crafted_item_id] = banked_gear.get(crafted_item_id, 0) + 1
	alchemy_craft_job = {}


func can_build_runic_workshop() -> bool:
	return runic_workshop_level == 0 and gold >= RUNIC_WORKSHOP_BUILD_COST


func build_runic_workshop() -> bool:
	if not can_build_runic_workshop():
		return false
	gold -= RUNIC_WORKSHOP_BUILD_COST
	runic_workshop_level = 1
	return true


func can_upgrade_runic_workshop() -> bool:
	return runic_workshop_level == 1 and gold >= RUNIC_WORKSHOP_UPGRADE_COST


func upgrade_runic_workshop() -> bool:
	if not can_upgrade_runic_workshop():
		return false
	gold -= RUNIC_WORKSHOP_UPGRADE_COST
	runic_workshop_level = 2
	return true


func start_runic_craft(target_instance_id: String) -> bool:
	if runic_workshop_level < 1 or not runic_craft_job.is_empty() or target_instance_id.is_empty():
		return false
	if not _is_owned_armor_instance(target_instance_id):
		return false
	if gold < THORN_RUNE_GOLD_COST:
		return false
	var crystal_tier := _first_available_mana_crystal_tier(THORN_RUNE_MINIMUM_CRYSTAL_TIER)
	if crystal_tier == 0:
		return false
	gold -= THORN_RUNE_GOLD_COST
	mana_crystals[crystal_tier] -= 1
	if mana_crystals[crystal_tier] == 0:
		mana_crystals.erase(crystal_tier)
	runic_craft_job = {
		"target_instance_id": target_instance_id,
		"rune_id": THORN_RUNE_ID,
		"completion_turn": world_turn + RUNIC_CRAFT_DURATION_TURNS,
	}
	return true


func get_runic_job_turns_remaining() -> int:
	return max(0, int(runic_craft_job.get("completion_turn", world_turn)) - world_turn)


func _advance_runic_craft_job() -> void:
	if runic_craft_job.is_empty() or get_runic_job_turns_remaining() != 0:
		return
	var target_instance_id := str(runic_craft_job.target_instance_id)
	# The target was validated and remains durably owned. If an invalid save or
	# later state corruption somehow breaks that invariant, discard the paid job
	# rather than applying a rune to an incompatible item.
	if _is_owned_armor_instance(target_instance_id):
		set_item_instance_modifier(target_instance_id, "rune", THORN_RUNE_ID, 1)
	runic_craft_job = {}


func _is_owned_armor_instance(instance_id: String) -> bool:
	if not owned_item_instances.has(instance_id):
		return false
	var item: Dictionary = get_item_definition(instance_id)
	return str(item.get("slot", "")) == "armor"


func can_purchase_trading_post() -> bool:
	return false


func purchase_trading_post() -> bool:
	return false


func shop_gold_cap() -> int:
	return SHOP_LEVEL_TWO_GOLD_CAP if shop_level >= 2 else SHOP_LEVEL_ONE_GOLD_CAP


func get_shop_catalogue_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	if shop_level <= 0:
		return item_ids
	for item_id in WEAPONS:
		if item_id.ends_with("_iron") or (shop_level >= 2 and item_id.ends_with("_steel")):
			item_ids.append(item_id)
	return item_ids


func _shop_upgrade_cost() -> int:
	return SHOP_LEVEL_3_UPGRADE_COST if shop_level == 2 else SHOP_UPGRADE_COST


func can_upgrade_shop() -> bool:
	return shop_level >= 1 and shop_level < 3 and gold >= _shop_upgrade_cost()


func upgrade_shop() -> bool:
	if not can_upgrade_shop():
		return false
	gold -= _shop_upgrade_cost()
	shop_level += 1
	return true


## Shop Tier 3 unlocks direct purchase of the Minor Healing Potion (restores
## 2-8 HP for 20 gold -- see docs/plans/2026-08-18-core-loop-and-engagement/
## 03-encampment-buildings-and-tier-model.md), the same catalog entry
## Alchemy Workshop crafting already produces (POTIONS.greater_healing_
## potion), banked exactly like a crafted potion so Stores' existing
## sell/equip flow needs no separate code path for it.
func can_buy_healing_potion() -> bool:
	return shop_level >= 3 and gold >= int(POTIONS.greater_healing_potion.gold_cost)


func buy_healing_potion() -> bool:
	if not can_buy_healing_potion():
		return false
	var cost := int(POTIONS.greater_healing_potion.gold_cost)
	gold -= cost
	shop_gold += cost
	banked_gear["greater_healing_potion"] = banked_gear.get("greater_healing_potion", 0) + 1
	return true


func is_encounter_complete(encounter_id: String) -> bool:
	return completed_encounters.has(encounter_id)


## Resolves either a live active-encounter-instance id or a raw template id
## from EXPEDITIONS (checked in that order), returning a safe copy either
## way. The instance branch is what keeps World Map's normal flow working;
## the template branch is what keeps direct template-id callers (the debug
## menu's raw battlefield shortcuts, and get_expedition(GOBLIN_CAMP_ID/
## ORC_OUTPOST_ID) callers generally) working unchanged.
func get_expedition(encounter_id: String) -> Dictionary:
	var instance_index := _get_active_encounter_index(encounter_id)
	if instance_index != -1:
		return active_encounters[instance_index].duplicate(true)
	if not EXPEDITIONS.has(encounter_id):
		return {}
	return EXPEDITIONS[encounter_id].duplicate(true)


## Every THREAT_TURN_INTERVAL world turns elapsed adds one star on top of an
## encounter's own base "difficulty", clamped to the 1-5 range World Map
## markers render (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md). A tunable constant, not
## GameConfig-backed like the balance vars above it in this file -- Step 6's
## simulation/balance harness is the step that revisits its exact value.
## Returns 1 for an unknown encounter id, matching get_expedition()'s own
## "difficulty" fallback.
const THREAT_TURN_INTERVAL := 15


func get_threat_stars(encounter_id: String) -> int:
	var expedition := get_expedition(encounter_id)
	var base_difficulty: int = int(expedition.get("difficulty", 1))
	return clampi(base_difficulty + int(world_turn / THREAT_TURN_INTERVAL), 1, 5)


## Scout strategic reconnaissance (docs/plans/2026-08-18-core-loop-and-
## engagement/04-cleric-class-and-scout-reconnaissance.md). Per index.md's
## locked decision, an encounter discloses NOTHING beyond its bare location
## until party_id's own deployed party contains a Scout AND stands within
## Manhattan distance 3 (_grid_distance) of the encounter's position -- at
## that point both danger_tier AND enemy_types/enemy_counts/enemy_count
## become visible together (rewards and battlefield placement are never
## revealed, at any range). A mixed authored formation (see EXPEDITIONS'
## "enemies" field) fields more than one species: enemy_types and
## enemy_counts are parallel arrays, one entry per composition group (e.g.
## the pre-boss Gatehouse's ["Hobgoblin Elite", "Goblin Archer", "Kobold
## Swarmer"] / [2, 2, 1]), so a caller can render each type with its own
## count rather than one type times the total -- enemy_count remains the
## flat sum across every group, for a caller that only wants the aggregate.
## The legacy single-"enemy" template (the three sandbox expeditions) still
## resolves to exactly one group, so both arrays stay single-element there.
## Returns {} for an unknown party or encounter id. When has_intel is false,
## danger_tier is 0 -- a value no real expedition difficulty ever takes
## (difficulties start at 1) -- meaning "not yet known", not "tier zero";
## callers must gate on has_intel before rendering danger_tier.
func get_party_scouting_intel(party_id: String, encounter_id: String) -> Dictionary:
	var party := get_party(party_id)
	var expedition := get_expedition(encounter_id)
	if party.is_empty() or expedition.is_empty():
		return {}

	var has_scout := false
	for member_id in party.member_ids:
		var member := get_adventurer(str(member_id))
		if not member.is_empty() and str(member.get("class", "")) == "scout":
			has_scout = true
			break

	var within_range: bool = (
		bool(party.get("deployed", false))
		and _grid_distance(party.world_position, expedition.position) <= 3
	)

	if has_scout and within_range:
		var enemy_types: Array[String] = []
		var enemy_counts: Array[int] = []
		var enemy_count := 0
		# Authored nodes (see EXPEDITIONS' "enemies" field) can field more
		# than one species; every group's own name_key and count are reported
		# in parallel arrays, instead of the legacy single "enemy" + "count"
		# template's one-species read below.
		if expedition.has("enemies"):
			for group in expedition.enemies:
				var stats: Dictionary = group.get("enemy", {})
				var count: int = int(group.get("count", 1))
				enemy_types.append(tr(str(stats.get("name_key", ""))))
				enemy_counts.append(count)
				enemy_count += count
		else:
			var enemy: Dictionary = expedition.get("enemy", {})
			var count: int = int(enemy.get("count", 0))
			enemy_types.append(tr(str(enemy.get("name_key", ""))))
			enemy_counts.append(count)
			enemy_count = count
		return {
			"has_intel": true,
			"enemy_types": enemy_types,
			"enemy_counts": enemy_counts,
			"enemy_count": enemy_count,
			"danger_tier": int(expedition.get("difficulty", 1)),
		}

	return {
		"has_intel": false,
		"enemy_types": [] as Array[String],
		"enemy_counts": [] as Array[int],
		"enemy_count": 0,
		"danger_tier": 0,
	}


## Looks up an item id in WEAPONS then ARMORS, returning a safe copy either
## way (an empty Dictionary for an unknown id, matching get_adventurer()'s
## and get_party()'s not-found convention).
func get_item_definition(item_id: String) -> Dictionary:
	if owned_item_instances.has(item_id):
		return get_item_definition(str(owned_item_instances[item_id].base_item_id))
	if WEAPONS.has(item_id):
		return WEAPONS[item_id].duplicate(true)
	if ARMORS.has(item_id):
		return ARMORS[item_id].duplicate(true)
	if POTIONS.has(item_id):
		return POTIONS[item_id].duplicate(true)
	return {}


## Converts exactly one normal banked item into a unique owned instance,
## minting the instance id itself (see _new_instance_id) and returning it
## ("" on rejection). The later crafting slices supply the modifier and
## recipe calls; this boundary establishes the ownership transfer they will
## rely on. Every validation is intentionally before the first mutation so a
## failed conversion is atomic.
func materialize_banked_item_instance(base_item_id: String, explicit_instance_id: String = "") -> Variant:
	if banked_gear.get(base_item_id, 0) <= 0:
		return "" if explicit_instance_id.is_empty() else false
	if get_item_definition(base_item_id).is_empty():
		return "" if explicit_instance_id.is_empty() else false
	var instance_id := explicit_instance_id if not explicit_instance_id.is_empty() else _new_instance_id()
	if explicit_instance_id != "" and owned_item_instances.has(instance_id):
		return false
	banked_gear[base_item_id] -= 1
	owned_item_instances[instance_id] = {
		"id": instance_id,
		"base_item_id": base_item_id,
		"treatment_id": "",
		"enhancement_id": "",
		"rune_id": "",
		"modifier_tiers": {},
	}
	banked_item_instance_ids.append(instance_id)
	return instance_id if explicit_instance_id.is_empty() else true







## Assigns one permanent modifier category.  Categories deliberately map to
## the handbook's persisted fields; a strictly lower tier cannot downgrade a
## unique item, while equal-or-higher tiers replace that category only.
func set_item_instance_modifier(instance_id: String, category: String, modifier_id: String, tier: int) -> bool:
	if not owned_item_instances.has(instance_id) or modifier_id.is_empty() or tier <= 0:
		return false
	var field_by_category := {
		"treatment": "treatment_id",
		"enhancement": "enhancement_id",
		"rune": "rune_id",
	}
	if not field_by_category.has(category):
		return false
	var instance: Dictionary = owned_item_instances[instance_id].duplicate(true)
	var tiers: Dictionary = instance.modifier_tiers
	if tier < int(tiers.get(category, 0)):
		return false
	instance[field_by_category[category]] = modifier_id
	tiers[category] = tier
	instance["modifier_tiers"] = tiers
	owned_item_instances[instance_id] = instance
	return true


const MANA_CRYSTAL_ID_PREFIX := "mana_crystal_"


## Gear sells for half its catalog price (rounded to the nearest integer); a
## mana crystal id ("mana_crystal_<tier>") sells for its full listed value,
## since it was never purchased at a price to halve. An unknown id prices at
## 0 rather than erroring, matching get_item_definition()'s not-found style.
func get_item_sale_price(item_id: String) -> int:
	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
		return MANA_CRYSTAL_VALUES.get(tier, 0)
	var item := get_item_definition(item_id)
	return 0 if item.is_empty() else int(round(item.price / 2.0))


## The shared loot-row shape (id/name/type/count/price) every loot-listing
## screen renders through LootTable — Stores (banked_gear/mana_crystals),
## the victory summary (battle_gear/battle_mana_crystals), and the World
## Map's Party Details screen (pending_gear/pending_mana_crystals), each
## backed by a different pair of GameSession fields but sharing this exact
## row shape and this exact pricing/naming logic.
func build_loot_rows(gear_counts: Dictionary, mana_crystal_counts: Dictionary, item_instance_ids: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in gear_counts:
		var count: int = gear_counts[item_id]
		if count <= 0:
			continue
		var item := get_item_definition(item_id)
		rows.append({
			"id": item_id,
			"name": tr(item.name_key),
			"type": tr("stores.type.%s" % item.slot),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	for instance_id in item_instance_ids:
		var instance_item := get_item_definition(instance_id)
		if instance_item.is_empty():
			continue
		rows.append({
			"id": instance_id,
			"name": tr(instance_item.name_key),
			"type": tr("stores.type.%s" % instance_item.slot),
			"count": 1,
			"price": get_item_sale_price(instance_id),
		})
	for tier in mana_crystal_counts:
		var count: int = mana_crystal_counts[tier]
		if count <= 0:
			continue
		var item_id: String = "%s%d" % [MANA_CRYSTAL_ID_PREFIX, tier]
		rows.append({
			"id": item_id,
			"name": tr("stores.mana_crystal") % tier,
			"type": tr("stores.type.mana_crystal"),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	return rows


## Requires an unlocked Shop and at least `quantity` of item_id in stock (banked_gear
## for gear, mana_crystals for a "mana_crystal_<tier>" id). Rejects and
## mutates nothing otherwise.
func sell_item(item_id: String, quantity: int = 1) -> bool:
	if shop_level <= 0 or quantity <= 0:
		return false
	var total_price := get_item_sale_price(item_id) * quantity
	if total_price <= 0 or shop_gold < total_price:
		return false
	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
		if mana_crystals.get(tier, 0) < quantity:
			return false
		mana_crystals[tier] -= quantity
		gold += total_price
		shop_gold -= total_price
		return true
	if owned_item_instances.has(item_id):
		if quantity != 1 or not banked_item_instance_ids.has(item_id):
			return false
		var sale_price := get_item_sale_price(item_id)
		banked_item_instance_ids.erase(item_id)
		owned_item_instances.erase(item_id)
		gold += sale_price
		shop_gold -= sale_price
		return true
	if banked_gear.get(item_id, 0) < quantity:
		return false
	banked_gear[item_id] -= quantity
	gold += total_price
	shop_gold -= total_price
	return true


func can_sell_item(item_id: String, quantity: int = 1) -> bool:
	if shop_level <= 0 or quantity <= 0:
		return false
	var total_price := get_item_sale_price(item_id) * quantity
	if total_price <= 0 or shop_gold < total_price:
		return false
	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
		return mana_crystals.get(int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX)), 0) >= quantity
	return banked_gear.get(item_id, 0) >= quantity or (quantity == 1 and banked_item_instance_ids.has(item_id))


## Requires an unlocked Shop and enough gold for item_id's full catalog price.
## Buys exactly one unit, banking it into banked_gear.
func buy_item(item_id: String) -> bool:
	# Buying is a catalog operation: an owned instance must never be treated as
	# a template and turned into a second stack entry.
	if not get_shop_catalogue_item_ids().has(item_id):
		return false
	var item: Dictionary = WEAPONS.get(item_id, {})
	if item.is_empty() or gold < int(item.price):
		return false
	gold -= int(item.price)
	shop_gold += int(item.price)
	banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
	return true


## Requires item_id to currently be in banked_gear. See _equip_item_from()
## for the shared add-and-activate logic -- this is identical to
## equip_item_from_party_store() below except which pool it draws from.
func equip_item_from_bank(adventurer_id: String, item_id: String) -> bool:
	if owned_item_instances.has(item_id):
		return _equip_item_instance_from_bank(adventurer_id, item_id)
	return _equip_item_from(banked_gear, adventurer_id, item_id)


func _equip_item_instance_from_bank(adventurer_id: String, instance_id: String) -> bool:
	if not banked_item_instance_ids.has(instance_id):
		return false
	var item := get_item_definition(instance_id)
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if item.is_empty() or adventurer_index == -1 or not can_adventurer_equip_item(adventurer_id, instance_id):
		return false
	if get_carried_item_ids(adventurer_id).size() >= CARRIED_ITEM_CAPACITY:
		return false
	var slot: String = item.slot
	var inventory: Array = adventurers[adventurer_index].equipment["%s_inventory" % slot]
	if inventory.has(instance_id):
		return false
	banked_item_instance_ids.erase(instance_id)
	inventory.append(instance_id)
	adventurers[adventurer_index].equipment[slot] = instance_id
	return true


## Requires item_id to currently be in the party's own store (pending_gear
## -- everything the deployed party has picked up but not yet carried home
## and banked). Used by the victory summary and World Map Party Details'
## Equip actions, both scoped to the currently deployed party, as opposed
## to Stores' Equip, which always draws from the (encamped) bank via
## equip_item_from_bank() above.
func equip_item_from_party_store(adventurer_id: String, item_id: String) -> bool:
	return _equip_item_from(pending_gear, adventurer_id, item_id)


## Shared by equip_item_from_bank()/equip_item_from_party_store(): makes
## item_id the active item for its slot, taking one unit from source_gear
## (a Dictionary of the exact same id -> count shape banked_gear and
## pending_gear both use) unless the unit already carries item_id, in
## which case source_gear is untouched and the already-carried copy is
## just re-activated. Rejects (mutates nothing) for an item not currently
## in source_gear, an unknown item id, or an unknown adventurer.
func _equip_item_from(source_gear: Dictionary, adventurer_id: String, item_id: String) -> bool:
	if source_gear.get(item_id, 0) <= 0:
		return false
	var item := get_item_definition(item_id)
	if item.is_empty():
		return false
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	if not can_adventurer_equip_item(adventurer_id, item_id):
		return false

	var slot: String = item.slot
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		equipment[inventory_key] = []
	var inventory: Array = equipment[inventory_key]
	if get_carried_item_ids(adventurer_id).size() >= CARRIED_ITEM_CAPACITY:
		return false
	if slot == "potion":
		source_gear[item_id] -= 1
		inventory.append(item_id)
		return true
	if not inventory.has(item_id):
		source_gear[item_id] -= 1
		inventory.append(item_id)
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


func get_carried_item_ids(adventurer_id: String) -> Array[String]:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return []
	var carried: Array[String] = []
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	for slot in ["weapon", "armor", "potion"]:
		for item_id in equipment.get("%s_inventory" % slot, []):
			carried.append(str(item_id))
	return carried


func transfer_carried_item(from_adventurer_id: String, to_adventurer_id: String, item_id: String) -> bool:
	if from_adventurer_id == to_adventurer_id:
		return false
	var item := get_item_definition(item_id)
	var from_index := _get_adventurer_index(from_adventurer_id)
	var to_index := _get_adventurer_index(to_adventurer_id)
	if item.is_empty() or from_index == -1 or to_index == -1 or not can_adventurer_equip_item(to_adventurer_id, item_id):
		return false
	if get_carried_item_ids(to_adventurer_id).size() >= CARRIED_ITEM_CAPACITY:
		return false
	var slot: String = item.slot
	var inventory_key := "%s_inventory" % slot
	var from_equipment: Dictionary = adventurers[from_index].equipment
	var to_equipment: Dictionary = adventurers[to_index].equipment
	var from_inventory: Array = from_equipment.get(inventory_key, [])
	if not from_inventory.has(item_id) or (slot != "potion" and from_equipment.get(slot, "") == item_id):
		return false
	if not to_equipment.has(inventory_key):
		to_equipment[inventory_key] = []
	from_inventory.erase(item_id)
	to_equipment[inventory_key].append(item_id)
	return true


func consume_carried_potion(adventurer_id: String, potion_id: String) -> bool:
	if not POTIONS.has(potion_id):
		return false
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var inventory: Array = adventurers[adventurer_index].equipment.get("potion_inventory", [])
	if not inventory.has(potion_id):
		return false
	inventory.erase(potion_id)
	return true


## Switches the active item for `slot` ("weapon" or "armor") to item_id,
## which must already be in that slot's inventory array. No bank
## interaction. Rejects an item not carried in that slot, an unknown slot,
## or an unknown adventurer, mutating nothing.
func activate_carried_item(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	var item := get_item_definition(item_id)
	if not inventory.has(item_id) or item.is_empty() or item.slot != slot:
		return false
	if not can_adventurer_equip_item(adventurer_id, item_id):
		return false
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


## Returns whether an adventurer may use an item. Weapon categories are class
## restricted; armor and consumables remain available to every class.
func can_adventurer_equip_item(adventurer_id: String, item_id: String) -> bool:
	var adventurer := get_adventurer(adventurer_id)
	var item := get_item_definition(item_id)
	if adventurer.is_empty() or item.is_empty():
		return false
	if item.slot != "weapon":
		return true
	var class_definition: Dictionary = CLASS_DEFINITIONS.get(str(adventurer.get("class", "")), {})
	return class_definition.get("allowed_weapon_categories", []).has(str(item.get("category", "")))


## Removes item_id from slot's inventory array and returns one unit to
## banked_gear. Rejects (mutates nothing) if item_id is currently that
## slot's active item — a unit can never end up with an empty active slot,
## so the player must activate something else first — if item_id isn't
## carried in that slot at all, for an unknown slot, or for an unknown
## adventurer.
func unequip_to_bank(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	if not inventory.has(item_id) or equipment.get(slot, "") == item_id:
		return false
	inventory.erase(item_id)
	if owned_item_instances.has(item_id):
		banked_item_instance_ids.append(item_id)
	else:
		banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
	return true


func get_active_encounters() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	for instance in active_encounters:
		instances.append(instance.duplicate(true))
	return instances


func _make_encounter_instance(instance_id: String, template_id: String, position: Vector2i) -> Dictionary:
	var instance: Dictionary = EXPEDITIONS[template_id].duplicate(true)
	instance["id"] = instance_id
	instance["template_id"] = template_id
	instance["position"] = position
	return instance


func _get_active_encounter_index(instance_id: String) -> int:
	for index in active_encounters.size():
		if active_encounters[index].id == instance_id:
			return index
	return -1


## No-ops for an id that does not name a live active instance (e.g. a raw
## template id entered via the debug menu) — see complete_current_encounter().
func _clear_active_encounter(instance_id: String) -> void:
	var index := _get_active_encounter_index(instance_id)
	if index == -1:
		return
	active_encounters.remove_at(index)
	_start_encounter_vacancy()


## Resolves a single bounded delay for a newly opened vacancy via
## vacancy_delay_roll, called once per vacancy (never rerolled while
## ticking -- see _advance_encounter_vacancies()/_advance_recruitment_vacancies()).
## The lower bound is clamped to 1 so a jitter magnitude at or above the base
## can never produce a non-positive or zero-turn wait.
func _resolve_vacancy_delay(base_turns: int, jitter_turns: int) -> int:
	var minimum := maxi(1, base_turns - jitter_turns)
	var maximum := base_turns + jitter_turns
	return vacancy_delay_roll.call(minimum, maximum)


## Distinguishes "no new cooldown starts if already at capacity" (this guard,
## evaluated once at vacancy-open time) from "a clock exists but is capped
## from firing" (the symmetric guard inside _advance_encounter_vacancies).
func _start_encounter_vacancy() -> void:
	if active_encounters.size() >= ENCOUNTER_INSTANCE_CAP:
		return
	var turns_remaining := _resolve_vacancy_delay(ENCOUNTER_VACANCY_TURNS, ENCOUNTER_VACANCY_JITTER_TURNS)
	encounter_vacancies.append({"turns_remaining": turns_remaining})


## Ticks every pending encounter vacancy clock down by one World Map turn. A
## clock that reaches zero fires exactly once: if the cap still has room it
## spawns a new instance; either way the clock is then discarded — a vacancy
## blocked by a full cap does not reschedule itself or catch up later.
func _advance_encounter_vacancies() -> void:
	var still_pending: Array[Dictionary] = []
	for vacancy in encounter_vacancies:
		vacancy.turns_remaining -= 1
		if vacancy.turns_remaining > 0:
			still_pending.append(vacancy)
			continue
		if active_encounters.size() < ENCOUNTER_INSTANCE_CAP:
			active_encounters.append(_spawn_next_encounter_instance())
	encounter_vacancies = still_pending


func _spawn_next_encounter_instance() -> Dictionary:
	var template_id := _choose_encounter_template()
	var position := _choose_encounter_position(template_id)
	if not _used_encounter_template_ids.has(template_id):
		_used_encounter_template_ids.append(template_id)
	return _make_encounter_instance(_mint_encounter_instance_id(), template_id, position)


## Weighted-random by star tier, favoring higher tiers as the player's
## power (adventurer count plus Guild Hall level -- see _player_power())
## grows. Only a template with no currently-active instance is eligible,
## so a refill never activates a second live instance of an
## already-active template. Deliberately replaces the old "show every
## template once before reuse" guarantee: at a fresh campaign's first
## refill the Ruined Fortress would otherwise be the only unseen
## template and would always be forced in regardless of power, defeating
## the point of weighting it down for a weak party.
func _player_power() -> int:
	return adventurers.size() + guild_hall_level


func _star_tier_weight(tier: int, power: int) -> int:
	var clamped_tier: int = clampi(tier, 1, 3)
	return maxi(STAR_WEIGHT_MIN, STAR_WEIGHT_BASE[clamped_tier] + STAR_WEIGHT_PER_POWER[clamped_tier] * power)


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


func _is_encounter_template_active(template_id: String) -> bool:
	for instance in active_encounters:
		if instance.template_id == template_id:
			return true
	return false


## Prefers the template's own documented position; only scans for another
## in-bounds, unoccupied, non-settlement tile if that position is already
## occupied by another active instance, OR if template_id has ever been
## spawned before (tracked by _used_encounter_template_ids). The second
## condition matters for a *reused* template: its documented tile is only
## ever occupied by its own instances, so once its earlier instance has been
## cleared (and thus removed from active_encounters), the plain occupancy
## check alone would hand a refill back the exact tile a site was just
## cleared from — visually indistinguishable from "reopening" it, which
## design.md's approved rules explicitly forbid. Reusing
## _used_encounter_template_ids (rather than tracking completed instances'
## positions separately) is sufficient because each template's documented
## position is unique to it.
##
## The scan itself walks the grid far-corner-first (descending y, then
## descending x) rather than row-major from the settlement corner. The Goblin
## Camp and Orc Outpost's own documented tiles — (4, 4) and (4, 0) — already
## sit in that far region, so scanning outward from there keeps fallback
## refills requiring meaningful travel instead of landing 1-2 tiles from
## STARTING_SETTLEMENT_WORLD_POSITION, now at the map's center, which a
## settlement-first scan would otherwise hand out on literally every refill
## (both of those two sites are marked previously-spawned from turn one, per
## reset()). The Ruined Fortress's own documented position, (0, 4), is a
## different corner this far-corner-first reasoning does not cover — but it
## does not need to:
## the Ruined Fortress is never a starting site, so it is NOT marked
## previously-spawned at reset() time, and its own first-ever spawn (always a
## refill) takes the "documented position, not yet occupied, not yet used"
## fast path near the top of this function rather than reaching this scan at
## all. This scan applies to the Ruined Fortress exactly as described above
## once it has been used once (i.e. on its second and later refills). The
## scan also explicitly skips the current template's own documented_position:
## left in, the far-corner-first order would otherwise re-select that exact
## tile whenever it happens to be free (most notably Goblin Camp's, which
## *is* the far corner scanned first), reopening the same "respawns on the
## tile it was just cleared from" problem the template_previously_spawned
## guard above exists to prevent.
func _choose_encounter_position(template_id: String) -> Vector2i:
	var documented_position: Vector2i = EXPEDITIONS[template_id].position
	var template_previously_spawned := _used_encounter_template_ids.has(template_id)
	if not _is_position_occupied(documented_position) and not template_previously_spawned:
		return documented_position
	for y in range(WORLD_GRID_HEIGHT - 1, -1, -1):
		for x in range(WORLD_GRID_WIDTH - 1, -1, -1):
			var candidate := Vector2i(x, y)
			if candidate == documented_position:
				continue
			if candidate != STARTING_SETTLEMENT_WORLD_POSITION and not _is_position_occupied(candidate):
				return candidate
	return documented_position


func _is_position_occupied(position: Vector2i) -> bool:
	for instance in active_encounters:
		if instance.position == position:
			return true
	return false


## Mints an "encounter_NNN" id that collides with neither a currently-active
## instance nor a historically-completed one (completed_encounters), so a
## cleared site's old id is never reused by an unrelated later spawn.
func _mint_encounter_instance_id() -> String:
	var instance_number := 1
	var instance_id := "encounter_%03d" % instance_number
	while _get_active_encounter_index(instance_id) != -1 or completed_encounters.has(instance_id):
		instance_number += 1
		instance_id = "encounter_%03d" % instance_number
	return instance_id


## Mirrors _start_encounter_vacancy()/_advance_encounter_vacancies() for the
## recruitment category (see their docstrings for the capacity-guard split).
func _start_recruitment_vacancy() -> void:
	if recruitment_candidates.size() >= get_recruitment_offer_cap():
		return
	var turns_remaining := _resolve_vacancy_delay(RECRUITMENT_VACANCY_TURNS, RECRUITMENT_VACANCY_JITTER_TURNS)
	recruitment_vacancies.append({"turns_remaining": turns_remaining})


## A fired clock always mints a new offer (see _spawn_next_recruitment_offer()),
## even when the pool is already at get_recruitment_offer_cap() -- the oldest
## offer (index 0, the FIFO head) is evicted first to make room, rather than
## discarding the refill (see docs/plans/2026-08-18-core-loop-and-engagement/
## 03-encampment-buildings-and-tier-model.md's overflow policy). Either way
## the clock itself is consumed, not rescheduled.
func _advance_recruitment_vacancies() -> void:
	var still_pending: Array[Dictionary] = []
	for vacancy in recruitment_vacancies:
		vacancy.turns_remaining -= 1
		if vacancy.turns_remaining > 0:
			still_pending.append(vacancy)
			continue
		if recruitment_candidates.size() >= get_recruitment_offer_cap():
			recruitment_candidates.remove_at(0)
		recruitment_candidates.append(_spawn_next_recruitment_offer())
	recruitment_vacancies = still_pending


## Selects a Warrior or Scout through recruitment_class_roll, then claims the
## first unclaimed matching template. Once that class's templates are claimed
## (a fresh campaign seeds all four), mints a matching-class overflow
## candidate with a generated id and no template_id, so refills stay
## class-diverse rather than silently becoming Warrior-only.
func _spawn_next_recruitment_offer() -> Dictionary:
	# cleric_offer_roll is only ever consulted once the Temple is built, so a
	# Cleric candidate is structurally impossible before temple_level >= 1 --
	# see that Callable's own doc comment.
	var class_id: String = "cleric" if (temple_level >= 1 and cleric_offer_roll.call()) else recruitment_class_roll.call()
	for template in RECRUITMENT_CANDIDATE_TEMPLATES:
		if template["class"] == class_id and not _is_recruitment_template_claimed(template.id):
			return _make_recruitment_offer(template)

	var offer := _make_overflow_recruitment_offer(class_id)
	offer["cost"] = 10
	return offer


## The RECRUITMENT_CANDIDATE_TEMPLATES pool has no Cleric entries (it is the
## decided 3-warrior + 1-scout starting composition -- see that const's own
## doc comment), so a Cleric refill always mints an overflow candidate here.
func _make_overflow_recruitment_offer(class_id: String) -> Dictionary:
	if class_id == "cleric":
		return get_default_cleric(_new_instance_id(), _next_cosmetic_adventurer_name("cleric"))
	if class_id == "scout":
		return get_default_scout(_new_instance_id(), _next_cosmetic_adventurer_name("scout"))
	return get_default_warrior(_new_instance_id(), _next_cosmetic_adventurer_name("warrior"))


## Builds one live offer record from a fixed-pool template: a fresh record
## with a generated id plus the template_id it claims (a candidate's
## identity is no longer the template's identity), a cosmetic per-class
## counter name, and the class baseline stats/progression.
func _make_recruitment_offer(template: Dictionary) -> Dictionary:
	var offer := template.duplicate(true)
	offer["id"] = _new_instance_id()
	offer["template_id"] = template.id
	offer["name"] = _next_cosmetic_adventurer_name(str(template["class"]))
	return _seed_adventurer_baseline_stats(offer)


## Divides amount evenly across party_id's members and adds each member's
## share to their stored (float) xp, applying as many level-ups as the new
## total crosses (see get_level_xp_threshold()). Silently ignores an unknown
## or memberless party. Returns the ids of members who gained at least one
## level from this award.
func award_party_xp(party_id: String, amount: float) -> Array[String]:
	var leveled_up: Array[String] = []
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return leveled_up

	var member_ids: Array = parties[party_index].member_ids
	if member_ids.is_empty():
		return leveled_up

	var share := amount / member_ids.size()
	for member_id in member_ids:
		if _award_adventurer_xp(member_id, share):
			leveled_up.append(member_id)
	return leveled_up


func _award_adventurer_xp(adventurer_id: String, amount: float) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = adventurers[adventurer_index]
	adventurer.progression.xp += amount

	var leveled_up := false
	while adventurer.progression.xp >= get_level_xp_threshold(adventurer.level + 1):
		var old_max_health: int = adventurer.stats.max_health
		adventurer.level += 1
		var class_id: String = adventurer.get("class", "warrior")
		var class_def: Dictionary = CLASS_DEFINITIONS.get(class_id, CLASS_DEFINITIONS.warrior)
		var vitality: int = int(adventurer.stats.get("vitality", class_def.base_stats.get("vitality", 10)))
		adventurer.stats.max_health = vitality * adventurer.level
		var health_delta: int = adventurer.stats.max_health - old_max_health
		var current_hp: int = int(adventurer.get("health", old_max_health))
		adventurer["health"] = clampi(current_hp + health_delta, 1, adventurer.stats.max_health)
		var skills: Dictionary = class_def.get("skills", {})
		for skill_name in skills:
			var skill_info: Dictionary = skills[skill_name]
			var min_gain: int = int(skill_info.get("min_gain", 1))
			var max_gain: int = int(skill_info.get("max_gain", 2))
			var gain: int = skill_gain_roll.call(min_gain, max_gain)
			var current_val: int = int(adventurer.stats.get(skill_name, 0))
			adventurer.stats[skill_name] = current_val + gain
		leveled_up = true
	return leveled_up


## The single source of truth for cumulative XP thresholds: level 1 costs 0,
## level 2 costs 20, level 3 costs 50, level 4 costs 90 — each level costing
## 10 XP more than the previous step. Equivalent to 5*level*(level+1) - 10.
func get_level_xp_threshold(level: int) -> float:
	return float(5 * level * (level + 1) - 10)


## True once an adventurer has reached a level divisible by PERK_LEVEL_INTERVAL
## for which no perk has been chosen yet. choose_perk() is the only way to
## resolve a pending choice.
func is_perk_choice_pending(adventurer_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	return _pending_perk_slot_count(adventurers[adventurer_index]) > 0


func _pending_perk_slot_count(adventurer: Dictionary) -> int:
	var earned_slots: int = adventurer.level / PERK_LEVEL_INTERVAL
	return earned_slots - adventurer.progression.perks.size()


## Only accepts BONUS_MOVE_PERK_ID, only while is_perk_choice_pending() is
## true for adventurer_id, and only once per adventurer (a perk already in
## progression.perks cannot be re-chosen).
func choose_perk(adventurer_id: String, perk_id: String) -> bool:
	if perk_id != BONUS_MOVE_PERK_ID:
		return false

	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = adventurers[adventurer_index]
	if adventurer.progression.perks.has(perk_id):
		return false
	if _pending_perk_slot_count(adventurer) <= 0:
		return false

	adventurer.progression.perks.append(perk_id)
	return true


## Centralized effective-hit-chance formula: min(raw skill / 100.0, 0.95).
## Skill used depends on weapon category: "bow" -> missile, others -> melee.
## Returns 0.0 for an unknown adventurer.
func get_effective_hit_chance(adventurer_id: String) -> float:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0.0
	var weapon_id := str(adventurer.equipment.weapon)
	var weapon: Dictionary = get_item_definition(weapon_id)
	var category := str(weapon.get("category", ""))
	var raw_stat: float = 0.0
	if category == "bow":
		raw_stat = float(adventurer.stats.get("missile", adventurer.stats.get("attack", 60)))
	else:
		raw_stat = float(adventurer.stats.get("melee", adventurer.stats.get("attack", 60)))
	return minf(raw_stat / ATTACK_TO_HIT_CHANCE_DIVISOR, EFFECTIVE_HIT_CHANCE_CAP)


## Centralized effective max health: the adventurer's stored max_health,
## which leveling already keeps current. Returns 0 for an unknown adventurer.
func get_effective_max_health(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return adventurer.stats.max_health


## Returns current persistent health for adventurer_id (clamped in [1, max_health]),
## or 0 for an unknown adventurer.
func get_current_health(adventurer_id: String) -> int:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return 0
	var adventurer: Dictionary = adventurers[adventurer_index]
	var max_hp := get_effective_max_health(adventurer_id)
	return clampi(int(adventurer.get("health", max_hp)), 1, max_hp)


## Sets persistent health for adventurer_id, clamped to [1, max_health].
## Returns false for an unknown adventurer.
func set_adventurer_health(adventurer_id: String, amount: int) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var max_hp := get_effective_max_health(adventurer_id)
	adventurers[adventurer_index]["health"] = clampi(amount, 1, max_hp)
	return true


## Unit permadeath transaction (docs/plans/2026-08-18-core-loop-and-
## engagement/02-permadeath-retreat-and-economy-floor.md): called by
## Battlefield._persist_battle_aftermath() -- before apply_battle_aftermath()
## -- with every player unit's reported end-of-battle health, keyed by
## adventurer id. Every reported id at or below 0 HP is a kill. Validation
## (which ids actually name a live adventurer) runs to completion before any
## mutation, so a batch containing an already-unknown id still resolves
## every genuine kill in it rather than aborting the whole call. For each
## confirmed kill, in order: its full carried and equipped gear (ordinary
## stackable items and unique modified instances alike) moves atomically
## into the party's own pending_gear store (see _transfer_dead_unit_gear_
## to_pending()), its id is erased from every party's member_ids, and the
## adventurer record itself is deleted from the roster -- so a dead id can
## never remain in live session state afterward. A later successful retreat
## or victory banks that gear through the existing settlement transition
## (deposit_pending_reward()); a wipe forfeits it instead
## (resolve_party_wipe()). owned_item_instances records are never deleted
## here -- only resolve_party_wipe() ever discards a recovered instance
## record, never a successful recovery. Returns the ids actually removed.
func resolve_battle_deaths(health_by_id: Dictionary) -> Array[String]:
	var dead_ids: Array[String] = []
	for id_key in health_by_id:
		var adventurer_id := String(id_key)
		if int(health_by_id[id_key]) <= 0 and _has_adventurer(adventurer_id):
			dead_ids.append(adventurer_id)

	for adventurer_id in dead_ids:
		_transfer_dead_unit_gear_to_pending(adventurer_id)
		for party_index in parties.size():
			parties[party_index].member_ids.erase(adventurer_id)
		adventurers.remove_at(_get_adventurer_index(adventurer_id))
	total_casualties += dead_ids.size()
	return dead_ids


## Moves every item a slain adventurer carried -- weapons, armor, and
## potions, active or spare alike, since a unit's *_inventory array already
## lists everything it carries including its currently-active item -- into
## the party's pending_gear store, one count per item id. Whether an id
## later banks as a fungible count or a unique instance record is decided
## once, at deposit_pending_reward() time (see its own doc comment), not
## here.
func _transfer_dead_unit_gear_to_pending(adventurer_id: String) -> void:
	var adventurer := get_adventurer(adventurer_id)
	var equipment: Dictionary = adventurer.get("equipment", {})
	for slot in ["weapon", "armor", "potion"]:
		for item_id in equipment.get("%s_inventory" % slot, []):
			var id := str(item_id)
			pending_gear[id] = pending_gear.get(id, 0) + 1


## Batch write-back used by the battlefield after victory or defeat.
## For each entry, persists max(1, reported) clamped to max health.
func apply_battle_aftermath(health_by_id: Dictionary) -> void:
	for id_key in health_by_id:
		var adventurer_id := String(id_key)
		var reported := int(health_by_id[id_key])
		set_adventurer_health(adventurer_id, max(1, reported))


func _get_party_for_adventurer(adventurer_id: String) -> Dictionary:
	for party in parties:
		if adventurer_id in party.member_ids:
			return party
	return {}


func _apply_natural_recovery() -> void:
	for adventurer in adventurers:
		var adv_id := String(adventurer.id)
		var party: Dictionary = _get_party_for_adventurer(adv_id)
		var rate := HEAL_RATE_ENCAMPED
		if not party.is_empty() and bool(party.get("deployed", false)):
			if bool(party.get("movement_spent", false)):
				rate = HEAL_RATE_MOVING
			else:
				rate = HEAL_RATE_RESTING
		var current_hp := get_current_health(adv_id)
		var max_hp := get_effective_max_health(adv_id)
		if current_hp < max_hp:
			adventurers[_get_adventurer_index(adv_id)]["health"] = mini(current_hp + rate, max_hp)


## Centralized effective battle AP: every unit starts with the battle baseline,
## and Bonus Move adds one flexible AP rather than a movement-only allowance.
## Returns 0 for an unknown adventurer.
func get_effective_action_points(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var bonus := 1 if adventurer.progression.perks.has(BONUS_MOVE_PERK_ID) else 0
	return 6 + bonus


## Returns (damage_min, damage_max) from the adventurer's equipped weapon, or
## Vector2i.ZERO for an unknown adventurer or an equipped weapon id that has
## fallen out of WEAPONS (should not happen outside of hand-edited state).
func get_effective_weapon_damage_range(adventurer_id: String) -> Vector2i:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return Vector2i.ZERO
	var weapon: Dictionary = get_item_definition(adventurer.equipment.weapon)
	if weapon.is_empty():
		return Vector2i.ZERO
	return Vector2i(weapon.damage_min, weapon.damage_max)


## Ranged weapon data is optional while the catalog contains only melee
## weapons. Missing or invalid records remain safely adjacent-only.
func get_effective_weapon_attack_range(adventurer_id: String) -> Vector2i:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return Vector2i.ONE
	var weapon: Dictionary = get_item_definition(adventurer.equipment.weapon)
	if weapon.is_empty():
		return Vector2i.ONE
	var min_range: int = maxi(int(weapon.get("min_range", 1)), 1)
	var max_range: int = maxi(int(weapon.get("max_range", 1)), min_range)
	return Vector2i(min_range, max_range)


func get_effective_weapon_raw_damage_bonus(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var weapon_id := str(adventurer.equipment.weapon)
	if not owned_item_instances.has(weapon_id):
		return 0
	return 1 if owned_item_instances[weapon_id].get("treatment_id", "") == SHARPENED_TREATMENT_ID else 0


func get_effective_weapon_name(adventurer_id: String) -> String:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var weapon: Dictionary = get_item_definition(adventurer.equipment.weapon)
	return "" if weapon.is_empty() else tr(weapon.name_key)


func get_effective_armor_name(adventurer_id: String) -> String:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var armor: Dictionary = get_item_definition(adventurer.equipment.armor)
	return "" if armor.is_empty() else tr(armor.name_key)


func get_effective_defense(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = get_item_definition(adventurer.equipment.armor)
	var armor_def: int = 0 if armor.is_empty() else int(armor.defense)
	var guard_stat: int = int(adventurer.stats.get("guard", 0))
	return armor_def + guard_stat


func get_effective_might(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return int(adventurer.stats.get("might", 0))


func get_effective_resistance(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = get_item_definition(adventurer.equipment.armor)
	return 0 if armor.is_empty() else int(armor.resistance)


## Exports every durable field this session owns as a versioned, deep-copy-
## safe, JSON-safe Dictionary (see CampaignSnapshot). No disk I/O and no
## reward-banking side effects -- battle_reward/pending_reward are carried
## across exactly as they stand, never merged or deposited.
func export_campaign_snapshot() -> Dictionary:
	var snapshot := CampaignSnapshot.new()
	snapshot.adventurers = adventurers.duplicate(true)
	snapshot.recruitment_candidates = recruitment_candidates.duplicate(true)
	snapshot.recruitment_vacancies = recruitment_vacancies.duplicate(true)
	snapshot.parties = parties.duplicate(true)
	snapshot.selected_party_id = selected_party_id
	snapshot.selected_encounter = selected_encounter
	snapshot.campaign_objective_id = campaign_objective_id
	snapshot.completed_objectives = completed_objectives.duplicate(true)
	snapshot.unlocked_authored_encounters = unlocked_authored_encounters.duplicate(true)
	snapshot.is_campaign_completed = is_campaign_completed
	snapshot.is_free_play_active = is_free_play_active
	snapshot.total_casualties = total_casualties
	snapshot.completed_encounters = completed_encounters.duplicate(true)
	snapshot.active_encounters = active_encounters.duplicate(true)
	snapshot.encounter_vacancies = encounter_vacancies.duplicate(true)
	snapshot.used_encounter_template_ids = _used_encounter_template_ids.duplicate(true)
	snapshot.world_turn = world_turn
	snapshot.gold = gold
	snapshot.guild_hall_level = guild_hall_level
	snapshot.temple_level = temple_level
	snapshot.blacksmith_level = blacksmith_level
	snapshot.blacksmith_craft_job = blacksmith_craft_job.duplicate(true)
	snapshot.blacksmith_sharpening_job = blacksmith_sharpening_job.duplicate(true)
	snapshot.alchemy_workshop_level = alchemy_workshop_level
	snapshot.alchemy_craft_job = alchemy_craft_job.duplicate(true)
	snapshot.runic_workshop_level = runic_workshop_level
	snapshot.runic_craft_job = runic_craft_job.duplicate(true)
	snapshot.pending_reward = pending_reward
	snapshot.mana_crystals = mana_crystals.duplicate(true)
	snapshot.banked_gear = banked_gear.duplicate(true)
	snapshot.owned_item_instances = owned_item_instances.duplicate(true)
	snapshot.banked_item_instance_ids = banked_item_instance_ids.duplicate()
	snapshot.pending_mana_crystals = pending_mana_crystals.duplicate(true)
	snapshot.pending_gear = pending_gear.duplicate(true)
	snapshot.battle_reward = battle_reward
	snapshot.battle_mana_crystals = battle_mana_crystals.duplicate(true)
	snapshot.battle_gear = battle_gear.duplicate(true)
	snapshot.has_trading_post = has_trading_post
	snapshot.shop_level = shop_level
	snapshot.shop_gold = shop_gold
	snapshot.player_name = player_name
	snapshot.tutorial_progress = tutorial_progress.duplicate(true)
	return snapshot.to_dictionary()


## All-or-nothing import: validates and normalizes data into a separate
## Dictionary (see CampaignSnapshot.from_dictionary()) and only assigns this
## session's own fields once that normalization reports "ok": true, so a
## rejected import never partially lands. Returns the same
## { "ok", "snapshot", "error" } result CampaignSnapshot.from_dictionary()
## produced, for the caller to inspect. Never calls
## merge_battle_loot_into_party() or deposit_pending_reward() -- carried
## rewards are restored exactly as exported, never banked.
##
## Every Array/Dictionary field is duplicated (never assigned directly)
## when copied from result.snapshot onto this session's own fields, so the
## two stay independent objects in both directions: a caller mutating the
## returned result's nested "snapshot" afterward (e.g. for logging) cannot
## reach back into live session state, and this session mutating its own
## fields afterward cannot reach into the returned result.
func import_campaign_snapshot(data: Dictionary) -> Dictionary:
	var result := CampaignSnapshot.from_dictionary(data)
	if not result.ok:
		return result

	var snapshot: Dictionary = result.snapshot
	var owned_instance_error := _validate_owned_item_instance_ownership(snapshot)
	if not owned_instance_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": owned_instance_error}
	var blacksmith_error := _validate_blacksmith_state(snapshot)
	if not blacksmith_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": blacksmith_error}
	var alchemy_error := _validate_alchemy_workshop_state(snapshot)
	if not alchemy_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": alchemy_error}
	var runic_error := _validate_runic_workshop_state(snapshot)
	if not runic_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": runic_error}
	var carried_inventory_error := _validate_carried_inventory(snapshot)
	if not carried_inventory_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": carried_inventory_error}
	adventurers = snapshot.adventurers.duplicate(true)
	recruitment_candidates = snapshot.recruitment_candidates.duplicate(true)
	recruitment_vacancies = snapshot.recruitment_vacancies.duplicate(true)
	parties = snapshot.parties.duplicate(true)
	selected_party_id = snapshot.selected_party_id
	selected_encounter = snapshot.selected_encounter
	campaign_objective_id = snapshot.campaign_objective_id
	completed_objectives = snapshot.completed_objectives.duplicate(true)
	unlocked_authored_encounters = snapshot.unlocked_authored_encounters.duplicate(true)
	is_campaign_completed = snapshot.is_campaign_completed
	is_free_play_active = snapshot.is_free_play_active
	total_casualties = snapshot.total_casualties
	completed_encounters = snapshot.completed_encounters.duplicate(true)
	active_encounters = snapshot.active_encounters.duplicate(true)
	encounter_vacancies = snapshot.encounter_vacancies.duplicate(true)
	_used_encounter_template_ids = snapshot.used_encounter_template_ids.duplicate(true)
	world_turn = snapshot.world_turn
	gold = snapshot.gold
	guild_hall_level = snapshot.guild_hall_level
	temple_level = snapshot.temple_level
	blacksmith_level = snapshot.blacksmith_level
	blacksmith_craft_job = snapshot.blacksmith_craft_job.duplicate(true)
	blacksmith_sharpening_job = snapshot.blacksmith_sharpening_job.duplicate(true)
	alchemy_workshop_level = snapshot.alchemy_workshop_level
	alchemy_craft_job = snapshot.alchemy_craft_job.duplicate(true)
	runic_workshop_level = snapshot.runic_workshop_level
	runic_craft_job = snapshot.runic_craft_job.duplicate(true)
	pending_reward = snapshot.pending_reward
	mana_crystals = snapshot.mana_crystals.duplicate(true)
	banked_gear = snapshot.banked_gear.duplicate(true)
	owned_item_instances = snapshot.owned_item_instances.duplicate(true)
	banked_item_instance_ids.assign(snapshot.banked_item_instance_ids)
	pending_mana_crystals = snapshot.pending_mana_crystals.duplicate(true)
	pending_gear = snapshot.pending_gear.duplicate(true)
	battle_reward = snapshot.battle_reward
	battle_mana_crystals = snapshot.battle_mana_crystals.duplicate(true)
	battle_gear = snapshot.battle_gear.duplicate(true)
	has_trading_post = snapshot.has_trading_post
	shop_level = snapshot.shop_level
	shop_gold = snapshot.shop_gold
	player_name = snapshot.player_name
	tutorial_progress = snapshot.tutorial_progress.duplicate(true)
	return result


func _validate_blacksmith_state(snapshot: Dictionary) -> String:
	var level: int = snapshot.blacksmith_level
	if level < 0 or level > BLACKSMITH_MAX_LEVEL:
		return "blacksmith level is out of range"
	for job_key in ["blacksmith_craft_job", "blacksmith_sharpening_job"]:
		var job: Dictionary = snapshot[job_key]
		if job.is_empty():
			continue
		if level == 0:
			return "unbuilt blacksmith has a job"
		if not job.get("item_id") is String or not job.get("completion_turn") is int:
			return "blacksmith job has invalid fields"
		var item_id := str(job.item_id)
		if not WEAPONS.has(item_id) or int(job.completion_turn) < int(snapshot.world_turn):
			return "blacksmith job is invalid"
		if job_key == "blacksmith_craft_job" and level < _blacksmith_required_level_for_weapon(item_id):
			return "blacksmith level cannot craft this weapon"
	return ""


func _validate_alchemy_workshop_state(snapshot: Dictionary) -> String:
	var level: int = snapshot.alchemy_workshop_level
	if level < 0 or level > ALCHEMY_WORKSHOP_MAX_LEVEL:
		return "alchemy workshop level is out of range"
	var job: Dictionary = snapshot.alchemy_craft_job
	if job.is_empty():
		return ""
	if level == 0:
		return "unbuilt alchemy workshop has a job"
	if not job.get("item_id") is String or not job.get("completion_turn") is int:
		return "alchemy workshop job has invalid fields"
	var item_id := str(job.item_id)
	if not POTIONS.has(item_id) or int(job.completion_turn) < int(snapshot.world_turn):
		return "alchemy workshop job is invalid"
	if level < int(POTIONS[item_id].required_level):
		return "alchemy workshop level cannot craft this potion"
	return ""


func _validate_runic_workshop_state(snapshot: Dictionary) -> String:
	var level: int = snapshot.runic_workshop_level
	if level < 0 or level > RUNIC_WORKSHOP_MAX_LEVEL:
		return "runic workshop level is out of range"
	var job: Dictionary = snapshot.runic_craft_job
	if job.is_empty():
		return ""
	if level == 0:
		return "unbuilt runic workshop has a job"
	if not job.get("target_instance_id") is String or not job.get("rune_id") is String or not job.get("completion_turn") is int:
		return "runic workshop job has invalid fields"
	var target_instance_id := str(job.target_instance_id)
	var owned_instances: Dictionary = snapshot.owned_item_instances
	if target_instance_id.is_empty() or not owned_instances.has(target_instance_id) or str(job.rune_id) != THORN_RUNE_ID or int(job.completion_turn) < int(snapshot.world_turn):
		return "runic workshop job is invalid"
	var target_instance: Dictionary = owned_instances[target_instance_id]
	var base_item_id := str(target_instance.get("base_item_id", ""))
	if not ARMORS.has(base_item_id):
		return "runic workshop job target is not armor"
	return ""


func _validate_carried_inventory(snapshot: Dictionary) -> String:
	for adventurer in snapshot.adventurers:
		var equipment = adventurer.get("equipment", {})
		if not equipment is Dictionary:
			continue
		var carried_count := 0
		for slot in ["weapon", "armor", "potion"]:
			var inventory = equipment.get("%s_inventory" % slot, [])
			if not inventory is Array:
				return "carried item inventory is invalid"
			for raw_item_id in inventory:
				var item := _get_snapshot_item_definition(snapshot, str(raw_item_id))
				if item.is_empty() or str(item.slot) != slot:
					return "carried item inventory has an incompatible item"
				if slot == "weapon":
					var class_definition: Dictionary = CLASS_DEFINITIONS.get(str(adventurer.get("class", "")), {})
					if not class_definition.get("allowed_weapon_categories", []).has(str(item.get("category", ""))):
						return "carried item inventory has a class incompatible weapon"
				carried_count += 1
		if carried_count > CARRIED_ITEM_CAPACITY:
			return "carried item capacity is exceeded"
	return ""


## Resolves an imported inventory id against the candidate snapshot rather
## than the live session, so an owned instance's base item is validated before
## import mutates any durable state.
func _get_snapshot_item_definition(snapshot: Dictionary, item_id: String) -> Dictionary:
	var owned_instances = snapshot.get("owned_item_instances", {})
	if owned_instances is Dictionary and owned_instances.has(item_id):
		var instance = owned_instances[item_id]
		if not instance is Dictionary:
			return {}
		var base_item_id := str(instance.get("base_item_id", ""))
		return WEAPONS.get(base_item_id, ARMORS.get(base_item_id, POTIONS.get(base_item_id, {})))
	return WEAPONS.get(item_id, ARMORS.get(item_id, POTIONS.get(item_id, {})))


## Owned instances have exactly one location: Stores or one matching-slot
## adventurer inventory.  Validate the complete imported graph before
## assigning any field, preserving import_campaign_snapshot()'s all-or-
## nothing promise for malformed or hand-edited save data.
func _validate_owned_item_instance_ownership(snapshot: Dictionary) -> String:
	var locations: Dictionary = {}
	for raw_id in snapshot.owned_item_instances:
		var instance_id := str(raw_id)
		var instance = snapshot.owned_item_instances[raw_id]
		if not instance is Dictionary or instance.get("id") != instance_id:
			return "owned item instance has an invalid id"
		for field_name in ["base_item_id", "treatment_id", "enhancement_id", "rune_id"]:
			if not instance.get(field_name) is String:
				return "owned item instance has an invalid %s" % field_name
		if not instance.get("modifier_tiers") is Dictionary:
			return "owned item instance has invalid modifier tiers"
		for category in instance.modifier_tiers:
			if category not in ["treatment", "enhancement", "rune"]:
				return "owned item instance has an unknown modifier category"
			if not instance.modifier_tiers[category] is int or int(instance.modifier_tiers[category]) <= 0:
				return "owned item instance has an invalid modifier tier"
		var field_by_category := {
			"treatment": "treatment_id",
			"enhancement": "enhancement_id",
			"rune": "rune_id",
		}
		for category in field_by_category:
			var has_modifier := not str(instance[field_by_category[category]]).is_empty()
			var has_tier: bool = instance.modifier_tiers.has(category)
			if has_modifier != has_tier:
				return "owned item instance modifier and tier do not match"
		var base_item_id := str(instance.get("base_item_id", ""))
		if not WEAPONS.has(base_item_id) and not ARMORS.has(base_item_id):
			return "owned item instance has an unknown base item"
		locations[instance_id] = 0

	for raw_id in snapshot.banked_item_instance_ids:
		var instance_id := str(raw_id)
		if not locations.has(instance_id):
			return "banked owned item instance is unknown"
		locations[instance_id] += 1

	for adventurer in snapshot.adventurers:
		var equipment = adventurer.get("equipment", {})
		if not equipment is Dictionary:
			continue
		for slot in ["weapon", "armor"]:
			var inventory = equipment.get("%s_inventory" % slot, [])
			if not inventory is Array:
				continue
			var active_item_id := str(equipment.get(slot, ""))
			if locations.has(active_item_id) and not inventory.has(active_item_id):
				return "active owned item instance is missing from its inventory"
			for raw_id in inventory:
				var instance_id := str(raw_id)
				if not locations.has(instance_id):
					continue
				var base_item_id := str(snapshot.owned_item_instances[instance_id].base_item_id)
				var item_slot: String = str(get_item_definition(base_item_id).slot)
				if item_slot != slot:
					return "owned item instance is in an incompatible inventory"
				locations[instance_id] += 1

	for instance_id in locations:
		if locations[instance_id] != 1:
			return "owned item instance must have exactly one location"
	return ""


## Derived, one-shot guide-state query for the first campaign's opening
## reward-to-improvement loop (see docs/plans/2026-08-10-initial-campaign-
## and-automation/04-first-campaign-guidance.md): form a party, deploy it,
## select/commit a route, enter the first site, return home to bank the
## reward, then choose the first affordable improvement. Scans
## CAMPAIGN_GUIDE_SEQUENCE and returns whichever id's contextual trigger
## currently holds and has not already been dismissed via
## record_campaign_guide_dismissal() or retired via
## record_campaign_guide_progress(); "" means nothing is due right now.
##
## A pure read, like every other get_/has_/can_ method in this file --
## calling it never writes tutorial_progress or anything else. When several
## ids are simultaneously triggered, the *latest* one in the sequence wins
## rather than the first (see _compute_campaign_guide_active_id()), but that
## alone only decides what to show *this call*; making a message that was
## actually shown stay retired across later calls is
## record_campaign_guide_progress()'s job, not this one's -- see that
## method's doc for why the split matters.
func get_campaign_guide_state() -> String:
	return _compute_campaign_guide_active_id()


## Pure priority scan: the CAMPAIGN_GUIDE_SEQUENCE entries are visited in
## order, so simply overwriting active_id on every still-triggered, not-yet-
## retired hit naturally leaves the *last* (highest-priority) one standing --
## no index bookkeeping needed to pick "latest wins" over "first wins".
func _compute_campaign_guide_active_id() -> String:
	var active_id := ""
	for guide_id in CAMPAIGN_GUIDE_SEQUENCE:
		if not tutorial_progress.get(guide_id, false) and _is_campaign_guide_triggered(guide_id):
			active_id = guide_id
	return active_id


func _is_campaign_guide_triggered(guide_id: String) -> bool:
	match guide_id:
		CAMPAIGN_GUIDE_FORM_PARTY:
			return parties.is_empty()
		CAMPAIGN_GUIDE_DEPLOY:
			return not parties.is_empty() and not has_deployed_party()
		CAMPAIGN_GUIDE_SELECT_ROUTE:
			return (
				has_deployed_party() and selected_encounter == ""
				and get_deployed_party_route().is_empty()
				and not _campaign_guide_party_on_active_encounter()
			)
		CAMPAIGN_GUIDE_ENTER_SITE:
			return (
				has_deployed_party() and selected_encounter == ""
				and _campaign_guide_party_on_active_encounter()
			)
		CAMPAIGN_GUIDE_RETURN_BANK:
			return has_deployed_party() and selected_encounter == "" and pending_reward > 0
		CAMPAIGN_GUIDE_FIRST_IMPROVEMENT:
			return (
				not has_deployed_party() and gold > 0
				and not _campaign_guide_first_improvement_made()
				and _campaign_guide_has_affordable_improvement()
			)
	return false


## True once the deployed party is standing on a tile that still names a
## live, uncleared active-encounter instance -- mirrors world_map.gd's own
## _expedition_id_at() lookup against GameSession.get_active_encounters().
func _campaign_guide_party_on_active_encounter() -> bool:
	var position := get_deployed_party_position()
	for record in get_active_encounters():
		if record.position == position:
			return true
	return false


## Monotonic proxy for "the player has already made at least one of the
## three improvements the manual verification flow names (recruit,
## equipment, Guild Hall)". Equipment purchases (buy_item()) require
## has_trading_post already being true, so that flag alone also covers the
## equipment case without needing to inspect banked_gear, which loot pickups
## populate too and would otherwise be a false positive. The recruit case
## compares against the four-warrior starting roster (see
## STARTING_ROSTER_SIZE): a roster of exactly that size is still the
## un-improved opening state.
func _campaign_guide_first_improvement_made() -> bool:
	return guild_hall_level > 1 or shop_level > 1 or adventurers.size() > STARTING_ROSTER_SIZE


func _campaign_guide_has_affordable_improvement() -> bool:
	if can_upgrade_guild_hall() or can_upgrade_shop():
		return true
	for candidate in recruitment_candidates:
		if gold >= int(candidate.get("cost", 0)):
			return true
	return false


## Explicit player action from the guide banner's Dismiss button (see
## scripts/ui/campaign_guide.gd) -- durably retires guide_id so
## get_campaign_guide_state() never returns it again this campaign,
## independent of whether its trigger condition is still true.
func record_campaign_guide_dismissal(guide_id: String) -> void:
	tutorial_progress[guide_id] = true


## Explicit write called by the guide banner (scripts/ui/campaign_guide.gd's
## refresh()) whenever it actually renders guide_id on screen -- never by
## get_campaign_guide_state() itself, which stays a pure read like every
## other get_ method here. Durably retires every id *earlier* than guide_id
## in CAMPAIGN_GUIDE_SEQUENCE (guide_id itself is left alone -- only
## record_campaign_guide_dismissal() retires the currently-active message).
##
## This is required, not decorative: the deployed party un-deploys again on
## every walk home (see return_deployed_party_to_settlement()), and the
## route/arrival triggers re-arm on every later expedition, so once the
## player has visibly moved on to a later stage, the earlier ones' live
## trigger conditions can and do become true again on their own. Tying
## retirement to an explicit call the UI makes only when it actually
## displayed guide_id -- rather than to a side effect buried in the query --
## means a message can only ever be retired because the player really saw
## something past it, never because some unrelated caller merely asked
## what the current state is.
func record_campaign_guide_progress(guide_id: String) -> void:
	var reached_index := CAMPAIGN_GUIDE_SEQUENCE.find(guide_id)
	if reached_index <= 0:
		return
	for index in reached_index:
		tutorial_progress[CAMPAIGN_GUIDE_SEQUENCE[index]] = true
