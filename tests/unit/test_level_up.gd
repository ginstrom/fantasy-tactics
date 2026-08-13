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


func test_shows_xp_level_health_gain_and_skill_gains_after_a_level_up() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 10)

	assert_eq(level_up.name_label.text, "Warrior")
	assert_eq(level_up.xp_label.text, tr("level_up.xp") % 20)
	assert_eq(level_up.level_label.text, tr("level_up.level") % 2)
	assert_eq(level_up.health_gain_label.text, tr("level_up.health_gain") % [20, 10])
	assert_true(level_up.skill_gains_label.text.contains("Gained Skills:"))
	assert_true(level_up.visible)


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
