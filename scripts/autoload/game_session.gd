extends Node

## Stage 6 Step 3 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/03-authored-content-catalog.md): the authored-content loader
## get_expedition() overlays onto EXPEDITIONS for any encounter id that has
## migrated into config/content/ -- see _overlay_content_catalog_definition().
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")
## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/04-branching-perk-definitions.md): the DAG-shaped
## PerkDefinition catalog -- see CLASS_PERKS/SPECIALIZATION_PERKS/PERK_
## DEFINITIONS below, all three now generated from this single source rather
## than hand-duplicated, and get_available_perks()/choose_perk(), which
## additionally consult it for prerequisite/mutual-exclusion legality (only
## Knight's Shield Bash/Chain Blow carry a real DAG relationship -- every
## other class's perks have empty prerequisite_ids/mutually_exclusive_with,
## so this is a behavior-preserving migration for them).
const PerkCatalogScript := preload("res://scripts/progression/perk_catalog.gd")
const PerkEffectResolverScript := preload("res://scripts/battle/perk_effect_resolver.gd")

## Stage 6 Step 5 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/05-domain-extraction-and-stage-6-exit.md): GameSession is
## consolidated as a lean facade over these three extracted domain services.
## Every service holds NO state of its own -- each operates directly on this
## file's own durable dictionaries (parties, adventurers, active_encounters,
## _battle_context, etc.) via the `_gs` reference it is constructed with, so
## there is exactly one copy of every field, never a second one that could
## desync. Every function moved into a service keeps a one-line forwarding
## method here under its original name, so every pre-existing internal
## self-call and every external `GameSession.foo(...)` call site (UI, World
## Map, battle, tools, tests) keeps working completely unchanged -- only what
## runs behind each name moved.
const PartyServiceScript := preload("res://scripts/campaign/party_service.gd")
const EncounterServiceScript := preload("res://scripts/campaign/encounter_service.gd")
const ProgressionServiceScript := preload("res://scripts/progression/progression_service.gd")
var party_service: PartyServiceScript
var encounter_service: EncounterServiceScript
var progression_service: ProgressionServiceScript

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
## Emitted whenever a journal entry is appended or its read status changes,
## so navigation badges and views can refresh reactively.
signal journal_updated

