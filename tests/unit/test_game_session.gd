extends GutTest

const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func test_new_session_has_default_party_and_location() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.party, GameSessionScript.DEFAULT_PARTY, "New session starts with the default party")
	assert_eq(
		session.current_location,
		GameSessionScript.DEFAULT_LOCATION,
		"New session starts at the default location"
	)


func test_reset_restores_defaults_after_state_changes() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.party = ["someone_else"] as Array[String]
	session.current_location = "a_different_place"
	session.reset()

	assert_eq(session.party, GameSessionScript.DEFAULT_PARTY, "reset() restores the default party")
	assert_eq(
		session.current_location,
		GameSessionScript.DEFAULT_LOCATION,
		"reset() restores the default location"
	)


func test_start_new_game_replaces_prior_session_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.party = ["someone_else"] as Array[String]
	session.current_location = "a_different_place"
	session.start_new_game()

	assert_eq(session.party, GameSessionScript.DEFAULT_PARTY)
	assert_eq(session.current_location, GameSessionScript.DEFAULT_LOCATION)


func test_default_party_constant_is_not_mutated_by_instances() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.party.append("extra_member")

	assert_eq(
		GameSessionScript.DEFAULT_PARTY.size(),
		1,
		"Mutating a session's party must not mutate the shared default"
	)


func test_entering_an_encounter_records_it_as_selected() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.enter_encounter("goblin_camp")

	assert_eq(session.selected_encounter, "goblin_camp")
	assert_false(session.is_encounter_complete("goblin_camp"), "Entering does not itself complete an encounter")


func test_completing_the_current_encounter_marks_it_complete() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")

	session.complete_current_encounter()

	assert_true(session.is_encounter_complete("goblin_camp"), "Completing marks the encounter complete")
	assert_eq(session.selected_encounter, "", "Completing clears the selected encounter")


func test_reset_clears_encounter_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")
	session.complete_current_encounter()

	session.reset()

	assert_false(
		session.is_encounter_complete("goblin_camp"), "reset() clears previously completed encounters"
	)
	assert_eq(session.selected_encounter, "", "reset() clears the selected encounter")


func test_new_session_has_the_default_party_position() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.party_position, GameSessionScript.DEFAULT_PARTY_POSITION)


func test_reset_restores_the_default_party_position() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.party_position = Vector2i(3, 3)

	session.reset()

	assert_eq(
		session.party_position,
		GameSessionScript.DEFAULT_PARTY_POSITION,
		"reset() restores the default party position"
	)
