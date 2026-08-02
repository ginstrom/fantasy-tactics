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
