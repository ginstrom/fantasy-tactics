extends GutTest

## Task 3: the immediate, modal level-up overlay. LevelUp reads fresh
## GameSession data for exactly one adventurer id, spends attack points and
## chooses perks only through GameSession's validated mutation APIs, and
## never calls GameManager or changes scenes itself — it only emits a
## completion signal that its owner (Battlefield) reacts to.

const LevelUpScene := preload("res://scenes/ui/level_up.tscn")


func before_each() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)


func _open_level_up(adventurer_id: String, health_before: int) -> Control:
	var level_up: Control = LevelUpScene.instantiate()
	add_child_autofree(level_up)
	level_up.show_for_adventurer(adventurer_id, health_before)
	return level_up


func test_shows_xp_level_health_gain_attack_and_skill_points_after_a_level_up() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 10)

	assert_eq(level_up.name_label.text, "Warrior")
	assert_eq(level_up.xp_label.text, tr("level_up.xp") % 20)
	assert_eq(level_up.level_label.text, tr("level_up.level") % 2)
	assert_eq(level_up.health_gain_label.text, tr("level_up.health_gain") % [20, 10])
	assert_eq(level_up.attack_label.text, tr("level_up.attack") % [60, 60])
	assert_eq(level_up.skill_points_label.text, tr("level_up.skill_points") % 10)
	assert_true(level_up.visible)


func test_xp_is_floored_for_display_and_never_mutates_the_stored_float() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 5.5)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_eq(level_up.xp_label.text, tr("level_up.xp") % 5)
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.xp,
		5.5,
		"Display-only flooring must never mutate the stored float"
	)


func test_attack_plus_button_spends_one_point_via_game_session_and_refreshes_the_display() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	level_up.attack_plus_button.emit_signal("pressed")

	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.attack, 61)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.skill_points, 9)
	assert_eq(level_up.skill_points_label.text, tr("level_up.skill_points") % 9)
	assert_eq(level_up.attack_label.text, tr("level_up.attack") % [61, 61])


func test_attack_plus_button_disables_once_every_unspent_point_is_spent() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	for i in range(10):
		level_up.attack_plus_button.emit_signal("pressed")

	assert_true(level_up.attack_plus_button.disabled)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.skill_points, 0)


func test_attack_plus_button_can_never_overspend_past_available_points() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	for i in range(25):
		level_up.attack_plus_button.emit_signal("pressed")

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.skill_points,
		0,
		"Repeated presses past the available amount must never go negative"
	)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.attack, 70)


## GameSession exposes no way to unspend an Attack point (spend_attack_points
## only ever adds), so a decrement control has nothing safe to do. It stays
## present (mirroring this codebase's "present but disabled" convention, e.g.
## unit_details.gd's AddToPartyButton) rather than hidden, and disabled always
## — pressing it must never call GameSession or change any stored value.
func test_attack_minus_button_is_present_but_always_disabled() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_true(level_up.attack_minus_button.visible)
	assert_true(level_up.attack_minus_button.disabled)

	level_up.attack_minus_button.emit_signal("pressed")

	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.attack, 60)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.skill_points, 10)


func test_continue_is_free_on_an_ordinary_level_and_emits_resolved() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)
	watch_signals(level_up)

	assert_false(level_up.continue_button.disabled, "Level 2 has no pending perk choice")
	level_up.continue_button.emit_signal("pressed")

	assert_signal_emitted(level_up, "resolved")
	assert_false(level_up.visible, "Continue should close the modal")


func test_continue_stays_disabled_until_a_pending_level_three_perk_is_chosen() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)
	watch_signals(level_up)

	assert_true(level_up.continue_button.disabled)
	assert_true(level_up.perk_label.visible)
	assert_true(level_up.choose_bonus_move_button.visible)

	level_up.continue_button.emit_signal("pressed")
	assert_signal_not_emitted(level_up, "resolved")
	assert_true(level_up.visible, "A required perk choice must block dismissal")

	level_up.choose_bonus_move_button.emit_signal("pressed")

	assert_true(GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks.has("bonus_move"))
	assert_false(level_up.continue_button.disabled)
	assert_false(level_up.perk_label.visible)

	level_up.continue_button.emit_signal("pressed")
	assert_signal_emitted(level_up, "resolved")


func test_choosing_the_perk_uses_game_sessions_bonus_move_perk_id_constant() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	level_up.choose_bonus_move_button.emit_signal("pressed")

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks,
		[GameSession.BONUS_MOVE_PERK_ID]
	)


func test_an_ordinary_level_never_shows_the_perk_controls() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_false(level_up.perk_label.visible)
	assert_false(level_up.choose_bonus_move_button.visible)


func test_level_up_never_calls_game_manager_or_changes_scenes() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/level_up.gd")
	assert_false(source.contains("GameManager"))
	assert_false(source.contains("change_scene"))