const JOURNAL_SECTION_LOG := "log"
const JOURNAL_SECTION_QUESTS := "quests"
const JOURNAL_SECTIONS: Array[String] = [
	JOURNAL_SECTION_LOG,
	JOURNAL_SECTION_QUESTS,
]

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
		# Stage 5 D3's counter enemy: this one Orc carries a nonzero
		# magic_resistance as immutable per-encounter factory data -- NOT a
		# new monster family, exactly analogous to Step 3's Cover tiles on
		# `goblin_camp` above (_cover_tiles_for_encounter() in
		# battle_controller.gd) -- only THIS encounter's Orc carries the
		# override; every other Orc (including obj_tier2_*'s ORC_BRUISER_
		# ENEMY_STATS) is unaffected. 50, paired with Mage's own base
		# spellcasting (20, see CLASS_DEFINITIONS.mage's own doc comment),
		# yields a 30% Sleep-resist chance -- both a successful and a
		# resisted cast are reachable across a handful of casts, per D3's
		# "demonstrate both outcomes" requirement.
		"enemy": {
			"name_key": "battle.enemy.orc",
			"attack_name_key": "battle.enemy.orc.attack",
			"max_health": 22,
			"attack_damage": 3,
			"hit_chance": 0.5,
			"count": 1,
			"magic_resistance": 50,
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
# The four original species below (Goblin/Orc/Kobold/Hobgoblin) are Step 5's
# ("shared tactical profile migration") locked "Initial roster" (see
# docs/designs/monster-manual.md's "Initial roster — preserve shipped
# values" section, which is the sole source for every number in these four
# consts -- never re-derive or invent one here). They author the explicit
# melee/missile/might/guard/resistance/spellcasting/magic_resistance/
# action_points profile vocabulary directly, plus damage_min/damage_max in
# place of the old flat attack_damage -- see get_enemy_profile_hit_chance()/
# get_enemy_profile_guard() just below, which read melee/missile/guard (or
# fall back to legacy hit_chance/defense for every other, still-legacy enemy
# template in this file, e.g. GOBLIN_ARCHER_ENEMY_STATS just below). melee
# 25/30/50/60 reproduce the pre-migration hit_chance 0.25/0.3/0.5/0.6 exactly
# (melee / ATTACK_TO_HIT_CHANCE_DIVISOR), and damage_min == damage_max
# reproduces the old fixed attack_damage exactly -- see this step's own
# baseline-fixture regression coverage (test_deterministic_level_two_
# warrior_baseline_matches_monster_manual_table() and the *_enemy_stats_are_
# the_*_tier tests in test_game_session.gd, and test_battle_state_factory.gd/
# test_battle_controller.gd's own enemy-hydration tests) for the numbers
# this must never silently drift from.
const GOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.goblin",
	"attack_name_key": "battle.enemy.goblin.attack",
	"max_health": 13,
	"damage_min": 2,
	"damage_max": 2,
	"melee": 30,
	"missile": 0,
	"might": 0,
	"guard": 0,
	"resistance": 0,
	"spellcasting": 0,
	"magic_resistance": 0,
	"action_points": 6,
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
	"damage_min": 3,
	"damage_max": 3,
	"melee": 50,
	"missile": 0,
	"might": 0,
	"guard": 0,
	"resistance": 0,
	"spellcasting": 0,
	"magic_resistance": 0,
	"action_points": 6,
	"kill_xp": 10,
	"loot_id": "orc",
}
const KOBOLD_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.kobold",
	"attack_name_key": "battle.enemy.kobold.attack",
	"max_health": 6,
	"damage_min": 1,
	"damage_max": 1,
	"melee": 25,
	"missile": 0,
	"might": 0,
	"guard": 0,
	"resistance": 0,
	"spellcasting": 0,
	"magic_resistance": 0,
	"action_points": 6,
	"kill_xp": 3,
	"loot_id": "kobold",
}
const HOBGOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.hobgoblin",
	"attack_name_key": "battle.enemy.hobgoblin.attack",
	"max_health": 30,
	"damage_min": 4,
	"damage_max": 4,
	"melee": 60,
	"missile": 0,
	"might": 0,
	"guard": 0,
	"resistance": 0,
	"spellcasting": 0,
	"magic_resistance": 0,
	"action_points": 6,
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
	# WEAPONS.mace_iron). "spellcasting" is a base_stats key read by
	# get_effective_spellcasting() (the Cleric's own shared tactical
	# attribute, see class-system.md's "Shared tactical attributes" section),
	# unit_details.gd's Skills row, and unit_info_panel.gd's Skills row -- it
	# exists on no other class, and every reader treats a missing
	# spellcasting stat as 0 rather than requiring every class to carry a
	# dead field. "missile" stays in base_stats for schema parity with
	# warrior/scout (get_effective_hit_chance() falls back to it for a
	# bow-category weapon, which a Cleric can never equip) but is
	# deliberately absent from "skills" below -- it never needs to grow.
	# mp_max (this class's only spellcasting resource) is hydrated onto the
	# battle-local Unit by BattleController AND is now a persistent
	# adventurer stat via the durable "mp_current" field (see docs/designs/
	# campaign-loop.md's "Cleric current MP is durable adventurer state"
	# paragraph, get_default_cleric(), and get_current_mp()/set_adventurer_
	# mp()) -- Step 3's whole point. The flat mp_max value itself is config-
	# driven (GameConfig's cleric.mp_max, see CLERIC_MP_MAX and get_
	# effective_max_mp()), not this compile-time 3; this const stays as the
	# default baseline other call sites (BattleController._ready(),
	# campaign_snapshot.gd, scenario_contract.gd, battle_state_factory.gd)
	# read directly for battle-local Unit.mp_max hydration.
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
	# Mage (Stage 5 D3, docs/plans/2026-08-23-stage-5-strategic-roster-
	# expansion/decision-ledger.md): control/offense role, the weakest melee
	# stats and durability in the game, real spellcasting. Reuses Cleric's
	# already-declared "staff" weapon category (see WEAPONS.mace_iron's own
	# doc comment: mace/hammer/staff were pre-declared as distinct categories
	# with no distinct damage tier of their own yet) rather than inventing a
	# new weapon -- a fresh Mage equips the same mace_iron item Cleric does,
	# just eligible additionally through "staff". primary_attribute_ranges/
	# class_multiplier/spells are exactly D3's approved values; skills is the
	# class-system.md "skills-by-class table" mage row read literally --
	# might/melee/guard are n/a (omitted entirely, never grow -- see
	# battle_state_factory.gd's _build_player_unit(), which now defaults an
	# absent skill's per-level gain to 0, not 1) while missile (low) and
	# spellcasting (med) are the only two that do. base_stats.spellcasting
	# (20) and the counter Orc's magic_resistance (see EXPEDITIONS.orc_
	# outpost) are a paired judgment call absent from D3's own table: chosen
	# together so `(magic_resistance - spellcasting) / 100` lands at a
	# demonstrable, non-extreme resist chance (30%) rather than either
	# extreme -- see this step's own report for the reasoning. mp_max (this
	# class's only spellcasting resource) is hydrated onto the battle-local
	# Unit by BattleController/BattleStateFactory exactly like Cleric's, and
	# is a persistent adventurer stat via "mp_current" (see get_default_
	# mage()/get_current_mp()/set_adventurer_mp()). The flat mp_max value here
	# is config-driven (GameConfig's mage.mp_max, see MAGE_MP_MAX and get_
	# effective_max_mp()) -- its own var, never CLERIC_MP_MAX -- but this
	# compile-time 3 stays the default baseline other call sites
	# (BattleController._ready(), battle_state_factory.gd) read directly.
	"mage": {
		"allowed_weapon_categories": ["mace", "staff"],
		"base_stats": {
			"max_health": 8, "vitality": 8, "melee": 15, "missile": 25, "guard": 0, "might": 0,
			"spellcasting": 20, "move_range": 3,
		},
		"primary_attribute_ranges": {"strength": Vector2i(1, 3), "agility": Vector2i(3, 5), "vitality": Vector2i(3, 5), "intelligence": Vector2i(6, 8), "piety": Vector2i(1, 4), "luck": Vector2i(1, 10)},
		"class_multiplier": 0.5,
		"skills": {
			"missile": {"tier": "low", "min_gain": 1, "max_gain": 2},
			"spellcasting": {"tier": "med", "min_gain": 3, "max_gain": 4},
		},
		"mp_max": 3,
		"spells": ["sleep"],
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
var PERK_LEVEL_INTERVAL: int = 2
## Caps how many pending perk slots _pending_perk_slot_count() will ever
## report earned for one adventurer (see docs/designs/class-system.md's
## "Stage 2 locked perk set"). Each class has exactly two perks today, so a
## third earned level-interval never opens a third slot -- is_perk_choice_
## pending() simply stays false forever past this point, with no "no perks
## available" empty state required anywhere in the UI. A future slice that
## ships a third class perk raises this alongside CLASS_PERKS.
var PERK_TREE_SIZE: int = 2
const BONUS_MOVE_PERK_ID := "bonus_move"
# Stage 2 locked class-owned perk ids (docs/designs/class-system.md's "Stage
# 2 locked perk set", approved 2026-08-21). Exactly two per class, no
# prerequisites, choose-once -- see CLASS_PERKS/PERK_DEFINITIONS below for
# the catalog these ids index into, and choose_perk()/get_available_perks()
# for the only ways they are ever offered or selected. BONUS_MOVE_PERK_ID
# above is deliberately excluded from every class's list: it is retired from
# new choices (see choose_perk()'s own doc comment) but not migrated away
# from any adventurer who already holds it.
const WARRIOR_JUGGERNAUT_PERK_ID := "warrior_juggernaut"
const WARRIOR_BULWARK_PERK_ID := "warrior_bulwark"
const SCOUT_QUICKDRAW_PERK_ID := "scout_quickdraw"
const SCOUT_KEEN_EYES_PERK_ID := "scout_keen_eyes"
const CLERIC_MEDITATION_PERK_ID := "cleric_meditation"
const CLERIC_DEVOUT_PERK_ID := "cleric_devout"
## Knight (Stage 5 D4, decision-ledger.md): a Warrior specialization, not a
## new CLASS_DEFINITIONS root -- these two ids sit on the exact same perk-
## tree/PERK_TREE_SIZE mechanism CLASS_PERKS already drives, offered only
## once an adventurer has promoted (see SPECIALIZATION_PERKS/
## SPECIALIZATION_ROOT_CLASS, get_available_specializations()/promote_
## adventurer() below, and _pending_perk_slot_count()'s specialization-aware
## cap). Parry is deliberately absent -- Step 3 already shipped a universal
## flat-10% Parry for every unit; re-implementing it as a Knight-only perk
## would require inventing a new numeric upgrade the ledger explicitly
## rejected.
##
## Stage 6 Step 4 (G3, decision-ledger.md): these two are no longer
## independent -- KNIGHT_DISCIPLINE_PERK_ID below is a new shared tier-1
## prerequisite both now require, and PerkCatalog marks them mutually
## exclusive with each other (a real "offensive vs. defensive" branch,
## reusing their existing effect values verbatim -- no new numeric balance
## value is invented). See PerkCatalogScript's own doc comment.
const KNIGHT_SHIELD_BASH_PERK_ID := "knight_shield_bash"
const KNIGHT_CHAIN_BLOW_PERK_ID := "knight_chain_blow"
## The new tier-1 gate node (Stage 6 Step 4, G3): a purely structural choice
## with no mechanical effect of its own -- see PerkCatalogScript's
## "knight_discipline" entry -- that must be chosen before either Shield Bash
## or Chain Blow becomes available.
const KNIGHT_DISCIPLINE_PERK_ID := "knight_discipline"
## Archer (Stage 5 D4, decision-ledger.md): the second Warrior specialization
## -- verified against docs/designs/class-system.md's own roadmap table
## ("Warrior becomes Knight or Archer") rather than Scout, despite the
## thematic "ranged" name. Sits on the exact same perk-tree mechanism as
## Knight's two ids above; Piercing Arrow is deliberately absent (the user's
## explicit selection excluded it from this slice, see the ledger's "Archer's
## perks" row).
const ARCHER_LOCK_ON_PERK_ID := "archer_lock_on"
const ARCHER_CALLED_SHOT_PERK_ID := "archer_called_shot"
## Battle Mage (Stage 5 D4): the Mage specialization -- a single perk
## (Temporary Guard) rather than the usual two, since the class-system.md
## roadmap gives Battle Mage a perk PLUS a granted spell ("fire_bolt", see
## SPECIALIZATION_SPELLS below), not two perks. Mage's own CLASS_PERKS entry
## is deliberately absent (Mage has no Stage 2 locked perk tree at all -- see
## CLASS_PERKS' own doc comment), so Battle Mage's promotion eligibility is
## satisfied vacuously (see get_available_specializations()'s own doc comment
## on this) rather than by exhausting a root tree the way Knight/Archer's
## Warrior root does.
const BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID := "battle_mage_temporary_guard"
## Paladin (Stage 5 D4): the Cleric specialization -- deliberately owns NO
## perk id of its own at all (unlike every other specialization above), per
## the ledger's explicit "not a new perk-tree entry" instruction. Its whole
## ability is a granted, caster-identity-keyed amplification of the existing
## Bless spell (double hit-chance/damage bonus) -- see battle_controller.gd's
## PALADIN_BLESSED_STATUS_ID/PALADIN_BLESS_HIT_CHANCE_BONUS/PALADIN_BLESS_
## DAMAGE_MULTIPLIER and its try_cast_spell() "bless" match arm. Accordingly
## "paladin" is absent from SPECIALIZATION_PERKS below (SPECIALIZATION_PERKS.
## get("paladin", []) correctly returns [] by default) and from SPECIALIZATION_
## SPELLS (Bless is already a root Cleric spell -- nothing new is GRANTED,
## only amplified). Promotion eligibility additionally requires a built
## Temple (GameSession.temple_level >= 1, see get_available_specializations()'s
## own doc comment) on top of the same perk-exhaustion rule every other
## specialization uses -- the only specialization with an extra gate.
## Class id -> ordered Array of that class's own ROOT perk ids (Stage 2's
## locked set). The order here is purely presentational (get_available_
## perks() returns eligible ids in this order); selection has no
## prerequisite relationship between the two entries. A class id absent from
## this dict (should not happen for warrior/scout/cleric) simply offers no
## root perks. See SPECIALIZATION_PERKS immediately below for a promoted
## adventurer's ADDITIONAL perk catalog -- the two dicts are deliberately
## separate rather than merged, since only a promoted adventurer of the
## matching root class ever sees a specialization's entries.
## Stage 6 Step 4: generated from PerkCatalog's own authored catalog (see
## PerkCatalogScript's doc comment) rather than hand-duplicated -- the ids
## themselves, and every existing call site's behavior, are unchanged.
var CLASS_PERKS: Dictionary = {
	"warrior": PerkCatalogScript.get_scope_ids("warrior"),
	"scout": PerkCatalogScript.get_scope_ids("scout"),
	"cleric": PerkCatalogScript.get_scope_ids("cleric"),
}
## Specialization id -> ordered Array of that specialization's OWN perk ids,
## unlocked only once an adventurer has promoted into it (adventurer.
## specialization -- see promote_adventurer()). Mirrors CLASS_PERKS' own
## shape/ordering convention exactly; a specialization id absent here simply
## offers no perks. "knight" shipped in the prior slice; "archer" is this
## slice's addition (Stage 5 D4) -- Battle Mage/Paladin add their own entries
## in later Stage 5 slices reusing this same mechanism, per the ledger's
## explicit "implement as a general mechanism" instruction. Both "knight" and
## "archer" share the same "warrior" root (see SPECIALIZATION_ROOT_CLASS
## immediately below) -- a fully-perked Warrior sees BOTH offered by
## get_available_specializations() and may promote into only one (promotion
## is at most once per adventurer, see that function's own doc comment).
## Stage 6 Step 4 (G3, decision-ledger.md): "knight" now names THREE ids --
## the new "knight_discipline" tier-1 gate plus Shield Bash/Chain Blow, which
## now carry a real prerequisite/mutual-exclusion relationship (see
## PerkCatalog's own doc comment) instead of being two independent perks. The
## per-adventurer slot CAP a Knight ever earns stays exactly 2 (PERK_TREE_
## SIZE, unchanged -- see _perk_catalog_perk_cap()'s mini(PERK_TREE_SIZE,
## SPECIALIZATION_PERKS[id].size()) clamp, which simply clamps 3 down to 2
## the same way it always clamped a class with MORE than PERK_TREE_SIZE
## perks), so a Knight still spends exactly 2 specialization perk slots --
## Discipline, then EITHER Shield Bash OR Chain Blow, never both. Archer and
## Battle Mage are migrated unchanged (still independent, still no DAG
## relationship).
var SPECIALIZATION_PERKS: Dictionary = {
	"knight": PerkCatalogScript.get_scope_ids("knight"),
	"archer": PerkCatalogScript.get_scope_ids("archer"),
	"battle_mage": PerkCatalogScript.get_scope_ids("battle_mage"),
}
## Specialization id -> ordered Array of spell ids GRANTED to a promoted
## adventurer, on top of whatever its own root CLASS_DEFINITIONS entry already
## lists (Stage 5 D4's Battle Mage: "fire_bolt", mirroring how "sleep" itself
## was granted directly to base Mage's own CLASS_DEFINITIONS entry). Spells
## named here are never chosen through the perk-tree/choose_perk() mechanism
## SPECIALIZATION_PERKS drives -- they are unconditionally granted the moment
## adventurer.specialization is set, exactly like a root class's own "spells"
## list is unconditionally granted at creation. The two live spell-hydration
## call sites (BattleController._ready(), BattleStateFactory._build_player_
## unit()) both append this specialization's own entries onto the root class_
## def's "spells" list before hydrating Unit.spells -- see either file's own
## doc comment for the exact append point. adventurer_knows_spell() (this
## file) reads it too. A specialization id absent here simply grants no
## additional spells (Knight/Archer today).
const SPECIALIZATION_SPELLS: Dictionary = {
	"battle_mage": ["fire_bolt"],
}
## Specialization id -> the root CLASS_DEFINITIONS id an adventurer must
## already belong to (with both that root's own CLASS_PERKS already chosen,
## see get_available_specializations()) to promote into it. Existing root
## CLASS_DEFINITIONS entries/ids are never renamed or duplicated -- a
## promoted adventurer keeps adventurer.class == "warrior" forever; only its
## new adventurer.specialization field changes. General mechanism: "archer"
## also keys to "warrior" (verified against docs/designs/class-system.md's
## roadmap table -- Archer is a Warrior specialization, not Scout, despite
## its ranged theme), so this dict is keyed by specialization id (1:1), not
## the other way around, letting more than one specialization share a root.
## "paladin" keys to "cleric" (its own "Cleric->Paladin" ledger row) -- see
## get_available_specializations()'s own doc comment for Paladin's additional
## built-Temple gate, applied on top of this dict's plain root-class check.
const SPECIALIZATION_ROOT_CLASS: Dictionary = {
	"knight": "warrior",
	"archer": "warrior",
	"battle_mage": "mage",
	"paladin": "cleric",
}
## Stage 6 Step 4: PERK_DEFINITIONS itself is retired -- get_perk_definition()
## now delegates straight to PerkCatalogScript.get_definition(), whose own
## PerkDefinition schema already carries a `name_key` field (the only field
## get_perk_display_name() ever reads from this). See PerkCatalogScript's own
## doc comment for the full schema.
# Stage 2 locked balance values (see docs/designs/class-system.md and
# config/game_config.json's "progression" section) -- loaded from config in
# _load_balance_config() same as every other UPPER_SNAKE_CASE var above.
var WARRIOR_JUGGERNAUT_HP_PERCENT: int = 15
var WARRIOR_BULWARK_GUARD: int = 10
var SCOUT_QUICKDRAW_ACTION_POINTS: int = 1
var SCOUT_KEEN_EYES_INTEL_RANGE_BONUS: int = 1
var CLERIC_MEDITATION_SPELL_RANGE_BONUS: int = 1
var CLERIC_DEVOUT_HP_PERCENT: int = 10
## Knight's Shield Bash perk description reuses this exact magnitude -- the
## same GameConfig combat.off_balance_guard_penalty key BattleController
## already reads directly (its own file's established convention of calling
## GameConfig inline rather than caching); this cached var exists purely so
## get_perk_effect_description() can format the perk's display text through
## this file's own established "cache every config value into a var" pattern
## instead of calling GameConfig directly the way battle_controller.gd does.
## No new balance value -- see BattleController.try_shield_bash_selected_
## unit()'s own doc comment for the mechanical reuse.
var OFF_BALANCE_GUARD_PENALTY: int = 10
## Archer's Lock On/Called Shot perk descriptions (Stage 5 D4): cached here
## purely for get_perk_effect_description()'s own formatting, same "cache
## every config value into a var" convention as OFF_BALANCE_GUARD_PENALTY
## immediately above -- BattleController reads the SAME GameConfig keys
## directly and independently (its own established inline-GameConfig
## convention), so both call sites always agree without either one caching
## the other's value. Stored as floats (fractional hit-chance deltas,
## matching combat.parry_counter_melee_hit_bonus/opportunity_attack_melee_
## hit_penalty's own existing representation) and converted to a whole
## percent only at display time.
var ARCHER_LOCK_ON_HIT_CHANCE_BONUS: float = 0.10
var ARCHER_CALLED_SHOT_TO_HIT_PENALTY: float = 0.10
# Base (pre-perk) ranges the two Keen Eyes/Meditation perks add to. Named
# here rather than left as a bare "3" at each call site (get_party_scouting_
# intel()'s scout range, BattleController.try_cast_spell()'s spell range) so
# both the base and its perk bonus are visible together at each effective-
# stat reader below.
const BASE_SCOUT_INTEL_RANGE := 3
const BASE_CLERIC_SPELL_RANGE := 3
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
# Intelligence & Guild Hall quests (docs/designs/intelligence.md, Stage 5
# decision-ledger.md's D1, approved 2026-08-23). Watchtower tier costs and
# their Encampment detection scores are the design doc's own table,
# implemented verbatim (no re-derivation). Quest duration/reward/posting
# are D1's approved formula inputs: duration = encounter_tier *
# QUEST_DURATION_TURNS_PER_TIER World Map Turns; a missed quest blocks new
# postings for encounter_tier * QUEST_POSTING_BLOCK_TURNS_PER_TIER turns;
# reward is QUEST_REWARD_PERCENT of get_encounter_expected_gold_value(tier);
# posting is a one-time QUEST_POSTING_CHANCE_PERCENT roll at live-instance
# creation only (no periodic re-roll -- time-based escalation is deferred).
# The QUEST_TIER_CAP_LEVEL_* table is the design doc's own Guild Hall
# tier -> eligible encounter tier table (1/1-2/1-4/1-5); level 4 is
# forward-looking since GUILD_HALL_MAX_LEVEL caps at 3 today.
var WATCHTOWER_TIER_1_COST: int = 50
var WATCHTOWER_TIER_2_COST: int = 100
var WATCHTOWER_TIER_3_COST: int = 200
var WATCHTOWER_TIER_1_DETECTION: int = 50
var WATCHTOWER_TIER_2_DETECTION: int = 65
var WATCHTOWER_TIER_3_DETECTION: int = 75
var BASE_ENCAMPMENT_DETECTION: int = 25
var QUEST_DURATION_TURNS_PER_TIER: int = 10
var QUEST_POSTING_BLOCK_TURNS_PER_TIER: int = 5
var QUEST_REWARD_PERCENT: int = 50
var QUEST_POSTING_CHANCE_PERCENT: int = 50
var QUEST_TIER_CAP_LEVEL_1: int = 1
var QUEST_TIER_CAP_LEVEL_2: int = 2
var QUEST_TIER_CAP_LEVEL_3: int = 4
var QUEST_TIER_CAP_LEVEL_4: int = 5
## Flat Scouting skill applied to every Scout-class adventurer for the
## Intelligence system's detection/intel formulas (docs/designs/
## intelligence.md's own worked example: "no Watchtower plus a Scout with
## Scouting 20"). No per-adventurer Scouting stat/progression exists in this
## codebase yet and D1's approved parameter table does not define one, but it
## directly scales every detection/intel-accumulation chance the same way the
## sibling Watchtower/quest tunables above do, so it is GameConfig-backed
## like the rest of this step's approved values rather than a plain constant.
var SCOUT_SCOUTING_SKILL: int = 20
## Watchtower has exactly three tiers in the design's own table above --
## a plain constant (not GameConfig-backed) for the same reason
## THREAT_TURN_INTERVAL is: it names how many rows the approved table has,
## not a tunable balance number.
const WATCHTOWER_MAX_LEVEL := 3
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
## Superseded flat, Temple-blind encamped HP rate (docs/designs/campaign-
## loop.md): natural recovery now also depends on Temple tier (see
## TEMPLE_HP_BONUS_PER_TIER) and, for MP-bearing classes, a parallel MP_RATE_*
## trio below -- see _apply_natural_recovery().
var HEAL_RATE_ENCAMPED: int = 3
var HEAL_RATE_RESTING: int = 2
var HEAL_RATE_MOVING: int = 1
## Per-World-Map-Turn MP recovery (config/game_config.json's "healing"
## section): only ever applied to a class carrying an mp_max (Cleric today) --
## see _apply_natural_recovery(), which no-ops MP recovery entirely for any
## other class rather than writing a stray mp_current field. Unlike HP, the
## Temple bonus never applies to MP (docs/designs/campaign-loop.md: "it does
## not change MP recovery").
var MP_RATE_ENCAMPED: int = 6
var MP_RATE_RESTING: int = 4
var MP_RATE_MOVING: int = 2
## +1 HP/turn of natural recovery per Temple tier, added only to the
## Encampment (non-deployed) HP rate above -- see _apply_natural_recovery().
## TEMPLE_MAX_LEVEL is 1 today, so this is currently a step function (+0
## unbuilt, +1 built), but the formula (TEMPLE_HP_BONUS_PER_TIER *
## temple_level) already generalizes to a future higher-tier Temple.
var TEMPLE_HP_BONUS_PER_TIER: int = 1
## Details-view "Heal party member" transaction (see heal_party_member()):
## locked to match the existing battle-local Heal spell exactly (see
## BattleController.SPELL_MP_COST/SPELL_HEAL_MIN/SPELL_HEAL_MAX).
var DETAILS_HEAL_MP_COST: int = 1
var DETAILS_HEAL_MIN: int = 2
var DETAILS_HEAL_MAX: int = 8
## Cleric's max MP (docs/designs/campaign-loop.md: durable current MP is
## "clamped to cleric.mp_max (3, config/game_config.json)"). Config-driven
## like every other var in this block -- see _load_balance_config() and
## get_effective_max_mp(), which reads this var rather than the CLASS_
## DEFINITIONS.cleric.mp_max const those docs used to (incorrectly) claim was
## authoritative. CLASS_DEFINITIONS.cleric.mp_max itself is left as the
## compile-time default other call sites (BattleController._ready(),
## campaign_snapshot.gd, scenario_contract.gd, battle_state_factory.gd) still
## read directly for battle-local Unit.mp_max hydration -- out of scope for
## this fix, see the fix wave's own report.
var CLERIC_MP_MAX: int = 3
## Mage's own max MP (Stage 5 D3): a second, independent config-driven
## spellcasting resource pool -- see get_effective_max_mp(), which branches on
## the adventurer's own class to read this var (never CLERIC_MP_MAX) for a
## Mage. Kept as its own var, not a shared constant with Cleric's, exactly
## per D3's "same default magnitude as Cleric's, via its own mage.mp_max
## GameConfig key" approved value.
var MAGE_MP_MAX: int = 3

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
		# Durable MP (docs/designs/campaign-loop.md's "Cleric current MP is
		# durable adventurer state" paragraph): a fresh Cleric starts at full
		# MP, exactly like health above starts at full HP. Warrior/Scout carry
		# no "mp_current" field at all -- get_current_mp()/get_effective_max_mp()
		# read CLASS_DEFINITIONS to return 0 for those classes without needing
		# a dead field on every record. Reads the config-driven CLERIC_MP_MAX
		# var (not the CLASS_DEFINITIONS.cleric.mp_max compile-time default)
		# so a fresh Cleric's starting MP always agrees with get_effective_
		# max_mp()'s own config-driven value -- see that function's doc
		# comment.
		"mp_current": CLERIC_MP_MAX,
		"progression": {
			"xp": 0.0,
			"perks": [],
		},
	}


