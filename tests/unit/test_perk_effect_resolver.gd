extends GutTest

## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 04-branching-perk-definitions.md): PerkEffectResolver's pure rule
## evaluation over PerkCatalog's PerkDefinition catalog -- stat modifiers,
## granted actions, and action modifiers, exercised against the REAL shipped
## catalog (not a synthetic fixture) so this doubles as the "does the real
## Bulwark/Juggernaut/Quickdraw math still come out byte-identical" parity
## coverage the step's own review checklist calls for.

const PerkEffectResolverScript := preload("res://scripts/battle/perk_effect_resolver.gd")


## --- compute_stat_modifier() -------------------------------------------------

func test_compute_stat_modifier_applies_juggernauts_percent_bonus_to_max_health() -> void:
	var base := 100
	var expected := base + int(round(base * GameSession.WARRIOR_JUGGERNAUT_HP_PERCENT / 100.0))
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(base, ["warrior_juggernaut"], "max_health"), expected
	)


func test_compute_stat_modifier_applies_devouts_percent_bonus_to_max_health() -> void:
	var base := 100
	var expected := base + int(round(base * GameSession.CLERIC_DEVOUT_HP_PERCENT / 100.0))
	assert_eq(PerkEffectResolverScript.compute_stat_modifier(base, ["cleric_devout"], "max_health"), expected)


func test_compute_stat_modifier_is_a_no_op_without_a_matching_perk() -> void:
	assert_eq(PerkEffectResolverScript.compute_stat_modifier(100, [], "max_health"), 100)
	assert_eq(PerkEffectResolverScript.compute_stat_modifier(100, ["warrior_bulwark"], "max_health"), 100)


func test_compute_stat_modifier_applies_bulwarks_flat_bonus_to_defense() -> void:
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(10, ["warrior_bulwark"], "defense"),
		10 + GameSession.WARRIOR_BULWARK_GUARD
	)


func test_compute_stat_modifier_applies_the_legacy_bonus_move_perk_to_action_points() -> void:
	assert_eq(PerkEffectResolverScript.compute_stat_modifier(6, ["bonus_move"], "action_points"), 7)


func test_compute_stat_modifier_applies_quickdraws_flat_bonus_to_action_points() -> void:
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(6, ["scout_quickdraw"], "action_points"),
		6 + GameSession.SCOUT_QUICKDRAW_ACTION_POINTS
	)


func test_compute_stat_modifier_stacks_bonus_move_and_quickdraw_on_the_same_holder() -> void:
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(6, ["bonus_move", "scout_quickdraw"], "action_points"),
		6 + 1 + GameSession.SCOUT_QUICKDRAW_ACTION_POINTS
	)


func test_compute_stat_modifier_applies_keen_eyes_to_scout_intel_range() -> void:
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(3, ["scout_keen_eyes"], "scout_intel_range"),
		3 + GameSession.SCOUT_KEEN_EYES_INTEL_RANGE_BONUS
	)


func test_compute_stat_modifier_applies_meditation_to_spell_range() -> void:
	assert_eq(
		PerkEffectResolverScript.compute_stat_modifier(3, ["cleric_meditation"], "spell_range"),
		3 + GameSession.CLERIC_MEDITATION_SPELL_RANGE_BONUS
	)


## --- get_granted_actions() / has_granted_action() ---------------------------

func test_get_granted_actions_reports_shield_bash_for_its_holder() -> void:
	var actions := PerkEffectResolverScript.get_granted_actions(["knight_shield_bash"])
	assert_eq(actions.size(), 1)
	assert_eq(actions[0].action_id, "shield_bash")
	assert_eq(actions[0].perk_id, "knight_shield_bash")


func test_get_granted_actions_is_empty_for_a_stat_modifier_perk() -> void:
	assert_eq(PerkEffectResolverScript.get_granted_actions(["warrior_juggernaut"]), [])


func test_has_granted_action_true_only_for_the_matching_perk_holder() -> void:
	assert_true(PerkEffectResolverScript.has_granted_action(["knight_chain_blow"], "chain_blow"))
	assert_false(PerkEffectResolverScript.has_granted_action(["knight_shield_bash"], "chain_blow"))
	assert_false(PerkEffectResolverScript.has_granted_action([], "chain_blow"))


func test_has_granted_action_covers_archer_and_battle_mage_perks() -> void:
	assert_true(PerkEffectResolverScript.has_granted_action(["archer_lock_on"], "lock_on"))
	assert_true(PerkEffectResolverScript.has_granted_action(["archer_called_shot"], "called_shot"))
	assert_true(PerkEffectResolverScript.has_granted_action(["battle_mage_temporary_guard"], "temporary_guard"))


## --- resolve_action_modifier() ----------------------------------------------

func test_resolve_action_modifier_is_a_pass_through_with_no_matching_perk() -> void:
	var base_action := {"id": "attack", "hit_chance_bonus": 0.0}
	assert_eq(PerkEffectResolverScript.resolve_action_modifier(base_action, []), base_action)


func test_resolve_action_modifier_never_mutates_its_input() -> void:
	var base_action := {"id": "attack", "hit_chance_bonus": 0.0}
	PerkEffectResolverScript.resolve_action_modifier(base_action, ["knight_shield_bash"])
	assert_eq(base_action, {"id": "attack", "hit_chance_bonus": 0.0})