## Mage factory (Stage 5 D3): mirrors get_default_cleric() exactly, down to
## the shared mace_iron starting weapon (see CLASS_DEFINITIONS.mage's own
## doc comment) -- only the class id, base stats, and MAGE_MP_MAX differ.
func get_default_mage(adventurer_id: String, adventurer_name: String) -> Dictionary:
	return {
		"id": adventurer_id,
		"name": adventurer_name,
		"class": "mage",
		"equipment": {
			"weapon": "mace_iron", "weapon_inventory": ["mace_iron"],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"stats": CLASS_DEFINITIONS.mage.base_stats.duplicate(true),
		"health": CLASS_DEFINITIONS.mage.base_stats.max_health,
		# Durable MP (mirrors get_default_cleric()'s own identical field):
		# reads the config-driven MAGE_MP_MAX var, not the CLASS_DEFINITIONS.
		# mage.mp_max compile-time default, so a fresh Mage's starting MP
		# always agrees with get_effective_max_mp()'s own config-driven value.
		"mp_current": MAGE_MP_MAX,
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
## Durable journal entries (Stage 7 Information Design). Chronologically ordered list
## of event/quest records. Each entry has:
## { "id": String, "sequence": int, "section": "log"|"quests", "kind": String, "title_key": String, "detail": Dictionary, "read": bool }
var journal_entries: Array[Dictionary] = []
var _journal_sequence: int = 0
var parties: Array[Dictionary] = []

var selected_party_id: String = ""
var selected_encounter: String = ""
## Battle-party tie-break (Stage 5 D5; Stage 6 Step 2, decision-ledger.md's
## G4 disposition): whichever party's Enter GameManager.enter_battle() claims
## first owns the single active battle (relying on the existing single-
## BattleController-instance invariant -- no per-party lock/ownership field
## is added to the parties array itself). The claim itself now lives on
## _battle_context.owner_party_id (see create_battle_context()/
## can_party_enter_battle()) rather than its own dedicated field -- an empty
## _battle_context, or one whose status is no longer "active", means no
## battle is currently claimed. Deliberately NOT part of CampaignSnapshot,
## for the same reason the old active_battle_party_id field never was: a
## save is only ever possible while selected_encounter == "" (see
## GameManager.can_save_current_campaign()) and _battle_context.status ==
## "active" only for the same window selected_encounter is non-empty or a
## battle result/victory screen is still showing unsettled loot, so it can
## never be "active" at a point a save could actually happen. Never reset
## except by reset() itself.
var _battle_context: Dictionary = {}
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
## Injectable class policy for recruitment refills. Production picks Warrior,
## Scout, or Mage with equal probability (Mage needs no Temple-style building
## gate the way Cleric does -- no design doc names one, so it stays available
## the same ungated way Warrior/Scout always have been); tests may force any
## outcome without waiting through unrelated offers. Cleric is deliberately
## NOT part of this roll -- see cleric_offer_roll below, its own separate,
## Temple-gated policy.
var recruitment_class_roll: Callable = func() -> String:
	var roll := randi() % 3
	if roll == 0:
		return "warrior"
	if roll == 1:
		return "scout"
	return "mage"
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
	recruitment_class_roll = func() -> String:
		var roll := randi() % 3
		if roll == 0:
			return "warrior"
		if roll == 1:
			return "scout"
		return "mage"
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
## Injectable so tests can force a deterministic "Heal party member" amount
## (see heal_party_member()) instead of depending on real randomness -- the
## same pattern as loot_gold_roll immediately above. Never reset by reset().
var heal_amount_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
## Injectable percentage rolls (0.0-100.0) for the Intelligence system (see
## docs/designs/intelligence.md) -- same pattern/never-reset-by-reset()
## convention as loot_gold_roll/heal_amount_roll immediately above.
## detection_roll drives both encampment_detection_chance and
## party_detection_chance (_resolve_detection() calls it once per eligible
## source, independently); intel_tier_roll drives the single per-turn
## accumulating-intelligence check (_resolve_intel_tier()); quest_posting_roll
## drives the one-time 50% posting roll at live-instance creation
## (_register_encounter_intel_and_quest()).
var detection_roll: Callable = func() -> float: return randf() * 100.0
var intel_tier_roll: Callable = func() -> float: return randf() * 100.0
var quest_posting_roll: Callable = func() -> float: return randf() * 100.0

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
# Ordered information tiers accumulating scouting intelligence reveals, in
# the design doc's own order: Tier level, then Main monster, then All
# monsters, then Monster counts. INTEL_TIER_MODIFIERS is the doc's
# information_modifier table (x2/x1/x0.75/x0.5), keyed by the tier it takes
# to *reach* that information (e.g. reaching INTEL_TIER_LEVEL uses modifier
# 2.0).
const INTEL_TIER_NONE := 0
const INTEL_TIER_LEVEL := 1
const INTEL_TIER_MAIN_MONSTER := 2
const INTEL_TIER_ALL_MONSTERS := 3
const INTEL_TIER_MONSTER_COUNTS := 4
const INTEL_TIER_MODIFIERS: Dictionary = {1: 2.0, 2: 1.0, 3: 0.75, 4: 0.5}
const QUEST_STATUS_POSTED := "posted"
const QUEST_STATUS_ACTIVE := "active"
const QUEST_STATUS_COMPLETED := "completed"
const QUEST_STATUS_EXPIRED := "expired"
# Intelligence & Guild Hall quests (docs/designs/intelligence.md). Per-live-
# encounter-instance record keyed by the same id space active_encounters/
# CAMPAIGN_OBJECTIVES use ({"discovered": bool, "known_tier": int (0-4, see
# INTEL_TIER_* consts), "quest_id": String ("" when none)}). A record exists
# only for a currently-live encounter; clearing/removing it removes the
# record too (see _settle_encounter_intelligence()) -- knowledge itself never
# decays, but it never outlives the encounter it describes either. An
# authored obj_* node's record starts "discovered": true the instant it
# unlocks (see _ensure_authored_intel_record()) -- discovery is never gated
# by detection for those, only its own progressive info tiers are.
var encounter_intel: Dictionary = {}
# Guild Hall quest records keyed by their own generated id: {"id",
# "encounter_id" (the live instance/authored id this quest targets), "tier"
# (the encounter's star tier at posting), "status" ("posted" until accepted,
# then "active", "completed", or "expired"), "posted_turn", "accepted_turn"
# (-1 until accepted), "expires_turn" (-1 until accepted), "reward_gold"}.
var quests: Dictionary = {}
## No new quest may be posted (see _register_encounter_intel_and_quest())
## before this World Map Turn -- set by _advance_quest_timers() whenever an
## accepted quest's timer lapses uncleared. 0 means no active block.
var quest_posting_blocked_until_turn: int = 0
## Watchtower tier: 0 (unbuilt, BASE_ENCAMPMENT_DETECTION applies) through
## WATCHTOWER_MAX_LEVEL (see WATCHTOWER_TIER_*_COST/_DETECTION above).
var watchtower_level: int = 0
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
## PartyCarry (Stage 6 Step 2, decision-ledger.md): resolves the Stage 5 D5
## known limitation this comment used to describe -- pending_reward/
## pending_mana_crystals/pending_gear/battle_reward/battle_mana_crystals/
## battle_gear used to be single campaign-wide "loot in transit" buckets,
## which pooled two simultaneously-deployed parties' unbanked rewards
## together instead of keeping them independent. Each party's own carry now
## lives on its own `parties` entry (see create_party()'s "carry" field,
## get_party_carry()/deposit_party_carry()/forfeit_party_carry()); the
## in-progress battle's own not-yet-attributed reward lives on
## _battle_context.reward (see create_battle_context()/
## get_active_battle_context()/resolve_battle_victory()) until it is
## resolved into its owning party's own carry. `gold`/`mana_crystals`/
## `banked_gear`/`owned_item_instances`/`banked_item_instance_ids` below
## remain campaign-wide -- they are the shared Encampment bank every party
## deposits into, not a per-party carry.
var mana_crystals: Dictionary = {}
var banked_gear: Dictionary = {}
# Permanent improvements materialize a normal stack entry into one of these
# unique records.  Normal gear deliberately remains in banked_gear so Stores
# can retain its compact stack-based representation.
var owned_item_instances: Dictionary = {}
var banked_item_instance_ids: Array[String] = []
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
	party_service = PartyServiceScript.new(self)
	encounter_service = EncounterServiceScript.new(self)
	progression_service = ProgressionServiceScript.new(self)
	reset()


func _ready() -> void:
	_load_balance_config()
	_validate_content_catalog_at_startup()
	reset()


## Stage 6 Step 3's manual check requires a clear startup diagnostic (not a
## crash, not silently broken battle state) when config/content/ carries an
## invalid encounter -- ContentCatalog.load_catalog() never crashes on bad
## content (see its own doc comment), so this just surfaces whatever
## structured errors it already collected via push_error, exactly once at
## boot. An invalid/missing catalog entry otherwise degrades gracefully:
## get_expedition() simply keeps returning the untouched EXPEDITIONS entry
## for that id (see _overlay_content_catalog_definition()'s early-return).
func _validate_content_catalog_at_startup() -> void:
	var catalog := ContentCatalogScript.load_catalog()
	for error in (catalog.errors as Array):
		push_error("ContentCatalog: %s" % error)


func _load_balance_config() -> void:
	BASE_MOVE_RANGE = GameConfig.get_int("combat", "base_move_range", BASE_MOVE_RANGE)
	EFFECTIVE_HIT_CHANCE_CAP = GameConfig.get_float("combat", "effective_hit_chance_cap", EFFECTIVE_HIT_CHANCE_CAP)
	ATTACK_TO_HIT_CHANCE_DIVISOR = GameConfig.get_float("combat", "attack_to_hit_chance_divisor", ATTACK_TO_HIT_CHANCE_DIVISOR)
	PERK_LEVEL_INTERVAL = GameConfig.get_int("progression", "perk_level_interval", PERK_LEVEL_INTERVAL)
	PERK_TREE_SIZE = GameConfig.get_int("progression", "perk_tree_size", PERK_TREE_SIZE)
	WARRIOR_JUGGERNAUT_HP_PERCENT = GameConfig.get_int("progression", "warrior_juggernaut_hp_percent", WARRIOR_JUGGERNAUT_HP_PERCENT)
	WARRIOR_BULWARK_GUARD = GameConfig.get_int("progression", "warrior_bulwark_guard", WARRIOR_BULWARK_GUARD)
	SCOUT_QUICKDRAW_ACTION_POINTS = GameConfig.get_int("progression", "scout_quickdraw_action_points", SCOUT_QUICKDRAW_ACTION_POINTS)
	SCOUT_KEEN_EYES_INTEL_RANGE_BONUS = GameConfig.get_int("progression", "scout_keen_eyes_intel_range_bonus", SCOUT_KEEN_EYES_INTEL_RANGE_BONUS)
	CLERIC_MEDITATION_SPELL_RANGE_BONUS = GameConfig.get_int("progression", "cleric_meditation_spell_range_bonus", CLERIC_MEDITATION_SPELL_RANGE_BONUS)
	CLERIC_DEVOUT_HP_PERCENT = GameConfig.get_int("progression", "cleric_devout_hp_percent", CLERIC_DEVOUT_HP_PERCENT)
	OFF_BALANCE_GUARD_PENALTY = GameConfig.get_int("combat", "off_balance_guard_penalty", OFF_BALANCE_GUARD_PENALTY)
	ARCHER_LOCK_ON_HIT_CHANCE_BONUS = GameConfig.get_float("combat", "lock_on_hit_chance_bonus", ARCHER_LOCK_ON_HIT_CHANCE_BONUS)
	ARCHER_CALLED_SHOT_TO_HIT_PENALTY = GameConfig.get_float("combat", "called_shot_to_hit_penalty", ARCHER_CALLED_SHOT_TO_HIT_PENALTY)
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
	MP_RATE_ENCAMPED = GameConfig.get_int("healing", "encamped_mp_rate", MP_RATE_ENCAMPED)
	MP_RATE_RESTING = GameConfig.get_int("healing", "resting_mp_rate", MP_RATE_RESTING)
	MP_RATE_MOVING = GameConfig.get_int("healing", "moving_mp_rate", MP_RATE_MOVING)
	TEMPLE_HP_BONUS_PER_TIER = GameConfig.get_int("healing", "temple_hp_bonus_per_tier", TEMPLE_HP_BONUS_PER_TIER)
	DETAILS_HEAL_MP_COST = GameConfig.get_int("cleric", "details_heal_mp_cost", DETAILS_HEAL_MP_COST)
	DETAILS_HEAL_MIN = GameConfig.get_int("cleric", "details_heal_min", DETAILS_HEAL_MIN)
	DETAILS_HEAL_MAX = GameConfig.get_int("cleric", "details_heal_max", DETAILS_HEAL_MAX)
	CLERIC_MP_MAX = GameConfig.get_int("cleric", "mp_max", CLERIC_MP_MAX)
	MAGE_MP_MAX = GameConfig.get_int("mage", "mp_max", MAGE_MP_MAX)
	WATCHTOWER_TIER_1_COST = GameConfig.get_int("intelligence", "watchtower_tier_1_cost", WATCHTOWER_TIER_1_COST)
	WATCHTOWER_TIER_2_COST = GameConfig.get_int("intelligence", "watchtower_tier_2_cost", WATCHTOWER_TIER_2_COST)
	WATCHTOWER_TIER_3_COST = GameConfig.get_int("intelligence", "watchtower_tier_3_cost", WATCHTOWER_TIER_3_COST)
	WATCHTOWER_TIER_1_DETECTION = GameConfig.get_int("intelligence", "watchtower_tier_1_detection", WATCHTOWER_TIER_1_DETECTION)
	WATCHTOWER_TIER_2_DETECTION = GameConfig.get_int("intelligence", "watchtower_tier_2_detection", WATCHTOWER_TIER_2_DETECTION)
	WATCHTOWER_TIER_3_DETECTION = GameConfig.get_int("intelligence", "watchtower_tier_3_detection", WATCHTOWER_TIER_3_DETECTION)
	BASE_ENCAMPMENT_DETECTION = GameConfig.get_int("intelligence", "base_encampment_detection", BASE_ENCAMPMENT_DETECTION)
	QUEST_DURATION_TURNS_PER_TIER = GameConfig.get_int("intelligence", "quest_duration_turns_per_tier", QUEST_DURATION_TURNS_PER_TIER)
	QUEST_POSTING_BLOCK_TURNS_PER_TIER = GameConfig.get_int("intelligence", "quest_posting_block_turns_per_tier", QUEST_POSTING_BLOCK_TURNS_PER_TIER)
	QUEST_REWARD_PERCENT = GameConfig.get_int("intelligence", "quest_reward_percent", QUEST_REWARD_PERCENT)
	QUEST_POSTING_CHANCE_PERCENT = GameConfig.get_int("intelligence", "quest_posting_chance_percent", QUEST_POSTING_CHANCE_PERCENT)
	QUEST_TIER_CAP_LEVEL_1 = GameConfig.get_int("intelligence", "quest_tier_cap_level_1", QUEST_TIER_CAP_LEVEL_1)
	QUEST_TIER_CAP_LEVEL_2 = GameConfig.get_int("intelligence", "quest_tier_cap_level_2", QUEST_TIER_CAP_LEVEL_2)
	QUEST_TIER_CAP_LEVEL_3 = GameConfig.get_int("intelligence", "quest_tier_cap_level_3", QUEST_TIER_CAP_LEVEL_3)
	QUEST_TIER_CAP_LEVEL_4 = GameConfig.get_int("intelligence", "quest_tier_cap_level_4", QUEST_TIER_CAP_LEVEL_4)
	SCOUT_SCOUTING_SKILL = GameConfig.get_int("intelligence", "scout_scouting_skill", SCOUT_SCOUTING_SKILL)
	THREAT_TURN_INTERVAL = GameConfig.get_int("world_map", "threat_turn_interval", THREAT_TURN_INTERVAL)


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
	_battle_context = {}
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
	encounter_intel = {}
	quests = {}
	quest_posting_blocked_until_turn = 0
	watchtower_level = 0
	for instance in active_encounters:
		_register_encounter_intel_and_quest(instance)
	# The campaign's first authored objective starts unlocked (see
	# unlocked_authored_encounters above) -- it is permanently discovered from
	# turn one, matching complete_campaign_objective()'s own guarantee for
	# every later node (see _ensure_authored_intel_record()).
	_ensure_authored_intel_record("obj_tier1_1_goblin_outpost")
	temple_level = 0
	blacksmith_level = 0
	blacksmith_craft_job = {}
	blacksmith_sharpening_job = {}
	alchemy_workshop_level = 0
	alchemy_craft_job = {}
	runic_workshop_level = 0
	runic_craft_job = {}
	mana_crystals = {}
	banked_gear = {}
	owned_item_instances = {}
	banked_item_instance_ids = []
	has_trading_post = true
	shop_level = 1
	shop_gold = SHOP_LEVEL_ONE_GOLD_CAP
	player_name = DEFAULT_PLAYER_NAME
	tutorial_progress = {}
	journal_entries = []
	_journal_sequence = 0


func get_max_party_count() -> int:
	return party_service.get_max_party_count()


func _new_party_id() -> String:
	return party_service._new_party_id()


func _empty_carry() -> Dictionary:
	return party_service._empty_carry()


func create_party(party_name: String = "Party 1") -> bool:
	return party_service.create_party(party_name)


func select_party(party_id: String) -> bool:
	return party_service.select_party(party_id)


func get_selected_party() -> Dictionary:
	return party_service.get_selected_party()


func get_party(party_id: String) -> Dictionary:
	return party_service.get_party(party_id)


func get_adventurer(adventurer_id: String) -> Dictionary:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return {}
	return adventurers[adventurer_index].duplicate(true)


func get_deployable_encamped_parties() -> Array[Dictionary]:
	return party_service.get_deployable_encamped_parties()


func get_encamped_parties() -> Array[Dictionary]:
	return party_service.get_encamped_parties()


func get_deployed_parties() -> Array[Dictionary]:
	return party_service.get_deployed_parties()


func deploy_party(party_id: String) -> bool:
	return party_service.deploy_party(party_id)


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
	return party_service.is_party_deployable(party_id)


func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	return party_service.assign_adventurer_to_party(party_id, adventurer_id)


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	return party_service.assign_adventurer_to_selected_party(adventurer_id)


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
	elif class_id == "mage":
		baseline = get_default_mage(str(record.id), str(record.name))
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
	elif class_id == "mage":
		display_class = "Mage"
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
	return party_service.remove_adventurer_from_selected_party(adventurer_id)


func remove_adventurer_from_party(party_id: String, adventurer_id: String) -> bool:
	return party_service.remove_adventurer_from_party(party_id, adventurer_id)


func can_depart_selected_party() -> bool:
	return party_service.can_depart_selected_party()


func depart_selected_party() -> bool:
	return party_service.depart_selected_party()


func _resolve_party_id(party_id: String) -> String:
	return party_service._resolve_party_id(party_id)


func has_deployed_party(party_id: String = "") -> bool:
	return party_service.has_deployed_party(party_id)


func get_deployed_party_position(party_id: String = "") -> Vector2i:
	return party_service.get_deployed_party_position(party_id)


func set_deployed_party_position(position: Vector2i, party_id: String = "") -> bool:
	return party_service.set_deployed_party_position(position, party_id)


func get_deployed_party_route(party_id: String = "") -> Array[Vector2i]:
	return party_service.get_deployed_party_route(party_id)


func set_deployed_party_route(route: Array[Vector2i], party_id: String = "") -> bool:
	return party_service.set_deployed_party_route(route, party_id)


func clear_deployed_party_route(party_id: String = "") -> void:
	party_service.clear_deployed_party_route(party_id)


func take_next_route_step(party_id: String = "") -> bool:
	return party_service.take_next_route_step(party_id)


## Advances one World Map Turn for every deployed party at once, not only the
## selected one (Stage 5 D5): each deployed party auto-steps its own unspent
## route independently, and every deployed party's movement_spent resets
## together, so a non-selected party keeps travelling exactly like the
## selected one does. Returns true if ANY party auto-moved, matching the
## previous single-party return contract world_map.gd's debug logging reads.
func end_world_turn() -> bool:
	# A selected encounter is the durable marker for an unresolved battle. The
	# World Map may be opened to inspect it, but time cannot pass until the
	# player resumes and resolves (or loses) that battle.
	if selected_encounter != "":
		return false

	var auto_moved := false
	for party in parties:
		if bool(party.get("deployed", false)) and not bool(party.get("movement_spent", false)):
			if take_next_route_step(str(party.id)):
				auto_moved = true

	world_turn += 1
	_advance_blacksmith_jobs()
	_advance_alchemy_craft_job()
	_advance_runic_craft_job()
	if shop_level >= 1:
		gold += _shop_income_per_turn()
	if shop_level >= 1 and world_turn % 10 == 0:
		shop_gold = max(shop_gold, shop_gold_cap())
	_apply_natural_recovery()
	for party_index in parties.size():
		if bool(parties[party_index].get("deployed", false)):
			parties[party_index].movement_spent = false
	_advance_intelligence_and_quests()
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


func return_deployed_party_to_settlement(party_id: String = "") -> bool:
	return party_service.return_deployed_party_to_settlement(party_id)


func _get_selected_party_index() -> int:
	return party_service._get_selected_party_index()


func _get_party_index(party_id: String) -> int:
	return party_service._get_party_index(party_id)


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
	return party_service._party_has_available_member(party)


func _is_party_eligible_for_deployment(party: Dictionary) -> bool:
	return party_service._is_party_eligible_for_deployment(party)


func _is_party_encamped(party: Dictionary) -> bool:
	return party_service._is_party_encamped(party)


func _is_adventurer_assigned(adventurer_id: String) -> bool:
	for party in parties:
		if adventurer_id in party.member_ids:
			return true
	return false


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _resolve_enemy_composition(difficulty: int) -> Dictionary:
	return encounter_service._resolve_enemy_composition(difficulty)


func is_authored_encounter(encounter_id: String) -> bool:
	return encounter_service.is_authored_encounter(encounter_id)


func can_enter_encounter(encounter_id: String) -> bool:
	return encounter_service.can_enter_encounter(encounter_id)


func can_party_enter_battle(party_id: String) -> bool:
	return encounter_service.can_party_enter_battle(party_id)


func create_battle_context(party_id: String, encounter_id: String, seed: int = 0) -> Dictionary:
	return encounter_service.create_battle_context(party_id, encounter_id, seed)


func get_active_battle_context() -> Dictionary:
	return encounter_service.get_active_battle_context()


func enter_encounter(encounter_id: String) -> void:
	encounter_service.enter_encounter(encounter_id)


func complete_current_encounter() -> void:
	encounter_service.complete_current_encounter()


func _ensure_active_battle_context() -> void:
	encounter_service._ensure_active_battle_context()


func _roll_and_queue_loot(enemy: Dictionary) -> void:
	encounter_service._roll_and_queue_loot(enemy)


func abandon_current_encounter() -> void:
	encounter_service.abandon_current_encounter()


func withdraw_from_encounter(encounter_id: String, roll: Callable) -> Array[Dictionary]:
	return encounter_service.withdraw_from_encounter(encounter_id, roll)


func _build_route_to_settlement() -> Array[Vector2i]:
	return encounter_service._build_route_to_settlement()


func get_current_campaign_objective() -> Dictionary:
	return encounter_service.get_current_campaign_objective()


func is_objective_completed(id: String) -> bool:
	return encounter_service.is_objective_completed(id)


func complete_campaign_objective(id: String) -> void:
	encounter_service.complete_campaign_objective(id)


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
## Dictionaries sharing the exact shape a PartyCarry/BattleContext-reward's
## own "gear"/"mana_crystals" fields use. Shared by every carry-to-carry or
## carry-to-bank merge in this file (resolve_battle_victory()/
## deposit_party_carry()).
func _merge_counts(source: Dictionary, dest: Dictionary) -> void:
	for key in source:
		dest[key] = dest.get(key, 0) + source[key]


func get_party_carry(party_id: String) -> Dictionary:
	return party_service.get_party_carry(party_id)


func deposit_party_carry(party_id: String) -> Dictionary:
	return party_service.deposit_party_carry(party_id)


func forfeit_party_carry(party_id: String) -> void:
	party_service.forfeit_party_carry(party_id)


func has_unsettled_battle_loot() -> bool:
	return encounter_service.has_unsettled_battle_loot()


func resolve_battle_victory(battle_id: String) -> bool:
	return encounter_service.resolve_battle_victory(battle_id)


func resolve_battle_retreat(battle_id: String) -> bool:
	return encounter_service.resolve_battle_retreat(battle_id)


func resolve_battle_defeat(battle_id: String) -> bool:
	return encounter_service.resolve_battle_defeat(battle_id)


func get_max_party_size() -> int:
	return party_service.get_max_party_size()


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
	while recruitment_candidates.size() < get_recruitment_offer_cap():
		recruitment_candidates.append(_spawn_next_recruitment_offer())
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
	return encounter_service.is_encounter_complete(encounter_id)


func get_expedition(encounter_id: String) -> Dictionary:
	return encounter_service.get_expedition(encounter_id)


func _overlay_content_catalog_definition(encounter_id: String, expedition: Dictionary) -> Dictionary:
	return encounter_service._overlay_content_catalog_definition(encounter_id, expedition)


## Every THREAT_TURN_INTERVAL world turns elapsed adds one star on top of an
## encounter's own base "difficulty", clamped to the 1-5 range World Map
## markers render (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md). GameConfig-backed (Stage 5 D5,
## decision-ledger.md, Step 6) -- see _load_balance_config()'s own
## "world_map"/"threat_turn_interval" read; the value itself (15) is
## unchanged, only its home moves out of a plain code constant. Returns 1 for
## an unknown encounter id, matching get_expedition()'s own "difficulty"
## fallback.
var THREAT_TURN_INTERVAL: int = 15


func get_threat_stars(encounter_id: String) -> int:
	return encounter_service.get_threat_stars(encounter_id)


func get_turns_until_next_threat_star(encounter_id: String) -> int:
	return encounter_service.get_turns_until_next_threat_star(encounter_id)


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

	# A party with more than one Scout uses whichever member's own effective
	# range (see get_effective_scout_intel_range() -- BASE_SCOUT_INTEL_RANGE,
	# +1 once Keen Eyes is chosen) is largest, rather than any single fixed
	# member's.
	var has_scout := false
	var best_intel_range := 0
	for member_id in party.member_ids:
		var member := get_adventurer(str(member_id))
		if not member.is_empty() and str(member.get("class", "")) == "scout":
			has_scout = true
			best_intel_range = maxi(best_intel_range, get_effective_scout_intel_range(str(member_id)))

	var within_range: bool = (
		bool(party.get("deployed", false))
		and _grid_distance(party.world_position, expedition.position) <= best_intel_range
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


## ---------------------------------------------------------------------
## Intelligence & Guild Hall quests (docs/designs/intelligence.md, Stage 5
## decision-ledger.md's D1). Distinct from get_party_scouting_intel() above:
## that function is the pre-existing, still-shipped binary Scout-in-range
## reveal (docs/plans/2026-08-18-core-loop-and-engagement/
## 04-cleric-class-and-scout-reconnaissance.md's locked decision) which this
## step deliberately leaves untouched to avoid regressing its own dedicated
## test coverage. The system below is additive: it drives its own new state
## (encounter_intel/quests), and World Map/InformationPanel surface whichever
## of the two systems has revealed more for a given encounter (see
## world_map.gd's _get_marker_star_text() and information_panel.gd's
## refresh_encounter()).
## ---------------------------------------------------------------------

## distance_retention = clamp(1.0 - (turn_distance * 0.1), 0.0, 1.0) --
## intelligence.md's own formula. "turn_distance" here is exactly
## _grid_distance() (Manhattan, cardinal-only steps) rather than a separate
## Euclidean "straight-line" measure: it is the same metric build_route()/
## take_next_route_step() already use for actual travel time, so a location
## shown as "N turns away" always falls off intelligence at that same N.
func _distance_retention(turn_distance: int) -> float:
	return clampf(1.0 - (turn_distance * 0.1), 0.0, 1.0)


## The Encampment's current detection score before distance falloff: a
## Watchtower tier's own value replaces BASE_ENCAMPMENT_DETECTION entirely
## (never stacks with it) once built (docs/designs/intelligence.md's table).
func _current_watchtower_detection() -> int:
	if watchtower_level >= 3:
		return WATCHTOWER_TIER_3_DETECTION
	if watchtower_level >= 2:
		return WATCHTOWER_TIER_2_DETECTION
	if watchtower_level >= 1:
		return WATCHTOWER_TIER_1_DETECTION
	return BASE_ENCAMPMENT_DETECTION


## Best SCOUT_SCOUTING_SKILL among roster Scouts not currently part of a
## deployed party ("Scouts currently at the Encampment" per the design doc).
## 0 when no such Scout exists.
func _best_encamped_scout_scouting() -> int:
	var deployed_member_ids: Dictionary = {}
	for party in parties:
		if bool(party.get("deployed", false)):
			for member_id in party.member_ids:
				deployed_member_ids[str(member_id)] = true
	for adventurer in adventurers:
		if str(adventurer.get("class", "")) == "scout" and not deployed_member_ids.has(str(adventurer.id)):
			return SCOUT_SCOUTING_SKILL
	return 0


## Best SCOUT_SCOUTING_SKILL among party's own members who are Scouts. 0 when
## the party has none (the design's "every deployed party containing at
## least one Scout" eligibility gate).
func _best_party_scout_scouting(party: Dictionary) -> int:
	for member_id in party.member_ids:
		var member := get_adventurer(str(member_id))
		if not member.is_empty() and str(member.get("class", "")) == "scout":
			return SCOUT_SCOUTING_SKILL
	return 0


## encampment_detection_chance = clamp((encampment_detection +
## best_encamped_scout_scouting) * distance_retention, 0, 100).
func _encampment_detection_chance(position: Vector2i) -> float:
	var distance := _grid_distance(STARTING_SETTLEMENT_WORLD_POSITION, position)
	var chance := (_current_watchtower_detection() + _best_encamped_scout_scouting()) * _distance_retention(distance)
	return clampf(chance, 0.0, 100.0)


## party_detection_chance = clamp(best_party_scout_scouting *
## distance_retention, 0, 100). 0 for a party with no Scout (never eligible).
func _party_detection_chance(party: Dictionary, position: Vector2i) -> float:
	var best_scouting := _best_party_scout_scouting(party)
	if best_scouting <= 0:
		return 0.0
	var distance := _grid_distance(party.world_position, position)
	return clampf(best_scouting * _distance_retention(distance), 0.0, 100.0)


## Every eligible source (the Encampment, always; each deployed party with a
## Scout) gets its own independent detection_roll call this World Map Turn --
## one success is enough to permanently discover the encounter. Every source
## is always rolled (never short-circuited) so "independent" holds even when
## an earlier source already succeeded.
func _resolve_detection(position: Vector2i) -> bool:
	var detected: bool = float(detection_roll.call()) < _encampment_detection_chance(position)
	for party in parties:
		if not bool(party.get("deployed", false)):
			continue
		if _best_party_scout_scouting(party) <= 0:
			continue
		if detection_roll.call() < _party_detection_chance(party, position):
			detected = true
	return detected


## The best available chance to advance to the next info tier this turn,
## across every eligible source (the Encampment's best encamped Scout, each
## deployed party's best Scout): "use the highest eligible Scouting skill...
## then apply distance retention" is implemented as the best resulting chance
## after distance falloff, rather than picking a single source by raw skill
## alone and only then applying its distance -- with every Scout sharing the
## same flat SCOUT_SCOUTING_SKILL, raw-skill ties would otherwise need an
## arbitrary tiebreak; maximizing the final chance is the strictly more
## player-favorable (and unambiguous) reading of the same sentence.
func _best_intel_chance(position: Vector2i, information_modifier: float) -> float:
	var best := 0.0
	var encampment_scouting := _best_encamped_scout_scouting()
	if encampment_scouting > 0:
		var distance := _grid_distance(STARTING_SETTLEMENT_WORLD_POSITION, position)
		best = maxf(best, encampment_scouting * information_modifier * _distance_retention(distance))
	for party in parties:
		if not bool(party.get("deployed", false)):
			continue
		var party_scouting := _best_party_scout_scouting(party)
		if party_scouting <= 0:
			continue
		var distance := _grid_distance(party.world_position, position)
		best = maxf(best, party_scouting * information_modifier * _distance_retention(distance))
	return clampf(best, 0.0, 100.0)


## Attempts only the next unknown tier (design: "The check attempts only the
## next unknown information tier, so information accumulates in order over
## time") -- one attempted tier per World Map Turn, never more.
func _resolve_intel_tier(position: Vector2i, record: Dictionary) -> void:
	var next_tier: int = int(record.known_tier) + 1
	if next_tier > INTEL_TIER_MONSTER_COUNTS:
		return
	var modifier: float = INTEL_TIER_MODIFIERS[next_tier]
	var chance := _best_intel_chance(position, modifier)
	if chance <= 0.0:
		return
	if intel_tier_roll.call() < chance:
		record.known_tier = next_tier


func _quest_tier_cap_for_guild_hall(level: int) -> int:
	if level >= 4:
		return QUEST_TIER_CAP_LEVEL_4
	if level == 3:
		return QUEST_TIER_CAP_LEVEL_3
	if level == 2:
		return QUEST_TIER_CAP_LEVEL_2
	return QUEST_TIER_CAP_LEVEL_1


func get_encounter_expected_gold_value(tier: int) -> int:
	return encounter_service.get_encounter_expected_gold_value(tier)


## Registers a brand-new live encounter instance's intelligence record
## (always) and, for a non-authored instance only, rolls whether it becomes a
## postable Guild Hall quest (design: "a new live encounter instance is
## created" -- authored obj_* nodes never reach this function in normal play,
## see world_map.gd's own doc comment on why they never enter
## active_encounters). A one-time QUEST_POSTING_CHANCE_PERCENT roll, gated on
## the encounter's own star tier being eligible for the current Guild Hall
## tier and no active posting block -- never re-rolled later (time-based
## escalation is explicitly deferred).
func _register_encounter_intel_and_quest(instance: Dictionary) -> void:
	var instance_id: String = instance.id
	encounter_intel[instance_id] = {
		"discovered": false,
		"known_tier": INTEL_TIER_NONE,
		"quest_id": "",
	}
	var tier: int = int(instance.get("difficulty", 1))
	if world_turn < quest_posting_blocked_until_turn:
		return
	if tier > _quest_tier_cap_for_guild_hall(guild_hall_level):
		return
	if quest_posting_roll.call() >= QUEST_POSTING_CHANCE_PERCENT:
		return

	var quest_id := _new_instance_id()
	var reward := int(round(get_encounter_expected_gold_value(tier) * (QUEST_REWARD_PERCENT / 100.0)))
	quests[quest_id] = {
		"id": quest_id,
		"encounter_id": instance_id,
		"tier": tier,
		"status": QUEST_STATUS_POSTED,
		"posted_turn": world_turn,
		"accepted_turn": -1,
		"expires_turn": -1,
		"reward_gold": reward,
	}
	var record: Dictionary = encounter_intel[instance_id]
	record.quest_id = quest_id
	encounter_intel[instance_id] = record


## An authored obj_* node's discovery guarantee: called the instant it
## unlocks (see complete_campaign_objective()) and once more at a fresh
## campaign's start for the initially-unlocked first node (see reset()).
## Never rolls a quest -- authored objectives are never quest-eligible (D1:
## "Optional (non-authored) live encounter instances only"). Idempotent: a
## record that already exists (should not happen in practice, since each
## authored id unlocks exactly once) is left alone rather than reset to
## undiscovered.
func _ensure_authored_intel_record(encounter_id: String, emit_journal: bool = true) -> void:
	if encounter_intel.has(encounter_id):
		return
	encounter_intel[encounter_id] = {
		"discovered": true,
		"known_tier": INTEL_TIER_NONE,
		"quest_id": "",
	}
	if emit_journal:
		_record_encounter_discovery(encounter_id)


func _record_encounter_discovery(encounter_id: String) -> void:
	var expedition := get_expedition(encounter_id)
	var detail := {
		"encounter_id": encounter_id,
	}
	if expedition.has("name_key"):
		detail["name"] = tr(str(expedition.name_key))
	append_journal_entry(
		"discovery",
		"journal.discovery.title",
		detail,
		JOURNAL_SECTION_LOG
	)


## Backward-compatible migration safety net for import_campaign_snapshot():
## a snapshot exported before this system shipped (format version < 3) --
## or any snapshot otherwise carrying a live encounter/unlocked authored node
## with no matching encounter_intel entry -- would otherwise be permanently
## stuck with no data for it. _advance_intelligence_and_quests() only ever
## iterates encounter_intel's own keys, and _register_encounter_intel_and_
## quest() only ever runs at instance-creation time, never at import, so a
## missing record can never self-heal on its own. A backfilled sandbox
## instance never rolls a retroactive quest (conservative: the player never
## had that instance-creation-time roll's chance to begin with); a backfilled
## authored node goes through the same discovery guarantee every other
## authored node gets.
func _backfill_missing_intel_records() -> void:
	for instance in active_encounters:
		if not encounter_intel.has(instance.id):
			encounter_intel[instance.id] = {"discovered": false, "known_tier": INTEL_TIER_NONE, "quest_id": ""}
	for encounter_id in unlocked_authored_encounters:
		_ensure_authored_intel_record(encounter_id, false)


## Runs once per World Map Turn (see end_world_turn()): for every currently
## live encounter record, attempts detection (if undiscovered) or the next
## info tier (if discovered and not yet fully known) -- never both the same
## turn. Then advances every active quest's timer.
func _advance_intelligence_and_quests() -> void:
	for encounter_id in encounter_intel.keys():
		var record: Dictionary = encounter_intel[encounter_id]
		var expedition := get_expedition(encounter_id)
		if expedition.is_empty():
			continue
		if not bool(record.discovered):
			if _resolve_detection(expedition.position):
				record.discovered = true
				_record_encounter_discovery(encounter_id)
		elif int(record.known_tier) < INTEL_TIER_MONSTER_COUNTS:
			_resolve_intel_tier(expedition.position, record)
		encounter_intel[encounter_id] = record
	_advance_quest_timers()


## Expires any "active" (accepted) quest whose timer has lapsed and opens a
## new posting block for encounter_tier * QUEST_POSTING_BLOCK_TURNS_PER_TIER
## World Map Turns (design: "new quest postings are blocked... already
## posted quests remain visible but are expired and award no quest reward").
## An already-"posted" (never accepted) quest has no timer and is left alone.
func _advance_quest_timers() -> void:
	for quest_id in quests.keys():
		var quest: Dictionary = quests[quest_id]
		if quest.status != QUEST_STATUS_ACTIVE:
			continue
		if world_turn > int(quest.expires_turn):
			quest.status = QUEST_STATUS_EXPIRED
			quests[quest_id] = quest
			var block_turns: int = int(quest.tier) * QUEST_POSTING_BLOCK_TURNS_PER_TIER
			quest_posting_blocked_until_turn = maxi(quest_posting_blocked_until_turn, world_turn + block_turns)


## Removes the cleared encounter's intelligence/quest records (design:
## "Clearing or removing an encounter removes its record"). Called from
## complete_current_encounter() before the instance itself is cleared. An
## "active" (accepted, unexpired) quest completes here: its reward_gold folds
## into the active battle context's own reward alongside normal loot, so it
## flows through the exact same battle-context -> party-carry
## (resolve_battle_victory()) -> gold (deposit_party_carry()) pipeline every
## other reward already uses -- actual gold is only banked once the party
## reaches the Encampment, matching "a quest completes only when its target
## clears AND the party returns to the Encampment" without a parallel reward
## path. A "posted" (never accepted) or "expired" quest is simply dropped: no
## reward. Only ever called from complete_current_encounter(), after
## _ensure_active_battle_context() has already guaranteed an active context
## exists.
func _settle_encounter_intelligence(encounter_id: String) -> void:
	if not encounter_intel.has(encounter_id):
		return
	var quest_id: String = str(encounter_intel[encounter_id].get("quest_id", ""))
	if quest_id != "" and quests.has(quest_id):
		if str(quests[quest_id].status) == QUEST_STATUS_ACTIVE:
			_battle_context.reward.gold += int(quests[quest_id].reward_gold)
		quests.erase(quest_id)
	encounter_intel.erase(encounter_id)


## Public read of one encounter's current intelligence, resolved into the
## exact fields UI needs -- always safe to call for an unknown/absent id
## (returns the fully-unknown shape, matching get_party_scouting_intel()'s
## own not-found convention). enemy_types/enemy_counts are populated
## progressively exactly like get_party_scouting_intel()'s own fields: one
## entry for INTEL_TIER_MAIN_MONSTER (first composition group only), every
## group from INTEL_TIER_ALL_MONSTERS on, and enemy_counts only once
## INTEL_TIER_MONSTER_COUNTS is reached.
func get_encounter_intel(encounter_id: String) -> Dictionary:
	var not_found := {
		"discovered": false,
		"known_tier": INTEL_TIER_NONE,
		"tier_stars": 0,
		"enemy_types": [] as Array[String],
		"enemy_counts": [] as Array[int],
		"quest_id": "",
	}
	if not encounter_intel.has(encounter_id):
		return not_found
	var record: Dictionary = encounter_intel[encounter_id]
	if not bool(record.discovered):
		return not_found

	var known_tier: int = int(record.known_tier)
	var result := {
		"discovered": true,
		"known_tier": known_tier,
		"tier_stars": get_threat_stars(encounter_id) if known_tier >= INTEL_TIER_LEVEL else 0,
		"enemy_types": [] as Array[String],
		"enemy_counts": [] as Array[int],
		"quest_id": str(record.quest_id),
	}
	if known_tier < INTEL_TIER_MAIN_MONSTER:
		return result

	var expedition := get_expedition(encounter_id)
	var groups: Array = []
	if expedition.has("enemies"):
		for group in expedition.enemies:
			groups.append({"stats": group.get("enemy", {}), "count": int(group.get("count", 1))})
	else:
		var enemy: Dictionary = expedition.get("enemy", {})
		groups.append({"stats": enemy, "count": int(enemy.get("count", 0))})

	var group_limit: int = groups.size() if known_tier >= INTEL_TIER_ALL_MONSTERS else 1
	for index in group_limit:
		var group: Dictionary = groups[index]
		result.enemy_types.append(tr(str(group.stats.get("name_key", ""))))
		if known_tier >= INTEL_TIER_MONSTER_COUNTS:
			result.enemy_counts.append(group.count)
	return result


func get_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in quests:
		result.append(quests[quest_id].duplicate(true))
	return result


func get_quest(quest_id: String) -> Dictionary:
	if not quests.has(quest_id):
		return {}
	return quests[quest_id].duplicate(true)


## Accepting a quest permanently discovers its target and reveals its Tier
## level and Main monster (INTEL_TIER_MAIN_MONSTER) -- never downgrades an
## already-higher known_tier. Only a "posted" (not yet accepted) quest can be
## accepted; false for an unknown id or any other status.
func accept_quest(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	var quest: Dictionary = quests[quest_id]
	if quest.status != QUEST_STATUS_POSTED:
		return false

	quest.status = QUEST_STATUS_ACTIVE
	quest.accepted_turn = world_turn
	quest.expires_turn = world_turn + int(quest.tier) * QUEST_DURATION_TURNS_PER_TIER
	quests[quest_id] = quest

	var encounter_id: String = str(quest.encounter_id)
	if encounter_intel.has(encounter_id):
		var record: Dictionary = encounter_intel[encounter_id]
		var was_discovered: bool = bool(record.get("discovered", false))
		record.discovered = true
		record.known_tier = maxi(int(record.known_tier), INTEL_TIER_MAIN_MONSTER)
		encounter_intel[encounter_id] = record
		if not was_discovered:
			_record_encounter_discovery(encounter_id)
	return true


## Cost to purchase (level 0 -> 1) or upgrade the Watchtower to the next
## tier; -1 once WATCHTOWER_MAX_LEVEL is already reached (mirrors
## _guild_hall_upgrade_cost()'s pattern for an analogous tiered building).
func get_watchtower_upgrade_cost() -> int:
	if watchtower_level >= WATCHTOWER_MAX_LEVEL:
		return -1
	if watchtower_level == 0:
		return WATCHTOWER_TIER_1_COST
	if watchtower_level == 1:
		return WATCHTOWER_TIER_2_COST
	return WATCHTOWER_TIER_3_COST


func can_upgrade_watchtower() -> bool:
	return watchtower_level < WATCHTOWER_MAX_LEVEL and gold >= get_watchtower_upgrade_cost()


func upgrade_watchtower() -> bool:
	if not can_upgrade_watchtower():
		return false
	gold -= get_watchtower_upgrade_cost()
	watchtower_level += 1
	return true


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
## the victory summary (the active battle context's own reward), and the
## World Map's Party Details screen (a party's own carry), each backed by a
## different pair of gear/mana-crystal dictionaries but sharing this exact
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
## equip_item_from_party_carry() below except which pool it draws from.
func equip_item_from_bank(adventurer_id: String, item_id: String) -> bool:
	if owned_item_instances.has(item_id):
		return _equip_item_instance_from(banked_item_instance_ids, adventurer_id, item_id)
	return _equip_item_from(banked_gear, adventurer_id, item_id)


## Shared by equip_item_from_bank()/equip_item_from_party_carry(): makes
## instance_id the active item for its slot, removing it from source_ids (a
## unique-instance id Array of the exact shape banked_item_instance_ids and a
## PartyCarry's own "item_instance_ids" both use) unless the unit already
## carries it. Rejects (mutates nothing) for an id not currently in
## source_ids, an unknown item id, or an unknown adventurer.
func _equip_item_instance_from(source_ids: Array, adventurer_id: String, instance_id: String) -> bool:
	if not source_ids.has(instance_id):
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
	source_ids.erase(instance_id)
	inventory.append(instance_id)
	adventurers[adventurer_index].equipment[slot] = instance_id
	return true


func equip_item_from_party_carry(party_id: String, adventurer_id: String, item_id: String) -> bool:
	return party_service.equip_item_from_party_carry(party_id, adventurer_id, item_id)


## Shared by equip_item_from_bank()/equip_item_from_party_carry(): makes
## item_id the active item for its slot, taking one unit from source_gear
## (a Dictionary of the exact same id -> count shape banked_gear and a
## PartyCarry's own "gear" field both use) unless the unit already carries
## item_id, in which case source_gear is untouched and the already-carried
## copy is just re-activated. Rejects (mutates nothing) for an item not
## currently in source_gear, an unknown item id, or an unknown adventurer.
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
	return encounter_service.get_active_encounters()


func _make_encounter_instance(instance_id: String, template_id: String, position: Vector2i) -> Dictionary:
	return encounter_service._make_encounter_instance(instance_id, template_id, position)


func _get_active_encounter_index(instance_id: String) -> int:
	return encounter_service._get_active_encounter_index(instance_id)


func _clear_active_encounter(instance_id: String) -> void:
	encounter_service._clear_active_encounter(instance_id)


func _resolve_vacancy_delay(base_turns: int, jitter_turns: int) -> int:
	return encounter_service._resolve_vacancy_delay(base_turns, jitter_turns)


func _start_encounter_vacancy() -> void:
	encounter_service._start_encounter_vacancy()


func _advance_encounter_vacancies() -> void:
	encounter_service._advance_encounter_vacancies()


func _spawn_next_encounter_instance() -> Dictionary:
	return encounter_service._spawn_next_encounter_instance()


func _player_power() -> int:
	return encounter_service._player_power()


func _star_tier_weight(tier: int, power: int) -> int:
	return encounter_service._star_tier_weight(tier, power)


func _choose_encounter_template() -> String:
	return encounter_service._choose_encounter_template()


func _is_encounter_template_active(template_id: String) -> bool:
	return encounter_service._is_encounter_template_active(template_id)


func _choose_encounter_position(template_id: String) -> Vector2i:
	return encounter_service._choose_encounter_position(template_id)


func _is_position_occupied(position: Vector2i) -> bool:
	return encounter_service._is_position_occupied(position)


func _mint_encounter_instance_id() -> String:
	return encounter_service._mint_encounter_instance_id()


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


## The RECRUITMENT_CANDIDATE_TEMPLATES pool has no Cleric or Mage entries (it
## is the decided 3-warrior + 1-scout starting composition -- see that const's
## own doc comment), so a Cleric or Mage refill always mints an overflow
## candidate here.
func _make_overflow_recruitment_offer(class_id: String) -> Dictionary:
	if class_id == "cleric":
		return get_default_cleric(_new_instance_id(), _next_cosmetic_adventurer_name("cleric"))
	if class_id == "mage":
		return get_default_mage(_new_instance_id(), _next_cosmetic_adventurer_name("mage"))
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


func award_party_xp(party_id: String, amount: float) -> Array[String]:
	return progression_service.award_party_xp(party_id, amount)


func _award_adventurer_xp(adventurer_id: String, amount: float) -> bool:
	return progression_service._award_adventurer_xp(adventurer_id, amount)


func get_level_xp_threshold(level: int) -> float:
	return progression_service.get_level_xp_threshold(level)


func is_perk_choice_pending(adventurer_id: String) -> bool:
	return progression_service.is_perk_choice_pending(adventurer_id)


func _perk_catalog_perk_cap(adventurer: Dictionary) -> int:
	return progression_service._perk_catalog_perk_cap(adventurer)


func _pending_perk_slot_count(adventurer: Dictionary) -> int:
	return progression_service._pending_perk_slot_count(adventurer)


func get_available_perks(adventurer_id: String) -> Array[String]:
	return progression_service.get_available_perks(adventurer_id)


func get_perk_tree_status(adventurer_id: String) -> Array[Dictionary]:
	return progression_service.get_perk_tree_status(adventurer_id)


func get_perk_definition(perk_id: String) -> Dictionary:
	return progression_service.get_perk_definition(perk_id)


func get_perk_display_name(perk_id: String) -> String:
	return progression_service.get_perk_display_name(perk_id)


func get_perk_effect_description(perk_id: String) -> String:
	return progression_service.get_perk_effect_description(perk_id)


func choose_perk(adventurer_id: String, perk_id: String) -> bool:
	return progression_service.choose_perk(adventurer_id, perk_id)


## --- Specializations (Stage 5 D4) -------------------------------------------

func get_available_specializations(adventurer_id: String) -> Array[String]:
	return progression_service.get_available_specializations(adventurer_id)


func is_promotion_eligible(adventurer_id: String, specialization_id: String) -> bool:
	return progression_service.is_promotion_eligible(adventurer_id, specialization_id)


func promote_adventurer(adventurer_id: String, specialization_id: String) -> bool:
	return progression_service.promote_adventurer(adventurer_id, specialization_id)


func get_adventurer_specialization(adventurer_id: String) -> String:
	return progression_service.get_adventurer_specialization(adventurer_id)


func get_effective_hit_chance(adventurer_id: String) -> float:
	return progression_service.get_effective_hit_chance(adventurer_id)


func get_effective_melee(adventurer_id: String) -> int:
	return progression_service.get_effective_melee(adventurer_id)


func get_effective_missile(adventurer_id: String) -> int:
	return progression_service.get_effective_missile(adventurer_id)


func get_effective_spellcasting(adventurer_id: String) -> int:
	return progression_service.get_effective_spellcasting(adventurer_id)


func get_effective_magic_resistance(_adventurer_id: String) -> int:
	return progression_service.get_effective_magic_resistance(_adventurer_id)


func get_enemy_profile_hit_chance(stats: Dictionary) -> float:
	return progression_service.get_enemy_profile_hit_chance(stats)


func get_enemy_profile_guard(stats: Dictionary) -> int:
	return progression_service.get_enemy_profile_guard(stats)


func get_enemy_profile_melee(stats: Dictionary) -> int:
	return progression_service.get_enemy_profile_melee(stats)


func get_enemy_profile_missile(stats: Dictionary) -> int:
	return progression_service.get_enemy_profile_missile(stats)


func get_effective_max_health(adventurer_id: String) -> int:
	return progression_service.get_effective_max_health(adventurer_id)


## Pure Juggernaut/Devout percent-bonus math, factored out of get_effective_
## max_health() so CampaignSnapshot's own health-clamp normalization (see
## _normalize_roster_records() in campaign_snapshot.gd) can compute the same
## effective max for a record that is not yet -- and may never be -- part of
## GameSession.adventurers, without duplicating this formula in two files.
## Static and side-effect-free: takes every input explicitly (base max health
## and the record's own progression.perks) rather than reading any session
## state, so campaign_snapshot.gd/battle_state_factory.gd can call it via the
## preloaded script reference the same way they already do for CLASS_PERKS.
##
## Stage 6 Step 4: delegates to PerkEffectResolver.compute_stat_modifier(),
## which reads every perk's own percent_bonus straight out of PerkCatalog
## (itself reading the same GameConfig keys this file's own WARRIOR_
## JUGGERNAUT_HP_PERCENT/CLERIC_DEVOUT_HP_PERCENT vars cache) -- so this no
## longer takes explicit percentage arguments; a caller never needs to thread
## GameSession's own cached balance vars through just to compute this.
static func compute_effective_max_health(base_max_health: int, perks: Array) -> int:
	return PerkEffectResolverScript.compute_stat_modifier(base_max_health, perks, "max_health")


func get_current_health(adventurer_id: String) -> int:
	return progression_service.get_current_health(adventurer_id)


func set_adventurer_health(adventurer_id: String, amount: int) -> bool:
	return progression_service.set_adventurer_health(adventurer_id, amount)


func get_effective_max_mp(adventurer_id: String) -> int:
	return progression_service.get_effective_max_mp(adventurer_id)


func get_current_mp(adventurer_id: String) -> int:
	return progression_service.get_current_mp(adventurer_id)


func set_adventurer_mp(adventurer_id: String, amount: int) -> bool:
	return progression_service.set_adventurer_mp(adventurer_id, amount)


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
## into its own party's carry (see transfer_dead_unit_gear_to_party_carry()),
## its id is erased from every party's member_ids, and the adventurer record
## itself is deleted from the roster -- so a dead id can never remain in live
## session state afterward, and (docs/designs/campaign-loop.md: "a dead
## adventurer owns no persisted MP record, the same as HP") whatever
## "mp_current" the record carried is discarded along with it, no separate
## MP-specific cleanup needed. A later successful retreat or victory banks
## that gear through the existing settlement transition (deposit_party_
## carry()); a wipe forfeits it instead (forfeit_party_carry()).
## owned_item_instances records are never deleted here -- only forfeit_
## party_carry() ever discards a recovered instance record, never a
## successful recovery. Returns the ids actually removed.
func resolve_battle_deaths(health_by_id: Dictionary) -> Array[String]:
	var dead_ids: Array[String] = []
	for id_key in health_by_id:
		var adventurer_id := String(id_key)
		if int(health_by_id[id_key]) <= 0 and _has_adventurer(adventurer_id):
			dead_ids.append(adventurer_id)

	for adventurer_id in dead_ids:
		transfer_dead_unit_gear_to_party_carry(_get_party_for_adventurer(adventurer_id).get("id", ""), adventurer_id)
		for party_index in parties.size():
			parties[party_index].member_ids.erase(adventurer_id)
		adventurers.remove_at(_get_adventurer_index(adventurer_id))
	total_casualties += dead_ids.size()
	return dead_ids


func transfer_dead_unit_gear_to_party_carry(party_id: String, unit_id: String) -> void:
	party_service.transfer_dead_unit_gear_to_party_carry(party_id, unit_id)


## Batch write-back used by the battlefield after victory or defeat.
## For each entry, persists max(1, reported) clamped to max health.
func apply_battle_aftermath(health_by_id: Dictionary) -> void:
	for id_key in health_by_id:
		var adventurer_id := String(id_key)
		var reported := int(health_by_id[id_key])
		set_adventurer_health(adventurer_id, max(1, reported))


## Batch write-back used by the battlefield after victory or defeat, the MP
## twin of apply_battle_aftermath() above (docs/designs/campaign-loop.md:
## "battle aftermath writes the surviving Cleric's remaining MP back,
## clamped to cleric.mp_max"). Battlefield._persist_battle_aftermath() only
## ever populates mp_by_id from grid.units survivors (never from
## defeated_player_health_by_id), but even if a now-dead id somehow reached
## this call, set_adventurer_mp() already no-ops for an id resolve_battle_
## deaths() just erased -- no MP floor is needed the way apply_battle_
## aftermath()'s max(1, ...) floors health, because 0 MP is a legitimate
## resting value, not a death condition.
func apply_battle_mp_aftermath(mp_by_id: Dictionary) -> void:
	for id_key in mp_by_id:
		set_adventurer_mp(String(id_key), int(mp_by_id[id_key]))


func _get_party_for_adventurer(adventurer_id: String) -> Dictionary:
	for party in parties:
		if adventurer_id in party.member_ids:
			return party
	return {}


## True when adventurer_id is physically at the Encampment: either unassigned
## to any party, or a member of a party that has not deployed. Used by both
## _apply_natural_recovery() (Temple bonus eligibility) and heal_party_
## member()'s target legality (docs/designs/campaign-loop.md: "a living
## adventurer at the Encampment when the Healer is encamped").
func _is_adventurer_at_encampment(adventurer_id: String) -> bool:
	var party: Dictionary = _get_party_for_adventurer(adventurer_id)
	return party.is_empty() or not bool(party.get("deployed", false))


## Natural per-World-Map-Turn recovery (docs/designs/campaign-loop.md):
## HP always recovers (moving/resting/encamped rate, the last boosted by
## TEMPLE_HP_BONUS_PER_TIER * temple_level); MP recovers on the parallel
## MP_RATE_* trio, but only for a class that actually carries an MP resource
## (get_effective_max_mp() > 0) -- every other class is left with no
## "mp_current" field at all, never a spurious 0 one.
func _apply_natural_recovery() -> void:
	for adventurer in adventurers:
		var adv_id := String(adventurer.id)
		var deployed := not _is_adventurer_at_encampment(adv_id)
		var party: Dictionary = _get_party_for_adventurer(adv_id)
		var moving := deployed and bool(party.get("movement_spent", false))

		var hp_rate := HEAL_RATE_ENCAMPED + TEMPLE_HP_BONUS_PER_TIER * temple_level
		var mp_rate := MP_RATE_ENCAMPED
		if deployed:
			if moving:
				hp_rate = HEAL_RATE_MOVING
				mp_rate = MP_RATE_MOVING
			else:
				hp_rate = HEAL_RATE_RESTING
				mp_rate = MP_RATE_RESTING

		var current_hp := get_current_health(adv_id)
		var max_hp := get_effective_max_health(adv_id)
		if current_hp < max_hp:
			adventurers[_get_adventurer_index(adv_id)]["health"] = mini(current_hp + hp_rate, max_hp)

		var max_mp := get_effective_max_mp(adv_id)
		if max_mp > 0:
			var current_mp := get_current_mp(adv_id)
			if current_mp < max_mp:
				adventurers[_get_adventurer_index(adv_id)]["mp_current"] = mini(current_mp + mp_rate, max_mp)


## Stage 5 D3 fix: Mage now carries the same MP-shaped resource the Details-
## view Heal action reads (get_effective_max_mp() > 0), but Mage's
## CLASS_DEFINITIONS entry names no "heal" spell -- gating on MP alone would
## let a Mage use Cleric's Details-view heal for free. Keys off whether
## adventurer_id's own class actually lists spell_id among CLASS_
## DEFINITIONS[class].spells, the same data BattleController._ready()/
## BattleStateFactory already hydrate a battle-local Unit's `spells` array
## from, so this can never disagree with which spells a class' battle-local
## Unit actually carries. Public (not a private "_"-prefixed helper) since
## unit_details.gd's own _refresh_heal_section() reads it too, to decide
## whether to show the Heal row at all rather than a permanently-disabled one.
func adventurer_knows_spell(adventurer_id: String, spell_id: String) -> bool:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return false
	var class_def: Dictionary = CLASS_DEFINITIONS.get(str(adventurer.get("class", "")), {})
	if (class_def.get("spells", []) as Array).has(spell_id):
		return true
	# Stage 5 D4: a promoted specialization can GRANT an additional spell on
	# top of its root class's own list (Battle Mage's "fire_bolt" -- see
	# SPECIALIZATION_SPELLS' own doc comment) without that spell ever
	# appearing on the root CLASS_DEFINITIONS entry itself, so an unpromoted
	# Mage never knows it.
	var specialization_id := str(adventurer.get("specialization", ""))
	if specialization_id.is_empty():
		return false
	return (SPECIALIZATION_SPELLS.get(specialization_id, []) as Array).has(spell_id)


## Details-view "Heal party member" transaction (docs/designs/campaign-
## loop.md's Healer paragraph): caster_id spends DETAILS_HEAL_MP_COST MP to
## restore a random DETAILS_HEAL_MIN-DETAILS_HEAL_MAX HP (matching the
## existing battle-local Heal spell exactly -- see BattleController.
## SPELL_MP_COST/SPELL_HEAL_MIN/SPELL_HEAL_MAX) to target_id, capped at the
## target's own effective max HP. Every precondition -- caster's class knows
## "heal" (see adventurer_knows_spell()), caster has enough MP, target
## is a legal heal target (see _is_legal_heal_target()), target is not
## already at full HP -- is checked before any mutation, so a rejected call
## never spends MP or changes HP. Returns whether the heal actually happened.
func heal_party_member(caster_id: String, target_id: String) -> bool:
	if not adventurer_knows_spell(caster_id, "heal"):
		return false
	if get_current_mp(caster_id) < DETAILS_HEAL_MP_COST:
		return false
	if not _is_legal_heal_target(caster_id, target_id):
		return false
	var current_hp := get_current_health(target_id)
	var max_hp := get_effective_max_health(target_id)
	if current_hp >= max_hp:
		return false

	set_adventurer_mp(caster_id, get_current_mp(caster_id) - DETAILS_HEAL_MP_COST)
	var healed: int = heal_amount_roll.call(DETAILS_HEAL_MIN, DETAILS_HEAL_MAX)
	set_adventurer_health(target_id, current_hp + healed)
	return true


## heal_party_member()'s target-legality rule, factored out so get_legal_
## heal_targets() (unit_details.gd's target picker) and the transaction
## itself always agree: caster_id and target_id must both name a live
## adventurer (a dead one owns no record at all, see resolve_battle_deaths()),
## and either target_id is a member of caster_id's own deployed party, or
## caster_id itself is not deployed and target_id is at the Encampment.
func _is_legal_heal_target(caster_id: String, target_id: String) -> bool:
	if get_adventurer(caster_id).is_empty() or get_adventurer(target_id).is_empty():
		return false
	var caster_party: Dictionary = _get_party_for_adventurer(caster_id)
	var caster_deployed := not caster_party.is_empty() and bool(caster_party.get("deployed", false))
	if caster_deployed:
		return target_id in caster_party.member_ids
	return _is_adventurer_at_encampment(target_id)


## The living, legal, actually-healable targets for caster_id's "Heal party
## member" action (unit_details.gd's target picker) -- legal per _is_legal_
## heal_target() and not already at full HP, since a full-HP target can never
## be usefully healed (see heal_party_member()'s own no-op check). Excluding
## those here, rather than merely letting the transaction no-op on one, is
## what lets the UI disable the whole action and explain why instead of
## offering a target guaranteed to do nothing. Returns [] for an unknown
## caster, a class with no MP resource at all, or (Stage 5 D3) a class whose
## spells don't include "heal" (Mage) -- see adventurer_knows_spell().
func get_legal_heal_targets(caster_id: String) -> Array[String]:
	var targets: Array[String] = []
	if not adventurer_knows_spell(caster_id, "heal"):
		return targets
	if get_effective_max_mp(caster_id) <= 0:
		return targets
	for adventurer in adventurers:
		var target_id := String(adventurer.id)
		if not _is_legal_heal_target(caster_id, target_id):
			continue
		if get_current_health(target_id) >= get_effective_max_health(target_id):
			continue
		targets.append(target_id)
	return targets


func get_effective_action_points(adventurer_id: String) -> int:
	return progression_service.get_effective_action_points(adventurer_id)


## Pure Bonus Move/Quickdraw AP-bonus math, factored out of get_effective_
## action_points() so BattleStateFactory._build_player_unit() (docs/plans/
## 2026-08-21-stage-2-party-readiness/ fix wave's Fix 1) can apply the exact
## same formula to a scenario-built unit's own explicit `perks` field,
## without duplicating it or reading GameSession's mutable adventurer
## records (a scenario has no adventurer record -- see battle_state_
## factory.gd's own doc comment on why it never touches GameSession's
## mutable campaign fields). Static and side-effect-free, mirroring compute_
## effective_max_health()'s identical pattern.
##
## Stage 6 Step 4: delegates to PerkEffectResolver.compute_stat_modifier() --
## Bonus Move's own +1 (a retired legacy perk, see BONUS_MOVE_PERK_ID's own
## doc comment) and Quickdraw's configured bonus are both looked up from
## PerkCatalog now, so this no longer takes them as explicit arguments.
static func compute_effective_action_points(base_action_points: int, perks: Array) -> int:
	return PerkEffectResolverScript.compute_stat_modifier(base_action_points, perks, "action_points")


func get_effective_weapon_damage_range(adventurer_id: String) -> Vector2i:
	return progression_service.get_effective_weapon_damage_range(adventurer_id)


func get_effective_weapon_attack_range(adventurer_id: String) -> Vector2i:
	return progression_service.get_effective_weapon_attack_range(adventurer_id)


func get_effective_weapon_raw_damage_bonus(adventurer_id: String) -> int:
	return progression_service.get_effective_weapon_raw_damage_bonus(adventurer_id)


func get_effective_weapon_name(adventurer_id: String) -> String:
	return progression_service.get_effective_weapon_name(adventurer_id)


func get_effective_armor_name(adventurer_id: String) -> String:
	return progression_service.get_effective_armor_name(adventurer_id)


func get_effective_defense(adventurer_id: String) -> int:
	return progression_service.get_effective_defense(adventurer_id)


## Pure Bulwark Guard-bonus math, factored out of get_effective_defense() so
## BattleStateFactory._build_player_unit() (docs/plans/2026-08-21-stage-2-
## party-readiness/ fix wave's Fix 1) can apply the exact same formula to a
## scenario-built unit's own explicit `perks` field -- see compute_effective_
## action_points()'s identical doc comment for why this is static and takes
## every input explicitly rather than reading GameSession's mutable
## adventurer records.
##
## Stage 6 Step 4: delegates to PerkEffectResolver.compute_stat_modifier() --
## Bulwark's flat Guard bonus is now looked up from PerkCatalog, so this no
## longer takes it as an explicit argument.
static func compute_effective_defense(base_defense: int, perks: Array) -> int:
	return PerkEffectResolverScript.compute_stat_modifier(base_defense, perks, "defense")


func get_effective_scout_intel_range(adventurer_id: String) -> int:
	return progression_service.get_effective_scout_intel_range(adventurer_id)


func get_effective_spell_range(adventurer_id: String) -> int:
	return progression_service.get_effective_spell_range(adventurer_id)


func get_effective_might(adventurer_id: String) -> int:
	return progression_service.get_effective_might(adventurer_id)


func get_effective_resistance(adventurer_id: String) -> int:
	return progression_service.get_effective_resistance(adventurer_id)


## Appends a new journal entry to the durable journal log or quests section.
## Generates a stable unique id and assigns the next sequence number.
func append_journal_entry(
	kind: String,
	title_key: String,
	detail: Dictionary = {},
	section: String = JOURNAL_SECTION_LOG
) -> String:
	var entry_section: String = section if JOURNAL_SECTIONS.has(section) else JOURNAL_SECTION_LOG
	_journal_sequence += 1
	var entry_id: String = _new_instance_id()
	var entry: Dictionary = {
		"id": entry_id,
		"sequence": _journal_sequence,
		"section": entry_section,
		"kind": kind,
		"title_key": title_key,
		"detail": detail.duplicate(true),
		"read": false,
	}
	journal_entries.append(entry)
	journal_updated.emit()
	return entry_id


## Returns a list of deep-duplicated journal entries in deterministic chronological order.
## If section is non-empty, filters entries to that section only.
func get_journal_entries(section: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in journal_entries:
		if section.is_empty() or entry.get("section", "") == section:
			result.append(entry.duplicate(true))
	return result


## Returns a single journal entry by id, or an empty Dictionary if not found.
func get_journal_entry(entry_id: String) -> Dictionary:
	for entry in journal_entries:
		if entry.get("id", "") == entry_id:
			return entry.duplicate(true)
	return {}


## Returns true if there are any unread entries in the journal.
## If section is non-empty, checks only entries in that section.
func has_unread_journal_entries(section: String = "") -> bool:
	for entry in journal_entries:
		if not section.is_empty() and entry.get("section", "") != section:
			continue
		if not bool(entry.get("read", false)):
			return true
	return false


## Marks a journal entry as read by its id.
## Idempotent: returns true if the entry exists (whether previously unread or already read).
## Returns false if the entry is not found. Emits journal_updated only if read state changed.
func mark_journal_entry_read(entry_id: String) -> bool:
	for entry in journal_entries:
		if entry.get("id", "") == entry_id:
			if not bool(entry.get("read", false)):
				entry["read"] = true
				journal_updated.emit()
			return true
	return false


## Acknowledges every Journal entry in one durable operation. Opening the Log
## is the player's acknowledgement boundary, so one signal is emitted only
## when at least one unread record changed state.
func mark_all_journal_entries_read() -> bool:
	var changed := false
	for entry in journal_entries:
		if not bool(entry.get("read", false)):
			entry["read"] = true
			changed = true
	if changed:
		journal_updated.emit()
	return changed




## Exports every durable field this session owns as a versioned, deep-copy-
## safe, JSON-safe Dictionary (see CampaignSnapshot). No disk I/O and no
## reward-banking side effects -- each party's own "carry" (part of its
## `parties` entry) is carried across exactly as it stands, never deposited.
## The in-progress battle context (_battle_context) is deliberately NOT
## exported, for the same reason active_battle_party_id never was (see that
## field's own former doc comment): a save is only ever possible while no
## battle is unsettled.
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
	snapshot.encounter_intel = encounter_intel.duplicate(true)
	snapshot.quests = quests.duplicate(true)
	snapshot.quest_posting_blocked_until_turn = quest_posting_blocked_until_turn
	snapshot.watchtower_level = watchtower_level
	snapshot.temple_level = temple_level
	snapshot.blacksmith_level = blacksmith_level
	snapshot.blacksmith_craft_job = blacksmith_craft_job.duplicate(true)
	snapshot.blacksmith_sharpening_job = blacksmith_sharpening_job.duplicate(true)
	snapshot.alchemy_workshop_level = alchemy_workshop_level
	snapshot.alchemy_craft_job = alchemy_craft_job.duplicate(true)
	snapshot.runic_workshop_level = runic_workshop_level
	snapshot.runic_craft_job = runic_craft_job.duplicate(true)
	snapshot.mana_crystals = mana_crystals.duplicate(true)
	snapshot.banked_gear = banked_gear.duplicate(true)
	snapshot.owned_item_instances = owned_item_instances.duplicate(true)
	snapshot.banked_item_instance_ids = banked_item_instance_ids.duplicate()
	snapshot.has_trading_post = has_trading_post
	snapshot.shop_level = shop_level
	snapshot.shop_gold = shop_gold
	snapshot.player_name = player_name
	snapshot.tutorial_progress = tutorial_progress.duplicate(true)
	snapshot.journal_entries = journal_entries.duplicate(true)
	return snapshot.to_dictionary()



## All-or-nothing import: validates and normalizes data into a separate
## Dictionary (see CampaignSnapshot.from_dictionary()) and only assigns this
## session's own fields once that normalization reports "ok": true, so a
## rejected import never partially lands. Returns the same
## { "ok", "snapshot", "error" } result CampaignSnapshot.from_dictionary()
## produced, for the caller to inspect. Never calls resolve_battle_victory()
## or deposit_party_carry() -- each party's own carry is restored exactly as
## exported, never banked.
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
	var party_membership_error := _validate_party_membership_state(snapshot)
	if not party_membership_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": party_membership_error}
	var party_route_error := _validate_party_route_state(snapshot)
	if not party_route_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": party_route_error}
	var campaign_completion_error := _validate_campaign_completion_state(snapshot)
	if not campaign_completion_error.is_empty():
		return {"ok": false, "snapshot": {}, "error": campaign_completion_error}
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
	encounter_intel = snapshot.encounter_intel.duplicate(true)
	quests = snapshot.quests.duplicate(true)
	quest_posting_blocked_until_turn = snapshot.quest_posting_blocked_until_turn
	watchtower_level = snapshot.watchtower_level
	temple_level = snapshot.temple_level
	blacksmith_level = snapshot.blacksmith_level
	blacksmith_craft_job = snapshot.blacksmith_craft_job.duplicate(true)
	blacksmith_sharpening_job = snapshot.blacksmith_sharpening_job.duplicate(true)
	alchemy_workshop_level = snapshot.alchemy_workshop_level
	alchemy_craft_job = snapshot.alchemy_craft_job.duplicate(true)
	runic_workshop_level = snapshot.runic_workshop_level
	runic_craft_job = snapshot.runic_craft_job.duplicate(true)
	mana_crystals = snapshot.mana_crystals.duplicate(true)
	banked_gear = snapshot.banked_gear.duplicate(true)
	owned_item_instances = snapshot.owned_item_instances.duplicate(true)
	banked_item_instance_ids.assign(snapshot.banked_item_instance_ids)
	has_trading_post = snapshot.has_trading_post
	shop_level = snapshot.shop_level
	shop_gold = snapshot.shop_gold
	player_name = snapshot.player_name
	tutorial_progress = snapshot.tutorial_progress.duplicate(true)
	journal_entries = (snapshot.get("journal_entries", []) as Array).duplicate(true)
	_journal_sequence = 0
	for entry in journal_entries:
		if int(entry.get("sequence", 0)) > _journal_sequence:
			_journal_sequence = int(entry.sequence)
	_backfill_missing_intel_records()
	journal_updated.emit()
	return result



## Stage 5 D5 (decision-ledger.md, Step 6 task 1): "a party may never share an
## adventurer with another party" -- CampaignSnapshot.from_dictionary() checks
## each party's own shape (see _normalize_party()) but has no cross-party
## concept, so a hand-edited or corrupted multi-party save could otherwise
## import two parties both claiming the same adventurer id. Structurally
## impossible to reach through normal play (assign_adventurer_to_party()/
## _is_adventurer_assigned() already forbid it at runtime), but import must
## still reject it atomically, exactly like every other malformed-field
## rejection in this pipeline.
func _validate_party_membership_state(snapshot: Dictionary) -> String:
	var claimed_by: Dictionary = {}
	for party in snapshot.parties:
		for raw_member_id in party.member_ids:
			var member_id := str(raw_member_id)
			if claimed_by.has(member_id):
				return "adventurer %s is assigned to more than one party (%s and %s)" % [
					member_id, claimed_by[member_id], party.id
				]
			claimed_by[member_id] = party.id
	return ""


## Stage 5 D5 (Step 6 task 1): "malformed... route imports must fail
## transactionally". CampaignSnapshot.from_dictionary() already validates
## each travel_route step's own shape (a real Vector2i), but not that
## consecutive steps -- starting from the party's own world_position -- are
## reachable one cardinal tile at a time, the same adjacency
## set_deployed_party_route() enforces at runtime. A hand-edited or corrupted
## save could otherwise silently teleport a party; reject the whole import
## atomically instead.
func _validate_party_route_state(snapshot: Dictionary) -> String:
	for party in snapshot.parties:
		var previous: Vector2i = party.world_position
		for step in party.travel_route:
			if _grid_distance(previous, step) != 1:
				return "party %s has a non-adjacent travel_route step" % party.id
			previous = step
	return ""


## set_campaign_victory() is the only place real play ever sets is_free_play_
## active true, and it always flips is_campaign_completed true in the same
## atomic call (see that function) -- no real campaign state ever has one
## true and the other false. CampaignSnapshot.from_dictionary() only checks
## each field's own type, not this cross-field relationship, so a
## hand-edited or corrupted save could otherwise import an incomplete
## campaign straight into free play. Rejecting it here (a GameSession-level
## policy, alongside the blacksmith/alchemy/runic checks below) keeps this
## rule out of CampaignSnapshot's own structural-only contract.
func _validate_campaign_completion_state(snapshot: Dictionary) -> String:
	if snapshot.is_free_play_active and not snapshot.is_campaign_completed:
		return "is_free_play_active cannot be true while is_campaign_completed is false"
	return ""


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

	# A party's own carry (see get_party_carry()/PartyCarry's own contract) is
	# a third valid location alongside the bank and an adventurer's equipped
	# inventory -- a slain party member's salvaged unique gear lives here
	# until deposit_party_carry() banks it (see transfer_dead_unit_gear_to_
	# party_carry()).
	for party in snapshot.parties:
		var carry = party.get("carry", {})
		if not carry is Dictionary:
			continue
		for raw_id in carry.get("item_instance_ids", []):
			var instance_id := str(raw_id)
			if not locations.has(instance_id):
				return "carried owned item instance is unknown"
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
			return (
				has_deployed_party() and selected_encounter == ""
				and int(get_party_carry(selected_party_id).get("gold", 0)) > 0
			)
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


## Publishes the currently relevant campaign guide as one durable Journal
## record. The Journal itself is the sole campaign-guidance presentation; a
## matching guide_id is never appended twice, including after save/load.
func publish_active_campaign_guidance() -> void:
	var guide_id := get_campaign_guide_state()
	if guide_id == "":
		return
	for entry in journal_entries:
		if entry.get("kind", "") == "campaign_guidance" and entry.get("detail", {}).get("guide_id", "") == guide_id:
			return
	append_journal_entry(
		"campaign_guidance",
		"journal.guidance.title",
		{
			"guide_id": guide_id,
			"message": tr("campaign_guide.%s.message" % guide_id),
			"target": tr("campaign_guide.%s.target" % guide_id),
		},
		JOURNAL_SECTION_LOG
	)
	record_campaign_guide_progress(guide_id)


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
